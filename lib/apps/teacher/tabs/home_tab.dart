import 'package:flutter/material.dart';
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
import '../../../features/attendance/presentation/screens/teacher_session_board_screen.dart';
import '../../../features/academy/presentation/widgets/join_center_dialog.dart';
import '../../../features/assessment/presentation/widgets/live_blitz_quiz_dialog.dart';
import '../../../features/communication/presentation/screens/class_broadcast_dialog.dart';
import '../../../features/assessment/presentation/widgets/smart_grading_studio.dart';
import '../../../features/attendance/presentation/screens/live_class_focus_mode_screen.dart';
import '../../../features/analytics/presentation/widgets/at_risk_students_card.dart';

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
            'بوابة المعلم',
            style: AppTypography.displaySmall(
              textPrimary,
            ).copyWith(fontWeight: FontWeight.w800, fontSize: 20),
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
              tooltip: 'تحديث',
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
                    'أهلاً بك، ${user?.fullName ?? "معلمنا الفاضل"}',
                    style: AppTypography.titleLarge(textPrimary).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Live Class Session Cockpit & Absence Alert Radar
                FadeInSlide(
                  duration: const Duration(milliseconds: 550),
                  delay: const Duration(milliseconds: 50),
                  child: _LiveSessionCockpitCard(
                    teacherId: user?.id ?? '',
                    teacherName: user?.fullName ?? 'معلمنا الفاضل',
                  ),
                ),
                const SizedBox(height: 20),

                // Metrics grid
                FadeInSlide(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 100),
                  child: PortalMetricGrid(
                    children: [
                      PortalMetricCard(
                        label: 'المجموعات المسندة',
                        value: '$assignedGroupsCount',
                        icon: Icons.groups_rounded,
                        accentColor: AppColors.teacherRole,
                        onTap: () => onNavigate(1),
                      ),
                      PortalMetricCard(
                        label: 'حصص اليوم',
                        value: '$todaySessionsCount',
                        icon: Icons.today_rounded,
                        accentColor: AppColors.info,
                        onTap: () => onNavigate(1),
                      ),
                      PortalMetricCard(
                        label: 'الواجبات الحالية',
                        value: '$openHomeworkCount',
                        icon: Icons.assignment_rounded,
                        accentColor: AppColors.warning,
                        onTap: () => onNavigate(2),
                      ),
                      PortalMetricCard(
                        label: 'بانتظار التصحيح',
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
                                const Text(
                                  'المختبر البرمجي التفاعلي',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'تجربة الأكواد البرمجية ومتابعة الشرح التفاعلي مع الطلاب',
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
                            message: 'فتح المختبر البرمجي',
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
                          final cardBoard = _TeacherQuickActionCard(
                            title: 'السبورة الذكية للشرح',
                            subtitle: 'شروحات حية، رسم وتصدير PDF',
                            icon: Icons.draw_rounded,
                            color: Colors.teal,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeacherSessionBoardScreen(
                                    teacherId: user?.id ?? '',
                                  ),
                                ),
                              );
                            },
                          );
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
                                Expanded(child: cardBoard),
                                const SizedBox(width: 12),
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
                                  Expanded(child: cardBoard),
                                  const SizedBox(width: 12),
                                  Expanded(child: card1),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: card2),
                                  const SizedBox(width: 12),
                                  Expanded(child: card3),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
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

                const SizedBox(height: 28),

                // At-Risk Students Alert & Predictive Academic Intervention Radar
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 190),
                  child: AtRiskStudentsAlertWidget(
                    teacherName: user?.fullName ?? 'معلمنا الفاضل',
                  ),
                ),

                const SizedBox(height: 32),

                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    'إحصائيات المجموعات الدراسية',
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
                          'لا توجد إحصائيات للمجموعات مسجلة حتى الآن.',
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
                        '${item.studentCount} طالب',
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
          LayoutBuilder(
            builder: (context, constraints) {
              final metricWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AnalyticsMiniMetric(
                    width: metricWidth,
                    icon: Icons.event_available,
                    label: 'نسبة الحضور',
                    value: '${item.attendanceRate.toStringAsFixed(1)}%',
                    color: AppColors.success,
                  ),
                  _AnalyticsMiniMetric(
                    width: metricWidth,
                    icon: Icons.cancel,
                    label: 'الغياب',
                    value: item.absentCount.toString(),
                    color: AppColors.error,
                  ),
                  _AnalyticsMiniMetric(
                    width: metricWidth,
                    icon: Icons.assignment_late,
                    label: 'واجبات لم تسلم',
                    value: item.pendingHomeworkCount.toString(),
                    color: AppColors.warning,
                  ),
                  _AnalyticsMiniMetric(
                    width: metricWidth,
                    icon: Icons.quiz,
                    label: 'متوسط الامتحانات',
                    value: '${item.averageExamScore.toStringAsFixed(1)}%',
                    color: AppColors.info,
                  ),
                ],
              );
            },
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
  final double? width;

  const _AnalyticsMiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? ((MediaQuery.sizeOf(context).width - 40 - 32 - 16) / 2),
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

