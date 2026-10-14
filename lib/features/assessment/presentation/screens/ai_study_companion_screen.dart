import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class AiStudyCompanionScreen extends StatefulWidget {
  final String studentName;

  const AiStudyCompanionScreen({
    super.key,
    this.studentName = 'أحمد محمود',
  });

  @override
  State<AiStudyCompanionScreen> createState() => _AiStudyCompanionScreenState();
}

class _AiStudyCompanionScreenState extends State<AiStudyCompanionScreen> {
  bool _isGeneratingQuiz = false;
  bool _isInQuizMode = false;
  int _currentQuizIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasRevealedAnswer = false;
  int _score = 0;

  final List<Map<String, dynamic>> _weakTopics = [
    {
      'topic': 'قوانين كيرشوف وتوزيع الجهود',
      'subject': 'فيزياء',
      'accuracy': 52.0,
      'status': 'يحتاج تركيز عاجل ⚠️',
      'color': Colors.red,
    },
    {
      'topic': 'تسمية هاليدات الألكيل والألكانات',
      'subject': 'كيمياء',
      'accuracy': 64.0,
      'status': 'متوسط ⚡',
      'color': Colors.orange,
    },
    {
      'topic': 'تفاضل الدوال المثلثية المعقدة',
      'subject': 'رياضيات',
      'accuracy': 70.0,
      'status': 'جيد ويمكن تحسينه 📈',
      'color': Colors.blue,
    },
  ];

  final List<Map<String, dynamic>> _generatedPracticeQuestions = [
    {
      'subject': 'فيزياء',
      'topic': 'قوانين كيرشوف',
      'question': 'في دائرة كهربية مغلقة، المجموع الجبري للقوى الدافعة الكهربية يساوي المجموع الجبري لـ:',
      'options': [
        'فروق الجهد عبر المقاومات (∑V = ∑IR)',
        'شدة التيار في الفروع الخارجية فقط',
        'القدرة الكهربية المستهلكة',
        'المقاومة الكلية المكافئة للدائرة',
      ],
      'correct_index': 0,
      'explanation': 'طبقاً لقانون كيرشوف الثاني (قانون حفظ الطاقة): في أي مسار مغلق يكون المجموع الجبري للقوى الدافعة الكهربية مساوياً للمجموع الجبري لفروق الجهد عبر مقاومات المسار.',
    },
    {
      'subject': 'كيمياء',
      'topic': 'الكيمياء العضوية',
      'question': 'ما هو الاسم النظامي (IUPAC) للمركب: CH3-CH(Cl)-CH3 ؟',
      'options': [
        '1-كلورو بروبان',
        '2-كلورو بروبان',
        'كلوريد البروبيل الحلقي',
        '2-كلورو إيثان',
      ],
      'correct_index': 1,
      'explanation': 'سلسلة الكربون الأطول تحتوي على 3 ذرات كربون (بروبان)، ومجموعة الكلور متصلة بذرة الكربون رقم 2، وبالتالي الاسم النظامي هو 2-كلورو بروبان.',
    },
    {
      'subject': 'فيزياء',
      'topic': 'قانون أوم',
      'question': 'إذا زاد طول موصل فلزي منتظم المقطع إلى الضعف وقلت مساحة مقطعه إلى النصف، فإن مقاومته الكهربية:',
      'options': [
        'تزداد إلى الضعف',
        'تظل ثابتة دون تغيير',
        'تزداد إلى 4 أمثال قيمتها',
        'تقل إلى الربع',
      ],
      'correct_index': 2,
      'explanation': 'المقاومة R = ρ (L / A). عندما يتضاعف الطول (2L) وتنخفض المساحة للنصف (0.5A)، فإن R تصبح (2 / 0.5) = 4 أضعاف قيمتها الأصلية.',
    },
  ];

