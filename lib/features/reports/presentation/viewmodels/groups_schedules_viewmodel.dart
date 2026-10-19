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

      // 1. Resolve Effective Teacher ID (if not provided, check if current user is a teacher)
      String? effectiveTeacherId = (teacherId != null && teacherId != 'null' && teacherId!.isNotEmpty)
          ? teacherId
          : null;

      if (effectiveTeacherId == null && currentUser != null) {
        try {
          final tRes = await client
              .from('teachers')
              .select('id')
              .eq('user_id', currentUser.id)
              .maybeSingle();
          if (tRes != null && tRes['id'] != null) {
            effectiveTeacherId = tRes['id'].toString();
          }
        } catch (_) {}
      }

      // 2. Fetch Groups (Tier 1: RPC for assigned groups, Tier 2: direct query)
      List<Map<String, dynamic>> rawGroups = [];

      if (effectiveTeacherId != null && effectiveTeacherId.isNotEmpty) {
        try {
          final rpcRes = await client.rpc(
            'get_teacher_assigned_groups',
            params: {'p_teacher_id': effectiveTeacherId},
          );
          if (rpcRes is List && rpcRes.isNotEmpty) {
            rawGroups = rpcRes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (e) {
          debugPrint('GroupsSchedulesViewModel: RPC get_teacher_assigned_groups note: $e');
        }
      }

      if (rawGroups.isEmpty) {
        try {
          var query = client.from('groups').select('id, name, code, status, teacher_id, subject_id, branch_id');
          if (effectiveTeacherId != null && effectiveTeacherId.isNotEmpty) {
            query = query.eq('teacher_id', effectiveTeacherId);
          }
          final res = await query.order('name');
          if (res.isNotEmpty) {
            rawGroups = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (e) {
          debugPrint('GroupsSchedulesViewModel: direct query note: $e');
          // Tier 3: Fetch all groups if teacher_id column failed or user is admin
          try {
            final res = await client.from('groups').select().order('name');
            if (res.isNotEmpty) {
              rawGroups = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
          } catch (e2) {
            debugPrint('GroupsSchedulesViewModel: fallback query note: $e2');
          }
        }
      }

      // Tier 4: Check group_teachers link table if still empty
      if (rawGroups.isEmpty && effectiveTeacherId != null) {
        try {
          final gtRes = await client
              .from('group_teachers')
              .select('group_id')
              .eq('teacher_id', effectiveTeacherId);
          if (gtRes.isNotEmpty) {
            final gIds = gtRes
                .map((r) => r['group_id']?.toString())
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toList();
            if (gIds.isNotEmpty) {
              final gRes = await client.from('groups').select().inFilter('id', gIds);
              if (gRes.isNotEmpty) {
                rawGroups = gRes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              }
            }
          }
        } catch (_) {}
      }

      // 3. Batch Fetch Schedules for all retrieved groups
      final groupIds = rawGroups
          .map((g) => g['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final Map<String, List<Map<String, dynamic>>> groupSchedulesMap = {};
      if (groupIds.isNotEmpty) {
        try {
          final sRes = await client
              .from('schedules')
              .select('id, group_id, day_of_week, start_time, end_time, location, room_location, status')
              .inFilter('group_id', groupIds);
          for (final row in sRes) {
            final m = Map<String, dynamic>.from(row as Map);
            final gid = m['group_id']?.toString();
            if (gid != null) {
              groupSchedulesMap.putIfAbsent(gid, () => []).add(m);
            }
          }
        } catch (e) {
          debugPrint('GroupsSchedulesViewModel: batch schedules note: $e');
          for (final gid in groupIds) {
            try {
              final singleS = await client
                  .from('schedules')
                  .select()
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

      // 4. Batch Fetch Teacher Names
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
              .select('id, profiles(full_name)')
              .inFilter('id', teacherIds);
          for (final t in tRes) {
            final m = Map<String, dynamic>.from(t as Map);
            final prof = m['profiles'] as Map<String, dynamic>?;
            final name = prof?['full_name']?.toString();
            if (name != null && name.isNotEmpty) {
              teacherNamesMap[m['id'].toString()] = name;
            }
          }
        } catch (_) {
          try {
            final pRes = await client
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', teacherIds);
            for (final p in pRes) {
              final m = Map<String, dynamic>.from(p as Map);
              final name = m['full_name']?.toString();
              if (name != null) {
                teacherNamesMap[m['id'].toString()] = name;
              }
            }
          } catch (_) {}
        }
      }

      // 5. Batch Fetch Subject Names
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

      // 6. Build the Final Output Records
      final List<Map<String, dynamic>> list = [];
      for (final item in rawGroups) {
        final gid = item['id']?.toString() ?? '';
        final groupName = item['name'] as String? ?? 'مجموعة بدون اسم';
        final tid = item['teacher_id']?.toString();
        final sid = item['subject_id']?.toString();
        final teacherName = (tid != null ? teacherNamesMap[tid] : null) ??
            (effectiveTeacherId != null ? 'أنت (المعلم)' : 'غير محدد');
        final subjectName = (sid != null ? subjectNamesMap[sid] : null) ??
            item['subject']?.toString() ??
            '';

        final schedules = groupSchedulesMap[gid] ?? [];
        schedules.sort((a, b) {
          final da = int.tryParse(a['day_of_week']?.toString() ?? '') ?? 0;
          final db = int.tryParse(b['day_of_week']?.toString() ?? '') ?? 0;
          return da.compareTo(db);
        });

        String timingStr = 'غير محدد الموعد';
        final List<String> sessionStrings = [];
        final List<Map<String, dynamic>> formattedSessions = [];

        for (final s in schedules) {
          final day = formatDayOfWeek(s['day_of_week']);
          final start = formatTime(s['start_time']);
          final end = formatTime(s['end_time']);
          final loc = (s['location'] ?? s['room_location'])?.toString().trim();
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

        list.add({
          'id': gid,
          'group_name': groupName,
          'timing': timingStr,
          'sessions': formattedSessions,
          'schedules_count': schedules.length,
          'teacher': teacherName,
          'subject': subjectName,
          'code': item['code']?.toString() ?? '',
          'capacity': item['capacity'] ?? item['max_capacity'] ?? 30,
          'is_active': item['status'] == 'active' || item['status'] == null,
        });
      }

      _groupsData = list;
    } catch (e) {
      debugPrint('GroupsSchedulesViewModel: fetchGroupsData error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String formatDayOfWeek(dynamic day) {
    if (day == null) return '';
    final d = int.tryParse(day.toString());
    if (d != null) {
      switch (d) {
        case 6:
          return 'السبت';
        case 7:
        case 0:
          return 'الأحد';
        case 1:
          return 'الإثنين';
        case 2:
          return 'الثلاثاء';
        case 3:
          return 'الأربعاء';
        case 4:
          return 'الخميس';
        case 5:
          return 'الجمعة';
        default:
          return 'يوم $d';
      }
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
