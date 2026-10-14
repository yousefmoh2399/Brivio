import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/assessment_models.dart';

class QuestionBankWidget extends StatelessWidget {
  final List<Question> questions;
  final bool isLoading;

  const QuestionBankWidget({
    super.key,
    required this.questions,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('No questions found in Question Bank.')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
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
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _AssessmentMetaChip(
                            label:
                                '${context.tr('Type')}: ${context.tr(q.questionType.name)}',
                          ),
                          _AssessmentMetaChip(
                            label:
                                '${context.tr('Points')}: ${q.defaultPoints}',
                          ),
                          _AssessmentMetaChip(
                            label:
                                '${context.tr('Difficulty')}: ${context.tr(q.difficulty)}',
                          ),
                          _AssessmentMetaChip(
                            label:
                                '${q.options.length} ${context.tr('options')}',
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
    );
  }
}

class _AssessmentMetaChip extends StatelessWidget {
  final String label;

  const _AssessmentMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _AssessmentCardAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _AssessmentCardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _ResponsiveAssessmentTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget subtitle;
  final Widget? action;

  const _ResponsiveAssessmentTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  subtitle,
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeworkListWidget extends StatelessWidget {
  final List<Homework> homeworkList;
  final bool isLoading;

  const HomeworkListWidget({
    super.key,
    required this.homeworkList,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (homeworkList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('No assigned homework found.')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: homeworkList.length,
      itemBuilder: (context, index) {
        final hw = homeworkList[index];
        return _ResponsiveAssessmentTile(
          leading: const Icon(Icons.assignment, color: Colors.blue, size: 36),
          title: hw.title,
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _AssessmentMetaChip(
                label:
                    '${context.tr('Due')}: ${hw.dueAt.toLocal().toString().split(' ')[0]}',
              ),
              _AssessmentMetaChip(
                label: '${context.tr('Max Score')}: ${hw.maxScore}',
              ),
              _AssessmentMetaChip(
                label: context.l10n.t(hw.status).toUpperCase(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ExamListWidget extends StatelessWidget {
  final List<Exam> exams;
  final bool isLoading;
  final ValueChanged<Exam>? onStartExam;

  const ExamListWidget({
    super.key,
    required this.exams,
    this.isLoading = false,
    this.onStartExam,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('No available exams found.')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return _ResponsiveAssessmentTile(
          leading: const Icon(Icons.timer, color: Colors.deepPurple, size: 36),
          title: exam.title,
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _AssessmentMetaChip(
                label:
                    '${context.tr('Duration')}: ${exam.durationMinutes} ${context.tr('min')}',
              ),
              _AssessmentMetaChip(
                label: '${context.tr('Questions')}: ${exam.questions.length}',
              ),
            ],
          ),
          action: _AssessmentCardAction(
            icon: Icons.play_arrow,
            label: context.tr('Start'),
            onPressed: onStartExam != null ? () => onStartExam!(exam) : null,
          ),
        );
      },
    );
  }
}

class ExamRunnerScreen extends StatefulWidget {
  final Exam exam;
  final ExamAttempt attempt;
  final Function(String questionId, String optionId)? onOptionSelected;
  final VoidCallback? onSubmit;

  const ExamRunnerScreen({
    super.key,
    required this.exam,
    required this.attempt,
    this.onOptionSelected,
    this.onSubmit,
  });

  @override
  State<ExamRunnerScreen> createState() => _ExamRunnerScreenState();
}

class _ExamRunnerScreenState extends State<ExamRunnerScreen> {
  final Map<String, String> _answers = {};
  final Set<String> _flaggedQuestions = {};
  final Map<String, TextEditingController> _textControllers = {};
  int _currentQuestionIndex = 0;
  Timer? _timer;
  late Duration _remainingTime;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  TextEditingController _getTextController(String questionId) {
    if (!_textControllers.containsKey(questionId)) {
      final ctrl = TextEditingController(text: _answers[questionId] ?? '');
      ctrl.addListener(() {
        _answers[questionId] = ctrl.text;
        if (widget.onOptionSelected != null && ctrl.text.isNotEmpty) {
          widget.onOptionSelected!(questionId, ctrl.text);
        }
      });
      _textControllers[questionId] = ctrl;
    }
    return _textControllers[questionId]!;
  }

  void _startTimer() {
    final expiresAt = widget.attempt.expiresAt;
    final now = DateTime.now();
    _remainingTime = expiresAt.difference(now);

    if (_remainingTime.isNegative) {
      _remainingTime = Duration.zero;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSubmitOnTimeExpire();
      });
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingTime = expiresAt.difference(DateTime.now());
        if (_remainingTime.isNegative || _remainingTime == Duration.zero) {
          _remainingTime = Duration.zero;
          timer.cancel();
          _autoSubmitOnTimeExpire();
        }
      });
    });
  }

  void _autoSubmitOnTimeExpire() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.timer_off_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(context.tr('Time is up!')),
          ],
        ),
        content: Text(
          context.tr(
            'The allocated exam time has expired. Your current answers have been automatically submitted to your teacher.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onSubmit != null) widget.onSubmit!();
            },
            child: Text(context.tr('Done')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final ctrl in _textControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String get _formattedTime {
    final m = _remainingTime.inMinutes.toString().padLeft(2, '0');
    final s = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showQuestionPaletteSheet(List<Question> questions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.darkSurface : Colors.white;
        final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

        final answeredCount = questions.where((q) {
          final ans = _answers[q.id];
          return ans != null && ans.trim().isNotEmpty;
        }).length;
        final flaggedCount = _flaggedQuestions.length;
        final unansweredCount = questions.length - answeredCount;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جدول الانتقال السريع بين الأسئلة 🔢',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildLegendBadge(Colors.green, 'مجاب ($answeredCount)'),
                      _buildLegendBadge(Colors.grey.shade400, 'غير مجاب ($unansweredCount)'),
                      _buildLegendBadge(Colors.orange, 'للمراجعة ($flaggedCount)'),
                    ],
                  ),
                  const Divider(height: 24),
                  SizedBox(
                    height: 240,
                    child: GridView.builder(
                      itemCount: questions.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.1,
                      ),
                      itemBuilder: (context, idx) {
                        final q = questions[idx];
                        final isCurrent = idx == _currentQuestionIndex;
                        final isAnswered = (_answers[q.id]?.trim().isNotEmpty) ?? false;
                        final isFlagged = _flaggedQuestions.contains(q.id);

                        Color itemBg;
                        Color itemBorder;
                        Color textC;

                        if (isCurrent) {
                          itemBorder = AppColors.primary;
                          itemBg = AppColors.primary.withValues(alpha: 0.15);
                          textC = AppColors.primary;
                        } else if (isFlagged) {
                          itemBorder = Colors.orange;
                          itemBg = Colors.orange.withValues(alpha: 0.15);
                          textC = Colors.orange.shade800;
                        } else if (isAnswered) {
                          itemBorder = Colors.green;
                          itemBg = Colors.green.withValues(alpha: 0.12);
                          textC = Colors.green.shade800;
                        } else {
                          itemBorder = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
                          itemBg = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
                          textC = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
                        }

                        return InkWell(
                          onTap: () {
                            setState(() => _currentQuestionIndex = idx);
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: itemBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: itemBorder, width: isCurrent ? 2 : 1),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textC,
                                  ),
                                ),
                                if (isFlagged)
                                  const Positioned(
                                    top: 3,
                                    right: 4,
                                    child: Icon(Icons.flag_rounded, size: 10, color: Colors.orange),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(context.tr('Done')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendBadge(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _confirmAndSubmitExam(List<Question> questions) {
    final unanswered = <int>[];
    for (int i = 0; i < questions.length; i++) {
      final ans = _answers[questions[i].id];
      if (ans == null || ans.trim().isEmpty) {
        unanswered.add(i + 1);
      }
    }
    final flaggedCount = _flaggedQuestions.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              unanswered.isNotEmpty ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: unanswered.isNotEmpty ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(unanswered.isNotEmpty ? 'مراجعة قبل التسليم' : 'تأكيد تسليم الامتحان'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unanswered.isNotEmpty) ...[
              Text(
                'تنبيه: يوجد ${unanswered.length} سؤال لم تتم الإجابة عليهم بعد!',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                'الأسئلة غير المحلولة: ${unanswered.take(8).join('، ')}${unanswered.length > 8 ? ' ...' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
            ] else ...[
              const Text(
                'رائع! قمت بالإجابة على جميع الأسئلة بالكامل.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
            ],
            if (flaggedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '⚠️ لديك $flaggedCount سؤال محدد بعلامة المراجعة 🚩',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            const Text(
              'هل أنت متأكد من رغبتك في تسليم الامتحان نهائياً؟ لن تتمكن من تعديل الإجابات بعد التسليم.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة المراجعة'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: unanswered.isNotEmpty ? Colors.orange.shade800 : AppColors.success,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _finishSubmission();
            },
            child: const Text('تأكيد التسليم النهائي 🚀'),
          ),
        ],
      ),
    );
  }

  void _finishSubmission() {
    if (widget.onSubmit != null) {
      widget.onSubmit!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final questions = exam.questions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          title: Text(exam.title, style: AppTypography.titleLarge(textPrimary)),
        ),
        body: Center(
          child: Text(
            context.tr('No questions configured for this exam.'),
            style: AppTypography.bodyLarge(textSecondary),
          ),
        ),
      );
    }

    final currentQuestion = questions[_currentQuestionIndex];
    final isCurrentFlagged = _flaggedQuestions.contains(currentQuestion.id);
    final isUrgentTime = _remainingTime.inMinutes < 5;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('Exit Exam?')),
            content: Text(
              context.tr(
                'Are you sure you want to exit? You will not be able to re-enter this exam, and your current answers will be submitted to the teacher.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('Exit & Submit')),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          _finishSubmission();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          title: Text(
            exam.title,
            style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'لوحة الأسئلة',
              icon: const Icon(Icons.grid_view_rounded, color: AppColors.primary),
              onPressed: () => _showQuestionPaletteSheet(questions),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isUrgentTime ? AppColors.errorSubtle : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isUrgentTime
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isUrgentTime ? Icons.warning_rounded : Icons.timer_outlined,
                        color: isUrgentTime ? AppColors.error : AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formattedTime,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isUrgentTime ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: FadeInSlide(
            key: ValueKey(_currentQuestionIndex),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${context.tr('Question')} ${_currentQuestionIndex + 1} ${context.tr('of')} ${questions.length}',
                        style: AppTypography.bodyMedium(textSecondary).copyWith(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isCurrentFlagged) {
                                  _flaggedQuestions.remove(currentQuestion.id);
                                } else {
                                  _flaggedQuestions.add(currentQuestion.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCurrentFlagged ? Colors.orange.withValues(alpha: 0.15) : Colors.transparent,
                                border: Border.all(
                                  color: isCurrentFlagged ? Colors.orange : Colors.grey.shade400,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCurrentFlagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                                    size: 14,
                                    color: isCurrentFlagged ? Colors.orange : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isCurrentFlagged ? 'مميز للمراجعة' : 'تمييز',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrentFlagged ? Colors.orange : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: context.tr('Autosaved'),
                            status: ChipStatus.success,
                            icon: Icons.cloud_done_rounded,
                            small: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / questions.length,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${currentQuestion.defaultPoints} درجات',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'الصعوبة: ${context.tr(currentQuestion.difficulty)}',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentQuestion.prompt,
                    style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: _buildQuestionInputArea(currentQuestion, isDark, textPrimary),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: GhostButton(
                            text: context.tr('Previous'),
                            icon: Icons.arrow_back_rounded,
                            onPressed: () => setState(() => _currentQuestionIndex--),
                          ),
                        )
                      else
                        const Spacer(),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _currentQuestionIndex < questions.length - 1
                            ? PrimaryButton(
                                text: context.tr('Next'),
                                icon: Icons.arrow_forward_rounded,
                                onPressed: () => setState(() => _currentQuestionIndex++),
                              )
                            : PrimaryButton(
                                text: context.tr('Submit Exam'),
                                icon: Icons.check_circle_rounded,
                                color: AppColors.success,
                                onPressed: () => _confirmAndSubmitExam(questions),
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
  }

  Widget _buildQuestionInputArea(Question q, bool isDark, Color textPrimary) {
    if (q.questionType == QuestionType.trueFalse) {
      final selectedVal = _answers[q.id];
      return Column(
        children: [
          _buildTrueFalseOptionCard(
            label: 'صواب (True) ✔️',
            value: 'true',
            isSelected: selectedVal == 'true',
            activeColor: Colors.green,
            isDark: isDark,
            onTap: () {
              setState(() => _answers[q.id] = 'true');
              if (widget.onOptionSelected != null) {
                widget.onOptionSelected!(q.id, 'true');
              }
            },
          ),
          const SizedBox(height: 14),
          _buildTrueFalseOptionCard(
            label: 'خطأ (False) ❌',
            value: 'false',
            isSelected: selectedVal == 'false',
            activeColor: Colors.red,
            isDark: isDark,
            onTap: () {
              setState(() => _answers[q.id] = 'false');
              if (widget.onOptionSelected != null) {
                widget.onOptionSelected!(q.id, 'false');
              }
            },
          ),
        ],
      );
    }

    if (q.questionType == QuestionType.shortAnswer ||
        q.questionType == QuestionType.longAnswer ||
        q.options.isEmpty) {
      final ctrl = _getTextController(q.id);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اكتب إجابتك النموذجية بالتفصيل:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: q.questionType == QuestionType.longAnswer ? 8 : 4,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ابدأ بكتابة إجابتك هنا...',
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final letters = ['أ', 'ب', 'ج', 'د', 'هـ'];
    return ListView.separated(
      itemCount: q.options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final opt = q.options[i];
        final isSelected = _answers[q.id] == opt.id;
        final letter = i < letters.length ? letters[i] : '${i + 1}';

        return GestureDetector(
          onTap: () {
            setState(() => _answers[q.id] = opt.id);
            if (widget.onOptionSelected != null) {
              widget.onOptionSelected!(q.id, opt.id);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primarySubtle
                  : (isDark ? AppColors.darkCard : AppColors.lightCard),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: 1.5,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    opt.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? (isDark ? Colors.white : AppColors.primary)
                          : textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrueFalseOptionCard({
    required String label,
    required String value,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? activeColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeworkRunnerScreen extends StatefulWidget {
  final Homework homework;
  final Function(String questionId, String optionId)? onOptionSelected;
  final VoidCallback? onSubmit;

  const HomeworkRunnerScreen({
    super.key,
    required this.homework,
    this.onOptionSelected,
    this.onSubmit,
  });

  @override
  State<HomeworkRunnerScreen> createState() => _HomeworkRunnerScreenState();
}

class _HomeworkRunnerScreenState extends State<HomeworkRunnerScreen> {
  final Map<String, String> _answers = {};
  final Set<String> _flaggedQuestions = {};
  final Map<String, TextEditingController> _textControllers = {};
  int _currentQuestionIndex = 0;

  @override
  void dispose() {
    for (final ctrl in _textControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController _getTextController(String questionId) {
    if (!_textControllers.containsKey(questionId)) {
      final ctrl = TextEditingController(text: _answers[questionId] ?? '');
      ctrl.addListener(() {
        _answers[questionId] = ctrl.text;
        if (widget.onOptionSelected != null && ctrl.text.isNotEmpty) {
          widget.onOptionSelected!(questionId, ctrl.text);
        }
      });
      _textControllers[questionId] = ctrl;
    }
    return _textControllers[questionId]!;
  }

  void _showQuestionPaletteSheet(List<Question> questions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.darkSurface : Colors.white;
        final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

        final answeredCount = questions.where((q) {
          final ans = _answers[q.id];
          return ans != null && ans.trim().isNotEmpty;
        }).length;
        final flaggedCount = _flaggedQuestions.length;
        final unansweredCount = questions.length - answeredCount;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'قائمة أسئلة الواجب 📖',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  _buildLegend(Colors.blue, 'تم الحل ($answeredCount)'),
                  _buildLegend(Colors.grey.shade400, 'متبقي ($unansweredCount)'),
                  _buildLegend(Colors.orange, 'للمراجعة ($flaggedCount)'),
                ],
              ),
              const Divider(height: 20),
              SizedBox(
                height: 220,
                child: GridView.builder(
                  itemCount: questions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemBuilder: (context, idx) {
                    final q = questions[idx];
                    final isCurrent = idx == _currentQuestionIndex;
                    final isAnswered = (_answers[q.id]?.trim().isNotEmpty) ?? false;
                    final isFlagged = _flaggedQuestions.contains(q.id);

                    Color itemBg;
                    Color itemBorder;
                    Color textC;

                    if (isCurrent) {
                      itemBorder = Colors.blue;
                      itemBg = Colors.blue.withValues(alpha: 0.15);
                      textC = Colors.blue;
                    } else if (isFlagged) {
                      itemBorder = Colors.orange;
                      itemBg = Colors.orange.withValues(alpha: 0.15);
                      textC = Colors.orange.shade800;
                    } else if (isAnswered) {
                      itemBorder = Colors.blue.shade700;
                      itemBg = Colors.blue.withValues(alpha: 0.1);
                      textC = Colors.blue.shade800;
                    } else {
                      itemBorder = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
                      itemBg = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
                      textC = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
                    }

                    return InkWell(
                      onTap: () {
                        setState(() => _currentQuestionIndex = idx);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: itemBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: itemBorder, width: isCurrent ? 2 : 1),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textC),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('Done')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _confirmAndSubmitHomework(List<Question> questions) {
    final unanswered = <int>[];
    for (int i = 0; i < questions.length; i++) {
      final ans = _answers[questions[i].id];
      if (ans == null || ans.trim().isEmpty) {
        unanswered.add(i + 1);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.assignment_turned_in_rounded, color: Colors.blue),
            const SizedBox(width: 8),
            Text(unanswered.isNotEmpty ? 'تسليم الواجب مع أسئلة متبقية' : 'تأكيد تسليم الواجب 🚀'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unanswered.isNotEmpty) ...[
              Text(
                'تنبيه: لم تقم بالإجابة عن ${unanswered.length} سؤال من أسئلة الواجب!',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 6),
              Text(
                'الأسئلة المتبقية: ${unanswered.join('، ')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
            ] else ...[
              const Text(
                'أحسنت! قمت بحل كافة أسئلة الواجب بنجاح.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'هل ترغب في اعتماد تسليم الواجب الآن للمدرس للتصحيح ورصد الدرجات؟',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('العودة للحل'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onSubmit != null) {
                widget.onSubmit!();
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('تسليم الواجب الآن ✨'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homework = widget.homework;
    final questions = homework.questions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          title: Text(homework.title, style: AppTypography.titleLarge(textPrimary)),
        ),
        body: Center(
          child: Text(
            context.tr('No questions configured for this homework.'),
            style: AppTypography.bodyLarge(textSecondary),
          ),
        ),
      );
    }

    final currentQuestion = questions[_currentQuestionIndex];
    final isCurrentFlagged = _flaggedQuestions.contains(currentQuestion.id);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('Exit Homework?')),
            content: Text(
              context.tr(
                'Are you sure you want to exit? Your current answers will be submitted to the teacher.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('Exit & Submit')),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          if (widget.onSubmit != null) {
            widget.onSubmit!();
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          title: Text(
            homework.title,
            style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'لوحة الأسئلة',
              icon: const Icon(Icons.grid_view_rounded, color: Colors.blue),
              onPressed: () => _showQuestionPaletteSheet(questions),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'تسليم حتى: ${homework.dueAt.month}/${homework.dueAt.day}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: FadeInSlide(
            key: ValueKey(_currentQuestionIndex),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress and Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${context.tr('Question')} ${_currentQuestionIndex + 1} ${context.tr('of')} ${questions.length}',
                        style: AppTypography.bodyMedium(textSecondary).copyWith(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isCurrentFlagged) {
                                  _flaggedQuestions.remove(currentQuestion.id);
                                } else {
                                  _flaggedQuestions.add(currentQuestion.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCurrentFlagged ? Colors.orange.withValues(alpha: 0.15) : Colors.transparent,
                                border: Border.all(
                                  color: isCurrentFlagged ? Colors.orange : Colors.grey.shade400,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCurrentFlagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                                    size: 14,
                                    color: isCurrentFlagged ? Colors.orange : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isCurrentFlagged ? 'مميز للمراجعة' : 'تمييز',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrentFlagged ? Colors.orange : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: context.tr('Autosaved'),
                            status: ChipStatus.success,
                            icon: Icons.cloud_done_rounded,
                            small: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / questions.length,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 18),
                  // Points
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${currentQuestion.defaultPoints} درجات',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentQuestion.prompt,
                    style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // Question Options or Input Area
                  Expanded(
                    child: _buildHomeworkInputArea(currentQuestion, isDark, textPrimary),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: GhostButton(
                            text: context.tr('Previous'),
                            icon: Icons.arrow_back_rounded,
                            onPressed: () => setState(() => _currentQuestionIndex--),
                          ),
                        )
                      else
                        const Spacer(),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _currentQuestionIndex < questions.length - 1
                            ? PrimaryButton(
                                text: context.tr('Next'),
                                icon: Icons.arrow_forward_rounded,
                                onPressed: () => setState(() => _currentQuestionIndex++),
                              )
                            : PrimaryButton(
                                text: context.tr('Submit Homework'),
                                icon: Icons.check_circle_rounded,
                                color: AppColors.success,
                                onPressed: () => _confirmAndSubmitHomework(questions),
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
  }

  Widget _buildHomeworkInputArea(Question q, bool isDark, Color textPrimary) {
    if (q.questionType == QuestionType.trueFalse) {
      final selectedVal = _answers[q.id];
      return Column(
        children: [
          _buildTrueFalseCard(
            label: 'صواب (True) ✔️',
            value: 'true',
            isSelected: selectedVal == 'true',
            activeColor: Colors.green,
            isDark: isDark,
            onTap: () {
              setState(() => _answers[q.id] = 'true');
              if (widget.onOptionSelected != null) {
                widget.onOptionSelected!(q.id, 'true');
              }
            },
          ),
          const SizedBox(height: 12),
          _buildTrueFalseCard(
            label: 'خطأ (False) ❌',
            value: 'false',
            isSelected: selectedVal == 'false',
            activeColor: Colors.red,
            isDark: isDark,
            onTap: () {
              setState(() => _answers[q.id] = 'false');
              if (widget.onOptionSelected != null) {
                widget.onOptionSelected!(q.id, 'false');
              }
            },
          ),
        ],
      );
    }

    if (q.questionType == QuestionType.shortAnswer ||
        q.questionType == QuestionType.longAnswer ||
        q.options.isEmpty) {
      final ctrl = _getTextController(q.id);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اكتب إجابتك النموذجية على السؤال:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: q.questionType == QuestionType.longAnswer ? 8 : 4,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'اكتب حل المسألة أو الإجابة هنا...',
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default MCQ
    final letters = ['أ', 'ب', 'ج', 'د', 'هـ'];
    return ListView.separated(
      itemCount: q.options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final opt = q.options[i];
        final isSelected = _answers[q.id] == opt.id;
        final letter = i < letters.length ? letters[i] : '${i + 1}';

        return GestureDetector(
          onTap: () {
            setState(() => _answers[q.id] = opt.id);
            if (widget.onOptionSelected != null) {
              widget.onOptionSelected!(q.id, opt.id);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withValues(alpha: 0.15)
                  : (isDark ? AppColors.darkCard : AppColors.lightCard),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? Colors.blue
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.blue
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: 1.5,
                    ),
                    color: isSelected ? Colors.blue : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    opt.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? Colors.blue : textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrueFalseCard({
    required String label,
    required String value,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? activeColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

