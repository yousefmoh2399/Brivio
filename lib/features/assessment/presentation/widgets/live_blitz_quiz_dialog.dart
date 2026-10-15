import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class LiveBlitzQuizDialog extends StatefulWidget {
  final String groupName;
  final String subjectName;

  const LiveBlitzQuizDialog({
    super.key,
    this.groupName = 'ثانوية عامة - لغات A',
    this.subjectName = 'الفيزياء الحديثة',
  });

  static Future<void> show(BuildContext context, {String? groupName, String? subjectName}) {
    return showDialog(
      context: context,
      builder: (_) => LiveBlitzQuizDialog(
        groupName: groupName ?? 'مجموعة التميز A',
        subjectName: subjectName ?? 'الفيزياء',
      ),
    );
  }

  @override
  State<LiveBlitzQuizDialog> createState() => _LiveBlitzQuizDialogState();
}

class _LiveBlitzQuizDialogState extends State<LiveBlitzQuizDialog> {
  late String _pinCode;
  int _connectedCount = 18;
  Timer? _connectSimTimer;

  int _selectedQuestionsCount = 5;
  int _secondsPerQuestion = 45;
  bool _isLiveActive = false;
  int _activeQuestionIndex = 0;
  int _timeRemaining = 45;
  Timer? _countdownTimer;

  final List<String> _simulatedQuestions = [
    'في الدائرة الموضحة، ما هي قراءة الأميتر عند غلق المفتاح K؟',
    'أي من العوامل الآتية لا يؤثر على معامل الحث الذاتي للملف؟',
    'ما هي النسبة بين طاقة فوتون أشعة إكس وطاقة فوتون الضوء المرئي؟',
    'عند زيادة تردد الضوء الساقط على مهبط خلية كهروضوئية، ما الذي يزداد؟',
    'ما هي وظيفة أسطوانة الحديد المطاوع المقسمة إلى شرائح في المحول الكهربي؟',
  ];

  final List<Map<String, dynamic>> _liveLeaderboard = [
    {'name': 'عمر أحمد محمود', 'points': 480, 'speed': '1.2s', 'avatar': '🥇'},
    {'name': 'مريم حسام الدين', 'points': 460, 'speed': '1.8s', 'avatar': '🥈'},
    {'name': 'زياد طارق إبراهيم', 'points': 420, 'speed': '2.1s', 'avatar': '🥉'},
    {'name': 'فاطمة خالد علي', 'points': 390, 'speed': '2.5s', 'avatar': '🎖️'},
    {'name': 'يوسف مصطفى كمال', 'points': 350, 'speed': '3.0s', 'avatar': '⭐'},
  ];

  @override
  void initState() {
    super.initState();
    _pinCode = '${100 + Random().nextInt(899)}-${100 + Random().nextInt(899)}';
    _connectSimTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (mounted && _connectedCount < 38) {
        setState(() => _connectedCount += 1 + Random().nextInt(2));
      }
    });
  }

  @override
  void dispose() {
    _connectSimTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startLiveCompetition() {
    setState(() {
      _isLiveActive = true;
      _activeQuestionIndex = 0;
      _timeRemaining = _secondsPerQuestion;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          if (_activeQuestionIndex < _selectedQuestionsCount - 1) {
            _activeQuestionIndex++;
            _timeRemaining = _secondsPerQuestion;
          } else {
            _countdownTimer?.cancel();
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _isLiveActive ? _buildActiveQuizView(textPrimary, isDark) : _buildLobbyView(textPrimary, isDark),
        ),
      ),
    );
  }

  Widget _buildLobbyView(Color textPrimary, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.purpleAccent, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'كويز الـ 5 دقائق التفاعلي الحاسم ⚡',
                        style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Live Blitz', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                    ],
                  ),
                  Text(
                    '${widget.groupName} - ${widget.subjectName}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        const SizedBox(height: 20),

        // Live PIN Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withValues(alpha: 0.2),
                const Color(0xFFA855F7).withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            children: [
              const Text(
                'رمز الدخول المباشر للطلاب في القاعة 📱',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.purple.withValues(alpha: 0.2), blurRadius: 10),
                  ],
                ),
                child: Text(
                  _pinCode,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_connectedCount طالب متصل وجاهز الآن في القاعة',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Config Options
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('عدد الأسئلة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 3, label: Text('3 أسئلة')),
                      ButtonSegment(value: 5, label: Text('5 أسئلة')),
                    ],
                    selected: {_selectedQuestionsCount},
                    onSelectionChanged: (val) => setState(() => _selectedQuestionsCount = val.first),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('وقت السؤال:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 30, label: Text('30 ثانية')),
                      ButtonSegment(value: 45, label: Text('45 ثانية')),
                    ],
                    selected: {_secondsPerQuestion},
                    onSelectionChanged: (val) => setState(() => _secondsPerQuestion = val.first),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Start Button
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _startLiveCompetition,
          icon: const Icon(Icons.play_arrow_rounded, size: 24),
          label: const Text(
            'إطلاق المسابقة الآن في القاعة 🚀',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveQuizView(Color textPrimary, bool isDark) {
    final currentQ = _simulatedQuestions[_activeQuestionIndex % _simulatedQuestions.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Progress Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'السؤال ${_activeQuestionIndex + 1} من $_selectedQuestionsCount',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
              ),
            ),
            // Countdown circle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _timeRemaining <= 10 ? Colors.red.withValues(alpha: 0.15) : Colors.indigo.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _timeRemaining <= 10 ? Colors.red : Colors.indigo),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_rounded, size: 16, color: _timeRemaining <= 10 ? Colors.red : Colors.indigo),
                  const SizedBox(width: 4),
                  Text(
                    '$_timeRemaining ثانية',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _timeRemaining <= 10 ? Colors.red : Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Question Box
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Text(
            currentQ,
            style: AppTypography.titleMedium(textPrimary).copyWith(
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),

        // Live Answers Heatmap & Leaderboard
        Row(
          children: [
            const Icon(Icons.leaderboard_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              'لوحة صدارة المتفوقين في القاعة (Live Top 5) 🏆',
              style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ..._liveLeaderboard.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: idx == 0 ? Colors.amber.withValues(alpha: 0.4) : Colors.transparent),
            ),
            child: Row(
              children: [
                Text(item['avatar'] as String, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item['points']} نقطة ⚡ (${item['speed']})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isLiveActive = false),
                child: const Text('إنهاء التحدي'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_activeQuestionIndex < _selectedQuestionsCount - 1) {
                    setState(() {
                      _activeQuestionIndex++;
                      _timeRemaining = _secondsPerQuestion;
                    });
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إنهاء كويز الحصة وتوزيع نقاط التميز بنجاح! 🏆'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: Text(_activeQuestionIndex < _selectedQuestionsCount - 1 ? 'السؤال التالي ➡️' : 'تتويج الفائزين 👑'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
