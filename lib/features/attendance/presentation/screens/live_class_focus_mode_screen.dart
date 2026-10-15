import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/whatsapp_service.dart';
import 'teacher_session_board_screen.dart';
import '../../../assessment/presentation/widgets/live_blitz_quiz_dialog.dart';
import '../../../communication/presentation/screens/class_broadcast_dialog.dart';

enum ClassPhase {
  lecture('شرح الدرس الأساسي 📖', Colors.teal),
  problemSolving('حل المسائل والتدريبات ✍️', Colors.blue),
  liveQuiz('كويز تفاعلي سريع ⚡', Colors.purple),
  qa('أسئلة ومناقشة واستفسارات ❓', Colors.amber);

  final String label;
  final Color color;
  const ClassPhase(this.label, this.color);
}

class LiveClassFocusModeScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String groupName;
  final String roomName;
  final int totalStudents;
  final int initialPresent;
  final int initialAbsent;
  final int sessionDurationMinutes;
  final List<Map<String, String>> absentStudents;

  const LiveClassFocusModeScreen({
    super.key,
    required this.teacherId,
    this.teacherName = 'معلمنا الفاضل',
    this.groupName = 'المجموعة الدراسية الحالية',
    this.roomName = 'القاعة الدراسية',
    this.totalStudents = 0,
    this.initialPresent = 0,
    this.initialAbsent = 0,
    this.sessionDurationMinutes = 120,
    this.absentStudents = const [],
  });

  @override
  State<LiveClassFocusModeScreen> createState() => _LiveClassFocusModeScreenState();
}

