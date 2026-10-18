import 'package:flutter/material.dart';

import '../../../../design_system/components/editable_avatar.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

class TeacherProfileScreen extends StatefulWidget {
  final AuthViewModel authViewModel;

  const TeacherProfileScreen({super.key, required this.authViewModel});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _avatarController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.authViewModel.currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _avatarController = TextEditingController(text: user?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    await widget.authViewModel.updateProfile(
      fullName: _nameController.text,
      phoneNumber: _phoneController.text,
      avatarUrl: _avatarController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    final failure = widget.authViewModel.state.failure;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? 'Profile updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final user = widget.authViewModel.currentUser;
    final bootstrap = widget.authViewModel.bootstrap;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FadeInSlide(
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      EditableAvatar(
                        avatarUrl: _avatarController.text,
                        name: _nameController.text.isNotEmpty
                            ? _nameController.text
                            : (user?.fullName ?? 'معلم'),
                        role: 'teacher',
                        userId: user?.id,
                        userEmail: user?.email,
                        radius: 46,
                        onAvatarChanged: (newUrl) {
                          setState(() {
                            _avatarController.text = newUrl ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          AvatarPickerBottomSheet.show(
                            context: context,
                            currentAvatarUrl: _avatarController.text,
                            userName: _nameController.text.isNotEmpty
                                ? _nameController.text
                                : (user?.fullName ?? 'معلم'),
                            userRole: 'teacher',
                            userId: user?.id,
                            userEmail: user?.email,
                            onAvatarSelected: (newUrl) {
                              setState(() {
                                _avatarController.text = newUrl ?? '';
                              });
                            },
                          );
                        },
                        icon: const Icon(Icons.photo_camera_rounded, size: 17),
                        label: const Text('تغيير صورة الحساب'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: textPrimary, fontSize: 13.5),
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل للمعلم',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'الاسم مطلوب'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        style: TextStyle(color: textPrimary, fontSize: 13.5),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف للتواصل',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teacherRole,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text(
                          'حفظ تعديلات الملف الشخصي',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: const Duration(milliseconds: 100),
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات واعتماد الحساب الأكاديمي',
                      style: AppTypography.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(
                        icon: Icons.badge_rounded,
                        color: AppColors.teacherRole,
                      ),
                      title: Text(
                        'معرف حساب المعلم (Domain ID)',
                        style: AppTypography.titleMedium(textPrimary),
                      ),
                      subtitle: Text(
                        bootstrap?.teacherId ?? 'غير مربوط بملف معلم',
                        style: AppTypography.bodySmall(textSecondary),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(
                        icon: Icons.email_outlined,
                        color: AppColors.warning,
                      ),
                      title: Text(
                        'البريد الإلكتروني المسجل',
                        style: AppTypography.titleMedium(textPrimary),
                      ),
                      subtitle: Text(
                        user?.email ?? 'teacher@academy.com',
                        style: AppTypography.bodySmall(textSecondary),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(
                        icon: Icons.security_rounded,
                        color: AppColors.success,
                      ),
                      title: Text(
                        'صلاحيات النظام المفعلة',
                        style: AppTypography.titleMedium(textPrimary),
                      ),
                      subtitle: Text(
                        '${bootstrap?.effectivePermissions.length ?? 0} صلاحيات أكاديمية وإدارية نشطة',
                        style: AppTypography.bodySmall(textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeInSlide(
              delay: const Duration(milliseconds: 200),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => widget.authViewModel.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'تسجيل الخروج من الحساب',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
