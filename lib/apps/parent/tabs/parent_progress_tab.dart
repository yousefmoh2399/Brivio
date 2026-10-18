import 'package:flutter/material.dart';

import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';
import 'parent_home_tab.dart';

// ─── Shared Models for Parent Academic Progress ──────────────────────────────

class ParentExamItem {
  final String id;
  final String title;
  final String? description;
  final String? groupId;
  final String groupName;
  final int durationMinutes;
  final int maxAttempts;
  final String status;
  final String? lastAttemptStatus;
  final int attemptCount;
  final double? lastScore;
  final double? maxScore;

  const ParentExamItem({
    required this.id,
    required this.title,
    required this.description,
    required this.groupId,
    required this.groupName,
    required this.durationMinutes,
    required this.maxAttempts,
    required this.status,
    required this.lastAttemptStatus,
    required this.attemptCount,
    required this.lastScore,
    required this.maxScore,
  });

  bool get canReview =>
      lastAttemptStatus == 'submitted' ||
      lastAttemptStatus == 'graded' ||
      lastAttemptStatus == 'expired';

  double? get percentage =>
      (lastScore != null && maxScore != null && maxScore! > 0)
          ? (lastScore! / maxScore!) * 100
          : null;

  String? get scoreLabel {
    if (lastScore == null) return null;
    final score = lastScore == lastScore!.roundToDouble()
        ? lastScore!.toStringAsFixed(0)
        : lastScore!.toStringAsFixed(1);
    final max = maxScore == null
        ? ''
        : maxScore == maxScore!.roundToDouble()
            ? ' / ${maxScore!.toStringAsFixed(0)}'
            : ' / ${maxScore!.toStringAsFixed(1)}';
    return '$score$max';
  }

  factory ParentExamItem.fromJson(Map json) {
    return ParentExamItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'اختبار',
      description: json['description']?.toString(),
      groupId: json['group_id']?.toString(),
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      durationMinutes: (json['duration_minutes'] as num? ?? 30).toInt(),
      maxAttempts: (json['max_attempts'] as num? ?? 1).toInt(),
      status: json['status']?.toString() ?? 'published',
      lastAttemptStatus: json['last_attempt_status']?.toString(),
      attemptCount: (json['attempt_count'] as num? ?? 0).toInt(),
      lastScore: (json['last_score'] as num?)?.toDouble(),
      maxScore: (json['max_score'] as num?)?.toDouble(),
    );
  }
}

class ParentHomeworkItem {
  final String id;
  final String title;
  final String? description;
  final String? subjectId;
  final String subjectName;
  final String? groupId;
  final String groupName;
  final DateTime? dueAt;
  final double? maxScore;
  final String status;
  final String? submissionStatus;
  final double? score;
  final DateTime? submittedAt;

  const ParentHomeworkItem({
    required this.id,
    required this.title,
    this.description,
    this.subjectId,
    required this.subjectName,
    this.groupId,
    required this.groupName,
    this.dueAt,
    this.maxScore,
    required this.status,
    this.submissionStatus,
    this.score,
    this.submittedAt,
  });

  double? get percentage =>
      (score != null && maxScore != null && maxScore! > 0)
          ? (score! / maxScore!) * 100
          : null;

  String? get scoreLabel {
    if (score == null) return null;
    final s = score == score!.roundToDouble()
        ? score!.toStringAsFixed(0)
        : score!.toStringAsFixed(1);
    final m = maxScore == null
        ? ''
        : maxScore == maxScore!.roundToDouble()
            ? ' / ${maxScore!.toStringAsFixed(0)}'
            : ' / ${maxScore!.toStringAsFixed(1)}';
    return '$s$m';
  }

