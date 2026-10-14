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

  String _qTypeLabel(QuestionType type) {
    return switch (type) {
      QuestionType.multipleChoice => 'اختيار من متعدد',
      QuestionType.trueFalse => 'صواب أو خطأ',
      QuestionType.shortAnswer => 'إجابة قصيرة',
      QuestionType.longAnswer => 'إجابة مقالية',
    };
  }

  String _difficultyLabel(String diff) {
    return switch (diff.toLowerCase()) {
      'easy' => 'سهل',
      'hard' => 'صعب',
      _ => 'متوسط',
    };
  }

  Color _difficultyColor(String diff) {
    return switch (diff.toLowerCase()) {
      'easy' => AppColors.success,
      'hard' => AppColors.error,
      _ => AppColors.warning,
    };
  }

  void _showCreateQuestionDialog() {
    final selectedSubject = _selectedSubject;
    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مادة دراسية أولاً.')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final textCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '5');
    final explanationCtrl = TextEditingController();
    String qType = 'multiple_choice';
    String difficulty = 'medium';

    final optCtrls = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    int correctMcqIndex = 0;
    bool trueFalseCorrect = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.adminRole.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.help_outline, color: AppColors.adminRole),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إضافة سؤال لبنك الأسئلة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
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
                            const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'المادة: ${selectedSubject.name} (${selectedSubject.code})',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: textCtrl,
                        decoration: const InputDecoration(
                          labelText: 'نص وصيغة السؤال *',
                          hintText: 'اكتب نص السؤال بوضوح هنا...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال نص السؤال' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: qType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'نوع السؤال *',
                                border: OutlineInputBorder(),
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: difficulty,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'مستوى الصعوبة',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'easy', child: Text('سهل')),
                                DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                                DropdownMenuItem(value: 'hard', child: Text('صعب')),
                              ],
                              onChanged: (v) {
                                if (v != null) setStateDialog(() => difficulty = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: ptsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الدرجة الافتراضية *',
                          hintText: '5',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'يرجى إدخال الدرجة';
                          if (double.tryParse(v.trim()) == null) return 'أدخل رقم صحيح أو عشري';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // MCQ Options Builder
                      if (qType == 'multiple_choice') ...[
                        const Divider(height: 24),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            const Text(
                              'خيارات الإجابة (حدد الإجابة الصحيحة):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'الإجابة الصحيحة بالدائرة الخضراء',
                                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (int i = 0; i < 4; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Tooltip(
                                  message: correctMcqIndex == i ? 'الإجابة الصحيحة' : 'اضغط لتحديد كإجابة صحيحة',
                                  child: IconButton(
                                    icon: Icon(
                                      correctMcqIndex == i
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked,
                                      color: correctMcqIndex == i
                                          ? Colors.green
                                          : Colors.grey,
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      setStateDialog(() => correctMcqIndex = i);
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: optCtrls[i],
                                    decoration: InputDecoration(
                                      labelText: 'الاختيار (${['أ', 'ب', 'ج', 'د'][i]}) *',
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty ? 'يرجى كتابة نص الاختيار' : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      // True/False Builder
                      if (qType == 'true_false') ...[
                        const Divider(height: 24),
                        const Text(
                          'الإجابة النموذجية الصحيحة:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setStateDialog(() => trueFalseCorrect = true),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: trueFalseCorrect ? Colors.green : Colors.grey.shade400,
                                      width: trueFalseCorrect ? 2 : 1,
                                    ),
                                    color: trueFalseCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        trueFalseCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                        color: trueFalseCorrect ? Colors.green : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('صواب (True)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => setStateDialog(() => trueFalseCorrect = false),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !trueFalseCorrect ? Colors.green : Colors.grey.shade400,
                                      width: !trueFalseCorrect ? 2 : 1,
                                    ),
                                    color: !trueFalseCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        !trueFalseCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                        color: !trueFalseCorrect ? Colors.green : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('خطأ (False)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),
                      TextFormField(
                        controller: explanationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الشرح وملاحظات الإجابة النموذجية (اختياري)',
                          hintText: 'توضيح سبب الإجابة للطلبة بعد التصحيح...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
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

                        final nav = Navigator.of(ctx);
                        try {
                          final options = <QuestionOption>[];
                          if (qType == 'multiple_choice') {
                            for (int i = 0; i < 4; i++) {
                              options.add(
                                QuestionOption(
                                  id: '',
                                  questionId: '',
                                  text: optCtrls[i].text.trim(),
                                  orderNumber: i + 1,
                                  isCorrect: i == correctMcqIndex,
                                ),
                              );
                            }
                          } else if (qType == 'true_false') {
                            options.add(
                              QuestionOption(
                                id: '',
                                questionId: '',
                                text: 'صواب',
                                orderNumber: 1,
                                isCorrect: trueFalseCorrect,
                              ),
                            );
                            options.add(
                              QuestionOption(
                                id: '',
                                questionId: '',
                                text: 'خطأ',
                                orderNumber: 2,
                                isCorrect: !trueFalseCorrect,
                              ),
                            );
                          }

                          final q = Question(
                            id: '',
                            subjectId: selectedSubject.id,
                            questionType: QuestionTypeExtension.fromString(qType),
                            prompt: textCtrl.text.trim(),
                            explanation: explanationCtrl.text.trim().isEmpty
                                ? null
                                : explanationCtrl.text.trim(),
                            difficulty: difficulty,
                            defaultPoints:
                                double.tryParse(ptsCtrl.text.trim()) ?? 5.0,
                          );

                          await _questionRepo.createQuestion(q, options);
                          nav.pop();
                          _loadQuestions();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت إضافة السؤال وخياراته بنجاح!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSubmitting = false);
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
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(isSubmitting ? 'جاري الإضافة...' : 'إضافة السؤال'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditQuestionDialog(Question q) {
    final formKey = GlobalKey<FormState>();
    final textCtrl = TextEditingController(text: q.prompt);
    final ptsCtrl = TextEditingController(text: q.defaultPoints.toString());
    final explanationCtrl = TextEditingController(text: q.explanation ?? '');
    String qType = q.questionType.toDbValue();
    String difficulty = q.difficulty;

    final optCtrls = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    int correctMcqIndex = 0;
    bool trueFalseCorrect = true;

    if (q.questionType == QuestionType.multipleChoice) {
      for (int i = 0; i < 4; i++) {
        if (i < q.options.length) {
          optCtrls[i].text = q.options[i].text;
          if (q.options[i].isCorrect) {
            correctMcqIndex = i;
          }
        }
      }
    } else if (q.questionType == QuestionType.trueFalse) {
      final trueOpt = q.options.firstWhere(
        (o) => o.text.trim() == 'صواب' || o.text.trim().toLowerCase() == 'true',
        orElse: () => QuestionOption(id: '', questionId: '', text: '', isCorrect: false),
      );
      trueFalseCorrect = trueOpt.isCorrect;
    }

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
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
                    'تعديل السؤال',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: textCtrl,
                        decoration: const InputDecoration(
                          labelText: 'نص وصيغة السؤال *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال نص السؤال' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: qType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'نوع السؤال *',
                                border: OutlineInputBorder(),
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: difficulty,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'مستوى الصعوبة',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'easy', child: Text('سهل')),
                                DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                                DropdownMenuItem(value: 'hard', child: Text('صعب')),
                              ],
                              onChanged: (v) {
                                if (v != null) setStateDialog(() => difficulty = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: ptsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الدرجة الافتراضية *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'يرجى إدخال الدرجة';
                          if (double.tryParse(v.trim()) == null) return 'أدخل رقم صحيح أو عشري';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // MCQ Options Builder
                      if (qType == 'multiple_choice') ...[
                        const Divider(height: 24),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            const Text(
                              'خيارات الإجابة (حدد الإجابة الصحيحة):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'الإجابة الصحيحة بالدائرة الخضراء',
                                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (int i = 0; i < 4; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Tooltip(
                                  message: correctMcqIndex == i ? 'الإجابة الصحيحة' : 'اضغط لتحديد كإجابة صحيحة',
                                  child: IconButton(
                                    icon: Icon(
                                      correctMcqIndex == i
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked,
                                      color: correctMcqIndex == i
                                          ? Colors.green
                                          : Colors.grey,
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      setStateDialog(() => correctMcqIndex = i);
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: optCtrls[i],
                                    decoration: InputDecoration(
                                      labelText: 'الاختيار (${['أ', 'ب', 'ج', 'د'][i]}) *',
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty ? 'يرجى كتابة نص الاختيار' : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      // True/False Builder
                      if (qType == 'true_false') ...[
                        const Divider(height: 24),
                        const Text(
                          'الإجابة النموذجية الصحيحة:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setStateDialog(() => trueFalseCorrect = true),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: trueFalseCorrect ? Colors.green : Colors.grey.shade400,
                                      width: trueFalseCorrect ? 2 : 1,
                                    ),
                                    color: trueFalseCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        trueFalseCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                        color: trueFalseCorrect ? Colors.green : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('صواب (True)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => setStateDialog(() => trueFalseCorrect = false),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !trueFalseCorrect ? Colors.green : Colors.grey.shade400,
                                      width: !trueFalseCorrect ? 2 : 1,
                                    ),
                                    color: !trueFalseCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        !trueFalseCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                        color: !trueFalseCorrect ? Colors.green : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('خطأ (False)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),
                      TextFormField(
                        controller: explanationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الشرح وملاحظات الإجابة النموذجية (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
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

                        final nav = Navigator.of(ctx);
                        try {
                          final options = <QuestionOption>[];
                          if (qType == 'multiple_choice') {
                            for (int i = 0; i < 4; i++) {
                              options.add(
                                QuestionOption(
                                  id: i < q.options.length ? q.options[i].id : '',
                                  questionId: q.id,
                                  text: optCtrls[i].text.trim(),
                                  orderNumber: i + 1,
                                  isCorrect: i == correctMcqIndex,
                                ),
                              );
                            }
                          } else if (qType == 'true_false') {
                            options.add(
                              QuestionOption(
                                id: '',
                                questionId: q.id,
                                text: 'صواب',
                                orderNumber: 1,
                                isCorrect: trueFalseCorrect,
                              ),
                            );
                            options.add(
                              QuestionOption(
                                id: '',
                                questionId: q.id,
                                text: 'خطأ',
                                orderNumber: 2,
                                isCorrect: !trueFalseCorrect,
                              ),
                            );
                          }

                          final updatedQ = Question(
                            id: q.id,
                            subjectId: q.subjectId,
                            unitId: q.unitId,
                            lessonId: q.lessonId,
                            questionType: QuestionTypeExtension.fromString(qType),
                            prompt: textCtrl.text.trim(),
                            explanation: explanationCtrl.text.trim().isEmpty
                                ? null
                                : explanationCtrl.text.trim(),
                            difficulty: difficulty,
                            defaultPoints:
                                double.tryParse(ptsCtrl.text.trim()) ?? 5.0,
                          );

                          await _questionRepo.updateQuestion(updatedQ, options);
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
                          setStateDialog(() => isSubmitting = false);
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
          );
        },
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, Question q) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.help_outline, color: AppColors.adminRole, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.prompt,
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
                            color: AppColors.adminRole.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _qTypeLabel(q.questionType),
                            style: const TextStyle(fontSize: 12, color: AppColors.adminRole, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _difficultyColor(q.difficulty).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'المستوى: ${_difficultyLabel(q.difficulty)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _difficultyColor(q.difficulty),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'الدرجات: ${q.defaultPoints}',
                            style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('تأكيد الحذف'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await _questionRepo.deleteQuestion(q.id);
                        _loadQuestions();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حذف السؤال بنجاح')),
                          );
                        }
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل حذف السؤال: $err'),
                              backgroundColor: Colors.red,
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
                      leading: Icon(Icons.edit, size: 18),
                      title: Text('تعديل السؤال'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      title: Text('حذف السؤال', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Render options if present
          if (q.options.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < q.options.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            q.options[i].isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            size: 16,
                            color: q.options[i].isCorrect ? Colors.green : textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              q.options[i].text,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: q.options[i].isCorrect ? FontWeight.bold : FontWeight.normal,
                                color: q.options[i].isCorrect ? Colors.green.shade700 : textPrimary,
                              ),
                            ),
                          ),
                          if (q.options[i].isCorrect)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'الإجابة الصحيحة',
                                style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (i < q.options.length - 1)
                      Divider(height: 8, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ],
                ],
              ),
            ),
          ],

          // Render explanation if present
          if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'الشرح: ${q.explanation}',
                      style: AppTypography.caption(textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
                  isExpanded: true,
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
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _questions.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _buildQuestionCard(context, _questions[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