  void _startSmartQuiz() {
    setState(() => _isGeneratingQuiz = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _isGeneratingQuiz = false;
        _isInQuizMode = true;
        _currentQuizIndex = 0;
        _selectedAnswerIndex = null;
        _hasRevealedAnswer = false;
        _score = 0;
      });
    });
  }

  void _submitAnswer(int index) {
    if (_hasRevealedAnswer) return;
    final currentQ = _generatedPracticeQuestions[_currentQuizIndex];
    final isCorrect = index == currentQ['correct_index'];

    setState(() {
      _selectedAnswerIndex = index;
      _hasRevealedAnswer = true;
      if (isCorrect) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentQuizIndex < _generatedPracticeQuestions.length - 1) {
      setState(() {
        _currentQuizIndex++;
        _selectedAnswerIndex = null;
        _hasRevealedAnswer = false;
      });
    } else {
      // Completed quiz
      _showQuizResultDialog();
    }
  }

  void _showQuizResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('أحسنت يا بطل! 🎯', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 64),
            const SizedBox(height: 12),
            Text(
              'حققت $_score من ${_generatedPracticeQuestions.length} في الكويز التدريبي الذكي!',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تم تحديث سجل المذاكرة ونقاط الضعف تلقائياً.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isInQuizMode = false);
            },
            child: const Text('العودة للوحة المساعد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('المساعد الذكي للمذاكرة 🤖'),
      ),
      body: _isInQuizMode ? _buildQuizRunner(isDark, textPrimary, textSecondary) : _buildDashboard(isDark, textPrimary, textSecondary),
    );
  }

  Widget _buildDashboard(bool isDark, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting & AI status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Colors.indigo.shade800],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحباً بك، ${widget.studentName} 👋',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'قام المساعد الذكي بتحليل نتائج امتحاناتك وواجباتك الأخيرة واكتشف 3 نقاط تحتاج للتقوية قبل امتحانات الشهر.',
                        style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Weak topics heading
          Text(
            'تحليل نقاط القوة والضعف (Smart Insights) 📊',
            style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          ..._weakTopics.map((item) {
            final double acc = item['accuracy'];
            final Color color = item['color'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item['subject']} • ${item['status']}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                        Text(
                          'مستوى الإتقان: ${acc.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['topic'],
                      style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: acc / 100,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Action button to generate AI Practice Quiz
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
            ),
            onPressed: _isGeneratingQuiz ? null : _startSmartQuiz,
            icon: _isGeneratingQuiz
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.bolt_rounded, size: 22),
            label: Text(
              _isGeneratingQuiz ? 'جارٍ توليد الأسئلة من بنك الأسئلة...' : 'توليد كويز تدريبي فوري لتقوية نقاط الضعف',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizRunner(bool isDark, Color textPrimary, Color textSecondary) {
    final q = _generatedPracticeQuestions[_currentQuizIndex];
    final options = q['options'] as List<String>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تدريب ذكي: سؤال ${_currentQuizIndex + 1} من ${_generatedPracticeQuestions.length}',
                style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${q['subject']} • ${q['topic']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuizIndex + 1) / _generatedPracticeQuestions.length,
            backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 20),

          // Question prompt
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              q['question'],
              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),

          // Options
          ...List.generate(options.length, (idx) {
            final opt = options[idx];
            final isChosen = _selectedAnswerIndex == idx;
            final isCorrect = idx == q['correct_index'];

            Color borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
            Color bgCol = isDark ? AppColors.darkCard : AppColors.lightCard;

            if (_hasRevealedAnswer) {
              if (isCorrect) {
                borderCol = Colors.green;
                bgCol = Colors.green.withValues(alpha: 0.12);
              } else if (isChosen) {
                borderCol = Colors.red;
                bgCol = Colors.red.withValues(alpha: 0.12);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: _hasRevealedAnswer ? null : () => _submitAnswer(idx),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgCol,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isChosen ? AppColors.primary : Colors.transparent,
                          border: Border.all(color: isChosen ? AppColors.primary : Colors.grey),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + idx),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isChosen ? Colors.white : textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (_hasRevealedAnswer && isCorrect)
                        const Icon(Icons.check_circle_rounded, color: Colors.green),
                      if (_hasRevealedAnswer && isChosen && !isCorrect)
                        const Icon(Icons.cancel_rounded, color: Colors.red),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Detailed Explanation Box
          if (_hasRevealedAnswer) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: Colors.blue, size: 18),
                      SizedBox(width: 6),
                      Text('الشرح والتوضيح النموذجي:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q['explanation'],
                    style: TextStyle(fontSize: 12, color: textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _nextQuestion,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _currentQuizIndex < _generatedPracticeQuestions.length - 1 ? 'السؤال التالي' : 'إنهاء وعرض النتيجة',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
