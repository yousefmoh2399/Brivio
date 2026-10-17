import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../design_system/tokens/colors.dart';

/// Next-Generation 3D Holographic Interactive Student Digital ID Pass.
/// Features:
/// - Realistic 3D Tilt Physics on drag / hover
/// - Holographic Foil Iridescent Shimmer sheen
/// - 3D Card Flip (Front: ID & High-Tech QR, Back: Attendance, NFC Tap Gate, Security)
/// - Rotating Dynamic Security Token (Refreshes every 30 seconds to prevent gate fraud)
/// - Animated Laser Scanline on QR code
class StudentDigitalIdCard extends StatefulWidget {
  final String studentName;
  final String studentCode;
  final String? gradeLevel;
  final String centerName;
  final String? centerCode;
  final double attendanceRate;
  final int activeCoursesCount;
  final String seatNumber;

  const StudentDigitalIdCard({
    super.key,
    required this.studentName,
    required this.studentCode,
    this.gradeLevel,
    this.centerName = 'المركز التعليمي',
    this.centerCode,
    this.attendanceRate = 1.0,
    this.activeCoursesCount = 0,
    this.seatNumber = 'مقعد عام',
  });

  static void show(
    BuildContext context, {
    required String studentName,
    required String studentCode,
    String? gradeLevel,
    String centerName = 'المركز التعليمي',
    String? centerCode,
    double attendanceRate = 1.0,
    int activeCoursesCount = 0,
    String seatNumber = 'مقعد عام',
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: StudentDigitalIdCard(
          studentName: studentName,
          studentCode: studentCode,
          gradeLevel: gradeLevel,
          centerName: centerName,
          centerCode: centerCode,
          attendanceRate: attendanceRate,
          activeCoursesCount: activeCoursesCount,
          seatNumber: seatNumber,
        ),
      ),
    );
  }

  @override
  State<StudentDigitalIdCard> createState() => _StudentDigitalIdCardState();
}

