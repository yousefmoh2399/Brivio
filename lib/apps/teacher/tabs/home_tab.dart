import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
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
import '../../../features/assessment/presentation/screens/teacher_grading_screen.dart';
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
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: RefreshIndicator(
          onRefresh: () async => onRetry(),
          color: AppColors.teacherRole,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                titleSpacing: 16,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.teacherRole.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.teacherRole.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school_rounded, size: 16, color: AppColors.teacherRole),
                          const SizedBox(width: 6),
                          Text(
                            'بوابة التدريس والمتابعة',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.teacherRole,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: onRetry,
                    tooltip: 'تحديث البيانات',
                  ),
                  CenterSwitcherWidget(onCenterChanged: onRetry),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Executive Teacher Hero Card
                      FadeInSlide(
                        duration: const Duration(milliseconds: 400),
                        child: _buildTeacherHero(
                          context,
                          user: user,
                          assignedGroupsCount: assignedGroupsCount,
                          todaySessionsCount: todaySessionsCount,
                          gradingQueueCount: gradingQueueCount,
                          isDark: isDark,
                        ),
                      ),

                      // 2. Context-Aware Live Class Session Cockpit
                      FadeInSlide(
                        duration: const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 50),
                        child: _LiveSessionCockpitCard(
                          teacherId: user?.id ?? '',
                          teacherName: user?.fullName ?? 'معلمنا الفاضل',
                          groupAnalytics: groupAnalytics,
                          todaySessionsCount: todaySessionsCount,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Operational KPIs Grid
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
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
                              label: 'الواجبات والاختبارات',
                              value: '${openHomeworkCount + publishedExamsCount}',
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
                      const SizedBox(height: 20),

                      // 4. Unified Teaching Command Hub (8 distinct tools)
                      FadeInSlide(
                        duration: const Duration(milliseconds: 550),
                        delay: const Duration(milliseconds: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'مركز أدوات المعلم الذكية ⚡',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  '8 أدوات متكاملة',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _TeacherCommandHub(
                              teacherId: user?.id ?? '',
                              teacherName: user?.fullName ?? 'معلمنا الفاضل',
                              onRetry: onRetry,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. At-Risk Students Academic Intervention Radar
                      FadeInSlide(
                        duration: const Duration(milliseconds: 550),
                        delay: const Duration(milliseconds: 200),
                        child: AtRiskStudentsAlertWidget(
                          teacherName: user?.fullName ?? 'معلمنا الفاضل',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 6. Group Analytics Section
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 250),
                        child: Text(
                          'إحصائيات المجموعات الدراسية',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (groupAnalytics.isEmpty)
                        FadeInSlide(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 300),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'لا توجد إحصائيات للمجموعات مسجلة حتى الآن.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        ...groupAnalytics.asMap().entries.map(
                          (e) => FadeInSlide(
                            duration: const Duration(milliseconds: 600),
                            delay: Duration(milliseconds: 300 + (e.key * 80)),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
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
      ),
    );
  }

  Widget _buildTeacherHero(
    BuildContext context, {
    required UserProfile? user,
    required int assignedGroupsCount,
    required int todaySessionsCount,
    required int gradingQueueCount,
    required bool isDark,
  }) {
    final fullName = user?.fullName.trim();
    final name = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : 'معلمنا الفاضل';
    final initials = name.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0]).join();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? const [
                  Color(0xFF134E4A),
                  Color(0xFF0F172A),
                ]
              : const [
                  Color(0xFFF0FDFA),
                  Color(0xFFFFFFFF),
                ],
        ),
        border: Border.all(
          color: AppColors.teacherRole.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.teacherRole.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Teacher Avatar with active status indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : '👨‍🏫',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بك، $name 👨‍🏫',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'لوحة العمليات الأكاديمية والتدريس المباشر',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Glance Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : AppColors.teacherRole.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : AppColors.teacherRole.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGlanceItem(
                  icon: Icons.groups_rounded,
                  label: '$assignedGroupsCount مجموعات',
                  color: AppColors.teacherRole,
                  isDark: isDark,
                ),
                Container(width: 1, height: 14, color: isDark ? Colors.white12 : Colors.black12),
                _buildGlanceItem(
                  icon: Icons.event_available_rounded,
                  label: '$todaySessionsCount حصص اليوم',
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
                Container(width: 1, height: 14, color: isDark ? Colors.white12 : Colors.black12),
                _buildGlanceItem(
                  icon: Icons.rate_review_rounded,
                  label: '$gradingQueueCount للتصحيح',
                  color: gradingQueueCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlanceItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Unified Teaching Command Hub (8 distinct tools) ──
class _TeacherCommandHub extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final VoidCallback onRetry;

  const _TeacherCommandHub({
    required this.teacherId,
    required this.teacherName,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tools = [
      _TeacherToolItem(
        title: 'السبورة الذكية',
        subtitle: 'شروحات حية ورسم وتصدير',
        badge: 'مباشر 🎨',
        icon: Icons.draw_rounded,
        gradient: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
        borderAccent: const Color(0xFF14B8A6),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherSessionBoardScreen(teacherId: teacherId),
            ),
          );
        },
      ),
      _TeacherToolItem(
        title: 'استوديو التصحيح',
        subtitle: 'تصحيح الواجبات والاختبارات',
        badge: 'تصحيح ✍️',
        icon: Icons.rate_review_rounded,
        gradient: const [Color(0xFFEA580C), Color(0xFFF97316)],
        borderAccent: const Color(0xFFF97316),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('طابور التصحيح واستوديو القلم الرقمي ✍️'),
                  elevation: 0,
                ),
                body: TeacherGradingScreen(teacherId: teacherId),
              ),
            ),
          );
        },
      ),
      _TeacherToolItem(
        title: 'تصفية الأرباح',
        subtitle: 'حساب الحصص والمستحقات',
        badge: 'مالية 💰',
        icon: Icons.account_balance_wallet_rounded,
        gradient: const [Color(0xFF059669), Color(0xFF10B981)],
        borderAccent: const Color(0xFF10B981),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherSettlementScreen(),
            ),
          );
        },
      ),
      _TeacherToolItem(
        title: 'كشوفات الحضور',
        subtitle: 'طباعة وتصدير ملفات PDF',
        badge: 'تقارير 📄',
        icon: Icons.picture_as_pdf_rounded,
        gradient: const [Color(0xFF4338CA), Color(0xFF6366F1)],
        borderAccent: const Color(0xFF818CF8),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AttendanceReportsScreen(),
            ),
          );
        },
      ),
      _TeacherToolItem(
        title: 'بوابة الـ QR',
        subtitle: 'مسح وتسجيل حضور الطلاب',
        badge: 'تسجيل 🪪',
        icon: Icons.qr_code_scanner_rounded,
        gradient: const [Color(0xFF0891B2), Color(0xFF06B6D4)],
        borderAccent: const Color(0xFF06B6D4),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReceptionQrGateScreen(),
            ),
          );
        },
      ),
      _TeacherToolItem(
        title: 'كويز الـ 5 دقائق',
        subtitle: 'اختبار لحظي سريع وتنافسي',
        badge: 'تفاعلي ⚡',
        icon: Icons.bolt_rounded,
        gradient: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
        borderAccent: const Color(0xFFA855F7),
        onTap: () {
          HapticFeedback.lightImpact();
          LiveBlitzQuizDialog.show(
            context,
            groupName: 'كويز الحصة التفاعلي',
            subjectName: 'اختبار سريع',
            teacherId: teacherId,
          );
        },
      ),
      _TeacherToolItem(
        title: 'المختبر البرمجي',
        subtitle: 'تشغيل وتجربة الأكواد الحية',
        badge: 'أكواد 💻',
        icon: Icons.terminal_rounded,
        gradient: const [Color(0xFF334155), Color(0xFF475569)],
        borderAccent: const Color(0xFF64748B),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CodePlaygroundScreen(),
            ),
          );
        },
      ),
      _TeacherToolItem(
        title: 'ربط سنتر جديد',
        subtitle: 'إضافة سنتر تعليمي بكود ربط',
        badge: 'انضمام 🏫',
        icon: Icons.add_business_rounded,
        gradient: const [Color(0xFFD97706), Color(0xFFF59E0B)],
        borderAccent: const Color(0xFFFBBF24),
        onTap: () {
          HapticFeedback.lightImpact();
          JoinCenterDialog.show(context, onJoined: onRetry);
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final isMedium = constraints.maxWidth >= 480;
        final crossAxisCount = isWide ? 4 : (isMedium ? 3 : 2);
        final childAspectRatio = isWide ? 1.6 : (isMedium ? 1.45 : 1.35);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tools.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            return _TeacherToolCard(tool: tools[index], isDark: isDark);
          },
        );
      },
    );
  }
}

