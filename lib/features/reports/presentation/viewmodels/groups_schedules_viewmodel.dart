import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupsSchedulesViewModel extends ChangeNotifier {
  final String? teacherId;

  GroupsSchedulesViewModel({this.teacherId});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> _groupsData = [];
  List<Map<String, dynamic>> get groupsData => _groupsData;

  Future<void> fetchGroupsData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      final currentUserId = currentUser?.id;

      // ───────────────────────────────────────────────────────────────────────
      // 1. Resolve Effective Teacher Record ID & Profile ID
      // ───────────────────────────────────────────────────────────────────────
      String? resolvedTeacherId;
      String? resolvedProfileId = currentUserId;

      final inputId = (teacherId != null && teacherId != 'null' && teacherId!.trim().isNotEmpty)
          ? teacherId!.trim()
          : null;

      // Try reading bootstrap RPC (returns exact teacher_id for the logged in user)
      if (currentUser != null) {
        try {
          final boot = await client.rpc('get_current_user_bootstrap');
          if (boot is Map && boot['teacher_id'] != null) {
            resolvedTeacherId = boot['teacher_id']?.toString();
          }
        } catch (_) {}
      }

      // If inputId was passed, check whether it is a teachers.id or profiles.id
      if (inputId != null) {
        try {
          final tMatch = await client
              .from('teachers')
              .select('id, profile_id')
              .or('id.eq.$inputId,profile_id.eq.$inputId')
              .maybeSingle();
          if (tMatch != null) {
            resolvedTeacherId = tMatch['id']?.toString() ?? inputId;
            resolvedProfileId = tMatch['profile_id']?.toString() ?? resolvedProfileId;
          } else {
            resolvedTeacherId ??= inputId;
          }
        } catch (_) {
          resolvedTeacherId ??= inputId;
        }
      }

      // If resolvedTeacherId is still null, look up teachers table for current user
      if (resolvedTeacherId == null && currentUserId != null) {
        try {
          final tRow = await client
              .from('teachers')
              .select('id, profile_id')
              .or('profile_id.eq.$currentUserId,id.eq.$currentUserId')
              .maybeSingle();
          if (tRow != null) {
            resolvedTeacherId = tRow['id']?.toString();
            resolvedProfileId = tRow['profile_id']?.toString() ?? resolvedProfileId;
          }
        } catch (_) {
          // Fallback check user_id column
          try {
            final tRow2 = await client
                .from('teachers')
                .select('id')
                .eq('user_id', currentUserId)
                .maybeSingle();
            if (tRow2 != null && tRow2['id'] != null) {
              resolvedTeacherId = tRow2['id'].toString();
            }
          } catch (_) {}
        }
      }

      // ───────────────────────────────────────────────────────────────────────
      // 2. Fetch Groups (Multi-Tier Resilient Strategy)
      // ───────────────────────────────────────────────────────────────────────
      List<Map<String, dynamic>> rawGroups = [];

      // Tier 1: RPC get_teacher_assigned_groups using teachers.id
      if (resolvedTeacherId != null && resolvedTeacherId.isNotEmpty) {
        try {
          final rpcRes = await client.rpc(
            'get_teacher_assigned_groups',
            params: {'p_teacher_id': resolvedTeacherId},
          );
          if (rpcRes is List && rpcRes.isNotEmpty) {
            rawGroups = rpcRes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (e) {
          debugPrint('GroupsSchedulesViewModel: RPC with teacherId note: $e');
        }
      }

      // Tier 1b: RPC get_teacher_assigned_groups using profileId fallback
      if (rawGroups.isEmpty && resolvedProfileId != null && resolvedProfileId != resolvedTeacherId) {
        try {
          final rpcRes = await client.rpc(
            'get_teacher_assigned_groups',
            params: {'p_teacher_id': resolvedProfileId},
          );
          if (rpcRes is List && rpcRes.isNotEmpty) {
            rawGroups = rpcRes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (e) {
          debugPrint('GroupsSchedulesViewModel: RPC with profileId note: $e');
        }
      }

      // Tier 2: Direct query on groups filtered by teacher
      if (rawGroups.isEmpty) {
        try {
          var query = client.from('groups').select('*');
          if (resolvedTeacherId != null && resolvedProfileId != null && resolvedTeacherId != resolvedProfileId) {
            query = query.or('teacher_id.eq.$resolvedTeacherId,teacher_id.eq.$resolvedProfileId');
          } else if (resolvedTeacherId != null) {
            query = query.eq('teacher_id', resolvedTeacherId);
          } else if (resolvedProfileId != null) {
            query = query.eq('teacher_id', resolvedProfileId);
          }
          final res = await query.order('name');
          if (res.isNotEmpty) {
            rawGroups = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (e) {
          debugPrint('GroupsSchedulesViewModel: Direct query with teacher filter note: $e');
        }
      }

      // Tier 3: Check group_teachers link table
      if (rawGroups.isEmpty) {
        final teacherKeys = [
          if (resolvedTeacherId != null) resolvedTeacherId,
          if (resolvedProfileId != null) resolvedProfileId,
        ];
        if (teacherKeys.isNotEmpty) {
          try {
            final gtRes = await client
                .from('group_teachers')
                .select('group_id')
                .inFilter('teacher_id', teacherKeys);
            if (gtRes.isNotEmpty) {
              final gIds = gtRes
                  .map((r) => r['group_id']?.toString())
                  .whereType<String>()
                  .where((id) => id.isNotEmpty)
                  .toList();
              if (gIds.isNotEmpty) {
                final gRes = await client.from('groups').select('*').inFilter('id', gIds).order('name');
                if (gRes.isNotEmpty) {
                  rawGroups = gRes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                }
              }
            }
          } catch (e) {
            debugPrint('GroupsSchedulesViewModel: group_teachers check note: $e');
          }
        }
      }

      // Tier 4: Fetch all groups accessible to the user (e.g. Admin or center-wide fallback)
      if (rawGroups.isEmpty) {
        try {
          final res = await client.from('groups').select('*').order('name');
          if (res.isNotEmpty) {
            rawGroups = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (e) {
          debugPrint('GroupsSchedulesViewModel: Fallback all groups query note: $e');
        }
      }

      // ───────────────────────────────────────────────────────────────────────
      // 3. Batch Fetch Schedules for all retrieved groups
      // ───────────────────────────────────────────────────────────────────────
      final groupIds = rawGroups
          .map((g) => g['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final Map<String, List<Map<String, dynamic>>> groupSchedulesMap = {};

      // First check if any groups payload already contains embedded schedules
      for (final g in rawGroups) {
        final gid = g['id']?.toString();
        if (gid != null && g['schedules'] is List && (g['schedules'] as List).isNotEmpty) {
          final list = (g['schedules'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          groupSchedulesMap[gid] = list;
        }
      }

      if (groupIds.isNotEmpty) {
        // Fetch all schedules for these groups in a single clean query
        try {
          final sRes = await client
              .from('schedules')
              .select('*')
              .inFilter('group_id', groupIds);
          for (final row in sRes) {
            final m = Map<String, dynamic>.from(row as Map);
            final gid = m['group_id']?.toString();
            if (gid != null) {
              groupSchedulesMap.putIfAbsent(gid, () => []).add(m);
            }
          }
        } catch (e) {
          debugPrint('GroupsSchedulesViewModel: Batch schedules select error, trying per-group: $e');
          for (final gid in groupIds) {
            if (groupSchedulesMap.containsKey(gid)) continue;
            try {
              final singleS = await client
                  .from('schedules')
                  .select('*')
                  .eq('group_id', gid);
              if (singleS.isNotEmpty) {
                groupSchedulesMap[gid] = singleS
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
              }
            } catch (_) {}
          }
        }
      }

      // ───────────────────────────────────────────────────────────────────────
      // 4. Batch Fetch Rooms (if room_id or rooms exist)
      // ───────────────────────────────────────────────────────────────────────
      final Set<String> roomIds = {};
      for (final sList in groupSchedulesMap.values) {
        for (final s in sList) {
          final rId = s['room_id']?.toString();
          if (rId != null && rId.isNotEmpty) roomIds.add(rId);
        }
      }

      final Map<String, String> roomNamesMap = {};
      if (roomIds.isNotEmpty) {
        try {
          final rRes = await client.from('rooms').select('id, name').inFilter('id', roomIds.toList());
          for (final r in rRes) {
            final m = Map<String, dynamic>.from(r as Map);
            final id = m['id']?.toString();
            final name = m['name']?.toString();
            if (id != null && name != null && name.isNotEmpty) {
              roomNamesMap[id] = name;
            }
          }
        } catch (_) {}
      }

      // ───────────────────────────────────────────────────────────────────────
      // 5. Batch Fetch Enrollment Counts (How many active students per group)
      // ───────────────────────────────────────────────────────────────────────
      final Map<String, int> enrollmentCountsMap = {};
      if (groupIds.isNotEmpty) {
        try {
          final enrollRes = await client
              .from('enrollments')
              .select('group_id')
              .inFilter('group_id', groupIds);
          for (final e in enrollRes) {
            final gid = e['group_id']?.toString();
            if (gid != null) {
              enrollmentCountsMap[gid] = (enrollmentCountsMap[gid] ?? 0) + 1;
            }
          }
        } catch (_) {
          // Link table student_groups fallback
          try {
            final sgRes = await client
                .from('student_groups')
                .select('group_id')
                .inFilter('group_id', groupIds);
            for (final e in sgRes) {
              final gid = e['group_id']?.toString();
              if (gid != null) {
                enrollmentCountsMap[gid] = (enrollmentCountsMap[gid] ?? 0) + 1;
              }
            }
          } catch (_) {}
        }
      }

      // ───────────────────────────────────────────────────────────────────────
      // 6. Batch Fetch Teacher Names
      // ───────────────────────────────────────────────────────────────────────
      final teacherIds = rawGroups
          .map((g) => g['teacher_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, String> teacherNamesMap = {};
      if (teacherIds.isNotEmpty) {
        try {
          final tRes = await client
              .from('teachers')
              .select('id, profile_id, profiles(full_name)')
              .inFilter('id', teacherIds);
          for (final t in tRes) {
            final m = Map<String, dynamic>.from(t as Map);
            final prof = m['profiles'] as Map<String, dynamic>?;
            final name = prof?['full_name']?.toString();
            if (name != null && name.isNotEmpty) {
              teacherNamesMap[m['id'].toString()] = name;
              if (m['profile_id'] != null) {
                teacherNamesMap[m['profile_id'].toString()] = name;
              }
            }
          }
        } catch (_) {}

        // Fallback directly from profiles table
        final missingIds = teacherIds.where((id) => !teacherNamesMap.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          try {
            final pRes = await client
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', missingIds);
            for (final p in pRes) {
              final m = Map<String, dynamic>.from(p as Map);
              final name = m['full_name']?.toString();
              if (name != null && name.isNotEmpty) {
                teacherNamesMap[m['id'].toString()] = name;
              }
            }
          } catch (_) {}
        }
      }

      // ───────────────────────────────────────────────────────────────────────
      // 7. Batch Fetch Subject Names
      // ───────────────────────────────────────────────────────────────────────
      final subjectIds = rawGroups
          .map((g) => g['subject_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, String> subjectNamesMap = {};
      if (subjectIds.isNotEmpty) {
        try {
          final subRes = await client
              .from('subjects')
              .select('id, name')
              .inFilter('id', subjectIds);
          for (final s in subRes) {
            final m = Map<String, dynamic>.from(s as Map);
            final name = m['name']?.toString();
            if (name != null && name.isNotEmpty) {
              subjectNamesMap[m['id'].toString()] = name;
            }
          }
        } catch (_) {}
      }

      // ───────────────────────────────────────────────────────────────────────
      // 8. Build the Final Output Records
      // ───────────────────────────────────────────────────────────────────────
      final List<Map<String, dynamic>> list = [];
      for (final item in rawGroups) {
        final gid = item['id']?.toString() ?? '';
        final groupName = item['name'] as String? ?? 'مجموعة دراسية';
        final tid = item['teacher_id']?.toString();
        final sid = item['subject_id']?.toString();

        final isCurrentTeacherGroup = (tid != null &&
            (tid == resolvedTeacherId || tid == resolvedProfileId || tid == currentUserId));

        final teacherName = (tid != null ? teacherNamesMap[tid] : null) ??
            (isCurrentTeacherGroup ? 'أنت (المعلم)' : (item['teacher_name']?.toString() ?? 'غير محدد'));

        final subjectName = (sid != null ? subjectNamesMap[sid] : null) ??
            item['subject']?.toString() ??
            item['subject_name']?.toString() ??
            '';

        final schedules = List<Map<String, dynamic>>.from(groupSchedulesMap[gid] ?? []);
        schedules.sort((a, b) {
          final da = parseDayIndex(a['day_of_week']);
          final db = parseDayIndex(b['day_of_week']);
          final dayComp = da.compareTo(db);
          if (dayComp != 0) return dayComp;
          final sa = a['start_time']?.toString() ?? '';
          final sb = b['start_time']?.toString() ?? '';
          return sa.compareTo(sb);
        });

        String timingStr = 'غير محدد الموعد';
        final List<String> sessionStrings = [];
        final List<Map<String, dynamic>> formattedSessions = [];

        for (final s in schedules) {
          final day = formatDayOfWeek(s['day_of_week']);
          final start = formatTime(s['start_time']);
          final end = formatTime(s['end_time']);

          // Resolve room name: roomNamesMap > room_location > location > rooms.name
          final rId = s['room_id']?.toString();
          String? loc = (rId != null && roomNamesMap.containsKey(rId))
              ? roomNamesMap[rId]
              : (s['room_location'] ?? s['location'])?.toString().trim();

          if (loc == null || loc.isEmpty) {
            final rObj = s['rooms'] as Map<String, dynamic>?;
            loc = rObj?['name']?.toString();
          }

          final locStr = (loc != null && loc.isNotEmpty) ? ' (قاعة: $loc)' : '';

          if (day.isNotEmpty && start.isNotEmpty && end.isNotEmpty) {
            sessionStrings.add('$day $start - $end$locStr');
            formattedSessions.add({
              'day': day,
              'start': start,
              'end': end,
              'location': loc ?? '',
            });
          } else if (day.isNotEmpty) {
            sessionStrings.add('$day$locStr');
            formattedSessions.add({
              'day': day,
              'start': start,
              'end': end,
              'location': loc ?? '',
            });
          }
        }

        if (sessionStrings.isNotEmpty) {
          timingStr = sessionStrings.join(' • ');
        }

        final enrolled = enrollmentCountsMap[gid] ??
            (item['student_count'] as num?)?.toInt() ??
            (item['enrolled_count'] as num?)?.toInt() ??
            0;

        final capacity = (item['capacity'] as num?)?.toInt() ??
            (item['max_capacity'] as num?)?.toInt() ??
            30;

        final statusStr = item['status']?.toString().toLowerCase();
        final isActive = statusStr == null || statusStr == 'active' || statusStr == 'true';

        list.add({
          'id': gid,
          'group_name': groupName,
          'timing': timingStr,
          'sessions': formattedSessions,
          'schedules_count': schedules.length,
          'teacher': teacherName,
          'subject': subjectName,
          'code': item['code']?.toString() ?? '',
          'capacity': capacity,
          'enrolled_count': enrolled,
          'is_active': isActive,
        });
      }

      _groupsData = list;
    } catch (e, stack) {
      debugPrint('GroupsSchedulesViewModel: fetchGroupsData error: $e\n$stack');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static int parseDayIndex(dynamic day) {
    if (day == null) return 99;
    final d = int.tryParse(day.toString());
    if (d != null) {
      // Order starting from Saturday: 6, 7/0, 1, 2, 3, 4, 5
      return switch (d) {
        6 => 0, // السبت
        7 || 0 => 1, // الأحد
        1 => 2, // الإثنين
        2 => 3, // الثلاثاء
        3 => 4, // الأربعاء
        4 => 5, // الخميس
        5 => 6, // الجمعة
        _ => d + 10,
      };
    }
    final s = day.toString().trim().toLowerCase();
    return switch (s) {
      'saturday' || 'sat' || 'السبت' => 0,
      'sunday' || 'sun' || 'الأحد' => 1,
      'monday' || 'mon' || 'الإثنين' => 2,
      'tuesday' || 'tue' || 'الثلاثاء' => 3,
      'wednesday' || 'wed' || 'الأربعاء' => 4,
      'thursday' || 'thu' || 'الخميس' => 5,
      'friday' || 'fri' || 'الجمعة' => 6,
      _ => 99,
    };
  }

  static String formatDayOfWeek(dynamic day) {
    if (day == null) return '';
    final d = int.tryParse(day.toString());
    if (d != null) {
      return switch (d) {
        6 => 'السبت',
        7 || 0 => 'الأحد',
        1 => 'الإثنين',
        2 => 'الثلاثاء',
        3 => 'الأربعاء',
        4 => 'الخميس',
        5 => 'الجمعة',
        _ => 'يوم $d',
      };
    }
    final s = day.toString().trim().toLowerCase();
    return switch (s) {
      'saturday' || 'sat' => 'السبت',
      'sunday' || 'sun' => 'الأحد',
      'monday' || 'mon' => 'الإثنين',
      'tuesday' || 'tue' => 'الثلاثاء',
      'wednesday' || 'wed' => 'الأربعاء',
      'thursday' || 'thu' => 'الخميس',
      'friday' || 'fri' => 'الجمعة',
      _ => day.toString().trim(),
    };
  }

  static String formatTime(dynamic timeStr) {
    if (timeStr == null) return '';
    final str = timeStr.toString().trim();
    if (str.isEmpty) return '';
    final parts = str.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final period = hour >= 12 ? 'م' : 'ص';
        final h12 = hour % 12 == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final mStr = minute.toString().padLeft(2, '0');
        return '$h12:$mStr $period';
      }
    }
    return str;
  }
}
