import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceReportsViewModel extends ChangeNotifier {
  bool isLoading = false;

  List<Map<String, dynamic>> studentAttendance = [];
  List<Map<String, dynamic>> teacherAttendance = [];
  List<Map<String, dynamic>> staffAttendance = [];

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;

      // 1. Students Attendance
      try {
        final stuRes = await client
            .from('attendance')
            .select('status, date, students(profiles(full_name))')
            .limit(100);

        final Map<String, Map<String, dynamic>> studentMap = {};
        for (final item in (stuRes as List)) {
          final stu = item['students'] as Map<String, dynamic>?;
          final prof = stu?['profiles'] as Map<String, dynamic>?;
          final name = prof?['full_name'] as String? ?? 'طالب';
          final isPresent = item['status'] == 'present';
          final dateStr = item['date']?.toString() ?? '';

          if (!studentMap.containsKey(name)) {
            studentMap[name] = {
              'name': name,
              'present': 0,
              'absent': 0,
              'absence_dates': '',
              'status': 'منتظم',
            };
          }

          if (isPresent) {
            studentMap[name]!['present'] = (studentMap[name]!['present'] as int) + 1;
          } else {
            studentMap[name]!['absent'] = (studentMap[name]!['absent'] as int) + 1;
            final existingDates = studentMap[name]!['absence_dates'] as String;
            studentMap[name]!['absence_dates'] = existingDates.isEmpty ? dateStr : '$existingDates, $dateStr';
          }
        }
        studentAttendance = studentMap.values.toList();
      } catch (_) {
        studentAttendance = [];
      }

      // 2. Teachers Attendance
      try {
        final tchRes = await client.from('teachers').select('id, profiles(full_name)').limit(50);
        teacherAttendance = (tchRes as List).map((item) {
          final prof = item['profiles'] as Map<String, dynamic>?;
          return {
            'name': prof?['full_name'] ?? 'معلم',
            'present': 0,
            'absent': 0,
            'absence_dates': '',
            'status': 'منتظم',
          };
        }).toList();
      } catch (_) {
        teacherAttendance = [];
      }

      // 3. Staff Attendance
      try {
        final staffRes = await client
            .from('profiles')
            .select('full_name, role')
            .inFilter('role', ['admin', 'staff', 'super_admin'])
            .limit(50);
        staffAttendance = (staffRes as List).map((item) {
          return {
            'name': item['full_name'] ?? 'موظف إداري',
            'present': 0,
            'absent': 0,
            'absence_dates': '',
            'status': 'منتظم',
          };
        }).toList();
      } catch (_) {
        staffAttendance = [];
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
