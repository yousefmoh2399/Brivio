import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/supabase_client_wrapper.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/components/buttons.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/assessment/data/repositories/supabase_assessment_repositories.dart';
import '../../../features/attendance/data/repositories/supabase_attendance_repositories.dart';
import '../../../features/attendance/domain/models/attendance_models.dart';
import '../../../features/assessment/presentation/screens/assessment_screens.dart';
import '../../../features/curriculum/data/repositories/supabase_curriculum_repositories.dart';
import '../../../features/study_workspace/data/repositories/supabase_study_workspace_repository.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../../features/study_workspace/presentation/screens/study_workspace_screen.dart';
import '../../../features/curriculum/domain/models/curriculum_models.dart';
import '../../../features/assessment/presentation/widgets/student_homework_submission_dialog.dart';
import '../student_dashboard_models.dart';

class StudentGroupDetailsScreen extends StatefulWidget {
  final GroupEntity group;
  final String? studentId;

  const StudentGroupDetailsScreen({
    super.key,
    required this.group,
    this.studentId,
  });

  @override
  State<StudentGroupDetailsScreen> createState() =>
      _StudentGroupDetailsScreenState();
}

class _StudentGroupDetailsScreenState extends State<StudentGroupDetailsScreen> {
  late final SupabaseClassSessionRepository _sessionRepo;

  List<StudentHomeworkItem> _homeworkList = [];
  List<StudentExamItem> _examList = [];
  List<ClassSession> _sessionList = [];
  List<Semester> _semesters = [];
  bool _isLoading = false;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _studentId = widget.studentId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessionWrapper = SupabaseClientWrapper(Supabase.instance.client);
      if (_studentId == null) {
        try {
          _studentId = (await sessionWrapper.withFreshSession(
            (client) => client.rpc('current_student_id'),
          ))?.toString();
        } catch (_) {}
      }

      final hwResData = await sessionWrapper.withFreshSession(
        (client) => client.rpc('get_student_homework_feed'),
      );
      final examResData = await sessionWrapper.withFreshSession(
        (client) => client.rpc('get_student_exam_feed'),
      );

      final hwRes = (hwResData as List)
          .map((e) => StudentHomeworkItem.fromJson(e as Map<dynamic, dynamic>))
          .where((h) => h.homework.groupId == widget.group.id)
          .toList();

      final examRes = (examResData as List)
          .map((e) => StudentExamItem.fromJson(e as Map<dynamic, dynamic>))
          .where((x) => x.exam.groupId == widget.group.id)
          .toList();

      final sessionRes = await _sessionRepo.fetchSessionsForGroup(
        widget.group.id,
      );

      List<Semester> semesterRes = [];
      try {
        final wrapper = SupabaseClientWrapper(Supabase.instance.client);
        final semesterRepo = SupabaseSemesterRepository(wrapper);
        final unitRepo = SupabaseUnitRepository(wrapper);
        final lessonRepo = SupabaseLessonRepository(wrapper);
        final semesters = await semesterRepo.fetchSemestersForSubject(
          widget.group.subjectId,
        );
        final populatedSemesters = <Semester>[];

        for (final semester in semesters) {
          final units = await unitRepo.fetchUnitsForSemester(semester.id);
          final populatedUnits = <Unit>[];

          for (final unit in units) {
            final lessons =
                (await lessonRepo.fetchLessonsForUnit(unit.id))
                    .where((lesson) => lesson.status == LessonStatus.published)
                    .toList()
                  ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

            if (lessons.isEmpty) continue;
            populatedUnits.add(
              Unit(
                id: unit.id,
                subjectId: unit.subjectId,
                semesterId: unit.semesterId,
                name: unit.name,
                code: unit.code,
                orderNumber: unit.orderNumber,
                status: unit.status,
                lessons: lessons,
              ),
            );
          }

          if (populatedUnits.isEmpty) continue;
          populatedSemesters.add(
            Semester(
              id: semester.id,
              subjectId: semester.subjectId,
              name: semester.name,
              code: semester.code,
              orderNumber: semester.orderNumber,
              startDate: semester.startDate,
              endDate: semester.endDate,
              status: semester.status,
              units: populatedUnits,
            ),
          );
        }

        // Also fetch any units attached directly to the subject
        try {
          final allSubjectUnits = await unitRepo.fetchUnitsForSubject(widget.group.subjectId);
          final directUnits = <Unit>[];
          for (final unit in allSubjectUnits) {
            final alreadyAdded = populatedSemesters.any((s) => s.units.any((u) => u.id == unit.id));
            if (alreadyAdded) continue;

            final lessons = (await lessonRepo.fetchLessonsForUnit(unit.id))
                .where((lesson) => lesson.status == LessonStatus.published)
                .toList()
              ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

            if (lessons.isEmpty) continue;
            directUnits.add(
              Unit(
                id: unit.id,
                subjectId: unit.subjectId ?? widget.group.subjectId,
                semesterId: unit.semesterId,
                name: unit.name,
                code: unit.code,
                orderNumber: unit.orderNumber,
                status: unit.status,
                lessons: lessons,
              ),
            );
          }

          if (directUnits.isNotEmpty) {
            populatedSemesters.add(
              Semester(
                id: 'direct_subject_${widget.group.subjectId}',
                subjectId: widget.group.subjectId,
                name: 'الوحدات والدروس العامة',
                code: 'GEN',
                orderNumber: 0,
                status: 'active',
                units: directUnits,
              ),
            );
          }
        } catch (_) {}

        semesterRes = populatedSemesters;
      } catch (e) {
        debugPrint('Error fetching curriculum: $e');
      }

