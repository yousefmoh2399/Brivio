import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client_wrapper.dart';
import '../../../core/settings/app_settings_screen.dart';
import '../../../design_system/components/editable_avatar.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/auth/data/repositories/supabase_auth_repository.dart';
import '../../../features/auth/domain/models/user_profile.dart';
import '../../../features/auth/presentation/screens/saved_accounts_screen.dart';
import '../../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../features/avatar/presentation/screens/snapchat_avatar_studio_screen.dart';
import '../../../features/legal/presentation/screens/privacy_and_terms_screen.dart';
import '../../../features/payments/domain/models/payment_models.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatDate(DateTime? dt) {
  if (dt == null) return 'غير محدد';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

String _formatMoney(int minor, String currency) {
  final value = minor / 100.0;
  final clean = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$clean ج.م';
}

String _shortCode(String val) {
  if (val.length <= 8) return val;
  return val.substring(0, 8);
}

enum _ParentAccountSection {
  profile,
  children,
  finance,
  settings,
}

// ─── Main Parent Account Tab Widget ──────────────────────────────────────────

class ParentAccountTab extends StatefulWidget {
  final UserProfile? profile;
  final AuthViewModel? authViewModel;
  final Student? selectedChild;
  final List<Student> linkedChildren;
  final FinancialSummary? financialSummary;
  final List<Invoice> invoices;
  final List<Receipt> receipts;
  final List<GroupEntity> childGroups;
  final int unreadCount;
  final ValueChanged<Student>? onChildSelected;
  final VoidCallback? onLinkNewChild;
  final Future<void> Function()? onProfileChanged;
  final VoidCallback? onSignOut;
  final ValueChanged<int>? onNavigateToTab;
  final VoidCallback? onOpenWhatsApp;
  final VoidCallback? onExportLedger;
  final ValueChanged<Receipt>? onShowReceipt;

  const ParentAccountTab({
    super.key,
    required this.profile,
    this.authViewModel,
    this.selectedChild,
    this.linkedChildren = const [],
    this.financialSummary,
    this.invoices = const [],
    this.receipts = const [],
    this.childGroups = const [],
    this.unreadCount = 0,
    this.onChildSelected,
    this.onLinkNewChild,
    this.onProfileChanged,
    this.onSignOut,
    this.onNavigateToTab,
    this.onOpenWhatsApp,
    this.onExportLedger,
    this.onShowReceipt,
  });

  @override
  State<ParentAccountTab> createState() => _ParentAccountTabState();
}

class _ParentAccountTabState extends State<ParentAccountTab> {
  _ParentAccountSection _currentSection = _ParentAccountSection.profile;

  // Profile editing
  final _profileFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _avatarUrl;
  bool _isSavingProfile = false;
  String? _profileMessage;
  String? _profileError;

  // Password changing
  final _passwordFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isChangingPassword = false;
  String? _passwordMessage;
  String? _passwordError;

