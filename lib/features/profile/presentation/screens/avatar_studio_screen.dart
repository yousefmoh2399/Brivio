import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/models/avatar_builder_model.dart';
import '../../../../core/services/avatar_service.dart';
import '../../../../design_system/tokens/colors.dart';
import 'package:brivio/features/avatar/presentation/screens/snapchat_avatar_studio_screen.dart';

/// Interactive, Snapchat Bitmoji-style Avatar Studio Screen
class AvatarStudioScreen extends StatefulWidget {
  final String? userId;
  final String? userEmail;
  final String? initialAvatarUrl;
  final Color roleColor;
  final ValueChanged<String>? onAvatarSaved;

  const AvatarStudioScreen({
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
        builder: (_) => AvatarStudioScreen(
          userId: userId,
          userEmail: userEmail,
          initialAvatarUrl: initialAvatarUrl,
          roleColor: roleColor,
        ),
      ),
    );
  }

  @override
  State<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends State<AvatarStudioScreen> {
  late AvatarConfig _config;
  int _activeCategoryIndex = 0;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'الجنس والأسلوب', 'icon': Icons.face_retouching_natural_rounded},
    {'title': 'لون البشرة', 'icon': Icons.palette_rounded},
    {'title': 'الشعر والحجاب', 'icon': Icons.content_cut_rounded},
    {'title': 'العيون والحواجب', 'icon': Icons.remove_red_eye_rounded},
    {'title': 'التعبيرات', 'icon': Icons.mood_rounded},
    {'title': 'اللحية والشارب', 'icon': Icons.face_rounded},
    {'title': 'النظارات', 'icon': Icons.visibility_rounded},
    {'title': 'الملابس', 'icon': Icons.checkroom_rounded},
    {'title': 'الخلفية', 'icon': Icons.wallpaper_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _config = const AvatarConfig();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    if (widget.userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('brivio_avatar_builder_${widget.userId}');
      if (savedStr != null) {
        final map = jsonDecode(savedStr) as Map<String, dynamic>;
        setState(() {
          _config = AvatarConfig.fromJson(map);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveConfigLocally(AvatarConfig config) async {
    if (widget.userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'brivio_avatar_builder_${widget.userId}',
        jsonEncode(config.toJson()),
      );
    } catch (_) {}
  }

  void _randomize() {
    HapticFeedback.lightImpact();
    setState(() {
      _config = AvatarConfig.randomize(targetGender: _config.gender);
    });
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _config = const AvatarConfig();
    });
  }

  Future<void> _saveAndApply() async {
    setState(() => _isSaving = true);
    final avatarUrl = _config.toUrl();

    // 1. Save config locally for re-editing
    await _saveConfigLocally(_config);

    // 2. Persist in Supabase and sync local accounts
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      await AvatarService.updateUserAvatar(
        userId: widget.userId!,
        newAvatarUrl: avatarUrl,
        userEmail: widget.userEmail,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    widget.onAvatarSaved?.call(avatarUrl);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تصميم وحفظ الأفاتار الخاص بك بنجاح! 🌟'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(avatarUrl);
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);

    final avatarUrl = _config.toUrl();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0.5,
          title: const Text(
            'استوديو تصميم الأفاتار 🎨',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              tooltip: 'استوديو Bitmoji 3D الاحترافي ✨',
              icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEC4899)),
              onPressed: () async {
                final nav = Navigator.of(context);
                final res = await SnapchatAvatarStudioScreen.open(
                  context: context,
                  userId: widget.userId,
                  userEmail: widget.userEmail,
                  initialAvatarUrl: widget.initialAvatarUrl,
                  roleColor: widget.roleColor,
                );
                if (res != null && res.isNotEmpty) {
                  widget.onAvatarSaved?.call(res);
                  nav.pop(res);
                }
              },
            ),
            IconButton(
              tooltip: 'توليد مظهر عشوائي',
              icon: const Icon(Icons.casino_rounded, color: AppColors.warning),
              onPressed: _randomize,
            ),
            IconButton(
              tooltip: 'إعادة ضبط',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: _reset,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // ── Live Canvas & Character Preview ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar Viewport
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [widget.roleColor, widget.roleColor.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.roleColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(5),
                    child: ClipOval(
                      child: Container(
                        color: _hexToColor(_config.backgroundColor),
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            );
                          },
                          errorBuilder: (ctx, err, stack) => const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Style Selector Chips
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildStyleChip('avataaars', 'شخصية Bitmoji 👱', isDark),
                      _buildStyleChip('adventurer', 'مغامر أنمي ⚔️', isDark),
                      _buildStyleChip('bottts', 'روبوت ذكي 🤖', isDark),
                      _buildStyleChip('lorelei', 'أيقونة ناعمة 🌸', isDark),
                    ],
                  ),
                ],
              ),
            ),

            // ── Horizontal Categories Bar ──
            Container(
              height: 52,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final cat = _categories[idx];
                  final isSelected = (_activeCategoryIndex == idx);
                  return ChoiceChip(
                    avatar: Icon(
                      cat['icon'] as IconData,
                      size: 17,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                    label: Text(cat['title'] as String),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : textPrimary,
                    ),
                    selected: isSelected,
                    selectedColor: widget.roleColor,
                    backgroundColor: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? widget.roleColor : Colors.transparent,
                      ),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _activeCategoryIndex = idx);
                    },
                  );
                },
              ),
            ),

            // ── Interactive Options Panel ──
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: _buildCategoryOptions(isDark, textPrimary, textSecondary),
              ),
            ),

            // ── Sticky Save & Apply Button ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.roleColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSaving ? null : _saveAndApply,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(
                    _isSaving ? 'جاري حفظ مظهرك الجديد...' : 'حفظ وتعيين كصورتي الشخصية ✨',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleChip(String styleKey, String label, bool isDark) {
    final isSelected = _config.style == styleKey;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      selected: isSelected,
      selectedColor: widget.roleColor,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() {
          _config = _config.copyWith(style: styleKey);
        });
      },
    );
  }

  Widget _buildCategoryOptions(bool isDark, Color textPrimary, Color textSecondary) {
    switch (_activeCategoryIndex) {
      // 0: Gender & Base
      case 0:
        return ListView(
          children: [
            const Text('الجنس والمظهر الأساسي:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSelectCard(
                    title: 'ولد / شاب 👦',
                    isSelected: _config.gender == 'male',
                    onTap: () {
                      setState(() {
                        _config = _config.copyWith(
                          gender: 'male',
                          hairStyle: 'shortCurly',
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSelectCard(
                    title: 'بنت / فتاة 👧',
                    isSelected: _config.gender == 'female',
                    onTap: () {
                      setState(() {
                        _config = _config.copyWith(
                          gender: 'female',
                          hairStyle: 'straight01',
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        );

      // 1: Skin Tone
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر درجة لون البشرة:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.9,
                ),
                itemCount: AvatarConfig.skinColors.length,
                itemBuilder: (ctx, i) {
                  final sc = AvatarConfig.skinColors[i];
                  final isSelected = (_config.skinColor == sc['hex']);
                  return _buildColorSwatchItem(
                    title: sc['name']!,
                    hex: sc['hex']!,
                    isSelected: isSelected,
                    onTap: () => setState(() => _config = _config.copyWith(skinColor: sc['hex'])),
                  );
                },
              ),
            ),
          ],
        );

      // 2: Hair & Hijab
      case 2:
        final filteredHair = AvatarConfig.hairStyles
            .where((h) => h['gender'] == _config.gender || h['gender'] == 'neutral')
            .toList();

        return ListView(
          children: [
            const Text('لون الشعر:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AvatarConfig.hairColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final hc = AvatarConfig.hairColors[i];
                  final isSelected = (_config.hairColor == hc['hex']);
                  return GestureDetector(
                    onTap: () => setState(() => _config = _config.copyWith(hairColor: hc['hex'])),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _hexToColor(hc['hex']!),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? widget.roleColor : Colors.white24,
                          width: isSelected ? 3.5 : 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text('قصة الشعر أو غطاء الرأس:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filteredHair.map((h) {
                final isSelected = (_config.hairStyle == h['id']);
                return ChoiceChip(
                  label: Text(h['name']!),
                  selected: isSelected,
                  selectedColor: widget.roleColor,
                  onSelected: (_) => setState(() => _config = _config.copyWith(hairStyle: h['id'])),
                );
              }).toList(),
            ),
          ],
        );

      // 3: Eyes & Eyebrows
      case 3:
        return ListView(
          children: [
            const Text('شكل العيون:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AvatarConfig.eyeOptions.map((e) {
                final isSelected = (_config.eyes == e['id']);
                return ChoiceChip(
                  label: Text(e['name']!),
                  selected: isSelected,
                  selectedColor: widget.roleColor,
                  onSelected: (_) => setState(() => _config = _config.copyWith(eyes: e['id'])),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            const Text('شكل الحواجب:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AvatarConfig.eyebrowOptions.map((eb) {
                final isSelected = (_config.eyebrows == eb['id']);
                return ChoiceChip(
                  label: Text(eb['name']!),
                  selected: isSelected,
                  selectedColor: widget.roleColor,
                  onSelected: (_) => setState(() => _config = _config.copyWith(eyebrows: eb['id'])),
                );
              }).toList(),
            ),
          ],
        );

      // 4: Expressions & Mouth
      case 4:
        return ListView(
          children: [
            const Text('تعبيرات الوجه والابتسامة:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AvatarConfig.mouthOptions.map((m) {
                final isSelected = (_config.mouth == m['id']);
                return ChoiceChip(
                  label: Text(m['name']!),
                  selected: isSelected,
                  selectedColor: widget.roleColor,
                  onSelected: (_) => setState(() => _config = _config.copyWith(mouth: m['id'])),
                );
              }).toList(),
            ),
          ],
        );

      // 5: Beard & Moustache
      case 5:
        return ListView(
          children: [
            const Text('شعر الوجه (لحية / شارب):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AvatarConfig.facialHairOptions.map((fh) {
                final isSelected = (_config.facialHair == fh['id']);
                return ChoiceChip(
                  label: Text(fh['name']!),
                  selected: isSelected,
                  selectedColor: widget.roleColor,
                  onSelected: (_) => setState(() => _config = _config.copyWith(facialHair: fh['id'])),
                );
              }).toList(),
            ),
          ],
        );

      // 6: Eyewear & Accessories
      case 6:
        return ListView(
          children: [
            const Text('النظارات والإكسسوارات:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AvatarConfig.accessoryOptions.map((acc) {
                final isSelected = (_config.accessories == acc['id']);
                return ChoiceChip(
                  label: Text(acc['name']!),
                  selected: isSelected,
                  selectedColor: widget.roleColor,
                  onSelected: (_) => setState(() => _config = _config.copyWith(accessories: acc['id'])),
                );
              }).toList(),
            ),
          ],
        );

      // 7: Outfits
      case 7:
        return ListView(
          children: [
            const Text('لون الملابس:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AvatarConfig.clothingColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final cc = AvatarConfig.clothingColors[i];
                  final isSelected = (_config.clothingColor == cc['hex']);
                  return GestureDetector(
                    onTap: () => setState(() => _config = _config.copyWith(clothingColor: cc['hex'])),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _hexToColor(cc['hex']!),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? widget.roleColor : Colors.white24,
                          width: isSelected ? 3.5 : 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text('نوع الملابس والزي:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AvatarConfig.clothingOptions.map((cl) {
                final isSelected = (_config.clothing == cl['id']);
                return ChoiceChip(
                  label: Text(cl['name']!),
                  selected: isSelected,
                  selectedColor: widget.roleColor,
                  onSelected: (_) => setState(() => _config = _config.copyWith(clothing: cl['id'])),
                );
              }).toList(),
            ),
          ],
        );

      // 8: Background Color
      case 8:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر لون الخلفية المحيطة:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.9,
                ),
                itemCount: AvatarConfig.backgroundColors.length,
                itemBuilder: (ctx, i) {
                  final bg = AvatarConfig.backgroundColors[i];
                  final isSelected = (_config.backgroundColor == bg['hex']);
                  return _buildColorSwatchItem(
                    title: bg['name']!,
                    hex: bg['hex']!,
                    isSelected: isSelected,
                    onTap: () => setState(() => _config = _config.copyWith(backgroundColor: bg['hex'])),
                  );
                },
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSelectCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? widget.roleColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? widget.roleColor : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isSelected ? widget.roleColor : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatchItem({
    required String title,
    required String hex,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = _hexToColor(hex);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? widget.roleColor : Colors.black12,
                width: isSelected ? 3.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 24, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