class _LiveSessionCockpitCard extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const _LiveSessionCockpitCard({
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<_LiveSessionCockpitCard> createState() => _LiveSessionCockpitCardState();
}

class _LiveSessionCockpitCardState extends State<_LiveSessionCockpitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  final String _currentGroup = 'فيزياء 3 ثانوي - مجموعة التميز واللغات (A)';
  final String _roomName = 'قاعة نيوتن 1 (الفرع الرئيسي)';
  final int _totalEnrolled = 42;
  final int _presentCount = 38;
  final int _absentCount = 4;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openAbsenceBroadcastDialog() {
    showDialog(
      context: context,
      builder: (_) => _AbsenceAlertBroadcastDialog(
        groupName: _currentGroup,
        teacherName: widget.teacherName,
        absentStudents: const [
          {'name': 'عمر أحمد محمود', 'code': 'STU-101', 'phone': '01012345678'},
          {'name': 'مريم حسام الدين', 'code': 'STU-105', 'phone': '01198765432'},
          {'name': 'زياد طارق إبراهيم', 'code': 'STU-108', 'phone': '01234567890'},
          {'name': 'فاطمة خالد علي', 'code': 'STU-112', 'phone': '01055566778'},
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final attendancePercentage = (_presentCount / _totalEnrolled * 100).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFEEF2F6),
                ],
        ),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar: Live Beacon + Room + Time
          Row(
            children: [
              _CockpitPulseBeacon(controller: _pulseController),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'غرفة التحكم الحية للحصة المباشرة 🔴',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'جارية الآن ⏱️',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentGroup,
                      style: AppTypography.titleMedium(textPrimary).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text('04:00 - 06:00 م', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('مضى 42 دقيقة ⏳', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.meeting_room_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(_roomName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Live Attendance Gauge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF0D9488)),
                            const SizedBox(width: 6),
                            Text(
                              'الحضور المسجل حتى اللحظة:',
                              style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '$_presentCount من $_totalEnrolled طالب ($attendancePercentage%)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Two-Tone Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          children: [
                            Expanded(
                              flex: _presentCount,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: _absentCount,
                              child: Container(
                                color: Colors.redAccent.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dual Action Buttons: Live Class Focus Mode / Projector + Absence Alert
          Row(
            children: [
              Expanded(
                flex: 5,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.co_present_rounded, size: 20),
                  label: const Text(
                    'بدء وضع الحصة والبروجيكتور 📽️',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveClassFocusModeScreen(
                          teacherId: widget.teacherId,
                          teacherName: widget.teacherName,
                          groupName: _currentGroup,
                          roomName: _roomName,
                          totalStudents: _totalEnrolled,
                          initialPresent: _presentCount,
                          initialAbsent: _absentCount,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.campaign_rounded, size: 18),
                  label: Text(
                    'إنذار الغياب ($_absentCount) 🚨',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: _openAbsenceBroadcastDialog,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Classroom Quick Dock (Tools for active lecturing)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدوات التحكم التفاعلية أثناء الحصة المباشرة:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCockpitPill(
                      label: 'شاشة البروجيكتور 📽️',
                      color: const Color(0xFF0D9488),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveClassFocusModeScreen(
                              teacherId: widget.teacherId,
                              teacherName: widget.teacherName,
                              groupName: _currentGroup,
                              roomName: _roomName,
                              totalStudents: _totalEnrolled,
                              initialPresent: _presentCount,
                              initialAbsent: _absentCount,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildCockpitPill(
                      label: 'السبورة الذكية للشرح 🎨',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeacherSessionBoardScreen(teacherId: widget.teacherId),
                          ),
                        );
                      },
                    ),
                    _buildCockpitPill(
                      label: 'كويز الـ 5 دقائق التفاعلي ⚡',
                      color: Colors.purple,
                      onTap: () {
                        LiveBlitzQuizDialog.show(
                          context,
                          groupName: _currentGroup,
                          subjectName: 'الفيزياء',
                        );
                      },
                    ),
                    _buildCockpitPill(
                      label: 'استوديو التصحيح بالقلم ✍️',
                      color: Colors.deepOrange,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const SmartGradingStudioDialog(
                            studentName: 'عمر أحمد محمود',
                            submissionId: 'live_preview',
                            initialScore: 18.5,
                            maxScore: 20.0,
                            initialFeedback: 'ممتاز ومنظم يا بطل 🌟',
                          ),
                        );
                      },
                    ),
                    _buildCockpitPill(
                      label: 'مسح حضور QR السريع 🪪',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReceptionQrGateScreen()),
                        );
                      },
                    ),
                    _buildCockpitPill(
                      label: 'إذاعة تنبيه للقاعة 📢',
                      color: Colors.amber.shade800,
                      onTap: () {
                        ClassBroadcastDialog.show(
                          context,
                          groupName: _currentGroup,
                          teacherName: widget.teacherName,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitPill({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _CockpitPulseBeacon extends StatelessWidget {
  final AnimationController controller;

  const _CockpitPulseBeacon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + (controller.value * 0.25);
        final opacity = 0.8 - (controller.value * 0.4);
        return SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D9488).withValues(alpha: opacity),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0D9488),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF0D9488),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AbsenceAlertBroadcastDialog extends StatefulWidget {
  final String groupName;
  final String teacherName;
  final List<Map<String, String>> absentStudents;

  const _AbsenceAlertBroadcastDialog({
    required this.groupName,
    required this.teacherName,
    required this.absentStudents,
  });

  @override
  State<_AbsenceAlertBroadcastDialog> createState() => _AbsenceAlertBroadcastDialogState();
}

class _AbsenceAlertBroadcastDialogState extends State<_AbsenceAlertBroadcastDialog> {
  bool _sendAppNotification = true;
  bool _sendWhatsAppAlert = true;
  bool _isBroadcasting = false;

  Future<void> _broadcastAbsenceAlerts() async {
    setState(() => _isBroadcasting = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال إنذار الغياب الفوري لـ ${widget.absentStudents.length} أولياء أمور بنجاح عبر التطبيق والواتساب 📲',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: Colors.redAccent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إذاعة إنذار غياب فوري لأولياء الأمور 🚨',
                          style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.groupName,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Warning Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'سيتم إرسال إشعار فوري لأولياء أمور ${widget.absentStudents.length} طلاب متغيبين عن حصة اليوم الآن لتنبيههم فوراً واطمئنانهم.',
                        style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Absent Roster List
              Text(
                'قائمة الطلاب المتغيبين في الحصة الآن:',
                style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...widget.absentStudents.map((s) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_off_rounded, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 6),
                          Text('(${s['code']})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Text(s['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Message Preview Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'نص الرسالة المعتمد للتنبيه:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '🚨 تنبيه عاجل من إدارة السنتر: نحيط سيادتكم علماً بأن الطالب لم يسجل حضوره اليوم في حصة الفيزياء الجارية حالياً في تمام الساعة 04:00م. برجاء الاطمئنان عليه والتواصل معنا فوراً للضرورة.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Dispatch Channels
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _sendAppNotification,
                onChanged: (val) => setState(() => _sendAppNotification = val ?? true),
                title: const Text('إرسال إشعار لحظي عبر تطبيق ولي الأمر 📱', style: TextStyle(fontSize: 13)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _sendWhatsAppAlert,
                onChanged: (val) => setState(() => _sendWhatsAppAlert = val ?? true),
                title: const Text('إرسال رسالة واتساب رسمية من رقم السنتر 💬', style: TextStyle(fontSize: 13)),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isBroadcasting ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isBroadcasting ? null : _broadcastAbsenceAlerts,
                      icon: _isBroadcasting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isBroadcasting ? 'جارٍ إرسال التنبيهات...' : 'إرسال الإنذار للكل (${widget.absentStudents.length}) 🚀',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

