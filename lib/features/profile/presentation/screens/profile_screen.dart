import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/components/cards.dart';
import '../../../../design_system/components/editable_avatar.dart';
import '../../../../design_system/components/text_fields.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import 'package:brivio/features/avatar/presentation/screens/snapchat_avatar_studio_screen.dart';
import '../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileViewModel viewModel;
  final VoidCallback? onSignedOut;

  const ProfileScreen({super.key, required this.viewModel, this.onSignedOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarController;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = widget.viewModel.currentProfile;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _avatarController = TextEditingController(text: profile?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.viewModel.updateProfileDetails(
        fullName: _nameController.text,
        phoneNumber: _phoneController.text.isNotEmpty
            ? _phoneController.text
            : null,
        avatarUrl: _avatarController.text.isNotEmpty
            ? _avatarController.text
            : null,
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Change Password')),
          content: CustomTextField(
            label: 'New Password',
            hint: 'At least 6 characters',
            controller: _passwordController,
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (_passwordController.text.length >= 6) {
                  widget.viewModel.updatePassword(_passwordController.text);
                  Navigator.pop(context);
                  _passwordController.clear();
                }
              },
              child: Text(context.tr('Update')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;
        final profile = state.profile;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Account Profile')),
            actions: [
              if (widget.onSignedOut != null)
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  onPressed: widget.onSignedOut,
                  tooltip: context.tr('Sign Out'),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Avatar Header with 1-tap photo picker
                      EditableAvatar(
                        avatarUrl: _avatarController.text,
                        fullName: profile?.fullName ?? 'User',
                        radius: 48,
                        userId: profile?.id,
                        userEmail: profile?.email,
                        roleColor: AppColors.primary,
                        onAvatarChanged: (newUrl) {
                          setState(() {
                            _avatarController.text = newUrl ?? '';
                          });
                          _saveProfile();
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile?.fullName ?? context.tr('User'),
                        style: AppTypography.titleLarge(textPrimary),
                      ),
                      Text(
                        '${profile?.role.displayName} • ${profile?.email ?? ''}',
                        style: AppTypography.bodyMedium(textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () async {
                          final newUrl = await SnapchatAvatarStudioScreen.open(
                            context: context,
                            userId: profile?.id,
                            userEmail: profile?.email,
                            initialAvatarUrl: _avatarController.text,
                            roleColor: AppColors.primary,
                          );
                          if (newUrl != null && newUrl.isNotEmpty) {
                            setState(() {
                              _avatarController.text = newUrl;
                            });
                            _saveProfile();
                          }
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF8B5CF6)),
                        label: const Text(
                          'تصميم شخصية كارتونية (Bitmoji) 🎨',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (state.status == ProfileStatus.success &&
                          state.message != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            state.message!,
                            style: AppTypography.bodyMedium(AppColors.success),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      CustomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextField(
                              label: 'الاسم بالكامل / Full Name',
                              controller: _nameController,
                              prefixIcon: Icons.person_outline,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? context.tr('Name is required')
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: 'رقم الهاتف / Phone Number',
                              hint: '+20 10 1234 5678',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final newUrl = await showModalBottomSheet<String?>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => AvatarPickerBottomSheet(
                                    currentAvatarUrl: _avatarController.text,
                                    fullName: profile?.fullName ?? 'User',
                                    roleColor: AppColors.primary,
                                    userId: profile?.id,
                                    userEmail: profile?.email,
                                  ),
                                );
                                if (newUrl != null || newUrl == null && _avatarController.text.isNotEmpty) {
                                  setState(() {
                                    _avatarController.text = newUrl ?? '';
                                  });
                                  _saveProfile();
                                }
                              },
                              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                              label: const Text('تغيير أو رفع صورة شخصية 📷', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      PrimaryButton(
                        text: 'Save Changes',
                        isLoading: state.status == ProfileStatus.loading,
                        onPressed: _saveProfile,
                        icon: Icons.save_rounded,
                      ),
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: () => _showChangePasswordDialog(context),
                        icon: const Icon(Icons.key_rounded),
                        label: Text(context.tr('Change Password')),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
