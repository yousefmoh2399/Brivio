import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/tokens/colors.dart';

class ReceptionLiveTvKioskScreen extends StatefulWidget {
  final String centerName;

  const ReceptionLiveTvKioskScreen({
    super.key,
    this.centerName = 'المركز التعليمي',
  });

  @override
  State<ReceptionLiveTvKioskScreen> createState() => _ReceptionLiveTvKioskScreenState();
}

class _ReceptionLiveTvKioskScreenState extends State<ReceptionLiveTvKioskScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  List<Map<String, dynamic>> _liveSessions = [];
  List<Map<String, dynamic>> _hallOfFameStudents = [];
  bool _isLoadingSessions = false;
  bool _isLoadingHallOfFame = false;

  String _resolvedCenterName = '';

  @override
  void initState() {
    super.initState();
    _resolvedCenterName = widget.centerName;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
    _fetchCenterName();
    _fetchLiveSessions();
    _fetchHallOfFame();
  }

  Future<void> _fetchCenterName() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final prof = await client
            .from('profiles')
            .select('center_id')
            .eq('id', user.id)
            .maybeSingle();
        final cId = prof?['center_id'];
        if (cId != null) {
          final cRes = await client
              .from('educational_centers')
              .select('name')
              .eq('id', cId)
              .maybeSingle();
          final name = cRes?['name'] as String?;
          if (name != null && name.trim().isNotEmpty && mounted) {
            setState(() => _resolvedCenterName = name.trim());
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchLiveSessions() async {
    setState(() => _isLoadingSessions = true);
    try {
      final client = Supabase.instance.client;
      final List<Map<String, dynamic>> sessions = [];

      // 1. Try fetching from schedules table
      try {
        final res = await client
            .from('schedules')
            .select('*, groups(name, subject, teachers(profiles(full_name))), rooms(name)')
            .limit(20);

        for (final item in (res as List)) {
          final grp = item['groups'] as Map<String, dynamic>?;
          final room = item['rooms'] as Map<String, dynamic>?;
          final tchr = grp?['teachers'] as Map<String, dynamic>?;
          final prof = tchr?['profiles'] as Map<String, dynamic>?;

          final hallName = room?['name'] as String? ?? 'قاعة عامة';
          final subjectName = grp?['name'] as String? ?? grp?['subject'] as String? ?? 'حصة دراسية';
          final teacherName = prof?['full_name'] as String? ?? 'معلم المادة';
          final startTime = item['start_time'] as String? ?? '';
          final endTime = item['end_time'] as String? ?? '';
          final timeStr = (startTime.isNotEmpty && endTime.isNotEmpty) ? '$startTime - $endTime' : 'مجدولة';

          sessions.add({
            'hall': hallName,
            'subject': subjectName,
            'teacher': teacherName,
            'time': timeStr,
            'status': 'مجدولة ⚪',
            'status_color': Colors.blueGrey,
          });
        }
      } catch (_) {}

      // 2. If schedules is empty, query class_sessions for today
      if (sessions.isEmpty) {
        try {
          final todayStr = DateTime.now().toIso8601String().split('T').first;
          final classSessionsRes = await client
              .from('class_sessions')
              .select('id, scheduled_start_at, scheduled_end_at, status, location, groups(name, subject, teachers(profiles(full_name)))')
              .eq('session_date', todayStr);

          for (final item in (classSessionsRes as List)) {
            final grp = item['groups'] as Map<String, dynamic>?;
            final tchr = grp?['teachers'] as Map<String, dynamic>?;
            final prof = tchr?['profiles'] as Map<String, dynamic>?;

            final hallName = (item['location'] as String?)?.isNotEmpty == true
                ? (item['location'] as String)
                : 'قاعة المحاضرات';
            final subjectName = grp?['name'] as String? ?? grp?['subject'] as String? ?? 'حصة دراسية';
            final teacherName = prof?['full_name'] as String? ?? 'معلم المادة';
            final start = DateTime.tryParse(item['scheduled_start_at']?.toString() ?? '')?.toLocal();
            final end = DateTime.tryParse(item['scheduled_end_at']?.toString() ?? '')?.toLocal();
            final timeStr = (start != null && end != null)
                ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
                : 'اليوم';
            final statusStr = item['status']?.toString().toLowerCase() ?? '';
            final isLive = statusStr == 'in_progress' || statusStr == 'active' || statusStr == 'live';

            sessions.add({
              'hall': hallName,
              'subject': subjectName,
              'teacher': teacherName,
              'time': timeStr,
              'status': isLive ? 'حصة جارية 🟢' : 'مجدولة ⚪',
              'status_color': isLive ? Colors.green : Colors.blueGrey,
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _liveSessions = sessions);
      }
    } catch (_) {
      // Keep empty if table or relations not set
    } finally {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  Future<void> _fetchHallOfFame() async {
    setState(() => _isLoadingHallOfFame = true);
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('exam_submissions')
          .select('score, students(student_code, profiles(full_name)), exams(title, total_marks)')
          .order('score', ascending: false)
          .limit(10);

      final List<Map<String, dynamic>> top = [];
      int rank = 1;
      for (final item in (res as List)) {
        final stu = item['students'] as Map<String, dynamic>?;
        final prof = stu?['profiles'] as Map<String, dynamic>?;
        final exam = item['exams'] as Map<String, dynamic>?;
        final name = prof?['full_name'] as String? ?? 'طالب متميز';
        final scoreVal = item['score'];
        final totalVal = exam?['total_marks'] ?? 20;

        String badge = 'وسام التميز 🌟';
        if (rank == 1) badge = 'المركز الأول 🥇';
        if (rank == 2) badge = 'المركز الثاني 🥈';
        if (rank == 3) badge = 'المركز الثالث 🥉';

        top.add({
          'rank': rank++,
          'name': name,
          'group': exam?['title'] as String? ?? 'اختبار عام',
          'score': '$scoreVal / $totalVal',
          'badge': badge,
          'attendance': 'متفوق ⭐',
        });
      }
      if (mounted) {
        setState(() => _hallOfFameStudents = top);
      }
    } catch (_) {
      // Keep empty if table or submissions not set
    } finally {
      if (mounted) setState(() => _isLoadingHallOfFame = false);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime() {
    final h = _currentTime.hour.toString().padLeft(2, '0');
    final m = _currentTime.minute.toString().padLeft(2, '0');
    final s = _currentTime.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDate() {
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final dayName = days[_currentTime.weekday % 7];
    final monthName = months[_currentTime.month - 1];
    return '$dayName، ${_currentTime.day} $monthName ${_currentTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        final hallsPane = _buildHallsSchedulePane();
        final hallOfFamePane = _buildHallOfFamePane();

        Widget mainBody;
        if (isNarrow) {
          mainBody = Expanded(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const TabBar(
                    indicatorColor: AppColors.primary,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    tabs: [
                      Tab(
                        icon: Icon(Icons.meeting_room_rounded),
                        text: 'جدول الحصص والقاعات 🏛️',
                      ),
                      Tab(
                        icon: Icon(Icons.emoji_events_rounded),
                        text: 'لوحة الشرف 🏆',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TabBarView(
                      children: [
                        hallsPane,
                        hallOfFamePane,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          mainBody = Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: hallsPane,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 4,
                    child: hallOfFamePane,
                  ),
                ],
              ),
            ),
          );
        }

        final scaffold = Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(isNarrow),
                mainBody,

                // Bottom Center Announcement Marquee
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: AppColors.primary.withValues(alpha: 0.2),
                  child: const Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: Colors.amberAccent, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تنبيه هام لأولياء الأمور والطلاب: يرجى إبراز كود الـ QR عند بوابة الدخول لتسجيل الحضور وسداد المصاريف كاش بالخزينة. تتمنى إدارة السنتر لأبنائنا الطلاب عاماً دراسياً حافلاً بالتفوق والنجاح دائماً 🌟',
                          style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        if (isNarrow) {
          return DefaultTabController(
            length: 2,
            child: scaffold,
          );
        }
        return scaffold;
      },
    );
  }

  Widget _buildHeader(bool isNarrow) {
    if (isNarrow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resolvedCenterName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'شاشة الاستقبال والعرض المباشر',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق شاشة العرض',
                  icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, color: Colors.amberAccent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resolvedCenterName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'شاشة الاستقبال والعرض المباشر للقاعات والأنشطة',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.amberAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amberAccent, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _formatDate(),
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              IconButton(
                tooltip: 'إغلاق شاشة العرض',
                icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHallsSchedulePane() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'جدول الحصص الجارية والقادمة بالقاعات 🏛️',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isLoadingSessions)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _liveSessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد حصص مجدولة حالياً',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'سيتم عرض جدول الحصص هنا بمجرد تسجيل الجداول والقاعات في السنتر.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _liveSessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = _liveSessions[i];
                      final col = s['status_color'] as Color;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: col.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s['hall'],
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: col),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['subject'],
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'المحاضر: ${s['teacher']}',
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s['status'],
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s['time'],
                                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHallOfFamePane() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'لوحة شرف أوائل السنتر 🏆',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isLoadingHallOfFame)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _hallOfFameStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد نتائج اختبارات معتمدة بعد',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'سيتم تتويج وتكريم أوائل المجموعات والاختبارات فور تسجيل الدرجات.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _hallOfFameStudents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final st = _hallOfFameStudents[i];
                      final rank = st['rank'] as int;

                      Color rankColor;
                      if (rank == 1) {
                        rankColor = Colors.amber;
                      } else if (rank == 2) {
                        rankColor = const Color(0xFFE2E8F0);
                      } else if (rank == 3) {
                        rankColor = Colors.brown.shade300;
                      } else {
                        rankColor = Colors.tealAccent;
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: rankColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: rankColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$rank',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: rankColor, fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    st['name'],
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${st['group']} • ${st['attendance']}',
                                    style: const TextStyle(fontSize: 10.5, color: Colors.white60),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: rankColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                st['score'],
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rankColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
