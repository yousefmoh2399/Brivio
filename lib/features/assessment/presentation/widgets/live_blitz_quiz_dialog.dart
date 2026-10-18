import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class LiveBlitzQuizDialog extends StatefulWidget {
  final String groupName;
  final String subjectName;
  final String? groupId;
  final String? teacherId;
  final List<Map<String, dynamic>>? initialConnectedStudents;
  final List<String>? initialQuestions;
  final bool autoStartTimer;
  final bool startInLiveMode;

  const LiveBlitzQuizDialog({
    super.key,
    this.groupName = 'ثانوية عامة - لغات A',
    this.subjectName = 'الفيزياء الحديثة',
    this.groupId,
    this.teacherId,
    this.initialConnectedStudents,
    this.initialQuestions,
    this.autoStartTimer = true,
    this.startInLiveMode = false,
  });

  static Future<void> show(
    BuildContext context, {
    String? groupName,
    String? subjectName,
    String? groupId,
    String? teacherId,
    List<Map<String, dynamic>>? initialConnectedStudents,
    List<String>? initialQuestions,
    bool autoStartTimer = true,
    bool startInLiveMode = false,
  }) {
    return showDialog(
      context: context,
      builder: (_) => LiveBlitzQuizDialog(
        groupName: groupName ?? 'مجموعة التميز A',
        subjectName: subjectName ?? 'الفيزياء',
        groupId: groupId,
        teacherId: teacherId,
        initialConnectedStudents: initialConnectedStudents,
        initialQuestions: initialQuestions,
        autoStartTimer: autoStartTimer,
        startInLiveMode: startInLiveMode,
      ),
    );
  }

  @override
  State<LiveBlitzQuizDialog> createState() => _LiveBlitzQuizDialogState();
}

class _LiveBlitzQuizDialogState extends State<LiveBlitzQuizDialog> {
  late String _pinCode;
  int _connectedCount = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _connectedStudents = [];
  Timer? _attendancePollTimer;

  int _selectedQuestionsCount = 5;
  int _secondsPerQuestion = 45;
  bool _isLiveActive = false;
  int _activeQuestionIndex = 0;
  int _timeRemaining = 45;
  Timer? _countdownTimer;

  final List<String> _defaultQuestions = [
    'سؤال تفاعلي 1: اختر الإجابة الصحيحة بناءً على شرح الدرس اليوم',
    'سؤال تفاعلي 2: ما هي النتيجة المتوقعة للتطبيق العملي؟',
    'سؤال تفاعلي 3: حل المسألة السريعة خلال الوقت المحدد',
    'سؤال تفاعلي 4: قارن بين المفاهيم الأساسية المستنبطة',
    'سؤال تفاعلي 5: حدد الاستنتاج النهائي للعلاقة البيانية',
  ];
  List<String> _questions = [];

  List<Map<String, dynamic>> _liveLeaderboard = [];

