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
      // 1. Direct high-res PNG image URL
      final highResUrl = _traits.toImageUrl(size: 512);

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
              flex: 5,
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

            // ── Section Tabs Ribbon ──
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                ),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  _buildSectionTab(AvatarCustomizationSection.style, 'النمط والموديل', Icons.palette_rounded),
                  _buildSectionTab(AvatarCustomizationSection.genderBody, 'الجنس', Icons.wc_rounded),
                  _buildSectionTab(AvatarCustomizationSection.hairStyle, 'الشعر', Icons.content_cut_rounded),
                  _buildSectionTab(AvatarCustomizationSection.headwear, 'الحجاب والأغطية', Icons.dry_cleaning_rounded),
                  _buildSectionTab(AvatarCustomizationSection.outfit, 'الملابس والأزياء', Icons.checkroom_rounded),
                  _buildSectionTab(AvatarCustomizationSection.skinTone, 'البشرة', Icons.face_rounded),
                  _buildSectionTab(AvatarCustomizationSection.hairColor, 'لون الشعر', Icons.format_paint_rounded),
                  _buildSectionTab(AvatarCustomizationSection.eyewear, 'النظارات', Icons.visibility_rounded),
                  _buildSectionTab(AvatarCustomizationSection.mouth, 'التعبيرات', Icons.mood_rounded),
                  _buildSectionTab(AvatarCustomizationSection.facialHair, 'اللحية والشارب', Icons.face_retouching_natural_rounded),
                  _buildSectionTab(AvatarCustomizationSection.background, 'الاستوديو', Icons.wallpaper_rounded),
                ],
              ),
            ),

            // ── Options Tray ──
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
    final color = isSelected ? widget.roleColor : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
        label: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        selectedColor: widget.roleColor,
        showCheckmark: false,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentSection = section;
            // Auto focus camera depending on section
            if (section == AvatarCustomizationSection.outfit ||
                section == AvatarCustomizationSection.genderBody ||
                section == AvatarCustomizationSection.style) {
              _cameraFocus = AvatarCameraFocus.fullBody;
            } else {
              _cameraFocus = AvatarCameraFocus.face;
            }
          });
        },
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_currentSection) {
      case AvatarCustomizationSection.style:
        return _buildChoiceCards(
          options: const [
            {'id': 'avataaars', 'title': 'سناب شات كلاسيك 👱', 'subtitle': 'نمط شخصيات Bitmoji الشهيرة بجودة سينمائية'},
            {'id': 'adventurer', 'title': 'مغامر بيكسار 3D ⚔️', 'subtitle': 'تصميم بيكسار كارتوني ثلاثي الأبعاد مبهج'},
            {'id': 'lorelei', 'title': 'أنمي ولوريلاي 🌸', 'subtitle': 'رسوم أنمي يابانية حديثة وناعمة'},
            {'id': 'bottts', 'title': 'سايبر روبوتيكس 🤖', 'subtitle': 'شخصيات روبوت ثلاثية الأبعاد لمحبي البرمجة'},
          ],
          selectedId: _traits.style,
          onSelected: (id) => setState(() => _traits = _traits.copyWith(style: id)),
        );

      case AvatarCustomizationSection.genderBody:
        return _buildGenderSelector();

      case AvatarCustomizationSection.hairStyle:
        return _buildChoiceCards(
          options: const [
            {'id': 'short_curly', 'title': 'كيرلي عصري 👦', 'subtitle': 'شعر كيرلي مجعد وأنيق'},
            {'id': 'fade_crop', 'title': 'تدريج فيد (Fade) 💈', 'subtitle': 'مدرج جانبي خفيف وعصري'},
            {'id': 'slick_back', 'title': 'تسريحة كلاسيك ✂️', 'subtitle': 'ممشط للخلف بأناقة رجال الأعمال'},
            {'id': 'long_wavy', 'title': 'طويل مموج 💁‍♀️', 'subtitle': 'خصلات منسدلة وجميلة'},
            {'id': 'buzz_cut', 'title': 'قصة قصيرة رياضي 👨', 'subtitle': 'شعر خفيف ونظيف'},
            {'id': 'hijab_wrapped', 'title': 'حجاب إسلامي 🧕', 'subtitle': 'حجاب ساتر وأنيق متناسق مع الوجه'},
            {'id': 'bob', 'title': 'قصة بوب عصرية 💇‍♀️', 'subtitle': 'قصة قصيرة جذابة للفتيات'},
            {'id': 'bun', 'title': 'كعكة مرفوعة 👱‍♀️', 'subtitle': 'مظهر شبابي نشط'},
            {'id': 'hat', 'title': 'قبعة كاجوال 🧢', 'subtitle': 'ستايل رياضي شبابي'},
          ],
          selectedId: _traits.hairStyle,
          onSelected: (id) =>
              setState(() => _traits = _traits.copyWith(hairStyle: id)),
        );

      case AvatarCustomizationSection.headwear:
        return _buildChoiceCards(
          options: const [
            {'id': 'none', 'title': 'بدون غطاء', 'subtitle': 'الشعر مكشوف بالكامل'},
            {'id': 'hijab', 'title': 'حجاب إسلامي أنيق 🧕', 'subtitle': 'لفافة حجاب متناسقة مع لون الملابس'},
          ],
          selectedId: _traits.headwear,
          onSelected: (id) =>
              setState(() => _traits = _traits.copyWith(headwear: id)),
        );

      case AvatarCustomizationSection.outfit:
        return Column(
          children: [
            Expanded(
              child: _buildChoiceCards(
                options: const [
                  {'id': 'hoodie', 'title': 'سويت شيرت هودي 👕', 'subtitle': 'كاجوال شبابي دافئ وعصري'},
                  {'id': 'formal_blazer', 'title': 'بدلة رسمية وقميص 👔', 'subtitle': 'أناقة أكاديمية للمحاضرات والتفوق'},
                  {'id': 'polo', 'title': 'بلوفر بياقة كلاسيك 🧶', 'subtitle': 'مظهر راقي وأنيق'},
                  {'id': 'casual_crew', 'title': 'تيشرت قطني كاجوال 🥋', 'subtitle': 'بسيط وخفيف'},
                ],
                selectedId: _traits.outfit,
                onSelected: (id) =>
                    setState(() => _traits = _traits.copyWith(outfit: id)),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('لون الملابس:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
        return _buildColorPaletteRibbon(
          colors: BitmojiTraits.skinPalette,
          selected: _traits.skinColor,
          onChanged: (c) => setState(() => _traits = _traits.copyWith(skinColor: c)),
        );

      case AvatarCustomizationSection.hairColor:
        return _buildColorPaletteRibbon(
          colors: BitmojiTraits.hairPalette,
          selected: _traits.hairColor,
          onChanged: (c) => setState(() => _traits = _traits.copyWith(hairColor: c)),
        );

      case AvatarCustomizationSection.eyewear:
        return _buildChoiceCards(
          options: const [
            {'id': 'none', 'title': 'بدون نظارة', 'subtitle': 'رؤية طبيعية بدون إطارات'},
            {'id': 'square_frames', 'title': 'إطار مربع طبي 👓', 'subtitle': 'نظارة طبية ذكية وأنيقة'},
            {'id': 'round_frames', 'title': 'إطار دائري ذكي 🕶️', 'subtitle': 'ستايل فنانين ومبتكرين'},
            {'id': 'sunglasses', 'title': 'نظارة شمسية كول 😎', 'subtitle': 'عدسات داكنة فخمة'},
          ],
          selectedId: _traits.eyewear,
          onSelected: (id) =>
              setState(() => _traits = _traits.copyWith(eyewear: id)),
        );

      case AvatarCustomizationSection.mouth:
        return _buildChoiceCards(
          options: const [
            {'id': 'warm_smile', 'title': 'ابتسامة وسعادة 😊', 'subtitle': 'ملامح ترحيبية دافئة'},
            {'id': 'confident_smirk', 'title': 'واثقة ومرحة 😏', 'subtitle': 'ابتسامة ذكية هادئة'},
            {'id': 'wide_grin', 'title': 'ضحكة عريضة وأسنان 😁', 'subtitle': 'ضحكة مليئة بالطاقة والإيجابية'},
            {'id': 'neutral', 'title': 'تركيز وجدية 🧐', 'subtitle': 'ملامح طالب يدرس باهتمام'},
          ],
          selectedId: _traits.mouth,
          onSelected: (id) => setState(() => _traits = _traits.copyWith(mouth: id)),
        );

      case AvatarCustomizationSection.facialHair:
        return _buildChoiceCards(
          options: const [
            {'id': 'none', 'title': 'حلاقة ناعمة', 'subtitle': 'بدون ذقن أو شوارب'},
            {'id': 'stubble', 'title': 'ذقن خفيف (Stubble)', 'subtitle': 'ظل خفيف رجولي'},
            {'id': 'trimmed_beard', 'title': 'لحية كاملة مهندمة', 'subtitle': 'مشذبة وأنيقة'},
            {'id': 'mustache', 'title': 'شارب كلاسيكي', 'subtitle': 'أنيق ومرتب'},
          ],
          selectedId: _traits.facialHair,
          onSelected: (id) =>
              setState(() => _traits = _traits.copyWith(facialHair: id)),
        );

      case AvatarCustomizationSection.background:
        return _buildColorPaletteRibbon(
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildGenderCard(
              gender: 'male',
              title: 'شخصية شبابية 👦',
              subtitle: 'هيكل شبابي وملامح كلاسيكية وهودي عصري',
              isSelected: _traits.gender == 'male',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildGenderCard(
              gender: 'female',
              title: 'شخصية فتيات 👧',
              subtitle: 'خيارات حجاب وتسريحات بنات أنيقة',
              isSelected: _traits.gender == 'female',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard({
    required String gender,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.roleColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? widget.roleColor : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? widget.roleColor : null,
                )),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCards({
    required List<Map<String, String>> options,
    required String selectedId,
    required ValueChanged<String> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final opt = options[index];
        final id = opt['id']!;
        final title = opt['title']!;
        final subtitle = opt['subtitle']!;
        final isSelected = id == selectedId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              onSelected(id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? widget.roleColor.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? widget.roleColor
                      : Colors.grey.withValues(alpha: 0.2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? widget.roleColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? widget.roleColor : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? widget.roleColor : null,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
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

  Widget _buildColorPaletteRibbon({
    required List<Color> colors,
    required Color selected,
    required ValueChanged<Color> onChanged,
  }) {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? widget.roleColor : Colors.white70,
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: widget.roleColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 22,
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