class _TeacherToolItem {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final List<Color> gradient;
  final Color borderAccent;
  final VoidCallback onTap;

  const _TeacherToolItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.borderAccent,
    required this.onTap,
  });
}

class _TeacherToolCard extends StatelessWidget {
  final _TeacherToolItem tool;
  final bool isDark;

  const _TeacherToolCard({
    required this.tool,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.9)
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tool.borderAccent.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: tool.borderAccent.withValues(alpha: isDark ? 0.10 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: tool.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: tool.gradient.first.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(tool.icon, color: Colors.white, size: 19),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tool.borderAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: tool.borderAccent.withValues(alpha: 0.3),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      tool.badge,
                      style: TextStyle(
                        color: tool.borderAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tool.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
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

// ── Context-Aware Live Session Cockpit ──
class _LiveSessionCockpitCard extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final List<TeacherGroupAnalytics> groupAnalytics;
  final int todaySessionsCount;

  const _LiveSessionCockpitCard({
    required this.teacherId,
    required this.teacherName,
    this.groupAnalytics = const [],
    this.todaySessionsCount = 0,
  });

  @override
  State<_LiveSessionCockpitCard> createState() => _LiveSessionCockpitCardState();
}

class _LiveSessionCockpitCardState extends State<_LiveSessionCockpitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  String _currentGroup = '';
  String? _currentGroupId;
  String? _currentSessionId;
  String _roomName = 'القاعة الدراسية';
  int _totalEnrolled = 0;
  int _presentCount = 0;
  int _absentCount = 0;
  bool _hasActiveSession = false;
  List<Map<String, String>> _absentStudents = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _populateInitialGroup();
    _loadLiveSessionFromSupabase();
  }

  void _populateInitialGroup() {
    if (widget.groupAnalytics.isNotEmpty) {
      final first = widget.groupAnalytics.first;
      _currentGroup = first.groupName;
      _currentGroupId = first.groupId;
      _totalEnrolled = first.studentCount;
      _absentCount = first.absentCount;
      _presentCount = (first.studentCount - first.absentCount).clamp(0, first.studentCount);
    } else {
      _currentGroup = 'لا توجد مجموعات مسندة بعد';
      _currentGroupId = null;
      _totalEnrolled = 0;
      _presentCount = 0;
      _absentCount = 0;
    }
  }

  Future<void> _loadLiveSessionFromSupabase() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final sessions = await Supabase.instance.client
          .from('class_sessions')
          .select('id, group_id, status, scheduled_start_at, scheduled_end_at, groups(name, code), rooms(name)')
          .eq('session_date', today)
          .limit(5);

      if (sessions.isNotEmpty) {
        final inProgress = (sessions as List).firstWhere(
          (s) => s['status'] == 'in_progress',
          orElse: () => sessions.first,
        );

        final sessId = inProgress['id']?.toString();
        final grpId = inProgress['group_id']?.toString();
        final grp = inProgress['groups'] as Map<String, dynamic>?;
        final rm = inProgress['rooms'] as Map<String, dynamic>?;

        if (sessId == null) return;

        final attendanceRows = await Supabase.instance.client
            .from('attendance_records')
            .select('student_id, attendance_status, students(student_code, profiles(full_name, phone_number))')
            .eq('class_session_id', sessId);

        final absentList = <Map<String, String>>[];
        int present = 0;
        for (final att in (attendanceRows as List)) {
          final st = (att['attendance_status'] ?? att['status'])?.toString().toLowerCase();
          if (st == 'present' || st == 'late' || st == 'attended') {
            present++;
          } else if (st == 'absent') {
            final stu = att['students'] as Map<String, dynamic>?;
            final prof = stu?['profiles'] as Map<String, dynamic>?;
            absentList.add({
              'name': prof?['full_name']?.toString() ?? 'طالب',
              'code': stu?['student_code']?.toString() ?? '',
              'phone': prof?['phone_number']?.toString() ?? '',
            });
          }
        }

        if (mounted) {
          setState(() {
            _hasActiveSession = inProgress['status'] == 'in_progress';
            _currentSessionId = sessId;
            if (grpId != null) _currentGroupId = grpId;
            if (grp != null && grp['name'] != null) {
              _currentGroup = grp['name'].toString();
            }
            if (rm != null && rm['name'] != null) {
              _roomName = rm['name'].toString();
            }
            _presentCount = present;
            _absentCount = absentList.length;
            _absentStudents = absentList;
            if (present + absentList.length > 0) {
              _totalEnrolled = present + absentList.length;
            }
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openAbsenceBroadcastDialog() {
    if (_absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ممتاز! لا يوجد غياب مسجل لهذه الحصة حالياً 👏'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _AbsenceAlertBroadcastDialog(
        groupName: _currentGroup,
        teacherName: widget.teacherName,
        absentStudents: _absentStudents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    // Inactive Compact State: Sleek, non-intrusive status strip
    if (!_hasActiveSession) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sensors_rounded,
                color: Color(0xFF0D9488),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'رادار الحصص المباشرة',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'في الانتظار ⏸️',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.todaySessionsCount > 0
                        ? 'لديك ${widget.todaySessionsCount} حصص مجدولة اليوم • بانتظار بدء الحصة'
                        : 'لا توجد حصص جارية حالياً • الجدول جاهز لبدء الشرح',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.co_present_rounded, size: 16),
              label: const Text(
                'شاشة العرض',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
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
                      groupId: _currentGroupId,
                      sessionId: _currentSessionId,
                      totalStudents: _totalEnrolled,
                      initialPresent: _presentCount,
                      initialAbsent: _absentCount,
                      absentStudents: _absentStudents,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Active Live Cockpit State
    final attendancePercentage = _totalEnrolled > 0
        ? (_presentCount / _totalEnrolled * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ]
              : const [
                  Color(0xFFF8FAFC),
                  Color(0xFFEEF2F6),
                ],
        ),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar: Beacon + Room + Status
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
                          'غرفة التحكم للحصة المباشرة 🔴',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'مباشر ⏱️',
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(_roomName, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Attendance Counter & Gauge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, size: 15, color: Color(0xFF0D9488)),
                  const SizedBox(width: 6),
                  Text(
                    'الحضور المسجل:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ],
              ),
              Text(
                '$_presentCount من $_totalEnrolled طالب ($attendancePercentage%)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0D9488)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Two-Tone Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: (_totalEnrolled == 0 || (_presentCount == 0 && _absentCount == 0))
                  ? Container(color: Colors.grey.withValues(alpha: 0.2))
                  : Row(
                      children: [
                        if (_presentCount > 0)
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
                        if (_absentCount > 0)
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

          const SizedBox(height: 14),

          // Action Buttons: Focus Mode / Projector + Absence Alert + Broadcast
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final focusBtn = FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.co_present_rounded, size: 18),
                label: Text(
                  isNarrow ? 'البروجيكتور 📽️' : 'وضع البروجيكتور 📽️',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
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
                        groupId: _currentGroupId,
                        sessionId: _currentSessionId,
                        totalStudents: _totalEnrolled,
                        initialPresent: _presentCount,
                        initialAbsent: _absentCount,
                        absentStudents: _absentStudents,
                      ),
                    ),
                  );
                },
              );

              final absenceBtn = FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.campaign_rounded, size: 17),
                label: Text(
                  isNarrow ? 'غياب ($_absentCount) 🚨' : 'إنذار الغياب ($_absentCount) 🚨',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
                onPressed: _openAbsenceBroadcastDialog,
              );

              final broadcastBtn = Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 20),
                  tooltip: 'إذاعة تنبيه للقاعة',
                  color: const Color(0xFFD97706),
                  onPressed: () {
                    ClassBroadcastDialog.show(
                      context,
                      groupName: _currentGroup,
                      teacherName: widget.teacherName,
                    );
                  },
                ),
              );

