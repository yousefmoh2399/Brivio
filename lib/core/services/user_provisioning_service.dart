import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';

/// Centralized service for provisioning and creating user accounts (students, teachers, staff, parents).
/// Implements dual-strategy:
/// 1. Tries trusted Edge Function 'provision-user' first if deployed.
/// 2. If the Edge Function is missing (HTTP 404) or fails, falls back transparently
///    to isolated client auth sign-up and database RPC/upsert.
class UserProvisioningService {
  static Future<Map<String, dynamic>> provisionUser({
    required String email,
    required String fullName,
    required String role,
    String? branchId,
    String? phoneNumber,
    String? gradeLevel,
    String? specialization,
    String? password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
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

    // 1. Attempt trusted Edge Function 'provision-user' first
    try {
      final response = await client.functions.invoke(
        'provision-user',
        body: {
          'email': cleanEmail,
          'fullName': cleanName,
          'role': role,
          if (cleanBranchId != null) 'branchId': cleanBranchId,
          if (cleanPhone != null) 'phoneNumber': cleanPhone,
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

    // 2. Direct Provisioning Fallback
    // Generate temporary password if none provided
    final effectivePassword = (password != null && password.trim().isNotEmpty)
        ? password.trim()
        : 'Brivio@${100000 + Random().nextInt(900000)}';

    String newUserId;

    // Create an isolated SupabaseClient so the current admin/staff session is untouched
    final tempClient = SupabaseClient(
      AppConfig.effectiveSupabaseUrl,
      AppConfig.effectiveSupabaseAnonKey,
    );

    try {
      final authRes = await tempClient.auth.signUp(
        email: cleanEmail,
        password: effectivePassword,
        data: {
          'full_name': cleanName,
          'role': role,
          if (cleanBranchId != null) 'branch_id': cleanBranchId,
        },
      );

      final user = authRes.user;
      if (user == null) {
        throw Exception('تعذر إنشاء حساب المستخدم في نظام المصادقة.');
      }
      newUserId = user.id;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('user already exists') ||
          msg.contains('already exists')) {
        throw Exception('هذا البريد الإلكتروني مسجل بالفعل لمستخدم آخر.');
      }
      throw Exception('خطأ في المصادقة: ${e.message}');
    } catch (e) {
      throw Exception('فشل إنشاء حساب المصادقة: $e');
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
        final generatedCode =
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
