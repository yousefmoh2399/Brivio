import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../core/services/report_generator_service.dart';

class TeacherQuestionBankScreen extends StatefulWidget {
  final String teacherId;

  const TeacherQuestionBankScreen({super.key, required this.teacherId});

  @override
  State<TeacherQuestionBankScreen> createState() =>
      _TeacherQuestionBankScreenState();
}

class _TeacherQuestionBankScreenState extends State<TeacherQuestionBankScreen> {
  late final SupabaseQuestionBankRepository _questionRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Question> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _questionRepo = SupabaseQuestionBankRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _teacherRepo = SupabaseTeacherRepository(
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
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final q = selected == null
          ? <Question>[]
          : await _questionRepo.fetchQuestionsForSubject(selected.subjectId);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
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

  String _questionTypeName(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'اختيار من متعدد';
      case QuestionType.trueFalse:
        return 'صح أو خطأ';
      case QuestionType.shortAnswer:
        return 'إجابة قصيرة';
      case QuestionType.longAnswer:
        return 'إجابة مقالية';
    }
  }

  void _showQuestionEditorDialog([Question? existingQuestion]) async {
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مجموعة دراسية أولاً.'),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    QuestionType selectedType =
        existingQuestion?.questionType ?? QuestionType.multipleChoice;
    final promptCtrl = TextEditingController(text: existingQuestion?.prompt);
    final ptsCtrl = TextEditingController(
      text: existingQuestion?.defaultPoints.toString() ?? '5',
    );

    // MCQ/TF specific
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();
    final opt3Ctrl = TextEditingController();
    final opt4Ctrl = TextEditingController();
    int correctIdx = 0;

    if (existingQuestion != null && existingQuestion.options.isNotEmpty) {
      if (selectedType == QuestionType.multipleChoice) {
        if (existingQuestion.options.isNotEmpty) {
          opt1Ctrl.text = existingQuestion.options[0].text;
        }
        if (existingQuestion.options.length > 1) {
          opt2Ctrl.text = existingQuestion.options[1].text;
        }
        if (existingQuestion.options.length > 2) {
          opt3Ctrl.text = existingQuestion.options[2].text;
        }
        if (existingQuestion.options.length > 3) {
          opt4Ctrl.text = existingQuestion.options[3].text;
        }
        correctIdx = existingQuestion.options.indexWhere((o) => o.isCorrect);
        if (correctIdx == -1) correctIdx = 0;
      } else if (selectedType == QuestionType.trueFalse) {
        correctIdx = existingQuestion.options.indexWhere((o) => o.isCorrect);
        if (correctIdx == -1) correctIdx = 0;
      }
    } else if (selectedType == QuestionType.trueFalse) {
      opt1Ctrl.text = 'صواب';
      opt2Ctrl.text = 'خطأ';
    }

    // Short/Long answer specific
    final explanationCtrl = TextEditingController(
      text: existingQuestion?.explanation,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surfaceColor = isDark
              ? AppColors.darkCard
              : AppColors.lightCard;
          final borderColor = isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder;
          final textColor = isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary;

          return Dialog(
            backgroundColor: surfaceColor,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 750),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
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
                                    existingQuestion == null
                                        ? 'إضافة سؤال جديد لبنك الأسئلة ❓'
                                        : 'تعديل السؤال ✏️',
                                    style: AppTypography.titleLarge(textColor).copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'مادة: ${_selectedGroup?.name ?? ""}',
                                    style: AppTypography.caption(AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving ? null : () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        DropdownButtonFormField<QuestionType>(
                          initialValue: selectedType,
                          dropdownColor: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          decoration: const InputDecoration(
                            labelText: 'نوع السؤال *',
                            prefixIcon: Icon(Icons.category_rounded),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: QuestionType.multipleChoice,
                              child: Text(
                                'اختيار من متعدد (MCQ)',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: QuestionType.trueFalse,
                              child: Text(
                                'صح أو خطأ',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: QuestionType.shortAnswer,
                              child: Text(
                                'إجابة قصيرة',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: QuestionType.longAnswer,
                              child: Text(
                                'إجابة مقالية (مطولة)',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setStateDialog(() {
                                      selectedType = v;
                                      if (v == QuestionType.trueFalse) {
                                        opt1Ctrl.text = 'صواب';
                                        opt2Ctrl.text = 'خطأ';
                                        correctIdx = 0;
                                      } else {
                                        opt1Ctrl.clear();
                                        opt2Ctrl.clear();
                                      }
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: promptCtrl,
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            labelText: 'نص السؤال أو رأس المسألة *',
                            hintText: 'اكتب نص السؤال بدقة ووضوح...',
                            prefixIcon: Icon(Icons.help_outline_rounded),
                          ),
                          maxLines: 3,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى كتابة نص السؤال';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        if (selectedType == QuestionType.multipleChoice) ...[
                          Text(
                            'خيارات الإجابة *',
                            style: AppTypography.titleSmall(textColor).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: opt1Ctrl,
                            style: TextStyle(color: textColor),
                            decoration: const InputDecoration(
                              labelText: 'الخيار الأول (أ) *',
                              prefixIcon: Icon(Icons.looks_one_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'الخيار الأول مطلوب';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: opt2Ctrl,
                            style: TextStyle(color: textColor),
                            decoration: const InputDecoration(
                              labelText: 'الخيار الثاني (ب) *',
                              prefixIcon: Icon(Icons.looks_two_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'الخيار الثاني مطلوب';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: opt3Ctrl,
                            style: TextStyle(color: textColor),
                            decoration: const InputDecoration(
                              labelText: 'الخيار الثالث (ج)',
                              prefixIcon: Icon(Icons.looks_3_rounded),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: opt4Ctrl,
                            style: TextStyle(color: textColor),
                            decoration: const InputDecoration(
                              labelText: 'الخيار الرابع (د)',
                              prefixIcon: Icon(Icons.looks_4_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            initialValue: correctIdx,
                            dropdownColor: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            decoration: const InputDecoration(
                              labelText: 'الإجابة الصحيحة المعتمدة *',
                              prefixIcon: Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(
                                  'الخيار الأول (أ) هو الصحيح ✔️',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Text(
                                  'الخيار الثاني (ب) هو الصحيح ✔️',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(
                                  'الخيار الثالث (ج) هو الصحيح ✔️',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(
                                  'الخيار الرابع (د) هو الصحيح ✔️',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
                            onChanged: isSaving
                                ? null
                                : (v) {
                                    if (v != null) setStateDialog(() => correctIdx = v);
                                  },
                          ),
                        ] else if (selectedType == QuestionType.trueFalse) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: correctIdx,
                            dropdownColor: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            decoration: const InputDecoration(
                              labelText: 'الإجابة الصحيحة المعتمدة *',
                              prefixIcon: Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(
                                  'صواب (صح) هي الإجابة الصحيحة ✔️',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Text(
                                  'خطأ هي الإجابة الصحيحة ✔️',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
                            onChanged: isSaving
                                ? null
                                : (v) {
                                    if (v != null) setStateDialog(() => correctIdx = v);
                                  },
                          ),
                        ] else ...[
                          TextFormField(
                            controller: explanationCtrl,
                            style: TextStyle(color: textColor),
                            decoration: const InputDecoration(
                              labelText: 'الإجابة النموذجية / الشرح والتوضيح',
                              hintText: 'اكتب نموذج الإجابة ليظهر للطالب بعد التسليم أو أثناء التصحيح...',
                              prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                            ),
                            maxLines: 3,
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: ptsCtrl,
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            labelText: 'الدرجة الافتراضية للسؤال *',
                            hintText: 'مثال: 5',
                            prefixIcon: Icon(Icons.grade_rounded),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى إدخال درجة السؤال';
                            }
                            final val = double.tryParse(v);
                            if (val == null || val <= 0) {
                              return 'أدخل درجة صحيحة أكبر من صفر';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSaving ? null : () => Navigator.pop(ctx),
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
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      setStateDialog(() => isSaving = true);
                                      final nav = Navigator.of(ctx);
                                      try {
                                        List<QuestionOption> opts = [];

                                        if (selectedType == QuestionType.multipleChoice) {
                                          opts.add(
                                            QuestionOption(
                                              id: '',
                                              questionId: '',
                                              text: opt1Ctrl.text.trim(),
                                              isCorrect: correctIdx == 0,
                                              orderNumber: 1,
                                            ),
                                          );
                                          opts.add(
                                            QuestionOption(
                                              id: '',
                                              questionId: '',
                                              text: opt2Ctrl.text.trim(),
                                              isCorrect: correctIdx == 1,
                                              orderNumber: 2,
                                            ),
                                          );
                                          if (opt3Ctrl.text.trim().isNotEmpty) {
                                            opts.add(
                                              QuestionOption(
                                                id: '',
                                                questionId: '',
                                                text: opt3Ctrl.text.trim(),
                                                isCorrect: correctIdx == 2,
                                                orderNumber: 3,
                                              ),
                                            );
                                          }
                                          if (opt4Ctrl.text.trim().isNotEmpty) {
                                            opts.add(
                                              QuestionOption(
                                                id: '',
                                                questionId: '',
                                                text: opt4Ctrl.text.trim(),
                                                isCorrect: correctIdx == 3,
                                                orderNumber: 4,
                                              ),
                                            );
                                          }
                                        } else if (selectedType == QuestionType.trueFalse) {
                                          opts = [
                                            QuestionOption(
                                              id: '',
                                              questionId: '',
                                              text: 'صواب',
                                              isCorrect: correctIdx == 0,
                                              orderNumber: 1,
                                            ),
                                            QuestionOption(
                                              id: '',
                                              questionId: '',
                                              text: 'خطأ',
                                              isCorrect: correctIdx == 1,
                                              orderNumber: 2,
                                            ),
                                          ];
                                        }

                                        final q = Question(
                                          id: existingQuestion?.id ?? '',
                                          subjectId: _selectedGroup!.subjectId,
                                          questionType: selectedType,
                                          prompt: promptCtrl.text.trim(),
                                          explanation: explanationCtrl.text.trim().isNotEmpty
                                              ? explanationCtrl.text.trim()
                                              : null,
                                          defaultPoints: double.tryParse(ptsCtrl.text) ?? 5.0,
                                          options: opts,
                                        );

                                        if (existingQuestion != null) {
                                          final res = await Supabase.instance.client
                                              .from('exam_questions')
                                              .select('exams(title)')
                                              .eq('question_id', existingQuestion.id);

                                          if (res.isNotEmpty) {
                                            if (!mounted) return;
                                            final doUpdate = await showDialog<bool>(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: const Text('تنبيه هام ⚠️'),
                                                content: const Text(
                                                  'هذا السؤال مستخدم في امتحانات نشطة حالياً. هل تريد تحديثه في كافة الامتحانات المرتبطة، أم حفظه كسؤال جديد منفصل؟',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(c, false),
                                                    child: const Text('حفظ كسؤال جديد'),
                                                  ),
                                                  FilledButton(
                                                    style: FilledButton.styleFrom(
                                                      backgroundColor: AppColors.error,
                                                    ),
                                                    onPressed: () => Navigator.pop(c, true),
                                                    child: const Text('تحديث في الكل'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (doUpdate == true) {
                                              await _questionRepo.updateQuestion(q, opts);
                                            } else {
                                              await _questionRepo.createQuestion(q, opts);
                                            }
                                          } else {
                                            await _questionRepo.updateQuestion(q, opts);
                                          }
                                        } else {
                                          await _questionRepo.createQuestion(q, opts);
                                        }

                                        nav.pop();
                                        _loadQuestions();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('تم حفظ السؤال بنجاح في بنك الأسئلة ✔️'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          setStateDialog(() => isSaving = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('فشل حفظ السؤال: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_rounded),
                              label: Text(
                                isSaving
                                    ? 'جاري الحفظ...'
                                    : (existingQuestion == null ? 'حفظ السؤال 💾' : 'تحديث السؤال ✔️'),
                              ),
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
      ),
    );
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السؤال من بنك الأسئلة 🗑️'),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذا السؤال؟\n'
          'نص السؤال: "${question.prompt}"',
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
      await _questionRepo.deleteQuestion(question.id);
      await _loadQuestions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف السؤال بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف السؤال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportBankQuestionsAsPrintablePdf() async {
    if (_questions.isEmpty || _selectedGroup == null) return;

    try {
      final questionsData = _questions.map((q) {
        return {
          'prompt': q.prompt,
          'points': q.defaultPoints,
          'type': q.questionType.toDbValue(),
          'options': q.options.map((opt) => {'text': opt.text, 'is_correct': opt.isCorrect}).toList(),
        };
      }).toList();

      await ReportGeneratorService().generatePrintableExamSheet(
        centerName: 'سنتر الأوائل التعليمي',
        examTitle: 'كويز تدريبي - ${_selectedGroup!.name}',
        subjectName: _selectedGroup!.name,
        teacherName: 'الأستاذ المشرف',
        durationMinutes: 30,
        passScore: 10,
        questions: questionsData,
        groupName: _selectedGroup!.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصدير بنك الأسئلة كشيت كويز ورقي للطباعة 📄'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تصدير الكويز: $e'), backgroundColor: Colors.red),
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

    final filteredQuestions = _questions.where((q) {
      if (_searchQuery.trim().isEmpty) return true;
      final qStr = _searchQuery.trim().toLowerCase();
      final inPrompt = q.prompt.toLowerCase().contains(qStr);
      final inOptions = q.options.any((o) => o.text.toLowerCase().contains(qStr));
      return inPrompt || inOptions;
    }).toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadQuestions,
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
                            onPressed: _loadQuestions,
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
                    if (_groups.isNotEmpty)
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
                                        '${g.name} (${g.code})',
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (group) {
                                if (group == null) return;
                                setState(() => _selectedGroup = group);
                                _loadQuestions();
                              },
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (_questions.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'ابحث في أسئلة المادة أو خياراتها...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                    else if (_questions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.quiz_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد أسئلة مضافة في بنك الأسئلة لهذه المادة بعد.',
                                  style: AppTypography.titleMedium(textColor).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'اضغط على زر "إضافة سؤال جديد" بالأسفل لبناء بنك أسئلتك.',
                                  style: AppTypography.bodySmall(subtitleColor),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (filteredQuestions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'لا توجد أسئلة تطابق بحثك "$_searchQuery"',
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final q = filteredQuestions[i];
                            return FadeInSlide(
                              duration: Duration(milliseconds: 250 + (i * 35)),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.primary
                                                .withValues(alpha: 0.15),
                                            child: Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  q.prompt,
                                                  style: AppTypography.titleMedium(
                                                    textColor,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.bold,
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
                                          PopupMenuButton<String>(
                                            tooltip: 'خيارات السؤال',
                                            icon: const Icon(Icons.more_vert_rounded),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showQuestionEditorDialog(q);
                                              } else if (value == 'delete') {
                                                _deleteQuestion(q);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.edit_rounded,
                                                    color: AppColors.primary,
                                                  ),
                                                  title: Text('تعديل السؤال'),
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
                                                  title: Text('حذف السؤال'),
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (q.options.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: q.options.map((opt) {
                                            final isCorrect = opt.isCorrect;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isCorrect
                                                    ? Colors.green.withValues(alpha: 0.12)
                                                    : (isDark
                                                        ? Colors.white10
                                                        : Colors.black.withValues(alpha: 0.03)),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isCorrect
                                                      ? Colors.green
                                                      : Colors.grey.withValues(alpha: 0.25),
                                                  width: isCorrect ? 1.5 : 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isCorrect) ...[
                                                    const Icon(
                                                      Icons.check_circle_rounded,
                                                      size: 14,
                                                      color: Colors.green,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Text(
                                                    opt.text,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: isCorrect
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: isCorrect
                                                          ? Colors.green.shade800
                                                          : textColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                      if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '💡 نموذج الإجابة: ${q.explanation}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.blueGrey,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }, childCount: filteredQuestions.length),
                        ),
                      ),
                  ],
                ),
        ),
        if (_selectedGroup != null && _questions.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'print_bank_quiz_fab',
              onPressed: _exportBankQuestionsAsPrintablePdf,
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.print_rounded),
              label: const Text('طباعة كويز ورقي (PDF) 📄'),
            ),
          ),
        if (_selectedGroup != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'add_bank_question_fab',
              onPressed: () => _showQuestionEditorDialog(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة سؤال جديد ❓'),
            ),
          ),
      ],
    );
  }
}
