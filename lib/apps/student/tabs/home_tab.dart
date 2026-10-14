import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../../../core/localization/app_localizations.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/academy/presentation/screens/academy_screens.dart';
import '../../../features/payments/domain/models/payment_models.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../../features/code_playground/presentation/screens/code_playground_screen.dart';
import '../../../features/academy/presentation/widgets/center_switcher_widget.dart';
import '../../../features/academy/presentation/widgets/join_center_dialog.dart';
import '../../../features/student/presentation/widgets/student_digital_id_card.dart';
import '../../../features/study_workspace/presentation/screens/student_personal_board_screen.dart';
import '../../../features/assessment/presentation/widgets/group_leaderboard_widget.dart';
import '../widgets/student_timetable_widget.dart';
import '../../../features/assessment/presentation/screens/ai_study_companion_screen.dart';
import '../../../features/curriculum/presentation/screens/student_materials_screen.dart';
import '../../../features/helpdesk/presentation/screens/helpdesk_support_screen.dart';
import '../student_dashboard_models.dart';

String _formatMoney(int amountMinor, String currency) {
  final format = NumberFormat.currency(symbol: '$currency ', decimalDigits: 2);
  return format.format(amountMinor / 100);
}

class HomeTab extends StatelessWidget {
  final String userName;
  final bool isLoading;
  final String? errorMessage;
  final StudentLearningSnapshot? snapshot;
  final List<GroupEntity> enrolledGroups;
  final FinancialSummary? financialSummary;
  final int unreadCount;
  final VoidCallback onRetry;
  final VoidCallback? onOpenWorkspace;
  final VoidCallback? onOpenPersonalBoard;
  final ValueChanged<int> onNavigate;
  final List<StudentHomeworkItem> pendingHomework;

