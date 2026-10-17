import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleEvent {
  final String id;
  final String title;
  final String time;
  final String description;
  final Color color;
  final DateTime? date;
  final String groupName;
  final String subjectName;
  final String roomName;
  final String teacherName;
  final String statusText;
  final String dayName;
  final bool isToday;
  final bool isExam;

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.time,
    required this.description,
    required this.color,
    this.date,
    required this.groupName,
    required this.subjectName,
    required this.roomName,
    required this.teacherName,
    required this.statusText,
    required this.dayName,
    this.isToday = false,
    this.isExam = false,
  });

  factory ScheduleEvent.fromScheduleRow(Map<String, dynamic> row, DateTime today) {
    final groupName = row['group_name']?.toString() ?? 'المجموعة الدراسية';
    final subjectName = row['subject_name']?.toString() ?? 'حصة دراسية';
    final room = row['room_name']?.toString() ??
        row['location']?.toString() ??
        'القاعة الرئيسية';
    final teacher = row['teacher_name']?.toString() ?? 'معلم المادة';
    final rawStatus = row['status']?.toString() ?? 'scheduled';
    final statusText = switch (rawStatus.toLowerCase()) {
      'scheduled' || 'active' => 'مجدولة',
      'cancelled' => 'ملغاة',
      'completed' => 'مكتملة',
      'in_progress' => 'جارية الآن',
      _ => rawStatus,
    };

    final start = _formatTime(row['start_time']?.toString());
    final end = _formatTime(row['end_time']?.toString());
    final timeStr = (start.isNotEmpty && end.isNotEmpty) ? '$start - $end' : 'موعد الحصة';

    final sessionDateStr = row['session_date']?.toString();
    final sessionDate = sessionDateStr != null ? DateTime.tryParse(sessionDateStr) : null;
    final dayNum = (row['day_of_week'] as num?)?.toInt() ?? (sessionDate?.weekday ?? 6);
    final dayName = _dayNameFromNumber(dayNum);

    final isToday = sessionDate != null
        ? (sessionDate.year == today.year &&
            sessionDate.month == today.month &&
            sessionDate.day == today.day)
        : (_isoWeekday(today) == dayNum);

    Color color;
    if (rawStatus == 'cancelled') {
      color = Colors.redAccent;
    } else if (rawStatus == 'in_progress') {
      color = Colors.green;
    } else if (isToday) {
      color = const Color(0xFF10B981);
    } else {
      color = const Color(0xFF1E88E5);
    }

    return ScheduleEvent(
      id: row['class_session_id']?.toString() ?? row['schedule_id']?.toString() ?? row['id']?.toString() ?? '',
      title: subjectName,
      time: timeStr,
      description: '$groupName • $room • $teacher',
      color: color,
      date: sessionDate,
      groupName: groupName,
      subjectName: subjectName,
      roomName: room,
      teacherName: teacher,
      statusText: statusText,
      dayName: dayName,
      isToday: isToday,
      isExam: false,
    );
  }

  factory ScheduleEvent.fromExamRow(Map<String, dynamic> row) {
    final title = row['title']?.toString() ?? 'اختبار تقييمي';
    final groupName = row['group_name']?.toString() ?? 'المجموعة الدراسية';
    final duration = (row['duration_minutes'] as num?)?.toInt() ?? 30;
    final maxScore = (row['max_score'] as num?)?.toDouble() ?? 100.0;
    final rawStatus = row['last_attempt_status']?.toString() ?? row['status']?.toString() ?? 'published';
    
    final statusText = switch (rawStatus.toLowerCase()) {
      'graded' => 'تم التصحيح',
      'submitted' => 'تم التسليم',
      'published' || 'active' => 'متاح الآن',
      _ => 'قادم',
    };

    final maxScoreStr = maxScore == maxScore.roundToDouble()
        ? maxScore.toStringAsFixed(0)
        : maxScore.toStringAsFixed(1);

    return ScheduleEvent(
      id: row['id']?.toString() ?? '',
      title: title,
      time: '$duration دقيقة',
      description: '$groupName • الدرجة النهائية: $maxScoreStr درجات',
      color: const Color(0xFF8B5CF6),
      groupName: groupName,
      subjectName: title,
      roomName: 'اختبار بالسنتر / إلكتروني',
      teacherName: 'إدارة السنتر',
      statusText: statusText,
      dayName: 'متاح للحل',
      isToday: false,
      isExam: true,
    );
  }

  static String _formatTime(String? value) {
    if (value == null || value.length < 5) return '';
    try {
      final parts = value.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'م' : 'ص';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return '$hour:$minute $period';
      }
    } catch (_) {}
    return value.substring(0, 5);
  }

  static String _dayNameFromNumber(int day) {
    return switch (day) {
      6 => 'السبت',
      7 || 0 => 'الأحد',
      1 => 'الإثنين',
      2 => 'الثلاثاء',
      3 => 'الأربعاء',
      4 => 'الخميس',
      5 => 'الجمعة',
      _ => 'يوم الحصة',
    };
  }

  static int _isoWeekday(DateTime dt) {
    return dt.weekday; // 1 = Mon .. 7 = Sun
  }
}

