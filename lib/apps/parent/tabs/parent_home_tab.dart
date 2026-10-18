import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/payments/domain/models/payment_models.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';

// ─── Shared Models for Parent Portal ──────────────────────────────────────────

class ParentScheduleItem {
  final String id;
  final String subjectName;
  final String groupName;
  final String teacherName;
  final String location;
  final String? startTime;
  final String? endTime;
  final DateTime? sessionDate;
  final int? dayOfWeek;
  final String status;

  const ParentScheduleItem({
    required this.id,
    required this.subjectName,
    required this.groupName,
    required this.teacherName,
    required this.location,
    this.startTime,
    this.endTime,
    this.sessionDate,
    this.dayOfWeek,
    required this.status,
  });

  String get formattedTiming {
    final time = (startTime != null && endTime != null)
        ? '$startTime - $endTime'
        : (startTime ?? 'الموعد المحدد');
    final dateStr = sessionDate != null
        ? '${sessionDate!.day}/${sessionDate!.month}'
        : _dayName(dayOfWeek ?? 6);
    return '$dateStr • $time';
  }

  static String _dayName(int day) {
    return switch (day) {
      6 => 'السبت',
      7 || 0 => 'الأحد',
      1 => 'الإثنين',
      2 => 'الثلاثاء',
      3 => 'الأربعاء',
      4 => 'الخميس',
      5 => 'الجمعة',
      _ => 'يوم الحصة',
    };
  }

  String get statusLabel => switch (status.toLowerCase()) {
    'scheduled' || 'active' => 'مجدولة',
    'cancelled' => 'ملغاة',
    'completed' => 'مكتملة',
    'in_progress' => 'جارية الآن',
    _ => status,
  };

  factory ParentScheduleItem.fromJson(Map json) {
    DateTime? sessionDate =
        DateTime.tryParse(json['session_date']?.toString() ?? '');
    final dayOfWeek = (json['day_of_week'] as num?)?.toInt();
    if (sessionDate == null && dayOfWeek != null) {
      final now = DateTime.now();
      final currentWeekday = now.weekday;
      final targetWeekday = (dayOfWeek == 0 || dayOfWeek == 7) ? 7 : dayOfWeek;
      int daysUntil = targetWeekday - currentWeekday;
      if (daysUntil < 0) daysUntil += 7;
      sessionDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: daysUntil));
    }
    return ParentScheduleItem(
      id: json['class_session_id']?.toString() ??
          json['schedule_id']?.toString() ??
          json['id']?.toString() ??
          '',
      subjectName: json['subject_name']?.toString() ?? 'حصة دراسية',
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      teacherName: json['teacher_name']?.toString() ?? 'معلم المادة',
      location: json['location']?.toString() ??
          json['room_name']?.toString() ??
          'القاعة الرئيسية',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      sessionDate: sessionDate,
      dayOfWeek: dayOfWeek,
      status: json['status']?.toString() ?? 'scheduled',
    );
  }
}

class ParentAttendanceItem {
  final String id;
  final String classSessionId;
  final String status;
  final DateTime? markedAt;
  final DateTime? sessionDate;
  final String groupName;
  final String groupCode;
  final DateTime? checkOutAt;

  const ParentAttendanceItem({
    required this.id,
    required this.classSessionId,
    required this.status,
    required this.markedAt,
    required this.sessionDate,
    required this.groupName,
    required this.groupCode,
    this.checkOutAt,
  });

  factory ParentAttendanceItem.fromJson(Map json) {
    return ParentAttendanceItem(
      id: json['id']?.toString() ?? '',
      classSessionId: json['class_session_id']?.toString() ?? '',
      status: json['attendance_status']?.toString() ?? 'unknown',
      markedAt: DateTime.tryParse(
        json['marked_at']?.toString() ?? json['check_in_at']?.toString() ?? '',
      ),
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? ''),
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      groupCode: json['group_code']?.toString() ?? '',
      checkOutAt: DateTime.tryParse(json['check_out_at']?.toString() ?? ''),
    );
  }
}

