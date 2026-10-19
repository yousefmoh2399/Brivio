import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/avatar_service.dart';
import '../../../../design_system/tokens/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Professional Avatar Studio — Asset-based, Offline-ready
//  Uses the 13 high-quality AI-generated character PNGs already bundled in app
//  + Snapchat-style UI: backdrop picker, frame picker, sticker badges
// ─────────────────────────────────────────────────────────────────────────────

typedef SnapchatAvatarStudioScreen = SnapAvatarStudioScreen;

// ── Data models ───────────────────────────────────────────────────────────────

class _CharacterAsset {
  final String id;
  final String assetPath;
  final String label;
  final String category;
  final String emoji;

  const _CharacterAsset({
    required this.id,
    required this.assetPath,
    required this.label,
    required this.category,
    required this.emoji,
  });
}

class _BackdropTheme {
  final String id;
  final String label;
  final List<Color> colors; // gradient stops
  final bool isDark;

  const _BackdropTheme({
    required this.id,
    required this.label,
    required this.colors,
    this.isDark = false,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );

  Color get primary => colors.first;
}

class _FrameStyle {
  final String id;
  final String label;
  final Color color;
  final bool hasGlow;
  final bool hasBorder;
  final bool isRainbow;
  final String emoji;

  const _FrameStyle({
    required this.id,
    required this.label,
    required this.color,
    this.hasGlow = false,
    this.hasBorder = true,
    this.isRainbow = false,
    required this.emoji,
  });
}

// ── Static catalog data ───────────────────────────────────────────────────────

const List<_CharacterAsset> _characters = [
  _CharacterAsset(id: 'snap_boy_curly',         assetPath: 'assets/avatars/snap_boy_curly.png',         label: 'طالب عصري',          category: 'طلاب',  emoji: '👦'),
  _CharacterAsset(id: 'snap_girl_hijab',         assetPath: 'assets/avatars/snap_girl_hijab.png',        label: 'طالبة بالحجاب',      category: 'طلاب',  emoji: '🧕'),
  _CharacterAsset(id: 'snap_girl_stylish',       assetPath: 'assets/avatars/snap_girl_stylish.png',      label: 'طالبة مبدعة',        category: 'طلاب',  emoji: '🎧'),
  _CharacterAsset(id: 'snap_boy_glasses',        assetPath: 'assets/avatars/snap_boy_glasses.png',       label: 'طالب متفوق',         category: 'طلاب',  emoji: '👓'),
  _CharacterAsset(id: 'snap_student_star',       assetPath: 'assets/avatars/snap_student_star.png',      label: 'خريج متميز',         category: 'طلاب',  emoji: '🎓'),
  _CharacterAsset(id: 'snap_teacher_male',       assetPath: 'assets/avatars/snap_teacher_male.png',      label: 'أستاذ قدير',         category: 'معلمون', emoji: '👨‍🏫'),
  _CharacterAsset(id: 'snap_teacher_female',     assetPath: 'assets/avatars/snap_teacher_female.png',    label: 'أستاذة أكاديمية',    category: 'معلمون', emoji: '👩‍🏫'),
  _CharacterAsset(id: 'snap_counselor_female',   assetPath: 'assets/avatars/snap_counselor_female.png',  label: 'أخصائية إرشاد',     category: 'معلمون', emoji: '📚'),
  _CharacterAsset(id: 'snap_executive_leader',   assetPath: 'assets/avatars/snap_executive_leader.png',  label: 'مدير تنفيذي',        category: 'إدارة', emoji: '👔'),
  _CharacterAsset(id: 'snap_doctor_scientist',   assetPath: 'assets/avatars/snap_doctor_scientist.png',  label: 'دكتور وعالم',        category: 'تخصصات', emoji: '🔬'),
  _CharacterAsset(id: 'snap_artist_creative',    assetPath: 'assets/avatars/snap_artist_creative.png',   label: 'فنان ومبدع',         category: 'تخصصات', emoji: '🎨'),
  _CharacterAsset(id: 'snap_athlete_sports',     assetPath: 'assets/avatars/snap_athlete_sports.png',    label: 'بطل رياضي',          category: 'تخصصات', emoji: '🏆'),
  _CharacterAsset(id: 'snap_cyber_hacker',       assetPath: 'assets/avatars/snap_cyber_hacker.png',      label: 'خبير تقنية',         category: 'تخصصات', emoji: '💻'),
];

const List<_BackdropTheme> _backdrops = [
  _BackdropTheme(id: 'sky',       label: 'سماوي',     colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF0369A1)]),
  _BackdropTheme(id: 'violet',    label: 'بنفسجي',    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED), Color(0xFF4C1D95)]),
  _BackdropTheme(id: 'rose',      label: 'وردي',      colors: [Color(0xFFFDA4AF), Color(0xFFF43F5E), Color(0xFF9F1239)]),
  _BackdropTheme(id: 'emerald',   label: 'زمردي',     colors: [Color(0xFF6EE7B7), Color(0xFF10B981), Color(0xFF064E3B)]),
  _BackdropTheme(id: 'gold',      label: 'ذهبي',      colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFF92400E)]),
  _BackdropTheme(id: 'ocean',     label: 'المحيط',    colors: [Color(0xFF67E8F9), Color(0xFF06B6D4), Color(0xFF164E63)]),
  _BackdropTheme(id: 'sunset',    label: 'الغروب',    colors: [Color(0xFFFED7AA), Color(0xFFF97316), Color(0xFF7C2D12)]),
  _BackdropTheme(id: 'night',     label: 'الليل',     colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)], isDark: true),
  _BackdropTheme(id: 'galaxy',    label: 'المجرة',    colors: [Color(0xFF4C1D95), Color(0xFF1E1B4B), Color(0xFF0C0A1A)], isDark: true),
  _BackdropTheme(id: 'forest',    label: 'الغابة',    colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF022C22)], isDark: true),
  _BackdropTheme(id: 'mint',      label: 'نعناعي',    colors: [Color(0xFFCCFBF1), Color(0xFF99F6E4), Color(0xFF5EEAD4)]),
  _BackdropTheme(id: 'pearl',     label: 'لؤلؤي',    colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0), Color(0xFFCBD5E1)]),
  _BackdropTheme(id: 'fire',      label: 'النار',     colors: [Color(0xFFFEF08A), Color(0xFFFB923C), Color(0xFFDC2626)]),
  _BackdropTheme(id: 'aurora',    label: 'الشفق',     colors: [Color(0xFF5EEAD4), Color(0xFF818CF8), Color(0xFFF472B6)]),
  _BackdropTheme(id: 'steel',     label: 'فولاذي',    colors: [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)], isDark: true),
  _BackdropTheme(id: 'lavender',  label: 'خزامى',    colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE), Color(0xFFC4B5FD)]),
];