class ChildScheduleViewModel extends ChangeNotifier {
  final List<ScheduleEvent> todaySchedule = [];
  final List<ScheduleEvent> weeklySchedule = [];
  final List<ScheduleEvent> upcomingSchedule = [];
  final List<ScheduleEvent> upcomingExams = [];
  final List<ScheduleEvent> holidays = [];

  bool isLoading = false;
  String? errorMessage;

  ScheduleEvent? get nextClassSession {
    if (todaySchedule.isNotEmpty) return todaySchedule.first;
    if (upcomingSchedule.isNotEmpty) return upcomingSchedule.first;
    if (weeklySchedule.isNotEmpty) return weeklySchedule.first;
    return null;
  }

  Future<void> loadForChild(String studentId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final today = DateTime.now();
      final fromDate = DateTime(today.year, today.month, today.day);
      final toDate = fromDate.add(const Duration(days: 30));

      final client = Supabase.instance.client;

      List<dynamic> rows = [];
      try {
        final response = await client.rpc(
          'get_parent_child_schedule',
          params: {
            'p_student_id': studentId,
            'p_from_date': _dateOnly(fromDate),
            'p_to_date': _dateOnly(toDate),
          },
        );
        if (response is List) rows = response;
      } catch (_) {
        // Fallback: direct table query via enrollments -> groups -> schedules
        try {
          final res = await client
              .from('enrollments')
              .select('group_id, groups(id, name, subject, teachers(profiles(full_name)), schedules(*))')
              .eq('student_id', studentId)
              .eq('status', 'active');

          final List<Map<String, dynamic>> fallbackRows = [];
          for (final en in (res as List)) {
            final grp = en['groups'] as Map<String, dynamic>?;
            if (grp == null) continue;
            final grpName = grp['name']?.toString() ?? 'المجموعة';
            final subject = grp['subject']?.toString() ?? 'حصة دراسية';
            final teacherProf = grp['teachers']?['profiles'] as Map<String, dynamic>?;
            final teacherName = teacherProf?['full_name']?.toString() ?? 'معلم المادة';
            final schList = grp['schedules'] as List<dynamic>? ?? [];

            for (final sch in schList) {
              final sMap = Map<String, dynamic>.from(sch as Map);
              fallbackRows.add({
                'group_name': grpName,
                'subject_name': subject,
                'teacher_name': teacherName,
                'start_time': sMap['start_time'],
                'end_time': sMap['end_time'],
                'day_of_week': sMap['day_of_week'],
                'location': sMap['location'] ?? sMap['room_location'] ?? 'القاعة الرئيسية',
                'status': sMap['status'] ?? 'active',
              });
            }
          }
          rows = fallbackRows;
        } catch (_) {}
      }

      todaySchedule.clear();
      weeklySchedule.clear();
      upcomingSchedule.clear();

      final seenRecurring = <String>{};

      for (final r in rows) {
        final row = Map<String, dynamic>.from(r as Map);
        final event = ScheduleEvent.fromScheduleRow(row, today);

        if (event.isToday) {
          todaySchedule.add(event);
        }

        if (event.date != null && event.date!.isAfter(today.subtract(const Duration(hours: 2)))) {
          upcomingSchedule.add(event);
        }

        // Deduplicate weekly recurring schedules by group and day of week
        final recurringKey = '${event.groupName}_${event.dayName}_${event.time}';
        if (!seenRecurring.contains(recurringKey)) {
          seenRecurring.add(recurringKey);
          weeklySchedule.add(event);
        }
      }

      // 2. Fetch real upcoming exams for this child
      upcomingExams.clear();
      try {
        final examRes = await client.rpc(
          'get_parent_child_exam_feed',
          params: {'p_student_id': studentId},
        );
        if (examRes is List) {
          for (final row in examRes) {
            final e = Map<String, dynamic>.from(row as Map);
            upcomingExams.add(ScheduleEvent.fromExamRow(e));
          }
        }
      } catch (_) {
        // Fallback: direct exams table query
        try {
          final examFallback = await client
              .from('exams')
              .select('id, title, duration_minutes, max_attempts, total_marks, status, groups(name)')
              .eq('status', 'published')
              .limit(10);
          for (final row in (examFallback as List)) {
            final e = Map<String, dynamic>.from(row as Map);
            final grp = e['groups'] as Map<String, dynamic>?;
            upcomingExams.add(ScheduleEvent.fromExamRow({
              'id': e['id'],
              'title': e['title'],
              'group_name': grp?['name'] ?? 'المجموعة الدراسية',
              'duration_minutes': e['duration_minutes'] ?? 30,
              'max_score': e['total_marks'] ?? 100,
              'status': e['status'] ?? 'published',
            }));
          }
        } catch (_) {}
      }

      holidays.clear();
    } catch (e) {
      errorMessage = e.toString();
      todaySchedule.clear();
      weeklySchedule.clear();
      upcomingSchedule.clear();
      upcomingExams.clear();
      holidays.clear();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  static String _dateOnly(DateTime value) {
    return value.toIso8601String().split('T').first;
  }
}
