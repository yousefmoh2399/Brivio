import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class StudentTimetableWidget extends StatefulWidget {
  final VoidCallback? onViewFullSchedule;

  const StudentTimetableWidget({
    super.key,
    this.onViewFullSchedule,
  });

  @override
  State<StudentTimetableWidget> createState() => _StudentTimetableWidgetState();
}

class _StudentTimetableWidgetState extends State<StudentTimetableWidget> {
  int _selectedDayIndex = 0; // 0 = السبت, etc.

  final List<String> _daysOfWeek = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];

  final Map<int, List<Map<String, dynamic>>> _weeklySchedule = {
    0: [
      {
        'subject': 'فيزياء ثانوية عامة',
        'teacher': 'أ. محمد عبد الله',
        'hall': 'قاعة 1 (المسرح الكبير)',
        'time': '10:00 ص - 12:00 م',
        'is_next': true,
        'countdown': 'تبدأ بعد ساعة و20 دقيقة ⏰',
      },
      {
        'subject': 'كيمياء عضوية',
        'teacher': 'أ. محمود رضوان',
        'hall': 'قاعة 3 (المعمل)',
        'time': '02:00 م - 04:00 م',
        'is_next': false,
      },
    ],
    1: [
      {
        'subject': 'لغة عربية (نحو وبلاغة)',
        'teacher': 'أ. طارق عبد العزيز',
        'hall': 'قاعة 2 (الدور الثاني)',
        'time': '11:00 ص - 01:00 م',
        'is_next': false,
      },
    ],
    2: [
      {
        'subject': 'رياضيات (تفاضل وتكامل)',
        'teacher': 'أ. أحمد الشناوي',
        'hall': 'قاعة 1 (المسرح الكبير)',
        'time': '04:00 م - 06:00 م',
        'is_next': false,
      },
    ],
    3: [
      {
        'subject': 'لغة إنجليزية',
        'teacher': 'Miss Sarah Smith',
        'hall': 'قاعة 4 (لغات)',
        'time': '12:00 م - 02:00 م',
        'is_next': false,
      },
    ],
    4: [
      {
        'subject': 'مراجعة فيزياء وحل شيتات',
        'teacher': 'أ. محمد عبد الله',
        'hall': 'قاعة 2',
        'time': '01:00 م - 03:00 م',
        'is_next': false,
      },
    ],
    5: [],
    6: [],
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final todaySessions = _weeklySchedule[_selectedDayIndex] ?? [];
    final nextSession = _weeklySchedule[0]?.firstWhere((s) => s['is_next'] == true, orElse: () => {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Featured Upcoming Class Card
        if (nextSession != null && nextSession.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  Colors.blue.shade900,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        nextSession['countdown'] ?? 'الحصة القادمة اليوم',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  nextSession['subject'] ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'المدرس: ${nextSession['teacher']}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.meeting_room_outlined, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          nextSession['hall'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          nextSession['time'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Weekly Day Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'جدول الحصص الأسبوعي 🗓️',
              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
            if (widget.onViewFullSchedule != null)
              TextButton(
                onPressed: widget.onViewFullSchedule,
                child: const Text('عرض الكل'),
              ),
          ],
        ),
        const SizedBox(height: 10),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_daysOfWeek.length, (i) {
              final isSelected = _selectedDayIndex == i;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(_daysOfWeek[i]),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedDayIndex = i);
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // Classes for selected day
        if (todaySessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Center(
              child: Text(
                'لا توجد حصص مجدولة في هذا اليوم 🎉',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ...todaySessions.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session['subject'] ?? '',
                            style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الأستاذ: ${session['teacher']}',
                            style: AppTypography.caption(textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(session['hall'] ?? '', style: TextStyle(fontSize: 11, color: textSecondary)),
                              const SizedBox(width: 12),
                              Icon(Icons.schedule_rounded, size: 14, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(session['time'] ?? '', style: TextStyle(fontSize: 11, color: textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