  factory ParentHomeworkItem.fromJson(Map json) {
    return ParentHomeworkItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'واجب منزلي',
      description: json['description']?.toString(),
      subjectId: json['subject_id']?.toString(),
      subjectName: json['subject_name']?.toString() ?? 'مادة دراسية',
      groupId: json['group_id']?.toString(),
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      dueAt: DateTime.tryParse(json['due_at']?.toString() ?? ''),
      maxScore: (json['max_score'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'pending',
      submissionStatus: json['submission_status']?.toString(),
      score: (json['score'] as num?)?.toDouble(),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
    );
  }
}

// ─── Main Parent Progress Tab Widget ─────────────────────────────────────────

enum ProgressFilterCategory {
  all,
  exams,
  homework,
  lessons,
}

class ParentProgressTab extends StatefulWidget {
  final Student? child;
  final List<Student> linkedChildren;
  final ValueChanged<Student> onChildSelected;
  final StudentLearningSnapshot? learningSnapshot;
  final List<ParentExamItem> examItems;
  final List<ParentHomeworkItem> homeworkItems;
  final List<GroupEntity> childGroups;
  final List<ParentAttendanceItem> attendance;
  final VoidCallback onOpenAssignments;
  final VoidCallback onOpenReportCard;
  final ValueChanged<ParentExamItem> onReviewExam;

  const ParentProgressTab({
    super.key,
    required this.child,
    required this.linkedChildren,
    required this.onChildSelected,
    required this.learningSnapshot,
    required this.examItems,
    required this.homeworkItems,
    required this.childGroups,
    required this.attendance,
    required this.onOpenAssignments,
    required this.onOpenReportCard,
    required this.onReviewExam,
  });

  @override
  State<ParentProgressTab> createState() => _ParentProgressTabState();
}

class _ParentProgressTabState extends State<ParentProgressTab> {
  ProgressFilterCategory _selectedCategory = ProgressFilterCategory.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 380;
        final isMobile = screenWidth < 650;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Academic Standing Hero Card
            _ExecutiveAcademicStandingHero(
              child: widget.child,
              snapshot: widget.learningSnapshot,
              examItems: widget.examItems,
              homeworkItems: widget.homeworkItems,
              attendance: widget.attendance,
              isDark: isDark,
              isNarrow: isNarrow,
              isMobile: isMobile,
              onOpenReportCard: widget.onOpenReportCard,
            ),
            const SizedBox(height: 18),

            // 2. Interactive Category Filter Switcher Bar
            _ProgressCategoryFilterBar(
              selectedCategory: _selectedCategory,
              examCount: widget.examItems.length,
              homeworkCount: widget.homeworkItems.length,
              lessonsCount: widget.learningSnapshot?.availableLessons.length ?? 0,
              isDark: isDark,
              isNarrow: isNarrow,
              onCategoryChanged: (category) {
                setState(() => _selectedCategory = category);
              },
            ),
            const SizedBox(height: 18),