const List<_FrameStyle> _frames = [
  _FrameStyle(id: 'none',      label: 'بدون',      color: Colors.transparent, hasBorder: false, emoji: '⭕'),
  _FrameStyle(id: 'white',     label: 'أبيض',      color: Colors.white,       hasGlow: false,   emoji: '⚪'),
  _FrameStyle(id: 'gold',      label: 'ذهبي ✨',   color: Color(0xFFF59E0B),  hasGlow: true,    emoji: '🏅'),
  _FrameStyle(id: 'blue',      label: 'أزرق',      color: Color(0xFF0EA5E9),  hasGlow: true,    emoji: '💙'),
  _FrameStyle(id: 'purple',    label: 'بنفسجي',    color: Color(0xFF8B5CF6),  hasGlow: true,    emoji: '💜'),
  _FrameStyle(id: 'rose',      label: 'وردي',      color: Color(0xFFEC4899),  hasGlow: true,    emoji: '🌸'),
  _FrameStyle(id: 'green',     label: 'أخضر',      color: Color(0xFF10B981),  hasGlow: true,    emoji: '💚'),
  _FrameStyle(id: 'fire',      label: 'ناري 🔥',   color: Color(0xFFEF4444),  hasGlow: true,    emoji: '🔥'),
  _FrameStyle(id: 'rainbow',   label: 'قوس قزح',   color: Colors.transparent, isRainbow: true,  emoji: '🌈'),
  _FrameStyle(id: 'dark',      label: 'أسود',      color: Color(0xFF0F172A),  hasGlow: false,   emoji: '🖤'),
];

