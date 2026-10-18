import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/assessment/presentation/widgets/student_blitz_quiz_dialog.dart';
import '../student_dashboard_models.dart';

String _formatDate(DateTime? dt) {
  if (dt == null) return '';
  try {
    return DateFormat.yMMMd().format(dt);
  } catch (_) {
    return '${dt.year}/${dt.month}/${dt.day}';
  }
}

String _formatTime(DateTime? dt) {
  if (dt == null) return '';
  try {
    return DateFormat.jm().format(dt);
  } catch (_) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

String _availabilityLabel(BuildContext context, String status) {
  return switch (status) {
    'not_started' => 'لم تبدأ بعد',
    'expired' => 'انتهى الوقت المحدد',
    'closed' => 'مغلق',
    'available' => 'متاح الآن',
    'submitted' => 'تم التسليم',
    'graded' => 'تم التصحيح',
    _ => context.tr(status),
  };
}

Color _attendanceColor(String status) {
  switch (status) {
    case 'present':
      return AppColors.success;
    case 'late':
      return AppColors.warning;
    case 'absent':
      return AppColors.error;
    case 'excused':
      return AppColors.info;
    default:
      return AppColors.darkBorder;
  }
}

IconData _attendanceIcon(String status) {
  switch (status) {
    case 'present':
      return Icons.check_circle_rounded;
    case 'late':
      return Icons.schedule_rounded;
    case 'absent':
      return Icons.cancel_rounded;
    case 'excused':
      return Icons.event_available_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

String _attendanceLabel(String status) {
  switch (status) {
    case 'present':
      return 'حاضر في الموعد';
    case 'late':
      return 'تأخير مسجل';
    case 'absent':
      return 'غياب';
    case 'excused':
      return 'إذن معذور';
    default:
      return status;
  }
}

Color _leaveColor(String status) {
  switch (status) {
    case 'approved':
      return AppColors.success;
    case 'rejected':
      return AppColors.error;
    default:
      return AppColors.warning;
  }
}

String _leaveLabel(String status) {
  switch (status) {
    case 'approved':
      return 'تمت الموافقة ✅';
    case 'rejected':
      return 'تم الرفض ❌';
    default:
      return 'قيد المراجعة ⏳';
  }
}

class ActivityTab extends StatefulWidget {
  final bool isLoading;
  final List<StudentHomeworkItem> homeworkItems;
  final List<StudentExamItem> examItems;
  final List<StudentAttendanceItem> attendanceItems;
  final List<StudentLeaveItem> leaveItems;
  final List<PublishedSessionBoard> sessionBoards;
  final ValueChanged<StudentHomeworkItem> onSubmitHomework;
  final ValueChanged<StudentExamItem> onStartExam;
  final VoidCallback onCreateLeaveRequest;
  final VoidCallback onScanQr;
  final ValueChanged<PublishedSessionBoard> onOpenBoard;

  const ActivityTab({
    super.key,
    required this.isLoading,
    required this.homeworkItems,
    required this.examItems,
    required this.attendanceItems,
    required this.leaveItems,
    required this.sessionBoards,
    required this.onSubmitHomework,
    required this.onStartExam,
    required this.onCreateLeaveRequest,
    required this.onScanQr,
    required this.onOpenBoard,
  });

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab>
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

    // Calculate core KPIs
    final pendingHomework = widget.homeworkItems
        .where((h) => !h.isSubmitted && h.homework.isOpenForSubmission)
        .length;
    final availableExams = widget.examItems.where((e) => e.canStart).length;
    final totalAttendance = widget.attendanceItems.length;
    final presentCount = widget.attendanceItems
        .where((i) => i.status == 'present')
        .length;
    final lateCount = widget.attendanceItems
        .where((i) => i.status == 'late')
        .length;
    final excusedCount = widget.attendanceItems
        .where((i) => i.status == 'excused')
        .length;
    final attendanceRate = totalAttendance == 0
        ? 100
        : (((presentCount + lateCount + excusedCount) / totalAttendance) * 100)
            .round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final isNarrowMobile = screenWidth < 360;
        final hPadding = isNarrowMobile ? 12.0 : (isMobile ? 16.0 : 24.0);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                // ── Executive Header & Top KPIs ──
                Container(
                  color: bgColor,
                  padding: EdgeInsets.fromLTRB(hPadding, 14, hPadding, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.task_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الأنشطة والمهام',
                                  style: AppTypography.displaySmall(textPrimary)
                                      .copyWith(
                                    fontSize: isNarrowMobile ? 18 : 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pendingHomework > 0
                                      ? 'لديك $pendingHomework واجب بانتظار الحل ⚡'
                                      : 'جميع واجباتك مسلّمة بالكامل ✨',
                                  style: AppTypography.caption(textSecondary)
                                      .copyWith(
                                    fontSize: isNarrowMobile ? 10.5 : 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Quick QR scan button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onScanQr();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isNarrowMobile ? 8 : 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: isDark ? 0.15 : 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: isDark ? 0.35 : 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.qr_code_scanner_rounded,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                    if (!isNarrowMobile) ...[
                                      const SizedBox(width: 6),
                                      const Text(
                                        'مسح QR',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Activity Overview KPI Strip ──
                      _ActivityKpiGrid(
                        pendingHomework: pendingHomework,
                        availableExams: availableExams,
                        attendanceRate: attendanceRate,
                        boardsCount: widget.sessionBoards.length,
                        isMobile: isMobile,
                        isNarrow: isNarrowMobile,
                        onTabSelect: (tabIndex) {
                          HapticFeedback.selectionClick();
                          _tabCtrl.animateTo(tabIndex);
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── Modern Responsive Tab bar ──
                      Container(
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 0.7,
                          ),
                        ),
                        child: TabBar(
                          controller: _tabCtrl,
                          isScrollable: false,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.3 : 0.05,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: textPrimary,
                          unselectedLabelColor:
                              textPrimary.withValues(alpha: 0.6),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                          labelStyle: TextStyle(
                            fontSize: isNarrowMobile ? 10.5 : 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontSize: isNarrowMobile ? 10.5 : 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                          ),
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.assignment_rounded,
                                    size: isNarrowMobile ? 13 : 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      isMobile
                                          ? 'الواجبات'
                                          : 'الواجبات والاختبارات',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _CountBadge(
                                    count: widget.homeworkItems.length +
                                        widget.examItems.length,
                                    isHighlight: pendingHomework > 0,
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.co_present_rounded,
                                    size: isNarrowMobile ? 13 : 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      isMobile ? 'الحضور' : 'سجل الحضور',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _CountBadge(
                                    label: '$attendanceRate%',
                                    isHighlight: false,
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.draw_rounded,
                                    size: isNarrowMobile ? 13 : 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      isMobile ? 'السبورات' : 'سبورات الحصص',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _CountBadge(
                                    count: widget.sessionBoards.length,
                                    isHighlight: false,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _HomeworkAndExamsView(
                        isLoading: widget.isLoading,
                        homeworkItems: widget.homeworkItems,
                        examItems: widget.examItems,
                        onSubmitHomework: widget.onSubmitHomework,
                        onStartExam: widget.onStartExam,
                      ),
                      _AttendanceView(
                        isLoading: widget.isLoading,
                        attendanceItems: widget.attendanceItems,
                        leaveItems: widget.leaveItems,
                        onCreateLeaveRequest: widget.onCreateLeaveRequest,
                        onScanQr: widget.onScanQr,
                      ),
                      _SessionBoardsSection(
                        isLoading: widget.isLoading,
                        boards: widget.sessionBoards,
                        onOpenBoard: widget.onOpenBoard,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Small Count Badge for Tabs ──
class _CountBadge extends StatelessWidget {
  final int? count;
  final String? label;
  final bool isHighlight;

  const _CountBadge({
    this.count,
    this.label,
    required this.isHighlight,
  });

  @override
  Widget build(BuildContext context) {
    final text = label ?? (count?.toString() ?? '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.warning.withValues(alpha: 0.2)
            : AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: isHighlight ? AppColors.warning : AppColors.primary,
        ),
      ),
    );
  }
}

// ── Activity KPI Grid Strip ──
class _ActivityKpiGrid extends StatelessWidget {
  final int pendingHomework;
  final int availableExams;
  final int attendanceRate;
  final int boardsCount;
  final bool isMobile;
  final bool isNarrow;
  final ValueChanged<int> onTabSelect;

  const _ActivityKpiGrid({
    required this.pendingHomework,
    required this.availableExams,
    required this.attendanceRate,
    required this.boardsCount,
    required this.isMobile,
    required this.isNarrow,
    required this.onTabSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cards = [
      _KpiCardItem(
        label: 'واجبات مستحقة',
        value: '$pendingHomework',
        sublabel: pendingHomework > 0 ? 'بانتظار الحل' : 'مكتملة 🎉',
        icon: Icons.assignment_late_rounded,
        color: pendingHomework > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        onTap: () => onTabSelect(0),
        isDark: isDark,
        isNarrow: isNarrow,
      ),
      _KpiCardItem(
        label: 'اختبارات متاحة',
        value: '$availableExams',
        sublabel: availableExams > 0 ? 'متاحة للبدء' : 'لا اختبارات جارية',
        icon: Icons.quiz_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => onTabSelect(0),
        isDark: isDark,
        isNarrow: isNarrow,
      ),
      _KpiCardItem(
        label: 'نسبة الالتزام',
        value: '$attendanceRate%',
        sublabel: attendanceRate >= 85 ? 'ممتاز جداً 🌟' : 'يحتاج متابعة',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF06B6D4),
        onTap: () => onTabSelect(1),
        isDark: isDark,
        isNarrow: isNarrow,
      ),
      _KpiCardItem(
        label: 'سبورات الحصص',
        value: '$boardsCount',
        sublabel: 'شروحات تفاعلية',
        icon: Icons.draw_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () => onTabSelect(2),
        isDark: isDark,
        isNarrow: isNarrow,
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: isNarrow ? 1.7 : 2.0,
        children: cards,
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: c,
                ),
              ))
          .toList(),
    );
  }
}

class _KpiCardItem extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;
  final bool isNarrow;

  const _KpiCardItem({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isDark,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 8 : 12,
            vertical: isNarrow ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.2),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isNarrow ? 28 : 34,
                height: isNarrow ? 28 : 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: isNarrow ? 16 : 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isNarrow ? 14 : 16,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: isNarrow ? 9.5 : 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Assessment Review Dialog ──
Future<void> _showAssessmentReviewDialog(
  BuildContext context, {
  required String rpcName,
  required Map<String, dynamic> params,
}) async {
  var loaderVisible = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    ),
  );

  dynamic raw;
  try {
    raw = await Supabase.instance.client.rpc(rpcName, params: params);
  } catch (e) {
    if (context.mounted && loaderVisible) {
      Navigator.of(context).pop();
      loaderVisible = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم يتم إعلان تفاصيل النتيجة أو نموذج الإجابة بعد من قِبل المدرس.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  if (loaderVisible) {
    Navigator.of(context).pop();
    loaderVisible = false;
  }

  if (raw == null || raw is! Map) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('بيانات المراجعة غير متوفرة حالياً.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final review = Map<String, dynamic>.from(raw);
  final released = review['released'] == true;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textPrimary = isDark
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;
  final textSecondary = isDark
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;
  final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
  final answers = (review['answers'] as List<dynamic>? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.85;
      return Dialog(
        backgroundColor: surfaceColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640, maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: released
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.analytics_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review['title']?.toString() ?? 'مراجعة التقييم',
                                  style: AppTypography.titleLarge(textPrimary)
                                      .copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'الدرجة المستحقة: ${review['score'] ?? 0} / ${review['max_score'] ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      if ((review['teacher_feedback']?.toString() ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.feedback_outlined,
                                color: Colors.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ملاحظات المعلم: ${review['teacher_feedback']}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Answers list
                      Flexible(
                        child: answers.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    'لا توجد إجابات مسجلة لهذا التقييم.',
                                    style: AppTypography.bodyMedium(textSecondary),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: answers.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) {
                                  final answer = answers[index];
                                  final isCorrect = answer['is_correct'] == true;
                                  final color = isCorrect
                                      ? AppColors.success
                                      : AppColors.error;
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.06),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.35),
                                        width: 0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isCorrect
                                                  ? Icons.check_circle_rounded
                                                  : Icons.cancel_rounded,
                                              color: color,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                answer['prompt']?.toString() ?? '',
                                                style: AppTypography.bodyMedium(
                                                  textPrimary,
                                                ).copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${answer['points_awarded'] ?? 0}/${answer['max_points'] ?? 0} ن',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'إجابتك: ${answer['student_answer'] ?? 'لم تتم الإجابة'}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الإجابة النموذجية: ${answer['correct_answer'] ?? 'غير متوفرة'}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.success,
                                          ),
                                        ),
                                        if ((answer['explanation']?.toString() ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'التوضيح والشرح: ${answer['explanation']}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إغلاق النافذة'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        size: 52,
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        review['message']?.toString() ??
                            'لم يتم إعلان تفاصيل النتيجة ونموذج الإجابة بعد من قِبل المعلم.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(textPrimary).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1: الواجبات والاختبارات (Homework & Exams)
// ═════════════════════════════════════════════════════════════════════════════
class _HomeworkAndExamsView extends StatefulWidget {
  final bool isLoading;
  final List<StudentHomeworkItem> homeworkItems;
  final List<StudentExamItem> examItems;
  final ValueChanged<StudentHomeworkItem> onSubmitHomework;
  final ValueChanged<StudentExamItem> onStartExam;

  const _HomeworkAndExamsView({
    required this.isLoading,
    required this.homeworkItems,
    required this.examItems,
    required this.onSubmitHomework,
    required this.onStartExam,
  });

  @override
  State<_HomeworkAndExamsView> createState() => _HomeworkAndExamsViewState();
}

class _HomeworkAndExamsViewState extends State<_HomeworkAndExamsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, homework, exams, pending, graded

  @override
  void dispose() {
    _searchCtrl.dispose();
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

    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Filter homework
    final filteredHomework = widget.homeworkItems.where((h) {
      if (_selectedFilter == 'exams') return false;
      if (_selectedFilter == 'pending' && h.isSubmitted) return false;
      if (_selectedFilter == 'graded' && !h.isSubmitted) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchesTitle = h.homework.title.toLowerCase().contains(q);
        final matchesGroup = h.groupName.toLowerCase().contains(q);
        if (!matchesTitle && !matchesGroup) return false;
      }
      return true;
    }).toList();

    // Filter exams
    final filteredExams = widget.examItems.where((e) {
      if (_selectedFilter == 'homework') return false;
      if (_selectedFilter == 'pending' && !e.canStart) return false;
      if (_selectedFilter == 'graded' && !e.canReview) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchesTitle = e.exam.title.toLowerCase().contains(q);
        final matchesGroup = e.groupName.toLowerCase().contains(q);
        if (!matchesTitle && !matchesGroup) return false;
      }
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final isNarrow = width < 360;
        final hPadding = isNarrow ? 12.0 : (isMobile ? 16.0 : 20.0);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPadding, 12, hPadding, 32),
          children: [
            // ── Live Blitz Banner ──
            _buildLiveBlitzBanner(context, isDark, textPrimary, isNarrow),
            const SizedBox(height: 16),

            // ── Search & Filter Bar ──
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.8,
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(
                        fontSize: isNarrow ? 12 : 13,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        hintText: 'ابحث عن واجب أو اختبار أو مادة...',
                        hintStyle: TextStyle(
                          fontSize: isNarrow ? 11.5 : 12.5,
                          color: textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: textSecondary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'الكل',
                    count: widget.homeworkItems.length + widget.examItems.length,
                    isSelected: _selectedFilter == 'all',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'all');
                    },
                    isDark: isDark,
                  ),
                  _FilterPill(
                    label: 'الواجبات',
                    count: widget.homeworkItems.length,
                    isSelected: _selectedFilter == 'homework',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'homework');
                    },
                    isDark: isDark,
                  ),
                  _FilterPill(
                    label: 'الاختبارات',
                    count: widget.examItems.length,
                    isSelected: _selectedFilter == 'exams',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'exams');
                    },
                    isDark: isDark,
                  ),
                  _FilterPill(
                    label: 'يحتاج تسليم ⏳',
                    count: widget.homeworkItems
                        .where((h) => !h.isSubmitted && h.homework.isOpenForSubmission)
                        .length,
                    isSelected: _selectedFilter == 'pending',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'pending');
                    },
                    isDark: isDark,
                  ),
                  _FilterPill(
                    label: 'تم التسليم والمراجعة ✅',
                    count: widget.homeworkItems.where((h) => h.isSubmitted).length +
                        widget.examItems.where((e) => e.canReview).length,
                    isSelected: _selectedFilter == 'graded',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'graded');
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Homework Section ──
            if (filteredHomework.isNotEmpty) ...[
              _SectionHeading(
                title: 'الواجبات المنزلية',
                count: filteredHomework.length,
                icon: Icons.assignment_rounded,
                color: AppColors.primary,
                textPrimary: textPrimary,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, cardConstraints) {
                  final cardWidth = cardConstraints.maxWidth;
                  final isTwoCol = cardWidth >= 620;

                  if (isTwoCol) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: filteredHomework.map((item) {
                        return SizedBox(
                          width: (cardWidth - 12) / 2,
                          child: _ExecutiveHomeworkCard(
                            item: item,
                            onSubmit: () => widget.onSubmitHomework(item),
                            isDark: isDark,
                          ),
                        );
                      }).toList(),
                    );
                  }

                  return Column(
                    children: filteredHomework.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExecutiveHomeworkCard(
                          item: item,
                          onSubmit: () => widget.onSubmitHomework(item),
                          isDark: isDark,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // ── Exams Section ──
            if (filteredExams.isNotEmpty) ...[
              _SectionHeading(
                title: 'الاختبارات والتقييمات',
                count: filteredExams.length,
                icon: Icons.quiz_rounded,
                color: const Color(0xFF8B5CF6),
                textPrimary: textPrimary,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, cardConstraints) {
                  final cardWidth = cardConstraints.maxWidth;
                  final isTwoCol = cardWidth >= 620;

                  if (isTwoCol) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: filteredExams.map((item) {
                        return SizedBox(
                          width: (cardWidth - 12) / 2,
                          child: _ExecutiveExamCard(
                            item: item,
                            onStart: () => widget.onStartExam(item),
                            isDark: isDark,
                          ),
                        );
                      }).toList(),
                    );
                  }

                  return Column(
                    children: filteredExams.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExecutiveExamCard(
                          item: item,
                          onStart: () => widget.onStartExam(item),
                          isDark: isDark,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],

            // Empty state if nothing matches filter
            if (filteredHomework.isEmpty && filteredExams.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'لا توجد نتائج مطابقة لبحثك'
                            : 'لا توجد مهام حالياً في هذا القسم',
                        style: AppTypography.titleMedium(textPrimary).copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'جرّب كتابة كلمات مختلفة أو إزالة الفلاتر'
                            : 'الواجبات والاختبارات القادمة ستظهر هنا فور إتاحتها',
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                      if (_searchQuery.isNotEmpty || _selectedFilter != 'all') ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedFilter = 'all';
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('إعادة ضبط الفلاتر'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLiveBlitzBanner(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    bool isNarrow,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          final user = Supabase.instance.client.auth.currentUser;
          final name = user?.userMetadata?['full_name']?.toString() ?? 'طالب';
          StudentBlitzQuizJoinDialog.show(context, studentName: name);
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12 : 16,
            vertical: isNarrow ? 12 : 14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF2E1065), const Color(0xFF1E1B4B)]
                  : [const Color(0xFFF3E8FF), const Color(0xFFEDE9FE)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: isDark ? 0.45 : 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA855F7).withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'كويز الـ 5 دقائق المباشر ⚡',
                            style: TextStyle(
                              fontSize: isNarrow ? 12.5 : 14,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.redAccent,
                              width: 0.6,
                            ),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'أدخل كود الـ PIN للمشاركة السريعة مع المعلم',
                      style: TextStyle(
                        fontSize: isNarrow ? 10.5 : 11.5,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'أدخل الكود',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter Pill Widget ──
class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section Heading ──
class _SectionHeading extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final Color textPrimary;

  const _SectionHeading({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Modern Executive Homework Card ──
class _ExecutiveHomeworkCard extends StatelessWidget {
  final StudentHomeworkItem item;
  final VoidCallback onSubmit;
  final bool isDark;

  const _ExecutiveHomeworkCard({
    required this.item,
    required this.onSubmit,
    required this.isDark,
  });

  void _showGradedDetails(BuildContext context) async {
    try {
      await _showAssessmentReviewDialog(
        context,
        rpcName: 'get_my_homework_review',
        params: {'p_homework_id': item.homework.id},
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تحميل المراجعة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final statusColor = item.isGraded
        ? AppColors.success
        : item.isSubmitted
            ? AppColors.info
            : item.homework.isOpenForSubmission
                ? AppColors.warning
                : AppColors.error;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item.isSubmitted || item.isGraded
              ? () => _showGradedDetails(context)
              : item.canSubmit
                  ? onSubmit
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta: Group name & Status pill
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.groupName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
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
                    PortalStatusChip(status: item.availabilityStatus),
                  ],
                ),
                const SizedBox(height: 10),

                // Homework Title
                Text(
                  item.homework.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Due date & Points row
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 13,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'تاريخ التسليم: ${_formatDate(item.homework.dueAt)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.submissionScore != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.military_tech_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'الدرجة: ${item.submissionScore} / ${item.homework.maxScore}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Footer
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (item.isSubmitted || item.isGraded) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _showGradedDetails(context),
                          icon: const Icon(Icons.analytics_outlined, size: 16),
                          label: const Text(
                            'مراجعة النتيجة ونموذج الإجابة',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ] else if (item.canSubmit) ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onSubmit,
                          icon: const Icon(Icons.send_rounded, size: 15),
                          label: const Text(
                            'بدء وتسليم الحل 🚀',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _availabilityLabel(context, item.availabilityStatus),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modern Executive Exam Card ──
class _ExecutiveExamCard extends StatelessWidget {
  final StudentExamItem item;
  final VoidCallback onStart;
  final bool isDark;

  const _ExecutiveExamCard({
    required this.item,
    required this.onStart,
    required this.isDark,
  });

  Future<void> _showExamReview(BuildContext context) async {
    try {
      await _showAssessmentReviewDialog(
        context,
        rpcName: 'get_my_exam_review',
        params: {'p_exam_id': item.exam.id},
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تحميل المراجعة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item.canStart
              ? onStart
              : item.canReview
                  ? () => _showExamReview(context)
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.quiz_rounded,
                              size: 13,
                              color: Color(0xFF8B5CF6),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.groupName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8B5CF6),
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
                    PortalStatusChip(status: item.availabilityStatus),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  item.exam.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Exam details
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.exam.durationMinutes} دقيقة',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 13,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'المحاولات: ${item.attemptCount}/${item.exam.maxAttempts}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (item.lastScore != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'النتيجة: ${item.lastScore}%',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Footer
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (item.canStart) ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onStart,
                          icon: const Icon(Icons.play_arrow_rounded, size: 17),
                          label: const Text(
                            'بدء الاختبار الآن 📝',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else if (item.canReview) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(
                              color: Color(0xFF7C3AED),
                              width: 0.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _showExamReview(context),
                          icon: const Icon(Icons.analytics_outlined, size: 16),
                          label: const Text(
                            'مراجعة نموذج الإجابة 🔍',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _availabilityLabel(context, item.availabilityStatus),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2: سجل الحضور والانصراف (Attendance & Leave)
// ═════════════════════════════════════════════════════════════════════════════
class _AttendanceView extends StatefulWidget {
  final bool isLoading;
  final List<StudentAttendanceItem> attendanceItems;
  final List<StudentLeaveItem> leaveItems;
  final VoidCallback onCreateLeaveRequest;
  final VoidCallback onScanQr;

  const _AttendanceView({
    required this.isLoading,
    required this.attendanceItems,
    required this.leaveItems,
    required this.onCreateLeaveRequest,
    required this.onScanQr,
  });

  @override
  State<_AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<_AttendanceView> {
  String _selectedFilter = 'all'; // all, present, late, absent, leave

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final total = widget.attendanceItems.length;
    final present = widget.attendanceItems
        .where((i) => i.status == 'present')
        .length;
    final late = widget.attendanceItems
        .where((i) => i.status == 'late')
        .length;
    final absent = widget.attendanceItems
        .where((i) => i.status == 'absent')
        .length;
    final excused = widget.attendanceItems
        .where((i) => i.status == 'excused')
        .length;
    final rate = total == 0
        ? 100
        : (((present + late + excused) / total) * 100).round();

    // Filter attendance
    final filteredItems = widget.attendanceItems.where((i) {
      if (_selectedFilter == 'leave') return false;
      if (_selectedFilter == 'present') return i.status == 'present';
      if (_selectedFilter == 'late') return i.status == 'late';
      if (_selectedFilter == 'absent') return i.status == 'absent';
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final isNarrow = width < 360;
        final hPadding = isNarrow ? 12.0 : (isMobile ? 16.0 : 20.0);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPadding, 14, hPadding, 32),
          children: [
            // ── Quick Actions Hero Banner ──
            _buildQuickActionHero(context, isDark, isNarrow),
            const SizedBox(height: 16),

            // ── Attendance Metrics Strip ──
            _buildAttendanceAnalytics(
              rate: rate,
              present: present,
              late: late,
              absent: absent,
              excused: excused,
              isDark: isDark,
              isNarrow: isNarrow,
              isMobile: isMobile,
            ),
            const SizedBox(height: 18),

            // ── Attendance Filter Tabs ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'جميع الحصص',
                    count: total,
                    isSelected: _selectedFilter == 'all',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'all');
                    },
                    isDark: isDark,
                  ),
                  _FilterPill(
                    label: 'حاضر',
                    count: present,
                    isSelected: _selectedFilter == 'present',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'present');
                    },
                    isDark: isDark,
                  ),
                  _FilterPill(
                    label: 'تأخير',
                    count: late,
                    isSelected: _selectedFilter == 'late',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'late');
                    },
                    isDark: isDark,
                  ),
                  _FilterPill(
                    label: 'غياب',
                    count: absent,
                    isSelected: _selectedFilter == 'absent',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'absent');
                    },
                    isDark: isDark,
                  ),
                  _FilterPill(
                    label: 'طلبات الإذن',
                    count: widget.leaveItems.length,
                    isSelected: _selectedFilter == 'leave',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = 'leave');
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Attendance Timeline Section ──
            if (_selectedFilter != 'leave') ...[
              _SectionHeading(
                title: 'سجل الحصص والانصراف',
                count: filteredItems.length,
                icon: Icons.calendar_month_rounded,
                color: AppColors.primary,
                textPrimary: textPrimary,
              ),
              const SizedBox(height: 12),
              if (filteredItems.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'لا توجد حصص مسجلة في هذا التصنيف.',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ),
                ),
              ] else ...[
                LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final cardWidth = cardConstraints.maxWidth;
                    final isTwoCol = cardWidth >= 620;

                    if (isTwoCol) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: filteredItems.map((item) {
                          return SizedBox(
                            width: (cardWidth - 12) / 2,
                            child: _AttendanceSessionCard(
                              item: item,
                              isDark: isDark,
                            ),
                          );
                        }).toList(),
                      );
                    }

                    return Column(
                      children: filteredItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AttendanceSessionCard(
                            item: item,
                            isDark: isDark,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
            ],

            // ── Leave Requests Section ──
            if (_selectedFilter == 'all' || _selectedFilter == 'leave') ...[
              Row(
                children: [
                  const Icon(
                    Icons.event_busy_rounded,
                    size: 18,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'طلبات إذن الغياب',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.leaveItems.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onCreateLeaveRequest();
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'طلب جديد',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.leaveItems.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'لا توجد طلبات إذن غياب مسجلة حالياً.',
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                ),
              ] else ...[
                Column(
                  children: widget.leaveItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LeaveRequestCard(item: item, isDark: isDark),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildQuickActionHero(
    BuildContext context,
    bool isDark,
    bool isNarrow,
  ) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل الحضور السريع بـ QR',
                      style: TextStyle(
                        fontSize: isNarrow ? 13 : 14.5,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'امسح الرمز المعروض في القاعة لتأكيد حضورك فوراً',
                      style: TextStyle(
                        fontSize: isNarrow ? 10.5 : 11.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
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
          if (isNarrow) ...[
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onScanQr();
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text(
                'مسح QR الحضور الآن',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onCreateLeaveRequest();
              },
              icon: const Icon(Icons.event_busy_rounded, size: 17),
              label: const Text(
                'تقديم طلب إذن غياب',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onScanQr();
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text(
                      'مسح QR الحضور الآن',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onCreateLeaveRequest();
                    },
                    icon: const Icon(Icons.event_busy_rounded, size: 17),
                    label: const Text(
                      'تقديم طلب إذن غياب',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceAnalytics({
    required int rate,
    required int present,
    required int late,
    required int absent,
    required int excused,
    required bool isDark,
    required bool isNarrow,
    required bool isMobile,
  }) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final rateColor = rate >= 85
        ? AppColors.success
        : (rate >= 70 ? AppColors.warning : AppColors.error);

    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
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
              Text(
                'معدل الانتظام العام:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$rate%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: rateColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(rateColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricBadge(
                  label: 'حضور',
                  value: '$present',
                  color: AppColors.success,
                  isDark: isDark,
                  isNarrow: isNarrow,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MetricBadge(
                  label: 'تأخير',
                  value: '$late',
                  color: AppColors.warning,
                  isDark: isDark,
                  isNarrow: isNarrow,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MetricBadge(
                  label: 'غياب',
                  value: '$absent',
                  color: AppColors.error,
                  isDark: isDark,
                  isNarrow: isNarrow,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MetricBadge(
                  label: 'معذور',
                  value: '$excused',
                  color: AppColors.info,
                  isDark: isDark,
                  isNarrow: isNarrow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool isNarrow;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 4 : 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.6,
        ),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isNarrow ? 13 : 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isNarrow ? 9.5 : 10.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Attendance Session Card ──
class _AttendanceSessionCard extends StatelessWidget {
  final StudentAttendanceItem item;
  final bool isDark;

  const _AttendanceSessionCard({
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final statusColor = _attendanceColor(item.status);
    final statusIcon = _attendanceIcon(item.status);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.groupName,
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
                      _formatDate(item.sessionDate),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  _attendanceLabel(item.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${_formatTime(item.scheduledStartAt)} – ${_formatTime(item.scheduledEndAt)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if ((item.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.notes!,
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Leave Request Card ──
class _LeaveRequestCard extends StatelessWidget {
  final StudentLeaveItem item;
  final bool isDark;

  const _LeaveRequestCard({
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final statusColor = _leaveColor(item.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.event_busy_rounded, size: 16, color: statusColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.classSessionId == null
                      ? 'طلب إذن غياب عام'
                      : '${_formatDate(item.sessionDate ?? item.submittedAt)} · ${item.groupName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  _leaveLabel(item.status),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'السبب: ${item.reason}',
            style: TextStyle(fontSize: 12, color: textPrimary),
          ),
          if ((item.reviewerNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'رد الإدارة: ${item.reviewerNote}',
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3: سبورات الحصص (Published Session Whiteboards)
// ═════════════════════════════════════════════════════════════════════════════
class _SessionBoardsSection extends StatefulWidget {
  final bool isLoading;
  final List<PublishedSessionBoard> boards;
  final ValueChanged<PublishedSessionBoard> onOpenBoard;

  const _SessionBoardsSection({
    required this.isLoading,
    required this.boards,
    required this.onOpenBoard,
  });

  @override
  State<_SessionBoardsSection> createState() => _SessionBoardsSectionState();
}

class _SessionBoardsSectionState extends State<_SessionBoardsSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
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

    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Filter boards
    final filteredBoards = widget.boards.where((b) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchesTitle = b.title.toLowerCase().contains(q);
        final matchesGroup = b.groupName.toLowerCase().contains(q);
        if (!matchesTitle && !matchesGroup) return false;
      }
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final isNarrow = width < 360;
        final isDesktop = width >= 900;
        final hPadding = isNarrow ? 12.0 : (isMobile ? 16.0 : 20.0);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPadding, 14, hPadding, 32),
          children: [
            // ── Header Banner ──
            Container(
              padding: EdgeInsets.all(isNarrow ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.4 : 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سبورات وشروحات الحصص',
                          style: TextStyle(
                            fontSize: isNarrow ? 13 : 14.5,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'تصفح شروحات ورسومات المعلمين التفاعلية المنشورة',
                          style: TextStyle(
                            fontSize: isNarrow ? 10.5 : 11.5,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(
                  fontSize: isNarrow ? 12 : 13,
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  hintText: 'ابحث في سبورات الحصص أو المواد...',
                  hintStyle: TextStyle(
                    fontSize: isNarrow ? 11.5 : 12.5,
                    color: textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Grid of Boards ──
            if (filteredBoards.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.draw_rounded,
                          size: 48,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'لا توجد سبورات مطابقة لبحثك'
                            : 'لا توجد سبورات منشورة حالياً',
                        style: AppTypography.titleMedium(textPrimary).copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'جرّب كتابة كلمات بحث أخرى'
                            : 'ستظهر سبورات الحصص هنا بعد أن ينشر المعلم سبورة الحصة.',
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              LayoutBuilder(
                builder: (context, gridConstraints) {
                  final gridWidth = gridConstraints.maxWidth;
                  final crossAxisCount = isDesktop ? 3 : (isMobile ? 1 : 2);

                  if (crossAxisCount == 1) {
                    return Column(
                      children: filteredBoards.map((b) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExecutiveWhiteboardCard(
                            board: b,
                            onOpen: () {
                              HapticFeedback.lightImpact();
                              widget.onOpenBoard(b);
                            },
                            isDark: isDark,
                          ),
                        );
                      }).toList(),
                    );
                  }

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: filteredBoards.map((b) {
                      final itemW =
                          (gridWidth - ((crossAxisCount - 1) * 12)) /
                              crossAxisCount;
                      return SizedBox(
                        width: itemW,
                        child: _ExecutiveWhiteboardCard(
                          board: b,
                          onOpen: () {
                            HapticFeedback.lightImpact();
                            widget.onOpenBoard(b);
                          },
                          isDark: isDark,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Executive Whiteboard Card ──
class _ExecutiveWhiteboardCard extends StatelessWidget {
  final PublishedSessionBoard board;
  final VoidCallback onOpen;
  final bool isDark;

  const _ExecutiveWhiteboardCard({
    required this.board,
    required this.onOpen,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual thumbnail top row
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.draw_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              board.groupName,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3B82F6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDate(board.sessionDate),
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Board title
                Text(
                  board.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Footer button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'فتح وتصفح السبورة',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: Color(0xFF3B82F6),
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
        ),
      ),
    );
  }
}