  // Finance view switcher
  bool _showReceiptsInFinance = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.fullName ?? '');
    _phoneController = TextEditingController(text: widget.profile?.phoneNumber ?? '');
    _avatarUrl = widget.profile?.avatarUrl;
  }

  @override
  void didUpdateWidget(covariant ParentAccountTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      if (!_isSavingProfile) {
        _nameController.text = widget.profile?.fullName ?? '';
        _phoneController.text = widget.profile?.phoneNumber ?? '';
        _avatarUrl = widget.profile?.avatarUrl;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final p = widget.profile;
    if (p == null || !(_profileFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSavingProfile = true;
      _profileMessage = null;
      _profileError = null;
    });

    try {
      final repo = SupabaseAuthRepository(
        SupabaseClientWrapper(Supabase.instance.client),
      );
      final updated = p.copyWith(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        avatarUrl: (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty)
            ? _avatarUrl!.trim()
            : null,
      );

      await repo.updateProfile(updated);
      if (widget.onProfileChanged != null) {
        await widget.onProfileChanged!();
      }

      if (!mounted) return;
      setState(() {
        _isSavingProfile = false;
        _profileMessage = 'تم تحديث وحفظ بيانات الحساب بنجاح ✅';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingProfile = false;
        _profileError = 'تعذر حفظ البيانات: $e';
      });
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.length < 6) {
      setState(() {
        _passwordError = 'كلمة المرور يجب ألا تقل عن 6 أحرف.';
        _passwordMessage = null;
      });
      return;
    }

    if (newPass != confirmPass) {
      setState(() {
        _passwordError = 'كلمة المرور وتأكيدها غير متطابقين.';
        _passwordMessage = null;
      });
      return;
    }

    setState(() {
      _isChangingPassword = true;
      _passwordMessage = null;
      _passwordError = null;
    });

    try {
      final repo = SupabaseAuthRepository(
        SupabaseClientWrapper(Supabase.instance.client),
      );
      await repo.updatePassword(newPass);

      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      setState(() {
        _isChangingPassword = false;
        _passwordMessage = 'تم تغيير كلمة المرور وتأمين حسابك بنجاح 🔒';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChangingPassword = false;
        _passwordError = 'تعذر تحديث كلمة المرور: $e';
      });
    }
  }

  void _confirmSignOut(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: const [
              Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب ولي الأمر على هذا الجهاز؟',
            style: TextStyle(fontSize: 13.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onSignOut?.call();
              },
              child: const Text('نعم، تسجيل الخروج'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 380;
        final isMobile = screenWidth < 680;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Executive Account Hero ─────────────────────────────────
            _ExecutiveParentAccountHero(
              profile: widget.profile,
              selectedChild: widget.selectedChild,
              linkedChildrenCount: widget.linkedChildren.length,
              remainingBalanceMinor: widget.financialSummary?.remainingBalanceMinor ?? 0,
              currency: widget.financialSummary?.currency ?? 'EGP',
              unreadCount: widget.unreadCount,
              isDark: isDark,
              isNarrow: isNarrow,
              isMobile: isMobile,
              onAvatarChanged: (newUrl) async {
                setState(() => _avatarUrl = newUrl);
                await _saveProfile();
              },
              onSelectSection: (section) {
                setState(() => _currentSection = section);
              },
              onOpenHelpdesk: () => widget.onNavigateToTab?.call(6),
              onOpenNotifications: () => widget.onNavigateToTab?.call(5),
            ),
            const SizedBox(height: 18),

            // ─── 2. Segmented Navigation Hub ───────────────────────────────
            _SegmentedNavigationHub(
              currentSection: _currentSection,
              linkedChildrenCount: widget.linkedChildren.length,
              invoicesCount: widget.invoices.length,
              isDark: isDark,
              isNarrow: isNarrow,
              onSectionChanged: (sec) => setState(() => _currentSection = sec),
            ),
            const SizedBox(height: 18),

            // ─── 3. Active Section Router ──────────────────────────────────
            switch (_currentSection) {
              _ParentAccountSection.profile => _ParentProfileSecurityView(
                  profile: widget.profile,
                  nameController: _nameController,
                  phoneController: _phoneController,
                  profileFormKey: _profileFormKey,
                  isSavingProfile: _isSavingProfile,
                  profileMessage: _profileMessage,
                  profileError: _profileError,
                  onSaveProfile: _saveProfile,
                  // Password
                  passwordFormKey: _passwordFormKey,
                  newPasswordController: _newPasswordController,
                  confirmPasswordController: _confirmPasswordController,
                  obscureNewPassword: _obscureNewPassword,
                  obscureConfirmPassword: _obscureConfirmPassword,
                  isChangingPassword: _isChangingPassword,
                  passwordMessage: _passwordMessage,
                  passwordError: _passwordError,
                  onToggleNewPassword: () =>
                      setState(() => _obscureNewPassword = !_obscureNewPassword),
                  onToggleConfirmPassword: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  onChangePassword: _changePassword,
                  // Snapchat Avatar Studio
                  onOpenAvatarStudio: () async {
                    final newUrl = await SnapchatAvatarStudioScreen.open(
                      context: context,
                      userId: widget.profile?.id,
                      userEmail: widget.profile?.email,
                      initialAvatarUrl: _avatarUrl,
                      roleColor: AppColors.parentRole,
                    );
                    if (newUrl != null && mounted) {
                      setState(() => _avatarUrl = newUrl);
                      await _saveProfile();
                    }
                  },
                  isDark: isDark,
                  isNarrow: isNarrow,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              _ParentAccountSection.children => _ParentChildrenManagementView(
                  linkedChildren: widget.linkedChildren,
                  selectedChild: widget.selectedChild,
                  childGroups: widget.childGroups,
                  onChildSelected: widget.onChildSelected,
                  onLinkNewChild: widget.onLinkNewChild,
                  onNavigateToTab: widget.onNavigateToTab,
                  isDark: isDark,
                  isNarrow: isNarrow,
                  isMobile: isMobile,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              _ParentAccountSection.finance => _ParentFamilyFinanceView(
                  financialSummary: widget.financialSummary,
                  invoices: widget.invoices,
                  receipts: widget.receipts,
                  showReceipts: _showReceiptsInFinance,
                  onToggleView: (show) =>
                      setState(() => _showReceiptsInFinance = show),
                  onExportLedger: widget.onExportLedger,
                  onShowReceipt: widget.onShowReceipt,
                  onOpenFullPayments: () => widget.onNavigateToTab?.call(3),
                  isDark: isDark,
                  isNarrow: isNarrow,
                  isMobile: isMobile,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              _ParentAccountSection.settings => _ParentSettingsAndSystemView(
                  authViewModel: widget.authViewModel,
                  onOpenWhatsApp: widget.onOpenWhatsApp,
                  onOpenHelpdesk: () => widget.onNavigateToTab?.call(6),
                  onSignOut: () => _confirmSignOut(context),
                  isDark: isDark,
                  isNarrow: isNarrow,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
            },
          ],
        );
      },
    );
  }
}

// ─── Executive Account Hero Card ─────────────────────────────────────────────

class _ExecutiveParentAccountHero extends StatelessWidget {
  final UserProfile? profile;
  final Student? selectedChild;
  final int linkedChildrenCount;
  final int remainingBalanceMinor;
  final String currency;
  final int unreadCount;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final ValueChanged<String?> onAvatarChanged;
  final ValueChanged<_ParentAccountSection> onSelectSection;
  final VoidCallback onOpenHelpdesk;
  final VoidCallback onOpenNotifications;

  const _ExecutiveParentAccountHero({
    required this.profile,
    required this.selectedChild,
    required this.linkedChildrenCount,
    required this.remainingBalanceMinor,
    required this.currency,
    required this.unreadCount,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.onAvatarChanged,
    required this.onSelectSection,
    required this.onOpenHelpdesk,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile?.fullName ?? 'ولي الأمر';
    final email = profile?.email ?? '';
    final phone = profile?.phoneNumber ?? '';
    final parentId = profile?.id ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0D1B2A),
                ]
              : const [
                  Color(0xFFF8FAFC),
                  Color(0xFFEFF6FF),
                  Color(0xFFE2E8F0),
                ],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isNarrow ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top Row: Avatar + Name + Badges ───────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EditableAvatar(
                avatarUrl: profile?.avatarUrl,
                name: name,
                role: 'parent',
                userId: profile?.id,
                userEmail: profile?.email,
                radius: isNarrow ? 26 : (isMobile ? 36 : 42),
                roleColor: AppColors.parentRole,
                onAvatarChanged: onAvatarChanged,
              ),
              SizedBox(width: isNarrow ? 8 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verified Badge + Role
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.parentRole.withValues(alpha: isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.parentRole.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 12,
                                color: AppColors.parentRole,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'ولي أمر معتمد 🛡️',
                                  style: TextStyle(
                                    color: AppColors.parentRole,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (parentId.isNotEmpty)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Clipboard.setData(ClipboardData(text: parentId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم نسخ كود المعرف إلى الحافظة 📋'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.copy_rounded,
                                      size: 11,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'ID: #${_shortCode(parentId)}',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Full Name
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: isNarrow ? 15.5 : 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Contact Info Line
                    if (email.isNotEmpty || phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            phone.isNotEmpty ? Icons.phone_android_rounded : Icons.email_rounded,
                            size: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              phone.isNotEmpty ? phone : email,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Quick Edit Profile Shortcut
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.parentRole.withValues(alpha: 0.15),
                  foregroundColor: AppColors.parentRole,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => onSelectSection(_ParentAccountSection.profile),
                icon: const Icon(Icons.edit_rounded, size: 18),
                tooltip: 'تعديل بيانات الحساب',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── Quick Interactive Glance Micro-Cards ────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildHeroGlanceChip(
                  context: context,
                  label: 'الأبناء المرتبطين',
                  value: '$linkedChildrenCount طلاب',
                  icon: Icons.school_rounded,
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                  onTap: () => onSelectSection(_ParentAccountSection.children),
                ),
                const SizedBox(width: 8),
                _buildHeroGlanceChip(
                  context: context,
                  label: 'المتبقي للدفع',
                  value: _formatMoney(remainingBalanceMinor, currency),
                  icon: Icons.account_balance_wallet_rounded,
                  color: remainingBalanceMinor > 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () => onSelectSection(_ParentAccountSection.finance),
                ),
                const SizedBox(width: 8),
                _buildHeroGlanceChip(
                  context: context,
                  label: 'الإشعارات',
                  value: unreadCount > 0 ? '$unreadCount جديدة 🔔' : 'محدثة بالكامل',
                  icon: Icons.notifications_active_rounded,
                  color: unreadCount > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF64748B),
                  isDark: isDark,
                  onTap: onOpenNotifications,
                ),
                const SizedBox(width: 8),
                _buildHeroGlanceChip(
                  context: context,
                  label: 'الدعم الفني',
                  value: 'تواصل فوري',
                  icon: Icons.support_agent_rounded,
                  color: AppColors.parentRole,
                  isDark: isDark,
                  onTap: onOpenHelpdesk,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroGlanceChip({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? color.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Segmented Navigation Hub ────────────────────────────────────────────────

class _SegmentedNavigationHub extends StatelessWidget {
  final _ParentAccountSection currentSection;
  final int linkedChildrenCount;
  final int invoicesCount;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<_ParentAccountSection> onSectionChanged;

  const _SegmentedNavigationHub({
    required this.currentSection,
    required this.linkedChildrenCount,
    required this.invoicesCount,
    required this.isDark,
    required this.isNarrow,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final segments = [
      _SegmentModel(
        section: _ParentAccountSection.profile,
        title: 'الملف والأمان',
        icon: Icons.manage_accounts_rounded,
      ),
      _SegmentModel(
        section: _ParentAccountSection.children,
        title: 'إدارة الأبناء',
        icon: Icons.people_alt_rounded,
        badge: linkedChildrenCount > 0 ? '$linkedChildrenCount' : null,
      ),
      _SegmentModel(
        section: _ParentAccountSection.finance,
        title: 'المحفظة العائلية',
        icon: Icons.account_balance_wallet_rounded,
        badge: invoicesCount > 0 ? '$invoicesCount' : null,
      ),
      _SegmentModel(
        section: _ParentAccountSection.settings,
        title: 'التفضيلات والنظام',
        icon: Icons.tune_rounded,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: segments.map((item) {
          final isSelected = currentSection == item.section;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSectionChanged(item.section);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 12 : 15,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.parentRole.withValues(alpha: isDark ? 0.25 : 0.14)
                        : (isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white.withValues(alpha: 0.9)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.parentRole
                          : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.4 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.parentRole.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: isSelected
                            ? AppColors.parentRole
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: isNarrow ? 11.5 : 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? AppColors.parentRole
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      if (item.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.parentRole
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.badge!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade800),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SegmentModel {
  final _ParentAccountSection section;
  final String title;
  final IconData icon;
  final String? badge;

  const _SegmentModel({
    required this.section,
    required this.title,
    required this.icon,
    this.badge,
  });
}

// ─── 1. Profile & Security View ──────────────────────────────────────────────

class _ParentProfileSecurityView extends StatelessWidget {
  final UserProfile? profile;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final GlobalKey<FormState> profileFormKey;
  final bool isSavingProfile;
  final String? profileMessage;
  final String? profileError;
  final VoidCallback onSaveProfile;

  // Password
  final GlobalKey<FormState> passwordFormKey;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final bool isChangingPassword;
  final String? passwordMessage;
  final String? passwordError;
  final VoidCallback onToggleNewPassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onChangePassword;

  // Avatar Studio
  final VoidCallback onOpenAvatarStudio;

  final bool isDark;
  final bool isNarrow;
  final Color textPrimary;
  final Color textSecondary;

  const _ParentProfileSecurityView({
    required this.profile,
    required this.nameController,
    required this.phoneController,
    required this.profileFormKey,
    required this.isSavingProfile,
    required this.profileMessage,
    required this.profileError,
    required this.onSaveProfile,
    required this.passwordFormKey,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.obscureNewPassword,
    required this.obscureConfirmPassword,
    required this.isChangingPassword,
    required this.passwordMessage,
    required this.passwordError,
    required this.onToggleNewPassword,
    required this.onToggleConfirmPassword,
    required this.onChangePassword,
    required this.onOpenAvatarStudio,
    required this.isDark,
    required this.isNarrow,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Card A: Personal Info ───────────────────────────────────────
        GlassCard(
          padding: EdgeInsets.all(isNarrow ? 14 : 18),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Form(
            key: profileFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.parentRole.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.parentRole,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'البيانات الشخصية لولي الأمر',
                            style: AppTypography.titleMedium(textPrimary).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'تحديث الاسم ورقم الهاتف المستخدم في التواصل مع المركز.',
                            style: AppTypography.caption(textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name field
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل لولي الأمر',
                    prefixIcon: const Icon(Icons.person_rounded, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF141414)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم' : null,
                ),
                const SizedBox(height: 12),

                // Phone field
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف المحمول (واتساب)',
                    prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                    hintText: '01XXXXXXXXX',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF141414)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Email display (read only)
                TextFormField(
                  initialValue: profile?.email ?? '',
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني المسجل (للدخول فقط)',
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                    suffixIcon: const Tooltip(
                      message: 'لا يمكن تعديل البريد لأنه مرتبط بتوثيق الدخول',
                      child: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Snapchat Avatar Studio Button
                OutlinedButton.icon(
                  onPressed: onOpenAvatarStudio,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    side: BorderSide(
                      color: AppColors.parentRole.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.parentRole),
                  label: const Text(
                    'تخصيص الأفاتار والشخصية الكرتونية 🎨',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.parentRole,
                    ),
                  ),
                ),

                if (profileMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildStatusBanner(
                    message: profileMessage!,
                    isError: false,
                    isDark: isDark,
                  ),
                ],

                if (profileError != null) ...[
                  const SizedBox(height: 12),
                  _buildStatusBanner(
                    message: profileError!,
                    isError: true,
                    isDark: isDark,
                  ),
                ],

                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.parentRole,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSavingProfile ? null : onSaveProfile,
                    icon: isSavingProfile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      isSavingProfile ? 'جاري الحفظ...' : 'حفظ تعديلات الملف',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Card B: Security & Password ─────────────────────────────────
        GlassCard(
          padding: EdgeInsets.all(isNarrow ? 14 : 18),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Form(
            key: passwordFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الأمان وتغيير كلمة المرور',
                            style: AppTypography.titleMedium(textPrimary).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'تحديث كلمة مرور الحساب لحماية وتأمين بيانات الأبناء.',
                            style: AppTypography.caption(textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // New password
                TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    prefixIcon: const Icon(Icons.key_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNewPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: onToggleNewPassword,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF141414)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'كلمة المرور يجب ألا تقل عن 6 أحرف'
                      : null,
                ),
                const SizedBox(height: 12),

                // Confirm password
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور الجديدة',
                    prefixIcon: const Icon(Icons.lock_clock_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: onToggleConfirmPassword,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF141414)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v != newPasswordController.text) {
                      return 'كلمات المرور غير متطابقة';
                    }
                    return null;
                  },
                ),

                if (passwordMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildStatusBanner(
                    message: passwordMessage!,
                    isError: false,
                    isDark: isDark,
                  ),
                ],

                if (passwordError != null) ...[
                  const SizedBox(height: 12),
                  _buildStatusBanner(
                    message: passwordError!,
                    isError: true,
                    isDark: isDark,
                  ),
                ],

                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isChangingPassword ? null : onChangePassword,
                    icon: isChangingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset_rounded, size: 18),
                    label: Text(
                      isChangingPassword
                          ? 'جاري التحديث...'
                          : 'تحديث كلمة المرور',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Card C: Security Info & Trust Badges ─────────────────────────
        GlassCard(
          padding: EdgeInsets.all(isNarrow ? 14 : 18),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حالة الحساب والتوثيق',
                style: AppTypography.titleMedium(textPrimary).copyWith(fontSize: 14),
              ),
              const SizedBox(height: 10),
              _buildSecurityTile(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                title: 'توثيق الحساب',
                subtitle: 'الحساب موثق لدى إدارة السنتر وصالح لمتابعة كافة الأبناء.',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildSecurityTile(
                icon: Icons.lock_rounded,
                color: const Color(0xFF3B82F6),
                title: 'تشفير الاتصال والبيانات',
                subtitle: 'جميع البيانات المالية والأكاديمية مشفرة ببروتوكول TLS الحديث.',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner({
    required String message,
    required bool isError,
    required bool isDark,
  }) {
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 2. Children Management View ─────────────────────────────────────────────

class _ParentChildrenManagementView extends StatelessWidget {
  final List<Student> linkedChildren;
  final Student? selectedChild;
  final List<GroupEntity> childGroups;
  final ValueChanged<Student>? onChildSelected;
  final VoidCallback? onLinkNewChild;
  final ValueChanged<int>? onNavigateToTab;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final Color textPrimary;
  final Color textSecondary;

  const _ParentChildrenManagementView({
    required this.linkedChildren,
    required this.selectedChild,
    required this.childGroups,
    required this.onChildSelected,
    required this.onLinkNewChild,
    required this.onNavigateToTab,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header + Link New Child Button ──────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الطلاب المرتبطين بحسابك (${linkedChildren.length})',
                    style: AppTypography.titleMedium(textPrimary).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'إدارة شؤون الأبناء والتبديل السريع لمتابعة الدرجات والغياب.',
                    style: AppTypography.caption(textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.parentRole,
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 10 : 14,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onLinkNewChild,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: Text(
                isNarrow ? 'ربط طالب' : 'ربط طالب جديد ➕',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ─── Children Cards List ─────────────────────────────────────────
        if (linkedChildren.isEmpty)
          _buildEmptyChildrenCard(context)
        else
          ...linkedChildren.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildChildCard(context, child),
            ),
          ),
      ],
    );
  }

  Widget _buildChildCard(BuildContext context, Student child) {
    final isSelected = selectedChild?.id == child.id;

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isSelected
          ? AppColors.parentRole
          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: AppColors.parentRole.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.parentRole.withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.parentRole : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    child.fullName.isNotEmpty ? child.fullName[0] : 'ط',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.parentRole
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            child.fullName,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 11,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'المحدد حالياً',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Code with copy
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Clipboard.setData(ClipboardData(text: child.studentCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم نسخ كود ${child.fullName} 📋'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 10,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'كود: ${child.studentCode}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (childGroups.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              childGroups.first.name,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.6),
          const SizedBox(height: 8),

          // Action buttons row (Wrap to prevent overflow on 320px)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!isSelected)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => onChildSelected?.call(child),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                  label: const Text('تحديد للمتابعة 🔄', style: TextStyle(fontSize: 11)),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (!isSelected) onChildSelected?.call(child);
                  onNavigateToTab?.call(4); // Monthly Report
                },
                icon: const Icon(Icons.bar_chart_rounded, size: 15),
                label: const Text('التقرير الشهري 📊', style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (!isSelected) onChildSelected?.call(child);
                  onNavigateToTab?.call(3); // Payments
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 15),
                label: const Text('المدفوعات 💳', style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (!isSelected) onChildSelected?.call(child);
                  onNavigateToTab?.call(2); // Attendance
                },
                icon: const Icon(Icons.fact_check_rounded, size: 15),
                label: const Text('سجل الحضور 📅', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChildrenCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.parentRole.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                size: 36,
                color: AppColors.parentRole,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا يوجد طلاب مرتبطين بحسابك حالياً',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'يرجى استخدام كود الطالب المستلم من إدارة السنتر لربطه بحسابك والبدء في متابعة دراسته.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.parentRole,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onLinkNewChild,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('ربط طالب جديد بالكود'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3. Family Finance View ──────────────────────────────────────────────────

class _ParentFamilyFinanceView extends StatelessWidget {
  final FinancialSummary? financialSummary;
  final List<Invoice> invoices;
  final List<Receipt> receipts;
  final bool showReceipts;
  final ValueChanged<bool> onToggleView;
  final VoidCallback? onExportLedger;
  final ValueChanged<Receipt>? onShowReceipt;
  final VoidCallback? onOpenFullPayments;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final Color textPrimary;
  final Color textSecondary;

  const _ParentFamilyFinanceView({
    required this.financialSummary,
    required this.invoices,
    required this.receipts,
    required this.showReceipts,
    required this.onToggleView,
    required this.onExportLedger,
    required this.onShowReceipt,
    required this.onOpenFullPayments,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final currency = financialSummary?.currency ?? 'EGP';
    final totalBilled = financialSummary?.totalDueMinor ?? 0;
    final totalPaid = financialSummary?.totalPaidMinor ?? 0;
    final remaining = financialSummary?.remainingBalanceMinor ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Financial Banner Summary ────────────────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isNarrow ? 14 : 18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.parentRole.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.parentRole,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ملخص المحفظة العائلية المجمعة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onExportLedger != null)
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                      tooltip: 'تصدير كشف الحساب المالي',
                      color: AppColors.parentRole,
                      onPressed: onExportLedger,
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Responsive KPI Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobileKpi = constraints.maxWidth < 460;
                  if (isMobileKpi) {
                    return Column(
                      children: [
                        _buildKpiBox('إجمالي المقررات', _formatMoney(totalBilled, currency), const Color(0xFF3B82F6)),
                        const SizedBox(height: 8),
                        _buildKpiBox('المسدد فعلياً', _formatMoney(totalPaid, currency), const Color(0xFF10B981)),
                        const SizedBox(height: 8),
                        _buildKpiBox('المتبقي للدفع', _formatMoney(remaining, currency), const Color(0xFFEF4444)),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: _buildKpiBox('إجمالي المقررات', _formatMoney(totalBilled, currency), const Color(0xFF3B82F6))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildKpiBox('المسدد فعلياً', _formatMoney(totalPaid, currency), const Color(0xFF10B981))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildKpiBox('المتبقي للدفع', _formatMoney(remaining, currency), const Color(0xFFEF4444))),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Toggle Switcher: Invoices vs Receipts ────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            _buildTogglePill(
              label: 'الفواتير (${invoices.length})',
              icon: Icons.receipt_long_rounded,
              isSelected: !showReceipts,
              onTap: () => onToggleView(false),
              isDark: isDark,
            ),
            _buildTogglePill(
              label: 'الإيصالات (${receipts.length})',
              icon: Icons.check_circle_outline_rounded,
              isSelected: showReceipts,
              onTap: () => onToggleView(true),
              isDark: isDark,
            ),
            if (onOpenFullPayments != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: onOpenFullPayments,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('الكل ↗', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // ─── List of Invoices or Receipts ────────────────────────────────
        if (!showReceipts) ...[
          if (invoices.isEmpty)
            _buildEmptyState('لا توجد فواتير مسجلة حالياً', Icons.receipt_long_rounded)
          else
            ...invoices.take(5).map((inv) => _buildInvoiceItem(inv)),
        ] else ...[
          if (receipts.isEmpty)
            _buildEmptyState('لا توجد إيصالات سداد مسجلة حالياً', Icons.receipt_rounded)
          else
            ...receipts.take(5).map((rec) => _buildReceiptItem(rec)),
        ],
      ],
    );
  }

  Widget _buildKpiBox(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(Invoice inv) {
    final isPaid = inv.status.toLowerCase() == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'فاتورة #${inv.invoiceNumber}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'تاريخ الاستحقاق: ${_formatDate(inv.dueAt)}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatMoney(inv.totalMinor, inv.currency),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptItem(Receipt rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_rounded,
              color: Color(0xFF10B981),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.receiptNumber.isEmpty ? 'إيصال دفع إلكتروني' : 'إيصال #${rec.receiptNumber}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'تاريخ السداد: ${_formatDate(rec.issuedAt)}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatMoney(rec.amountMinor, rec.currency),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF10B981),
            ),
          ),
          if (onShowReceipt != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              onPressed: () => onShowReceipt!(rec),
              tooltip: 'عرض تفاصيل الإيصال',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTogglePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.parentRole.withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.parentRole
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? AppColors.parentRole
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? AppColors.parentRole
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 4. Settings & System View ───────────────────────────────────────────────

class _ParentSettingsAndSystemView extends StatelessWidget {
  final AuthViewModel? authViewModel;
  final VoidCallback? onOpenWhatsApp;
  final VoidCallback? onOpenHelpdesk;
  final VoidCallback onSignOut;
  final bool isDark;
  final bool isNarrow;
  final Color textPrimary;
  final Color textSecondary;

  const _ParentSettingsAndSystemView({
    required this.authViewModel,
    required this.onOpenWhatsApp,
    required this.onOpenHelpdesk,
    required this.onSignOut,
    required this.isDark,
    required this.isNarrow,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Group 1: Preferences ────────────────────────────────────────
        _buildSectionGroupTitle('تفضيلات المنظومة والمظهر'),
        const SizedBox(height: 8),

        // App Settings
        _buildActionTile(
          context: context,
          icon: Icons.palette_outlined,
          color: const Color(0xFF6366F1),
          title: 'المظهر واللغة والإشعارات',
          subtitle: 'تخصيص المظهر (داكن/فاتح)، لغة التطبيق، وتفضيلات تنبيهات الحضور والدرجات.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
            );
          },
        ),
        const SizedBox(height: 8),

        // Saved Accounts Switcher
        if (authViewModel != null)
          _buildActionTile(
            context: context,
            icon: Icons.switch_account_rounded,
            color: const Color(0xFF0EA5E9),
            title: 'إدارة الحسابات المحفوظة',
            subtitle: 'التبديل الفوري بين حسابات أولياء الأمور والطلاب على نفس الهاتف بدون إعادة إدخال كلمة المرور.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SavedAccountsScreen(
                    viewModel: authViewModel!,
                    onNavigateToLogin: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 18),

        // ─── Group 2: Support & Center Help ──────────────────────────────
        _buildSectionGroupTitle('الدعم والتواصل مع السنتر'),
        const SizedBox(height: 8),

        // WhatsApp Support
        if (onOpenWhatsApp != null)
          _buildActionTile(
            context: context,
            icon: Icons.chat_rounded,
            color: const Color(0xFF22C55E),
            title: 'المحادثة الفورية عبر واتساب المركز',
            subtitle: 'تواصل مباشر مع مشرفي الفرع وإدارة السنتر للاستفسارات السريعة.',
            onTap: onOpenWhatsApp!,
          ),
        const SizedBox(height: 8),

        // Helpdesk Tickets
        if (onOpenHelpdesk != null)
          _buildActionTile(
            context: context,
            icon: Icons.support_agent_rounded,
            color: AppColors.parentRole,
            title: 'تذاكر الدعم الفني والاستفسارات 🎫',
            subtitle: 'فتح تذكرة استفسار رسمية ومتابعة ردود المشرفين والمعلمين لحظياً.',
            onTap: onOpenHelpdesk!,
          ),

        const SizedBox(height: 18),

        // ─── Group 3: Legal & Privacy ────────────────────────────────────
        _buildSectionGroupTitle('الخصوصية والشروط'),
        const SizedBox(height: 8),

        _buildActionTile(
          context: context,
          icon: Icons.privacy_tip_outlined,
          color: const Color(0xFF64748B),
          title: 'سياسة الخصوصية وشروط الخدمة',
          subtitle: 'الاطلاع على سياسة حماية بيانات الأبناء وسرية الحسابات.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyAndTermsScreen()),
            );
          },
        ),

        const SizedBox(height: 22),

        // ─── Group 4: Logout ─────────────────────────────────────────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSignOut,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسجيل الخروج من الحساب',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'الخروج من حساب ولي الأمر على هذا الهاتف بأمان.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionGroupTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
