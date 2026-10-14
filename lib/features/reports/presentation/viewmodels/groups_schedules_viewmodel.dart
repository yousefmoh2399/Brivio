import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupsSchedulesViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _groupsData = [];
  List<Map<String, dynamic>> get groupsData => _groupsData;

  Future<void> fetchGroupsData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('groups')
          .select('id, name, status, teachers(profiles(full_name)), schedules(day_of_week, start_time, end_time)')
          .order('name');

      final List<Map<String, dynamic>> list = [];
      for (final item in (res as List)) {
        final teacher = item['teachers'] as Map<String, dynamic>?;
        final prof = teacher?['profiles'] as Map<String, dynamic>?;
        final teacherName = prof?['full_name'] as String? ?? 'غير محدد';

        final schedules = item['schedules'] as List<dynamic>? ?? [];
        String timingStr = 'غير محدد الموعد';
        if (schedules.isNotEmpty) {
          final s0 = schedules.first as Map<String, dynamic>;
          final day = s0['day_of_week'] ?? '';
          final start = s0['start_time'] ?? '';
          final end = s0['end_time'] ?? '';
          timingStr = '$day $start - $end';
        }

        list.add({
          'group_name': item['name'] as String? ?? 'مجموعة بدون اسم',
          'timing': timingStr,
          'teacher': teacherName,
          'is_active': item['status'] == 'active',
        });
      }
      _groupsData = list;
    } catch (_) {
      _groupsData = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
