import 'package:flutter/material.dart';

import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/payments/domain/models/payment_models.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';
import 'parent_home_tab.dart';
import 'parent_progress_tab.dart';

// ─── Filter Categories for Monthly Report ────────────────────────────────────

enum MonthlyReportCategory {
  all,
  attendance,
  academics,
  financial,
  insights,
}

// ─── Main Parent Monthly Report Tab ──────────────────────────────────────────

class ParentMonthlyReportTab extends StatefulWidget {
  final Student? child;
  final List<Student> linkedChildren;
  final ValueChanged<Student> onChildSelected;
  final List<ParentAttendanceItem> attendance;
  final List<StudyLessonSummary> lessons;
  final List<ParentExamItem> exams;
  final List<ParentHomeworkItem> homeworks;
  final List<Invoice> invoices;
  final FinancialSummary? financialSummary;
  final List<GroupEntity> childGroups;
  final VoidCallback onOpenOfficialReportCard;

  const ParentMonthlyReportTab({
    super.key,
    required this.child,
    required this.linkedChildren,
    required this.onChildSelected,
    required this.attendance,
    required this.lessons,
    required this.exams,
    required this.homeworks,
    required this.invoices,
    required this.financialSummary,
    required this.childGroups,
    required this.onOpenOfficialReportCard,
  });

  @override
  State<ParentMonthlyReportTab> createState() => _ParentMonthlyReportTabState();
}

class _ParentMonthlyReportTabState extends State<ParentMonthlyReportTab> {
  MonthlyReportCategory _selectedCategory = MonthlyReportCategory.all;
  int _selectedPeriodIndex = 0; // 0: current month, 1: previous month, 2: all-time

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final currentMonthDt = DateTime(now.year, now.month, 1);
    final prevMonthDt = DateTime(now.year, now.month - 1, 1);

    // Compute metrics according to selected period
    final List<ParentAttendanceItem> filteredAttendance;
    final String periodLabel;

    if (_selectedPeriodIndex == 0) {
      periodLabel = 'شهر ${_monthName(currentMonthDt.month)} ${currentMonthDt.year}';
      filteredAttendance = widget.attendance.where((item) {
        final d = item.sessionDate;
        return d != null && d.year == currentMonthDt.year && d.month == currentMonthDt.month;
      }).toList();
    } else if (_selectedPeriodIndex == 1) {
      periodLabel = 'شهر ${_monthName(prevMonthDt.month)} ${prevMonthDt.year}';
      filteredAttendance = widget.attendance.where((item) {
        final d = item.sessionDate;
        return d != null && d.year == prevMonthDt.year && d.month == prevMonthDt.month;
      }).toList();
    } else {
      periodLabel = 'السجل التراكمي الشامل';
      filteredAttendance = widget.attendance;
    }

    // Attendance calculation
    final totalSessions = filteredAttendance.length;
    final presentCount = filteredAttendance
        .where(
          (item) =>
              item.status.toLowerCase() == 'present' ||
              item.status.toLowerCase() == 'excused' ||
              item.status.toLowerCase() == 'late',
        )
        .length;
    final double attendanceRate =
        totalSessions > 0 ? (presentCount / totalSessions) * 100 : 100.0;

    // Academic progress calculation
    final totalLessons = widget.lessons.length;
    final completedLessons =
        widget.lessons.where((l) => l.progressPercentage >= 100).length;
    final double avgLessonProgress = totalLessons > 0
        ? widget.lessons.fold<int>(0, (sum, l) => sum + l.progressPercentage) / totalLessons
        : 0.0;

    // Exams calculation
    final gradedExams = widget.exams.where((e) => e.percentage != null).toList();
    final double? examAverage = gradedExams.isNotEmpty
        ? gradedExams.map((e) => e.percentage!).reduce((a, b) => a + b) / gradedExams.length
        : null;

    // Homeworks calculation
    final gradedHomeworks = widget.homeworks.where((h) => h.percentage != null).toList();
    final double? homeworkAverage = gradedHomeworks.isNotEmpty
        ? gradedHomeworks.map((h) => h.percentage!).reduce((a, b) => a + b) /
            gradedHomeworks.length
        : null;