              return Row(
                children: [
                  Expanded(flex: 5, child: focusBtn),
                  const SizedBox(width: 8),
                  Expanded(flex: 4, child: absenceBtn),
                  const SizedBox(width: 8),
                  broadcastBtn,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Pulse Beacon for Active State ──
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
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D9488).withValues(alpha: opacity),
                  ),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0D9488),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF0D9488),
                      blurRadius: 6,
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

// ── Group Analytics Cards ──
class _TeacherGroupAnalyticsCard extends StatelessWidget {
  final TeacherGroupAnalytics item;

  const _TeacherGroupAnalyticsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.teacherRole.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.teacherRole,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.groupName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (item.groupCode.isNotEmpty) item.groupCode,
                        '${item.studentCount} طالب',
                      ].join(' | '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
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
          const SizedBox(height: 12),
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
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Absence Alert Broadcast Dialog ──
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

    try {
      final client = Supabase.instance.client;
      for (final s in widget.absentStudents) {
        if (_sendAppNotification) {
          try {
            await client.from('notifications').insert({
              'title': 'تنبيه غياب: ${widget.groupName}',
              'body': 'نحيطكم علماً بعدم تسجيل حضور الطالب ${s['name']} (${s['code']}) في حصة اليوم مع الأستاذ ${widget.teacherName}.',
              'type': 'absence_alert',
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
        }
        if (_sendWhatsAppAlert) {
          final phone = s['phone'];
          if (phone != null && phone.isNotEmpty) {
            await WhatsAppService.sendAbsenceNotice(
              parentPhone: phone,
              studentName: s['name'] ?? 'الطالب',
              subjectName: widget.groupName,
              centerName: 'السنتر التعليمي',
            );
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال إنذار الغياب الفوري لـ ${widget.absentStudents.length} أولياء أمور بنجاح 📲',
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
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
                      '🚨 تنبيه عاجل من إدارة السنتر: نحيط سيادتكم علماً بأن الطالب لم يسجل حضوره اليوم في الحصة الجارية حالياً. برجاء الاطمئنان عليه والتواصل معنا للضرورة.',
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