class ParentInsight {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const ParentInsight({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

// ─── Executive Parent Home Tab ────────────────────────────────────────────────

class ParentHomeTab extends StatelessWidget {
  final Student? child;
  final List<Student> linkedChildren;
  final ValueChanged<Student> onChildSelected;
  final VoidCallback onLinkNewChild;
  final List<ParentAttendanceItem> attendance;
  final StudentLearningSnapshot? learningSnapshot;
  final FinancialSummary? financialSummary;
  final List<Invoice> invoices;
  final List<GroupEntity> childGroups;
  final int unreadCount;
  final ParentScheduleItem? nextClassSession;
  final VoidCallback onExcuseRequest;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenWhatsApp;

  const ParentHomeTab({
    super.key,
    required this.child,
    required this.linkedChildren,
    required this.onChildSelected,
    required this.onLinkNewChild,
    required this.attendance,
    required this.learningSnapshot,
    required this.financialSummary,
    required this.invoices,
    required this.childGroups,
    required this.unreadCount,
    required this.nextClassSession,
    required this.onExcuseRequest,
    required this.onOpenSchedule,
    required this.onOpenAttendance,
    required this.onOpenProgress,
    required this.onOpenPayments,
    required this.onOpenNotifications,
    required this.onOpenWhatsApp,
  });

  double _averageProgress() {
    final lessons = learningSnapshot?.availableLessons ?? [];
    if (lessons.isEmpty) return 0;
    final total = lessons.fold<int>(
      0,
      (sum, lesson) => sum + lesson.progressPercentage,
    );
    return total / lessons.length;
  }

  double _attendanceRate() {
    if (attendance.isEmpty) return 0;
    final present = attendance
        .where((item) => item.status == 'present' || item.status == 'late')
        .length;
    return present * 100 / attendance.length;
  }

  static String _formatMoney(int minor, String? currency) {
    final amount = minor / 100;
    final curr = currency ?? 'ج.م';
    if (amount == amount.roundToDouble()) {
      return '${amount.toInt()} $curr';
    }
    return '${amount.toStringAsFixed(2)} $curr';
  }

  List<ParentInsight> _buildInsights() {
    final insights = <ParentInsight>[];
    final attendanceRate = _attendanceRate();
    final progress = _averageProgress();
    final balance = financialSummary?.remainingBalanceMinor ?? 0;
    final absentCount = attendance
        .where((item) => item.status == 'absent')
        .length;
    final overdueInvoices = invoices
        .where((invoice) => invoice.status == 'overdue')
        .length;

    if (attendanceRate < 75 && attendance.isNotEmpty) {
      insights.add(
        ParentInsight(
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          title: 'متابعة نسبة الحضور والغياب',
          body:
              'نسبة الحضور الحالية ${attendanceRate.round()}% مع تسجيل $absentCount مرات غياب.',
        ),
      );
    }
    if (progress < 40 && (learningSnapshot?.availableLessons.isNotEmpty ?? false)) {
      insights.add(
        ParentInsight(
          icon: Icons.menu_book_rounded,
          color: AppColors.warning,
          title: 'مستوى التقدم الدراسي بحاجة لمتابعة',
          body: 'متوسط إنجاز المناهج والدروس ${progress.round()}% فقط.',
        ),
      );
    }
    if (balance > 0) {
      insights.add(
        ParentInsight(
          icon: Icons.payments_rounded,
          color: overdueInvoices > 0 ? AppColors.error : AppColors.warning,
          title: overdueInvoices > 0
              ? 'متأخرات مالية مستحقة السداد'
              : 'رسوم دراسية مستحقة السداد',
          body:
              'المتبقي للسداد: ${_formatMoney(balance, financialSummary?.currency)}.',
        ),
      );
    }
    if (unreadCount > 0) {
      insights.add(
        ParentInsight(
          icon: Icons.notifications_active_rounded,
          color: AppColors.parentRole,
          title: 'تنبيهات وإشعارات جديدة',
          body: 'لديك $unreadCount إشعارات غير مقروءة من السنتر.',
        ),
      );
    }
    if (insights.isEmpty) {
      insights.add(
        const ParentInsight(
          icon: Icons.verified_rounded,
          color: AppColors.success,
          title: 'المستوى ممتاز ومستقر',
          body: 'الحضور والتحصيل الدراسي والمدفوعات منتظمة دون أي ملاحظات.',
        ),
      );
    }
    return insights;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _averageProgress();
    final attendanceRate = _attendanceRate();
    final balance = financialSummary?.remainingBalanceMinor ?? 0;
    final insights = _buildInsights();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 360;
        final isDesktop = screenWidth >= 900;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Interactive Child Switcher Hub ────────────────────────
            if (linkedChildren.length > 1) ...[
              _ExecutiveChildSwitcherBar(
                children: linkedChildren,
                selectedChild: child,
                isDark: isDark,
                onChildSelected: onChildSelected,
                onLinkNewChild: onLinkNewChild,
              ),
              const SizedBox(height: 14),
            ],

            // ── 2. Smart Live Presence Radar Hero ────────────────────────
            _ExecutiveLivePresenceCard(
              child: child,
              attendance: attendance,
              learningSnapshot: learningSnapshot,
              isDark: isDark,
              isNarrow: isNarrow,
              onExcuseRequest: onExcuseRequest,
            ),
            const SizedBox(height: 16),

            // ── 3. Quick Actions Hub ─────────────────────────────────────
            _ExecutiveQuickActionsGrid(
              isDark: isDark,
              isNarrow: isNarrow,
              isDesktop: isDesktop,
              onOpenSchedule: onOpenSchedule,
              onOpenAttendance: onOpenAttendance,
              onOpenProgress: onOpenProgress,
              onOpenWhatsApp: onOpenWhatsApp,
            ),
            const SizedBox(height: 18),

            // ── 4. Executive KPI Overview Metrics ────────────────────────
            _ExecutiveKpiMetrics(
              progress: progress,
              attendanceRate: attendanceRate,
              balance: balance,
              currency: financialSummary?.currency ?? 'ج.م',
              unreadCount: unreadCount,
              isDark: isDark,
              onOpenProgress: onOpenProgress,
              onOpenAttendance: onOpenAttendance,
              onOpenPayments: onOpenPayments,
              onOpenNotifications: onOpenNotifications,
            ),
            const SizedBox(height: 18),

            // ── 5. Next Class / Upcoming Lesson Card ─────────────────────
            _UpcomingClassHeroBanner(
              nextClass: nextClassSession,
              nextLesson: learningSnapshot?.nextLesson,
              isDark: isDark,
              isNarrow: isNarrow,
              onOpenSchedule: onOpenSchedule,
            ),
            const SizedBox(height: 18),

            // ── 6. Executive AI Insights Panel ───────────────────────────
            _ExecutiveInsightsCard(
              insights: insights,
              isDark: isDark,
            ),
            const SizedBox(height: 18),

            // ── 7. Active Enrolled Groups ────────────────────────────────
            _ActiveGroupsSection(
              childGroups: childGroups,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }
}

// ─── 1. Executive Child Switcher Bar ──────────────────────────────────────────

class _ExecutiveChildSwitcherBar extends StatelessWidget {
  final List<Student> children;
  final Student? selectedChild;
  final bool isDark;
  final ValueChanged<Student> onChildSelected;
  final VoidCallback onLinkNewChild;

  const _ExecutiveChildSwitcherBar({
    required this.children,
    required this.selectedChild,
    required this.isDark,
    required this.onChildSelected,
    required this.onLinkNewChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_rounded,
                size: 16,
                color: AppColors.parentRole,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'التبديل بين الأبناء:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: onLinkNewChild,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 14),
                label: const Text(
                  'ربط طالب',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final student = children[i];
                final isSelected = selectedChild?.id == student.id;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onChildSelected(student);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.parentRole.withValues(alpha: isDark ? 0.22 : 0.12)
                            : (isDark
                                ? const Color(0xFF161616)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.parentRole
                              : (isDark
                                  ? const Color(0xFF262626)
                                  : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.parentRole.withValues(alpha: 0.15),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 15,
                              color: AppColors.parentRole,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                student.fullName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.parentRole
                                      : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                              Text(
                                student.studentCode,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

// ─── 2. Smart Live Presence Radar Hero Card ───────────────────────────────────

class _ExecutiveLivePresenceCard extends StatefulWidget {
  final Student? child;
  final List<ParentAttendanceItem> attendance;
  final StudentLearningSnapshot? learningSnapshot;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback onExcuseRequest;

  const _ExecutiveLivePresenceCard({
    required this.child,
    required this.attendance,
    required this.learningSnapshot,
    required this.isDark,
    required this.isNarrow,
    required this.onExcuseRequest,
  });

  @override
  State<_ExecutiveLivePresenceCard> createState() =>
      _ExecutiveLivePresenceCardState();
}

class _ExecutiveLivePresenceCardState extends State<_ExecutiveLivePresenceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (child == null) return const SizedBox.shrink();

    final now = DateTime.now();
    ParentAttendanceItem? todayItem;
    for (final item in widget.attendance) {
      final date = item.sessionDate ?? item.markedAt;
      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        todayItem = item;
        break;
      }
    }

    final isPresent = todayItem != null &&
        (todayItem.status == 'present' || todayItem.status == 'late') &&
        todayItem.checkOutAt == null;
    final isCheckedOut = todayItem != null && todayItem.checkOutAt != null;
    final isAbsent = todayItem != null && todayItem.status == 'absent';

    Color cardBg;
    Color accentColor;
    String statusTitle;
    String statusSubtitle;
    String badgeText;

    if (isPresent) {
      cardBg = const Color(0xFF064E3B).withValues(alpha: widget.isDark ? 0.25 : 0.12);
      accentColor = const Color(0xFF10B981);
      statusTitle = 'الطالب متواجد في القاعة الدراسية الآن 🏫';
      final timeStr = todayItem.markedAt != null
          ? '${todayItem.markedAt!.hour.toString().padLeft(2, '0')}:${todayItem.markedAt!.minute.toString().padLeft(2, '0')}'
          : '';
      final elapsedMinutes = todayItem.markedAt != null
          ? now.difference(todayItem.markedAt!).inMinutes
          : 0;
      statusSubtitle =
          'سجل حضور $timeStr • ${todayItem.groupName} • منذ $elapsedMinutes دقيقة ⏱️';
      badgeText = 'داخل السنتر الآن 🟢';
    } else if (isCheckedOut) {
      cardBg = const Color(0xFF1E3A8A).withValues(alpha: widget.isDark ? 0.25 : 0.12);
      accentColor = const Color(0xFF3B82F6);
      statusTitle = 'غادر السنتر بأمان بعد الحصة 👋';
      final outTime = todayItem.checkOutAt != null
          ? '${todayItem.checkOutAt!.hour.toString().padLeft(2, '0')}:${todayItem.checkOutAt!.minute.toString().padLeft(2, '0')}'
          : '';
      statusSubtitle = 'تم تسجيل الانصراف $outTime • نتمنى له عودة سالمة للبيت 🏠';
      badgeText = 'انصرف بنجاح ✔️';
    } else if (isAbsent) {
      cardBg = const Color(0xFF7F1D1D).withValues(alpha: widget.isDark ? 0.30 : 0.14);
      accentColor = const Color(0xFFEF4444);
      statusTitle = 'تنبيه غياب: لم يسجل حضوراً اليوم ⚠️';
      statusSubtitle =
          'حصة ${todayItem.groupName} المقررة لم يتم رصد حضور الطالب بها بالبوابة حتى الآن';
      badgeText = 'غياب غير مسجل بعذر 🔴';
    } else {
      cardBg = AppColors.parentRole.withValues(alpha: widget.isDark ? 0.16 : 0.08);
      accentColor = AppColors.parentRole;
      statusTitle = 'رادار التواجد ومتابعة الدخول والخروج';
      final next = widget.learningSnapshot?.nextLesson;
      statusSubtitle = next != null
          ? 'الحصة القادمة: ${next.title} (${next.pathName})'
          : 'لا توجد حصص مسجلة لليوم.';
      badgeText = 'في الانتظار ⏳';
    }

    return Container(
      padding: EdgeInsets.all(widget.isNarrow ? 14 : 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Radar/Icon + Title + Badge (with adaptive Wrap)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPresent)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 22 + (_pulseAnimation.value * 18),
                            height: 22 + (_pulseAnimation.value * 18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withValues(
                                alpha: (1.0 - _pulseAnimation.value) * 0.45,
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isAbsent
                        ? Icons.warning_amber_rounded
                        : (isCheckedOut
                            ? Icons.directions_walk_rounded
                            : Icons.school_rounded),
                    color: accentColor,
                    size: 20,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          statusTitle,
                          style: TextStyle(
                            fontSize: widget.isNarrow ? 13 : 14.5,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        fontSize: widget.isNarrow ? 11 : 12,
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Safe Verified Pill (Guaranteed zero-overflow)
          if (isPresent) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF10B981),
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'حضور موثق بالبوابة الإلكترونية الذكية للسنتر • القاعة مؤمنة بالكامل 🛡️',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Excuse Action Button (If absent)
          if (isAbsent) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: widget.onExcuseRequest,
                icon: const Icon(Icons.note_add_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'تقديم عذر غياب فوري مع تقرير طبي أو ورقي 📝',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 3. Quick Actions Hub ─────────────────────────────────────────────────────

class _ExecutiveQuickActionsGrid extends StatelessWidget {
  final bool isDark;
  final bool isNarrow;
  final bool isDesktop;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenWhatsApp;

  const _ExecutiveQuickActionsGrid({
    required this.isDark,
    required this.isNarrow,
    required this.isDesktop,
    required this.onOpenSchedule,
    required this.onOpenAttendance,
    required this.onOpenProgress,
    required this.onOpenWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ParentActionItem(
        title: 'جدول الحصص',
        subtitle: 'المواعيد والقاعات',
        badge: 'مواعيد 📅',
        icon: Icons.calendar_month_rounded,
        gradient: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
        borderAccent: const Color(0xFF38BDF8),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenSchedule();
        },
      ),
      _ParentActionItem(
        title: 'سجل الحضور',
        subtitle: 'نسبة الالتزام والغياب',
        badge: 'متابعة 📊',
        icon: Icons.fact_check_rounded,
        gradient: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
        borderAccent: const Color(0xFF14B8A6),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenAttendance();
        },
      ),
      _ParentActionItem(
        title: 'الواجبات والدرجات',
        subtitle: 'متابعة الحل والتسليم',
        badge: 'أكاديمي ✍️',
        icon: Icons.assignment_rounded,
        gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        borderAccent: const Color(0xFF818CF8),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenProgress();
        },
      ),
      _ParentActionItem(
        title: 'خدمة أولياء الأمور',
        subtitle: 'تواصل مباشر مع الإدارة',
        badge: 'دعم 💬',
        icon: Icons.chat_rounded,
        gradient: const [Color(0xFF059669), Color(0xFF10B981)],
        borderAccent: const Color(0xFF10B981),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenWhatsApp();
        },
      ),
    ];

    final crossAxisCount = isDesktop ? 4 : 2;
    final mainExtent = isDesktop ? 104.0 : 100.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: mainExtent,
      ),
      itemBuilder: (context, i) {
        return _ParentActionCard(
          action: actions[i],
          isDark: isDark,
          isNarrow: isNarrow,
        );
      },
    );
  }
}

class _ParentActionItem {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final List<Color> gradient;
  final Color borderAccent;
  final VoidCallback onTap;

  const _ParentActionItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.borderAccent,
    required this.onTap,
  });
}

class _ParentActionCard extends StatelessWidget {
  final _ParentActionItem action;
  final bool isDark;
  final bool isNarrow;

  const _ParentActionCard({
    required this.action,
    required this.isDark,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 10 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.95)
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: action.borderAccent.withValues(alpha: isDark ? 0.35 : 0.22),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: action.borderAccent.withValues(alpha: isDark ? 0.10 : 0.05),
                blurRadius: 8,
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: action.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: action.gradient.first.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(action.icon, color: Colors.white, size: 16),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: action.borderAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: action.borderAccent.withValues(alpha: 0.25),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        action.badge,
                        style: TextStyle(
                          color: action.borderAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: isNarrow ? 12 : 12.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontSize: 9.5,
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

// ─── 4. Executive KPI Overview Metrics ────────────────────────────────────────

class _ExecutiveKpiMetrics extends StatelessWidget {
  final double progress;
  final double attendanceRate;
  final int balance;
  final String currency;
  final int unreadCount;
  final bool isDark;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenNotifications;

  const _ExecutiveKpiMetrics({
    required this.progress,
    required this.attendanceRate,
    required this.balance,
    required this.currency,
    required this.unreadCount,
    required this.isDark,
    required this.onOpenProgress,
    required this.onOpenAttendance,
    required this.onOpenPayments,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return PortalMetricGrid(
      children: [
        PortalMetricCard(
          label: 'مستوى التقدم الدراسي',
          value: '${progress.round()}%',
          icon: Icons.trending_up_rounded,
          accentColor: AppColors.success,
          onTap: onOpenProgress,
        ),
        PortalMetricCard(
          label: 'نسبة الحضور والالتزام',
          value: '${attendanceRate.round()}%',
          icon: Icons.fact_check_rounded,
          accentColor: AppColors.info,
          onTap: onOpenAttendance,
        ),
        PortalMetricCard(
          label: 'المستحقات المتبقية',
          value: ParentHomeTab._formatMoney(balance, currency),
          icon: Icons.account_balance_wallet_rounded,
          accentColor: balance > 0 ? AppColors.warning : AppColors.success,
          onTap: onOpenPayments,
        ),
        PortalMetricCard(
          label: 'تنبيهات غير مقروءة',
          value: unreadCount.toString(),
          icon: Icons.notifications_active_rounded,
          accentColor: AppColors.parentRole,
          onTap: onOpenNotifications,
        ),
      ],
    );
  }
}

// ─── 5. Upcoming Class / Next Lesson Hero Banner ──────────────────────────────

class _UpcomingClassHeroBanner extends StatelessWidget {
  final ParentScheduleItem? nextClass;
  final StudyLessonSummary? nextLesson;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback onOpenSchedule;

  const _UpcomingClassHeroBanner({
    required this.nextClass,
    required this.nextLesson,
    required this.isDark,
    required this.isNarrow,
    required this.onOpenSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'الحصة القادمة والمواعيد',
                subtitle: 'الحصة الدراسية القادمة ومكان انعقادها بالسنتر.',
              ),
            ),
            TextButton.icon(
              onPressed: onOpenSchedule,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text(
                'جدول المواعيد',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (nextClass != null)
          GlassCard(
            padding: EdgeInsets.all(isNarrow ? 12 : 16),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: AppColors.primary.withValues(alpha: 0.35),
            child: InkWell(
              onTap: onOpenSchedule,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.access_time_filled_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '${nextClass!.subjectName} (${nextClass!.groupName})',
                                style: TextStyle(
                                  fontSize: isNarrow ? 13 : 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            PortalStatusChip(status: nextClass!.statusLabel),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (nextClass!.location.isNotEmpty)
                              _buildHeroChip(
                                icon: Icons.place_rounded,
                                text: nextClass!.location,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            if (nextClass!.teacherName.isNotEmpty)
                              _buildHeroChip(
                                icon: Icons.person_outline_rounded,
                                text: nextClass!.teacherName,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            if (nextClass!.formattedTiming.isNotEmpty)
                              _buildHeroChip(
                                icon: Icons.schedule_rounded,
                                text: nextClass!.formattedTiming,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (nextLesson != null)
          PortalListCard(
            icon: nextLesson!.hasPdf ? Icons.picture_as_pdf : Icons.menu_book,
            accentColor: AppColors.studentRole,
            title: nextLesson!.title,
            subtitle:
                '${nextLesson!.pathName} • ${nextLesson!.unitName} • ${nextLesson!.progressPercentage}%',
            trailing: [
              PortalStatusChip(status: nextLesson!.hasPdf ? 'ملف PDF' : 'شرح'),
            ],
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: Colors.grey.withValues(alpha: 0.6),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لا توجد حصص قادمة مجدولة اليوم',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تابع جدول المواعيد للاطلاع على كامل مواعيد الأسبوع.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String text,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 6. Executive AI Insights Panel ───────────────────────────────────────────

class _ExecutiveInsightsCard extends StatelessWidget {
  final List<ParentInsight> insights;
  final bool isDark;

  const _ExecutiveInsightsCard({
    required this.insights,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'توجيهات وملاحظات ولي الأمر الذكية',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'نقاط متابعة هامة مستخلصة من أداء الطالب الفعلي.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: insight.color.withValues(alpha: isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: insight.color.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(insight.icon, color: insight.color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.body,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 7. Active Enrolled Groups ────────────────────────────────────────────────

class _ActiveGroupsSection extends StatelessWidget {
  final List<GroupEntity> childGroups;
  final bool isDark;

  const _ActiveGroupsSection({
    required this.childGroups,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(
          title: 'المجموعات والفصول الدراسية النشطة',
          subtitle: 'المجموعات المسجل بها الطالب حالياً بالسنتر والمدرس المشرف.',
        ),
        const SizedBox(height: 8),
        if (childGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.group_off_rounded,
                  color: Colors.grey.withValues(alpha: 0.5),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لا توجد مجموعات نشطة مسجلة لهذا الطالب حالياً.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: childGroups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final group = childGroups[i];
              return PortalListCard(
                icon: Icons.group_work_rounded,
                accentColor: AppColors.info,
                title: group.name,
                subtitle: '${group.code} • ${group.status}',
                trailing: [PortalStatusChip(status: group.status)],
              );
            },
          ),
      ],
    );
  }
}