  @override
  void initState() {
    super.initState();
    _pinCode = '${100 + Random().nextInt(899)}-${100 + Random().nextInt(899)}';

    if (widget.initialQuestions != null && widget.initialQuestions!.isNotEmpty) {
      _questions = List.from(widget.initialQuestions!);
    } else {
      _questions = List.from(_defaultQuestions);
    }

    if (widget.initialConnectedStudents != null) {
      _connectedStudents = List.from(widget.initialConnectedStudents!);
      _connectedCount = _connectedStudents.length;
      _isLoading = false;
    } else {
      _loadRealData();
    }

    if (widget.startInLiveMode) {
      _startLiveCompetition();
    } else if (widget.autoStartTimer) {
      _attendancePollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && !_isLiveActive) {
          _loadConnectedStudents();
        }
      });
    }
  }

  Future<void> _loadRealData() async {
    await Future.wait([
      _loadConnectedStudents(),
      _loadQuestions(),
    ]);
  }

  Future<void> _loadQuestions() async {
    if (widget.initialQuestions != null) return;
    try {
      final client = Supabase.instance.client;
      var q = client
          .from('questions')
          .select('prompt')
          .eq('status', 'active');

      if (widget.groupId != null && widget.groupId!.isNotEmpty) {
        try {
          final gRes = await client.from('groups').select('subject_id').eq('id', widget.groupId!).maybeSingle();
          if (gRes != null && gRes['subject_id'] != null) {
            q = q.eq('subject_id', gRes['subject_id']);
          }
        } catch (_) {}
      }

      final res = await q.order('created_at', ascending: false).limit(10);
      final prompts = (res as List)
          .map((r) => r['prompt']?.toString() ?? '')
          .where((p) => p.trim().isNotEmpty)
          .toList();
      if (prompts.isNotEmpty && mounted) {
        setState(() {
          _questions = prompts;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadConnectedStudents() async {
    if (widget.initialConnectedStudents != null) return;
    try {
      final now = DateTime.now();
      final todayDate = now.toIso8601String().split('T').first;
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final client = Supabase.instance.client;

      List<dynamic> rows = [];

      // If groupId is provided, locate today's class_sessions for this group
      if (widget.groupId != null && widget.groupId!.isNotEmpty) {
        final sessionRes = await client
            .from('class_sessions')
            .select('id')
            .eq('group_id', widget.groupId!)
            .eq('session_date', todayDate);
        final sessionIds = (sessionRes as List)
            .map((s) => s['id']?.toString())
            .whereType<String>()
            .toList();

        if (sessionIds.isNotEmpty) {
          final attRes = await client
              .from('attendance_records')
              .select('id, attendance_status, student:students(id, student_code, profile:profiles(full_name))')
              .inFilter('class_session_id', sessionIds);
          rows = attRes as List;
        }
      } else {
        // Direct attendance records query for today
        try {
          final attRes = await client
              .from('attendance_records')
              .select('id, attendance_status, student:students(id, student_code, profile:profiles(full_name))')
              .gte('marked_at', todayStart)
              .order('marked_at', ascending: false)
              .limit(50);
          rows = attRes as List;
        } catch (_) {}
      }

      final list = <Map<String, dynamic>>[];
      for (final row in rows) {
        final st = (row['attendance_status'] ?? row['status'])?.toString().toLowerCase();
        if (st == 'present' || st == 'attended' || st == 'late') {
          final student = row['student'] as Map<String, dynamic>?;
          final profile = student?['profile'] as Map<String, dynamic>?;
          final name = profile?['full_name']?.toString() ?? '';
          if (name.isNotEmpty && !list.any((s) => s['name'] == name)) {
            list.add({
              'name': name,
              'points': 0,
              'speed': '--',
              'avatar': '⚡',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _connectedStudents = list;
          _connectedCount = list.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addDemoStudent() {
    HapticFeedback.lightImpact();
    final names = ['عمر خالد السيد', 'سارة محمود علي', 'يوسف أحمد كمال', 'مريم إبراهيم حسن', 'بلال مصطفى نور'];
    final unused = names.where((n) => !_connectedStudents.any((s) => s['name'] == n)).toList();
    final nameToAdd = unused.isNotEmpty ? unused.first : 'طالب جديد #${_connectedStudents.length + 1}';

    setState(() {
      _connectedStudents.add({
        'name': nameToAdd,
        'points': 0,
        'speed': '--',
        'avatar': '⚡',
      });
      _connectedCount = _connectedStudents.length;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم انضمام "$nameToAdd" إلى كويز القاعة بنجاح! 🚀'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  @override
  void dispose() {
    _attendancePollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startLiveCompetition() {
    _attendancePollTimer?.cancel();

    final avatars = ['🥇', '🥈', '🥉', '🎖️', '⭐'];
    final initialLeaderboard = <Map<String, dynamic>>[];
    for (int i = 0; i < _connectedStudents.length; i++) {
      initialLeaderboard.add({
        'name': _connectedStudents[i]['name'],
        'points': (_connectedStudents.length - i) * 20,
        'speed': '${(1.2 + i * 0.4).toStringAsFixed(1)} ث',
        'avatar': i < avatars.length ? avatars[i] : '⚡',
      });
    }

    setState(() {
      _liveLeaderboard = initialLeaderboard;
      _isLiveActive = true;
      _activeQuestionIndex = 0;
      _timeRemaining = _secondsPerQuestion;
    });

    if (widget.autoStartTimer) {
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
          } else {
            final maxQ = _questions.isEmpty
                ? _selectedQuestionsCount
                : min(_selectedQuestionsCount, _questions.length);
            if (_activeQuestionIndex < maxQ - 1) {
              _activeQuestionIndex++;
              _timeRemaining = _secondsPerQuestion;
            } else {
              _countdownTimer?.cancel();
            }
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 450;
            return SingleChildScrollView(
              padding: EdgeInsets.all(isSmall ? 16 : 24),
              child: _isLiveActive
                  ? _buildActiveQuizView(textPrimary, isDark, isSmall)
                  : _buildLobbyView(textPrimary, isDark, isSmall),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLobbyView(Color textPrimary, bool isDark, bool isSmall) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmall ? 8 : 10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bolt_rounded,
                color: Colors.purpleAccent,
                size: isSmall ? 24 : 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        'كويز الـ 5 دقائق التفاعلي ⚡',
                        style: AppTypography.titleMedium(textPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmall ? 15 : 17,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Live Blitz',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.groupName} - ${widget.subjectName}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'إغلاق',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Live PIN Banner
        Container(
          padding: EdgeInsets.all(isSmall ? 14 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4F46E5).withValues(alpha: 0.25),
                const Color(0xFF7C3AED).withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              const Text(
                'رمز الانضمام المباشر للطلاب في القاعة 📱',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigoAccent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Big PIN container with copy action
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _pinCode));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم نسخ كود الـ PIN: $_pinCode إلى الحافظة! 📋'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF4F46E5),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 12 : 24,
                    vertical: isSmall ? 6 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pinCode,
                        style: TextStyle(
                          fontSize: isSmall ? 22 : 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: isSmall ? 2 : 4,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF6366F1)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Presence status row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (_connectedCount > 0 ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_connectedCount > 0 ? Colors.green : Colors.grey).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _connectedCount > 0 ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _isLoading
                            ? 'جاري فحص حضور الطلاب بالقاعة...'
                            : (_connectedCount > 0
                                ? '$_connectedCount طالب متصل وجاهز الآن في القاعة'
                                : 'لا يوجد طلاب متصلين حالياً (0 طلاب)'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _connectedCount > 0 ? Colors.green : Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              if (_connectedCount == 0) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.indigoAccent,
                  ),
                  onPressed: _addDemoStudent,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text(
                    'إضافة طالب تجريبي للتجربة 🧪',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Config Options (Question Count & Time per Question)
        if (isSmall)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildQuestionCountSelector(isDark),
              const SizedBox(height: 12),
              _buildTimerSelector(isDark),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildQuestionCountSelector(isDark)),
              const SizedBox(width: 14),
              Expanded(child: _buildTimerSelector(isDark)),
            ],
          ),

        const SizedBox(height: 20),

        // Start Button
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          onPressed: () {
            if (_connectedCount == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تنبيه: لا يوجد طلاب متصلون بالقاعة حالياً. يمكنك الضغط على "إضافة طالب تجريبي للتجربة" أو انتظار حضور الطلاب للبدء!',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            HapticFeedback.heavyImpact();
            _startLiveCompetition();
          },
          icon: const Icon(Icons.play_arrow_rounded, size: 24),
          label: Text(
            'إطلاق كويز الـ 5 دقائق في القاعة 🚀',
            style: TextStyle(
              fontSize: isSmall ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCountSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'عدد أسئلة الكويز:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [3, 5, 10].map((count) {
            final isSelected = _selectedQuestionsCount == count;
            return ChoiceChip(
              label: Text('$count أسئلة'),
              selected: isSelected,
              selectedColor: const Color(0xFF6366F1),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              onSelected: (_) => setState(() => _selectedQuestionsCount = count),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimerSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'وقت كل سؤال:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [30, 45, 60].map((secs) {
            final isSelected = _secondsPerQuestion == secs;
            return ChoiceChip(
              label: Text('$secs ثانية'),
              selected: isSelected,
              selectedColor: Colors.purpleAccent,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              onSelected: (_) => setState(() => _secondsPerQuestion = secs),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActiveQuizView(Color textPrimary, bool isDark, bool isSmall) {
    final questionsPool = _questions.isNotEmpty ? _questions : _defaultQuestions;
    final currentQ = questionsPool[_activeQuestionIndex % questionsPool.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Progress & Timer Header
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'السؤال ${_activeQuestionIndex + 1} من $_selectedQuestionsCount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.purpleAccent,
                ),
              ),
            ),
            // Countdown chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _timeRemaining <= 10
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.indigo.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _timeRemaining <= 10 ? Colors.red : Colors.indigo,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_rounded,
                    size: 14,
                    color: _timeRemaining <= 10 ? Colors.red : Colors.indigo,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_timeRemaining ثانية',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: _timeRemaining <= 10 ? Colors.red : Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Question Box
        Container(
          padding: EdgeInsets.all(isSmall ? 12 : 18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Text(
            currentQ,
            style: AppTypography.titleMedium(textPrimary).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isSmall ? 13 : 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),

        // Live Answers Leaderboard Header
        Row(
          children: [
            const Icon(Icons.leaderboard_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'لوحة صدارة المتفوقين في القاعة (Live Top 5) 🏆',
                style: AppTypography.titleSmall(textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmall ? 11 : 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Leaderboard List
        if (_liveLeaderboard.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: const Center(
              child: Text(
                'في انتظار إجابات الطلاب عبر أجهزتهم...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        else
          ..._liveLeaderboard.take(5).toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: idx == 0 ? Colors.amber.withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Text(item['avatar'] as String, style: TextStyle(fontSize: isSmall ? 14 : 16)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmall ? 11 : 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSmall ? '${item['points']} ن ⚡' : '${item['points']} نقطة ⚡ (${item['speed']})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
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
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() => _isLiveActive = false),
                child: const Text('إنهاء التحدي', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF6366F1),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (_activeQuestionIndex < _selectedQuestionsCount - 1) {
                    setState(() {
                      _activeQuestionIndex++;
                      _timeRemaining = _secondsPerQuestion;
                    });
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إنهاء كويز الحصة وتتويج المتفوقين بنجاح! 🏆'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: Text(
                  _activeQuestionIndex < _selectedQuestionsCount - 1
                      ? 'السؤال التالي ➡️'
                      : 'تتويج الفائزين 👑',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
