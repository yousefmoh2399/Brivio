import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/payments/domain/models/payment_models.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../../features/code_playground/presentation/screens/code_playground_screen.dart';
import '../../../features/academy/presentation/widgets/center_switcher_widget.dart';
import '../../../features/academy/presentation/widgets/join_center_dialog.dart';
import '../../../features/student/presentation/widgets/student_digital_id_card.dart';
import '../../../features/study_workspace/presentation/screens/student_personal_board_screen.dart';
import '../../../features/assessment/presentation/widgets/group_leaderboard_widget.dart';
import '../../../features/assessment/presentation/widgets/student_blitz_quiz_dialog.dart';
import '../../../features/attendance/presentation/screens/student_qr_attendance_screen.dart';
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
  final List<StudentAttendanceItem> attendanceItems;
  final String? centerName;
  final String? centerCode;
  final String? seatNumber;
  final VoidCallback? onScanQr;

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
    this.attendanceItems = const [],
    this.centerName,
    this.centerCode,
    this.seatNumber,
    this.onScanQr,
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

    // Calculate attendance percentage
    final totalSessions = attendanceItems.length;
    final attendedSessions = attendanceItems
        .where((a) =>
            a.status.toLowerCase() == 'present' ||
            a.status.toLowerCase() == 'attended')
        .length;
    final attendanceRate = totalSessions > 0
        ? ((attendedSessions / totalSessions) * 100).round()
        : 100;

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
              // ── Minimalist Executive App Bar ──
              SliverAppBar(
                backgroundColor: isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                floating: false,
                elevation: 0,
                titleSpacing: 16,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'بوابة الطالب الذكية',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.primary,
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

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (errorMessage != null) ...[
                      PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
                      const SizedBox(height: 16),
                    ],

                    // 1. Executive Student Hero Card
                    FadeInSlide(
                      duration: const Duration(milliseconds: 400),
                      child: _buildStudentHero(
                        context,
                        userName: userName,
                        activeCourses: enrolledGroups.length,
                        pendingHomeworkCount: pendingHomework.length,
                        attendanceRate: attendanceRate,
                        level: gamification?.level ?? 1,
                        totalXp: gamification?.totalXp ?? 0,
                        centerName: centerName,
                        seatNumber: seatNumber,
                        isDark: isDark,
                      ),
                    ),

                    // 2. Next Class / Timetable Radar
                    FadeInSlide(
                      duration: const Duration(milliseconds: 450),
                      delay: const Duration(milliseconds: 50),
                      child: LiveCountdownHeroCard(
                        isLoading: isLoading,
                        lesson: nextLesson,
                        gamification: gamification,
                        onOpen: onOpenWorkspace,
                        onNavigateToCourses: () => onNavigate(1),
                        groupName: enrolledGroups.isNotEmpty
                            ? enrolledGroups.first.name
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Primary Academic KPIs Grid
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 100),
                      child: PortalMetricGrid(
                        children: [
                          PortalMetricCard(
                            label: 'المجموعات الدراسية',
                            value: '${enrolledGroups.length}',
                            icon: Icons.school_rounded,
                            accentColor: AppColors.primary,
                            onTap: () => onNavigate(1),
                          ),
                          PortalMetricCard(
                            label: 'واجبات للتسليم',
                            value: '${pendingHomework.length}',
                            icon: Icons.assignment_rounded,
                            accentColor: AppColors.warning,
                            onTap: () => onNavigate(2),
                          ),
                          PortalMetricCard(
                            label: 'نسبة الحضور بالسنتر',
                            value: '$attendanceRate%',
                            icon: Icons.verified_user_rounded,
                            accentColor: AppColors.success,
                            onTap: () => onNavigate(2),
                          ),
                          PortalMetricCard(
                            label: 'المحفظة والمصروفات',
                            value: _formatMoney(
                              financialSummary?.remainingBalanceMinor ?? 0,
                              financialSummary?.currency ?? 'EGP',
                            ),
                            icon: Icons.account_balance_wallet_rounded,
                            accentColor: AppColors.info,
                            onTap: () => onNavigate(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Unified Student Command Hub (7 distinct tools)
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
                                'مركز أدوات الطالب الذكية ⚡',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                '7 أدوات متكاملة',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _StudentCommandHub(
                            onScanQr: onScanQr,
                            onOpenPersonalBoard: onOpenPersonalBoard,
                            onRetry: onRetry,
                            userName: userName,
                            enrolledGroups: enrolledGroups,
                            centerName: centerName,
                            centerCode: centerCode,
                            attendanceRate: attendanceRate.toDouble(),
                            seatNumber: seatNumber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Urgent Pending Homework (If any)
                    if (pendingHomework.isNotEmpty) ...[
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'واجبات تستحق قريباً 📝',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => onNavigate(2),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('عرض الكل'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _PendingHomeworkCard(
                              homework: pendingHomework.first,
                              onTap: () => onNavigate(2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 6. Gamification & Academic Progress
                    if (gamification != null && gamification.level > 0) ...[
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 250),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مستوى تقدمك الأكاديمي 🌟',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _GamificationCard(
                              summary: gamification,
                              enrolledGroups: enrolledGroups,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 7. 3-Minute Quick Review Flashcard Deck (When lesson exists)
                    if (enrolledGroups.isNotEmpty && nextLesson != null) ...[
                      FadeInSlide(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 300),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مراجعة الـ 3 دقائق التفاعلية 🃏',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            QuickReviewFlashcardDeck(
                              lesson: nextLesson,
                              groupName: enrolledGroups.first.name,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHero(
    BuildContext context, {
    required String userName,
    required int activeCourses,
    required int pendingHomeworkCount,
    required int attendanceRate,
    required int level,
    required int totalXp,
    required String? centerName,
    required String? seatNumber,
    required bool isDark,
  }) {
    final cleanName = userName.trim().isNotEmpty ? userName.trim() : 'طالبنا المتميز';
    final initials = cleanName.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0]).join();
    final firstName = cleanName.split(' ').first;

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
                  Color(0xFF1E1B4B),
                  Color(0xFF0F172A),
                ]
              : const [
                  Color(0xFFEEF2FF),
                  Color(0xFFFFFFFF),
                ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.05),
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
              // Student Avatar with active ring
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : '🎓',
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
                      'أهلاً بك يا $firstName 🎓',
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
                      '${centerName?.trim().isNotEmpty == true ? centerName! : "السنتر التعليمي"} • ${seatNumber?.trim().isNotEmpty == true ? seatNumber! : "مقعد عام"}',
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
                  : AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildGlanceItem(
                    icon: Icons.school_rounded,
                    label: '$activeCourses مجموعات',
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 14, color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(width: 8),
                  _buildGlanceItem(
                    icon: Icons.assignment_rounded,
                    label: '$pendingHomeworkCount واجبات',
                    color: pendingHomeworkCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 14, color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(width: 8),
                  _buildGlanceItem(
                    icon: Icons.stars_rounded,
                    label: 'مستوى $level ($totalXp XP)',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 14, color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(width: 8),
                  _buildGlanceItem(
                    icon: Icons.verified_user_rounded,
                    label: '$attendanceRate% حضور',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ],
              ),
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
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Unified Student Command Hub (7 distinct tools) ──
class _StudentCommandHub extends StatelessWidget {
  final VoidCallback? onScanQr;
  final VoidCallback? onOpenPersonalBoard;
  final VoidCallback onRetry;
  final String userName;
  final List<GroupEntity> enrolledGroups;
  final String? centerName;
  final String? centerCode;
  final double attendanceRate;
  final String? seatNumber;

  const _StudentCommandHub({
    required this.onScanQr,
    required this.onOpenPersonalBoard,
    required this.onRetry,
    required this.userName,
    required this.enrolledGroups,
    this.centerName,
    this.centerCode,
    this.attendanceRate = 1.0,
    this.seatNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tools = [
      _StudentToolItem(
        title: 'بوابة الحضور',
        subtitle: 'مسح كود القاعة الذكية',
        badge: 'تسجيل ⚡',
        icon: Icons.qr_code_scanner_rounded,
        gradient: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
        borderAccent: const Color(0xFF14B8A6),
        onTap: () {
          HapticFeedback.lightImpact();
          if (onScanQr != null) {
            onScanQr!();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudentQrAttendanceScreen(),
              ),
            );
          }
        },
      ),
      _StudentToolItem(
        title: 'كارنيه الطالب',
        subtitle: 'باركود الدخول السريع',
        badge: 'هويتي 🪪',
        icon: Icons.badge_rounded,
        gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
        borderAccent: const Color(0xFF818CF8),
        onTap: () {
          HapticFeedback.lightImpact();
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
            centerName: centerName?.trim().isNotEmpty == true
                ? centerName!
                : 'المركز التعليمي',
            centerCode: centerCode,
            attendanceRate: attendanceRate / 100.0,
            activeCoursesCount: enrolledGroups.length,
            seatNumber: seatNumber ?? 'مقعد عام',
          );
        },
      ),
      _StudentToolItem(
        title: 'كويز 5 دقائق',
        subtitle: 'إدخال PIN والتحدي اللحظي',
        badge: 'مباشر ⚡',
        icon: Icons.bolt_rounded,
        gradient: const [Color(0xFFDB2777), Color(0xFFE11D48)],
        borderAccent: const Color(0xFFF43F5E),
        onTap: () {
          HapticFeedback.lightImpact();
          StudentBlitzQuizJoinDialog.show(
            context,
            studentName: userName,
            groupId: enrolledGroups.isNotEmpty ? enrolledGroups.first.id : null,
          );
        },
      ),
      _StudentToolItem(
        title: 'سبورتي ومسودتي',
        subtitle: 'رسم وحل المسائل والملاحظات',
        badge: 'مسودة 🎨',
        icon: Icons.draw_rounded,
        gradient: const [Color(0xFFEA580C), Color(0xFFF97316)],
        borderAccent: const Color(0xFFF97316),
        onTap: () {
          HapticFeedback.lightImpact();
          if (onOpenPersonalBoard != null) {
            onOpenPersonalBoard!();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudentPersonalBoardScreen(),
              ),
            );
          }
        },
      ),
      _StudentToolItem(
        title: 'أوائل المجموعات',
        subtitle: 'لوحة الشرف وتصنيف المتفوقين',
        badge: 'شرف 🏆',
        icon: Icons.emoji_events_rounded,
        gradient: const [Color(0xFFCA8A04), Color(0xFFEAB308)],
        borderAccent: const Color(0xFFFACC15),
        onTap: () {
          HapticFeedback.lightImpact();
          GroupLeaderboardWidget.show(
            context,
            groupId: enrolledGroups.isNotEmpty ? enrolledGroups.first.id : null,
            groupName: enrolledGroups.isNotEmpty ? enrolledGroups.first.name : null,
            availableGroups: enrolledGroups,
          );
        },
      ),
      _StudentToolItem(
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
      _StudentToolItem(
        title: 'ربط سنتر جديد',
        subtitle: 'الانضمام لأكاديمية بكود الربط',
        badge: 'انضمام 🏫',
        icon: Icons.add_business_rounded,
        gradient: const [Color(0xFF0891B2), Color(0xFF06B6D4)],
        borderAccent: const Color(0xFF22D3EE),
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
            return _StudentToolCard(tool: tools[index], isDark: isDark);
          },
        );
      },
    );
  }
}

class _StudentToolItem {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final List<Color> gradient;
  final Color borderAccent;
  final VoidCallback onTap;

  const _StudentToolItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.borderAccent,
    required this.onTap,
  });
}

class _StudentToolCard extends StatelessWidget {
  final _StudentToolItem tool;
  final bool isDark;

  const _StudentToolCard({
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

// ── Next Class / Live Lesson Countdown Radar ──
class LiveCountdownHeroCard extends StatefulWidget {
  final bool isLoading;
  final StudyLessonSummary? lesson;
  final StudentGamificationSummary? gamification;
  final VoidCallback? onOpen;
  final VoidCallback? onNavigateToCourses;
  final String? groupName;

  const LiveCountdownHeroCard({
    super.key,
    required this.isLoading,
    required this.lesson,
    required this.gamification,
    required this.onOpen,
    this.onNavigateToCourses,
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

    // Compact Idle State when no lesson is assigned yet
    if (widget.lesson == null) {
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
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
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
                        'جدولك الأكاديمي جاهز',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'محدّث 🟢',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.groupName != null
                        ? 'أنت ملتحق بـ: ${widget.groupName} • الدروس جاهزة'
                        : 'لا توجد حصص مباشرة جارية حالياً • يمكنك استعراض المناهج',
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text(
                'المناهج',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              onPressed: widget.onNavigateToCourses,
            ),
          ],
        ),
      );
    }

    final hasScheduledUpcoming = _targetClassTime != null && _remaining.inSeconds > 0;
    final isLiveNow = _targetClassTime != null && _remaining.inSeconds <= 0;
    final isStartingSoon = hasScheduledUpcoming && _remaining.inMinutes < 60;

    final days = math.max(0, _remaining.inDays);
    final hours = math.max(0, _remaining.inHours % 24);
    final minutes = math.max(0, _remaining.inMinutes % 60);
    final seconds = math.max(0, _remaining.inSeconds % 60);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isLiveNow
              ? [const Color(0xFF991B1B), const Color(0xFF450A0A)]
              : [
                  AppColors.primary,
                  HSLColor.fromColor(AppColors.primary)
                      .withLightness(
                        math.max(
                          0.0,
                          HSLColor.fromColor(AppColors.primary).lightness - 0.14,
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
              alpha: isDark ? 0.35 : 0.18,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Status & Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                            : (isStartingSoon ? Colors.amberAccent : Colors.greenAccent),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLiveNow
                          ? 'الحصة جارية الآن! 🔴'
                          : (hasScheduledUpcoming
                              ? (isStartingSoon ? 'أقل من ساعة على البداية! ⏳' : 'الحصة القادمة بعد')
                              : 'الدرس متاح للمتابعة 🟢'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Smart Reminder Toggle
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: _toggleReminder,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _reminderEnabled
                          ? Colors.amber.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: _reminderEnabled ? Colors.amberAccent : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _reminderEnabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: _reminderEnabled ? Colors.amberAccent : Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _reminderEnabled ? 'منبه مفعّل 🔔' : 'تنبيه (15 د)',
                          style: TextStyle(
                            color: _reminderEnabled ? Colors.amberAccent : Colors.white,
                            fontSize: 10.5,
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

          const SizedBox(height: 14),

          // Countdown Ticker (when scheduled in future)
          if (hasScheduledUpcoming) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                  _buildCountdownUnit('$seconds'.padLeft(2, '0'), 'ثانية', isPulsing: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Lesson Title
          Text(
            widget.isLoading
                ? 'جاري التحميل...'
                : (widget.lesson?.title ?? 'لا توجد دروس متاحة حالياً'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Unit & Estimated duration
          Text(
            widget.isLoading
                ? ''
                : '${widget.lesson!.unitName}  ·  ${widget.lesson!.estimatedMinutes} دقيقة${widget.groupName != null ? "  ·  🏛️ ${widget.groupName}" : ""}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Lesson Progress Bar
          if (!widget.isLoading && widget.lesson != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: widget.lesson!.progress.clamp(0.0, 1.0),
                backgroundColor: Colors.black26,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'تم إنجاز ${widget.lesson!.progressPercentage}% من محتوى الدرس',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isLiveNow ? Colors.red.shade900 : AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.onOpen,
              icon: Icon(
                isLiveNow ? Icons.sensors_rounded : Icons.play_arrow_rounded,
                size: 18,
              ),
              label: Text(
                widget.onOpen == null
                    ? 'لا يوجد درس متاح'
                    : (isLiveNow ? 'انضم إلى الحصة المباشرة الآن! 🔴' : 'ابدأ مذاكرة الدرس 🚀'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
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
          fontSize: 16,
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
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isPulsing ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(8),
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
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Urgent Pending Homework Card ──
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
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        color: surfaceColor,
        borderColor: borderColor,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment_late_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homework.homework.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'تاريخ التسليم: ${DateFormat.yMMMd().format(homework.homework.dueAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gamification Card ──
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
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      color: surfaceColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Streak Fire Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF451A03), const Color(0xFF2E1065)]
                    : [const Color(0xFFFEF3C7), const Color(0xFFF3E8FF)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 15)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حماسك مشتعل: ${summary.streakDays} أيام متتالية!',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const Text(
                        'حافظ على استمرارية المذاكرة اليومية لمضاعفة نقاط الـ XP',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Level & XP Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المستوى ${summary.level} (طالب متميز)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              Text(
                '${summary.totalXp} XP (متبقي ${summary.xpToNextLevel} XP)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (summary.levelProgressPercentage / 100.0).clamp(0.0, 1.0),
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),

          // Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadgePill('⭐ مثابر يومي', Colors.amber),
              _buildBadgePill('📝 مسلّم الواجبات', Colors.teal),
              _buildBadgePill('🎯 دقيق الحضور', Colors.indigo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgePill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ── Interactive Flashcard Review Deck ──
class QuickReviewFlashcardDeck extends StatefulWidget {
  final StudyLessonSummary lesson;
  final String groupName;

  const QuickReviewFlashcardDeck({
    super.key,
    required this.lesson,
    required this.groupName,
  });

  @override
  State<QuickReviewFlashcardDeck> createState() => _QuickReviewFlashcardDeckState();
}

class _QuickReviewFlashcardDeckState extends State<QuickReviewFlashcardDeck> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  final List<Map<String, String>> _flashcards = [
    {
      'question': 'ما هو المفهوم الجوهري الأول للحصة الحالية؟',
      'answer': 'استيعاب الأساسيات وتطبيق المعادلات الرئيسية مع التركيز على الأمثلة العملية.',
      'tag': 'مفهوم أساسي',
    },
    {
      'question': 'ما هي أهم نقطة تحذيرية يقع فيها أغلب الطلاب في المسائل؟',
      'answer': 'التسرع في التعويض دون التأكد من توحيد الوحدات ومراعاة الاتجاهات.',
      'tag': 'تنبيه امتحاني',
    },
    {
      'question': 'كيف تضمن الحصول على الدرجة النهائية في واجب اليوم؟',
      'answer': 'كتابة خطوات الحل النموذجية كاملة، وتوضيح القانون المستخدم بوضوح.',
      'tag': 'نصيحة ذهبية',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = _flashcards[_currentIndex];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card['tag'] ?? 'بطاقة ذكية',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                '${_currentIndex + 1} / ${_flashcards.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isFlipped = !_isFlipped);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _isFlipped ? '💡 الإجابة والتوضيح:' : '❓ السؤال السريع:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isFlipped ? Colors.green : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFlipped ? card['answer']! : card['question']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isFlipped ? 'اضغط لقلب البطاقة للوجه الآخر' : 'اضغط لإظهار الإجابة النموذجية 🔄',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _currentIndex > 0
                    ? () => setState(() {
                          _currentIndex--;
                          _isFlipped = false;
                        })
                    : null,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 12),
                label: const Text('السابقة', style: TextStyle(fontSize: 11.5)),
              ),
              TextButton.icon(
                onPressed: _currentIndex < _flashcards.length - 1
                    ? () => setState(() {
                          _currentIndex++;
                          _isFlipped = false;
                        })
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                label: const Text('التالية', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
