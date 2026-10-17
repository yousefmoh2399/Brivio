import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../design_system/tokens/typography.dart';

class _BlitzQuestionData {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String subject;

  const _BlitzQuestionData({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.subject,
  });
}

class StudentBlitzQuizJoinDialog extends StatefulWidget {
  final String studentName;
  final String? initialPin;
  final String? groupId;

  const StudentBlitzQuizJoinDialog({
    super.key,
    required this.studentName,
    this.initialPin,
    this.groupId,
  });

  static Future<void> show(
    BuildContext context, {
    required String studentName,
    String? initialPin,
    String? groupId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => StudentBlitzQuizJoinDialog(
        studentName: studentName,
        initialPin: initialPin,
        groupId: groupId,
      ),
    );
  }

  @override
  State<StudentBlitzQuizJoinDialog> createState() =>
      _StudentBlitzQuizJoinDialogState();
}

enum _BlitzStep { enterPin, connecting, inProgress, finished }

class _StudentBlitzQuizJoinDialogState
    extends State<StudentBlitzQuizJoinDialog> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  _BlitzStep _currentStep = _BlitzStep.enterPin;
  String? _errorMessage;

  // Quiz State
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswerSubmitted = false;
  int _score = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _timeRemaining = 45;
  Timer? _countdownTimer;

  // Loaded questions
  final List<_BlitzQuestionData> _questions = [
    const _BlitzQuestionData(
      prompt: 'في الدائرة الكهربية، ما هي قراءة الأميتر عند غلق المفتاح K؟',
      options: [
        'تزداد للضعف',
        'تقل للنصف',
        'تظل ثابتة',
        'تنعدم تماماً',
      ],
      correctIndex: 0,
      subject: 'الفيزياء الحديثة',
    ),
    const _BlitzQuestionData(
      prompt: 'أي من العوامل الآتية لا يؤثر على معامل الحث الذاتي للملف؟',
      options: [
        'شدة التيار المار بالملف',
        'عدد لفات الملف',
        'المساحة المقطعية للملف',
        'النفاذية المغناطيسية للوسط',
      ],
      correctIndex: 0,
      subject: 'الفيزياء الكهربية',
    ),
    const _BlitzQuestionData(
      prompt: 'ما النسبة بين طاقة فوتون أشعة إكس وطاقة فوتون الضوء المرئي؟',
      options: [
        'أكبر من الواحد الصحيح',
        'أقل من الواحد الصحيح',
        'تساوي الواحد الصحيح',
        'تساوي صفر دائماً',
      ],
      correctIndex: 0,
      subject: 'الفيزياء الحديثة',
    ),
    const _BlitzQuestionData(
      prompt: 'عند زيادة تردد الضوء الساقط على مهبط خلية كهروضوئية، ما الذي يزداد حتماً؟',
      options: [
        'طاقة حركة الإلكترونات المنبعثة',
        'عدد الإلكترونات المنبعثة في الثانية',
        'شدة تيار التشبع',
        'دالة الشغل لسطح المعدن',
      ],
      correctIndex: 0,
      subject: 'الفيزياء',
    ),
    const _BlitzQuestionData(
      prompt: 'ما هي وظيفة أسطوانة الحديد المطاوع المقسمة إلى شرائح في المحول الكهربي؟',
      options: [
        'الحد من التيارات الدوامية وفقد الطاقة',
        'زيادة مقاومة الأسلاك',
        'رفع التردد الناتج',
        'تبريد الدائرة الثانوية فقط',
      ],
      correctIndex: 0,
      subject: 'الفيزياء التطبيقية',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPin != null && widget.initialPin!.isNotEmpty) {
      _pinController.text = widget.initialPin!;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _formatPinInput(String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length > 6) return;

    if (clean.length > 3) {
      final formatted = '${clean.substring(0, 3)}-${clean.substring(3)}';
      if (_pinController.text != formatted) {
        _pinController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    } else {
      if (_pinController.text != clean) {
        _pinController.value = TextEditingValue(
          text: clean,
          selection: TextSelection.collapsed(offset: clean.length),
        );
      }
    }
  }

  Future<void> _handleJoinQuiz() async {
    final cleanPin = _pinController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPin.length != 6) {
      setState(() {
        _errorMessage = 'الرجاء إدخال كود PIN صحيح مكون من 6 أرقام (مثال: 582-194)';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _currentStep = _BlitzStep.connecting;
    });

    HapticFeedback.lightImpact();

    // Try fetching live questions or verify connection
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('questions')
          .select('id, prompt, options')
          .order('created_at', ascending: false)
          .limit(5);

      if (res.isNotEmpty) {
        final loaded = <_BlitzQuestionData>[];
        for (final row in res) {
          final prompt = row['prompt']?.toString() ?? '';
          final rawOptions = row['options'] as List<dynamic>? ?? [];
          if (prompt.isNotEmpty && rawOptions.length >= 2) {
            final opts = rawOptions.map((o) => o.toString()).toList();
            loaded.add(_BlitzQuestionData(
              prompt: prompt,
              options: opts,
              correctIndex: 0,
              subject: 'كويز الحصة المباشر',
            ));
          }
        }
        if (loaded.isNotEmpty) {
          _questions.clear();
          _questions.addAll(loaded);
        }
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _currentStep = _BlitzStep.inProgress;
      _currentQuestionIndex = 0;
      _score = 0;
      _correctCount = 0;
      _streak = 0;
      _isAnswerSubmitted = false;
      _selectedOptionIndex = null;
    });

    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _countdownTimer?.cancel();
    _timeRemaining = 45;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_timeRemaining <= 1) {
        t.cancel();
        _handleTimeExpired();
      } else {
        setState(() {
          _timeRemaining--;
        });
      }
    });
  }

  void _handleTimeExpired() {
    if (_isAnswerSubmitted) return;
    setState(() {
      _isAnswerSubmitted = true;
      _selectedOptionIndex = null;
      _streak = 0;
    });
    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _goToNextQuestion();
    });
  }

  void _selectOption(int index) {
    if (_isAnswerSubmitted) return;

    _countdownTimer?.cancel();
    final currentQ = _questions[_currentQuestionIndex];
    final isCorrect = (index == currentQ.correctIndex);

    HapticFeedback.mediumImpact();

    setState(() {
      _selectedOptionIndex = index;
      _isAnswerSubmitted = true;

      if (isCorrect) {
        _correctCount++;
        _streak++;
        // Base 100 points + speed bonus (up to 50) + streak bonus
        final speedBonus = (_timeRemaining * 1.1).round().clamp(0, 50);
        final streakBonus = (_streak > 1) ? (_streak * 10) : 0;
        _score += (100 + speedBonus + streakBonus);
      } else {
        _streak = 0;
      }
    });

    // Auto proceed to next question after 1.4 seconds
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _goToNextQuestion();
    });
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex + 1 < _questions.length) {
      setState(() {
        _currentQuestionIndex++;
        _isAnswerSubmitted = false;
        _selectedOptionIndex = null;
      });
      _startQuestionTimer();
    } else {
      _countdownTimer?.cancel();
      setState(() {
        _currentStep = _BlitzStep.finished;
      });
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.purpleAccent.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: switch (_currentStep) {
                _BlitzStep.enterPin => _buildPinEntryView(textPrimary, isDark),
                _BlitzStep.connecting => _buildConnectingView(textPrimary, isDark),
                _BlitzStep.inProgress => _buildQuizRunnerView(textPrimary, isDark),
                _BlitzStep.finished => _buildFinishedView(textPrimary, isDark),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: PIN Entry ──
  Widget _buildPinEntryView(Color textPrimary, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'كويز 5 دقائق المباشر ⚡',
                          style: AppTypography.titleMedium(textPrimary).copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'أهلاً ${widget.studentName}، أدخل كود الحصة للبدء',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // PIN Input Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.indigoAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'رمز الـ PIN المعروض في قاعة السنتر 📱',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigoAccent,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                autofocus: false,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: _formatPinInput,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Color(0xFF6366F1),
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: '___-___',
                  hintStyle: TextStyle(
                    fontSize: 30,
                    letterSpacing: 4,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.indigo.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Action Buttons
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _handleJoinQuiz,
          icon: const Icon(Icons.rocket_launch_rounded, size: 20),
          label: const Text(
            'دخول الكويز الآن 🚀',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Connecting ──
  Widget _buildConnectingView(Color textPrimary, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'جاري الاتصال بالقاعة...',
          style: AppTypography.titleMedium(textPrimary).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'التحقق من كود الـ PIN ومزامنة أسئلة الحصة...',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Step 3: Interactive Quiz Runner ──
  Widget _buildQuizRunnerView(Color textPrimary, bool isDark) {
    final currentQ = _questions[_currentQuestionIndex];
    final progress = (_timeRemaining / 45.0).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top HUD: Question index, Timer, Score & Streak
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'سؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purpleAccent,
                  fontSize: 12,
                ),
              ),
            ),
            Row(
              children: [
                if (_streak > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Text(
                      '🔥 x$_streak',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '⭐ $_score نقطة',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Animated Countdown Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(
              _timeRemaining <= 10
                  ? Colors.redAccent
                  : (_timeRemaining <= 20 ? Colors.amber : const Color(0xFF6366F1)),
            ),
          ),
        ),

        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$_timeRemaining ثانية متبقية',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _timeRemaining <= 10 ? Colors.redAccent : Colors.grey,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Question Prompt Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.indigoAccent.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            currentQ.prompt,
            style: AppTypography.bodyLarge(textPrimary).copyWith(
              fontWeight: FontWeight.bold,
              height: 1.4,
              fontSize: 15,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 4 Options
        ...List.generate(currentQ.options.length, (idx) {
          final optText = currentQ.options[idx];
          final isSelected = (_selectedOptionIndex == idx);
          final isCorrect = (idx == currentQ.correctIndex);

          Color cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
          Color borderColor = isDark ? Colors.white12 : Colors.black12;
          Color textColor = textPrimary;

          if (_isAnswerSubmitted) {
            if (isCorrect) {
              cardBg = Colors.green.withValues(alpha: 0.2);
              borderColor = Colors.greenAccent;
              textColor = Colors.greenAccent;
            } else if (isSelected) {
              cardBg = Colors.red.withValues(alpha: 0.2);
              borderColor = Colors.redAccent;
              textColor = Colors.redAccent;
            }
          }

          final optionLetters = ['أ', 'ب', 'ج', 'د'];
          final letter = idx < optionLetters.length ? optionLetters[idx] : '${idx + 1}';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: _isAnswerSubmitted ? null : () => _selectOption(idx),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: borderColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        optText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isAnswerSubmitted && isCorrect)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 20,
                      )
                    else if (_isAnswerSubmitted && isSelected && !isCorrect)
                      const Icon(
                        Icons.cancel_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Step 4: Results Screen ──
  Widget _buildFinishedView(Color textPrimary, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: Colors.black87,
            size: 44,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'أحسنت يا بطل! 🎉',
          style: AppTypography.titleLarge(textPrimary).copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'انتهى كويز الـ 5 دقائق المباشر بنجاح',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 20),

        // Score summary cards
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn('مجموع النقاط', '$_score', Colors.amber),
              _buildMetricColumn('الإجابات الصحيحة', '$_correctCount/${_questions.length}', Colors.greenAccent),
              _buildMetricColumn('المكافأة المكتسبة', '+100 XP', Colors.cyanAccent),
            ],
          ),
        ),

        const SizedBox(height: 24),

        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'إنهاء والعودة للرئيسية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
