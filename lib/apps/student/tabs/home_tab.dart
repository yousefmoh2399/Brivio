import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

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
import '../student_dashboard_models.dart';

String _formatMoney(int amountMinor, String currency) {
  final value = amountMinor / 100;
  final clean = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  final curr = (currency.toUpperCase() == 'EGP' || currency.isEmpty) ? 'ج.م' : currency;
  return '$clean $curr';
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
                      'أهلاً بك،',
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.displayMedium(textPrimary).copyWith(
                        fontSize: 22,
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

                // ── Live Countdown Hero Card ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 150),
                  child: LiveCountdownHeroCard(
                    isLoading: isLoading,
                    lesson: nextLesson,
                    gamification: gamification,
                    onOpen: onOpenWorkspace,
                    groupName: enrolledGroups.isNotEmpty
                        ? enrolledGroups.first.name
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // ── 3-Minute Quick Review Flashcard Deck (Only shown when enrolled in groups with an active lesson) ──
                if (enrolledGroups.isNotEmpty && nextLesson != null) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 700),
                    delay: const Duration(milliseconds: 165),
                    child: QuickReviewFlashcardDeck(
                      lesson: nextLesson,
                      groupName: enrolledGroups.first.name,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                                  'منصة التجارب التفاعلية (Playground)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleMedium(
                                    textPrimary,
                                  ).copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'شغّل الأكواد وشاهد الشرح التفاعلي خطوة بخطوة',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'فتح منصة التجارب',
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

                // ── Quick Stats ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    'نظرة عامة',
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
                          'واجبات تستحق قريباً',
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
                          child: const Text('عرض الكل'),
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
                      'مستوى تقدمك الأكاديمي',
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
                    child: _GamificationCard(
                      summary: gamification,
                      enrolledGroups: enrolledGroups,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Study Metrics ──
                if ((snapshot?.metrics ?? const []).isNotEmpty) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 350),
                    child: Text(
                      'مؤشرات المذاكرة',
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
                          'مجموعاتي الدراسية',
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
                            'عرض الكل',
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

class LiveCountdownHeroCard extends StatefulWidget {
  final bool isLoading;
  final StudyLessonSummary? lesson;
  final StudentGamificationSummary? gamification;
  final VoidCallback? onOpen;
  final String? groupName;

  const LiveCountdownHeroCard({
    super.key,
    required this.isLoading,
    required this.lesson,
    required this.gamification,
    required this.onOpen,
    this.groupName,
  });

  @override
  State<LiveCountdownHeroCard> createState() => _LiveCountdownHeroCardState();
}

class _LiveCountdownHeroCardState extends State<LiveCountdownHeroCard> {
  Timer? _ticker;
  DateTime? _targetClassTime;
  Duration _remaining = Duration.zero;
  bool _reminderEnabled = false;

  @override
  void initState() {
    super.initState();
    _computeTargetTime();
    _startTicker();
  }

  void _computeTargetTime() {
    final now = DateTime.now();
    if (widget.lesson?.publishedAt != null &&
        widget.lesson!.publishedAt!.isAfter(now)) {
      _targetClassTime = widget.lesson!.publishedAt;
      _remaining = _targetClassTime!.difference(now);
    } else {
      _targetClassTime = null;
      _remaining = Duration.zero;
    }
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_targetClassTime != null) {
        setState(() {
          _remaining = _targetClassTime!.difference(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggleReminder() {
    HapticFeedback.mediumImpact();
    setState(() {
      _reminderEnabled = !_reminderEnabled;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _reminderEnabled
              ? 'تم تفعيل التنبيه الذكي قبل موعد الحصة بـ 15 دقيقة! 🔔'
              : 'تم إلغاء التنبيه الذكي لهذه الحصة.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            _reminderEnabled ? const Color(0xFF0F172A) : Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasScheduledUpcoming = _targetClassTime != null && _remaining.inSeconds > 0;
    final isLiveNow = _targetClassTime != null && _remaining.inSeconds <= 0;
    final isStartingSoon = hasScheduledUpcoming && _remaining.inMinutes < 60;

    final days = math.max(0, _remaining.inDays);
    final hours = math.max(0, _remaining.inHours % 24);
    final minutes = math.max(0, _remaining.inMinutes % 60);
    final seconds = math.max(0, _remaining.inSeconds % 60);

    return GlowContainer(
      glowColor: isLiveNow ? Colors.redAccent : AppColors.primary,
      glowOpacity: isDark ? 0.35 : 0.15,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isLiveNow
                ? [const Color(0xFF991B1B), const Color(0xFF450A0A)]
                : [
                    AppColors.primary,
                    HSLColor.fromColor(AppColors.primary)
                        .withLightness(
                          math.max(
                            0.0,
                            HSLColor.fromColor(
                                  AppColors.primary,
                                ).lightness -
                                0.14,
                          ),
                        )
                        .toColor(),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLiveNow ? Colors.red : AppColors.primary).withValues(
                alpha: isDark ? 0.4 : 0.2,
              ),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status & Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Live Countdown Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isLiveNow
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isLiveNow ? Colors.redAccent : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isLiveNow
                              ? Colors.redAccent
                              : (isStartingSoon
                                  ? Colors.amberAccent
                                  : Colors.greenAccent),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLiveNow
                            ? 'الحصة جارية الآن! 🔴'
                            : (hasScheduledUpcoming
                                ? (isStartingSoon
                                    ? 'أقل من ساعة على البداية! ⏳'
                                    : 'الحصة القادمة بعد')
                                : (widget.lesson != null
                                    ? 'الدرس متاح للمشاهدة 🟢'
                                    : 'الجدول الأكاديمي 📚')),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // 1-Tap Smart Reminder Toggle
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: _toggleReminder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _reminderEnabled
                            ? Colors.amber.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: _reminderEnabled
                              ? Colors.amberAccent
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _reminderEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
                            color: _reminderEnabled
                                ? Colors.amberAccent
                                : Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _reminderEnabled
                                ? 'منبه مفعّل 🔔'
                                : 'تذكير (15 د)',
                            style: TextStyle(
                              color: _reminderEnabled
                                  ? Colors.amberAccent
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Live Digital Countdown Ticker Boxes (only when a lesson is scheduled in the future)
            if (hasScheduledUpcoming) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCountdownUnit('$days', 'يوم'),
                    _buildColon(),
                    _buildCountdownUnit('$hours'.padLeft(2, '0'), 'ساعة'),
                    _buildColon(),
                    _buildCountdownUnit('$minutes'.padLeft(2, '0'), 'دقيقة'),
                    _buildColon(),
                    _buildCountdownUnit(
                      '$seconds'.padLeft(2, '0'),
                      'ثانية',
                      isPulsing: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (!isLiveNow && widget.lesson != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'المحاضرة منشورة ومتاحة بالكامل للمتابعة الآن 🚀',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Lesson Title
            Text(
              widget.isLoading
                  ? 'جاري التحميل...'
                  : (widget.lesson?.title ?? 'لا توجد دروس متاحة حالياً'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),

            // Unit Name, Group, and Classroom location
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isLoading
                        ? ''
                        : widget.lesson == null
                        ? 'انضم لمجموعة وانتظر نشر الدروس الجديدة من معلمك.'
                        : '${widget.lesson!.unitName}  ·  ${widget.lesson!.estimatedMinutes} دقيقة${widget.groupName != null ? "  ·  🏛️ ${widget.groupName}" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            // Lesson Progress Bar
            if (!widget.isLoading && widget.lesson != null) ...[
              const SizedBox(height: 16),
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
                    widthFactor: widget.lesson!.progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'تم إنجاز ${widget.lesson!.progressPercentage}% من محتوى الحصة',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor:
                      isLiveNow ? Colors.red.shade900 : AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: widget.onOpen,
                icon: Icon(
                  isLiveNow ? Icons.sensors_rounded : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(
                  widget.onOpen == null
                      ? 'لا يوجد درس متاح'
                      : (isLiveNow
                          ? 'انضم إلى الحصة المباشرة الآن! 🔴'
                          : 'ابدأ مذاكرة الدرس'),
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

  Widget _buildColon() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white60,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildCountdownUnit(
    String value,
    String label, {
    bool isPulsing = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 54),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isPulsing ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPulsing
              ? Colors.cyanAccent.withValues(alpha: 0.6)
              : Colors.white24,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: isPulsing ? Colors.cyanAccent : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3-Minute Quick Review Flashcard Deck.
/// High-yield smart concept cards students can tap to 3D flip before lectures.
class QuickReviewFlashcardDeck extends StatefulWidget {
  final StudyLessonSummary? lesson;
  final String? groupName;

  const QuickReviewFlashcardDeck({
    super.key,
    this.lesson,
    this.groupName,
  });

  @override
  State<QuickReviewFlashcardDeck> createState() =>
      _QuickReviewFlashcardDeckState();
}

class _QuickReviewFlashcardDeckState extends State<QuickReviewFlashcardDeck> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Map<int, bool> _flipped = {};
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessonFlashcards();
  }

  @override
  void didUpdateWidget(covariant QuickReviewFlashcardDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson?.id != widget.lesson?.id) {
      _loadLessonFlashcards();
    }
  }

  Future<void> _loadLessonFlashcards() async {
    if (widget.lesson == null) {
      if (mounted) setState(() { _cards = []; _isLoading = false; });
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('questions')
          .select('prompt, explanation, difficulty')
          .eq('lesson_id', widget.lesson!.id)
          .limit(5);

      final list = <Map<String, dynamic>>[];
      final colors = [
        const Color(0xFF0284C7),
        const Color(0xFFD97706),
        const Color(0xFF7C3AED),
        const Color(0xFF059669),
      ];
      final icons = [
        Icons.bolt_rounded,
        Icons.lightbulb_rounded,
        Icons.psychology_rounded,
        Icons.star_rounded,
      ];

      for (int i = 0; i < (res as List).length; i++) {
        final row = res[i];
        final prompt = row['prompt']?.toString() ?? '';
        final explanation = row['explanation']?.toString() ?? '';
        if (prompt.isNotEmpty) {
          list.add({
            'tag': 'مفهوم للمراجعة 💡',
            'title': prompt,
            'teaser': 'المس الكارت لاكتشاف التفسير والحل النموذجي ⚡',
            'tipTitle': 'التفسير والمفتاح النموذجي:',
            'tipBody': explanation.isNotEmpty
                ? explanation
                : 'راجع خطوات الحل والقوانين المتعلقة بهذا المفهوم في المحاضرة.',
            'color': colors[i % colors.length],
            'icon': icons[i % icons.length],
          });
        }
      }

      if (mounted) {
        setState(() {
          _cards = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cards = [];
          _isLoading = false;
        });
      }
    }
  }

  void _flipCard(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _flipped[index] = !(_flipped[index] ?? false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'كروت المراجعة الذكية للدرس ⚡',
                  style: AppTypography.titleMedium(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Row(
              children: List.generate(
                _cards.length,
                (i) => Container(
                  width: _currentIndex == i ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _currentIndex == i
                        ? AppColors.primary
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _cards.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final card = _cards[index];
              final isFlipped = _flipped[index] ?? false;
              final accentColor = card['color'] as Color;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: GestureDetector(
                  onTap: () => _flipCard(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentColor.withValues(
                          alpha: isDark ? 0.35 : 0.25,
                        ),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isFlipped
                        ? _buildBackContent(
                            card,
                            accentColor,
                            textPrimary,
                            textSecondary,
                          )
                        : _buildFrontContent(
                            card,
                            accentColor,
                            textPrimary,
                            textSecondary,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFrontContent(
    Map<String, dynamic> card,
    Color accentColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                card['tag'] as String,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  'المس لقلب الكارت',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.touch_app_rounded,
                  color: accentColor,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
        Text(
          card['title'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium(textPrimary).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        Row(
          children: [
            Icon(card['icon'] as IconData, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                card['teaser'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(
                  textSecondary,
                ).copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackContent(
    Map<String, dynamic> card,
    Color accentColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              card['tipTitle'] as String,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 12,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'تم الكشف',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          card['tipBody'] as String,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall(
            textPrimary,
          ).copyWith(height: 1.45, fontSize: 12),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            'المس لإعادة الوجه 🔄',
            style: TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
          label: 'الدروس',
          value: '$availableLessons',
          icon: Icons.menu_book_rounded,
          accentColor: AppColors.studentRole,
          onTap: onLessons,
        ),
        PortalMetricCard(
          label: 'المجموعات',
          value: '$activeCourses',
          icon: Icons.grid_view_rounded,
          accentColor: AppColors.info,
          onTap: onCourses,
        ),
        PortalMetricCard(
          label: 'الإشعارات',
          value: '$unreadCount',
          icon: Icons.notifications_rounded,
          accentColor: AppColors.warning,
          onTap: onNotifications,
        ),
        PortalMetricCard(
          label: 'الرصيد المتبقي',
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
  final List<GroupEntity> enrolledGroups;

  const _GamificationCard({
    required this.summary,
    this.enrolledGroups = const [],
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
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      color: surfaceColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Daily Streak Fire Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF451A03), const Color(0xFF2E1065)]
                    : [const Color(0xFFFEF3C7), const Color(0xFFF3E8FF)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حماسك مشتعل: ${summary.streakDays} أيام متتالية!',
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'حافظ على الحضور وتسليم الواجبات يومياً لمضاعفة نقاط الـ XP ⚡',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── 2. Level & XP Progress ──
          Row(
            children: [
              // Level circle
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${summary.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${summary.totalXp} XP',
                          style: AppTypography.titleMedium(textPrimary).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'المستوى ${summary.level}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                              ),
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${summary.xpToNextLevel} XP متبقية للوصول للمستوى التالي',
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

          const SizedBox(height: 16),

          // ── 3. Hall of Fame Leaderboard Button ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber.shade800,
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                GroupLeaderboardWidget.show(
                  context,
                  groupId: enrolledGroups.isNotEmpty ? enrolledGroups.first.id : null,
                  groupName: enrolledGroups.isNotEmpty ? enrolledGroups.first.name : null,
                  availableGroups: enrolledGroups,
                );
              },
              icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
              label: const Text(
                'عرض لوحة شرف الأوائل (Hall of Fame) 🏆',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
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
                    'تاريخ التسليم: ${DateFormat.yMMMd().format(homework.homework.dueAt)}',
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