class _LiveClassFocusModeScreenState extends State<LiveClassFocusModeScreen>
    with TickerProviderStateMixin {
  late Timer _clockTimer;
  late Timer _qrRotationTimer;
  Timer? _attendancePollTimer;
  late AnimationController _pulseController;
  late AnimationController _bellController;

  int _elapsedSeconds = 0; // Starts from 0 seconds
  int _qrTimeRemaining = 20;
  String _currentQrToken = '';

  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;

  ClassPhase _currentPhase = ClassPhase.lecture;
  bool _isSilenceAlertActive = false;

  List<Map<String, String>> _recentCheckIns = [];
  bool _isLoadingAttendance = true;

  @override
  void initState() {
    super.initState();
    _presentCount = widget.initialPresent;
    _absentCount = widget.initialAbsent;
    _generateNewQrToken();
    _loadLiveAttendance();

    // Poll live attendance from database every 10 seconds during the projected session
    _attendancePollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadLiveAttendance();
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });

    _qrRotationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_qrTimeRemaining > 1) {
          _qrTimeRemaining--;
        } else {
          _qrTimeRemaining = 20;
          _generateNewQrToken();
        }
      });
    });
  }

  Future<void> _loadLiveAttendance() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final client = Supabase.instance.client;

      final res = await client
          .from('attendance')
          .select('id, status, recorded_at, student:students(id, student_code, profile:profiles(full_name))')
          .gte('recorded_at', todayStart)
          .order('recorded_at', ascending: false)
          .limit(10);

      final list = <Map<String, String>>[];
      int present = 0;
      int lateCount = 0;

      for (final row in (res as List)) {
        final st = row['status']?.toString().toLowerCase();
        if (st == 'present' || st == 'attended') {
          present++;
        } else if (st == 'late') {
          lateCount++;
        }
        final sName = row['student']?['profile']?['full_name']?.toString() ?? 'طالب مسجل';
        final sCode = row['student']?['student_code']?.toString() ?? '';
        final recStr = row['recorded_at']?.toString() ?? '';
        final dt = DateTime.tryParse(recStr)?.toLocal();
        final timeStr = dt != null
            ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : '--:--';
        list.add({
          'name': sName,
          'time': timeStr,
          'seat': sCode.isNotEmpty ? 'كود: $sCode' : 'قاعة المحاضرات',
        });
      }

      if (mounted) {
        setState(() {
          _recentCheckIns = list;
          _isLoadingAttendance = false;
          if (present > 0) {
            _presentCount = present;
            _lateCount = lateCount;
            if (widget.totalStudents > 0) {
              _absentCount = math.max(0, widget.totalStudents - _presentCount);
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAttendance = false;
        });
      }
    }
  }

  void _generateNewQrToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = math.Random().nextInt(9999).toString().padLeft(4, '0');
    _currentQrToken = 'BRIVIO:ATTEND:${widget.teacherId}:$timestamp:$randomSuffix';
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _qrRotationTimer.cancel();
    _attendancePollTimer?.cancel();
    _pulseController.dispose();
    _bellController.dispose();
    super.dispose();
  }

  void _triggerSilenceAlert() {
    HapticFeedback.heavyImpact();
    setState(() => _isSilenceAlertActive = true);
    _bellController.forward(from: 0.0);

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isSilenceAlertActive = false);
    });
  }

  String _formatDuration(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalDurationSecs = widget.sessionDurationMinutes * 60;
    final remainingSecs = math.max(0, totalDurationSecs - _elapsedSeconds);
    final progress = (_elapsedSeconds / totalDurationSecs).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      body: SafeArea(
        child: Stack(
          children: [
            // Background Ambient Glow
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                ),
              ),
            ),

            // Main Content Layout
            Column(
              children: [
                // Top Projector Header Bar
                _buildProjectorHeader(remainingSecs, progress),

                // Silence Banner (Active when teacher triggers bell)
                if (_isSilenceAlertActive) _buildSilenceAlertBanner(),

                // Center Content: Dual Cockpit Columns
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left: Giant QR Gate & Real-time Check-ins
                              Expanded(flex: 5, child: _buildQrGateSection()),
                              const SizedBox(width: 20),
                              // Right: Headcount HUD, Class Phase & Quick Dock
                              Expanded(flex: 4, child: _buildCockpitControlsSection()),
                            ],
                          );
                        } else {
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildQrGateSection(),
                                const SizedBox(height: 16),
                                _buildCockpitControlsSection(),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectorHeader(int remainingSecs, double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1626),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF0D9488).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Live Pulse Beacon & Title
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.25);
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(
                        alpha: 0.4 + (_pulseController.value * 0.4),
                      ),
                      blurRadius: 10 * scale,
                      spreadRadius: 2 * scale,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'وضع الحصة الذكي والبروجيكتور 📽️',
                    style: TextStyle(
                      color: Color(0xFF14B8A6),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.roomName,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.groupName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Session Duration & Progress Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF14B8A6)),
                        const SizedBox(width: 6),
                        Text(
                          'مضى: ${_formatDuration(_elapsedSeconds)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'متبقي: ${_formatDuration(remainingSecs)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                        strokeWidth: 3.5,
                      ),
                      Center(
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Attention Bell Button
          IconButton(
            tooltip: 'تنبيه الهدوء والانتباه في القاعة 🔔',
            style: IconButton.styleFrom(
              backgroundColor: _isSilenceAlertActive
                  ? Colors.amber
                  : Colors.white.withValues(alpha: 0.06),
              foregroundColor: _isSilenceAlertActive ? Colors.black : Colors.amber,
            ),
            icon: const Icon(Icons.notifications_active_rounded),
            onPressed: _triggerSilenceAlert,
          ),

          const SizedBox(width: 8),

          // Close / Exit Focus Mode Button
          IconButton(
            tooltip: 'الخروج من وضع البروجيكتور ❌',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              foregroundColor: Colors.white70,
            ),
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSilenceAlertBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.volume_off_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Text(
            'يرجى الانتباه والهدوء التام في القاعة مع المعلم 🤫 📢',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrGateSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section Title & Rotation Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.qr_code_2_rounded, color: Color(0xFF14B8A6), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'بوابة تسجيل الحضور التلقائي بالـ QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, color: Color(0xFF14B8A6), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'يتجدد بعد $_qrTimeRemaining ثانية 🔒',
                      style: const TextStyle(
                        color: Color(0xFF14B8A6),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // High-Contrast Projected QR Code
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _currentQrToken,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F172A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Instructions for Students in Hall
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'افتح تطبيق الطالب واضغط "مسح QR الدخول" من بطاقتك الرقمية لتأكيد تسجيلك في القاعة',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 14),

          // Live Ticker: Recent Check-ins
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'آخر المسجلين بالقاعة مباشرة:',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  if (_isLoadingAttendance)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14B8A6)),
                    )
                  else
                    const Text(
                      'مزامنة فورية ⚡',
                      style: TextStyle(color: Color(0xFF14B8A6), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_recentCheckIns.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF14B8A6), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'في انتظار مسح الطلاب للباركود لتسجيل الحضور الحي بالقاعة 📱',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentCheckIns.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = _recentCheckIns[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item['name']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${item['time']} • ${item['seat']}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitControlsSection() {
    final attendancePct = widget.totalStudents > 0
        ? ((_presentCount / widget.totalStudents) * 100).toStringAsFixed(1)
        : (_presentCount > 0 ? '100.0' : '0.0');

    return Column(
      children: [
        // Top Card: Headcount HUD
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'إحصائية الحضور الحالية بالقاعة',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text(
                    '$attendancePct% حضور',
                    style: const TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildHeadcountPill(
                      label: 'حاضرون',
                      value: '$_presentCount',
                      total: '${widget.totalStudents}',
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeadcountPill(
                      label: 'متغيبون',
                      value: '$_absentCount',
                      total: '${widget.totalStudents}',
                      color: const Color(0xFFEF4444),
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeadcountPill(
                      label: 'متأخرون',
                      value: '$_lateCount',
                      total: '${widget.totalStudents}',
                      color: const Color(0xFFF59E0B),
                      icon: Icons.access_time_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Phase Selector Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مرحلة الحصة الجارية الآن:',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ClassPhase.values.map((phase) {
                  final isSelected = _currentPhase == phase;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentPhase = phase);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? phase.color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? phase.color : Colors.white12,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        phase.label,
                        style: TextStyle(
                          color: isSelected ? phase.color : Colors.white70,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Quick Classroom Dock
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدوات التحكم التفاعلية المباشرة:',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      _buildProjectorActionButton(
                        title: 'فتح السبورة الذكية للشرح التفاعلي 🎨',
                        subtitle: 'رسم بياني، تصدير صفحات، وتدوين الملاحظات للطلاب',
                        color: Colors.teal,
                        icon: Icons.draw_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeacherSessionBoardScreen(
                                teacherId: widget.teacherId,
                                groupName: widget.groupName,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildProjectorActionButton(
                        title: 'إطلاق كويز الـ 5 دقائق التفاعلي ⚡',
                        subtitle: 'منافسة حية مع لوحة الشرف وأسرع الطلاب إجابة',
                        color: Colors.purple,
                        icon: Icons.bolt_rounded,
                        onTap: () {
                          LiveBlitzQuizDialog.show(
                            context,
                            groupName: widget.groupName,
                            subjectName: 'الفيزياء',
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildProjectorActionButton(
                        title: 'إذاعة تنبيه فوري للقاعة والمجموعة 📢',
                        subtitle: 'إشعار شاشات هواتف الطلاب الحاضرين في الحال',
                        color: Colors.amber.shade700,
                        icon: Icons.campaign_rounded,
                        onTap: () {
                          ClassBroadcastDialog.show(
                            context,
                            groupName: widget.groupName,
                            teacherName: widget.teacherName,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildProjectorActionButton(
                        title: 'إنذار فوري لأولياء أمور الغائبين ($_absentCount طلاب) 🚨',
                        subtitle: 'رسالة واتساب ونظام تنبيهات لولي الأمر بعدم التواجد',
                        color: const Color(0xFFDC2626),
                        icon: Icons.warning_amber_rounded,
                        onTap: () {
                          if (_absentCount == 0 && widget.absentStudents.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ممتاز! لا يوجد طلاب غائبين مسجلين لهذه الحصة 👏'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            return;
                          }
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text('إرسال إنذار غياب فوري', style: TextStyle(color: Colors.white)),
                              content: Text(
                                'سيتم إرسال إشعار فوري لـ $_absentCount أولياء أمور للطلاب الذين لم يمرروا الباركود حتى الآن في ${widget.groupName}.',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                  onPressed: () async {
                                    Navigator.pop(ctx);

                                    try {
                                      final client = Supabase.instance.client;
                                      for (final s in widget.absentStudents) {
                                        await client.from('notifications').insert({
                                          'title': 'تنبيه غياب فوري: ${widget.groupName}',
                                          'body': 'نحيطكم علماً بأن الطالب ${s['name']} لم يمرر الباركود في حصة اليوم بقاعة ${widget.roomName}.',
                                          'type': 'absence_alert',
                                          'created_at': DateTime.now().toIso8601String(),
                                        });

                                        final phone = s['phone'];
                                        if (phone != null && phone.isNotEmpty) {
                                          await WhatsAppService.sendAbsenceNotice(
                                            parentPhone: phone,
                                            studentName: s['name'] ?? 'الطالب',
                                            subjectName: widget.groupName,
                                            centerName: 'منظومة بريفيو التعليمية المتطورة',
                                            sessionDate: DateTime.now().toString().split(' ')[0],
                                          );
                                        }
                                      }
                                    } catch (_) {}

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم إرسال إشعارات الغياب الفورية في النظام بنجاح 🚨'),
                                          backgroundColor: Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('إرسال الإنذار الآن'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeadcountPill({
    required String label,
    required String value,
    required String total,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            'من أصل $total',
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectorActionButton({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.7), size: 12),
            ],
          ),
        ),
      ),
    );
  }
}