const List<String> _badges = [
  'none', '⭐', '🎓', '🏆', '💎', '🔥', '👑', '✨',
  '🌟', '🎯', '💡', '🚀', '🎨', '⚡', '💪', '🧠',
];

// ── Main Widget ───────────────────────────────────────────────────────────────

class SnapAvatarStudioScreen extends StatefulWidget {
  final String? userId;
  final String? userEmail;
  final String? initialAvatarUrl;
  final Color roleColor;
  final ValueChanged<String>? onAvatarSaved;

  const SnapAvatarStudioScreen({
    super.key,
    this.userId,
    this.userEmail,
    this.initialAvatarUrl,
    this.roleColor = AppColors.primary,
    this.onAvatarSaved,
  });

  static Future<String?> open({
    required BuildContext context,
    String? userId,
    String? userEmail,
    String? initialAvatarUrl,
    Color roleColor = AppColors.primary,
    ValueChanged<String>? onAvatarSaved,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SnapAvatarStudioScreen(
          userId: userId,
          userEmail: userEmail,
          initialAvatarUrl: initialAvatarUrl,
          roleColor: roleColor,
          onAvatarSaved: onAvatarSaved,
        ),
      ),
    );
  }

  @override
  State<SnapAvatarStudioScreen> createState() => _SnapAvatarStudioScreenState();
}

// ── State ─────────────────────────────────────────────────────────────────────

