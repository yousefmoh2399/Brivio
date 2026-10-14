import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/auth/domain/models/user_profile.dart';
import '../teacher_dashboard.dart';
import '../../../features/code_playground/presentation/screens/code_playground_screen.dart';
import '../../../features/academy/presentation/widgets/center_switcher_widget.dart';
import '../../../features/attendance/presentation/screens/reception_qr_gate_screen.dart';
import '../../../features/payments/presentation/screens/teacher_settlement_screen.dart';
import '../../../features/reports/presentation/screens/attendance_reports_screen.dart';
import '../../../features/academy/presentation/widgets/join_center_dialog.dart';

class HomeTab extends StatelessWidget {
  final UserProfile? user;
  final bool isLoading;
  final String? errorMessage;
  final int assignedGroupsCount;
  final int openHomeworkCount;
  final int publishedExamsCount;
  final int gradingQueueCount;
  final int todaySessionsCount;
  final int savedBoardCount;
  final List<TeacherGroupAnalytics> groupAnalytics;
  final VoidCallback onRetry;
  final ValueChanged<int> onNavigate;

  const HomeTab({
    super.key,
    required this.user,
    required this.isLoading,
    this.errorMessage,
    required this.assignedGroupsCount,
    required this.openHomeworkCount,
    required this.publishedExamsCount,
    required this.gradingQueueCount,
    required this.todaySessionsCount,
    required this.savedBoardCount,
    required this.groupAnalytics,
    required this.onRetry,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          title: Text(
            context.tr('Teacher Portal'),
            style: AppTypography.displaySmall(
              textPrimary,
            ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_business_rounded),
              tooltip: 'الانضمام لسنتر جديد بكود',
              onPressed: () => JoinCenterDialog.show(context, onJoined: onRetry),
            ),
            CenterSwitcherWidget(onCenterChanged: onRetry),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRetry,
              tooltip: context.tr('Refresh'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        if (isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.teacherRole),
            ),
          )
        else if (errorMessage != null)
          SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: PortalErrorBanner(
                message: errorMessage!,
                onRetry: onRetry,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    '${context.tr("Welcome")}, ${user?.fullName ?? "Educator"}',
                    style: AppTypography.titleLarge(textPrimary).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Metrics grid
                FadeInSlide(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 100),
                  child: PortalMetricGrid(
                    children: [
                      PortalMetricCard(
                        label: context.tr('Assigned Groups'),
                        value: '$assignedGroupsCount',
                        icon: Icons.groups_rounded,
                        accentColor: AppColors.teacherRole,
                        onTap: () => onNavigate(1),
                      ),
                      PortalMetricCard(
                        label: context.tr('Today Sessions'),
                        value: '$todaySessionsCount',
                        icon: Icons.today_rounded,
                        accentColor: AppColors.info,
                        onTap: () => onNavigate(1),
                      ),
                      PortalMetricCard(
                        label: context.tr('Open Homework'),
                        value: '$openHomeworkCount',
                        icon: Icons.assignment_rounded,
                        accentColor: AppColors.warning,
                        onTap: () => onNavigate(2),
                      ),
                      PortalMetricCard(
                        label: context.tr('To Grade'),
                        value: '$gradingQueueCount',
                        icon: Icons.grading_rounded,
                        accentColor: AppColors.error,
                        onTap: () => onNavigate(2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Code Playground Shortcut
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 150),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CodePlaygroundScreen(),
                        ),
                      );
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderColor: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.teacherRole.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.code,
                              color: AppColors.teacherRole,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code Playground',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleMedium(
                                    isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ).copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Test examples and preview visual execution for students',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'Open code playground',
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppColors.teacherRole,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Egyptian Center Quick Operations
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة السنتر والحصة السريعة',
                        style: AppTypography.titleLarge(textPrimary).copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 720;
                          final card1 = _TeacherQuickActionCard(
                            title: 'بوابة الحضور السريع',
                            subtitle: 'مسح QR وتحصيل المصاريف',
                            icon: Icons.qr_code_scanner_rounded,
                            color: AppColors.primary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReceptionQrGateScreen(),
                                ),
                              );
                            },
                          );
                          final card2 = _TeacherQuickActionCard(
                            title: 'تصفية أرباح الحصة',
                            subtitle: 'حساب نسبة المدرس والمصاريف',
                            icon: Icons.calculate_rounded,
                            color: AppColors.teacherRole,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TeacherSettlementScreen(),
                                ),
                              );
                            },
                          );
                          final card3 = _TeacherQuickActionCard(
                            title: 'كشف الحضور (PDF)',
                            subtitle: 'تصدير وطباعة كشوفات الغياب',
                            icon: Icons.print_rounded,
                            color: AppColors.staffRole,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AttendanceReportsScreen(),
                                ),
                              );
                            },
                          );
                          final card4 = _TeacherQuickActionCard(
                            title: 'انضمام لسنتر بكود',
                            subtitle: 'الربط مع سنتر آخر بسهولة',
                            icon: Icons.add_business_rounded,
                            color: AppColors.warning,
                            onTap: () {
                              JoinCenterDialog.show(context, onJoined: onRetry);
                            },
                          );

                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(child: card1),
                                const SizedBox(width: 12),
                                Expanded(child: card2),
                                const SizedBox(width: 12),
                                Expanded(child: card3),
                                const SizedBox(width: 12),
                                Expanded(child: card4),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: card1),
                                  const SizedBox(width: 12),
                                  Expanded(child: card2),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: card3),
                                  const SizedBox(width: 12),
                                  Expanded(child: card4),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    context.tr('Group Analytics'),
                    style: AppTypography.titleLarge(textPrimary).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (groupAnalytics.isEmpty)
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 300),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          context.tr('No group analytics available yet.'),
                          style: AppTypography.bodyMedium(
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  ...groupAnalytics.asMap().entries.map(
                    (e) => FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: Duration(milliseconds: 300 + (e.key * 100)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TeacherGroupAnalyticsCard(item: e.value),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
      ],
    ),
  ),
);
}
}

