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
/// responsive two-pane desktop / vertical mobile layout, camera zoom toggle,
/// visual trait selector, and PNG exporter.
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
      if (_cameraFocus == AvatarCameraFocus.fullBody) {
        _cameraFocus = AvatarCameraFocus.face;
      } else if (_cameraFocus == AvatarCameraFocus.face) {
        _cameraFocus = AvatarCameraFocus.bust;
      } else {
        _cameraFocus = AvatarCameraFocus.fullBody;
      }
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
      'graphic_tee',
    ];

    final avatars = [
      'assets/avatars/snap_boy_curly.png',
      'assets/avatars/snap_girl_hijab.png',
      'assets/avatars/snap_student_star.png',
      'assets/avatars/snap_girl_stylish.png',
      'assets/avatars/snap_boy_glasses.png',
      'assets/avatars/snap_teacher_male.png',
      'assets/avatars/snap_teacher_female.png',
      'assets/avatars/snap_executive_leader.png',
      'assets/avatars/snap_doctor_scientist.png',
      'assets/avatars/snap_artist_creative.png',
      'assets/avatars/snap_athlete_sports.png',
      'assets/avatars/snap_cyber_hacker.png',
      'assets/avatars/snap_counselor_female.png',
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
    final chosenAsset = avatars[rnd % avatars.length];
    final isFemale = chosenAsset.contains('girl') || chosenAsset.contains('female') || chosenAsset.contains('star');

    setState(() {
      _traits = _traits.copyWith(
        seed: 'Seed_$rnd',
        characterAsset: chosenAsset,
        gender: isFemale ? 'female' : 'male',
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 720;
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
        body: isWide
            // Desktop / Tablet 2-Pane Side-by-Side Studio Layout
            ? Row(
                children: [
                  // Left Pane: 3D Stage Viewport
                  SizedBox(
                    width: (screenWidth * 0.42).clamp(360.0, 480.0),
                    child: _buildStageViewport(cardColor, textPrimary),
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
                    child: _buildStageViewport(cardColor, textPrimary),
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
      ),
    );
  }

  // ==========================================
  // Stage Viewport Component
  // ==========================================
  Widget _buildStageViewport(Color cardColor, Color textPrimary) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Vector Stage with 3D Pedestal
        Container(
          width: double.infinity,
          height: double.infinity,
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

        // Floating Sticker Pack Quick Pill (Bottom Left)
        Positioned(
          bottom: 12,
          left: 14,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                selectedId: _traits.characterAsset != null
                    ? _traits.characterAsset!.replaceAll('assets/avatars/', '').replaceAll('.png', '')
                    : _traits.resolvedAssetPath.replaceAll('assets/avatars/', '').replaceAll('.png', ''),
                crossAxisCount: defaultCols,
                childAspectRatio: 0.90,
                previewTraitsBuilder: (id) => _traits.copyWith(
                  characterAsset: 'assets/avatars/$id.png',
                ),
                onSelected: (id) {
                  final asset = 'assets/avatars/$id.png';
                  setState(() {
                    _traits = _traits.copyWith(
                      characterAsset: asset,
                      gender: (id.contains('girl') || id.contains('female') || id == 'snap_student_star')
                          ? 'female'
                          : 'male',
                      headwear: id == 'snap_girl_hijab'
                          ? 'hijab'
                          : (id == 'snap_student_star' ? 'graduation_cap' : 'none'),
                      hairStyle: id == 'snap_girl_hijab' ? 'hijab_wrapped' : _traits.hairStyle,
                    );
                  });
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
          previewTraitsBuilder: (id) {
            String? asset;
            if (id == 'short_curly') asset = 'assets/avatars/snap_boy_curly.png';
            if (id == 'hijab_wrapped') asset = 'assets/avatars/snap_girl_hijab.png';
            if (id == 'long_wavy') asset = 'assets/avatars/snap_girl_stylish.png';
            if (id == 'fade_crop') asset = 'assets/avatars/snap_boy_glasses.png';
            if (id == 'slick_back') asset = 'assets/avatars/snap_teacher_male.png';
            if (id == 'bob') asset = 'assets/avatars/snap_teacher_female.png';
            return _traits.copyWith(
              hairStyle: id,
              headwear: id == 'hijab_wrapped' ? 'hijab' : 'none',
              characterAsset: asset,
            );
          },
          onSelected: (id) {
            String? asset;
            if (id == 'short_curly') asset = 'assets/avatars/snap_boy_curly.png';
            if (id == 'hijab_wrapped') asset = 'assets/avatars/snap_girl_hijab.png';
            if (id == 'long_wavy') asset = 'assets/avatars/snap_girl_stylish.png';
            if (id == 'fade_crop') asset = 'assets/avatars/snap_boy_glasses.png';
            if (id == 'slick_back') asset = 'assets/avatars/snap_teacher_male.png';
            if (id == 'bob') asset = 'assets/avatars/snap_teacher_female.png';
            setState(() {
              _traits = _traits.copyWith(
                hairStyle: id,
                characterAsset: asset,
                headwear: id == 'hijab_wrapped' ? 'hijab' : 'none',
                gender: (id == 'hijab_wrapped' || id == 'long_wavy' || id == 'bob' || id == 'bun') ? 'female' : 'male',
              );
            });
          },
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
          previewTraitsBuilder: (id) {
            String? asset;
            if (id == 'hijab') asset = 'assets/avatars/snap_girl_hijab.png';
            if (id == 'graduation_cap') asset = 'assets/avatars/snap_student_star.png';
            if (id == 'headphones') asset = 'assets/avatars/snap_girl_stylish.png';
            return _traits.copyWith(
              headwear: id,
              characterAsset: asset,
              hairStyle: id == 'hijab' ? 'hijab_wrapped' : _traits.hairStyle,
            );
          },
          onSelected: (id) {
            String? asset;
            if (id == 'hijab') asset = 'assets/avatars/snap_girl_hijab.png';
            if (id == 'graduation_cap') asset = 'assets/avatars/snap_student_star.png';
            if (id == 'headphones') asset = 'assets/avatars/snap_girl_stylish.png';
            setState(() {
              _traits = _traits.copyWith(
                headwear: id,
                characterAsset: asset,
                hairStyle: id == 'hijab' ? 'hijab_wrapped' : _traits.hairStyle,
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
                  {'id': 'blazer_sweater', 'title': 'بليزر كاجوال 🧥'},
                  {'id': 'polo', 'title': 'بلوفر بولو 🧶'},
                  {'id': 'casual_crew', 'title': 'تيشيرت 🥋'},
                  {'id': 'graphic_tee', 'title': 'تيشيرت جرافيك 🎨'},
                  {'id': 'overall', 'title': 'سالوبيت جينز 👖'},
                ],
                selectedId: _traits.outfit,
                crossAxisCount: defaultCols,
                childAspectRatio: 0.90,
                previewTraitsBuilder: (id) => _traits.copyWith(outfit: id),
                onSelected: (id) => setState(() => _traits = _traits.copyWith(outfit: id)),
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
            {'id': 'wayfarers', 'title': 'واي فيرر كلاسيك 👓'},
            {'id': 'sunglasses', 'title': 'نظارة شمسية 😎'},
          ],
          selectedId: _traits.eyewear,
          crossAxisCount: defaultCols,
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
            {'id': 'playful_tongue', 'title': 'مرح وغمزة 😜'},
          ],
          selectedId: _traits.mouth,
          crossAxisCount: defaultCols,
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
          crossAxisCount: defaultCols,
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
                child: previewUrl.startsWith('assets/')
                    ? Image.asset(
                        previewUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          gender == 'male' ? Icons.boy_rounded : Icons.girl_rounded,
                          size: 24,
                          color: widget.roleColor,
                        ),
                      )
                    : Image.network(
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
                            child: previewUrl.startsWith('assets/')
                                ? Image.asset(
                                    previewUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, err, stack) => Icon(
                                      fallbackIcon,
                                      size: 22,
                                      color: isSelected ? widget.roleColor : Colors.grey,
                                    ),
                                  )
                                : Image.network(
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

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(c);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
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
                    ? const Center(
                        child: Icon(Icons.check, size: 16, color: Colors.white),
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
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        itemBuilder: (context, i) {
          final c = colors[i];
          final isSelected = c.toARGB32() == selected.toARGB32();

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(c);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? widget.roleColor : Colors.white,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: widget.roleColor.withValues(alpha: 0.35),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 12, color: Colors.white),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStyleCategoryFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filters = const [
      {'id': 'all', 'label': 'الكل 🌟'},
      {'id': 'student', 'label': 'الطلاب 🎒'},
      {'id': 'teacher', 'label': 'المعلمون 👨‍🏫'},
      {'id': 'admin', 'label': 'الإدارة 👔'},
      {'id': 'talent', 'label': 'المواهب 🔬'},
    ];

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.6,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final f = filters[i];
          final isSelected = _styleCategoryFilter == f['id'];

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _styleCategoryFilter = f['id']!;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? widget.roleColor.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? widget.roleColor : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? widget.roleColor
                        : (isDark ? Colors.white70 : Colors.black87),
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
        'desc': 'حلقة ضوئية زرقاء مستقبلية ثلاثية الأبعاد',
        'color': const Color(0xFF0EA5E9),
      },
      {
        'id': 'royal_gold',
        'title': 'المنصة الملكية الذهبية 👑',
        'desc': 'قاعدة ذهبية فخمة للأوائل والرواد',
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