class _SnapAvatarStudioScreenState extends State<SnapAvatarStudioScreen>
    with TickerProviderStateMixin {

  // Current selections
  _CharacterAsset _character = _characters[0];
  _BackdropTheme  _backdrop  = _backdrops[0];
  _FrameStyle     _frame     = _frames[2]; // gold by default
  String          _badge     = '⭐';
  String          _activeTab = 'character'; // 'character' | 'backdrop' | 'frame' | 'badge'

  bool _isSaving = false;

  // Animations
  late final AnimationController _floatCtrl;
  late final Animation<double>   _floatAnim;
  late final AnimationController _shimmerCtrl;
  late final Animation<double>   _shimmerAnim;
  late final AnimationController _selectCtrl;
  late final Animation<double>   _selectAnim;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOutSine));

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _selectCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _selectAnim = CurvedAnimation(parent: _selectCtrl, curve: Curves.elasticOut);

    _loadSaved();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _shimmerCtrl.dispose();
    _selectCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadSaved() async {
    if (widget.userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final charId    = prefs.getString('av_char_${widget.userId}');
      final backdropId = prefs.getString('av_bg_${widget.userId}');
      final frameId   = prefs.getString('av_frame_${widget.userId}');
      final badge     = prefs.getString('av_badge_${widget.userId}');

      if (!mounted) return;
      setState(() {
        if (charId != null)    _character = _characters.firstWhere((c) => c.id == charId,    orElse: () => _characters[0]);
        if (backdropId != null) _backdrop  = _backdrops.firstWhere((b) => b.id == backdropId, orElse: () => _backdrops[0]);
        if (frameId != null)   _frame     = _frames.firstWhere((f) => f.id == frameId,       orElse: () => _frames[2]);
        if (badge != null)     _badge     = badge;
      });
    } catch (_) {}
  }

  Future<void> _persistLocally() async {
    if (widget.userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('av_char_${widget.userId}',  _character.id);
      await prefs.setString('av_bg_${widget.userId}',    _backdrop.id);
      await prefs.setString('av_frame_${widget.userId}', _frame.id);
      await prefs.setString('av_badge_${widget.userId}', _badge);
    } catch (_) {}
  }

  // The saved "url" is the asset path — AvatarService already handles assets:// paths
  String get _avatarIdentifier => _character.assetPath;

  Future<void> _save() async {
    if (_isSaving) return;
    HapticFeedback.heavyImpact();
    setState(() => _isSaving = true);
    try {
      await _persistLocally();
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        await AvatarService.updateUserAvatar(
          userId: widget.userId!,
          newAvatarUrl: _avatarIdentifier,
          userEmail: widget.userEmail,
        );
      }
      if (!mounted) return;
      widget.onAvatarSaved?.call(_avatarIdentifier);
      _showSuccess();
      Navigator.of(context).pop(_avatarIdentifier);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        SizedBox(width: 10),
        Text('تم حفظ أفاتارك! ✨', style: TextStyle(fontWeight: FontWeight.bold)),
      ]),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _select<T>(T val, VoidCallback fn) {
    HapticFeedback.selectionClick();
    _selectCtrl.forward(from: 0);
    setState(fn);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size   = MediaQuery.of(context).size;
    final isWide = size.width >= 720;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        body: SafeArea(
          child: isWide
              ? _buildWideLayout(isDark)
              : _buildMobileLayout(isDark),
        ),
      ),
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────────────

  Widget _buildWideLayout(bool isDark) {
    return Row(
      children: [
        // Preview panel — 380px
        SizedBox(
          width: 380,
          child: Column(children: [
            _buildTopBar(isDark),
            Expanded(child: _buildPreviewStage(isDark)),
          ]),
        ),
        // Editor panel
        Expanded(child: Column(children: [
          _buildTabBar(isDark),
          Expanded(child: _buildTabContent(isDark)),
        ])),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Column(children: [
      _buildTopBar(isDark),
      // Preview — 38% height
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.38,
        child: _buildPreviewStage(isDark),
      ),
      // Editor tabs + content
      _buildTabBar(isDark),
      Expanded(child: _buildTabContent(isDark)),
    ]);
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(bool isDark) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Row(children: [
        // Close
        IconButton(
          icon: Icon(Icons.close_rounded,
              color: isDark ? Colors.white60 : Colors.black45, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),

        // Title chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              widget.roleColor,
              widget.roleColor.withValues(alpha: 0.75),
            ]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 13),
            SizedBox(width: 5),
            Text('استوديو الأفاتار',
                style: TextStyle(color: Colors.white, fontSize: 12.5,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        const Spacer(),

        // Randomize
        IconButton(
          tooltip: 'عشوائي 🎲',
          icon: const Icon(Icons.shuffle_rounded, color: AppColors.warning, size: 20),
          onPressed: () {
            final rnd = math.Random();
            setState(() {
              _character = _characters[rnd.nextInt(_characters.length)];
              _backdrop  = _backdrops[rnd.nextInt(_backdrops.length)];
              _frame     = _frames[rnd.nextInt(_frames.length)];
              _badge     = _badges[rnd.nextInt(_badges.length)];
            });
            HapticFeedback.mediumImpact();
          },
        ),

        // Save
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: widget.roleColor,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ ✨',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  // ── Preview stage ─────────────────────────────────────────────────────────

  Widget _buildPreviewStage(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated backdrop fills whole stage
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(gradient: _backdrop.gradient),
          width: double.infinity,
          height: double.infinity,
        ),

        // Decorative circles in backdrop
        ..._buildDecorativeCircles(),

        // Floating avatar card
        AnimatedBuilder(
          animation: _floatAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _floatAnim.value),
            child: child,
          ),
          child: _buildAvatarCard(),
        ),

        // Badge sticker (top-right of card)
        if (_badge != 'none')
          Positioned(
            top: _avatarCardTop() - 2,
            right: _avatarCardRight() - 2,
            child: _buildBadgeSticker(),
          ),
      ],
    );
  }

  double _avatarCardTop() {
    final h = MediaQuery.of(context).size.height * 0.38;
    return h * 0.09;
  }

  double _avatarCardRight() => 30;

  List<Widget> _buildDecorativeCircles() {
    final color = _backdrop.colors.last;
    return [
      Positioned(top: -40,    right: -40,   child: _circle(160, color, 0.2)),
      Positioned(bottom: -30, left: -30,    child: _circle(120, color, 0.15)),
      Positioned(top: 60,     left: 20,     child: _circle(40,  Colors.white, 0.07)),
      Positioned(bottom: 80,  right: 30,    child: _circle(24,  Colors.white, 0.06)),
    ];
  }

  Widget _circle(double size, Color color, double alpha) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: alpha),
    ),
  );

  Widget _buildAvatarCard() {
    final frameCol = _frame.color;
    final showBorder = _frame.hasBorder && !_frame.isRainbow;

    return AnimatedBuilder(
      animation: _selectAnim,
      builder: (_, child) {
        final scale = 1.0 + (_selectAnim.value * 0.04);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            // Depth shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
            // Glow from frame
            if (_frame.hasGlow && !_frame.isRainbow)
              BoxShadow(
                color: frameCol.withValues(alpha: 0.55),
                blurRadius: 24,
                spreadRadius: 4,
              ),
          ],
        ),
        child: Stack(
          children: [
            // Character image
            ClipOval(
              child: Image.asset(
                _character.assetPath,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _backdrop.primary.withValues(alpha: 0.3),
                  child: Center(
                    child: Text(_character.emoji,
                        style: const TextStyle(fontSize: 72)),
                  ),
                ),
              ),
            ),

            // Frame border overlay
            if (showBorder)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: frameCol,
                    width: 4.5,
                  ),
                ),
              ),

            // Rainbow frame overlay
            if (_frame.isRainbow)
              CustomPaint(
                size: const Size(200, 200),
                painter: _RainbowRingPainter(progress: _shimmerAnim),
              ),

            // Shimmer on gold frame
            if (_frame.id == 'gold')
              AnimatedBuilder(
                animation: _shimmerAnim,
                builder: (_, __) => ClipOval(
                  child: ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment(_shimmerAnim.value - 1, -1),
                      end: Alignment(_shimmerAnim.value, 1),
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ).createShader(rect),
                    child: Container(
                      width: 200,
                      height: 200,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeSticker() {
    return AnimatedScale(
      scale: _badge == 'none' ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.elasticOut,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(_badge, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  static const _tabs = [
    ('character', '🧑', 'الشخصية'),
    ('backdrop',  '🎨', 'الخلفية'),
    ('frame',     '💫', 'الإطار'),
    ('badge',     '⭐', 'الوسام'),
  ];

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 58,
      color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: _tabs.map((t) {
          final isActive = _activeTab == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = t.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? widget.roleColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isActive
                      ? [BoxShadow(
                          color: widget.roleColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3))]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.$2, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 1),
                    Text(
                      t.$3,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────

  Widget _buildTabContent(bool isDark) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0.03, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_activeTab),
        child: switch (_activeTab) {
          'character' => _buildCharacterTab(isDark),
          'backdrop'  => _buildBackdropTab(isDark),
          'frame'     => _buildFrameTab(isDark),
          'badge'     => _buildBadgeTab(isDark),
          _           => _buildCharacterTab(isDark),
        },
      ),
    );
  }

  // ── Character tab ─────────────────────────────────────────────────────────

  Widget _buildCharacterTab(bool isDark) {
    // Group by category
    final cats = <String, List<_CharacterAsset>>{};
    for (final c in _characters) {
      cats.putIfAbsent(c.category, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: cats.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 6),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: entry.value.map((char) =>
                _buildCharacterTile(char, isDark)).toList(),
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCharacterTile(_CharacterAsset char, bool isDark) {
    final isSelected = _character.id == char.id;
    return GestureDetector(
      onTap: () => _select(char, () => _character = char),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? widget.roleColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
          border: Border.all(
            color: isSelected ? widget.roleColor : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? widget.roleColor.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.07),
              blurRadius: isSelected ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Character image fills the tile
              Image.asset(
                char.assetPath,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(char.emoji,
                      style: const TextStyle(fontSize: 40)),
                ),
              ),

              // Bottom label strip
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent,
                        Colors.black.withValues(alpha: 0.7)],
                    ),
                  ),
                  child: Text(
                    char.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: widget.roleColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Backdrop tab ──────────────────────────────────────────────────────────

  Widget _buildBackdropTab(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.25,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _backdrops.length,
      itemBuilder: (_, i) {
        final bd = _backdrops[i];
        final isSelected = _backdrop.id == bd.id;
        return GestureDetector(
          onTap: () => _select(bd, () => _backdrop = bd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: bd.gradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? bd.primary.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.12),
                  blurRadius: isSelected ? 16 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  bd.label,
                  style: TextStyle(
                    color: bd.isDark ? Colors.white70 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 13, color: bd.primary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Frame tab ─────────────────────────────────────────────────────────────

  Widget _buildFrameTab(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _frames.length,
      itemBuilder: (_, i) {
        final fr = _frames[i];
        final isSelected = _frame.id == fr.id;
        return GestureDetector(
          onTap: () => _select(fr, () => _frame = fr),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? widget.roleColor : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? widget.roleColor.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: isSelected ? 12 : 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mini preview circle with frame
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: fr.hasBorder && !fr.isRainbow
                        ? Border.all(color: fr.color, width: 3.5)
                        : null,
                    boxShadow: fr.hasGlow && !fr.isRainbow
                        ? [BoxShadow(color: fr.color.withValues(alpha: 0.5), blurRadius: 10)]
                        : null,
                  ),
                  child: fr.isRainbow
                      ? CustomPaint(
                          painter: _RainbowRingPainter(progress: _shimmerAnim),
                          child: ClipOval(child: Container(color: Colors.grey.shade200)),
                        )
                      : ClipOval(
                          child: fr.id == 'none'
                              ? Center(child: Icon(Icons.block_rounded,
                                  color: Colors.grey.shade400, size: 22))
                              : const SizedBox.shrink(),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  fr.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? widget.roleColor
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Badge tab ─────────────────────────────────────────────────────────────

  Widget _buildBadgeTab(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _badges.length,
      itemBuilder: (_, i) {
        final b = _badges[i];
        final isSelected = _badge == b;
        return GestureDetector(
          onTap: () => _select(b, () => _badge = b),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isSelected
                  ? widget.roleColor.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? widget.roleColor : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? widget.roleColor.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.07),
                  blurRadius: isSelected ? 12 : 5,
                ),
              ],
            ),
            child: Center(
              child: b == 'none'
                  ? Icon(Icons.block_rounded,
                      color: isDark ? Colors.white30 : Colors.black26, size: 22)
                  : Text(b, style: const TextStyle(fontSize: 26)),
            ),
          ),
        );
      },
    );
  }
}

// ── Rainbow ring CustomPainter ────────────────────────────────────────────────

class _RainbowRingPainter extends CustomPainter {
  final Animation<double> progress;
  _RainbowRingPainter({required this.progress}) : super(repaint: progress);

  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFF06B6D4),
    Color(0xFF6366F1),
    Color(0xFFA855F7),
    Color(0xFFEF4444),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: _colors,
        startAngle: progress.value * 0.5,
        endAngle: progress.value * 0.5 + 2 * math.pi,
      ).createShader(rect);

    canvas.drawCircle(center, radius - 2.5, paint);
  }

  @override
  bool shouldRepaint(_RainbowRingPainter old) => true;
}
