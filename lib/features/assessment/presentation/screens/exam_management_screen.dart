import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';
import 'exam_submissions_screen.dart';
import '../../../../core/services/report_generator_service.dart';

class ExamManagementScreen extends StatefulWidget {
  const ExamManagementScreen({super.key});

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  late final SupabaseExamRepository _examRepo;
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseQuestionBankRepository _questionRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _examRepo = SupabaseExamRepository(wrapper);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _questionRepo = SupabaseQuestionBankRepository(wrapper);
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final list = selected == null
          ? <Exam>[]
          : await _examRepo.fetchExamsForGroup(selected.id);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
          _exams = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCreateExamDialog() {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مجموعة دراسية نشطة أولاً.')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '45');
    final passCtrl = TextEditingController(text: '50');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.quiz, color: AppColors.adminRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'إضافة وتعيين اختبار جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.group, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'المجموعة: ${selectedGroup.name} (${selectedGroup.code})',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الاختبار *',
                        hintText: 'مثال: اختبار شهر نوفمبر - الباب الأول',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان الاختبار' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationCtrl,
                            decoration: const InputDecoration(
                              labelText: 'المدة بالدقائق *',
                              hintText: '45',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'أدخل المدة';
                              final val = int.tryParse(v.trim());
                              if (val == null || val <= 0) return 'أدخل رقم صحيح';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: passCtrl,
                            decoration: const InputDecoration(
                              labelText: 'نسبة النجاح (%) *',
                              hintText: '50',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'أدخل النسبة';
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0 || val > 100) return 'بين 0 و 100';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminRole,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => isSubmitting = true);

                      final duration = int.parse(durationCtrl.text.trim());
                      final passScore = double.parse(passCtrl.text.trim());
                      final nav = Navigator.of(ctx);

                      try {
                        await Supabase.instance.client.rpc(
                          'create_exam_assignment',
                          params: {
                            'p_title': titleCtrl.text.trim(),
                            'p_subject_id': selectedGroup.subjectId,
                            'p_group_id': selectedGroup.id,
                            'p_duration_minutes': duration,
                            'p_pass_score': passScore,
                            'p_status': 'published',
                          },
                        );
                        nav.pop();
                        _loadExams();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إنشاء ونشر الاختبار بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل إنشاء الاختبار: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(isSubmitting ? 'جاري النشر...' : 'نشر الاختبار'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExamDialog(Exam e) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: e.title);
    final durationCtrl = TextEditingController(text: e.durationMinutes.toString());
    final passCtrl = TextEditingController(text: e.passScore.toString());
    String status = e.status;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: AppColors.adminRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات الاختبار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الاختبار *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان الاختبار' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationCtrl,
                            decoration: const InputDecoration(
                              labelText: 'المدة بالدقائق *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'أدخل المدة';
                              final val = int.tryParse(v.trim());
                              if (val == null || val <= 0) return 'أدخل رقم صحيح';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: passCtrl,
                            decoration: const InputDecoration(
                              labelText: 'درجة النجاح (%) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'أدخل النسبة';
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0 || val > 100) return 'بين 0 و 100';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'حالة الاختبار',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'published', child: Text('منشور ومتاح')),
                        DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                        DropdownMenuItem(value: 'closed', child: Text('مغلق')),
                      ],
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => status = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminRole,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => isSubmitting = true);

                      final duration = int.parse(durationCtrl.text.trim());
                      final passScore = double.parse(passCtrl.text.trim());
                      final nav = Navigator.of(ctx);

