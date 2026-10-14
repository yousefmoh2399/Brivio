import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';

class ReceptionLiveTvKioskScreen extends StatefulWidget {
  final String centerName;

  const ReceptionLiveTvKioskScreen({
    super.key,
    this.centerName = 'سنتر الأوائل التعليمي',
  });

  @override
  State<ReceptionLiveTvKioskScreen> createState() => _ReceptionLiveTvKioskScreenState();
}

class _ReceptionLiveTvKioskScreenState extends State<ReceptionLiveTvKioskScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  final List<Map<String, dynamic>> _liveSessions = [
    {
      'hall': 'قاعة 1 (المسرح الكبير)',
      'subject': 'فيزياء ثانوية عامة (لغات)',
      'teacher': 'أ. محمد عبد الله',
      'time': '10:00 ص - 12:00 م',
      'status': 'جارية الآن 🟢',
      'status_color': Colors.green,
    },
    {
      'hall': 'قاعة 2 (مدرج المتفوقين)',
      'subject': 'رياضيات بحتة وتفاضل',
      'teacher': 'أ. أحمد الشناوي',
      'time': '10:30 ص - 12:30 م',
      'status': 'جارية الآن 🟢',
      'status_color': Colors.green,
    },
    {
      'hall': 'قاعة 3 (معمل اللغات)',
      'subject': 'لغة إنجليزية - مراجعة عامة',
      'teacher': 'Miss Sarah Smith',
      'time': '12:00 م - 02:00 م',
      'status': 'تبدأ خلال 15 دقيقة 🟡',
      'status_color': Colors.amber,
    },
    {
      'hall': 'قاعة 4 (القاعة الكبرى)',
      'subject': 'كيمياء عضوية وتطبيقات',
      'teacher': 'أ. محمود رضوان',
      'time': '02:00 م - 04:00 م',
      'status': 'قادمة ⚪',
      'status_color': Colors.blueGrey,
    },
  ];

  final List<Map<String, dynamic>> _hallOfFameStudents = [
    {
      'rank': 1,
      'name': 'عمر أحمد محمود',
      'group': 'ثانوية عامة لغات A',
      'score': '20.0 / 20.0',
      'badge': 'المركز الأول 🥇',
      'attendance': '100% حضور',
    },
    {
      'rank': 2,
      'name': 'سارة إبراهيم مصطفى',
      'group': 'ثانوية عامة لغات A',
      'score': '19.5 / 20.0',
      'badge': 'المركز الثاني 🥈',
      'attendance': '100% حضور',
    },
    {
      'rank': 3,
      'name': 'يوسف خالد منصور',
      'group': 'ثانوية عامة عربي B',
      'score': '19.0 / 20.0',
      'badge': 'المركز الثالث 🥉',
      'attendance': '98% حضور',
    },
    {
      'rank': 4,
      'name': 'نوران محمد عبد العزيز',
      'group': 'أولى ثانوي لغات',
      'score': '19.0 / 20.0',
      'badge': 'وسام الامتياز 🌟',
      'attendance': '100% حضور',
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateTime.now());
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Slate
      body: SafeArea(
        child: Column(
          children: [
            // Top Live Kiosk Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.centerName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const Text(
                            'شاشة الاستقبال والعرض المباشر للقاعات والأنشطة',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
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
            ),

            // Main Display Body (2 Columns)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Column 1: Live Halls Schedule
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'جدول الحصص الجارية والقادمة بالقاعات 🏛️',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _liveSessions.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final s = _liveSessions[i];
                                  final col = s['status_color'] as Color;

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: col.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: col.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                s['hall'],
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: col),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s['subject'],
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'المحاضر: ${s['teacher']}',
                                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: col.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                s['status'],
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: col),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              s['time'],
                                              style: const TextStyle(fontSize: 12, color: Colors.white60),
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
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Column 2: Hall of Fame / Leaderboard
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'لوحة شرف أوائل السنتر 🏆',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: ListView.separated(
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
                                              ),
                                              Text(
                                                '${st['group']} • ${st['attendance']}',
                                                style: const TextStyle(fontSize: 10.5, color: Colors.white60),
                                              ),
                                            ],
                                          ),
                                        ),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
  }
}
