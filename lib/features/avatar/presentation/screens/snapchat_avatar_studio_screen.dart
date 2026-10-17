import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/avatar_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../domain/models/bitmoji_traits.dart';
import '../widgets/bitmoji_renderer.dart';
import '../widgets/bitmoji_stickers_sheet.dart';

/// Full-featured, commercial-grade Snapchat Bitmoji 3D Studio.
/// Real high-resolution character rendering, 3D pedestal stage,
/// camera zoom toggle, visual trait selector, and PNG exporter.
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
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SnapchatAvatarStudioScreen(
          userId: userId,
          userEmail: userEmail,
          initialAvatarUrl: initialAvatarUrl,
          roleColor: roleColor,
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

  @override
  void initState() {
    super.initState();
    _traits = BitmojiTraits(
      seed: widget.userId ?? 'Hero_${DateTime.now().millisecondsSinceEpoch}',
    );
    _loadSavedTraits();
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
          _traits = BitmojiTraits.fromJson(map);
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
      _cameraFocus = (_cameraFocus == AvatarCameraFocus.fullBody)
          ? AvatarCameraFocus.face
          : AvatarCameraFocus.fullBody;
    });
  }

  void _randomize() {
    HapticFeedback.mediumImpact();
    final rnd = DateTime.now().millisecondsSinceEpoch;
    final skins = BitmojiTraits.skinPalette;
    final hairs = BitmojiTraits.hairPalette;
    final outfits = BitmojiTraits.outfitPalette;
    final bgs = BitmojiTraits.backgroundPalette;

    final styles = ['avataaars', 'adventurer', 'lorelei'];
    final hairStyles = [
      'short_curly',
      'fade_crop',
      'slick_back',
      'long_wavy',
      'buzz_cut',
      'hijab_wrapped',
      'bob',
      'bun',
      'hat',
    ];
    final eyeStyles = [
      'happy_curved',
      'focused_round',
      'confident_almond',
      'winking',
    ];
    final mouths = ['warm_smile', 'confident_smirk', 'wide_grin', 'neutral'];
    final beards = ['none', 'stubble', 'trimmed_beard', 'mustache'];
    final glasses = ['none', 'square_frames', 'round_frames', 'sunglasses'];
    final clothes = ['hoodie', 'formal_blazer', 'casual_crew', 'polo'];

    setState(() {
      _traits = _traits.copyWith(
        seed: 'Seed_$rnd',
        style: styles[rnd % styles.length],
        skinColor: skins[rnd % skins.length],
        hairColor: hairs[(rnd ~/ 2) % hairs.length],
        outfitColor: outfits[(rnd ~/ 3) % outfits.length],
        backgroundColor: bgs[(rnd ~/ 4) % bgs.length],
        hairStyle: hairStyles[(rnd ~/ 5) % hairStyles.length],
        eyes: eyeStyles[(rnd ~/ 6) % eyeStyles.length],
        mouth: mouths[(rnd ~/ 7) % mouths.length],
        facialHair: beards[(rnd ~/ 8) % beards.length],
        eyewear: glasses[(rnd ~/ 9) % glasses.length],
        outfit: clothes[(rnd ~/ 10) % clothes.length],
      );
    });
  }

  Future<void> _saveAvatar() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      // 1. Direct high-res PNG image URL with background
      final highResUrl = _traits.toImageUrl(size: 512, includeBackground: true);

      // 2. Capture high-res PNG bytes from native Canvas if available
      final Uint8List? pngBytes = await BitmojiRenderer.capturePng(
        _repaintKey,
        pixelRatio: 3.0,
      );

      String finalAvatarUrl = highResUrl;
      if (pngBytes != null) {
        final filename =
            'bitmoji_${widget.userId ?? "guest"}_${DateTime.now().millisecondsSinceEpoch}.png';

        // 3. Upload to Supabase Storage
        final uploadedUrl = await AvatarService.uploadAvatar(
          bytes: pngBytes,
          filename: filename,
          userId: widget.userId,
        );
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          finalAvatarUrl = uploadedUrl;
        }
      }

      // 4. Persist traits configuration locally
      await _persistTraitsLocally();

      // 5. Update user profile and saved accounts
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
        const SnackBar(
          content: Text('تم تصميم وحفظ الأفاتار بنجاح! 🌟'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(finalAvatarUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0.5,
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          actions: [
            // Stickers sheet button
            IconButton(
              tooltip: 'ملصقات شخصيتك 🎭',
              icon: const Icon(Icons.emoji_emotions_rounded,
                  color: Color(0xFF8B5CF6)),
              onPressed: () {
                BitmojiStickersSheet.show(
                  context,
                  traits: _traits,
                  onApplyStickerExpression: (updated) {
                    setState(() => _traits = updated);
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
        body: Column(
          children: [
            // ── Interactive 3D Stage Viewport ──
            Expanded(
              flex: 6,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vector Stage with 3D Pedestal
                  Container(
                    width: double.infinity,
                    color: _traits.backgroundColor.withValues(alpha: 0.15),
                    child: Center(
                      child: BitmojiRenderer(
                        traits: _traits,
                        cameraFocus: _cameraFocus,
                        repaintKey: _repaintKey,
                        isAnimated: true,
                        showPedestal: true,
                      ),
                    ),
                  ),

                  // Floating Camera Switcher Pill (Top Right)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _toggleCameraFocus,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor.withValues(alpha: 0.92),
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
                                  : Icons.face_rounded,
                              size: 16,
                              color: widget.roleColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _cameraFocus == AvatarCameraFocus.face
                                  ? 'عرض الجسم كامل'
                                  : 'تكبير الوجه',
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

                  // Floating Sticker Pack Quick Pill (Bottom Left)
                  Positioned(
                    bottom: 12,
                    left: 16,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        BitmojiStickersSheet.show(
                          context,
                          traits: _traits,
                          onApplyStickerExpression: (updated) {
                            setState(() => _traits = updated);
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                            Text('✨', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Text(
                              'ملصقات Bitmoji',
                              style: TextStyle(
                                fontSize: 12,
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
              ),
            ),

            // ── Snapchat Compact Dock Ribbon ──
            Container(
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
                  _buildSectionTab(AvatarCustomizationSection.hairStyle, 'الشعر', Icons.content_cut_rounded),
                  _buildSectionTab(AvatarCustomizationSection.headwear, 'الحجاب', Icons.dry_cleaning_rounded),
                  _buildSectionTab(AvatarCustomizationSection.outfit, 'الملابس', Icons.checkroom_rounded),
                  _buildSectionTab(AvatarCustomizationSection.skinTone, 'البشرة', Icons.face_rounded),
                  _buildSectionTab(AvatarCustomizationSection.hairColor, 'لون الشعر', Icons.format_paint_rounded),
                  _buildSectionTab(AvatarCustomizationSection.eyewear, 'النظارات', Icons.visibility_rounded),
                  _buildSectionTab(AvatarCustomizationSection.mouth, 'التعبيرات', Icons.mood_rounded),
                  _buildSectionTab(AvatarCustomizationSection.facialHair, 'اللحية', Icons.face_retouching_natural_rounded),
                  _buildSectionTab(AvatarCustomizationSection.background, 'الاستوديو', Icons.wallpaper_rounded),
                ],
              ),
            ),

            // ── Compact Options Tray ──
            Expanded(
              flex: 4,
              child: Container(
                color: cardColor,
                child: _buildSectionContent(),
              ),
            ),
          ],
        ),
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
                  section == AvatarCustomizationSection.style) {
                _cameraFocus = AvatarCameraFocus.fullBody;
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

  Widget _buildSectionContent() {
    switch (_currentSection) {
      case AvatarCustomizationSection.style:
        return _buildVisualGrid(
          options: const [
            {'id': 'avataaars', 'title': 'سناب شات 👱'},
            {'id': 'adventurer', 'title': 'بيكسار 3D ⚔️'},
            {'id': 'lorelei', 'title': 'أنمي 🌸'},
            {'id': 'bottts', 'title': 'روبوت 🤖'},
          ],
          selectedId: _traits.style,
          crossAxisCount: 4,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(style: id),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(style: id)),
        );

      case AvatarCustomizationSection.genderBody:
        return _buildGenderSelector();

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
            {'id': 'hat', 'title': 'قبعة 🧢'},
          ],
          selectedId: _traits.hairStyle,
          crossAxisCount: 4,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(
            hairStyle: id,
            headwear: id == 'hijab_wrapped' ? 'hijab' : 'none',
          ),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(hairStyle: id)),
        );

      case AvatarCustomizationSection.headwear:
        return _buildVisualGrid(
          options: const [
            {'id': 'none', 'title': 'بدون غطاء'},
            {'id': 'hijab', 'title': 'حجاب إسلامي 🧕'},
          ],
          selectedId: _traits.headwear,
          crossAxisCount: 4,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(
            headwear: id,
            hairStyle: id == 'hijab' ? 'hijab_wrapped' : _traits.hairStyle,
          ),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(headwear: id)),
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
                  {'id': 'polo', 'title': 'بلوفر 🧶'},
                  {'id': 'casual_crew', 'title': 'تيشيرت 🥋'},
                ],
                selectedId: _traits.outfit,
                crossAxisCount: 4,
                childAspectRatio: 0.90,
                previewTraitsBuilder: (id) => _traits.copyWith(outfit: id),
                onSelected: (id) => setState(() => _traits = _traits.copyWith(outfit: id)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  const Text('لون الملابس:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildColorPaletteRibbon(
                      colors: BitmojiTraits.outfitPalette,
                      selected: _traits.outfitColor,
                      onChanged: (c) => setState(() => _traits =
                          _traits.copyWith(outfitColor: c, outfitAccentColor: c)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case AvatarCustomizationSection.skinTone:
        return _buildColorGrid(
          colors: BitmojiTraits.skinPalette,
          selected: _traits.skinColor,
          onChanged: (c) => setState(() => _traits = _traits.copyWith(skinColor: c)),
        );

      case AvatarCustomizationSection.hairColor:
        return _buildColorGrid(
          colors: BitmojiTraits.hairPalette,
          selected: _traits.hairColor,
          onChanged: (c) => setState(() => _traits = _traits.copyWith(hairColor: c)),
        );

      case AvatarCustomizationSection.eyewear:
        return _buildVisualGrid(
          options: const [
            {'id': 'none', 'title': 'بدون نظارة'},
            {'id': 'square_frames', 'title': 'إطار مربع 👓'},
            {'id': 'round_frames', 'title': 'إطار دائري 🕶️'},
            {'id': 'sunglasses', 'title': 'نظارة شمسية 😎'},
          ],
          selectedId: _traits.eyewear,
          crossAxisCount: 4,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(eyewear: id),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(eyewear: id)),
        );

      case AvatarCustomizationSection.mouth:
        return _buildVisualGrid(
          options: const [
            {'id': 'warm_smile', 'title': 'ابتسامة 😊'},
            {'id': 'confident_smirk', 'title': 'واثق 😏'},
            {'id': 'wide_grin', 'title': 'ضحكة 😁'},
            {'id': 'neutral', 'title': 'تركيز 🧐'},
          ],
          selectedId: _traits.mouth,
          crossAxisCount: 4,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(mouth: id),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(mouth: id)),
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
          crossAxisCount: 4,
          childAspectRatio: 0.90,
          previewTraitsBuilder: (id) => _traits.copyWith(facialHair: id),
          onSelected: (id) => setState(() => _traits = _traits.copyWith(facialHair: id)),
        );

      case AvatarCustomizationSection.background:
        return _buildColorGrid(
          colors: BitmojiTraits.backgroundPalette,
          selected: _traits.backgroundColor,
          onChanged: (c) =>
              setState(() => _traits = _traits.copyWith(backgroundColor: c)),
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
    );
    final femalePreview = _traits.copyWith(
      gender: 'female',
      hairStyle: 'hijab_wrapped',
      headwear: 'hijab',
      facialHair: 'none',
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
                previewUrl: malePreview.toImageUrl(size: 128),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactGenderCard(
                gender: 'female',
                title: 'شخصية فتيات 👧',
                isSelected: _traits.gender == 'female',
                previewUrl: femalePreview.toImageUrl(size: 128),
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
    required String previewUrl,
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
          );
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
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
                width: 40,
                height: 40,
                child: Image.network(
                  previewUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    gender == 'male' ? Icons.boy_rounded : Icons.girl_rounded,
                    size: 24,
                    color: widget.roleColor,
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
    IconData fallbackIcon = Icons.auto_awesome_rounded,
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
        final previewUrl = previewTraits.toImageUrl(size: 128);

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
                    // Visual Preview Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              previewUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: widget.roleColor,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (ctx, err, stack) => Icon(
                                fallbackIcon,
                                size: 22,
                                color: isSelected ? widget.roleColor : Colors.grey,
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

                // Selected Checkmark Badge (Micro circle)
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
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: colors.map((c) {
            final isSelected = c.toARGB32() == selected.toARGB32();
            final isLight = c.computeLuminance() > 0.5;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(c);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? widget.roleColor : Colors.white70,
                    width: isSelected ? 3.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                    if (isSelected)
                      BoxShadow(
                        color: widget.roleColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: isSelected
                    ? Center(
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: isLight ? Colors.black87 : Colors.white,
                        ),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildColorPaletteRibbon({
    required List<Color> colors,
    required Color selected,
    required ValueChanged<Color> onChanged,
  }) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final c = colors[index];
          final isSelected = c.toARGB32() == selected.toARGB32();

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(c);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? widget.roleColor : Colors.white70,
                  width: isSelected ? 2.5 : 1.2,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: widget.roleColor.withValues(alpha: 0.4),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: c.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