    // Financial balance
    final remainingMinor = widget.financialSummary?.remainingBalanceMinor ?? 0;
    final openInvoices = widget.invoices.where((inv) {
      final s = inv.status.toLowerCase();
      return s == 'issued' || s == 'overdue' || s == 'partially_paid';
    }).toList();

    // Composite Academic Index (Out of 100)
    final double effectiveAcademicScore;
    if (examAverage != null) {
      effectiveAcademicScore =
          ((attendanceRate * 0.35) + (examAverage * 0.45) + (avgLessonProgress * 0.20))
              .clamp(0.0, 100.0);
    } else {
      effectiveAcademicScore =
          ((attendanceRate * 0.50) + (avgLessonProgress * 0.50)).clamp(0.0, 100.0);
    }

    // Dynamic Pedagogical Insights
    final insights = _generateRecommendations(
      attendanceRate: attendanceRate,
      sessionsCount: totalSessions,
      avgProgress: avgLessonProgress,
      examAverage: examAverage,
      remainingMinor: remainingMinor,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 380;
        final isMobile = screenWidth < 650;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Performance Overview Hero Card
            _ExecutiveMonthlyReportHero(
              child: widget.child,
              childGroups: widget.childGroups,
              periodLabel: periodLabel,
              selectedPeriodIndex: _selectedPeriodIndex,
              onPeriodChanged: (index) {
                setState(() => _selectedPeriodIndex = index);
              },
              compositeScore: effectiveAcademicScore,
              attendanceRate: attendanceRate,
              presentSessionsCount: presentCount,
              totalSessionsCount: totalSessions,
              avgLessonProgress: avgLessonProgress,
              completedLessons: completedLessons,
              totalLessons: totalLessons,
              examAverage: examAverage,
              remainingBalanceMinor: remainingMinor,
              currency: widget.financialSummary?.currency ?? 'EGP',
              isDark: isDark,
              isNarrow: isNarrow,
              isMobile: isMobile,
              onOpenOfficialReport: widget.onOpenOfficialReportCard,
            ),
            const SizedBox(height: 18),

            // 2. Interactive Category Filter Switcher Bar
            _MonthlyCategoryFilterBar(
              selectedCategory: _selectedCategory,
              attendanceCount: filteredAttendance.length,
              academicsCount: widget.lessons.length + widget.exams.length,
              financialCount: openInvoices.length,
              insightsCount: insights.length,
              isDark: isDark,
              isNarrow: isNarrow,
              onCategoryChanged: (cat) {
                setState(() => _selectedCategory = cat);
              },
            ),
            const SizedBox(height: 18),

            // 3. Dynamic Categorized Views
            if (_selectedCategory == MonthlyReportCategory.all) ...[
              // Summary Recommendations Highlight
              if (insights.isNotEmpty) ...[
                _ParentInsightsSection(
                  insights: insights,
                  isDark: isDark,
                  isNarrow: isNarrow,
                ),
                const SizedBox(height: 18),
              ],

              // Monthly Attendance Snippet
              _AttendanceMonthlySection(
                attendance: filteredAttendance,
                limit: 4,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: () {
                  setState(() => _selectedCategory = MonthlyReportCategory.attendance);
                },
              ),
              const SizedBox(height: 18),

              // Academic Progress & Exams Snippet
              _AcademicsMonthlySection(
                lessons: widget.lessons,
                exams: widget.exams,
                homeworks: widget.homeworks,
                examAverage: examAverage,
                homeworkAverage: homeworkAverage,
                limit: 3,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: () {
                  setState(() => _selectedCategory = MonthlyReportCategory.academics);
                },
              ),
              const SizedBox(height: 18),

              // Financial Monthly Status Snippet
              _FinancialMonthlySection(
                openInvoices: openInvoices,
                remainingMinor: remainingMinor,
                currency: widget.financialSummary?.currency ?? 'EGP',
                isDark: isDark,
                isNarrow: isNarrow,
                limit: 3,
                onViewAll: () {
                  setState(() => _selectedCategory = MonthlyReportCategory.financial);
                },
              ),
            ] else if (_selectedCategory == MonthlyReportCategory.attendance) ...[
              _AttendanceMonthlySection(
                attendance: filteredAttendance,
                limit: null,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: null,
              ),
            ] else if (_selectedCategory == MonthlyReportCategory.academics) ...[
              _AcademicsMonthlySection(
                lessons: widget.lessons,
                exams: widget.exams,
                homeworks: widget.homeworks,
                examAverage: examAverage,
                homeworkAverage: homeworkAverage,
                limit: null,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: null,
              ),
            ] else if (_selectedCategory == MonthlyReportCategory.financial) ...[
              _FinancialMonthlySection(
                openInvoices: openInvoices,
                remainingMinor: remainingMinor,
                currency: widget.financialSummary?.currency ?? 'EGP',
                isDark: isDark,
                isNarrow: isNarrow,
                limit: null,
                onViewAll: null,
              ),
            ] else if (_selectedCategory == MonthlyReportCategory.insights) ...[
              _ParentInsightsSection(
                insights: insights,
                isDark: isDark,
                isNarrow: isNarrow,
              ),
              const SizedBox(height: 16),
              _HomeSupportGuidanceCard(isDark: isDark, isNarrow: isNarrow),
            ],
          ],
        );
      },
    );
  }

  static String _monthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'الشهر';
  }

  static List<ParentInsight> _generateRecommendations({
    required double attendanceRate,
    required int sessionsCount,
    required double avgProgress,
    required double? examAverage,
    required int remainingMinor,
  }) {
    final list = <ParentInsight>[];

    // Attendance Advice
    if (sessionsCount > 0 && attendanceRate < 85) {
      list.add(
        ParentInsight(
          icon: Icons.event_busy_rounded,
          color: const Color(0xFFEF4444),
          title: 'تنبيه: انخفاض نسبة الحضور (${attendanceRate.round()}%)',
          body:
              'تغيب الطالب عن بعض الحصص المنعقدة هذا الشهر. الانتظام بالحضور هو الركيزة الأساسية لتفوقه واستيعابه.',
        ),
      );
    } else if (sessionsCount > 0 && attendanceRate >= 95) {
      list.add(
        const ParentInsight(
          icon: Icons.verified_rounded,
          color: Color(0xFF10B981),
          title: 'التزام مثالي في الحضور والانتظام (100%)',
          body: 'حضور مستمر دون أي غياب غير مبرر، مما يعكس انضباطاً وحرصاً متميزاً للطالب.',
        ),
      );
    }

    // Academics Advice
    if (examAverage != null) {
      if (examAverage >= 85) {
        list.add(
          ParentInsight(
            icon: Icons.military_tech_rounded,
            color: const Color(0xFF10B981),
            title: 'مستوى أكاديمي متفوق في الاختبارات (${examAverage.round()}%)',
            body: 'يحقق الطالب نتائج عالية تعكس استيعاباً عميقاً للمفاهيم واجتهاداً في المراجعة.',
          ),
        );
      } else if (examAverage < 65) {
        list.add(
          ParentInsight(
            icon: Icons.auto_stories_rounded,
            color: const Color(0xFFF59E0B),
            title: 'فرصة لتحسين التحصيل الدراسي (${examAverage.round()}%)',
            body: 'نوصي بجدول مراجعة أسبوعي مكثف للمفاهيم الصعبة مع حل تدريبات إضافية.',
          ),
        );
      }
    } else if (avgProgress < 50) {
      list.add(
        ParentInsight(
          icon: Icons.schedule_rounded,
          color: const Color(0xFFF59E0B),
          title: 'تكثيف معدل دراسة المنهج (${avgProgress.round()}%)',
          body: 'يحتاج الطالب لتخصيص وقت يومي أكبر للمذاكرة وإنهاء الدروس والأنشطة الرقمية.',
        ),
      );
    }

    // Financial Advice
    if (remainingMinor > 0) {
      list.add(
        const ParentInsight(
          icon: Icons.receipt_long_rounded,
          color: Color(0xFFEF4444),
          title: 'تذكير بمستحقات مالية معلقة بالخزينة',
          body: 'يرجى تسوية رسوم واشتراكات الشهر لضمان استمرار طباعة المذكرات ودخول الحصص بانتظام.',
        ),
      );
    } else {
      list.add(
        const ParentInsight(
          icon: Icons.price_check_rounded,
          color: Color(0xFF10B981),
          title: 'الموقف المالي خالص ومسدد بالكامل',
          body: 'كافة رسوم واشتراكات الطالب مسددة ولا توجد أي متأخرات مالية معلقة.',
        ),
      );
    }

    return list;
  }
}