                      try {
                        await Supabase.instance.client
                            .from('exams')
                            .update({
                              'title': titleCtrl.text.trim(),
                              'duration_minutes': duration,
                              'pass_score': passScore,
                              'status': status,
                              'updated_at': DateTime.now().toIso8601String(),
                            })
                            .eq('id', e.id);
                        nav.pop();
                        _loadExams();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تحديث الاختبار بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (err) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل تحديث الاختبار: $err'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageQuestionsDialog(Exam exam) async {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) return;

    List<Question> bankQuestions = [];
    bool isBankLoading = true;

    try {
      bankQuestions = await _questionRepo.fetchQuestionsForSubject(selectedGroup.subjectId);
    } catch (_) {}
    isBankLoading = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final linkedIds = exam.questions.map((q) => q.id).toSet();

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.adminRole.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.format_list_numbered_rtl, color: AppColors.adminRole),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إدارة أسئلة الاختبار',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${exam.title} (${exam.questions.length} سؤال مرتبط)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 480,
              child: isBankLoading
                  ? const Center(child: CircularProgressIndicator())
                  : bankQuestions.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد أسئلة مسجلة في بنك الأسئلة لهذه المادة.\nيمكنك إضافة أسئلة من بنك الأسئلة أولاً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: bankQuestions.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 8),
                          itemBuilder: (ctx, i) {
                            final q = bankQuestions[i];
                            final isLinked = linkedIds.contains(q.id);

                            return ListTile(
                              leading: Icon(
                                isLinked ? Icons.check_box : Icons.check_box_outline_blank,
                                color: isLinked ? Colors.green : Colors.grey,
                              ),
                              title: Text(
                                q.prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isLinked ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                'النوع: ${_questionTypeLabel(q.questionType)} | الدرجة: ${q.defaultPoints}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLinked ? Colors.red.shade50 : Colors.green.shade50,
                                  foregroundColor: isLinked ? Colors.red : Colors.green.shade800,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () async {
                                  try {
                                    if (isLinked) {
                                      await _examRepo.unlinkQuestion(exam.id, q.id);
                                    } else {
                                      await _examRepo.linkQuestion(exam.id, q.id, q.defaultPoints);
                                    }
                                    _loadExams();
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isLinked ? 'تم إزالة السؤال من الاختبار' : 'تم ربط السؤال بالاختبار'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('فشل تحديث الارتباط: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: Text(isLinked ? 'إزالة' : 'ربط بالاختبار', style: const TextStyle(fontSize: 11)),
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _questionTypeLabel(QuestionType type) {
    return switch (type) {
      QuestionType.multipleChoice => 'اختيار من متعدد',
      QuestionType.trueFalse => 'صواب أو خطأ',
      QuestionType.shortAnswer => 'إجابة قصيرة',
      QuestionType.longAnswer => 'إجابة مقالية',
    };
  }

  Future<void> _exportExamData() async {
    try {
      final service = ReportGeneratorService();
      final examDataList = _exams
          .map(
            (e) => {
              'title': e.title,
              'duration': e.durationMinutes,
              'pass_score': e.passScore,
              'status': e.status,
            },
          )
          .toList();

      final groupName = _selectedGroup?.name ?? 'مجموعة';
      await service.generateExamReport(
        groupName: groupName,
        examData: examDataList,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير تقرير الاختبارات بنجاح 📄')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير التقرير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildExamCard(BuildContext context, Exam e) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.quiz, color: AppColors.adminRole, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: AppTypography.titleMedium(textPrimary).copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'المدة: ${e.durationMinutes} دقيقة',
                            style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'نسبة النجاح: ${e.passScore}%',
                            style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'الأسئلة: ${e.questions.length} سؤال',
                            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PortalStatusChip(status: e.status),
                  const SizedBox(height: 4),
                  PopupMenuButton<String>(
                    tooltip: 'خيارات',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) async {
                      switch (value) {
                        case 'submissions':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => ExamSubmissionsScreen(exam: e),
                            ),
                          );
                          break;
                        case 'questions':
                          _showManageQuestionsDialog(e);
                          break;
                        case 'edit':
                          _showEditExamDialog(e);
                          break;
                        case 'close':
                          if (e.status == 'closed') return;
                          try {
                            await Supabase.instance.client
                                .from('exams')
                                .update({
                                  'status': 'closed',
                                  'updated_at': DateTime.now().toIso8601String(),
                                })
                                .eq('id', e.id);
                            _loadExams();
                          } catch (err) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('فشل إغلاق الاختبار: $err')),
                              );
                            }
                          }
                          break;
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حذف الاختبار'),
                              content: const Text(
                                'هل أنت متأكد من رغبتك في حذف هذا الاختبار نهائياً؟',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('إلغاء'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await Supabase.instance.client.rpc(
                                'delete_exam',
                                params: {'exam_id': e.id},
                              );
                              _loadExams();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم حذف الاختبار بنجاح')),
                                );
                              }
                            } catch (err) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فشل الحذف: $err')),
                                );
                              }
                            }
                          }
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'submissions',
                        child: ListTile(
                          leading: Icon(Icons.people, size: 18),
                          title: Text('عرض الإجابات والتصحيح'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'questions',
                        child: ListTile(
                          leading: Icon(Icons.format_list_numbered_rtl, size: 18),
                          title: Text('إدارة أسئلة الاختبار'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, size: 18),
                          title: Text('تعديل الاختبار'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (e.status != 'closed')
                        const PopupMenuItem(
                          value: 'close',
                          child: ListTile(
                            leading: Icon(Icons.lock_outline, size: 18),
                            title: Text('إغلاق الاختبار'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          title: Text('حذف الاختبار', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'إدارة الاختبارات والتقييمات',
      subtitle: 'نشر وجدولة اختبارات المجموعات وتحديد زمن الإجابة والتصحيح الآلي.',
      icon: Icons.quiz,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadExams,
        ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.add,
            label: 'إضافة اختبار',
            onPressed: _showCreateExamDialog,
            primary: true,
          ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.picture_as_pdf,
            label: 'تصدير تقرير (PDF)',
            onPressed: _exportExamData,
            primary: false,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'لا توجد بيانات اختبارات',
        emptySubtitle: 'قم باختيار أو إنشاء مجموعة دراسية أولاً.',
        emptyIcon: Icons.quiz,
        onRetry: _loadExams,
        child: Column(
          children: [
            if (_groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<GroupEntity>(
                  initialValue: _selectedGroup,
                  decoration: const InputDecoration(labelText: 'اختر المجموعة الدراسية'),
                  items: _groups
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('${g.name} (${g.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (group) {
                    if (group == null) return;
                    setState(() => _selectedGroup = group);
                    _loadExams();
                  },
                ),
              ),
            Expanded(
              child: _selectedGroup == null
                  ? const Center(child: Text('لا توجد مجموعات دراسية نشطة حالياً.', style: TextStyle(color: Colors.grey)))
                  : _exams.isEmpty
                      ? const Center(child: Text('لا توجد اختبارات مسجلة لهذه المجموعة.', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _exams.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _buildExamCard(context, _exams[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
