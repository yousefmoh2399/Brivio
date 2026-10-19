import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/avatar_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../domain/models/bitmoji_traits.dart';
import '../painters/bitmoji_vector_library.dart';
import '../widgets/bitmoji_renderer.dart';
import '../widgets/bitmoji_stickers_sheet.dart';

/// Full-featured, commercial-grade Snapchat Bitmoji 3D Studio 2.0.
/// Features true 3D interactive gesture orbit rotation, 360° auto-spin turntable,
/// real-time 3D perspective vector rendering (100% reactive traits, zero static image locks),
/// transparent background export mode, visual trait selector, and high-res PNG exporter.
class SnapchatAvatarStudioScreen extends StatefulWidget {
  final String? userId;
  final String? userEmail;
  final String? initialAvatarUrl;
  final Color roleColor;
  final ValueChanged<String>? onAvatarSaved;

  const SnapchatAvatarStudioScreen({
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
        builder: (_) => SnapchatAvatarStudioScreen(
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
  State<SnapchatAvatarStudioScreen> createState() =>
      _SnapchatAvatarStudioScreenState();
}

class _SnapchatAvatarStudioScreenState
    extends State<SnapchatAvatarStudioScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  late BitmojiTraits _traits;
  AvatarCameraFocus _cameraFocus = AvatarCameraFocus.fullBody;
  AvatarCustomizationSection _currentSection =
      AvatarCustomizationSection.style;
  bool _isSaving = false;
  String _styleCategoryFilter = 'all';

  // 3D Orbit & Perspective Controls
  double _rotationY = 0.0;
  double _pitchX = 0.0;
  bool _isAutoRotating = false;
  Timer? _autoRotateTimer;
  bool _isTransparentMode = false;

  @override
  void initState() {
    super.initState();
    _traits = BitmojiTraits(
      seed: widget.userId ?? 'Hero_${DateTime.now().millisecondsSinceEpoch}',
      characterAsset: null, // Always start with dynamic live vectors
    );
    _loadSavedTraits();
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedTraits() async {
    if (widget.userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'brivio_bitmoji_traits_${widget.userId}';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        setState(() {
          _traits = BitmojiTraits.fromJson(map).copyWith(characterAsset: null);
          _isTransparentMode = _traits.isTransparent;
        });
      }
    } catch (_) {}
  }

  Future<void> _persistTraitsLocally() async {
    if (widget.userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'brivio_bitmoji_traits_${widget.userId}';
      await prefs.setString(key, jsonEncode(_traits.toJson()));
    } catch (_) {}
  }

  void _toggleCameraFocus() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_cameraFocus == AvatarCameraFocus.fullBody) {
        _cameraFocus = AvatarCameraFocus.face;
      } else if (_cameraFocus == AvatarCameraFocus.face) {
        _cameraFocus = AvatarCameraFocus.bust;
      } else {
        _cameraFocus = AvatarCameraFocus.fullBody;
      }
    });
  }

  void _toggleAutoRotate() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAutoRotating = !_isAutoRotating;
      if (_isAutoRotating) {
        _autoRotateTimer?.cancel();
        _autoRotateTimer = Timer.periodic(const Duration(milliseconds: 32), (_) {
          if (!mounted) return;
          setState(() {
            _rotationY = (_rotationY + 0.035) % (2 * math.pi);
          });
        });
      } else {
        _autoRotateTimer?.cancel();
      }
    });
  }

  void _setAngle(double angleRadians) {
    HapticFeedback.selectionClick();
    if (_isAutoRotating) {
      _isAutoRotating = false;
      _autoRotateTimer?.cancel();
    }
    setState(() {
      _rotationY = angleRadians;
      _pitchX = 0.0;
    });
  }

  void _toggleTransparentMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _isTransparentMode = !_isTransparentMode;
      _traits = _traits.copyWith(isTransparent: _isTransparentMode);
    });
  }

  void _randomize() {
    HapticFeedback.mediumImpact();
    final rnd = DateTime.now().millisecondsSinceEpoch;
    final skins = BitmojiTraits.skinPalette;
    final hairs = BitmojiTraits.hairPalette;
    final outfits = BitmojiTraits.outfitPalette;
    final bgs = BitmojiTraits.backgroundPalette;

    final hairStyles = [
      'short_curly',
      'fade_crop',
      'slick_back',
      'long_wavy',
      'buzz_cut',
      'hijab_wrapped',
      'bob',
      'bun',
      'dreads',
      'hat',
    ];
    final eyeStyles = [
      'happy_curved',
      'focused_round',
      'confident_almond',
      'winking',
      'heart_eyes',
    ];
    final mouths = [
      'warm_smile',
      'confident_smirk',
      'wide_grin',
      'neutral',
      'playful_tongue',
    ];
    final beards = ['none', 'stubble', 'trimmed_beard', 'mustache'];
    final glasses = ['none', 'square_frames', 'round_frames', 'wayfarers', 'sunglasses'];
    final clothes = [
      'hoodie',
      'formal_blazer',
      'casual_crew',
      'polo',
      'athletic',
      'lab_coat',
    ];
    final pedestals = [
      'neon_disc',
      'royal_gold',
      'emerald_crystal',
      'obsidian_holo',
      'floating_halo',
    ];
    final badges = [
      null,
      'top_honor',
      'star_achiever',
      'math_genius',
      'student_leader',
      'researcher',
      'creative',
    ];

    final isFemale = (rnd % 2 == 1);

    setState(() {
      _traits = _traits.copyWith(
        seed: 'Seed_$rnd',
        characterAsset: null, // Always keep dynamic vectors live
        gender: isFemale ? 'female' : 'male',
        skinColor: skins[rnd % skins.length],
        hairColor: hairs[(rnd ~/ 2) % hairs.length],
        outfitColor: outfits[(rnd ~/ 3) % outfits.length],
        backgroundColor: bgs[(rnd ~/ 4) % bgs.length],
        hairStyle: isFemale && (rnd % 3 == 0)
            ? 'hijab_wrapped'
            : hairStyles[(rnd ~/ 5) % hairStyles.length],
        headwear: isFemale && (rnd % 3 == 0) ? 'hijab' : 'none',
        eyes: eyeStyles[(rnd ~/ 6) % eyeStyles.length],
        mouth: mouths[(rnd ~/ 7) % mouths.length],
        facialHair: isFemale ? 'none' : beards[(rnd ~/ 8) % beards.length],
        eyewear: glasses[(rnd ~/ 9) % glasses.length],
        outfit: clothes[(rnd ~/ 10) % clothes.length],
        pedestalStyle: pedestals[(rnd ~/ 11) % pedestals.length],
        honorBadge: badges[(rnd ~/ 12) % badges.length],
      );
    });
  }

  Future<void> _saveAvatar() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      // 1. Capture high-res PNG bytes directly from live vector Canvas RepaintBoundary
      final Uint8List? pngBytes = await BitmojiRenderer.capturePng(
        _repaintKey,
        pixelRatio: 3.0,
      );

      String finalAvatarUrl = '';
      if (pngBytes != null && pngBytes.isNotEmpty) {
        final filename =
            'bitmoji_${widget.userId ?? "user"}_${DateTime.now().millisecondsSinceEpoch}.png';

        // 2. Upload to Supabase Storage or fallback to base64 Data URI
        final uploadedUrl = await AvatarService.uploadAvatar(
          bytes: pngBytes,
          filename: filename,
          userId: widget.userId,
        );
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          finalAvatarUrl = uploadedUrl;
        }
      }

      // Fallback to image url if png capture was unavailable
      if (finalAvatarUrl.isEmpty) {
        finalAvatarUrl = _traits.toImageUrl(size: 512, includeBackground: !_isTransparentMode);
      }

      // 3. Persist traits configuration locally
      await _persistTraitsLocally();

      // 4. Update user profile and saved accounts
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        await AvatarService.updateUserAvatar(
          userId: widget.userId!,
          newAvatarUrl: finalAvatarUrl,
          userEmail: widget.userEmail,
        );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      widget.onAvatarSaved?.call(finalAvatarUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'تم حفظ وتطبيق الأفاتار ثلاثي الأبعاد بنجاح! ✨',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(finalAvatarUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ الأفاتار: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Archetype preset mapper that sets real live vector traits
  BitmojiTraits _getArchetypeTraits(String id) {
    return switch (id) {
      'snap_boy_curly' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'short_curly',
        hairColor: const Color(0xFF2C1B18),
        skinColor: const Color(0xFFF3C7A8),
        outfit: 'hoodie',
        outfitColor: const Color(0xFF0EA5E9),
        outfitAccentColor: const Color(0xFF38BDF8),
        eyewear: 'none',
        headwear: 'none',
        characterAsset: null,
      ),
      'snap_girl_hijab' => _traits.copyWith(
        gender: 'female',
        hairStyle: 'hijab_wrapped',
        headwear: 'hijab',
        headwearColor: const Color(0xFF8B5CF6),
        skinColor: const Color(0xFFF5D0C5),
        outfit: 'formal_blazer',
        outfitColor: const Color(0xFF6366F1),
        outfitAccentColor: const Color(0xFFA855F7),
        eyewear: 'none',
        characterAsset: null,
      ),
      'snap_student_star' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'short_curly',
        headwear: 'graduation_cap',
        headwearColor: const Color(0xFF0F172A),
        outfit: 'graduation_gown',
        outfitColor: const Color(0xFF1E3A8A),
        outfitAccentColor: const Color(0xFFF59E0B),
        honorBadge: 'top_honor',
        characterAsset: null,
      ),
      'snap_girl_stylish' => _traits.copyWith(
        gender: 'female',
        hairStyle: 'long_wavy',
        hairColor: const Color(0xFF831843),
        headwear: 'headphones',
        headwearColor: const Color(0xFFEC4899),
        outfit: 'hoodie',
        outfitColor: const Color(0xFFF43F5E),
        outfitAccentColor: const Color(0xFFFDA4AF),
        eyewear: 'none',
        characterAsset: null,
      ),
      'snap_boy_glasses' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'fade_crop',
        hairColor: const Color(0xFF18181B),
        eyewear: 'square_frames',
        eyewearColor: const Color(0xFF0F172A),
        outfit: 'polo',
        outfitColor: const Color(0xFF059669),
        outfitAccentColor: const Color(0xFF34D399),
        headwear: 'none',
        characterAsset: null,
      ),
      'snap_cyber_hacker' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'spiky',
        hairColor: const Color(0xFF06B6D4),
        eyewear: 'cyber_visor',
        eyewearColor: const Color(0xFF06B6D4),
        outfit: 'hoodie',
        outfitColor: const Color(0xFF0F172A),
        outfitAccentColor: const Color(0xFF06B6D4),
        headwear: 'none',
        characterAsset: null,
      ),
      'snap_athlete_sports' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'buzz_cut',
        outfit: 'athletic',
        outfitColor: const Color(0xFFDC2626),
        outfitAccentColor: Colors.white,
        eyewear: 'none',
        headwear: 'none',
        characterAsset: null,
      ),
      'snap_artist_creative' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'slick_back',
        hairColor: const Color(0xFFB45309),
        headwear: 'beret',
        headwearColor: const Color(0xFF475569),
        outfit: 'hoodie',
        outfitColor: const Color(0xFFF59E0B),
        outfitAccentColor: const Color(0xFFFDE68A),
        characterAsset: null,
      ),
      'snap_doctor_scientist' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'slick_back',
        outfit: 'lab_coat',
        outfitColor: Colors.white,
        outfitAccentColor: const Color(0xFF0284C7),
        eyewear: 'round_frames',
        eyewearColor: const Color(0xFF334155),
        headwear: 'none',
        characterAsset: null,
      ),
      'snap_teacher_male' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'slick_back',
        facialHair: 'trimmed_beard',
        facialHairColor: const Color(0xFF2C1B18),
        outfit: 'formal_blazer',
        outfitColor: const Color(0xFF1E293B),
        outfitAccentColor: const Color(0xFFDC2626),
        eyewear: 'square_frames',
        headwear: 'none',
        characterAsset: null,
      ),
      'snap_teacher_female' => _traits.copyWith(
        gender: 'female',
        hairStyle: 'bob',
        hairColor: const Color(0xFF451A03),
        outfit: 'formal_blazer',
        outfitColor: const Color(0xFF4F46E5),
        outfitAccentColor: const Color(0xFFA855F7),
        eyewear: 'cat_eye',
        eyewearColor: const Color(0xFF7C3AED),
        headwear: 'none',
        characterAsset: null,
      ),
      'snap_counselor_female' => _traits.copyWith(
        gender: 'female',
        hairStyle: 'long_wavy',
        hairColor: const Color(0xFF1C1917),
        outfit: 'formal_blazer',
        outfitColor: const Color(0xFF0D9488),
        outfitAccentColor: const Color(0xFF5EEAD4),
        eyewear: 'round_frames',
        eyewearColor: const Color(0xFF0D9488),
        characterAsset: null,
      ),
      'snap_executive_leader' => _traits.copyWith(
        gender: 'male',
        hairStyle: 'fade_crop',
        facialHair: 'full_beard',
        facialHairColor: const Color(0xFF18181B),
        outfit: 'formal_blazer',
        outfitColor: const Color(0xFF0F172A),
        outfitAccentColor: const Color(0xFFEAB308),
        characterAsset: null,
      ),
      _ => _traits.copyWith(characterAsset: null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isWide = screenWidth >= 780;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF030712) : const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0.5,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'استوديو الأفاتار (Bitmoji 3D)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                ),
              ],
            ),
            actions: [
              // Stickers sheet button
              IconButton(
                tooltip: 'ملصقات شخصيتك 🎭',
                icon: const Icon(Icons.emoji_emotions_rounded, color: Color(0xFF8B5CF6)),
                onPressed: () {
                  BitmojiStickersSheet.show(
                    context,
                    traits: _traits,
                    onApplyStickerExpression: (updated) {
                      setState(() => _traits = updated.copyWith(characterAsset: null));
                    },
                  );
                },
              ),

              // Randomizer dice
              IconButton(
                tooltip: 'توليد شخصية عشوائية 🎲',
                icon: const Icon(Icons.casino_rounded, color: AppColors.warning),
                onPressed: _randomize,
              ),

              // Save & Apply Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.roleColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: _isSaving ? null : _saveAvatar,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'حفظ ✨',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
          body: isWide
              // Desktop / Tablet 2-Pane Side-by-Side Studio Layout
              ? Row(
                  children: [
                    // Left Pane: 3D Stage Viewport
                    SizedBox(
                      width: (screenWidth * 0.42).clamp(360.0, 480.0),
                      child: _buildStageViewport(cardColor, textPrimary, isDark),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    // Right Pane: Customization Tray & Ribbon
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionRibbon(cardColor, isDark),
                          Expanded(
                            child: Container(
                              color: cardColor,
                              child: _buildSectionContent(screenWidth, isWide: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              // Mobile Vertical Stack Layout
              : Column(
                  children: [
                    // Top: 3D Stage Viewport
                    Expanded(
                      flex: 5,
                      child: _buildStageViewport(cardColor, textPrimary, isDark),
                    ),
                    // Middle: Category Tabs Ribbon
                    _buildSectionRibbon(cardColor, isDark),
                    // Bottom: Customization Tray
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: cardColor,
                        child: _buildSectionContent(screenWidth, isWide: false),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ==========================================
  // Stage Viewport Component (Live 3D Gesture Orbit)
  // ==========================================
  Widget _buildStageViewport(Color cardColor, Color textPrimary, bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 3D Vector Stage with Interactive Gesture Orbit
        Container(
          width: double.infinity,
          height: double.infinity,
          color: _isTransparentMode
              ? Colors.transparent
              : _traits.backgroundColor.withValues(alpha: 0.15),
          child: Center(
            child: BitmojiRenderer(
              traits: _traits,
              cameraFocus: _cameraFocus,
              repaintKey: _repaintKey,
              isAnimated: true,
              showPedestal: !_isTransparentMode,
              rotationY: _rotationY,
              pitchX: _pitchX,
              isTransparent: _isTransparentMode,
              isInteractive: true,
              onRotationChanged: (val) => setState(() => _rotationY = val),
              onPitchChanged: (val) => setState(() => _pitchX = val),
            ),
          ),
        ),

        // 1. Top Left: Background Mode Toggle (Studio vs Transparent)
        Positioned(
          top: 14,
          left: 14,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _toggleTransparentMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.roleColor.withValues(alpha: 0.35),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isTransparentMode
                        ? Icons.check_box_outline_blank_rounded
                        : Icons.wb_sunny_rounded,
                    size: 14,
                    color: widget.roleColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isTransparentMode ? 'خلفية شفافة 🏁' : 'استوديو 🌟',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Top Right: Floating Camera Switcher Pill
        Positioned(
          top: 14,
          right: 14,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _toggleCameraFocus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.roleColor.withValues(alpha: 0.4),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _cameraFocus == AvatarCameraFocus.face
                        ? Icons.person_rounded
                        : (_cameraFocus == AvatarCameraFocus.bust
                            ? Icons.accessibility_new_rounded
                            : Icons.face_rounded),
                    size: 16,
                    color: widget.roleColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _cameraFocus == AvatarCameraFocus.face
                        ? 'عرض الجسم كامل'
                        : (_cameraFocus == AvatarCameraFocus.bust
                            ? 'عرض المنصة 🕺'
                            : 'تكبير الوجه'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. Bottom Left: 360 Turntable Auto-Rotate Button
        Positioned(
          bottom: 12,
          left: 14,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _toggleAutoRotate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isAutoRotating
                    ? widget.roleColor
                    : cardColor.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.roleColor.withValues(alpha: 0.4),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.threesixty_rounded,
                    size: 15,
                    color: _isAutoRotating ? Colors.white : widget.roleColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isAutoRotating ? 'إيقاف الدوران' : 'دوران 360°',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _isAutoRotating ? Colors.white : textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. Bottom Center: 3D Angle Presets Pill
        Positioned(
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAngleBtn('أمام 0°', 0.0),
                _buildAngleBtn('35°', 0.61),
                _buildAngleBtn('90°', math.pi / 2),
                _buildAngleBtn('خلف 180°', math.pi),
              ],
            ),
          ),
        ),

        // 5. Floating Sticker Pack Quick Pill (Bottom Right)
        Positioned(
          bottom: 12,
          right: 14,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              BitmojiStickersSheet.show(
                context,
                traits: _traits,
                onApplyStickerExpression: (updated) {
                  setState(() => _traits = updated.copyWith(characterAsset: null));
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✨', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 4),
                  Text(
                    'ملصقات Bitmoji',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAngleBtn(String label, double radians) {
    final isSelected = (_rotationY - radians).abs() < 0.15;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _setAngle(radians),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? widget.roleColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Section Ribbon Bar
  // ==========================================
  Widget _buildSectionRibbon(Color cardColor, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.8,
          ),
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.8,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _buildSectionTab(AvatarCustomizationSection.style, 'النمط', Icons.auto_awesome_rounded),
          _buildSectionTab(AvatarCustomizationSection.genderBody, 'الجنس', Icons.wc_rounded),
          _buildSectionTab(AvatarCustomizationSection.skinTone, 'البشرة', Icons.face_rounded),
          _buildSectionTab(AvatarCustomizationSection.hairStyle, 'الشعر', Icons.content_cut_rounded),
          _buildSectionTab(AvatarCustomizationSection.pedestal, 'المنصة', Icons.album_rounded),
          _buildSectionTab(AvatarCustomizationSection.honorBadge, 'الأوسمة', Icons.military_tech_rounded),
          _buildSectionTab(AvatarCustomizationSection.headwear, 'الحجاب', Icons.dry_cleaning_rounded),
          _buildSectionTab(AvatarCustomizationSection.outfit, 'الملابس', Icons.checkroom_rounded),
          _buildSectionTab(AvatarCustomizationSection.hairColor, 'لون الشعر', Icons.format_paint_rounded),
          _buildSectionTab(AvatarCustomizationSection.eyes, 'العيون', Icons.remove_red_eye_rounded),
          _buildSectionTab(AvatarCustomizationSection.eyewear, 'النظارات', Icons.visibility_rounded),
          _buildSectionTab(AvatarCustomizationSection.mouth, 'التعبيرات', Icons.mood_rounded),
          _buildSectionTab(AvatarCustomizationSection.facialHair, 'اللحية', Icons.face_retouching_natural_rounded),
          _buildSectionTab(AvatarCustomizationSection.background, 'الاستوديو', Icons.wallpaper_rounded),
        ],
      ),
    );
  }

  Widget _buildSectionTab(
    AvatarCustomizationSection section,
    String title,
    IconData icon,
  ) {
    final isSelected = _currentSection == section;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _currentSection = section;
              if (section == AvatarCustomizationSection.outfit ||
                  section == AvatarCustomizationSection.genderBody ||
                  section == AvatarCustomizationSection.style ||
                  section == AvatarCustomizationSection.pedestal) {
                _cameraFocus = AvatarCameraFocus.fullBody;
              } else if (section == AvatarCustomizationSection.honorBadge) {
                _cameraFocus = AvatarCameraFocus.bust;
              } else {
                _cameraFocus = AvatarCameraFocus.face;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        widget.roleColor,
                        widget.roleColor.withValues(alpha: 0.85),
                      ],
                    )
                  : null,
              color: isSelected
                  ? null
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.035)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                width: 0.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: widget.roleColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Section Content Tray
  // ==========================================
  Widget _buildSectionContent(double screenWidth, {required bool isWide}) {
    final int defaultCols = isWide
        ? (screenWidth >= 1100 ? 5 : 4)
        : (screenWidth < 360 ? 3 : 4);

    switch (_currentSection) {
      case AvatarCustomizationSection.style:
        final allModels = const [
          {
            'id': 'snap_boy_curly',
            'title': 'طالب كيرلي 👦',
            'category': 'student',
          },
          {
            'id': 'snap_girl_hijab',
            'title': 'طالبة بالحجاب 🧕',
            'category': 'student',
          },
          {
            'id': 'snap_student_star',
            'title': 'خريج متفوق 🎓',
            'category': 'student',
          },
          {
            'id': 'snap_girl_stylish',
            'title': 'طالبة مبدعة 🎧',
            'category': 'student',
          },
          {
            'id': 'snap_boy_glasses',
            'title': 'طالب بنظارات 👓',
            'category': 'student',
          },
          {
            'id': 'snap_cyber_hacker',
            'title': 'طالب تكنولوجيا 💻',
            'category': 'student,talent',
          },
          {
            'id': 'snap_athlete_sports',
            'title': 'طالب رياضي 🏆',
            'category': 'student,talent',
          },
          {
            'id': 'snap_artist_creative',
            'title': 'فنان ومصمم 🎨',
            'category': 'student,talent',
          },
          {
            'id': 'snap_doctor_scientist',
            'title': 'باحث علمي 🔬',
            'category': 'teacher,talent',
          },
          {
            'id': 'snap_teacher_male',
            'title': 'أستاذ موجه 👨‍🏫',
            'category': 'teacher',
          },
          {
            'id': 'snap_teacher_female',
            'title': 'أستاذة قديرة 👩‍🏫',
            'category': 'teacher',
          },
          {
            'id': 'snap_counselor_female',
            'title': 'أخصائية إرشاد 📚',
            'category': 'teacher',
          },
          {
            'id': 'snap_executive_leader',
            'title': 'مدير المنظومة 👨‍💼',
            'category': 'admin',
          },
        ];

        final filteredModels = allModels.where((m) {
          if (_styleCategoryFilter == 'all') return true;
          return m['category']!.contains(_styleCategoryFilter);
        }).toList();

        return Column(
          children: [
            _buildStyleCategoryFilters(),
            Expanded(
              child: _buildVisualGrid(
                options: filteredModels,
                selectedId: '',
                crossAxisCount: defaultCols,
                childAspectRatio: 0.90,
                previewTraitsBuilder: (id) => _getArchetypeTraits(id),
                onSelected: (id) {
                  final newTraits = _getArchetypeTraits(id);
                  setState(() => _traits = newTraits);
                },
              ),
            ),
          ],
        );

      case AvatarCustomizationSection.pedestal:
        return _buildPedestalSelector(isWide: isWide);

      case AvatarCustomizationSection.honorBadge:
        return _buildHonorBadgeSelector(isWide: isWide);

      case AvatarCustomizationSection.genderBody:
        return _buildGenderSelector();

      case AvatarCustomizationSection.skinTone:
        return _buildColorGrid(
          colors: BitmojiTraits.skinPalette,
          selected: _traits.skinColor,
          onChanged: (c) =>
              setState(() => _traits = _traits.copyWith(skinColor: c, characterAsset: null)),
        );

      case AvatarCustomizationSection.hairStyle:
        return _buildVisualGrid(
          options: const [
            {'id': 'short_curly', 'title': 'كيرلي عصري 👦'},
            {'id': 'fade_crop', 'title': 'تدريج فيد 💈'},
            {'id': 'slick_back', 'title': 'كلاسيك ✂️'},
            {'id': 'long_wavy', 'title': 'طويل مموج 💁‍♀️'},
            {'id': 'buzz_cut', 'title': 'قصيرة رياضي 👨'},
            {'id': 'hijab_wrapped', 'title': 'حجاب إسلامي 🧕'},
            {'id': 'bob', 'title': 'بوب عصري 💇‍♀️'},
            {'id': 'bun', 'title': 'كعكة 👱‍♀️'},
            {'id': 'dreads', 'title': 'جدائل دريدز 🧔'},
            {'id': 'hat', 'title': 'قبعة 🧢'},
          ],
          selectedId: _traits.hairStyle,
          crossAxisCount: defaultCols,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(
            hairStyle: id,
            headwear: id == 'hijab_wrapped' ? 'hijab' : (_traits.headwear == 'hijab' ? 'none' : _traits.headwear),
            characterAsset: null,
          ),
          onSelected: (id) {
            setState(() {
              _traits = _traits.copyWith(
                hairStyle: id,
                headwear: id == 'hijab_wrapped' ? 'hijab' : (_traits.headwear == 'hijab' ? 'none' : _traits.headwear),
                gender: (id == 'hijab_wrapped' || id == 'long_wavy' || id == 'bob' || id == 'bun') ? 'female' : 'male',
                characterAsset: null,
              );
            });
          },
        );

      case AvatarCustomizationSection.hairColor:
        return _buildColorGrid(
          colors: BitmojiTraits.hairPalette,
          selected: _traits.hairColor,
          onChanged: (c) =>
              setState(() => _traits = _traits.copyWith(hairColor: c, characterAsset: null)),
        );

      case AvatarCustomizationSection.eyes:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          children: [
            Expanded(
              child: _buildVisualGrid(
                options: const [
                  {'id': 'happy_curved', 'title': 'عيون مرحة 😊'},
                  {'id': 'focused_round', 'title': 'عيون ذكية 🧐'},
                  {'id': 'confident_almond', 'title': 'واثقة وجريئة 😎'},
                  {'id': 'winking', 'title': 'غمزة 😉'},
                  {'id': 'heart_eyes', 'title': 'قلوب حب 😍'},
                ],
                selectedId: _traits.eyes,
                crossAxisCount: defaultCols,
                childAspectRatio: 0.90,
                previewTraitsBuilder: (id) => _traits.copyWith(eyes: id, characterAsset: null),
                onSelected: (id) => setState(() => _traits = _traits.copyWith(eyes: id, characterAsset: null)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'لون قزحية العين:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: BitmojiTraits.eyePalette.map((c) {
                          final isSel = _traits.eyeColor.toARGB32() == c.toARGB32();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _traits = _traits.copyWith(eyeColor: c, characterAsset: null)),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? widget.roleColor : Colors.white,
                                    width: isSel ? 2.5 : 1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case AvatarCustomizationSection.headwear:
        return _buildVisualGrid(
          options: const [
            {'id': 'none', 'title': 'بدون غطاء'},
            {'id': 'hijab', 'title': 'حجاب إسلامي 🧕'},
            {'id': 'graduation_cap', 'title': 'قبعة تخرج 🎓'},
            {'id': 'headphones', 'title': 'سماعات رأس 🎧'},
            {'id': 'baseball_cap', 'title': 'كاب رياضي 🧢'},
          ],
          selectedId: _traits.headwear,
          crossAxisCount: defaultCols,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(
            headwear: id,
            hairStyle: id == 'hijab' ? 'hijab_wrapped' : _traits.hairStyle,
            characterAsset: null,
          ),
          onSelected: (id) {
            setState(() {
              _traits = _traits.copyWith(
                headwear: id,
                hairStyle: id == 'hijab' ? 'hijab_wrapped' : _traits.hairStyle,
                characterAsset: null,
              );
            });
          },
        );

      case AvatarCustomizationSection.outfit:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          children: [
            Expanded(
              child: _buildVisualGrid(
                options: const [
                  {'id': 'hoodie', 'title': 'هودي 👕'},
                  {'id': 'formal_blazer', 'title': 'بدلة رسمية 👔'},
                  {'id': 'lab_coat', 'title': 'بالطو طبيب 🥼'},
                  {'id': 'athletic', 'title': 'جاكيت رياضي 🏃'},
                  {'id': 'polo', 'title': 'بلوفر بولو 🧶'},
                  {'id': 'graduation_gown', 'title': 'روب تخرج 🎓'},
                  {'id': 'casual_crew', 'title': 'تيشيرت 🥋'},
                ],
                selectedId: _traits.outfit,
                crossAxisCount: defaultCols,
                childAspectRatio: 0.90,
                previewTraitsBuilder: (id) => _traits.copyWith(outfit: id, characterAsset: null),
                onSelected: (id) => setState(() => _traits = _traits.copyWith(outfit: id, characterAsset: null)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'لون الملابس:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: BitmojiTraits.outfitPalette.map((c) {
                          final isSel = _traits.outfitColor.toARGB32() == c.toARGB32();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _traits = _traits.copyWith(outfitColor: c, characterAsset: null)),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? widget.roleColor : Colors.white,
                                    width: isSel ? 2.5 : 1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case AvatarCustomizationSection.eyewear:
        return _buildVisualGrid(
          options: const [
            {'id': 'none', 'title': 'بدون نظارة'},
            {'id': 'square_frames', 'title': 'إطار مربع 👓'},
            {'id': 'round_frames', 'title': 'إطار دائري 🕶️'},
            {'id': 'cyber_visor', 'title': 'نظارة تكنولوجية 💻'},
            {'id': 'sunglasses', 'title': 'نظارة شمسية 😎'},
          ],
          selectedId: _traits.eyewear,
          crossAxisCount: defaultCols,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(eyewear: id, characterAsset: null),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(eyewear: id, characterAsset: null)),
        );

      case AvatarCustomizationSection.mouth:
        return _buildVisualGrid(
          options: const [
            {'id': 'warm_smile', 'title': 'ابتسامة 😊'},
            {'id': 'confident_smirk', 'title': 'واثق 😏'},
            {'id': 'wide_grin', 'title': 'ضحكة 😁'},
            {'id': 'neutral', 'title': 'تركيز 🧐'},
            {'id': 'playful_tongue', 'title': 'مرح وغمزة 😜'},
          ],
          selectedId: _traits.mouth,
          crossAxisCount: defaultCols,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(mouth: id, characterAsset: null),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(mouth: id, characterAsset: null)),
        );

      case AvatarCustomizationSection.facialHair:
        return _buildVisualGrid(
          options: const [
            {'id': 'none', 'title': 'حلاقة ناعمة 🪒'},
            {'id': 'stubble', 'title': 'ذقن خفيف 🧔'},
            {'id': 'trimmed_beard', 'title': 'لحية مشذبة ✨'},
            {'id': 'mustache', 'title': 'شارب 👨'},
          ],
          selectedId: _traits.facialHair,
          crossAxisCount: defaultCols,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(facialHair: id, characterAsset: null),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(facialHair: id, characterAsset: null)),
        );

      case AvatarCustomizationSection.background:
        return _buildColorGrid(
          colors: BitmojiTraits.backgroundPalette,
          selected: _traits.backgroundColor,
          onChanged: (c) =>
              setState(() => _traits = _traits.copyWith(backgroundColor: c, isTransparent: false)),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGenderSelector() {
    final malePreview = _traits.copyWith(
      gender: 'male',
      hairStyle: 'short_curly',
      headwear: 'none',
      facialHair: 'none',
      characterAsset: null,
    );
    final femalePreview = _traits.copyWith(
      gender: 'female',
      hairStyle: 'hijab_wrapped',
      headwear: 'hijab',
      facialHair: 'none',
      characterAsset: null,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: _buildCompactGenderCard(
                gender: 'male',
                title: 'شخصية شبابية 👦',
                isSelected: _traits.gender == 'male',
                previewTraits: malePreview,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactGenderCard(
                gender: 'female',
                title: 'شخصية فتيات 👧',
                isSelected: _traits.gender == 'female',
                previewTraits: femalePreview,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactGenderCard({
    required String gender,
    required String title,
    required bool isSelected,
    required BitmojiTraits previewTraits,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _traits = _traits.copyWith(
            gender: gender,
            hairStyle: gender == 'female' ? 'hijab_wrapped' : 'short_curly',
            headwear: gender == 'female' ? 'hijab' : 'none',
            facialHair: gender == 'female' ? 'none' : _traits.facialHair,
            characterAsset: null,
          );
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.roleColor.withValues(alpha: 0.12)
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? widget.roleColor : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.8 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: widget.roleColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 42,
                height: 42,
                child: CustomPaint(
                  size: const Size(42, 42),
                  painter: BitmojiCustomPainter(
                    traits: previewTraits,
                    showFullBody: false,
                    isTransparent: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? widget.roleColor : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.roleColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 10,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualGrid({
    required List<Map<String, String>> options,
    required String selectedId,
    required ValueChanged<String> onSelected,
    required BitmojiTraits Function(String optionId) previewTraitsBuilder,
    int crossAxisCount = 4,
    double childAspectRatio = 0.90,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final opt = options[index];
        final id = opt['id']!;
        final title = opt['title']!;
        final isSelected = id == selectedId;
        final previewTraits = previewTraitsBuilder(id);

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            onSelected(id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? widget.roleColor.withValues(alpha: 0.12)
                  : cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? widget.roleColor
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                width: isSelected ? 1.8 : 0.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: widget.roleColor.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Real Live 3D Vector Preview Thumbnail
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 48,
                              child: CustomPaint(
                                size: const Size(44, 48),
                                painter: BitmojiCustomPainter(
                                  traits: previewTraits,
                                  showFullBody: false,
                                  isTransparent: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Compact Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? widget.roleColor
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                  ],
                ),

                // Selected Checkmark Badge
                if (isSelected)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: widget.roleColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorGrid({
    required List<Color> colors,
    required Color selected,
    required ValueChanged<Color> onChanged,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: colors.map((c) {
            final isSelected = selected.toARGB32() == c.toARGB32();
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(c);
              },
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? widget.roleColor : Colors.white,
                    width: isSelected ? 3.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.35),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 20,
                        color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStyleCategoryFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filters = [
      {'id': 'all', 'title': 'الكل 🌟'},
      {'id': 'student', 'title': 'الطلاب 🎒'},
      {'id': 'teacher', 'title': 'المعلمون 👨‍🏫'},
      {'id': 'talent', 'title': 'المواهب 🔬'},
      {'id': 'admin', 'title': 'الإدارة 👔'},
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _styleCategoryFilter == f['id'];

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _styleCategoryFilter = f['id']!);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? widget.roleColor
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  f['title']!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPedestalSelector({required bool isWide}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    final pedestals = [
      {
        'id': 'neon_disc',
        'title': 'ديسك النيون المشع ⚡',
        'desc': 'منصة إلكترونية متوهجة بنبضات النيون',
        'color': const Color(0xFF0EA5E9),
      },
      {
        'id': 'royal_gold',
        'title': 'المنصة الملكية الذهبية 👑',
        'desc': 'أناقة الذهب الخالص مع لمعان فخم',
        'color': const Color(0xFFF59E0B),
      },
      {
        'id': 'emerald_crystal',
        'title': 'الكريستال الزمردي 💎',
        'desc': 'بلورات متوهجة بلون الزمرد الملكي',
        'color': const Color(0xFF10B981),
      },
      {
        'id': 'obsidian_holo',
        'title': 'الأوبسيديان المستقبلي 🌌',
        'desc': 'حلقة هولوجرامية أرجوانية ساحرة',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'id': 'floating_halo',
        'title': 'حلقة الطاقة العائمة 💫',
        'desc': 'هالة ناعمة بلون وردي مبهج وأنيق',
        'color': const Color(0xFFEC4899),
      },
      {
        'id': 'none',
        'title': 'بدون منصة ⭕',
        'desc': 'عرض الشخصية بالكامل على أرضية محايدة',
        'color': Colors.grey,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: pedestals.length,
      itemBuilder: (context, index) {
        final p = pedestals[index];
        final id = p['id'] as String;
        final title = p['title'] as String;
        final desc = p['desc'] as String;
        final color = p['color'] as Color;
        final isSelected = _traits.pedestalStyle == id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _traits = _traits.copyWith(pedestalStyle: id);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.12)
                    : cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                  width: isSelected ? 1.8 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isSelected
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
                          : Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white70,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? color
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHonorBadgeSelector({required bool isWide}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    final badges = [
      {
        'id': 'none',
        'emoji': '⭕',
        'title': 'بدون وسام',
        'desc': 'إخفاء شارة الشرف العائمة',
        'color': Colors.grey,
      },
      {
        'id': 'top_honor',
        'emoji': '🥇',
        'title': 'وسام الشرف والامتياز',
        'desc': 'مخصص للطلاب الأوائل والمتفوقين أكاديمياً',
        'color': const Color(0xFFF59E0B),
      },
      {
        'id': 'star_achiever',
        'emoji': '🌟',
        'title': 'نجم الإنجاز الأكاديمي',
        'desc': 'للطلاب ذوي الأنشطة والواجبات المتميزة',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'id': 'math_genius',
        'emoji': '📐',
        'title': 'عبقري الرياضيات والعلوم',
        'desc': 'لأصحاب التفكير المنطقي والحلول الإبداعية',
        'color': const Color(0xFF0EA5E9),
      },
      {
        'id': 'student_leader',
        'emoji': '👑',
        'title': 'القائد الطلابي المتميز',
        'desc': 'لأصحاب روح المبادرة والعمل الجماعي',
        'color': const Color(0xFFEAB308),
      },
      {
        'id': 'researcher',
        'emoji': '🔬',
        'title': 'الباحث والمستكشف',
        'desc': 'لرواد الابتكار والتجارب المعملية',
        'color': const Color(0xFF10B981),
      },
      {
        'id': 'creative',
        'emoji': '🎨',
        'title': 'المبدع والفنان الرقمي',
        'desc': 'لأصحاب المواهب الفنية والتصميم',
        'color': const Color(0xFFEC4899),
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final b = badges[index];
        final id = b['id'] as String;
        final emoji = b['emoji'] as String;
        final title = b['title'] as String;
        final desc = b['desc'] as String;
        final color = b['color'] as Color;
        final isSelected = (id == 'none' && _traits.honorBadge == null) ||
            _traits.honorBadge == id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _traits = _traits.copyWith(
                  honorBadge: id == 'none' ? null : id,
                );
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.12)
                    : cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                  width: isSelected ? 1.8 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.15),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? color
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
