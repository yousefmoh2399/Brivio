import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Student {
  final String id;
  final String name;
  final String avatarUrl;
  final double attendanceRate;
  final double grade;

  Student({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.attendanceRate,
    required this.grade,
  });
}

class TeacherClass {
  final String id;
  final String name;
  final String time;
  final String room;
  final List<Student> students;

  TeacherClass({
    required this.id,
    required this.name,
    required this.time,
    required this.room,
    required this.students,
  });
}

class ClassesViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<TeacherClass> _classes = [];
  List<TeacherClass> get classes => _classes;

  Future<void> loadClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;

      String? teacherId;
      if (currentUserId != null) {
        final teacherRes = await client
            .from('teachers')
            .select('id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        teacherId = teacherRes?['id'] as String?;
      }

      var query = client
          .from('groups')
          .select('id, name, schedules(day_of_week, start_time, end_time, rooms(name))');

      if (teacherId != null) {
        query = query.eq('teacher_id', teacherId);
      }

      final res = await query.order('name');
      final List<TeacherClass> loadedClasses = [];

      for (final item in (res as List)) {
        final classId = item['id'] as String;
        final className = item['name'] as String? ?? 'مجموعة دراسية';
        final schedules = item['schedules'] as List<dynamic>? ?? [];

        String timeStr = 'غير محدد الموعد';
        String roomStr = 'قاعة عامة';

        if (schedules.isNotEmpty) {
          final s0 = schedules.first as Map<String, dynamic>;
          final day = s0['day_of_week'] ?? '';
          final start = s0['start_time'] ?? '';
          final end = s0['end_time'] ?? '';
          if (day.toString().isNotEmpty) {
            timeStr = '$day ($start - $end)';
          }
          final room = s0['rooms'] as Map<String, dynamic>?;
          if (room != null && room['name'] != null) {
            roomStr = room['name'] as String;
          }
        }

        // Fetch students for this group
        final List<Student> loadedStudents = [];
        try {
          final enrollments = await client
              .from('group_enrollments')
              .select('students(id, profiles(full_name, avatar_url))')
              .eq('group_id', classId)
              .eq('status', 'active');

          for (final en in (enrollments as List)) {
            final stu = en['students'] as Map<String, dynamic>?;
            final prof = stu?['profiles'] as Map<String, dynamic>?;
            if (stu != null) {
              loadedStudents.add(
                Student(
                  id: stu['id'] as String,
                  name: prof?['full_name'] as String? ?? 'طالب',
                  avatarUrl: prof?['avatar_url'] as String? ?? '',
                  attendanceRate: 100.0,
                  grade: 100.0,
                ),
              );
            }
          }
        } catch (_) {}

        loadedClasses.add(
          TeacherClass(
            id: classId,
            name: className,
            time: timeStr,
            room: roomStr,
            students: loadedStudents,
          ),
        );
      }

      _classes = loadedClasses;
    } catch (_) {
      _classes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
