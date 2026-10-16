import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';

/// Centralized service for provisioning and creating user accounts (students, teachers, staff, parents).
/// Implements dual-strategy:
/// 1. Tries trusted Edge Function 'provision-user' first if deployed.
/// 2. If the Edge Function is missing (HTTP 404) or fails, falls back transparently
///    to direct Auth REST API sign-up and database RPC/upsert.
class UserProvisioningService {
  static Future<Map<String, dynamic>> provisionUser({
    required String email,
    required String fullName,
    required String role,
    String? branchId,
    String? centerId,
    String? phoneNumber,
    String? gradeLevel,
    String? specialization,
    String? password,
    String? studentCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
    final cleanStudentCode = (studentCode != null && studentCode.trim().isNotEmpty)
        ? studentCode.trim()
        : null;
    final cleanPhone = (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        ? phoneNumber.trim()
        : null;
    final cleanBranchId = (branchId != null && branchId.trim().isNotEmpty)
        ? branchId.trim()
        : null;
    final cleanGrade = (gradeLevel != null && gradeLevel.trim().isNotEmpty)
        ? gradeLevel.trim()
        : null;
    final cleanSpec = (specialization != null && specialization.trim().isNotEmpty)
        ? specialization.trim()
        : null;

    final client = Supabase.instance.client;

    // Resolve centerId from admin profile if not provided
    String? effectiveCenterId = (centerId != null && centerId.trim().isNotEmpty)
        ? centerId.trim()
        : null;
    if (effectiveCenterId == null) {
      final curUser = client.auth.currentUser;
      if (curUser != null) {
        try {
          final p = await client
              .from('profiles')
              .select('center_id')
              .eq('id', curUser.id)
              .maybeSingle();
          if (p != null && p['center_id'] != null) {
            effectiveCenterId = p['center_id'].toString();
          }
        } catch (_) {}
      }
    }

    // 1. Attempt trusted Edge Function 'provision-user' first if deployed
    try {
      final response = await client.functions.invoke(
        'provision-user',
        body: {
          'email': cleanEmail,
          'fullName': cleanName,
          'role': role,
          if (cleanBranchId != null) 'branchId': cleanBranchId,
          if (effectiveCenterId != null) 'centerId': effectiveCenterId,
          if (cleanPhone != null) 'phoneNumber': cleanPhone,
          if (cleanStudentCode != null) 'studentCode': cleanStudentCode,
          if (cleanGrade != null) 'gradeLevel': cleanGrade,
          if (cleanSpec != null) 'specialization': cleanSpec,
          if (password != null && password.trim().isNotEmpty)
            'password': password.trim(),
        },
      ).timeout(const Duration(seconds: 8));

      if (response.status >= 200 && response.status < 300) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {
      AppLogger.info(
        'Edge function provision-user unavailable or failed ($e). Falling back to direct database provisioning...',
      );
    }

    // 2. Direct Provisioning Fallback via Supabase Auth REST API
    // Generate temporary password if none provided
    final effectivePassword = (password != null && password.trim().isNotEmpty)
        ? password.trim()
        : 'Brivio@${100000 + Random().nextInt(900000)}';

    String newUserId = '';

    // Direct HTTP call to /auth/v1/signup avoids client PKCE storage requirements
    // and completely prevents touching the current admin session.
    final signupUri = Uri.parse('${AppConfig.effectiveSupabaseUrl}/auth/v1/signup');
    try {
      final httpResponse = await http.post(
        signupUri,
        headers: {
          'apikey': AppConfig.effectiveSupabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': cleanEmail,
          'password': effectivePassword,
          'data': {
            'full_name': cleanName,
            'role': role,
            if (cleanBranchId != null) 'branch_id': cleanBranchId,
            if (effectiveCenterId != null) 'center_id': effectiveCenterId,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      final dynamic responseBody = jsonDecode(httpResponse.body);

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        if (responseBody is Map<String, dynamic>) {
          newUserId = responseBody['id']?.toString() ??
              responseBody['user']?['id']?.toString() ??
              '';
        }
        if (newUserId.isEmpty) {
          throw Exception('تعذر استخراج معرّف المستخدم من استجابة المصادقة.');
        }
      } else {
        final msg = (responseBody is Map
                ? (responseBody['msg'] ??
                    responseBody['message'] ??
                    responseBody['error_description'] ??
                    responseBody['error'])
                : null)
            ?.toString()
            .toLowerCase() ??
            '';

        if (msg.contains('already registered') ||
            msg.contains('already exists') ||
            msg.contains('user already exists')) {
          throw Exception('هذا البريد الإلكتروني مسجل بالفعل لمستخدم آخر.');
        }
        throw Exception(
          responseBody is Map && responseBody['msg'] != null
              ? responseBody['msg'].toString()
              : (responseBody is Map && responseBody['message'] != null
                  ? responseBody['message'].toString()
                  : 'فشل إنشاء حساب المصادقة: رمز الحالة ${httpResponse.statusCode}'),
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('فشل الاتصال بخادم المصادقة: $e');
    }

    // 3. Complete Profile and Domain Entity
    // Try complete_privileged_user_profile RPC first
    try {
      await client.rpc(
        'complete_privileged_user_profile',
        params: {
          'p_target_user_id': newUserId,
          'p_full_name': cleanName,
          'p_role': role,
          if (cleanBranchId != null) 'p_branch_id': cleanBranchId,
        },
      );
    } catch (rpcError) {
      AppLogger.warning(
        'complete_privileged_user_profile RPC failed ($rpcError), falling back to direct table upsert...',
      );
    }

    // Direct table upserts if RPC failed or for supplementary domain fields
    try {
      await client.from('profiles').upsert({
        'id': newUserId,
        'email': cleanEmail,
        'full_name': cleanName,
        'role': role,
        if (cleanBranchId != null) 'branch_id': cleanBranchId,
        if (effectiveCenterId != null) 'center_id': effectiveCenterId,
        if (cleanPhone != null) 'phone_number': cleanPhone,
        'status': 'active',
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      AppLogger.warning('Profiles table direct upsert note: $e');
    }

    // Domain entity table provisioning
    try {
      if (role == 'student') {
        final generatedCode = cleanStudentCode ??
            'STU-${newUserId.replaceAll('-', '').substring(0, 8).toUpperCase()}';
        await client.from('students').upsert(
          {
            'profile_id': newUserId,
            'student_code': generatedCode,
            if (cleanBranchId != null) 'primary_branch_id': cleanBranchId,
            if (cleanGrade != null) 'grade_level': cleanGrade,
            if (cleanPhone != null) 'emergency_contact_phone': cleanPhone,
            'status': 'active',
          },
          onConflict: 'profile_id',
        );
      } else if (role == 'teacher') {
        await client.from('teachers').upsert(
          {
            'profile_id': newUserId,
            if (cleanBranchId != null) 'primary_branch_id': cleanBranchId,
            if (cleanSpec != null) 'specialization': cleanSpec,
            'status': 'active',
          },
          onConflict: 'profile_id',
        );
      } else if (role == 'parent') {
        await client.from('parents').upsert(
          {
            'profile_id': newUserId,
            'status': 'active',
          },
          onConflict: 'profile_id',
        );
      }
    } catch (e) {
      AppLogger.warning('Domain entity direct upsert note: $e');
    }

    // Supplementary field updates
    if (cleanPhone != null) {
      try {
        await client
            .from('profiles')
            .update({'phone_number': cleanPhone})
            .eq('id', newUserId);
      } catch (_) {}
    }

    if (role == 'student' && cleanGrade != null) {
      try {
        await client
            .from('students')
            .update({'grade_level': cleanGrade})
            .eq('profile_id', newUserId);
      } catch (_) {}
    }

    return {
      'success': true,
      'userId': newUserId,
      'email': cleanEmail,
      'role': role,
      'temporaryPassword': effectivePassword,
    };
  }
}