// ─── 1. Executive Performance Overview Hero Card ─────────────────────────────

class _ExecutiveMonthlyReportHero extends StatelessWidget {
  final Student? child;
  final List<GroupEntity> childGroups;
  final String periodLabel;
  final int selectedPeriodIndex;
  final ValueChanged<int> onPeriodChanged;
  final double compositeScore;
  final double attendanceRate;
  final int presentSessionsCount;
  final int totalSessionsCount;
  final double avgLessonProgress;
  final int completedLessons;
  final int totalLessons;
  final double? examAverage;
  final int remainingBalanceMinor;
  final String currency;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final VoidCallback onOpenOfficialReport;

  const _ExecutiveMonthlyReportHero({
    required this.child,
    required this.childGroups,
    required this.periodLabel,
    required this.selectedPeriodIndex,
    required this.onPeriodChanged,
    required this.compositeScore,
    required this.attendanceRate,
    required this.presentSessionsCount,
    required this.totalSessionsCount,
    required this.avgLessonProgress,
    required this.completedLessons,
    required this.totalLessons,
    required this.examAverage,
    required this.remainingBalanceMinor,
    required this.currency,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.onOpenOfficialReport,
  });

  @override
  Widget build(BuildContext context) {
    final int scoreInt = compositeScore.round();
    final Color scoreColor;
    final String ratingBadge;
    final String ratingSubtitle;

    if (scoreInt >= 88) {
      scoreColor = const Color(0xFF10B981);
      ratingBadge = 'أداء عام استثنائي 🌟';
      ratingSubtitle = 'طالب منضبط وملتزم في الحضور والتحصيل الدراسي';
    } else if (scoreInt >= 70) {
      scoreColor = const Color(0xFF3B82F6);
      ratingBadge = 'أداء جيد جداً ✨';
      ratingSubtitle = 'مستوى أكاديمي طيب ومستقر مع إمكانية تحسن أكبر';
    } else {
      scoreColor = const Color(0xFFF59E0B);
      ratingBadge = 'يحتاج متابعة وتكثيف ⏳';
      ratingSubtitle = 'نوصي بزيادة التركيز على الحضور والمراجعة المستمرة';
    }

    final groupName =
        childGroups.isNotEmpty ? childGroups.first.name : 'مجموعة دراسية عامة';

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scoreColor.withValues(alpha: isDark ? 0.40 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Dial Gauge + Student Identity & Period
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular Performance Gauge
                SizedBox(
                  width: isNarrow ? 56 : 66,
                  height: isNarrow ? 56 : 66,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (scoreInt / 100).clamp(0.0, 1.0),
                        strokeWidth: isNarrow ? 5 : 6,
                        backgroundColor: scoreColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$scoreInt%',
                            style: TextStyle(
                              fontSize: isNarrow ? 12.5 : 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'التقييم',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Student Identity & Rating Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            child?.fullName ?? 'الطالب',
                            style: TextStyle(
                              fontSize: isNarrow ? 14 : 15.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: scoreColor.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              ratingBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ratingSubtitle,
                        style: TextStyle(
                          fontSize: isNarrow ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: scoreColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'كود: ${child?.studentCode ?? "---"} • $groupName • $periodLabel',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Period Selector Pill Switcher: الشهر الحالي / الشهر السابق / التراكمي
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPeriodPill(
                      label: 'الشهر الحالي',
                      isSelected: selectedPeriodIndex == 0,
                      onTap: () => onPeriodChanged(0),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildPeriodPill(
                      label: 'الشهر السابق',
                      isSelected: selectedPeriodIndex == 1,
                      onTap: () => onPeriodChanged(1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildPeriodPill(
                      label: 'السجل التراكمي',
                      isSelected: selectedPeriodIndex == 2,
                      onTap: () => onPeriodChanged(2),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4 Executive Core Metric Cards
            Row(
              children: [
                Expanded(
                  child: _buildHeroMetricTile(
                    label: 'نسبة الحضور',
                    value: '${attendanceRate.round()}%',
                    subValue: '$presentSessionsCount من $totalSessionsCount حصص',
                    icon: Icons.fact_check_rounded,
                    color: attendanceRate >= 85
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHeroMetricTile(
                    label: 'التقدم الدراسي',
                    value: '${avgLessonProgress.round()}%',
                    subValue: '$completedLessons من $totalLessons دروس',
                    icon: Icons.menu_book_rounded,
                    color: AppColors.studentRole,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildHeroMetricTile(
                    label: 'معدل الاختبارات',
                    value: examAverage != null ? '${examAverage!.round()}%' : '---',
                    subValue: examAverage != null ? 'متوسط التقييمات' : 'لم ترصد درجات',
                    icon: Icons.military_tech_rounded,
                    color: (examAverage ?? 100) >= 75
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHeroMetricTile(
                    label: 'الموقف المالي',
                    value: remainingBalanceMinor <= 0
                        ? 'خالص ✔️'
                        : '${(remainingBalanceMinor / 100).toStringAsFixed(0)} $currency',
                    subValue: remainingBalanceMinor <= 0
                        ? 'لا توجد متأخرات'
                        : 'متبقي للسداد',
                    icon: Icons.payments_rounded,
                    color: remainingBalanceMinor <= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Official PDF Report Card Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: child == null ? null : onOpenOfficialReport,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'عرض وطباعة كارت التقرير الشهري المعتمد (PDF) 📄',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.parentRole
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isNarrow ? 10.5 : 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildHeroMetricTile({
    required String label,
    required String value,
    required String subValue,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isNarrow ? 9.5 : 10.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isNarrow ? 13 : 14.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 2. Interactive Category Filter Switcher Bar ──────────────────────────────

class _MonthlyCategoryFilterBar extends StatelessWidget {
  final MonthlyReportCategory selectedCategory;
  final int attendanceCount;
  final int academicsCount;
  final int financialCount;
  final int insightsCount;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<MonthlyReportCategory> onCategoryChanged;

  const _MonthlyCategoryFilterBar({
    required this.selectedCategory,
    required this.attendanceCount,
    required this.academicsCount,
    required this.financialCount,
    required this.insightsCount,
    required this.isDark,
    required this.isNarrow,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (
        category: MonthlyReportCategory.all,
        label: 'نظرة شاملة',
        icon: Icons.dashboard_rounded,
        count: null,
      ),
      (
        category: MonthlyReportCategory.attendance,
        label: 'الحضور والانتظام',
        icon: Icons.fact_check_rounded,
        count: attendanceCount,
      ),
      (
        category: MonthlyReportCategory.academics,
        label: 'التحصيل والدروس',
        icon: Icons.menu_book_rounded,
        count: academicsCount,
      ),
      (
        category: MonthlyReportCategory.financial,
        label: 'الرسوم والمصروفات',
        icon: Icons.payments_rounded,
        count: financialCount > 0 ? financialCount : null,
      ),
      (
        category: MonthlyReportCategory.insights,
        label: 'التوجيهات والتوصيات',
        icon: Icons.lightbulb_rounded,
        count: insightsCount,
      ),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final isSelected = selectedCategory == item.category;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onCategoryChanged(item.category),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 10 : 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.parentRole
                      : (isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.8)
                          : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.parentRole
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 1.4 : 0.8,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.parentRole.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: isNarrow ? 11 : 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    if (item.count != null && item.count! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.parentRole.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${item.count}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.parentRole,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── 3. Attendance Monthly Section ───────────────────────────────────────────

class _AttendanceMonthlySection extends StatelessWidget {
  final List<ParentAttendanceItem> attendance;
  final int? limit;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback? onViewAll;

  const _AttendanceMonthlySection({
    required this.attendance,
    this.limit,
    required this.isDark,
    required this.isNarrow,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayed = limit != null ? attendance.take(limit!).toList() : attendance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'سجل حضور وغياب الشهر',
                subtitle: 'الحصص المنعقدة والمواقف المسجلة للطالب خلال الفترة.',
              ),
            ),
            if (onViewAll != null && attendance.length > (limit ?? 0))
              TextButton.icon(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text(
                  'عرض الكل',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (displayed.isEmpty)
          _buildEmptyCard(
            message: 'لا توجد حصص مسجلة خلال الفترة المحددة.',
            icon: Icons.event_available_rounded,
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = displayed[index];
              final status = item.status.toLowerCase();
              final isPresent = status == 'present';
              final isLate = status == 'late';
              final isExcused = status == 'excused';

              final Color color = isPresent
                  ? const Color(0xFF10B981)
                  : isLate
                      ? const Color(0xFFF59E0B)
                      : isExcused
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFEF4444);

              final IconData icon = isPresent
                  ? Icons.check_circle_rounded
                  : isLate
                      ? Icons.schedule_rounded
                      : isExcused
                          ? Icons.fact_check_rounded
                          : Icons.cancel_rounded;

              final dateStr = item.sessionDate != null
                  ? '${item.sessionDate!.year}-${item.sessionDate!.month.toString().padLeft(2, '0')}-${item.sessionDate!.day.toString().padLeft(2, '0')}'
                  : 'بتاريخ الحصة';

              return GlassCard(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 10 : 12,
                  vertical: 10,
                ),
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.groupName,
                            style: TextStyle(
                              fontSize: isNarrow ? 12.5 : 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dateStr • ${item.groupCode}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PortalStatusChip(status: item.status),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─── 4. Academics Monthly Section ────────────────────────────────────────────

class _AcademicsMonthlySection extends StatelessWidget {
  final List<StudyLessonSummary> lessons;
  final List<ParentExamItem> exams;
  final List<ParentHomeworkItem> homeworks;
  final double? examAverage;
  final double? homeworkAverage;
  final int? limit;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback? onViewAll;

  const _AcademicsMonthlySection({
    required this.lessons,
    required this.exams,
    required this.homeworks,
    required this.examAverage,
    required this.homeworkAverage,
    this.limit,
    required this.isDark,
    required this.isNarrow,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayedLessons =
        limit != null ? lessons.take(limit!).toList() : lessons;
    final displayedExams = limit != null ? exams.take(limit!).toList() : exams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'التحصيل الأكاديمي والدروس',
                subtitle: 'إنجاز المنهج ونتائج الاختبارات والواجبات الدورية.',
              ),
            ),
            if (onViewAll != null &&
                (lessons.length > (limit ?? 0) || exams.length > (limit ?? 0)))
              TextButton.icon(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text(
                  'عرض الكل',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (displayedLessons.isEmpty && displayedExams.isEmpty)
          _buildEmptyCard(
            message: 'لا توجد دروس أو نتائج اختبارات مسجلة حالياً.',
            icon: Icons.menu_book_outlined,
            isDark: isDark,
          )
        else ...[
          // Exam highlights (if any)
          if (displayedExams.isNotEmpty) ...[
            Text(
              'أحدث الاختبارات والتقييمات 📝',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedExams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final exam = displayedExams[index];
                final pct = exam.percentage;
                final color = (pct ?? 0) >= 80
                    ? const Color(0xFF10B981)
                    : (pct ?? 0) >= 60
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFEF4444);

                return GlassCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 10 : 12,
                    vertical: 10,
                  ),
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.military_tech_rounded, size: 18, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.title,
                              style: TextStyle(
                                fontSize: isNarrow ? 12.5 : 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              exam.groupName,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          exam.scoreLabel ?? (pct != null ? '${pct.round()}%' : 'قيد التصحيح'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
          ],

          // Lessons list
          if (displayedLessons.isNotEmpty) ...[
            Text(
              'تقدم دروس المنهج الدراسي 📚',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedLessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final lesson = displayedLessons[index];
                final isDone = lesson.progressPercentage >= 100;
                final color = isDone ? const Color(0xFF10B981) : AppColors.studentRole;

                return GlassCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 10 : 12,
                    vertical: 10,
                  ),
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDone ? Icons.check_circle_rounded : Icons.pending_rounded,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lesson.title,
                              style: TextStyle(
                                fontSize: isNarrow ? 12 : 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${lesson.progressPercentage}%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: (lesson.progressPercentage / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lesson.pathName} • ${lesson.unitName}',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ],
    );
  }
}

// ─── 5. Financial Monthly Section ────────────────────────────────────────────

class _FinancialMonthlySection extends StatelessWidget {
  final List<Invoice> openInvoices;
  final int remainingMinor;
  final String currency;
  final int? limit;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback? onViewAll;

  const _FinancialMonthlySection({
    required this.openInvoices,
    required this.remainingMinor,
    required this.currency,
    this.limit,
    required this.isDark,
    required this.isNarrow,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayed =
        limit != null ? openInvoices.take(limit!).toList() : openInvoices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'متابعة الرسوم والالتزامات المالية',
                subtitle: 'موقف الفواتير والمصروفات المستحقة خلال الشهر.',
              ),
            ),
            if (onViewAll != null && openInvoices.length > (limit ?? 0))
              TextButton.icon(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text(
                  'عرض الكل',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (openInvoices.isEmpty && remainingMinor <= 0)
          GlassCard(
            padding: const EdgeInsets.all(14),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تمت تصفية وسداد كافة المصروفات الشهرية بنجاح ✔️',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (displayed.isEmpty)
          _buildEmptyCard(
            message: 'لا توجد فواتير معلقة خلال الفترة.',
            icon: Icons.receipt_long_outlined,
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final inv = displayed[index];
              final rem = inv.totalMinor - inv.amountPaidMinor;
              final remStr = '${(rem / 100).toStringAsFixed(0)} $currency';
              final dueDateStr =
                  '${inv.dueAt.year}-${inv.dueAt.month.toString().padLeft(2, '0')}-${inv.dueAt.day.toString().padLeft(2, '0')}';
              final invTitle = inv.invoiceNumber.isNotEmpty
                  ? inv.invoiceNumber
                  : 'فاتورة #${inv.id.substring(0, 8)}';

              return GlassCard(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 10 : 12,
                  vertical: 10,
                ),
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invTitle,
                            style: TextStyle(
                              fontSize: isNarrow ? 12.5 : 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'متبقي $remStr • استحقاق $dueDateStr',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PortalStatusChip(status: inv.status),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─── 6. Parent Pedagogical Insights Section ──────────────────────────────────

class _ParentInsightsSection extends StatelessWidget {
  final List<ParentInsight> insights;
  final bool isDark;
  final bool isNarrow;

  const _ParentInsightsSection({
    required this.insights,
    required this.isDark,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(
          title: 'توجيهات وتوصيات المتابعة الشهرية 💡',
          subtitle: 'نقاط متابعة ذكية مستخلصة من أداء الطالب الفعلي وسجل نشاطه.',
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: insights.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final insight = insights[index];
            return GlassCard(
              padding: EdgeInsets.all(isNarrow ? 12 : 14),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderColor: insight.color.withValues(alpha: 0.3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: insight.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(insight.icon, size: 18, color: insight.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: TextStyle(
                            fontSize: isNarrow ? 12 : 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight.body,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
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
      ],
    );
  }
}

// ─── 7. Home Support Guidance Advice Card ────────────────────────────────────

class _HomeSupportGuidanceCard extends StatelessWidget {
  final bool isDark;
  final bool isNarrow;

  const _HomeSupportGuidanceCard({
    required this.isDark,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.parentRole.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.parentRole.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                size: 18,
                color: AppColors.parentRole,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إرشادات دعم الطالب وتشجيعه بالمنزل 🏡',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.parentRole,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• توفير بيئة هادئة ومناسبة للمذاكرة بعيداً عن المشتتات والأجهزة الإلكترونية غير التعليمية.\n'
            '• متابعة حل الواجبات الدورية فور انتهاء الحصة لترسيخ المفاهيم والمعادلات.\n'
            '• التحفيز الإيجابي المستمر عند تحقيق درجات جيدة في الاختبارات الدورية.\n'
            '• التواصل مع معلم المادة أو إدارة السنتر عبر نافذة الدعم الفني عند وجود أي تعثر دراسي.',
            style: TextStyle(
              fontSize: 11,
              height: 1.55,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Empty Card ───────────────────────────────────────────────────────

Widget _buildEmptyCard({
  required String message,
  required IconData icon,
  required bool isDark,
}) {
  return GlassCard(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ),
  );
}
