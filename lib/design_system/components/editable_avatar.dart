import 'package:flutter/material.dart';
import '../../core/services/avatar_service.dart';
import '../tokens/colors.dart';

/// Interactive, responsive Avatar component supporting 1-tap photo picking,
/// educational presets selection, URL input, and photo removal.
class EditableAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String fullName;
  final double radius;
  final Color? roleColor;
  final String? role;
  final String? userId;
  final String? userEmail;
  final ValueChanged<String?>? onAvatarChanged;
  final bool canEdit;

  EditableAvatar({
    super.key,
    required this.avatarUrl,
    String? fullName,
    String? name,
    this.radius = 42,
    this.roleColor,
    this.role,
    this.userId,
    this.userEmail,
    this.onAvatarChanged,
    this.canEdit = true,
  }) : fullName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : (name != null && name.isNotEmpty ? name : 'User');

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  String? _currentAvatarUrl;

  Color get _resolvedColor {
    if (widget.roleColor != null) return widget.roleColor!;
    final r = widget.role?.toLowerCase() ?? '';
    if (r.contains('admin')) return AppColors.adminRole;
    if (r.contains('teacher')) return AppColors.teacherRole;
    if (r.contains('student')) return AppColors.studentRole;
    if (r.contains('parent')) return AppColors.parentRole;
    if (r.contains('staff')) return AppColors.info;
    return AppColors.primary;
  }

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.avatarUrl;
  }

  @override
  void didUpdateWidget(covariant EditableAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      setState(() {
        _currentAvatarUrl = widget.avatarUrl;
      });
    }
  }

  Future<void> _handleTap() async {
    if (!widget.canEdit) return;

    final newUrl = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AvatarPickerBottomSheet(
        currentAvatarUrl: _currentAvatarUrl,
        fullName: widget.fullName,
        roleColor: _resolvedColor,
        userId: widget.userId,
        userEmail: widget.userEmail,
      ),
    );
    if (mounted) {
      if (newUrl != null || _currentAvatarUrl != null) {
        setState(() {
          _currentAvatarUrl = newUrl;
        });
      }
      widget.onAvatarChanged?.call(newUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _resolvedColor;
    final imageProvider = AvatarService.getImageProvider(_currentAvatarUrl);

    final initial = widget.fullName.trim().isNotEmpty
        ? widget.fullName.trim()[0].toUpperCase()
        : 'U';

    return GestureDetector(
      onTap: widget.canEdit ? _handleTap : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow / Ring
          Container(
            width: widget.radius * 2 + 6,
            height: widget.radius * 2 + 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              radius: widget.radius,
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              backgroundImage: imageProvider,
              onBackgroundImageError: imageProvider != null ? (_, __) {} : null,
              child: imageProvider == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: widget.radius * 0.9,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    )
                  : null,
            ),
          ),

          // Camera Edit Badge
          if (widget.canEdit)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom Sheet UI allowing user to pick from device gallery, choose educational presets,
/// input URL, or remove photo.
class AvatarPickerBottomSheet extends StatefulWidget {
  final String? currentAvatarUrl;
  final String fullName;
  final Color roleColor;
  final String? userId;
  final String? userEmail;

  const AvatarPickerBottomSheet({
    super.key,
    required this.currentAvatarUrl,
    required this.fullName,
    required this.roleColor,
    this.userId,
    this.userEmail,
  });

  static Future<String?> show({
    required BuildContext context,
    String? currentAvatarUrl,
    String? fullName,
    String? userName,
    Color? roleColor,
    String? userRole,
    String? userId,
    String? userEmail,
    ValueChanged<String?>? onAvatarSelected,
  }) async {
    Color computedColor = roleColor ?? AppColors.primary;
    if (userRole != null) {
      final r = userRole.toLowerCase();
      if (r.contains('admin')) {
        computedColor = AppColors.adminRole;
      } else if (r.contains('teacher')) {
        computedColor = AppColors.teacherRole;
      } else if (r.contains('student')) {
        computedColor = AppColors.studentRole;
      } else if (r.contains('parent')) {
        computedColor = AppColors.parentRole;
      } else if (r.contains('staff')) {
        computedColor = AppColors.info;
      }
    }

    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AvatarPickerBottomSheet(
        currentAvatarUrl: currentAvatarUrl,
        fullName: (fullName != null && fullName.isNotEmpty)
            ? fullName
            : (userName != null && userName.isNotEmpty ? userName : 'مستخدم'),
        roleColor: computedColor,
        userId: userId,
        userEmail: userEmail,
      ),
    );

    if (result != null || result == null && currentAvatarUrl != null) {
      onAvatarSelected?.call(result);
    }
    return result;
  }

  @override
  State<AvatarPickerBottomSheet> createState() => _AvatarPickerBottomSheetState();
}

class _AvatarPickerBottomSheetState extends State<AvatarPickerBottomSheet> {
  bool _isLoading = false;
  String? _selectedUrl;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.currentAvatarUrl;
  }

  Future<void> _applyAvatar(String? url) async {
    setState(() => _isLoading = true);

    if (widget.userId != null && widget.userId!.isNotEmpty) {
      await AvatarService.updateUserAvatar(
        userId: widget.userId!,
        newAvatarUrl: url,
        userEmail: widget.userEmail,
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _selectedUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الصورة الشخصية بنجاح! ✨'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, url);
    }
  }

  Future<void> _pickFromDevice() async {
    setState(() => _isLoading = true);
    final uploadedUrl = await AvatarService.pickAndUploadAvatar(
      userId: widget.userId ?? 'user',
    );
    if (!mounted) return;

    if (uploadedUrl != null) {
      await _applyAvatar(uploadedUrl);
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _promptDirectUrl() {
    final ctrl = TextEditingController(text: _selectedUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رابط الصورة الشخصية'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'https://example.com/photo.png',
              labelText: 'أدخل رابط الصورة (URL)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final text = ctrl.text.trim();
                Navigator.pop(ctx);
                if (text.isNotEmpty) {
                  _applyAvatar(text);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final imageProvider = AvatarService.getImageProvider(_selectedUrl);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تعديل الصورة الشخصية 📷',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Preview Avatar
              CircleAvatar(
                radius: 46,
                backgroundColor: widget.roleColor.withValues(alpha: 0.15),
                backgroundImage: imageProvider,
                onBackgroundImageError: imageProvider != null ? (_, __) {} : null,
                child: imageProvider == null
                    ? Text(
                        widget.fullName.trim().isNotEmpty
                            ? widget.fullName.trim()[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: widget.roleColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                widget.fullName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoading) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('جاري رفع وتحديث الصورة الشخصية...'),
                    ],
                  ),
                ),
              ] else ...[
                // Main Option: Pick from Gallery/Device
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.roleColor,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _pickFromDevice,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text(
                    'اختيار صورة من المعرض أو الجهاز 📁',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),

                // Presets Section
                Row(
                  children: [
                    Text(
                      'أو اختر شخصية رمزية جاهزة 🎭:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: AvatarService.educationalPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      final p = AvatarService.educationalPresets[idx];
                      final isSelected = (_selectedUrl == p.url);

                      return InkWell(
                        onTap: () => _applyAvatar(p.url),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? widget.roleColor : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: widget.roleColor.withValues(alpha: 0.1),
                            backgroundImage: AvatarService.getImageProvider(p.url),
                            onBackgroundImageError: (_, __) {},
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary actions: Direct URL & Remove Photo
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _promptDirectUrl,
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('رابط مباشر'),
                      ),
                    ),
                    if (_selectedUrl != null && _selectedUrl!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _applyAvatar(null),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('إزالة الصورة'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