      if (mounted) {
        setState(() {
          _homeworkList = hwRes;
          _examList = examRes;
          _sessionList = sessionRes;
          _semesters = semesterRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          title: Text(
            widget.group.name,
            style: AppTypography.titleLarge(
              textPrimary,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'الملفات والشروحات'),
              Tab(text: 'الواجبات المنزلية'),
              Tab(text: 'الاختبارات والتقييمات'),
              Tab(text: 'سجل الحضور'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : TabBarView(
                children: [
                  _buildFilesTab(isDark, textPrimary, textSecondary),
                  _buildHomeworkTab(isDark, textPrimary, textSecondary),
                  _buildExamsTab(isDark, textPrimary, textSecondary),
                  _buildAttendanceTab(isDark, textPrimary, textSecondary),
                ],
              ),
      ),
    );
  }

  Future<void> _submitHomework(StudentHomeworkItem item) async {
    if (!item.canSubmit) {
      _showAssessmentLockedMessage(item.availabilityStatus);
      return;
    }
    var homework = item.homework;
    if (homework.questions.isEmpty && homework.groupId != null) {
      try {
        final wrapper = SupabaseClientWrapper(Supabase.instance.client);
        final repo = SupabaseHomeworkRepository(wrapper);
        final fullHomework = await repo.fetchHomeworkForGroup(
          homework.groupId!,
        );
        homework = fullHomework.firstWhere(
          (candidate) => candidate.id == homework.id,
          orElse: () => homework,
        );
      } catch (_) {}
    }

    if (homework.questions.isNotEmpty) {
      final Map<String, String> currentAnswers = {};
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HomeworkRunnerScreen(
            homework: homework,
            onOptionSelected: (qId, oId) => currentAnswers[qId] = oId,
            onSubmit: () async {
              try {
                final wrapper = SupabaseClientWrapper(Supabase.instance.client);
                await wrapper.withFreshSession(
                  (client) => client.rpc(
                    'submit_homework_mcq',
                    params: {
                      'p_homework_id': homework.id,
                      'p_answers': currentAnswers,
                    },
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسليم الواجب بنجاح ✅')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل تسليم الواجب: $e')),
                  );
                }
              }
            },
          ),
        ),
      );
      await _loadData();
      return;
    }

    final payload = await StudentHomeworkSubmissionDialog.show(
      context,
      homework: homework,
    );
    if (payload == null) return;

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await wrapper.withFreshSession(
        (client) => client.rpc(
          'submit_homework_text',
          params: {
            'p_homework_id': homework.id,
            'p_submission_text': payload.text,
            'p_attachment_url': payload.attachmentUrl,
          },
        ),
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🎉 أحسنت يا بطل! تم تسليم الواجب بنجاح وحصلت على +${payload.earnedXp} XP 🌟',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تسليم الواجب: $e')));
    }
  }

  Future<void> _showAssessmentReview({
    required String rpcName,
    required Map<String, dynamic> params,
    required String titleFallback,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    dynamic raw;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      raw = await wrapper.withFreshSession((client) => client.rpc(rpcName, params: params));
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم إعلان تفاصيل النتيجة أو نموذج الإجابة بعد من قِبل المعلم.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

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
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final answers = (review['answers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: surfaceColor,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: released
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              review['title']?.toString() ?? titleFallback,
                              style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'الدرجة: ${review['score'] ?? 0} / ${review['max_score'] ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      if ((review['teacher_feedback']?.toString() ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.comment_rounded, size: 16, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ملاحظات المعلم: ${review['teacher_feedback']}',
                                  style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.46,
                        child: answers.isEmpty
                            ? Center(
                                child: Text('لا توجد إجابات مسجلة لهذا التقييم.', style: AppTypography.bodyMedium(textSecondary)),
                              )
                            : ListView.separated(
                                itemCount: answers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, index) {
                                  final answer = answers[index];
                                  final isCorrect = answer['is_correct'] == true;
                                  final color = isCorrect ? AppColors.success : AppColors.error;
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.08),
                                      border: Border.all(color: color.withValues(alpha: 0.35)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                answer['prompt']?.toString() ?? '',
                                                style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text('إجابتك: ${answer['student_answer'] ?? 'لم تتم الإجابة'}', style: AppTypography.bodySmall(textPrimary)),
                                        const SizedBox(height: 4),
                                        Text('الإجابة النموذجية: ${answer['correct_answer'] ?? 'غير متوفرة'}', style: AppTypography.bodySmall(AppColors.success).copyWith(fontWeight: FontWeight.bold)),
                                        if ((answer['explanation']?.toString() ?? '').trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('الشرح والتوضيح: ${answer['explanation']}', style: AppTypography.caption(textSecondary)),
                                        ],
                                        const SizedBox(height: 6),
                                        Text('الدرجة: ${answer['points_awarded'] ?? 0} / ${answer['max_points'] ?? 0}', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إغلاق المراجعة'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock_rounded, size: 48, color: Colors.orange),
                      const SizedBox(height: 12),
                      Text(
                        review['message']?.toString() ?? 'لم يتم إعلان تفاصيل النتيجة ونموذج الإجابة بعد من قِبل المعلم.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(textPrimary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeworkTab(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_homeworkList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in_rounded,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد واجبات حالياً',
              style: AppTypography.titleLarge(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'ليس لديك أي واجبات مطلوبة في هذه المجموعة.',
              style: AppTypography.bodyMedium(textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _homeworkList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final hw = _homeworkList[index];
        final isGraded = hw.isGraded;
        final isSubmitted = hw.isSubmitted;
        final statusColor = isGraded
            ? AppColors.success
            : (isSubmitted
                ? AppColors.info
                : (hw.homework.isOpenForSubmission ? AppColors.warning : AppColors.error));

        String statusBadgeText;
        if (isGraded) {
          statusBadgeText = 'تم التصحيح · ${hw.submissionScore?.toStringAsFixed(1) ?? '0'} / ${hw.homework.maxScore} درجة';
        } else if (isSubmitted) {
          statusBadgeText = 'تم التسليم · بانتظار تصحيح المعلم';
        } else if (hw.homework.isOpenForSubmission) {
          statusBadgeText = 'مطلوب التسليم · متاح للحل';
        } else {
          statusBadgeText = 'انتهى موعد التسليم';
        }

        final dueFormatted = '${hw.homework.dueAt.year}/${hw.homework.dueAt.month}/${hw.homework.dueAt.day}';

        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isGraded
                          ? Icons.assignment_turned_in_rounded
                          : Icons.assignment_rounded,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusBadgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hw.homework.title,
                          style: AppTypography.titleMedium(
                            textPrimary,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تاريخ التسليم: $dueFormatted  ·  الدرجة القصوى: ${hw.homework.maxScore}',
                          style: AppTypography.caption(
                            textSecondary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((hw.teacherFeedback ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.comment_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ملاحظة المعلم: ${hw.teacherFeedback}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isSubmitted || isGraded) ...[
                    OutlinedButton.icon(
                      onPressed: () => _showAssessmentReview(
                        rpcName: 'get_my_homework_review',
                        params: {'p_homework_id': hw.homework.id},
                        titleFallback: hw.homework.title,
                      ),
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('مراجعة النتيجة والحل'),
                    ),
                  ],
                  if (hw.canSubmit || (isSubmitted && hw.homework.isOpenForSubmission)) ...[
                    PrimaryButton(
                      text: isSubmitted ? 'تعديل الحل' : 'بدء حل الواجب 🚀',
                      color: isSubmitted ? AppColors.info : AppColors.primary,
                      expand: false,
                      height: 40,
                      onPressed: () => _submitHomework(hw),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilesTab(bool isDark, Color textPrimary, Color textSecondary) {
    if (_semesters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: AppColors.info.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد ملفات أو مناهج حالياً',
              style: AppTypography.titleLarge(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر المحاضرات والمذكرات هنا بمجرد رفعها من قِبل المعلم.',
              style: AppTypography.bodyMedium(textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _semesters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final semester = _semesters[index];
        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.info,
                size: 22,
              ),
            ),
            title: Text(
              semester.name,
              style: AppTypography.titleMedium(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${semester.units.length} وحدات دراسية',
              style: AppTypography.caption(
                textSecondary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            children: [
              for (final unit in semester.units)
                _StudentUnitSection(
                  semester: semester,
                  unit: unit,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                  onOpenResource: _openResource,
                  onOpenLessonBoard: _openLessonBoard,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openResource({
    required Semester semester,
    required Unit unit,
    required Lesson lesson,
    required LessonResource resource,
  }) async {
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final resourceRepo = SupabaseLessonResourceRepository(wrapper);
      final url = await resourceRepo.getAuthorizedAssetUrl(resource.id);
      final uri = Uri.parse(url);
      if (resource.resourceType == 'pdf') {
        final summary = StudyLessonSummary(
          id: lesson.id,
          title: lesson.title,
          pathName: semester.name,
          unitName: unit.name,
          progressPercentage: 0,
          estimatedMinutes: lesson.estimatedDurationMinutes ?? 30,
          lastPage: 1,
          totalPages: 0,
          xp: 0,
          hasPdf: true,
          hasCodePlayground: false,
          pdfUrl: url,
          groupId: widget.group.id,
        );
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StudyWorkspaceScreen(
              lesson: summary,
              studentId: _studentId,
              repository: SupabaseStudyWorkspaceRepository(wrapper),
            ),
          ),
        );
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر فتح الملف: $e')));
    }
  }

  Future<void> _openLessonBoard({
    required Semester semester,
    required Unit unit,
    required Lesson lesson,
  }) async {
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      String? pdfUrl;
      final pdfResource =
          lesson.resources.where((r) => r.resourceType == 'pdf').firstOrNull;
      if (pdfResource != null) {
        try {
          final resourceRepo = SupabaseLessonResourceRepository(wrapper);
          pdfUrl = await resourceRepo.getAuthorizedAssetUrl(pdfResource.id);
        } catch (_) {}
      }

      final summary = StudyLessonSummary(
        id: lesson.id,
        title: lesson.title,
        pathName: semester.name,
        unitName: unit.name,
        progressPercentage: 0,
        estimatedMinutes: lesson.estimatedDurationMinutes ?? 30,
        lastPage: 1,
        totalPages: 0,
        xp: 0,
        hasPdf: pdfUrl != null,
        hasCodePlayground: false,
        pdfUrl: pdfUrl,
        groupId: widget.group.id,
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudyWorkspaceScreen(
            lesson: summary,
            studentId: _studentId,
            repository: SupabaseStudyWorkspaceRepository(wrapper),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر فتح السبورة: $e')));
    }
  }

  Future<void> _startExam(StudentExamItem item) async {
    if (!item.canStart) {
      _showAssessmentLockedMessage(item.availabilityStatus);
      return;
    }
    final groupId = item.exam.groupId;
    if (groupId == null) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final repo = SupabaseExamRepository(wrapper);
      final exams = await repo.fetchExamsForGroup(groupId);
      final exam = exams.firstWhere((e) => e.id == item.exam.id);
      final attempt = await repo.startExam(exam.id);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamRunnerScreen(
            exam: exam,
            attempt: attempt,
            onOptionSelected: (qId, oId) => repo.saveExamAnswer(
              attemptId: attempt.id,
              questionId: qId,
              selectedOptionId: oId,
            ),
            onSubmit: () async {
              await repo.submitExamAttempt(attempt.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر بدء الاختبار: $e')));
    }
  }

  void _showAssessmentLockedMessage(String status) {
    final message = switch (status) {
      'not_started' => 'هذا الاختبار لم يبدأ بعد.',
      'expired' => 'انتهى الوقت المحدد للاختبار.',
      'closed' => 'تم إغلاق الاختبار.',
      _ => 'هذا الاختبار غير متاح حالياً.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestExamReset(StudentExamItem item) async {
    final reasonCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب إعادة محاولة الاختبار'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'إذا واجهتك مشكلة تقنية أو طارئة، يرجى كتابة السبب لطلب فرصة جديدة من المعلم.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'سبب طلب الإعادة'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );

    if (submitted != true) return;

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await wrapper.withFreshSession(
        (client) => client.rpc(
          'request_exam_reset',
          params: {
            'p_exam_id': item.exam.id,
            'p_reason': reasonCtrl.text.trim(),
          },
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب إعادة الاختبار بنجاح للمعلم ✅'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في إرسال طلب الإعادة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildExamsTab(bool isDark, Color textPrimary, Color textSecondary) {
    if (_examList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_rounded,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد اختبارات حالياً',
              style: AppTypography.titleLarge(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد اختبارات منشورة لهذه المجموعة في الوقت الحالي.',
              style: AppTypography.bodyMedium(textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _examList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final exam = _examList[index];
        final isPassed = (exam.lastScore != null) && (exam.lastScore! >= exam.exam.passScore);
        final scoreColor = isPassed ? AppColors.success : AppColors.error;

        String statusBadgeText;
        Color statusColor;
        if (exam.lastScore != null) {
          statusBadgeText = 'درجتك: ${exam.lastScore!.toStringAsFixed(1)} درجة ${isPassed ? "(ناجح ✔️)" : "(غير مجتاز)"}';
          statusColor = scoreColor;
        } else if (exam.lastAttemptStatus == 'submitted' || exam.lastAttemptStatus == 'graded') {
          statusBadgeText = 'تم التسليم · قيد التصحيح';
          statusColor = AppColors.info;
        } else if (exam.canStart) {
          statusBadgeText = 'متاح للاختبار الآن ⏱️';
          statusColor = AppColors.primary;
        } else {
          statusBadgeText = 'مغلق أو مستنفد المحاولات';
          statusColor = Colors.grey;
        }

        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      color: AppColors.error,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusBadgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          exam.exam.title,
                          style: AppTypography.titleMedium(
                            textPrimary,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المدة: ${exam.exam.durationMinutes} دقيقة  ·  درجة النجاح: ${exam.exam.passScore}  ·  المحاولات: ${exam.attemptCount} من ${exam.exam.maxAttempts}',
                          style: AppTypography.caption(
                            textSecondary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (exam.canReview)
                    OutlinedButton.icon(
                      onPressed: () => _showAssessmentReview(
                        rpcName: 'get_my_exam_review',
                        params: {'p_exam_id': exam.exam.id},
                        titleFallback: exam.exam.title,
                      ),
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('مراجعة النتيجة والإجابات'),
                    ),
                  if (exam.canStart)
                    PrimaryButton(
                      text: 'بدء الاختبار الآن 🚀',
                      expand: false,
                      height: 40,
                      onPressed: () => _startExam(exam),
                      color: AppColors.primary,
                    )
                  else if (exam.resetRequestStatus == 'pending')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'بانتظار موافقة المعلم على الإعادة ⏳',
                        style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (exam.resetRequestStatus == 'rejected')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'تم رفض طلب الإعادة ❌',
                        style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (exam.attemptCount >= exam.exam.maxAttempts)
                    PrimaryButton(
                      text: 'طلب إعادة محاولة ⚠️',
                      expand: false,
                      height: 40,
                      onPressed: () => _requestExamReset(exam),
                      color: AppColors.error,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_sessionList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 64,
              color: AppColors.warning.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد حصص مسجلة حالياً',
              style: AppTypography.titleLarge(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد سجلات حضور مسجلة لهذه المجموعة بعد.',
              style: AppTypography.bodyMedium(textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _sessionList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = _sessionList[index];
        final isDone = session.status == SessionStatus.completed;
        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isDone ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone
                      ? Icons.check_circle_outline_rounded
                      : Icons.event_note_rounded,
                  color: isDone ? AppColors.success : AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حصة دراسية ${session.location != null && session.location!.isNotEmpty ? "· ${session.location}" : ""}',
                      style: AppTypography.titleMedium(
                        textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.sessionDate.toLocal().toString().split(" ")[0],
                      style: AppTypography.caption(
                        textSecondary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isDone ? AppColors.success : AppColors.info)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDone ? 'مكتملة' : 'مجدولة',
                  style: AppTypography.caption(
                    isDone ? AppColors.success : AppColors.info,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

typedef _OpenLessonResource =
    Future<void> Function({
      required Semester semester,
      required Unit unit,
      required Lesson lesson,
      required LessonResource resource,
    });

typedef _OpenLessonBoard =
    Future<void> Function({
      required Semester semester,
      required Unit unit,
      required Lesson lesson,
    });

class _StudentUnitSection extends StatelessWidget {
  final Semester semester;
  final Unit unit;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;
  final _OpenLessonResource onOpenResource;
  final _OpenLessonBoard onOpenLessonBoard;

  const _StudentUnitSection({
    required this.semester,
    required this.unit,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
    required this.onOpenResource,
    required this.onOpenLessonBoard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        leading: const Icon(Icons.folder_copy_rounded, color: AppColors.info),
        title: Text(
          unit.name,
          style: AppTypography.bodyLarge(
            textPrimary,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${unit.lessons.length} دروس',
          style: AppTypography.caption(textSecondary),
        ),
        children: [
          for (final lesson in unit.lessons)
            _StudentLessonRow(
              semester: semester,
              unit: unit,
              lesson: lesson,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onOpenResource: onOpenResource,
              onOpenLessonBoard: onOpenLessonBoard,
            ),
        ],
      ),
    );
  }
}

class _StudentLessonRow extends StatelessWidget {
  final Semester semester;
  final Unit unit;
  final Lesson lesson;
  final Color textPrimary;
  final Color textSecondary;
  final _OpenLessonResource onOpenResource;
  final _OpenLessonBoard onOpenLessonBoard;

  const _StudentLessonRow({
    required this.semester,
    required this.unit,
    required this.lesson,
    required this.textPrimary,
    required this.textSecondary,
    required this.onOpenResource,
    required this.onOpenLessonBoard,
  });

  @override
  Widget build(BuildContext context) {
    final resources = [...lesson.resources]
      ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.play_lesson_rounded,
              color: AppColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: AppTypography.bodyLarge(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (lesson.estimatedDurationMinutes != null)
                      '${lesson.estimatedDurationMinutes} دقيقة',
                    '${resources.length} ملفات',
                  ].join(' · '),
                  style: AppTypography.caption(textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.draw_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      label: const Text(
                        'سبورة شرح المعلم ومذاكرتي',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () => onOpenLessonBoard(
                        semester: semester,
                        unit: unit,
                        lesson: lesson,
                      ),
                    ),
                    for (final resource in resources)
                      ActionChip(
                        avatar: Icon(
                          resource.resourceType == 'pdf'
                              ? Icons.picture_as_pdf_rounded
                              : Icons.insert_drive_file_rounded,
                          size: 16,
                        ),
                        label: Text(resource.title),
                        onPressed: () => onOpenResource(
                          semester: semester,
                          unit: unit,
                          lesson: lesson,
                          resource: resource,
                        ),
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
}
