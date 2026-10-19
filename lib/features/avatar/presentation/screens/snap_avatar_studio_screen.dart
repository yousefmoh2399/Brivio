import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/avatar_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../domain/models/avatar_config.dart';

// ============================================================
//  Snapchat Avatar Studio — Complete Redesign
//  Real DiceBear Avataaars API integration + Snap-style UI
// ============================================================

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

class _SnapAvatarStudioScreenState extends State<SnapAvatarStudioScreen>
    with TickerProviderStateMixin {
  late AvatarConfig _config;
  AvatarSection _activeSection = AvatarSection.skin;
  bool _isSaving = false;
  bool _isLoading = false;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Avatar preview key for capture
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _config = AvatarConfig(
      seed: widget.userId ?? 'BrivioUser_${DateTime.now().millisecondsSinceEpoch}',
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _loadSaved();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    if (widget.userId == null) return;
    try {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      final key = 'snap_avatar_config_${widget.userId}';
      final json = prefs.getString(key);
      if (json != null && json.isNotEmpty) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        setState(() => _config = AvatarConfig.fromJson(map));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _persistLocally() async {
    if (widget.userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'snap_avatar_config_${widget.userId}',
        jsonEncode(_config.toJson()),
      );
    } catch (_) {}
  }

  void _updateConfig(AvatarConfig updated) {
    HapticFeedback.selectionClick();
    setState(() => _config = updated);
  }

  void _randomize() {
    HapticFeedback.mediumImpact();
    setState(() => _config = AvatarConfig.randomize(seed: 'random_${DateTime.now().millisecondsSinceEpoch}'));
  }

  Future<void> _saveAvatar() async {
    if (_isSaving) return;
    HapticFeedback.heavyImpact();
    setState(() => _isSaving = true);

    try {
      // Build the avatar URL
      final avatarUrl = _config.buildAvatarUrl(size: 512);

      // Persist config locally
      await _persistLocally();

      // Update user profile
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('تم حفظ أفاتارك بنجاح! ✨',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(avatarUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 768;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: isTablet
          ? _buildTabletLayout(isDark)
          : _buildMobileLayout(isDark),
    );
  }

  // ── Tablet: Side-by-side layout ──────────────────────────────────────────
  Widget _buildTabletLayout(bool isDark) {
    return Row(
      children: [
        // Left: Full-height avatar preview
        SizedBox(
          width: 380,
          child: Column(
            children: [
              _buildTopBar(isDark),
              Expanded(child: _buildAvatarPreviewPanel(isDark)),
            ],
          ),
        ),
        // Right: Customization panel
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: 60), // Space for top bar alignment
              _buildSectionTabs(isDark),
              Expanded(child: _buildSectionContent(isDark, isWide: true)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Mobile: Stack layout (preview top, editor bottom) ──────────────────
  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        // Top bar
        _buildTopBar(isDark),
        // Avatar preview (40% of screen)
        Expanded(
          flex: 42,
          child: _buildAvatarPreviewPanel(isDark),
        ),
        // Category tabs (Snapchat-style horizontal scroll)
        _buildSectionTabs(isDark),
        // Options panel (58% of screen)
        Expanded(
          flex: 58,
          child: _buildSectionContent(isDark, isWide: false),
        ),
      ],
    );
  }

  // ── Top app bar ──────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isDark) {
    final bg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    return Container(
      height: 56 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 4,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Studio title
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.roleColor, widget.roleColor.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'استوديو الأفاتار',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Randomize button
          IconButton(
            tooltip: 'عشوائي 🎲',
            icon: const Icon(Icons.shuffle_rounded, color: AppColors.warning),
            onPressed: _randomize,
          ),
          // Save button
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.roleColor,
                minimumSize: const Size(80, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isSaving ? null : _saveAvatar,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.0, color: Colors.white),
                    )
                  : const Text(
                      'حفظ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar Preview Panel ─────────────────────────────────────────────────
  Widget _buildAvatarPreviewPanel(bool isDark) {
    final avatarUrl = _config.buildAvatarUrl(size: 400);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _config.backgroundColor.withValues(alpha: 0.3),
            _config.backgroundColor.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle glow
          Positioned(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _config.backgroundColor.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Avatar — animated scale pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            ),
            child: RepaintBoundary(
              key: _previewKey,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _config.backgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: _config.backgroundColor.withValues(alpha: 0.6),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) => _buildAvatarFallback(),
                      ),
              ),
            ),
          ),

          // Bottom: background color picker (quick access)
          Positioned(
            bottom: 12,
            child: _buildQuickBgPicker(isDark),
          ),
        ],
      ),
    );
  }


  /// Fallback when avatar image fails to load (no network / API error)
  Widget _buildAvatarFallback() {
    final initials = (widget.userEmail ?? 'A').substring(0, 1).toUpperCase();
    return Container(
      color: _config.backgroundColor,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: widget.roleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickBgPicker(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'الخلفية',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          ...AvatarConfig.backgroundColors.take(8).map((color) {
            final selected = _config.backgroundColor == color;
            return GestureDetector(
              onTap: () => _updateConfig(_config.copyWith(backgroundColor: color)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: selected ? 22 : 18,
                height: selected ? 22 : 18,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? widget.roleColor : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: widget.roleColor.withValues(alpha: 0.5), blurRadius: 8)]
                      : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Section Tabs (Snapchat-style) ────────────────────────────────────────
  Widget _buildSectionTabs(bool isDark) {
    final bg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final sections = AvatarSection.values;

    return Container(
      height: 64,
      color: bg,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final s = sections[i];
          final isActive = s == _activeSection;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeSection = s);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? widget.roleColor
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: widget.roleColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Section Content ──────────────────────────────────────────────────────
  Widget _buildSectionContent(bool isDark, {required bool isWide}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(_activeSection),
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF8F9FA),
        child: _buildOptionsForSection(isDark, isWide: isWide),
      ),
    );
  }

  Widget _buildOptionsForSection(bool isDark, {required bool isWide}) {
    switch (_activeSection) {
      case AvatarSection.skin:
        return _buildColorGrid(
          isDark: isDark,
          options: AvatarConfig.skinOptions,
          selectedId: _config.skinColor,
          onSelect: (id) => _updateConfig(_config.copyWith(skinColor: id)),
          isColorPicker: true,
        );

      case AvatarSection.hair:
        return _buildOptionGrid(
          isDark: isDark,
          options: AvatarConfig.hairStyleOptions,
          selectedId: _config.hairStyle,
          onSelect: (id) => _updateConfig(_config.copyWith(hairStyle: id)),
          showPreview: true,
          previewBaseUrl: _config.buildAvatarUrl(size: 120),
        );

      case AvatarSection.hairColor:
        return _buildColorGrid(
          isDark: isDark,
          options: AvatarConfig.hairColorOptions,
          selectedId: _config.hairColor,
          onSelect: (id) => _updateConfig(_config.copyWith(hairColor: id)),
          isColorPicker: true,
        );

      case AvatarSection.eyes:
        return _buildOptionGrid(
          isDark: isDark,
          options: AvatarConfig.eyesOptions,
          selectedId: _config.eyes,
          onSelect: (id) => _updateConfig(_config.copyWith(eyes: id)),
          showPreview: false,
        );

      case AvatarSection.eyebrows:
        return _buildOptionGrid(
          isDark: isDark,
          options: AvatarConfig.eyebrowsOptions,
          selectedId: _config.eyebrows,
          onSelect: (id) => _updateConfig(_config.copyWith(eyebrows: id)),
          showPreview: false,
        );

      case AvatarSection.mouth:
        return _buildOptionGrid(
          isDark: isDark,
          options: AvatarConfig.mouthOptions,
          selectedId: _config.mouth,
          onSelect: (id) => _updateConfig(_config.copyWith(mouth: id)),
          showPreview: false,
        );

      case AvatarSection.facialHair:
        return _buildOptionGrid(
          isDark: isDark,
          options: AvatarConfig.facialHairOptions,
          selectedId: _config.facialHair,
          onSelect: (id) => _updateConfig(_config.copyWith(facialHair: id)),
          showPreview: false,
        );

      case AvatarSection.eyewear:
        return _buildOptionGrid(
          isDark: isDark,
          options: AvatarConfig.eyewearOptions,
          selectedId: _config.eyewear,
          onSelect: (id) => _updateConfig(_config.copyWith(eyewear: id)),
          showPreview: false,
        );

      case AvatarSection.headwear:
        return _buildHeadwearSection(isDark);

      case AvatarSection.outfit:
        return _buildOutfitSection(isDark);

      case AvatarSection.background:
        return _buildBackgroundSection(isDark);

      case AvatarSection.style:
        return _buildStyleSection(isDark);
    }
  }

  // ── Generic option grid ─────────────────────────────────────────────────
  Widget _buildOptionGrid({
    required bool isDark,
    required List<AvatarOption> options,
    required String selectedId,
    required ValueChanged<String> onSelect,
    bool showPreview = false,
    String? previewBaseUrl,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: options.length,
      itemBuilder: (context, i) {
        final opt = options[i];
        final selected = opt.id == selectedId;
        return _OptionTile(
          option: opt,
          isSelected: selected,
          roleColor: widget.roleColor,
          isDark: isDark,
          onTap: () => onSelect(opt.id),
          avatarPreviewUrl: showPreview ? _buildPreviewUrl(opt.id) : null,
        );
      },
    );
  }

  String _buildPreviewUrl(String hairStyle) {
    return _config.copyWith(hairStyle: hairStyle).buildAvatarUrl(size: 120);
  }

  // ── Color grid ───────────────────────────────────────────────────────────
  Widget _buildColorGrid({
    required bool isDark,
    required List<AvatarOption> options,
    required String selectedId,
    required ValueChanged<String> onSelect,
    bool isColorPicker = false,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: options.length,
      itemBuilder: (context, i) {
        final opt = options[i];
        final selected = opt.id == selectedId;
        final color = opt.previewColor ?? Colors.grey;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(opt.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? widget.roleColor : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: widget.roleColor.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      },
    );
  }

  // ── Headwear section ─────────────────────────────────────────────────────
  Widget _buildHeadwearSection(bool isDark) {
    return Column(
      children: [
        // Hat color row
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          child: Row(
            children: [
              Text(
                'لون الغطاء:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: AvatarConfig.outfitColorOptions.map((opt) {
                    final sel = opt.id == _config.headwearColor;
                    return GestureDetector(
                      onTap: () => _updateConfig(_config.copyWith(headwearColor: opt.id)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: sel ? 34 : 28,
                        height: sel ? 34 : 28,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: opt.previewColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? widget.roleColor : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // Hat style grid (reuse hair styles that include hats)
        Expanded(
          child: _buildOptionGrid(
            isDark: isDark,
            options: const [
              AvatarOption(id: 'noHat', label: 'بدون', emoji: '👤'),
              AvatarOption(id: 'hijab', label: 'حجاب', emoji: '🧕'),
              AvatarOption(id: 'turban', label: 'عمامة', emoji: '👳'),
              AvatarOption(id: 'winterHat01', label: 'قبعة شتوية', emoji: '🧢'),
              AvatarOption(id: 'winterHat02', label: 'قبعة كولد', emoji: '❄️'),
              AvatarOption(id: 'hat', label: 'قبعة كلاسيك', emoji: '🎩'),
            ],
            selectedId: _config.headwear,
            onSelect: (id) => _updateConfig(_config.copyWith(headwear: id)),
          ),
        ),
      ],
    );
  }

  // ── Outfit section ───────────────────────────────────────────────────────
  Widget _buildOutfitSection(bool isDark) {
    return Column(
      children: [
        // Outfit color row
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          child: Row(
            children: [
              Text(
                'اللون:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: AvatarConfig.outfitColorOptions.map((opt) {
                    final sel = opt.id == _config.outfitColor;
                    return GestureDetector(
                      onTap: () => _updateConfig(_config.copyWith(outfitColor: opt.id)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: sel ? 34 : 28,
                        height: sel ? 34 : 28,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: opt.previewColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? widget.roleColor : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // Outfit type grid
        Expanded(
          child: _buildOptionGrid(
            isDark: isDark,
            options: AvatarConfig.outfitOptions,
            selectedId: _config.outfit,
            onSelect: (id) => _updateConfig(_config.copyWith(outfit: id)),
          ),
        ),
      ],
    );
  }

  // ── Background section ───────────────────────────────────────────────────
  Widget _buildBackgroundSection(bool isDark) {
    final colors = AvatarConfig.backgroundColors;
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: colors.length,
      itemBuilder: (context, i) {
        final color = colors[i];
        final selected = _config.backgroundColor == color;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _updateConfig(_config.copyWith(backgroundColor: color));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? widget.roleColor : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: widget.roleColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: selected
                ? Icon(
                    Icons.check_circle_rounded,
                    color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                    size: 26,
                  )
                : null,
          ),
        );
      },
    );
  }

  // ── Style presets section ────────────────────────────────────────────────
  Widget _buildStyleSection(bool isDark) {
    final presets = [
      _PresetStyle(
        name: 'طالب كلاسيك',
        emoji: '📚',
        config: const AvatarConfig(
          skinColor: 'F9C9B6',
          hairStyle: 'shortFlat',
          hairColor: '2C1B18',
          eyes: 'default',
          eyebrows: 'default',
          mouth: 'smile',
          outfit: 'hoodie',
          outfitColor: '0EA5E9',
          backgroundColor: Color(0xFFE0F2FE),
        ),
      ),
      _PresetStyle(
        name: 'طالبة بالحجاب',
        emoji: '🧕',
        config: const AvatarConfig(
          skinColor: 'F5CFA0',
          hairStyle: 'hijab',
          hairColor: '2C1B18',
          eyes: 'happy',
          eyebrows: 'raisedExcited',
          mouth: 'smile',
          outfit: 'blazerAndShirt',
          outfitColor: '6366F1',
          backgroundColor: Color(0xFFF3E8FF),
        ),
      ),
      _PresetStyle(
        name: 'معلم محترف',
        emoji: '👨‍🏫',
        config: const AvatarConfig(
          skinColor: 'EAAD80',
          hairStyle: 'shortFlat',
          hairColor: '2C1B18',
          eyes: 'default',
          eyebrows: 'defaultNatural',
          mouth: 'smile',
          facialHair: 'beardLight',
          eyewear: 'prescription01',
          outfit: 'blazerAndShirt',
          outfitColor: '1E293B',
          backgroundColor: Color(0xFFDCFCE7),
        ),
      ),
      _PresetStyle(
        name: 'معلمة أكاديمية',
        emoji: '👩‍🏫',
        config: const AvatarConfig(
          skinColor: 'F9C9B6',
          hairStyle: 'longButNotTooLong',
          hairColor: '451A03',
          eyes: 'wink',
          eyebrows: 'raisedExcitedNatural',
          mouth: 'smile',
          eyewear: 'kurt',
          outfit: 'blazerAndSweater',
          outfitColor: '4F46E5',
          backgroundColor: Color(0xFFE0E7FF),
        ),
      ),
      _PresetStyle(
        name: 'مبرمج تقني',
        emoji: '💻',
        config: const AvatarConfig(
          skinColor: 'AE5D29',
          hairStyle: 'shortCurly',
          hairColor: '2C1B18',
          eyes: 'squint',
          eyebrows: 'flatNatural',
          mouth: 'serious',
          eyewear: 'sunglasses',
          outfit: 'graphicShirt',
          outfitColor: '0F172A',
          backgroundColor: Color(0xFF1A1A2E),
        ),
      ),
      _PresetStyle(
        name: 'رياضي نشيط',
        emoji: '🏆',
        config: const AvatarConfig(
          skinColor: 'D08B5B',
          hairStyle: 'shavedSides',
          hairColor: '2C1B18',
          eyes: 'happy',
          eyebrows: 'raisedExcited',
          mouth: 'twinkle',
          outfit: 'overall',
          outfitColor: 'EF4444',
          backgroundColor: Color(0xFFFFE4E6),
        ),
      ),
      _PresetStyle(
        name: 'فنان مبدع',
        emoji: '🎨',
        config: const AvatarConfig(
          skinColor: 'F5CFA0',
          hairStyle: 'bigHair',
          hairColor: 'B58143',
          eyes: 'winkWacky',
          eyebrows: 'upDown',
          mouth: 'tongue',
          outfit: 'graphicShirt',
          outfitColor: 'F59E0B',
          backgroundColor: Color(0xFFFEF3C7),
        ),
      ),
      _PresetStyle(
        name: 'طبيب / دكتور',
        emoji: '⚕️',
        config: const AvatarConfig(
          skinColor: 'F9C9B6',
          hairStyle: 'shortFlat',
          hairColor: '2C1B18',
          eyes: 'default',
          eyebrows: 'default',
          mouth: 'smile',
          eyewear: 'round',
          outfit: 'blazerAndShirt',
          outfitColor: 'FFFFFF',
          backgroundColor: Color(0xFFDCFCE7),
        ),
      ),
      _PresetStyle(
        name: 'مدير تنفيذي',
        emoji: '👔',
        config: const AvatarConfig(
          skinColor: '614335',
          hairStyle: 'shortFlat',
          hairColor: '2C1B18',
          eyes: 'default',
          eyebrows: 'defaultNatural',
          mouth: 'smile',
          facialHair: 'beardMedium',
          outfit: 'blazerAndShirt',
          outfitColor: '0F172A',
          backgroundColor: Color(0xFFF9FAFB),
        ),
      ),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: presets.length,
      itemBuilder: (context, i) {
        final preset = presets[i];
        final previewUrl = preset.config.buildAvatarUrl(size: 150);

        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _updateConfig(preset.config.copyWith(
              seed: _config.seed,
            ));
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: preset.config.backgroundColor,
                    width: double.infinity,
                    child: Image.network(
                      previewUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  child: Column(
                    children: [
                      Text(preset.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        preset.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Option Tile Widget ────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final AvatarOption option;
  final bool isSelected;
  final Color roleColor;
  final bool isDark;
  final VoidCallback onTap;
  final String? avatarPreviewUrl;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.roleColor,
    required this.isDark,
    required this.onTap,
    this.avatarPreviewUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? roleColor.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? roleColor : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: roleColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (avatarPreviewUrl != null)
              Expanded(
                child: Image.network(
                  avatarPreviewUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    );
                  },
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    color: isSelected ? roleColor : Colors.grey,
                    size: 30,
                  ),
                ),
              )
            else if (option.emoji != null)
              Text(option.emoji!, style: const TextStyle(fontSize: 26))
            else
              Icon(
                Icons.auto_awesome,
                color: isSelected ? roleColor : Colors.grey,
                size: 26,
              ),
            if (avatarPreviewUrl == null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? roleColor
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Preset data class ─────────────────────────────────────────────────────
class _PresetStyle {
  final String name;
  final String emoji;
  final AvatarConfig config;

  const _PresetStyle({
    required this.name,
    required this.emoji,
    required this.config,
  });
}

// ── Backward-compatibility alias ───────────────────────────────────────────
// All existing code that imports SnapchatAvatarStudioScreen will continue
// to work without any changes — it now points to the new DiceBear studio.
typedef SnapchatAvatarStudioScreen = SnapAvatarStudioScreen;
