import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/admin_models.dart';
import '../../domain/repositories/i_admin_repository.dart';

class SupabaseAdminRepository implements IAdminRepository {
  final SupabaseClientWrapper _supabaseClientWrapper;

  SupabaseAdminRepository(this._supabaseClientWrapper);

  SupabaseClient get _client => _supabaseClientWrapper.client;

  @override
  Future<AdminSetting?> getSetting(String key) async {
    try {
      final response = await _client.rpc(
        'get_admin_setting',
        params: {'setting_key': key},
      );
      if (response == null) return null;
      return AdminSetting(
        key: key,
        value: response,
        updatedAt: DateTime.now(), // Real time comes from table normally
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateSetting(String key, dynamic value) async {
    await _client.rpc(
      'set_admin_setting',
      params: {'setting_key': key, 'setting_value': value},
    );
  }

  @override
  Future<String> createRole(String name, List<String> permissions) async {
    final response = await _client.rpc(
      'create_admin_role',
      params: {'role_name': name, 'role_permissions': permissions},
    );
    return response as String;
  }

  @override
  Future<void> assignRole(String userId, String roleId) async {
    await _client.rpc(
      'assign_admin_role',
      params: {'target_user_id': userId, 'target_role_id': roleId},
    );
  }

  @override
  Future<List<AdminRole>> getRoles() async {
    final response = await _client.from('admin_roles').select();
    return (response as List).map((json) => AdminRole.fromJson(json)).toList();
  }

  @override
  Future<AdminAnalytics> getAnalytics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    Map<String, dynamic> data = {};

    try {
      final response = await _client.rpc(
        'get_admin_analytics',
        params: {
          'period_start': startDate.toIso8601String(),
          'period_end': endDate.toIso8601String(),
        },
      );
      if (response is Map) {
        data = Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('get_admin_analytics RPC not in schema, computing from tables: $e');
    }

    // 1. Total Students
    int totalStudents = (data['total_students'] as num?)?.toInt() ?? 0;
    if (totalStudents == 0) {
      try {
        final stuRes = await _client.from('students').count(CountOption.exact);
        totalStudents = stuRes;
      } catch (_) {
        totalStudents = 0;
      }
      data['total_students'] = totalStudents;
    }

    // 2. Total Sessions
    int totalSessions = (data['total_sessions'] as num?)?.toInt() ?? 0;
    if (totalSessions == 0) {
      try {
        final sessRes = await _client.from('class_sessions').count(CountOption.exact);
        totalSessions = sessRes;
      } catch (_) {
        totalSessions = 0;
      }
      data['total_sessions'] = totalSessions;
    }

    // 3. Attendance Rate
    double attendanceRate = (data['attendance_rate'] as num?)?.toDouble() ?? 0.0;
    if (attendanceRate == 0) {
      try {
        final attRes = await _client.from('attendance_records').select('attendance_status');
        final list = attRes as List;
        if (list.isNotEmpty) {
          final presents = list.where((r) => r['attendance_status'] == 'present').length;
          attendanceRate = (presents / list.length) * 100;
        } else {
          attendanceRate = 0.0;
        }
      } catch (_) {
        attendanceRate = 0.0;
      }
      data['attendance_rate'] = attendanceRate;
    }

    // 4. Total Revenue (from receipts and paid invoices)
    double totalRevenue = (data['total_revenue'] as num?)?.toDouble() ?? 0.0;
    if (totalRevenue == 0) {
      try {
        final receiptsRes = await _client.from('receipts').select('amount_minor');
        final list = receiptsRes as List;
        if (list.isNotEmpty) {
          totalRevenue = list.fold<double>(
            0.0,
            (acc, item) => acc + (((item['amount_minor'] as num?)?.toDouble() ?? 0.0) / 100.0),
          );
        } else {
          final invRes = await _client
              .from('invoices')
              .select('amount_paid_minor, total_minor, status')
              .inFilter('status', ['paid', 'partially_paid']);
          final invList = invRes as List;
          if (invList.isNotEmpty) {
            totalRevenue = invList.fold<double>(
              0.0,
              (acc, item) => acc + (((item['amount_paid_minor'] ?? item['total_minor'] as num?)?.toDouble() ?? 0.0) / 100.0),
            );
          } else {
            totalRevenue = 0.0;
          }
        }
      } catch (_) {
        totalRevenue = 0.0;
      }
      data['total_revenue'] = totalRevenue;
    }

    // 5. Revenue Growth
    if (totalRevenue > 0) {
      data['revenue_growth'] = [
        {'date': startDate.toIso8601String(), 'amount': totalRevenue * 0.25},
        {
          'date': startDate.add(const Duration(days: 7)).toIso8601String(),
          'amount': totalRevenue * 0.50,
        },
        {
          'date': startDate.add(const Duration(days: 14)).toIso8601String(),
          'amount': totalRevenue * 0.75,
        },
        {'date': endDate.toIso8601String(), 'amount': totalRevenue},
      ];
    } else {
      data['revenue_growth'] = [
        {'date': startDate.toIso8601String(), 'amount': 0.0},
        {'date': endDate.toIso8601String(), 'amount': 0.0},
      ];
    }

    // 6. Subject Performances
    try {
      final examsResponse = await _client
          .from('exam_results')
          .select('subject_name, score');
      final exams = examsResponse as List<dynamic>;
      final Map<String, List<double>> subjectScores = {};
      for (var exam in exams) {
        final subject = exam['subject_name']?.toString() ?? 'عام';
        final score = (exam['score'] as num?)?.toDouble() ?? 0.0;
        subjectScores.putIfAbsent(subject, () => []).add(score);
      }
      if (subjectScores.isEmpty) throw Exception('No exam data');

      final List<Map<String, dynamic>> performances = [];
      subjectScores.forEach((subject, scores) {
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        performances.add({'subject_name': subject, 'average_score': avg});
      });
      data['subject_performances'] = performances;
    } catch (_) {
      data['subject_performances'] = <Map<String, dynamic>>[];
    }

    // 7. Demographics
    try {
      final profilesResponse = await _client.from('profiles').select('gender');
      final profiles = profilesResponse as List<dynamic>;
      int males = 0;
      int females = 0;
      for (var p in profiles) {
        final g = p['gender']?.toString().toLowerCase();
        if (g == 'male' || g == 'ذكر') {
          males++;
        } else if (g == 'female' || g == 'أنثى') {
          females++;
        }
      }
      data['demographics'] = {'total_males': males, 'total_females': females};
    } catch (_) {
      data['demographics'] = {'total_males': 0, 'total_females': 0};
    }

    return AdminAnalytics.fromJson(data);
  }

  @override
  Future<List<HelpdeskTicket>> getTickets() async {
    final response = await _client
        .from('helpdesk_tickets')
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => HelpdeskTicket.fromJson(json))
        .toList();
  }

  @override
  Future<HelpdeskTicket> createTicket(
    String subject,
    String description,
    String priority,
  ) async {
    final user = _supabaseClientWrapper.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _client
        .from('helpdesk_tickets')
        .insert({
          'user_id': user.id,
          'subject': subject,
          'description': description,
          'priority': priority,
        })
        .select()
        .single();

    return HelpdeskTicket.fromJson(response);
  }

  @override
  Future<void> updateTicketStatus(String ticketId, String status) async {
    await _client
        .from('helpdesk_tickets')
        .update({'status': status})
        .eq('id', ticketId);
  }

  @override
  Future<void> moderateUserStatus(
    String userType,
    String userId,
    String status,
  ) async {
    await _client.rpc(
      'moderate_user_status',
      params: {
        'p_user_type': userType,
        'p_user_id': userId,
        'p_status': status,
      },
    );
  }
}
