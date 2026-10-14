import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/assessment_models.dart';

class SmartExamGeneratorDialog extends StatefulWidget {
  final String subjectName;
  final String? groupName;
  final Function(Exam generatedExam)? onExamGenerated;

  const SmartExamGeneratorDialog({
    super.key,
    required this.subjectName,
    this.groupName,
    this.onExamGenerated,
  });

  static Future<Exam?> show(
    BuildContext context, {
    required String subjectName,
    String? groupName,
  }) {
    return showDialog<Exam>(
      context: context,
      builder: (_) => SmartExamGeneratorDialog(
        subjectName: subjectName,
        groupName: groupName,
      ),
    );
  }

  @override
  State<SmartExamGeneratorDialog> createState() => _SmartExamGeneratorDialogState();
}

class _SmartExamGeneratorDialogState extends State<SmartExamGeneratorDialog> {
  final _titleController = TextEditingController(text: 'امتحان شهري شامل ومتوازن');
  int _durationMinutes = 45;
  int _easyCount = 4;
  int _mediumCount = 4;
  int _hardCount = 2;

  bool _isGenerating = false;
  List<Question>? _generatedQuestions;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int get _totalQuestions => _easyCount + _mediumCount + _hardCount;

  void _generateQuestionsFromBank() {
    setState(() => _isGenerating = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      final questions = <Question>[];

      // Easy questions
      for (int i = 1; i <= _easyCount; i++) {
        questions.add(
          Question(
            id: 'gen-easy-$i',
            subjectId: 'sub-1',
            questionType: QuestionType.multipleChoice,
            prompt: 'سؤال معرفي رقم $i في منهج ${widget.subjectName}: اختر الإجابة النموذجية الصحيحة',
            difficulty: 'easy',
            defaultPoints: 1.0,
            options: [
              QuestionOption(id: 'o-1', questionId: 'gen-easy-$i', text: 'الإجابة النموذجية الصحيحة', isCorrect: true),
              QuestionOption(id: 'o-2', questionId: 'gen-easy-$i', text: 'خيار بديل أول', isCorrect: false),
              QuestionOption(id: 'o-3', questionId: 'gen-easy-$i', text: 'خيار بديل ثانٍ', isCorrect: false),
            ],
          ),
        );
      }

      // Medium questions
      for (int i = 1; i <= _mediumCount; i++) {
        questions.add(
          Question(
            id: 'gen-med-$i',
            subjectId: 'sub-1',
            questionType: i % 2 == 0 ? QuestionType.multipleChoice : QuestionType.trueFalse,
            prompt: 'سؤال تطبيقي رقم $i في منهج ${widget.subjectName}: حدد التطبيق السليم أو الإجابة الأدق',
            difficulty: 'medium',
            defaultPoints: 2.0,
            options: [
              QuestionOption(id: 'o-1', questionId: 'gen-med-$i', text: 'صحيح / التطبيق النموذجي', isCorrect: true),
              QuestionOption(id: 'o-2', questionId: 'gen-med-$i', text: 'خطأ / بديل غير دقيق', isCorrect: false),
            ],
          ),
        );
      }

      // Hard questions
      for (int i = 1; i <= _hardCount; i++) {
        questions.add(
          Question(
            id: 'gen-hard-$i',
            subjectId: 'sub-1',
            questionType: QuestionType.shortAnswer,
            prompt: 'سؤال مقالي تحليلي رقم $i في منهج ${widget.subjectName}: اشرح ووضح استنتاجك مدعوماً بالأدلة.',
            difficulty: 'hard',
            defaultPoints: 3.0,
            options: const [],
          ),
        );
      }

      setState(() {
        _isGenerating = false;
        _generatedQuestions = questions;
      });
    });
  }

  void _confirmAndPublish() {
    if (_generatedQuestions == null || _generatedQuestions!.isEmpty) return;

    final exam = Exam(
      id: 'exam-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      subjectId: 'sub-1',
      durationMinutes: _durationMinutes,
      status: 'published',
      questions: _generatedQuestions!,
    );

    widget.onExamGenerated?.call(exam);
    Navigator.pop(context, exam);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('تم توليد واعتماد الامتحان ونشره للمجموعة بنجاح 🎯'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'توليد امتحان ذكي متوازن ⚡',
                          style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الامتحان',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _durationMinutes,
                        decoration: const InputDecoration(labelText: 'المدة الزمنية'),
                        items: const [
                          DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
                          DropdownMenuItem(value: 45, child: Text('45 دقيقة')),
                          DropdownMenuItem(value: 60, child: Text('ساعة كاملة')),
                          DropdownMenuItem(value: 90, child: Text('ساعة ونصف')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _durationMinutes = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('المادة المستهدفة', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                            Text(widget.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Matrix Distribution
                Text(
                  'مصفوفة مواصفات وصعوبة الأسئلة (إجمالي $_totalQuestions سؤال):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: textPrimary),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    _buildStepperBox('سهل (مباشر)', _easyCount, Colors.green, (v) => setState(() => _easyCount = v)),
                    const SizedBox(width: 8),
                    _buildStepperBox('متوسط (تطبيقي)', _mediumCount, Colors.blue, (v) => setState(() => _mediumCount = v)),
                    const SizedBox(width: 8),
                    _buildStepperBox('متقدم (فائقين)', _hardCount, Colors.purple, (v) => setState(() => _hardCount = v)),
                  ],
                ),
                const SizedBox(height: 16),

                // Generate Button
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isGenerating ? null : _generateQuestionsFromBank,
                  icon: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.bolt_rounded),
                  label: Text(_isGenerating ? 'جارٍ السحب الآلي من بنك الأسئلة...' : 'سحب وتوليد الأسئلة فوراً'),
                ),

                // Preview section
                if (_generatedQuestions != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    'معاينة الأسئلة التي تم توليدها (${_generatedQuestions!.length} أسئلة):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: _generatedQuestions!.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, i) {
                        final q = _generatedQuestions![i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q.prompt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'الصعوبة: ${q.difficulty} • ${q.defaultPoints} درجات',
                                    style: TextStyle(fontSize: 10, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _confirmAndPublish,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('اعتماد ونشر الامتحان للطلاب الآن'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepperBox(String label, int count, Color color, ValueChanged<int> onChanged) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: count > 0 ? () => onChanged(count - 1) : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2)),
                    child: const Icon(Icons.remove, size: 14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('$count', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                InkWell(
                  onTap: count < 20 ? () => onChanged(count + 1) : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2)),
                    child: const Icon(Icons.add, size: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
