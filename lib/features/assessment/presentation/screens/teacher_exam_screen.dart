import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../widgets/group_leaderboard_widget.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import 'student_submissions_screen.dart';
import 'smart_exam_generator_dialog.dart';

class TeacherExamScreen extends StatefulWidget {
  final String teacherId;

  const TeacherExamScreen({super.key, required this.teacherId});

  @override
  State<TeacherExamScreen> createState() => _TeacherExamScreenState();
}

class _TeacherExamScreenState extends State<TeacherExamScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseExamRepository _examRepo;
  late final SupabaseQuestionBankRepository _questionRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _attemptStatusLabel(String? status) {
    switch (status) {
      case 'in_progress':
        return 'قيد الإجابة';
      case 'submitted':
        return 'تم التسليم';
      case 'graded':
        return 'تم التصحيح والتقييم';
      case 'expired':
        return 'منتهي الصلاحية';
      default:
        final value = status?.trim();
        return value == null || value.isEmpty ? 'غير معروف' : value;
    }
  }

  String _examStatusArabic(String status) {
    switch (status) {
      case 'published':
        return 'منشور ومتاح';
      case 'closed':
        return 'مغلق ومكتمل';
      case 'draft':
        return 'مسودة';
      default:
        return status;
    }
  }

  String _questionTypeArabic(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'اختيار من متعدد';
      case QuestionType.trueFalse:
        return 'صح وخطأ';
      case QuestionType.shortAnswer:
        return 'إجابة قصيرة';
      case QuestionType.longAnswer:
        return 'إجابة مقالية';
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final period = d.hour >= 12 ? 'م' : 'ص';
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}/${d.month}/${d.day} $hour:$min $period';
  }

  Future<List<Map<String, dynamic>>> _loadExamAttemptsForReview(
    String examId,
  ) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'get_teacher_exam_attempts',
        params: {'p_exam_id': examId},
      );
      final attempts = List<Map<String, dynamic>>.from(res);
      if (attempts.isNotEmpty) return attempts;
      debugPrint('get_teacher_exam_attempts returned no rows, using fallback');
    } catch (e) {
      debugPrint('get_teacher_exam_attempts failed, using fallback: $e');
    }

    final attemptsRes = await Supabase.instance.client
        .from('exam_attempts')
        .select('*')
        .eq('exam_id', examId)
        .order('attempt_number', ascending: true);
    final attempts = List<Map<String, dynamic>>.from(attemptsRes);
    final studentIds = attempts
        .map((attempt) => attempt['student_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (studentIds.isEmpty) return attempts;

    final studentsRes = await Supabase.instance.client
        .from('students')
        .select('id, student_code, profile_id')
        .inFilter('id', studentIds);
    final studentsById = {
      for (final raw in List<Map<String, dynamic>>.from(studentsRes))
        raw['id']?.toString(): raw,
    };
    final profileIds = studentsById.values
        .map((student) => student['profile_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final profilesById = <String, Map<String, dynamic>>{};
    if (profileIds.isNotEmpty) {
      try {
        final profilesRes = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, phone_number')
            .inFilter('id', profileIds);
        profilesById.addEntries(
          List<Map<String, dynamic>>.from(
            profilesRes,
          ).map((profile) => MapEntry(profile['id'].toString(), profile)),
        );
      } catch (e) {
        debugPrint('Fallback profiles lookup failed: $e');
      }
    }

    return attempts.map((attempt) {
      final student = studentsById[attempt['student_id']?.toString()];
      final profile = profilesById[student?['profile_id']?.toString()];
      return {
        ...attempt,
        'student_code': student?['student_code'],
        'student_phone': profile?['phone_number'],
        'student_name':
            profile?['full_name'] ??
            student?['student_code'] ??
            'Unknown Student',
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _examRepo = SupabaseExamRepository(wrapper);
    _questionRepo = SupabaseQuestionBankRepository(wrapper);
    _loadGroupsAndExams();
  }

  Future<void> _loadGroupsAndExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected;
      if (_selectedGroup == null) {
        selected = groups.isNotEmpty ? groups.first : null;
      } else {
        for (final group in groups) {
          if (group.id == _selectedGroup!.id) {
            selected = group;
            break;
          }
        }
      }
      final exams = selected == null
          ? <Exam>[]
          : await _examRepo.fetchExamsForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _exams = exams;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectGroup(GroupEntity? group) async {
    setState(() => _selectedGroup = group);
    await _loadGroupsAndExams();
  }

  void _showCreateExamDialog() {
    final group = _selectedGroup;
    if (group == null) return;

    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '60');
    final passCtrl = TextEditingController(text: '60');
    DateTime? availableFrom;
    DateTime availableUntil = DateTime.now().add(const Duration(days: 7));
    bool isSubmitting = false;

    Future<DateTime?> pickDateTime(DateTime initial) async {
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        confirmText: 'تأكيد',
        cancelText: 'إلغاء',
      );
      if (date == null || !mounted) return null;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        confirmText: 'تأكيد',
        cancelText: 'إلغاء',
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.quiz_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إنشاء امتحان جديد 📝',
                                  style: AppTypography.titleLarge(textColor).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'المجموعة: ${group.name}',
                                  style: AppTypography.caption(AppColors.primary).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepOrange.withValues(alpha: 0.12),
                              Colors.orange.withValues(alpha: 0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Colors.deepOrange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تريد توليد امتحان متوازن تلقائياً من بنك الأسئلة؟',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.deepOrange.withValues(alpha: 0.2),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                SmartExamGeneratorDialog.show(
                                  context,
                                  teacherId: widget.teacherId,
                                  initialGroupId: group.id,
                                  initialSubjectId: group.subjectId,
                                  groupName: group.name,
                                  onExamGenerated: (_) => _loadGroupsAndExams(),
                                );
                              },
                              child: const Text(
                                'توليد ذكي ⚡',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextFormField(
                        controller: titleCtrl,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: 'عنوان الامتحان أو الاختبار *',
                          hintText: 'مثال: امتحان منتصف الفصل - قوانين نيوتن',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى إدخال عنوان الامتحان';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: durationCtrl,
                              style: TextStyle(color: textColor),
                              decoration: const InputDecoration(
                                labelText: 'المدة (بالدقائق) *',
                                hintText: '60',
                                prefixIcon: Icon(Icons.timer_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'أدخل المدة';
                                }
                                final val = int.tryParse(v);
                                if (val == null || val <= 0) {
                                  return 'مدة غير صحيحة';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: passCtrl,
                              style: TextStyle(color: textColor),
                              decoration: const InputDecoration(
                                labelText: 'درجة النجاح *',
                                hintText: '60',
                                prefixIcon: Icon(Icons.grade_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'أدخل درجة النجاح';
                                }
                                final val = double.tryParse(v);
                                if (val == null || val <= 0) {
                                  return 'درجة غير صحيحة';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.play_circle_outline_rounded,
                                color: Colors.green,
                              ),
                              title: const Text('يبدأ الامتحان في'),
                              subtitle: Text(
                                availableFrom == null
                                    ? 'متاح فور النشر مباشرة'
                                    : _formatDateTime(availableFrom!),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: OutlinedButton(
                                onPressed: () async {
                                  final picked = await pickDateTime(
                                    availableFrom ?? DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => availableFrom = picked);
                                  }
                                },
                                child: const Text('تحديد'),
                              ),
                            ),
                            const Divider(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.lock_clock_rounded,
                                color: Colors.orange,
                              ),
                              title: const Text('ينتهي الامتحان في'),
                              subtitle: Text(
                                _formatDateTime(availableUntil),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: OutlinedButton(
                                onPressed: () async {
                                  final picked = await pickDateTime(availableUntil);
                                  if (picked != null) {
                                    setDialogState(() => availableUntil = picked);
                                  }
                                },
                                child: const Text('تعديل'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            child: Text(
                              'إلغاء',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    if (availableFrom != null &&
                                        availableUntil.isBefore(availableFrom!)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'يجب أن يكون موعد انتهاء الامتحان بعد موعد البدء',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() => isSubmitting = true);
                                    final nav = Navigator.of(ctx);
                                    try {
                                      await Supabase.instance.client.rpc(
                                        'create_exam_assignment',
                                        params: {
                                          'p_title': titleCtrl.text.trim(),
                                          'p_subject_id': group.subjectId,
                                          'p_group_id': group.id,
                                          'p_duration_minutes':
                                              int.tryParse(durationCtrl.text) ?? 60,
                                          'p_pass_score':
                                              double.tryParse(passCtrl.text) ?? 60.0,
                                          'p_status': 'published',
                                          'p_available_from': availableFrom
                                              ?.toIso8601String(),
                                          'p_available_until': availableUntil
                                              .toIso8601String(),
                                        },
                                      );
                                      nav.pop();
                                      await _loadGroupsAndExams();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم نشر الامتحان وتفعيله للطلاب بنجاح 🚀'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      setDialogState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('فشل إنشاء الامتحان: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(isSubmitting ? 'جاري النشر...' : 'نشر الامتحان للطلاب 🚀'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showManageQuestionsBottomSheet(Exam exam) async {
    final group = _selectedGroup;
    if (group == null) return;

    final Set<String> initiallyLinkedIds = exam.questions
        .map((q) => q.id)
        .toSet();
    final Set<String> currentSelectedIds = Set<String>.from(initiallyLinkedIds);
    bool isSaving = false;
    String filterQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: FutureBuilder<List<Question>>(
                future: _questionRepo.fetchQuestionsForSubject(group.subjectId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'فشل تحميل الأسئلة: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final allQuestions = snapshot.data ?? [];
                  if (allQuestions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.quiz_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد أسئلة مضافة في بنك الأسئلة بعد.',
                              style: TextStyle(color: textColor, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'يمكنك إضافة الأسئلة من تبويب بنك الأسئلة ثم ربطها بالامتحان.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final displayedQuestions = allQuestions.where((q) {
                    if (filterQuery.trim().isEmpty) return true;
                    return q.prompt.toLowerCase().contains(filterQuery.toLowerCase());
                  }).toList();

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'إدارة وربط أسئلة الامتحان ❓',
                              style: AppTypography.titleLarge(textColor).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exam.title,
                              style: AppTypography.bodySmall(AppColors.primary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'ابحث في الأسئلة المتاحة...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (val) => setModalState(() => filterQuery = val),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${currentSelectedIds.length} من أصل ${allQuestions.length} سؤال محدد',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              icon: Icon(
                                currentSelectedIds.length == allQuestions.length
                                    ? Icons.deselect_rounded
                                    : Icons.select_all_rounded,
                                size: 16,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  if (currentSelectedIds.length == allQuestions.length) {
                                    currentSelectedIds.clear();
                                  } else {
                                    currentSelectedIds.addAll(
                                      allQuestions.map((q) => q.id),
                                    );
                                  }
                                });
                              },
                              label: Text(
                                currentSelectedIds.length == allQuestions.length
                                    ? 'إلغاء تحديد الكل'
                                    : 'تحديد الكل',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 8),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: displayedQuestions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final q = displayedQuestions[index];
                            final isLinked = currentSelectedIds.contains(q.id);

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setModalState(() {
                                  if (isLinked) {
                                    currentSelectedIds.remove(q.id);
                                  } else {
                                    currentSelectedIds.add(q.id);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLinked
                                        ? AppColors.primary
                                        : Colors.grey.withValues(alpha: 0.2),
                                    width: isLinked ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isLinked,
                                      activeColor: AppColors.primary,
                                      onChanged: (val) {
                                        if (val == null) return;
                                        setModalState(() {
                                          if (val) {
                                            currentSelectedIds.add(q.id);
                                          } else {
                                            currentSelectedIds.remove(q.id);
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            q.prompt,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  _questionTypeArabic(q.questionType),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${q.defaultPoints.toStringAsFixed(0)} درجات',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.amber.shade900,
                                                    fontWeight: FontWeight.bold,
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
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setModalState(() => isSaving = true);
                                  try {
                                    final additions = currentSelectedIds
                                        .difference(initiallyLinkedIds);
                                    final removals = initiallyLinkedIds
                                        .difference(currentSelectedIds);

                                    for (final id in additions) {
                                      final q = allQuestions.firstWhere(
                                        (q) => q.id == id,
                                      );
                                      await _examRepo.linkQuestion(
                                        exam.id,
                                        q.id,
                                        q.defaultPoints,
                                      );
                                    }
                                    for (final id in removals) {
                                      await _examRepo.unlinkQuestion(
                                        exam.id,
                                        id,
                                      );
                                    }

                                    await _loadGroupsAndExams();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'تم تحديث أسئلة الامتحان بنجاح (${currentSelectedIds.length} سؤال)',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('فشل حفظ الأسئلة: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => isSaving = false);
                                    }
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            isSaving
                                ? 'جاري حفظ الأسئلة...'
                                : 'حفظ الأسئلة (${currentSelectedIds.length} سؤال)',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showSendWhatsAppDialog({
    required String studentName,
    required String examTitle,
    required num score,
    required num maxScore,
    String? defaultPhone,
    int? rank,
  }) {
    final phoneCtrl = TextEditingController(text: defaultPhone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('إرسال النتيجة لواتساب ولي الأمر'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطالب: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('الدرجة: $score من $maxScore'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف ولي الأمر (واتساب)',
                hintText: 'مثال: 01012345678',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.send_rounded),
            label: const Text('إرسال عبر واتساب'),
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;
              Navigator.pop(ctx);
              await WhatsAppService.sendExamResultToParent(
                parentPhone: phone,
                studentName: studentName,
                examTitle: examTitle,
                score: score,
                maxScore: maxScore,
                centerName: 'سنتر الأوائل التعليمي',
                teacherName: 'مدرس المادة',
                subjectName: _selectedGroup?.name ?? 'المادة الدراسية',
                rank: rank,
                groupName: _selectedGroup?.name,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportPrintableExam(Exam exam) async {
    if (exam.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الامتحان لا يحتوي على أسئلة مرتبطة بعد! يرجى ربط أسئلة أولاً عبر إدارة الأسئلة.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final questionsData = exam.questions.map((q) {
        return {
          'prompt': q.prompt,
          'points': q.defaultPoints,
          'type': q.questionType.toDbValue(),
          'options': q.options.map((opt) => {'text': opt.text, 'is_correct': opt.isCorrect}).toList(),
        };
      }).toList();

      await ReportGeneratorService().generatePrintableExamSheet(
        centerName: 'سنتر الأوائل التعليمي',
        examTitle: exam.title,
        subjectName: _selectedGroup?.name ?? 'المادة الدراسية',
        teacherName: 'الأستاذ المشرف',
        durationMinutes: exam.durationMinutes,
        passScore: exam.passScore,
        questions: questionsData,
        groupName: _selectedGroup?.name,
        includeBubbleSheet: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم توليد ورقة امتحان (${exam.title}) مع نموذج الإجابة والبابل شيت بنجاح 📄'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل توليد الامتحان المطبوع: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportStandaloneBubbleSheet(Exam exam) async {
    try {
      await ReportGeneratorService().generateStandaloneBubbleSheetPdf(
        centerName: 'سنتر الأوائل التعليمي',
        teacherName: 'الأستاذ المشرف',
        examTitle: exam.title,
        groupName: _selectedGroup?.name,
        subjectName: _selectedGroup?.name ?? 'المادة الدراسية',
        questionCount: exam.questions.isNotEmpty ? exam.questions.length : 30,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم توليد ورقة إجابة البابل شيت الرسمية (${exam.title}) بنجاح 📑'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل توليد البابل شيت: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showExamAttemptsDialog(Exam exam) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    List<Map<String, dynamic>> attempts = [];
    Object? loadError;
    try {
      attempts = await _loadExamAttemptsForReview(exam.id);
    } catch (e) {
      loadError = e;
      debugPrint('Error fetching attempts: $e');
    }

    if (!context.mounted) return;
    Navigator.pop(context);

    final totalAttempts = attempts.length;
    double totalScores = 0;
    num topScore = 0;
    int passCount = 0;
    for (final a in attempts) {
      final sc = (a['score'] as num?) ?? 0;
      totalScores += sc;
      if (sc > topScore) topScore = sc;
      if (sc >= exam.passScore) passCount++;
    }
    final avgScore = totalAttempts > 0 ? totalScores / totalAttempts : 0.0;
    final passRate = totalAttempts > 0 ? (passCount / totalAttempts) * 100 : 0.0;

    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filteredAttempts = attempts.where((att) {
            if (searchQuery.trim().isEmpty) return true;
            final q = searchQuery.trim().toLowerCase();
            final name = (att['student_name']?.toString() ?? '').toLowerCase();
            final code = (att['student_code']?.toString() ?? '').toLowerCase();
            return name.contains(q) || code.contains(q);
          }).toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 650),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                        child: const Icon(Icons.analytics_rounded, color: Colors.deepPurple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'كشف نتائج ومحاولات الطلاب 📊',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '${exam.title} • ${_selectedGroup?.name ?? ''}',
                              style: TextStyle(fontSize: 12, color: subtitleColor),
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
                  const SizedBox(height: 14),

                  // Metrics Row
                  Row(
                    children: [
                      _buildExamMetricBox('إجمالي المحاولات', '$totalAttempts', Colors.blueGrey),
                      const SizedBox(width: 8),
                      _buildExamMetricBox('نسبة النجاح', '${passRate.toStringAsFixed(0)}%', Colors.green),
                      const SizedBox(width: 8),
                      _buildExamMetricBox('متوسط الدرجات', avgScore.toStringAsFixed(1), Colors.purple),
                      const SizedBox(width: 8),
                      _buildExamMetricBox('أعلى درجة', '$topScore', Colors.amber.shade900),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search and PDF Export Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'ابحث باسم الطالب أو الكود...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) => setDialogState(() => searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onPressed: () async {
                          try {
                            final examData = attempts.map((a) => {
                              'title': exam.title,
                              'duration': exam.durationMinutes.toString(),
                              'pass_score': exam.passScore.toString(),
                              'status': a['status']?.toString() ?? 'completed',
                            }).toList();
                            await ReportGeneratorService().generateExamReport(
                              groupName: _selectedGroup?.name ?? 'المجموعة',
                              examData: examData,
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ في تصدير التقرير: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.indigo),
                        label: const Text('كشف الدرجات PDF', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  if (loadError != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'فشل تحميل محاولات الطلاب: $loadError',
                        style: AppTypography.bodyMedium(AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (attempts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'لا توجد محاولات تسليم لهذا الامتحان حتى الآن.',
                        style: AppTypography.bodyMedium(subtitleColor),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredAttempts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final att = filteredAttempts[i];
                          final studentName =
                              att['student_name']?.toString().trim().isNotEmpty == true
                                  ? att['student_name'].toString()
                                  : 'طالب غير معروف';
                          final studentCode = att['student_code']?.toString();
                          final statusLabel = _attemptStatusLabel(
                            att['status']?.toString(),
                          );
                          final studentId = att['student_id']?.toString();
                          final score = (att['score'] as num?) ?? 0;
                          final isPassed = score >= exam.passScore;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isPassed
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.red.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isPassed
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.1),
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPassed ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studentName,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${studentCode == null || studentCode.isEmpty ? '' : '$studentCode • '}الحالة: $statusLabel',
                                        style: TextStyle(fontSize: 11, color: subtitleColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPassed
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$score / ${att['max_score'] ?? 0}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isPassed ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 20),
                                  tooltip: 'مراجعة وتصحيح الإجابات 📝',
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StudentSubmissionsScreen(
                                          initialSubmission: {
                                            'id': att['id'],
                                            'assessment_type': 'exam',
                                            'assessment_id': exam.id,
                                            'assessment_title': exam.title,
                                            'student_id': att['student_id'],
                                            'student_full_name': studentName,
                                            'score': att['score'],
                                            'max_score': exam.totalMarks,
                                            'teacher_feedback': att['teacher_feedback'],
                                          },
                                          onGraded: () {
                                            _loadGroupsAndExams();
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat_rounded, color: Colors.green, size: 20),
                                  tooltip: 'إرسال النتيجة لولي الأمر عبر واتساب',
                                  onPressed: () {
                                    _showSendWhatsAppDialog(
                                      studentName: studentName,
                                      examTitle: exam.title,
                                      score: att['score'] ?? 0,
                                      maxScore: att['max_score'] ?? 0,
                                      defaultPhone: att['student_phone']?.toString(),
                                      rank: i + 1,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: AppColors.error, size: 20),
                                  tooltip: 'إعادة تعيين المحاولة',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (c) => AlertDialog(
                                        title: const Text('إعادة تعيين الامتحان'),
                                        content: Text(
                                          'هل أنت متأكد من رغبتك في إعادة تعيين الامتحان للطالب $studentName؟ سيتم مسح محاولته الحالية وإتاحة الامتحان له مجدداً.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(c, false),
                                            child: const Text('إلغاء'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                            ),
                                            onPressed: () => Navigator.pop(c, true),
                                            child: const Text('إعادة تعيين'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && studentId != null) {
                                      try {
                                        await Supabase.instance.client.rpc(
                                          'reset_student_exam_attempt',
                                          params: {
                                            'p_exam_id': exam.id,
                                            'p_student_id': studentId,
                                          },
                                        );
                                        await _loadGroupsAndExams();
                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'تمت إعادة تعيين محاولة الامتحان بنجاح',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('فشلت إعادة التعيين: $e')),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamMetricBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExam(Exam exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الامتحان نهائياً 🗑️'),
        content: Text(
          'هل أنت متأكد من حذف امتحان "${exam.title}"؟\n'
          'سيتم مسح كافة محاولات ودرجات الطلاب المسجلة به نهائياً ولا يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _examRepo.deleteExam(exam.id);
      await _loadGroupsAndExams();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الامتحان وسجلاته بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف الامتحان: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _closeExam(Exam exam) async {
    if (exam.status == 'closed') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق الامتحان 🔒'),
        content: Text(
          'هل أنت متأكد من إغلاق امتحان "${exam.title}"؟\n'
          'لن يتمكن الطلاب من بدء محاولات جديدة أو تسليم إجاباتهم بعد الإغلاق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إغلاق الامتحان الآن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _examRepo.closeExam(exam.id);
      await _loadGroupsAndExams();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إغلاق الامتحان بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إغلاق الامتحان: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadGroupsAndExams,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'حدث خطأ: $_errorMessage',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadGroupsAndExams,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          child: DropdownButtonFormField<GroupEntity>(
                            initialValue: _selectedGroup,
                            dropdownColor: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            decoration: const InputDecoration(
                              labelText: 'المجموعة الدراسية',
                              border: InputBorder.none,
                            ),
                            items: _groups
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g.name,
                                      style: TextStyle(color: textColor),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _groups.isEmpty ? null : _selectGroup,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                                label: const Text('لوحة شرف الأوائل ونظام التحفيز 🏆'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.amber.shade50,
                                  foregroundColor: isDark ? Colors.amber : Colors.amber.shade900,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                                  ),
                                ),
                                onPressed: () {
                                  GroupLeaderboardWidget.show(
                                    context,
                                    groupId: _selectedGroup?.id,
                                    groupName: _selectedGroup?.name,
                                    availableGroups: _groups,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (_selectedGroup == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'لم يتم العثور على مجموعات دراسية مسندة.',
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else if (_exams.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.quiz_outlined,
                                    size: 40,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد امتحانات منشورة لهذه المجموعة حتى الآن',
                                  style: AppTypography.titleMedium(textColor).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'يمكنك توليد امتحان ذكي متوازن فوراً أو إنشاء امتحان يدوياً',
                                  style: AppTypography.bodySmall(subtitleColor),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.deepOrange,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        SmartExamGeneratorDialog.show(
                                          context,
                                          teacherId: widget.teacherId,
                                          initialGroupId: _selectedGroup?.id,
                                          initialSubjectId: _selectedGroup?.subjectId,
                                          groupName: _selectedGroup?.name,
                                          onExamGenerated: (_) => _loadGroupsAndExams(),
                                        );
                                      },
                                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                                      label: const Text('توليد امتحان ذكي ⚡'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _showCreateExamDialog,
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      label: const Text('إنشاء يدوي 📝'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final exam = _exams[i];
                            final isClosed = exam.status.toLowerCase() == 'closed';

                            return FadeInSlide(
                              duration: Duration(milliseconds: 250 + (i * 40)),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: (isClosed ? Colors.orange : AppColors.primary)
                                                .withValues(alpha: 0.15),
                                            child: Icon(
                                              isClosed ? Icons.lock_clock_rounded : Icons.quiz_rounded,
                                              color: isClosed ? Colors.orange : AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        exam.title,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: AppTypography.titleMedium(
                                                          textColor,
                                                        ).copyWith(
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: (isClosed ? Colors.orange : Colors.green)
                                                            .withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        _examStatusArabic(exam.status),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: isClosed ? Colors.orange : Colors.green,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '⏱️ ${exam.durationMinutes} دقيقة',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.blue,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.teal.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'درجة النجاح: ${exam.passScore.toStringAsFixed(0)}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.teal,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            tooltip: 'خيارات الامتحان',
                                            icon: const Icon(Icons.more_vert_rounded),
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'attempts':
                                                  _showExamAttemptsDialog(exam);
                                                  break;
                                                case 'print_exam':
                                                  _exportPrintableExam(exam);
                                                  break;
                                                case 'print_bubble_sheet':
                                                  _exportStandaloneBubbleSheet(exam);
                                                  break;
                                                case 'questions':
                                                  _showManageQuestionsBottomSheet(exam);
                                                  break;
                                                case 'close':
                                                  _closeExam(exam);
                                                  break;
                                                case 'delete':
                                                  _deleteExam(exam);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'attempts',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.analytics_rounded,
                                                    color: Colors.indigo,
                                                  ),
                                                  title: Text('كشف النتائج والمحاولات 📊'),
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'print_exam',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.print_rounded,
                                                    color: Colors.teal,
                                                  ),
                                                  title: Text('طباعة الامتحان + البابل شيت (PDF) 📄'),
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'print_bubble_sheet',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.fact_check_outlined,
                                                    color: Colors.purple,
                                                  ),
                                                  title: Text('طباعة نموذج بابل شيت فارغ 📑'),
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'questions',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.quiz_rounded,
                                                    color: AppColors.primary,
                                                  ),
                                                  title: Text('إدارة وربط الأسئلة ❓'),
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                              if (!isClosed)
                                                const PopupMenuItem(
                                                  value: 'close',
                                                  child: ListTile(
                                                    leading: Icon(
                                                      Icons.lock_outline_rounded,
                                                      color: AppColors.warning,
                                                    ),
                                                    title: Text('إغلاق الامتحان 🔒'),
                                                    contentPadding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.delete_outline_rounded,
                                                    color: AppColors.error,
                                                  ),
                                                  title: Text('حذف الامتحان 🗑️'),
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${exam.questions.length} سؤال مضاف',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 4,
                                              ),
                                            ),
                                            onPressed: () => _showExamAttemptsDialog(exam),
                                            icon: const Icon(
                                              Icons.analytics_rounded,
                                              size: 15,
                                            ),
                                            label: const Text(
                                              'كشف النتائج والمحاولات',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }, childCount: _exams.length),
                        ),
                      ),
                  ],
                ),
        ),

        if (_selectedGroup != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'smart_exam_fab',
                  onPressed: () {
                    SmartExamGeneratorDialog.show(
                      context,
                      teacherId: widget.teacherId,
                      initialGroupId: _selectedGroup?.id,
                      initialSubjectId: _selectedGroup?.subjectId,
                      groupName: _selectedGroup?.name,
                      onExamGenerated: (_) => _loadGroupsAndExams(),
                    );
                  },
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('توليد ذكي ⚡'),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.extended(
                  heroTag: 'manual_exam_fab',
                  onPressed: _showCreateExamDialog,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.quiz_rounded),
                  label: const Text('إنشاء امتحان جديد 📝'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