  const HomeTab({
    super.key,
    required this.userName,
    required this.isLoading,
    required this.errorMessage,
    required this.snapshot,
    required this.enrolledGroups,
    required this.financialSummary,
    required this.unreadCount,
    required this.onRetry,
    required this.onOpenWorkspace,
    this.onOpenPersonalBoard,
    required this.onNavigate,
    required this.pendingHomework,
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
    final nextLesson = snapshot?.nextLesson;
    final gamification = snapshot?.gamification;

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      color: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Large Title App Bar ──
              SliverAppBar(
            backgroundColor: isDark
                ? AppColors.darkBackground
                : AppColors.lightBackground,
            surfaceTintColor: Colors.transparent,
            floating: true,
            pinned: false,
            expandedHeight: 120,
            actions: [
              IconButton(
                tooltip: 'بطاقة هويتي بالسنتر (QR)',
                onPressed: () {
                  final authId = Supabase.instance.client.auth.currentUser?.id;
                  final stuCode = authId != null && authId.length >= 8
                      ? 'STU-${authId.substring(0, 8).toUpperCase()}'
                      : 'STU-BRIVIO';
                  StudentDigitalIdCard.show(
                    context,
                    studentName: userName,
                    studentCode: stuCode,
                    gradeLevel: enrolledGroups.isNotEmpty
                        ? enrolledGroups.first.name
                        : null,
                  );
                },
                icon: const Icon(
                  Icons.badge_rounded,
                  color: AppColors.studentRole,
                ),
              ),
              IconButton(
                tooltip: 'سبورتي ومسودتي الشخصية',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentPersonalBoardScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.draw_rounded,
                  color: AppColors.studentRole,
                ),
              ),
              IconButton(
                tooltip: 'الانضمام لسنتر جديد بكود',
                onPressed: () => JoinCenterDialog.show(context, onJoined: onRetry),
                icon: const Icon(
                  Icons.add_business_rounded,
                  color: AppColors.studentRole,
                ),
              ),
              IconButton(
                tooltip: 'لوحة شرف الأوائل (Hall of Fame)',
                onPressed: () {
                  GroupLeaderboardWidget.show(
                    context,
                    groupId: enrolledGroups.isNotEmpty ? enrolledGroups.first.id : null,
                    groupName: enrolledGroups.isNotEmpty ? enrolledGroups.first.name : null,
                    availableGroups: enrolledGroups,
                  );
                },
                icon: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                ),
              ),
              CenterSwitcherWidget(onCenterChanged: onRetry),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 24,
                bottom: 8,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      context.tr('Good morning,'),
                      style: AppTypography.caption(
                        textSecondary,
                      ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      userName.split(' ').first,
                      style: AppTypography.displayMedium(textPrimary).copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (errorMessage != null) ...[
                  PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
                  const SizedBox(height: 16),
                ],

                // ── Next Lesson Hero (Glassmorphism) ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 150),
                  child: _NextLessonHero(
                    isLoading: isLoading,
                    lesson: nextLesson,
                    gamification: gamification,
                    onOpen: onOpenWorkspace,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Code Playground Shortcut ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 175),
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
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.code,
                              color: AppColors.primary,
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
                                    textPrimary,
                                  ).copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Run code and watch step-by-step visual explanations',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'Open code playground',
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Leaderboard & Hall of Fame Shortcut ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 175),
                  child: GestureDetector(
                    onTap: () {
                      GroupLeaderboardWidget.show(
                        context,
                        groupId: enrolledGroups.isNotEmpty ? enrolledGroups.first.id : null,
                        groupName: enrolledGroups.isNotEmpty ? enrolledGroups.first.name : null,
                        availableGroups: enrolledGroups,
                      );
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.amber.shade50.withValues(alpha: 0.6),
                      borderColor: Colors.amber.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.amber,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'لوحة شرف الأوائل • Hall of Fame',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.titleMedium(
                                        textPrimary,
                                      ).copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'الأوائل 👑',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'شاهد فرسان المجموعة وأعلى درجات الامتحانات ونسبة الحضور 100%',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Personal Board Shortcut ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 185),
                  child: GestureDetector(
                    onTap: () {
                      if (onOpenPersonalBoard != null) {
                        onOpenPersonalBoard!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const StudentPersonalBoardScreen(),
                          ),
                        );
                      }
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
                              color: AppColors.purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.draw_rounded,
                              color: AppColors.purple,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'سبورتي ومسودتي الحرة',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.titleMedium(
                                        textPrimary,
                                      ).copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'خاصة وسريعة',
                                        style: AppTypography.caption(
                                          AppColors.success,
                                        ).copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'كشكول وسبورة ذكية لحل المسائل وتدوين الملاحظات بحرية تامة',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.purple,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Student Smart Services Hub ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 195),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AiStudyCompanionScreen(studentName: userName),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.psychology_rounded, color: AppColors.primary, size: 24),
                                SizedBox(height: 6),
                                Text(
                                  'المساعد الذكي 🤖',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentMaterialsScreen(studentName: userName),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.menu_book_rounded, color: Colors.green, size: 24),
                                SizedBox(height: 6),
                                Text(
                                  'مكتبة الملازم 📚',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpdeskSupportScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.support_agent_rounded, color: Colors.amber, size: 24),
                                SizedBox(height: 6),
                                Text(
                                  'الدعم والشكاوى 🎧',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Student Interactive Timetable Widget ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 200),
                  child: const StudentTimetableWidget(),
                ),
                const SizedBox(height: 24),

                // ── Quick Stats ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    context.tr('Overview'),
                    style: AppTypography.titleLarge(textPrimary).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeInSlide(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 250),
                  child: _QuickStatsGrid(
                    availableLessons: snapshot?.availableLessons.length ?? 0,
                    activeCourses: enrolledGroups.length,
                    unreadCount: unreadCount,
                    balance: financialSummary?.remainingBalanceMinor ?? 0,
                    currency: financialSummary?.currency ?? 'EGP',
                    onLessons: () => onNavigate(1),
                    onCourses: () => onNavigate(1),
                    onNotifications: () => onNavigate(3),
                    onBilling: () => onNavigate(4),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Pending Homework ──
                if (pendingHomework.isNotEmpty) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 320),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('Due Soon'),
                          style: AppTypography.titleLarge(textPrimary).copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        TextButton(
                          onPressed: () => onNavigate(2),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: Text(context.tr('See All')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 380),
                    child: _PendingHomeworkCard(
                      homework: pendingHomework.first,
                      onTap: () => onNavigate(2),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Gamification ──
                if (gamification != null && gamification.level > 0) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      context.tr('Learning progress'),
                      style: AppTypography.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 350),
                    child: _GamificationCard(summary: gamification),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Study Metrics ──
                if ((snapshot?.metrics ?? const []).isNotEmpty) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 350),
                    child: Text(
                      context.tr('Study Metrics'),
                      style: AppTypography.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 400),
                    child: _StudyMetricsGrid(metrics: snapshot!.metrics),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Enrolled Groups preview ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 400),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('Enrolled Groups'),
                          style: AppTypography.titleLarge(textPrimary).copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onNavigate(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            context.tr('See all'),
                            style: AppTypography.labelLarge(AppColors.primary)
                                .copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FadeInSlide(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 450),
                  child: SizedBox(
                    height: 340,
                    child: GroupListWidget(
                      groups: enrolledGroups,
                      isLoading: isLoading,
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
}

class _NextLessonHero extends StatelessWidget {
  final bool isLoading;
  final StudyLessonSummary? lesson;
  final StudentGamificationSummary? gamification;
  final VoidCallback? onOpen;

  const _NextLessonHero({
    required this.isLoading,
    required this.lesson,
    required this.gamification,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlowContainer(
      glowColor: AppColors.primary,
      glowOpacity: isDark ? 0.35 : 0.15,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              HSLColor.fromColor(AppColors.primary)
                  .withLightness(
                    math.max(
                      0.0,
                      HSLColor.fromColor(AppColors.primary).lightness - 0.12,
                    ),
                  )
                  .toColor(),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level badge
            if (gamification != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'المستوى ${gamification!.level} · ${gamification!.streakDays} يوم حماسي',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Text(
              isLoading
                  ? context.tr('Loading…')
                  : (lesson?.title ?? context.tr('No lesson available')),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isLoading
                  ? ''
                  : lesson == null
                  ? context.tr(
                      'Enroll in a group and wait for a published lesson.',
                    )
                  : '${lesson!.unitName}  ·  ${lesson!.estimatedMinutes} min',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isLoading && lesson != null) ...[
              const SizedBox(height: 18),
              Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: lesson!.progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${lesson!.progressPercentage}% ${context.tr("Completed Lessons")}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onOpen,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  onOpen == null
                      ? context.tr('No lesson ready')
                      : context.tr('Start Lesson'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  final int availableLessons;
  final int activeCourses;
  final int unreadCount;
  final int balance;
  final String currency;
  final VoidCallback onLessons;
  final VoidCallback onCourses;
  final VoidCallback onNotifications;
  final VoidCallback onBilling;

  const _QuickStatsGrid({
    required this.availableLessons,
    required this.activeCourses,
    required this.unreadCount,
    required this.balance,
    required this.currency,
    required this.onLessons,
    required this.onCourses,
    required this.onNotifications,
    required this.onBilling,
  });

  @override
  Widget build(BuildContext context) {
    return PortalMetricGrid(
      children: [
        PortalMetricCard(
          label: context.tr('Lessons'),
          value: '$availableLessons',
          icon: Icons.menu_book_rounded,
          accentColor: AppColors.studentRole,
          onTap: onLessons,
        ),
        PortalMetricCard(
          label: context.tr('Courses'),
          value: '$activeCourses',
          icon: Icons.grid_view_rounded,
          accentColor: AppColors.info,
          onTap: onCourses,
        ),
        PortalMetricCard(
          label: context.tr('Notifications'),
          value: '$unreadCount',
          icon: Icons.notifications_rounded,
          accentColor: AppColors.warning,
          onTap: onNotifications,
        ),
        PortalMetricCard(
          label: context.tr('Balance'),
          value: _formatMoney(balance, currency),
          icon: Icons.wallet_rounded,
          accentColor: AppColors.error,
          onTap: onBilling,
        ),
      ],
    );
  }
}

class _GamificationCard extends StatelessWidget {
  final StudentGamificationSummary summary;

  const _GamificationCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      color: surfaceColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Level circle
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${summary.level}',
                  style: AppTypography.titleLarge(
                    AppColors.primary,
                  ).copyWith(fontWeight: FontWeight.w900, fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.totalXp} XP',
                      style: AppTypography.titleMedium(textPrimary).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (summary.levelProgressPercentage / 100)
                              .clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${summary.xpToNextLevel} XP ${context.tr("to next level")}',
                style: AppTypography.caption(
                  textSecondary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${summary.levelProgressPercentage.toInt()}%',
                style: AppTypography.caption(
                  AppColors.primary,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudyMetricsGrid extends StatelessWidget {
  final List<StudyMetric> metrics;

  const _StudyMetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 110,
          ),
          itemBuilder: (context, i) {
            final m = metrics[i];
            return GlassCard(
              padding: const EdgeInsets.all(16),
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    m.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(
                      textSecondary,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleLarge(textPrimary).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.helper,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(
                      textSecondary,
                    ).copyWith(fontSize: 11),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PendingHomeworkCard extends StatelessWidget {
  final StudentHomeworkItem homework;
  final VoidCallback onTap;

  const _PendingHomeworkCard({required this.homework, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        color: surfaceColor,
        borderColor: borderColor,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_late_rounded,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homework.homework.title,
                    style: AppTypography.titleMedium(
                      textPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.tr("Due")}: ${DateFormat.yMMMd().format(homework.homework.dueAt)}',
                    style: AppTypography.caption(
                      textSecondary,
                    ).copyWith(color: AppColors.warning),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}
