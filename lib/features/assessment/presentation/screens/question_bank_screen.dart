import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  late final SupabaseQuestionBankRepository _questionRepo;
  late final SupabaseSubjectRepository _subjectRepo;
  List<SubjectEntity> _subjects = [];
  SubjectEntity? _selectedSubject;
  List<Question> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionRepo = SupabaseQuestionBankRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _subjectRepo = SupabaseSubjectRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subjects = await _subjectRepo.fetchSubjects(status: 'active');
      final selected =
          _selectedSubject ?? (subjects.isEmpty ? null : subjects.first);
      final q = selected == null
          ? <Question>[]
          : await _questionRepo.fetchQuestionsForSubject(selected.id);
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _selectedSubject = selected;
          _questions = q;
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

  void _showCreateQuestionDialog() {
    final selectedSubject = _selectedSubject;
    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مادة دراسية أولاً.')),
      );
      return;
    }
    final textCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '5');
    String qType = 'multiple_choice';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('إضافة سؤال لبنك الأسئلة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نص وصيغة السؤال',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: qType,
                    decoration: const InputDecoration(
                      labelText: 'نوع السؤال',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'multiple_choice',
                        child: Text('اختيار من متعدد (MCQ)'),
                      ),
                      DropdownMenuItem(
                        value: 'true_false',
                        child: Text('صواب أو خطأ'),
                      ),
                      DropdownMenuItem(
                        value: 'short_answer',
                        child: Text('إجابة قصيرة'),
                      ),
                      DropdownMenuItem(
                        value: 'long_answer',
                        child: Text('إجابة مقالية'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => qType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ptsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الدرجة الافتراضية',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (textCtrl.text.trim().isEmpty) return;

                  final nav = Navigator.of(ctx);
                  try {
                    final q = Question(
                      id: '',
                      subjectId: selectedSubject.id,
                      questionType: QuestionTypeExtension.fromString(qType),
                      prompt: textCtrl.text.trim(),
                      defaultPoints: double.tryParse(ptsCtrl.text) ?? 5.0,
                    );

                    await _questionRepo.createQuestion(q, []);
                    nav.pop();
                    _loadQuestions();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تمت إضافة السؤال بنجاح!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل إضافة السؤال: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('إضافة السؤال'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditQuestionDialog(Question q) {
    final textCtrl = TextEditingController(text: q.prompt);
    final ptsCtrl = TextEditingController(text: q.defaultPoints.toString());
    String qType = q.questionType.toDbValue();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تعديل السؤال'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نص وصيغة السؤال',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: qType,
                    decoration: const InputDecoration(
                      labelText: 'نوع السؤال',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'multiple_choice',
                        child: Text('اختيار من متعدد (MCQ)'),
                      ),
                      DropdownMenuItem(
                        value: 'true_false',
                        child: Text('صواب أو خطأ'),
                      ),
                      DropdownMenuItem(
                        value: 'short_answer',
                        child: Text('إجابة قصيرة'),
                      ),
                      DropdownMenuItem(
                        value: 'long_answer',
                        child: Text('إجابة مقالية'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => qType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ptsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الدرجة الافتراضية',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (textCtrl.text.trim().isEmpty) return;

                  final nav = Navigator.of(ctx);
                  try {
                    await Supabase.instance.client
                        .from('questions')
                        .update({
                          'prompt': textCtrl.text.trim(),
                          'question_type': qType,
                          'default_points':
                              double.tryParse(ptsCtrl.text) ?? 5.0,
                        })
                        .eq('id', q.id);

                    nav.pop();
                    _loadQuestions();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حفظ التعديلات بنجاح!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل تحديث السؤال: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _qTypeLabel(QuestionType type) {
    return switch (type) {
      QuestionType.multipleChoice => 'اختيار من متعدد',
      QuestionType.trueFalse => 'صواب أو خطأ',
      QuestionType.shortAnswer => 'إجابة قصيرة',
      QuestionType.longAnswer => 'إجابة مقالية',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'بنك الأسئلة',
      subtitle: 'إنشاء وإدارة بنك الأسئلة لإعداد الاختبارات والواجبات حسب المادة.',
      icon: Icons.help_outline,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadQuestions,
        ),
        if (_selectedSubject != null)
          PortalAction(
            icon: Icons.add,
            label: 'إضافة سؤال',
            onPressed: _showCreateQuestionDialog,
            primary: true,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'لا توجد أسئلة',
        emptySubtitle: 'قم باختيار أو إضافة مادة دراسية أولاً.',
        emptyIcon: Icons.help_outline,
        onRetry: _loadQuestions,
        child: Column(
          children: [
            if (_subjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<SubjectEntity>(
                  initialValue: _selectedSubject,
                  decoration: const InputDecoration(labelText: 'المادة الدراسية'),
                  items: _subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (${s.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (subject) {
                    if (subject == null) return;
                    setState(() => _selectedSubject = subject);
                    _loadQuestions();
                  },
                ),
              ),
            Expanded(
              child: _selectedSubject == null
                  ? const Center(child: Text('لا توجد مواد دراسية نشطة حالياً.'))
                  : _questions.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد أسئلة مسجلة في بنك الأسئلة لهذه المادة.',
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _questions.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final q = _questions[i];
                        return PortalListCard(
                          icon: Icons.help_outline,
                          accentColor: AppColors.adminRole,
                          title: q.prompt,
                          subtitle:
                              'النوع: ${_qTypeLabel(q.questionType)} | الدرجات الافتراضية: ${q.defaultPoints} درجات',
                          trailing: [
                            PopupMenuButton<String>(
                              tooltip: 'خيارات',
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  _showEditQuestionDialog(q);
                                  return;
                                }
                                if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('حذف السؤال'),
                                      content: const Text(
                                        'هل أنت متأكد من رغبتك في حذف هذا السؤال من بنك الأسئلة؟',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('إلغاء'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('تأكيد الحذف'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      await _questionRepo.deleteQuestion(q.id);
                                      _loadQuestions();
                                    } catch (err) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'فشل حذف السؤال: $err',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('تعديل السؤال'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('حذف السؤال'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