            // 3. Dynamic Filtered Content
            if (_selectedCategory == ProgressFilterCategory.all) ...[
              // Analytics KPI Metric Grid
              if (widget.learningSnapshot != null &&
                  widget.learningSnapshot!.metrics.isNotEmpty) ...[
                _ExecutiveStudyMetricsGrid(
                  metrics: widget.learningSnapshot!.metrics,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
              ],

              // Subject Breakdown / Competency Radar
              if (widget.childGroups.isNotEmpty) ...[
                _SubjectPerformanceBreakdown(
                  childGroups: widget.childGroups,
                  examItems: widget.examItems,
                  homeworkItems: widget.homeworkItems,
                  lessons: widget.learningSnapshot?.availableLessons ?? const [],
                  isDark: isDark,
                  isNarrow: isNarrow,
                ),
                const SizedBox(height: 20),
              ],

              // Recent Exams Section
              _ExamsAssessmentsSection(
                examItems: widget.examItems,
                limit: 3,
                isDark: isDark,
                isNarrow: isNarrow,
                onReviewExam: widget.onReviewExam,
                onViewAll: () {
                  setState(() => _selectedCategory = ProgressFilterCategory.exams);
                },
              ),
              const SizedBox(height: 20),

              // Homework & Assignments Section
              _HomeworkAssignmentsSection(
                homeworkItems: widget.homeworkItems,
                limit: 4,
                isDark: isDark,
                isNarrow: isNarrow,
                onOpenAssignments: widget.onOpenAssignments,
                onViewAll: () {
                  setState(() => _selectedCategory = ProgressFilterCategory.homework);
                },
              ),
              const SizedBox(height: 20),

              // Curriculum & Lessons Section
              _CurriculumProgressSection(
                lessons: widget.learningSnapshot?.availableLessons ?? const [],
                limit: 4,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: () {
                  setState(() => _selectedCategory = ProgressFilterCategory.lessons);
                },
              ),
            ] else if (_selectedCategory == ProgressFilterCategory.exams) ...[
              _ExamsAssessmentsSection(
                examItems: widget.examItems,
                limit: null,
                isDark: isDark,
                isNarrow: isNarrow,
                onReviewExam: widget.onReviewExam,
                onViewAll: null,
              ),
            ] else if (_selectedCategory == ProgressFilterCategory.homework) ...[
              _HomeworkAssignmentsSection(
                homeworkItems: widget.homeworkItems,
                limit: null,
                isDark: isDark,
                isNarrow: isNarrow,
                onOpenAssignments: widget.onOpenAssignments,
                onViewAll: null,
              ),
            ] else if (_selectedCategory == ProgressFilterCategory.lessons) ...[
              _CurriculumProgressSection(
                lessons: widget.learningSnapshot?.availableLessons ?? const [],
                limit: null,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: null,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── 1. Executive Academic Standing Hero Card ─────────────────────────────────

class _ExecutiveAcademicStandingHero extends StatelessWidget {
  final Student? child;
  final StudentLearningSnapshot? snapshot;
  final List<ParentExamItem> examItems;
  final List<ParentHomeworkItem> homeworkItems;
  final List<ParentAttendanceItem> attendance;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final VoidCallback onOpenReportCard;

  const _ExecutiveAcademicStandingHero({
    required this.child,
    required this.snapshot,
    required this.examItems,
    required this.homeworkItems,
    required this.attendance,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.onOpenReportCard,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Exam Average
    final gradedExams = examItems.where((e) => e.percentage != null).toList();
    final double? examAverage = gradedExams.isNotEmpty
        ? gradedExams.map((e) => e.percentage!).reduce((a, b) => a + b) /
            gradedExams.length
        : null;

    // 2. Calculate Homework Completion & Score
    final completedHw = homeworkItems
        .where((h) => h.status == 'graded' || h.status == 'submitted')
        .length;
    final totalHw = homeworkItems.length;
    final gradedHw = homeworkItems.where((h) => h.percentage != null).toList();
    final double? hwAverage = gradedHw.isNotEmpty
        ? gradedHw.map((h) => h.percentage!).reduce((a, b) => a + b) /
            gradedHw.length
        : null;

    // 3. Calculate Lessons Progress Average
    final lessons = snapshot?.availableLessons ?? const <StudyLessonSummary>[];
    final double lessonsAverage = lessons.isNotEmpty
        ? lessons.fold<int>(0, (sum, l) => sum + l.progressPercentage) /
            lessons.length
        : 0.0;

    // 4. Calculate Attendance Rate
    final totalAtt = attendance.length;
    final presentAtt =
        attendance.where((a) => a.status.toLowerCase() == 'present').length;
    final double? attRate = totalAtt > 0 ? (presentAtt / totalAtt) * 100 : null;

    // 5. Overall Weighted Index (Exams 40%, Homework 30%, Lessons 15%, Attendance 15%)
    double overallScore = 0.0;
    int weightSum = 0;

    if (examAverage != null) {
      overallScore += examAverage * 0.40;
      weightSum += 40;
    }
    if (hwAverage != null) {
      overallScore += hwAverage * 0.30;
      weightSum += 30;
    }
    if (lessons.isNotEmpty) {
      overallScore += lessonsAverage * 0.15;
      weightSum += 15;
    }
    if (attRate != null) {
      overallScore += attRate * 0.15;
      weightSum += 15;
    }

    final double effectiveScore = weightSum > 0 ? (overallScore / weightSum) * 100 : 0.0;
    final int scoreInt = effectiveScore.round();

    // Standing label & colors
    final String standingLabel;
    final Color standingColor;
    final String badgeText;

    if (scoreInt >= 85) {
      standingLabel = 'مستوى أكاديمي ممتاز ومتقدم 🏆';
      standingColor = const Color(0xFF10B981);
      badgeText = 'امتياز';
    } else if (scoreInt >= 75) {
      standingLabel = 'مستوى دراسي جيد جداً 🌟';
      standingColor = const Color(0xFF3B82F6);
      badgeText = 'جيد جداً';
    } else if (scoreInt >= 60) {
      standingLabel = 'مستوى دراسي مستقر وجيد 👍';
      standingColor = const Color(0xFFF59E0B);
      badgeText = 'جيد';
    } else if (scoreInt > 0) {
      standingLabel = 'يحتاج إلى تعزيز المتابعة والدعم ⚠️';
      standingColor = const Color(0xFFEF4444);
      badgeText = 'متابعة عاجلة';
    } else {
      standingLabel = 'بيانات التقييم قيد التجميع والاعتماد ⏳';
      standingColor = AppColors.parentRole;
      badgeText = 'قيد الرصد';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: standingColor.withValues(alpha: isDark ? 0.40 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: standingColor.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar with Student Identification and Rating
          Padding(
            padding: EdgeInsets.all(isNarrow ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular Radial Progress Indicator
                    SizedBox(
                      width: isNarrow ? 54 : 64,
                      height: isNarrow ? 54 : 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: scoreInt > 0 ? (scoreInt / 100).clamp(0.0, 1.0) : 0.05,
                            strokeWidth: isNarrow ? 5 : 6,
                            backgroundColor: standingColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(standingColor),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                scoreInt > 0 ? '$scoreInt%' : '--',
                                style: TextStyle(
                                  fontSize: isNarrow ? 13 : 15,
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

                    // Student & Standing Details
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: standingColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: standingColor.withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: standingColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            standingLabel,
                            style: TextStyle(
                              fontSize: isNarrow ? 11 : 12,
                              fontWeight: FontWeight.w700,
                              color: standingColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'كود الطالب: ${child?.studentCode ?? "---"} • كشف أداء شامل ومحدث لحظياً',
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

                // 4 Mini Key Metrics
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 8 : 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'متوسط الاختبارات',
                          value: examAverage != null
                              ? '${examAverage.round()}%'
                              : 'لم يرصد',
                          color: AppColors.studentRole,
                          icon: Icons.quiz_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'تسليم الواجبات',
                          value: totalHw > 0 ? '$completedHw / $totalHw' : 'لا يوجد',
                          color: AppColors.info,
                          icon: Icons.assignment_turned_in_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'إنجاز المناهج',
                          value: lessons.isNotEmpty
                              ? '${lessonsAverage.round()}%'
                              : '0%',
                          color: AppColors.success,
                          icon: Icons.menu_book_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Action Button: Open Official Monthly Report Card
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
                    onPressed: onOpenReportCard,
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'عرض الشهادة وكشف التقرير الشهري المعتمد 📜',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isNarrow ? 12 : 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── 2. Interactive Segmented Filter Bar ──────────────────────────────────────

class _ProgressCategoryFilterBar extends StatelessWidget {
  final ProgressFilterCategory selectedCategory;
  final int examCount;
  final int homeworkCount;
  final int lessonsCount;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<ProgressFilterCategory> onCategoryChanged;

  const _ProgressCategoryFilterBar({
    required this.selectedCategory,
    required this.examCount,
    required this.homeworkCount,
    required this.lessonsCount,
    required this.isDark,
    required this.isNarrow,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (
        category: ProgressFilterCategory.all,
        label: 'نظرة شاملة',
        icon: Icons.dashboard_rounded,
        count: null,
      ),
      (
        category: ProgressFilterCategory.exams,
        label: 'الاختبارات',
        icon: Icons.quiz_rounded,
        count: examCount,
      ),
      (
        category: ProgressFilterCategory.homework,
        label: 'الواجبات',
        icon: Icons.assignment_rounded,
        count: homeworkCount,
      ),
      (
        category: ProgressFilterCategory.lessons,
        label: 'المناهج والدروس',
        icon: Icons.auto_stories_rounded,
        count: lessonsCount,
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
                  horizontal: isNarrow ? 10 : 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.parentRole
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.parentRole
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 1,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
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

// ─── 3. Executive Study Metrics Grid ──────────────────────────────────────────

class _ExecutiveStudyMetricsGrid extends StatelessWidget {
  final List<StudyMetric> metrics;
  final bool isDark;

  const _ExecutiveStudyMetricsGrid({
    required this.metrics,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return PortalMetricGrid(
      children: metrics.map((metric) {
        final icon = _resolveMetricIcon(metric.label);
        final color = _resolveMetricColor(metric.label);

        return PortalMetricCard(
          label: metric.label,
          value: metric.value,
          icon: icon,
          accentColor: color,
        );
      }).toList(),
    );
  }

  IconData _resolveMetricIcon(String label) {
    if (label.contains('حضور') || label.contains('التزام')) {
      return Icons.fact_check_rounded;
    }
    if (label.contains('ساعة') || label.contains('وقت') || label.contains('زمن')) {
      return Icons.timer_rounded;
    }
    if (label.contains('دروس') || label.contains('منهج')) {
      return Icons.auto_stories_rounded;
    }
    if (label.contains('اختبار') || label.contains('درجات')) {
      return Icons.military_tech_rounded;
    }
    return Icons.insights_rounded;
  }

  Color _resolveMetricColor(String label) {
    if (label.contains('حضور') || label.contains('التزام')) {
      return AppColors.info;
    }
    if (label.contains('ساعة') || label.contains('وقت') || label.contains('زمن')) {
      return AppColors.warning;
    }
    if (label.contains('دروس') || label.contains('منهج')) {
      return AppColors.success;
    }
    return AppColors.studentRole;
  }
}

// ─── 4. Subject Breakdown / Competency Radar ──────────────────────────────────

class _SubjectPerformanceBreakdown extends StatelessWidget {
  final List<GroupEntity> childGroups;
  final List<ParentExamItem> examItems;
  final List<ParentHomeworkItem> homeworkItems;
  final List<StudyLessonSummary> lessons;
  final bool isDark;
  final bool isNarrow;

  const _SubjectPerformanceBreakdown({
    required this.childGroups,
    required this.examItems,
    required this.homeworkItems,
    required this.lessons,
    required this.isDark,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(
          title: 'تحليل الأداء حسب المواد الدراسية',
          subtitle: 'مؤشرات التقييم والإنجاز موزعة على المجموعات المسجل بها الطالب.',
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: childGroups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final group = childGroups[index];

            // Matching items
            final groupExams = examItems
                .where((e) => e.groupId == group.id || e.groupName == group.name)
                .toList();
            final groupHw = homeworkItems
                .where((h) => h.groupId == group.id || h.groupName == group.name)
                .toList();

            final gradedExams = groupExams.where((e) => e.percentage != null).toList();
            final double? examAvg = gradedExams.isNotEmpty
                ? gradedExams.map((e) => e.percentage!).reduce((a, b) => a + b) /
                    gradedExams.length
                : null;

            final completedHw =
                groupHw.where((h) => h.status == 'graded' || h.status == 'submitted').length;

            return GlassCard(
              padding: EdgeInsets.all(isNarrow ? 12 : 14),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.parentRole.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 18,
                          color: AppColors.parentRole,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: TextStyle(
                                fontSize: isNarrow ? 12.5 : 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              group.code,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (examAvg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _scoreColor(examAvg).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _scoreColor(examAvg).withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${examAvg.round()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _scoreColor(examAvg),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress bar showing subject completion/score
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: examAvg != null ? (examAvg / 100).clamp(0.0, 1.0) : 0.0,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        examAvg != null ? _scoreColor(examAvg) : AppColors.parentRole,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Metadata chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildMiniInfo(
                        icon: Icons.quiz_outlined,
                        text: groupExams.isNotEmpty
                            ? '${groupExams.length} اختبارات'
                            : 'لا توجد اختبارات',
                        isDark: isDark,
                      ),
                      _buildMiniInfo(
                        icon: Icons.assignment_outlined,
                        text: groupHw.isNotEmpty
                            ? 'أُنجز $completedHw من ${groupHw.length} واجب'
                            : 'لا توجد واجبات',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniInfo({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static Color _scoreColor(double score) {
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF3B82F6);
    if (score >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

// ─── 5. Exams & Periodic Assessments Hub ──────────────────────────────────────

class _ExamsAssessmentsSection extends StatelessWidget {
  final List<ParentExamItem> examItems;
  final int? limit;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<ParentExamItem> onReviewExam;
  final VoidCallback? onViewAll;

  const _ExamsAssessmentsSection({
    required this.examItems,
    required this.limit,
    required this.isDark,
    required this.isNarrow,
    required this.onReviewExam,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayedItems = limit != null ? examItems.take(limit!).toList() : examItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'الاختبارات والتقييمات الدورية',
                subtitle: 'نتائج الاختبارات والدرجات المعتمدة ومراجعة الإجابات والحلول.',
              ),
            ),
            if (onViewAll != null && examItems.length > (limit ?? 0))
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

        if (displayedItems.isEmpty)
          _buildEmptyCard(
            message: 'لا توجد اختبارات مسجلة لهذا الطالب حتى الآن.',
            icon: Icons.quiz_outlined,
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final exam = displayedItems[index];
              return _buildExamCard(exam, context);
            },
          ),
      ],
    );
  }

  Widget _buildExamCard(ParentExamItem exam, BuildContext context) {
    final pct = exam.percentage;
    final color = pct != null ? _SubjectPerformanceBreakdown._scoreColor(pct) : AppColors.studentRole;

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Exam Icon, Title, and Score Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.military_tech_rounded, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: TextStyle(
                        fontSize: isNarrow ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exam.groupName} • ${exam.durationMinutes} دقيقة • المحاولات: ${exam.attemptCount}/${exam.maxAttempts}',
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
              if (exam.scoreLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    exam.scoreLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),

          // Score visual progress bar
          if (pct != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],

          // Action review button if canReview
          if (exam.canReview) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: AppColors.parentRole.withValues(alpha: 0.5),
                    width: 0.9,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => onReviewExam(exam),
                icon: const Icon(
                  Icons.find_in_page_rounded,
                  size: 15,
                  color: AppColors.parentRole,
                ),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'مراجعة نموذج الإجابات وتصحيح المعلم 🔍',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.parentRole,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildEmptyCard({
    required String message,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
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
    );
  }
}

// ─── 6. Homework & Assignments Section ────────────────────────────────────────

class _HomeworkAssignmentsSection extends StatelessWidget {
  final List<ParentHomeworkItem> homeworkItems;
  final int? limit;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback onOpenAssignments;
  final VoidCallback? onViewAll;

  const _HomeworkAssignmentsSection({
    required this.homeworkItems,
    required this.limit,
    required this.isDark,
    required this.isNarrow,
    required this.onOpenAssignments,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayedItems =
        limit != null ? homeworkItems.take(limit!).toList() : homeworkItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'الواجبات والتكليفات المدرسية',
                subtitle: 'متابعة حل وتسليم الواجبات الدورية والتكليفات المنزلية.',
              ),
            ),
            TextButton.icon(
              onPressed: onViewAll ?? onOpenAssignments,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 14),
              label: Text(
                onViewAll != null ? 'عرض الكل' : 'شاشة الواجبات',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (displayedItems.isEmpty)
          _ExamsAssessmentsSection._buildEmptyCard(
            message: 'لا توجد واجبات أو تكليفات مدرسية مسجلة لهذا الطالب حالياً.',
            icon: Icons.assignment_outlined,
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final hw = displayedItems[index];
              return _buildHomeworkCard(hw, context);
            },
          ),
      ],
    );
  }

  Widget _buildHomeworkCard(ParentHomeworkItem hw, BuildContext context) {
    final statusColor = hw.status == 'graded'
        ? AppColors.success
        : hw.status == 'submitted'
            ? AppColors.info
            : hw.status == 'missing'
                ? AppColors.error
                : AppColors.warning;

    final statusText = hw.status == 'graded'
        ? 'تم التصحيح والتقييم ⭐'
        : hw.status == 'submitted'
            ? 'تم التسليم بنجاح ✔️'
            : hw.status == 'missing'
                ? 'متأخر عن الموعد ⚠️'
                : 'مطلوب إنجازه ⏳';

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: InkWell(
        onTap: onOpenAssignments,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hw.title,
                        style: TextStyle(
                          fontSize: isNarrow ? 13 : 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hw.subjectName} • ${hw.groupName}',
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
                if (hw.scoreLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      hw.scoreLabel!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Footer row with date and status badge
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                if (hw.dueAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'التسليم: ${hw.dueAt!.year}-${hw.dueAt!.month.toString().padLeft(2, '0')}-${hw.dueAt!.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 7. Curriculum & Lessons Progress Section ─────────────────────────────────

class _CurriculumProgressSection extends StatelessWidget {
  final List<StudyLessonSummary> lessons;
  final int? limit;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback? onViewAll;

  const _CurriculumProgressSection({
    required this.lessons,
    required this.limit,
    required this.isDark,
    required this.isNarrow,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayedLessons =
        limit != null ? lessons.take(limit!).toList() : lessons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'الدروس والمناهج المنشورة',
                subtitle: 'متابعة دراسة المناهج ونسب الإنجاز وزمن القراءة.',
              ),
            ),
            if (onViewAll != null && lessons.length > (limit ?? 0))
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

        if (displayedLessons.isEmpty)
          _ExamsAssessmentsSection._buildEmptyCard(
            message: 'لا توجد دروس أو شروحات منشورة لهذا الطالب حالياً.',
            icon: Icons.auto_stories_outlined,
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedLessons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final lesson = displayedLessons[index];
              return _buildLessonCard(lesson, context);
            },
          ),
      ],
    );
  }

  Widget _buildLessonCard(StudyLessonSummary lesson, BuildContext context) {
    final isDone = lesson.progressPercentage >= 100;
    final color = isDone ? AppColors.success : AppColors.studentRole;

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  lesson.hasPdf ? Icons.picture_as_pdf_rounded : Icons.menu_book_rounded,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: TextStyle(
                        fontSize: isNarrow ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lesson.pathName} • ${lesson.unitName}',
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
                  '${lesson.progressPercentage}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Custom styled progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: lesson.progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),

          const SizedBox(height: 8),

          // Metadata row
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMetaItem(
                icon: Icons.pages_rounded,
                text: 'صفحة ${lesson.lastPage} من ${lesson.totalPages}',
                isDark: isDark,
              ),
              _buildMetaItem(
                icon: Icons.timer_outlined,
                text: _formatStudyTime(lesson.timeSpentSeconds),
                isDark: isDark,
              ),
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'مكتمل ✔️',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _formatStudyTime(int seconds) {
    if (seconds < 60) return '$seconds ثانية';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours ساعة' : '$hours ساعة و $rest دقيقة';
  }
}
