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
    DateTime? sessionDate = sessionDateStr != null ? DateTime.tryParse(sessionDateStr) : null;
    final dayNum = (row['day_of_week'] as num?)?.toInt() ?? (sessionDate?.weekday ?? 6);
    final dayName = _dayNameFromNumber(dayNum);

    // If sessionDate is null (recurring weekly schedule), calculate the next date for this day_of_week
    if (sessionDate == null) {
      final currentWeekday = today.weekday; // 1 = Mon ... 6 = Sat, 7 = Sun
      final targetWeekday = (dayNum == 0 || dayNum == 7) ? 7 : dayNum;
      int daysUntil = targetWeekday - currentWeekday;
      if (daysUntil < 0) daysUntil += 7;
      sessionDate = DateTime(today.year, today.month, today.day).add(Duration(days: daysUntil));
    }

    final isToday = (sessionDate.year == today.year &&
        sessionDate.month == today.month &&
        sessionDate.day == today.day);

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
        if (response is List && response.isNotEmpty) {
          rows = response;
        }
      } catch (_) {}

      // Fallback: robust multi-table resolution if RPC failed or returned no data
      if (rows.isEmpty) {
        try {
          String effectiveStudentId = studentId;
          try {
            final sRes = await client
                .from('students')
                .select('id')
                .or('id.eq.$studentId,profile_id.eq.$studentId')
                .maybeSingle();
            if (sRes != null && sRes['id'] != null) {
              effectiveStudentId = sRes['id'].toString();
            }
          } catch (_) {}

          final enRes = await client
              .from('enrollments')
              .select('group_id, status')
              .or('student_id.eq.$effectiveStudentId,student_id.eq.$studentId');

          final groupIds = <String>{};
          for (final row in (enRes as List)) {
            final status = row['status']?.toString().toLowerCase();
            if (status != 'cancelled' && status != 'dropped' && status != 'suspended') {
              final gId = row['group_id']?.toString();
              if (gId != null && gId.isNotEmpty) {
                groupIds.add(gId);
              }
            }
          }

          if (groupIds.isNotEmpty) {
            final groupsRes = await client
                .from('groups')
                .select('id, name, subject_id, teacher_id')
                .inFilter('id', groupIds.toList());

            final gList = (groupsRes as List).cast<Map<String, dynamic>>();

            final subjectIds = gList
                .map((g) => g['subject_id']?.toString())
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList();

            final Map<String, String> subjectNames = {};
            if (subjectIds.isNotEmpty) {
              try {
                final subs = await client
                    .from('subjects')
                    .select('id, name')
                    .inFilter('id', subjectIds);
                for (final s in (subs as List)) {
                  subjectNames[s['id'].toString()] = s['name']?.toString() ?? 'حصة دراسية';
                }
              } catch (_) {}
            }

            final teacherIds = gList
                .map((g) => g['teacher_id']?.toString())
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList();

            final Map<String, String> teacherNames = {};
            if (teacherIds.isNotEmpty) {
              try {
                final tRes = await client
                    .from('teachers')
                    .select('id, profiles(full_name)')
                    .inFilter('id', teacherIds);
                for (final t in (tRes as List)) {
                  final prof = t['profiles'] as Map<String, dynamic>?;
                  if (prof != null && prof['full_name'] != null) {
                    teacherNames[t['id'].toString()] = prof['full_name'].toString();
                  }
                }
              } catch (_) {}
            }

            final List<Map<String, dynamic>> fallbackRows = [];

            // 1. Fetch class sessions for date window
            try {
              final sessionsRes = await client
                  .from('class_sessions')
                  .select('id, group_id, session_date, day_of_week, scheduled_start_at, scheduled_end_at, status, location')
                  .inFilter('group_id', groupIds.toList())
                  .gte('session_date', _dateOnly(fromDate))
                  .lte('session_date', _dateOnly(toDate));

              for (final cs in (sessionsRes as List)) {
                final gId = cs['group_id']?.toString();
                final grp = gList.firstWhere(
                  (g) => g['id'].toString() == gId,
                  orElse: () => <String, dynamic>{},
                );
                final subId = grp['subject_id']?.toString();
                final tId = grp['teacher_id']?.toString();
                fallbackRows.add({
                  'source_type': 'session',
                  'class_session_id': cs['id'],
                  'group_id': gId,
                  'group_name': grp['name'] ?? 'مجموعة دراسية',
                  'subject_name': subjectNames[subId] ?? 'حصة دراسية',
                  'teacher_name': teacherNames[tId] ?? 'معلم المادة',
                  'session_date': cs['session_date'],
                  'day_of_week': cs['day_of_week'],
                  'scheduled_start_at': cs['scheduled_start_at'],
                  'scheduled_end_at': cs['scheduled_end_at'],
                  'start_time': cs['scheduled_start_at']?.toString().split('T').last.substring(0, 5),
                  'end_time': cs['scheduled_end_at']?.toString().split('T').last.substring(0, 5),
                  'status': cs['status'] ?? 'scheduled',
                  'location': cs['location'] ?? 'القاعة الرئيسية',
                });
              }
            } catch (_) {}

            // 2. Fetch recurring schedules
            try {
              final schRes = await client
                  .from('schedules')
                  .select('id, group_id, day_of_week, start_time, end_time, location, room_location, status')
                  .inFilter('group_id', groupIds.toList());

              for (final sch in (schRes as List)) {
                final gId = sch['group_id']?.toString();
                final grp = gList.firstWhere(
                  (g) => g['id'].toString() == gId,
                  orElse: () => <String, dynamic>{},
                );
                final subId = grp['subject_id']?.toString();
                final tId = grp['teacher_id']?.toString();
                fallbackRows.add({
                  'source_type': 'schedule',
                  'schedule_id': sch['id'],
                  'group_id': gId,
                  'group_name': grp['name'] ?? 'مجموعة دراسية',
                  'subject_name': subjectNames[subId] ?? 'حصة دراسية',
                  'teacher_name': teacherNames[tId] ?? 'معلم المادة',
                  'day_of_week': sch['day_of_week'],
                  'start_time': sch['start_time'],
                  'end_time': sch['end_time'],
                  'status': sch['status'] ?? 'active',
                  'location': sch['location'] ?? sch['room_location'] ?? 'القاعة الرئيسية',
                });
              }
            } catch (_) {}

            rows = fallbackRows;
          }
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

      // Sort lists logically
      todaySchedule.sort((a, b) => a.time.compareTo(b.time));
      upcomingSchedule.sort((a, b) => (a.date ?? DateTime(2099)).compareTo(b.date ?? DateTime(2099)));
      const dayOrder = {
        'السبت': 1,
        'الأحد': 2,
        'الإثنين': 3,
        'الثلاثاء': 4,
        'الأربعاء': 5,
        'الخميس': 6,
        'الجمعة': 7,
      };
      weeklySchedule.sort((a, b) {
        final aDay = dayOrder[a.dayName] ?? 99;
        final bDay = dayOrder[b.dayName] ?? 99;
        final cmp = aDay.compareTo(bDay);
        if (cmp != 0) return cmp;
        return a.time.compareTo(b.time);
      });

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