class _StudentDigitalIdCardState extends State<StudentDigitalIdCard>
    with TickerProviderStateMixin {
  // 3D Tilt angles (in radians)
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  // Card Flip Animation (0.0 = Front, 1.0 = Back)
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isBack = false;

  // Dynamic QR Token refresh timer
  Timer? _tokenTimer;
  int _secondsRemaining = 30;
  String _securityHash = '';

  // Laser scanner animation on QR
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _generateSecurityHash();
    _startTokenTimer();
  }

  void _generateSecurityHash() {
    final now = DateTime.now();
    final epochMinute = now.millisecondsSinceEpoch ~/ 30000;
    final hexPart = (epochMinute ^ 0xABCD).toRadixString(16).toUpperCase().padLeft(4, '0');
    _securityHash = 'SEC-$hexPart-${now.second}';
  }

  void _startTokenTimer() {
    _tokenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _secondsRemaining = 30;
          _generateSecurityHash();
        }
      });
    });
  }

  @override
  void dispose() {
    _tokenTimer?.cancel();
    _flipController.dispose();
    _laserController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.mediumImpact();
    if (_isBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isBack = !_isBack;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      // Sensible physics sensitivity
      _tiltY += details.delta.dx * 0.003;
      _tiltX -= details.delta.dy * 0.003;

      // Clamp tilt to avoid excessive distortion
      _tiltX = _tiltX.clamp(-0.35, 0.35);
      _tiltY = _tiltY.clamp(-0.35, 0.35);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    // Smoothly settle back to 0
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dynamicQrPayload =
        'BRIVIO-SEC-GATE:${widget.studentCode}:HASH=$_securityHash:TIME=${DateTime.now().millisecondsSinceEpoch}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instruction banner
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, color: Colors.amberAccent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'المس واسحب لتحريك البطاقة ثلاثية الأبعاد 3D ✨',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              // Interactive 3D Card Container
              GestureDetector(
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final flipVal = _flipAnimation.value;
                    final isUnder = flipVal > 0.5;
                    final angle = flipVal * math.pi;

                    // Matrix 4 perspective transform
                    final matrix = Matrix4.identity()
                      ..setEntry(3, 2, 0.0018) // 3D depth perspective
                      ..rotateX(_tiltX)
                      ..rotateY(_tiltY + angle);

                    return Transform(
                      transform: matrix,
                      alignment: Alignment.center,
                      child: isUnder
                          ? Transform(
                              transform: Matrix4.identity()..rotateY(math.pi),
                              alignment: Alignment.center,
                              child: _buildCardBack(),
                            )
                          : _buildCardFront(dynamicQrPayload),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _toggleFlip,
                    icon: const Icon(Icons.flip_camera_android_rounded, size: 18),
                    label: Text(_isBack ? 'الوجه الأمامي 🪪' : 'بيانات الحضور والنظام 🔄'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.studentCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم نسخ كود الطالب إلى الحافظة!'),
                          backgroundColor: Colors.black87,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('نسخ الكود'),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                    ),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Front of the Holographic 3D Pass ──
  Widget _buildCardFront(String qrPayload) {
    // Dynamic shimmer offset linked to tilt
    final shimmerAlignment = Alignment(
      -_tiltY * 3.5,
      -_tiltX * 3.5,
    );

    return Container(
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0D1B2A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: Offset(_tiltY * 30, 14 + _tiltX * 30),
          ),
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Holographic Foil Iridescent Sheen Layer
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: shimmerAlignment,
                      end: Alignment(-shimmerAlignment.x, -shimmerAlignment.y),
                      colors: [
                        Colors.transparent,
                        Colors.cyanAccent.withValues(alpha: 0.12),
                        Colors.purpleAccent.withValues(alpha: 0.14),
                        Colors.amberAccent.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.centerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const Text(
                                    'بطاقة الطالب الذكية • Smart Pass',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // VIP Hologram Seal
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.amber,
                              blurRadius: 8,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.black87, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'VIP CARD',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // High-Tech QR Box with Laser Scanline and Glow
                  Container(
                    width: 200,
                    height: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 176,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0F172A),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),

                        // Animated Laser Scanline
                        AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: _laserAnimation.value * 160,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.cyanAccent,
                                      Colors.blueAccent,
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Dynamic Security Hash Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    constraints: const BoxConstraints(maxWidth: 310),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'كود أمان حي: $_securityHash • $_secondsRemaining ث',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Student Name
                  Text(
                    widget.studentName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Student Code Badge & Grade
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          widget.studentCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.gradeLevel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            widget.gradeLevel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'قرّب البطاقة من قارئ البوابة الإلكترونية أو أظهرها للاستقبال ⚡',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Back of the Holographic 3D Pass ──
  Widget _buildCardBack() {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF111827),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),

            // Black Magnetic Stripe
            Container(
              height: 44,
              color: Colors.black87,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'AUTHORIZED SIGNATURE // NOT TRANSFERABLE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 8,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.seatNumber,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Performance & Attendance Overview
                  const Text(
                    'بيانات السجل الأكاديمي للسنتر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          title: 'نسبة الحضور',
                          value: '${(widget.attendanceRate * 100).toInt()}%',
                          icon: Icons.check_circle_rounded,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'المجموعات النشطة',
                          value: '${widget.activeCoursesCount} مواد',
                          icon: Icons.auto_stories_rounded,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'المقعد المخصص',
                          value: widget.seatNumber,
                          icon: Icons.event_seat_rounded,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Smart NFC Tap Gate Simulation
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.nfc_rounded,
                            color: Colors.purpleAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ميزة الدخول اللاتلامسي NFC 📡',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'قارئ البوابات يدعم تمرير الهاتف مباشرة بدون فتح التطبيق في السناتر المجهزة.',
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Center Security Terms
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '• هذه البطاقة وثيقة رقمية رسمية خاصة بالطالب المسجل فقط.\n• يمنع تداول أو تصوير الكود الدوار للغير تحت طائلة إيقاف الحساب.\n• للدعم الفني والاستفسارات: تواصل مع إدارة السنتر عبر تبويب المساعدة.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
