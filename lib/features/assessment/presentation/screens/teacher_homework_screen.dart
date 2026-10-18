import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import 'student_submissions_screen.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class TeacherHomeworkScreen extends StatefulWidget {
  final String teacherId;

  const TeacherHomeworkScreen({super.key, required this.teacherId});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen> {
  late final SupabaseHomeworkRepository _homeworkRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseQuestionBankRepository _questionRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Homework> _homeworks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _homeworkRepo = SupabaseHomeworkRepository(wrapper);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _questionRepo = SupabaseQuestionBankRepository(wrapper);
    _loadGroupsAndHomeworks();
  }

  Future<void> _loadGroupsAndHomeworks() async {
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
      final homeworks = selected == null
          ? <Homework>[]
          : await _homeworkRepo.fetchHomeworkForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _homeworks = homeworks;
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

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final period = d.hour >= 12 ? 'م' : 'ص';
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}/${d.month}/${d.day} $hour:$min $period';
  }

  String _questionTypeName(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'اختيار من متعدد';
      case QuestionType.trueFalse:
        return 'صح أو خطأ';
      case QuestionType.shortAnswer:
        return 'إجابة قصيرة';
      case QuestionType.longAnswer:
        return 'سؤال مقالي';
    }
  }

  String _statusArabic(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return 'متاح للحل';
      case 'closed':
        return 'مغلق';
      case 'draft':
        return 'مسودة';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.green;
      case 'closed':
        return Colors.orange;
      case 'draft':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _selectGroup(GroupEntity? group) async {
    setState(() => _selectedGroup = group);
    await _loadGroupsAndHomeworks();
  }

  void _showCreateHomeworkDialog() {
    final group = _selectedGroup;
    if (group == null) return;

    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '100');
    DateTime? availableFrom;
    DateTime dueAt = DateTime.now().add(const Duration(days: 7));
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
                              Icons.assignment_add,
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
                                  'إضافة واجب جديد 📝',
                                  style: AppTypography.titleLarge(textColor).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'مجموعة: ${group.name}',
                                  style: AppTypography.caption(
                                    AppColors.primary,
                                  ).copyWith(fontWeight: FontWeight.w600),
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
                      TextFormField(
                        controller: titleCtrl,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: 'عنوان الواجب *',
                          hintText: 'مثال: واجب الأسبوع الأول - القوى والحركة',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى إدخال عنوان الواجب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descCtrl,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: 'تعليمات وإرشادات للطلاب (اختياري)',
                          hintText: 'اكتب أي ملاحظات للطلاب قبل البدء في حل الواجب...',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: ptsCtrl,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: 'الدرجة الكلية للواجب *',
                          hintText: 'مثال: 100',
                          prefixIcon: Icon(Icons.grade_rounded),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى إدخال الدرجة الكلية للواجب';
                          }
                          final val = double.tryParse(v);
                          if (val == null || val <= 0) {
                            return 'أدخل درجة صحيحة أكبر من صفر';
                          }
                          return null;
                        },
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
                              title: const Text('موعد إتاحة الواجب'),
                              subtitle: Text(
                                availableFrom == null
                                    ? 'فور النشر مباشرة'
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
                              title: const Text('آخر موعد للتسليم (الديدلاين)'),
                              subtitle: Text(
                                _formatDateTime(dueAt),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: OutlinedButton(
                                onPressed: () async {
                                  final picked = await pickDateTime(dueAt);
                                  if (picked != null) {
                                    setDialogState(() => dueAt = picked);
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
                                        dueAt.isBefore(availableFrom!)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'يجب أن يكون موعد التسليم بعد موعد إتاحة الواجب',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() => isSubmitting = true);
                                    final nav = Navigator.of(ctx);
                                    try {
                                      await _homeworkRepo.createHomework(
                                        Homework(
                                          id: '',
                                          title: titleCtrl.text.trim(),
                                          description: descCtrl.text.trim().isEmpty
                                              ? null
                                              : descCtrl.text.trim(),
                                          subjectId: group.subjectId,
                                          groupId: group.id,
                                          availableFrom: availableFrom,
                                          dueAt: dueAt,
                                          maxScore: double.tryParse(ptsCtrl.text) ?? 100.0,
                                          status: 'published',
                                        ),
                                      );
                                      nav.pop();
                                      await _loadGroupsAndHomeworks();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم نشر الواجب لطلاب المجموعة بنجاح 🚀'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      setDialogState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تعذر إنشاء الواجب: $e'),
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
                            label: Text(isSubmitting ? 'جاري النشر...' : 'نشر الواجب للطلاب 🚀'),
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

  void _showManageQuestionsBottomSheet(Homework homework) async {
    final group = _selectedGroup;
    if (group == null) return;

    final Set<String> initiallyLinkedIds = homework.questions
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
                        'خطأ في تحميل الأسئلة: ${snapshot.error}',
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
                              'لا توجد أسئلة مسجلة في بنك الأسئلة لهذه المادة بعد.',
                              style: TextStyle(color: textColor, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'يمكنك إضافة الأسئلة من تبويب بنك الأسئلة ثم ربطها بالواجب.',
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
                      // Handle bar
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
                              'إدارة وتحديد أسئلة الواجب ❓',
                              style: AppTypography.titleLarge(textColor).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              homework.title,
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
                            hintText: 'ابحث في الأسئلة...',
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
                                    currentSelectedIds.addAll(allQuestions.map((q) => q.id));
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
                                                  _questionTypeName(q.questionType),
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
                                      await _homeworkRepo.linkQuestion(
                                        homework.id,
                                        q.id,
                                        q.defaultPoints,
                                      );
                                    }
                                    for (final id in removals) {
                                      await _homeworkRepo.unlinkQuestion(
                                        homework.id,
                                        id,
                                      );
                                    }

                                    await _loadGroupsAndHomeworks();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'تم تحديث أسئلة الواجب بنجاح (${currentSelectedIds.length} سؤال)',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('حدث خطأ أثناء الحفظ: $e'),
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

  Future<void> _deleteHomework(Homework homework) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الواجب نهائياً 🗑️'),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف واجب "${homework.title}"؟\n'
          'سيتم حذف جميع إجابات وتسليمات الطلاب المرتبطة به نهائياً ولا يمكن التراجع.',
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
      await _homeworkRepo.deleteHomework(homework.id);
      await _loadGroupsAndHomeworks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الواجب وسجلاته بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف الواجب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _closeHomework(Homework homework) async {
    if (homework.status == 'closed') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق موعد تسليم الواجب 🔒'),
        content: Text(
          'هل أنت متأكد من إغلاق موعد تسليم "${homework.title}"؟\n'
          'لن يتمكن الطلاب من تقديم أي حلول أو تعديل إجاباتهم بعد الإغلاق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إغلاق الواجب الآن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _homeworkRepo.closeHomework(homework.id);
      await _loadGroupsAndHomeworks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إغلاق موعد تسليم الواجب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إغلاق الواجب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showHomeworkSubmissionsDialog(Homework homework) {
    final group = _selectedGroup;
    if (group == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _HomeworkSubmissionsDialogContent(
        homework: homework,
        group: group,
        onDataChanged: _loadGroupsAndHomeworks,
      ),
    );
  }

  Future<void> _printPrintableHomeworkSheet(Homework homework) async {
    final group = _selectedGroup;
    try {
      final questionsData = homework.questions.map((q) => {
        'prompt': q.prompt,
        'points': q.defaultPoints,
        'type': q.questionType.toDbValue(),
        'options': q.options.map((o) => {'text': o.text, 'is_correct': o.isCorrect}).toList(),
      }).toList();

      await ReportGeneratorService().generatePrintableHomeworkSheet(
        centerName: 'سنتر الأوائل التعليمي',
        homeworkTitle: homework.title,
        subjectName: group?.name ?? 'المادة',
        teacherName: 'المدرس المعتمد',
        groupName: group?.name,
        dueAt: homework.dueAt,
        maxScore: homework.maxScore,
        questions: questionsData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في توليد شيت الواجب: $e')),
        );
      }
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
          onRefresh: _loadGroupsAndHomeworks,
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
                            'حدث خطأ في تحميل البيانات: $_errorMessage',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadGroupsAndHomeworks,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('إعادة المحاولة'),
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
                              labelText: 'المجموعة الدراسية المختارة',
                              prefixIcon: Icon(Icons.group_rounded, color: AppColors.primary),
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
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (_selectedGroup == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'لا توجد مجموعات دراسية مسندة إليك حالياً.',
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else if (_homeworks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لم تقم بنشر أي واجبات لهذه المجموعة بعد.',
                                  style: AppTypography.titleMedium(textColor).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'اضغط على زر "إضافة واجب جديد" بالأسفل لإنشاء أول واجب دراسي.',
                                  style: AppTypography.bodySmall(subtitleColor),
                                  textAlign: TextAlign.center,
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
                            final h = _homeworks[i];
                            final isClosed = h.status.toLowerCase() == 'closed';

                            return FadeInSlide(
                              duration: Duration(milliseconds: 250 + (i * 40)),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showHomeworkSubmissionsDialog(h),
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
                                                isClosed
                                                    ? Icons.assignment_late_rounded
                                                    : Icons.assignment_rounded,
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
                                                          h.title,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: AppTypography.titleMedium(textColor).copyWith(
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
                                                          color: _statusColor(h.status).withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          _statusArabic(h.status),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: _statusColor(h.status),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'آخر موعد للتسليم: ${_formatDateTime(h.dueAt)}',
                                                    style: AppTypography.caption(subtitleColor),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              tooltip: 'خيارات الواجب',
                                              icon: const Icon(Icons.more_vert_rounded),
                                              onSelected: (value) {
                                                switch (value) {
                                                  case 'submissions':
                                                    _showHomeworkSubmissionsDialog(h);
                                                    break;
                                                  case 'print_sheet':
                                                    _printPrintableHomeworkSheet(h);
                                                    break;
                                                  case 'questions':
                                                    _showManageQuestionsBottomSheet(h);
                                                    break;
                                                  case 'close':
                                                    _closeHomework(h);
                                                    break;
                                                  case 'delete':
                                                    _deleteHomework(h);
                                                    break;
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'submissions',
                                                  child: ListTile(
                                                    leading: Icon(
                                                      Icons.assignment_turned_in_rounded,
                                                      color: Colors.blue,
                                                    ),
                                                    title: Text('كشف التسليمات والتصحيح 📋'),
                                                    contentPadding: EdgeInsets.zero,
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'print_sheet',
                                                  child: ListTile(
                                                    leading: Icon(
                                                      Icons.print_rounded,
                                                      color: Colors.deepPurple,
                                                    ),
                                                    title: Text('طباعة شيت واجب ورقي (PDF) 🖨️'),
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
                                                    title: Text('إدارة وتحديد الأسئلة ❓'),
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
                                                      title: Text('إغلاق موعد التسليم 🔒'),
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
                                                    title: Text('حذف الواجب 🗑️'),
                                                    contentPadding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
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
                                                    color: AppColors.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${h.questions.length} سؤال',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.primary,
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
                                                    'الدرجة: ${h.maxScore.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.teal,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            FilledButton.tonalIcon(
                                              style: FilledButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 4,
                                                ),
                                              ),
                                              onPressed: () => _showHomeworkSubmissionsDialog(h),
                                              icon: const Icon(
                                                Icons.assignment_turned_in_rounded,
                                                size: 15,
                                              ),
                                              label: const Text(
                                                'كشف التسليمات والتصحيح',
                                                style: TextStyle(fontSize: 11),
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
                          }, childCount: _homeworks.length),
                        ),
                      ),
                  ],
                ),
        ),
        if (_selectedGroup != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _showCreateHomeworkDialog,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.assignment_add),
              label: const Text('إضافة واجب جديد 📝'),
            ),
          ),
      ],
    );
  }
}

class _HomeworkSubmissionsDialogContent extends StatefulWidget {
  final Homework homework;
  final GroupEntity group;
  final VoidCallback onDataChanged;

  const _HomeworkSubmissionsDialogContent({
    required this.homework,
    required this.group,
    required this.onDataChanged,
  });

  @override
  State<_HomeworkSubmissionsDialogContent> createState() =>
      _HomeworkSubmissionsDialogContentState();
}

class _HomeworkSubmissionsDialogContentState
    extends State<_HomeworkSubmissionsDialogContent> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  String _filter = 'all'; // 'all', 'submitted', 'missing'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final studentRepo = SupabaseStudentRepository(wrapper);
      final students = await studentRepo.fetchStudentsForGroup(widget.group.id);

      final subsRes = await Supabase.instance.client
          .from('homework_submissions')
          .select('*')
          .eq('homework_id', widget.homework.id);

      final subsList = List<Map<String, dynamic>>.from(subsRes);
      final subsByStudent = {
        for (final sub in subsList) sub['student_id']?.toString(): sub,
      };

      final records = <Map<String, dynamic>>[];
      for (final st in students) {
        final sub = subsByStudent[st.id];
        final isSubmitted = sub != null;
        DateTime? submittedAt;
        if (sub != null) {
          final dateStr = sub['submitted_at'] ?? sub['created_at'];
          if (dateStr != null) {
            submittedAt = DateTime.tryParse(dateStr.toString())?.toLocal();
          }
        }
        final isLate = submittedAt != null && submittedAt.isAfter(widget.homework.dueAt);

        records.add({
          'student_id': st.id,
          'student_name': st.fullName,
          'student_code': st.studentCode,
          'phone_number': st.phoneNumber,
          'is_submitted': isSubmitted,
          'is_late': isLate,
          'submitted_at': submittedAt != null
              ? '${submittedAt.month}/${submittedAt.day} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}'
              : null,
          'score': sub?['score'],
          'status': sub?['status'] ?? (isSubmitted ? 'submitted' : 'missing'),
          'feedback': sub?['teacher_feedback'],
          'submission_raw': sub,
        });
      }

      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportRosterPdf() async {
    try {
      await ReportGeneratorService().generateHomeworkSubmissionsRosterPdf(
        centerName: 'سنتر الأوائل التعليمي',
        homeworkTitle: widget.homework.title,
        subjectName: widget.group.name,
        teacherName: 'المدرس المعتمد',
        groupName: widget.group.name,
        dueAt: widget.homework.dueAt,
        maxScore: widget.homework.maxScore,
        submissionsData: _records,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تصدير كشف التسليمات: $e')),
        );
      }
    }
  }

  Future<void> _exportPrintableSheetPdf() async {
    try {
      final questionsData = widget.homework.questions.map((q) => {
        'prompt': q.prompt,
        'points': q.defaultPoints,
        'type': q.questionType.toDbValue(),
        'options': q.options.map((o) => {'text': o.text, 'is_correct': o.isCorrect}).toList(),
      }).toList();

      await ReportGeneratorService().generatePrintableHomeworkSheet(
        centerName: 'سنتر الأوائل التعليمي',
        homeworkTitle: widget.homework.title,
        subjectName: widget.group.name,
        teacherName: 'المدرس المعتمد',
        groupName: widget.group.name,
        dueAt: widget.homework.dueAt,
        maxScore: widget.homework.maxScore,
        questions: questionsData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في توليد شيت الواجب الورقي: $e')),
        );
      }
    }
  }

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> r) async {
    final phone = r['phone_number']?.toString() ?? '';
    final studentName = r['student_name']?.toString() ?? '';

    final phoneController = TextEditingController(text: phone);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إرسال تذكير بالواجب لولي الأمر عبر واتساب 📲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطالب: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('الواجب: ${widget.homework.title}'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف ولي الأمر (واتساب)',
                prefixIcon: Icon(Icons.phone_rounded),
                hintText: '01XXXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );

    if (confirmed == true && phoneController.text.trim().isNotEmpty) {
      await WhatsAppService.sendHomeworkReminderToParent(
        parentPhone: phoneController.text.trim(),
        studentName: studentName,
        homeworkTitle: widget.homework.title,
        dueAt: widget.homework.dueAt,
        centerName: 'سنتر الأوائل التعليمي',
        subjectName: widget.group.name,
        groupName: widget.group.name,
      );
    }
  }

  Future<void> _sendWhatsAppResult(Map<String, dynamic> r) async {
    final phone = r['phone_number']?.toString() ?? '';
    final studentName = r['student_name']?.toString() ?? '';
    final score = (r['score'] as num?) ?? 0;

    final phoneController = TextEditingController(text: phone);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إرسال نتيجة الواجب لولي الأمر عبر واتساب 📲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطالب: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('الدرجة المحققة: $score من ${widget.homework.maxScore}'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف ولي الأمر (واتساب)',
                prefixIcon: Icon(Icons.phone_rounded),
                hintText: '01XXXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );

    if (confirmed == true && phoneController.text.trim().isNotEmpty) {
      await WhatsAppService.sendHomeworkResultToParent(
        parentPhone: phoneController.text.trim(),
        studentName: studentName,
        homeworkTitle: widget.homework.title,
        score: score,
        maxScore: widget.homework.maxScore,
        centerName: 'سنتر الأوائل التعليمي',
        teacherFeedback: r['feedback']?.toString(),
        subjectName: widget.group.name,
        groupName: widget.group.name,
      );
    }
  }

  void _openGrading(Map<String, dynamic> r) async {
    final sub = r['submission_raw'];
    if (sub == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSubmissionsScreen(
          initialSubmission: {
            'id': sub['id'],
            'assessment_type': 'homework',
            'assessment_id': widget.homework.id,
            'assessment_title': widget.homework.title,
            'student_id': r['student_id'],
            'student_full_name': r['name'] ?? r['student_name'] ?? 'طالب',
            'score': sub['score'] ?? 0,
            'max_score': widget.homework.maxScore,
            'attachment_url': sub['attachment_url'],
            'submission_text': sub['submission_text'],
            'teacher_feedback': sub['teacher_feedback'] ?? '',
          },
          onGraded: () {
            widget.onDataChanged();
          },
        ),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final totalStudents = _records.length;
    final submittedCount = _records.where((r) => r['is_submitted'] == true).length;
    final missingCount = totalStudents - submittedCount;
    final submissionRate = totalStudents > 0 ? (submittedCount / totalStudents) * 100 : 0.0;

    double totalGrades = 0;
    int gradedCount = 0;
    for (final r in _records) {
      if (r['score'] != null) {
        totalGrades += (r['score'] as num).toDouble();
        gradedCount++;
      }
    }
    final avgScore = gradedCount > 0 ? totalGrades / gradedCount : 0.0;

    final filteredRecords = _records.where((r) {
      if (_filter == 'submitted' && r['is_submitted'] != true) return false;
      if (_filter == 'missing' && r['is_submitted'] == true) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final name = (r['student_name']?.toString() ?? '').toLowerCase();
        final code = (r['student_code']?.toString() ?? '').toLowerCase();
        if (!name.contains(query) && !code.contains(query)) return false;
      }
      return true;
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Dialog Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كشف تسليمات وتصحيح الواجب 📋',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${widget.homework.title} • ${widget.group.name}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
            const SizedBox(height: 14),

            // Metrics Row
            Row(
              children: [
                _buildMetricCard('إجمالي الطلاب', '$totalStudents', Colors.blueGrey),
                const SizedBox(width: 8),
                _buildMetricCard('تم التسليم', '$submittedCount (${submissionRate.toStringAsFixed(0)}%)', Colors.green),
                const SizedBox(width: 8),
                _buildMetricCard('لم يسلّم', '$missingCount', missingCount > 0 ? Colors.red : Colors.grey),
                const SizedBox(width: 8),
                _buildMetricCard('متوسط الدرجات', '${avgScore.toStringAsFixed(1)} / ${widget.homework.maxScore.toStringAsFixed(0)}', Colors.purple),
              ],
            ),
            const SizedBox(height: 12),

            // PDF Actions Bar
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _exportRosterPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.indigo),
                  label: const Text('كشف التسليمات الرسمي (PDF)', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportPrintableSheetPdf,
                  icon: const Icon(Icons.print_rounded, size: 16, color: Colors.deepPurple),
                  label: const Text('شيت واجب للطباعة (PDF)', style: TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'تحديث البيانات',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadData,
                ),
              ],
            ),
            const Divider(height: 18),

            // Search and Filters
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
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'all', label: Text('الكل ($totalStudents)', style: const TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'submitted', label: Text('سلّم ($submittedCount)', style: const TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'missing', label: Text('لم يسلّم ($missingCount)', style: const TextStyle(fontSize: 11))),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (set) => setState(() => _filter = set.first),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Students List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('خطأ: $_error', style: const TextStyle(color: Colors.red)))
                  : filteredRecords.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد طلاب مطابقين للبحث',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final r = filteredRecords[idx];
                        final isSubmitted = r['is_submitted'] == true;
                        final isLate = r['is_late'] == true;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSubmitted
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.red.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isSubmitted
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.red.withValues(alpha: 0.1),
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSubmitted ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          r['student_name']?.toString() ?? 'طالب',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSubmitted
                                                ? (isLate ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.12))
                                                : Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            !isSubmitted
                                                ? 'لم يسلّم بعد ❌'
                                                : (isLate ? 'مسلّم متأخر ⚠️' : 'مسلّم في الموعد ✔️'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: !isSubmitted
                                                  ? Colors.red.shade700
                                                  : (isLate ? Colors.orange.shade800 : Colors.green.shade700),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'كود: ${r['student_code'] ?? '-'} ${r['submitted_at'] != null ? '• تاريخ التسليم: ${r['submitted_at']}' : ''}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    if (r['feedback'] != null && r['feedback'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          'ملاحظة: ${r['feedback']}',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Score and Action buttons
                              if (isSubmitted) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r['score'] != null ? '${r['score']} / ${widget.homework.maxScore.toStringAsFixed(0)}' : 'قيد التصحيح',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'مراجعة وتصحيح الإجابات 📝',
                                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                                  onPressed: () => _openGrading(r),
                                ),
                                IconButton(
                                  tooltip: 'إرسال النتيجة لولي الأمر واتساب 📲',
                                  icon: const Icon(Icons.chat_rounded, color: Colors.green),
                                  onPressed: () => _sendWhatsAppResult(r),
                                ),
                              ] else ...[
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade800,
                                    side: BorderSide(color: Colors.green.shade400),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  ),
                                  icon: const Icon(Icons.chat_rounded, size: 14),
                                  label: const Text('تذكير واتساب', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _sendWhatsAppReminder(r),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
}

