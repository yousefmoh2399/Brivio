import 'package:flutter/material.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../features/academy/presentation/screens/teacher_groups_screen.dart';
import '../../../features/academy/presentation/screens/teacher_schedule_screen.dart';
import '../../../features/curriculum/presentation/screens/teacher_curriculum_screen.dart';

class ClassesTab extends StatefulWidget {
  final String teacherId;
  final Widget? groupsScreen;
  final Widget? scheduleScreen;
  final Widget? curriculumScreen;

  const ClassesTab({
    super.key,
    required this.teacherId,
    this.groupsScreen,
    this.scheduleScreen,
    this.curriculumScreen,
  });

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    duration: const Duration(milliseconds: 350),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 420;
                        final isUltraCompact = constraints.maxWidth < 360;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.teacherRole.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.teacherRole.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.school_rounded,
                                          size: 13,
                                          color: AppColors.teacherRole,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'الأكاديمية والسنتر',
                                            style: TextStyle(
                                              fontSize: isUltraCompact ? 10 : 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.teacherRole,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'مزامنة فورية',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.greenAccent
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'إدارة المجموعات والحصص',
                              style: AppTypography.displaySmall(textPrimary)
                                  .copyWith(
                                    fontSize: isUltraCompact
                                        ? 18
                                        : (isCompact ? 20 : 23),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'متابعة المجموعات الأكاديمية، مواعيد الحصص، والمقررات الدراسية',
                              style: AppTypography.bodySmall(textSecondary)
                                  .copyWith(fontSize: isUltraCompact ? 11 : 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 80),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 360;
                        return Container(
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabCtrl,
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            isScrollable: isNarrow,
                            tabAlignment: isNarrow
                                ? TabAlignment.start
                                : TabAlignment.fill,
                            indicator: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            labelColor: AppColors.teacherRole,
                            unselectedLabelColor: textPrimary.withValues(
                              alpha: 0.6,
                            ),
                            labelStyle: TextStyle(
                              fontSize: isNarrow ? 11 : 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: isNarrow ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.groups_2_rounded, size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      'المجموعات',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 11 : 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'جدول الحصص',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 11 : 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.menu_book_rounded, size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      'المناهج والدروس',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 11 : 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  widget.groupsScreen ??
                      TeacherGroupsScreen(teacherId: widget.teacherId),
                  widget.scheduleScreen ??
                      TeacherScheduleScreen(teacherId: widget.teacherId),
                  widget.curriculumScreen ??
                      TeacherCurriculumScreen(teacherId: widget.teacherId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