class _TeacherGroupAnalyticsCard extends StatelessWidget {
  final TeacherGroupAnalytics item;

  const _TeacherGroupAnalyticsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.teacherRole.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.teacherRole,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.groupName,
                      style: AppTypography.titleMedium(
                        textPrimary,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (item.groupCode.isNotEmpty) item.groupCode,
                        '${item.studentCount} ${context.tr("students")}',
                      ].join(' | '),
                      style: AppTypography.caption(
                        textSecondary,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PortalStatusChip(
                status: item.attendanceRate >= 85
                    ? 'healthy'
                    : item.attendanceRate >= 65
                    ? 'watch'
                    : 'risk',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AnalyticsMiniMetric(
                icon: Icons.event_available,
                label: context.tr('Attendance'),
                value: '${item.attendanceRate.toStringAsFixed(1)}%',
                color: AppColors.success,
              ),
              _AnalyticsMiniMetric(
                icon: Icons.cancel,
                label: context.tr('Absences'),
                value: item.absentCount.toString(),
                color: AppColors.error,
              ),
              _AnalyticsMiniMetric(
                icon: Icons.assignment_late,
                label: context.tr('Pending HW'),
                value: item.pendingHomeworkCount.toString(),
                color: AppColors.warning,
              ),
              _AnalyticsMiniMetric(
                icon: Icons.quiz,
                label: context.tr('Exam Avg'),
                value: '${item.averageExamScore.toStringAsFixed(1)}%',
                color: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsMiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AnalyticsMiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 40 - 32 - 16) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(color),
                ),
                Text(
                  value,
                  style: AppTypography.titleMedium(
                    color,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherQuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TeacherQuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall(
                        isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                        isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
