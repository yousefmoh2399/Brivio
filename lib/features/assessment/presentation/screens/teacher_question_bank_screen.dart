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
        return 'صح وخطأ';
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
          content: Text('لم يتم العثور على مجموعات دراسية مسندة.'),
        ),
      );
      return;
    }

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
    }

    // Short/Long answer specific
    final explanationCtrl = TextEditingController(
      text: existingQuestion?.explanation,
    );

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
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
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        existingQuestion == null
                            ? 'إضافة سؤال جديد'
                            : 'تعديل السؤال',
                        style: AppTypography.displaySmall(textColor),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<QuestionType>(
                        initialValue: selectedType,
                        dropdownColor: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        decoration: const InputDecoration(
                          labelText: 'نوع السؤال',
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
                        onChanged: (v) {
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: promptCtrl,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: 'نص السؤال أو رأس المسألة',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),

                      if (selectedType == QuestionType.multipleChoice) ...[
                        TextField(
                          controller: opt1Ctrl,
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            labelText: 'الخيار الأول (أ)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: opt2Ctrl,
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            labelText: 'الخيار الثاني (ب)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: opt3Ctrl,
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            labelText: 'الخيار الثالث (ج)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: opt4Ctrl,
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            labelText: 'الخيار الرابع (د)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: correctIdx,
                          dropdownColor: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          decoration: const InputDecoration(
                            labelText: 'الإجابة الصحيحة',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text(
                                'الخيار الأول (أ) هو الصحيح',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text(
                                'الخيار الثاني (ب) هو الصحيح',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text(
                                'الخيار الثالث (ج) هو الصحيح',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text(
                                'الخيار الرابع (د) هو الصحيح',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setStateDialog(() => correctIdx = v);
                          },
                        ),
                      ] else if (selectedType == QuestionType.trueFalse) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: correctIdx,
                          dropdownColor: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          decoration: const InputDecoration(
                            labelText: 'الإجابة الصحيحة',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text(
                                'صواب (صح) هي الإجابة الصحيحة',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text(
                                'خطأ هي الإجابة الصحيحة',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setStateDialog(() => correctIdx = v);
                          },
                        ),
                      ] else ...[
                        TextField(
                          controller: explanationCtrl,
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            labelText: 'الإجابة النموذجية / الشرح والتوضيح',
                          ),
                          maxLines: 3,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: ptsCtrl,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: 'درجة السؤال (الافتراضية)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'إلغاء',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (promptCtrl.text.trim().isEmpty) return;
                              final nav = Navigator.of(ctx);
                              try {
                                List<QuestionOption> opts = [];

                                if (selectedType ==
                                    QuestionType.multipleChoice) {
                                  opts = [
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: opt1Ctrl.text.trim(),
                                      isCorrect: correctIdx == 0,
                                      orderNumber: 1,
                                    ),
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: opt2Ctrl.text.trim(),
                                      isCorrect: correctIdx == 1,
                                      orderNumber: 2,
                                    ),
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: opt3Ctrl.text.trim(),
                                      isCorrect: correctIdx == 2,
                                      orderNumber: 3,
                                    ),
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: opt4Ctrl.text.trim(),
                                      isCorrect: correctIdx == 3,
                                      orderNumber: 4,
                                    ),
                                  ];
                                } else if (selectedType ==
                                    QuestionType.trueFalse) {
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
                                  explanation:
                                      explanationCtrl.text.trim().isNotEmpty
                                      ? explanationCtrl.text.trim()
                                      : null,
                                  defaultPoints:
                                      double.tryParse(ptsCtrl.text) ?? 5.0,
                                  options: opts,
                                );

                                if (existingQuestion != null) {
                                  // Check if used in exams
                                  final res = await Supabase.instance.client
                                      .from('exam_questions')
                                      .select('exams(title)')
                                      .eq('question_id', existingQuestion.id);

                                  if (res.isNotEmpty) {
                                    // Ask to update all or save as new
                                    if (!mounted) return;
                                    final doUpdate = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('تنبيه'),
                                        content: const Text(
                                          'هذا السؤال مستخدم في امتحانات نشطة. هل تريد تحديثه في كافة الامتحانات، أم حفظه كسؤال جديد منفصل؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('حفظ كسؤال جديد'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('تحديث في الكل'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (doUpdate == true) {
                                      await _questionRepo.updateQuestion(
                                        q,
                                        opts,
                                      );
                                    } else {
                                      await _questionRepo.createQuestion(
                                        q,
                                        opts,
                                      );
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
                                      content: Text('تم حفظ السؤال بنجاح!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('فشل الحفظ: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              existingQuestion == null
                                  ? 'حفظ السؤال'
                                  : 'تحديث السؤال',
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
        },
      ),
    );
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السؤال'),
        content: const Text('هل أنت متأكد من حذف هذا السؤال من بنك الأسئلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _questionRepo.deleteQuestion(question.id);
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحذف: $e')),
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
                            'حدث خطأ: $_errorMessage',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadQuestions,
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
                                labelText: 'المجموعة الدراسية',
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
                    else if (_questions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'لا توجد أسئلة مضافة في بنك الأسئلة لهذه المجموعة.',
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final q = _questions[i];
                            return FadeInSlide(
                              duration: Duration(milliseconds: 300 + (i * 50)),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        child: const Icon(
                                          Icons.help_outline,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              q.prompt,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  AppTypography.titleMedium(
                                                    textColor,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'النوع: ${_questionTypeName(q.questionType)} | الدرجة: ${q.defaultPoints} درجات',
                                              style: AppTypography.caption(
                                                subtitleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        tooltip: 'خيارات',
                                        icon: const Icon(
                                          Icons.more_vert_rounded,
                                        ),
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
                                              ),
                                              title: Text('تعديل'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.delete_outline,
                                                color: AppColors.error,
                                              ),
                                              title: Text('حذف'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }, childCount: _questions.length),
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
              label: const Text('طباعة كويز ورقي (PDF)'),
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
              icon: const Icon(Icons.add),
              label: const Text('إضافة سؤال جديد'),
            ),
          ),
      ],
    );
  }
}
