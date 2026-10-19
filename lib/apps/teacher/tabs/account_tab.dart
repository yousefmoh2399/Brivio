import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_screen.dart';
import '../../../design_system/components/editable_avatar.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../features/auth/presentation/screens/saved_accounts_screen.dart';
import '../../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../features/legal/presentation/screens/privacy_and_terms_screen.dart';
import '../../../features/payments/presentation/screens/teacher_finance_screen.dart';
import '../screens/teacher_helpdesk_screen.dart';

// ─── Teacher Account Sections Enum ───────────────────────────────────────────

enum TeacherAccountSection {
  profile,
  finance,
  helpdesk,
  settings,
}

// ─── Main Teacher Account Tab Widget ─────────────────────────────────────────

class AccountTab extends StatefulWidget {
  final String teacherId;
  final AuthViewModel authViewModel;
  final TeacherAccountSection initialSection;
  final ValueChanged<int>? onNavigateToTab;
  final WidgetBuilder? financeBuilder;
  final WidgetBuilder? helpdeskBuilder;

  const AccountTab({
    super.key,
    required this.teacherId,
    required this.authViewModel,
    this.initialSection = TeacherAccountSection.profile,
    this.onNavigateToTab,
    this.financeBuilder,
    this.helpdeskBuilder,
  });

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  late TeacherAccountSection _selectedSection;

  // Profile Form Controllers
  final _profileFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _avatarController;
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
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

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isSavingProfile = true);

    await widget.authViewModel.updateProfile(
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      avatarUrl: _avatarController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSavingProfile = false);

    final failure = widget.authViewModel.state.failure;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure?.message ?? 'تم تحديث بيانات الملف الشخصي بنجاح ✨',
        ),
        backgroundColor:
            failure == null ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'تسجيل الخروج',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من بوابة المعلم؟',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                widget.authViewModel.signOut();
              },
              child: const Text(
                'تأكيد الخروج',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
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
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isAr = AppLocalizations.of(context).isArabic;

    final user = widget.authViewModel.currentUser;
    final bootstrap = widget.authViewModel.bootstrap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 360;
        final isMobile = screenWidth < 720;
        final isDesktop = screenWidth >= 1024;
        final horizontalPadding = isNarrow ? 12.0 : (isMobile ? 16.0 : 24.0);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1100 : double.infinity,
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ─── 1. Executive Teacher Hero Banner ─────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        12,
                      ),
                      child: _TeacherAccountHero(
                        user: user,
                        bootstrapTeacherId: bootstrap?.teacherId ?? widget.teacherId,
                        avatarUrl: _avatarController.text,
                        permissionsCount:
                            bootstrap?.effectivePermissions.length ?? 0,
                        isDark: isDark,
                        isNarrow: isNarrow,
                        isAr: isAr,
                        onAvatarTap: () {
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
                              _saveProfile();
                            },
                          );
                        },
                        onSignOut: _showSignOutDialog,
                      ),
                    ),
                  ),

                  // ─── 2. Segmented Section Switcher Bar ─────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 6,
                      ),
                      child: _TeacherAccountSegmentBar(
                        selectedSection: _selectedSection,
                        isDark: isDark,
                        isNarrow: isNarrow,
                        isAr: isAr,
                        onSectionChanged: (sec) =>
                            setState(() => _selectedSection = sec),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ─── 3. Dynamic Section Content ───────────────────────────
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      4,
                      horizontalPadding,
                      32,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: switch (_selectedSection) {
                        TeacherAccountSection.profile => _buildProfileSection(
                            isDark: isDark,
                            isNarrow: isNarrow,
                            isMobile: isMobile,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            userEmail: user?.email,
                            teacherDomainId:
                                bootstrap?.teacherId ?? widget.teacherId,
                            permissions: bootstrap?.effectivePermissions ?? const [],
                          ),
                        TeacherAccountSection.finance => _buildFinanceSection(),
                        TeacherAccountSection.helpdesk => _buildHelpdeskSection(),
                        TeacherAccountSection.settings => _buildSettingsSection(
                            isDark: isDark,
                            isNarrow: isNarrow,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                      },
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

  // ─── Section 1: Profile & Domain Specs ──────────────────────────────────────

  Widget _buildProfileSection({
    required bool isDark,
    required bool isNarrow,
    required bool isMobile,
    required Color textPrimary,
    required Color textSecondary,
    required String? userEmail,
    required String teacherDomainId,
    required List<dynamic> permissions,
  }) {
    final formCard = GlassCard(
      padding: EdgeInsets.all(isNarrow ? 14 : 20),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teacherRole.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    size: 18,
                    color: AppColors.teacherRole,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'البيانات الأساسية للمعلم',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'يمكنك تعديل الاسم ورقم الهاتف المعتمدين بالسنتر.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'الاسم الكامل للمعلم',
                hintText: 'أدخل اسمك الثلاثي أو الرباعي',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'يرجى إدخال اسم المعلم'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف للتواصل',
                hintText: '01xxxxxxxxx',
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teacherRole,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _isSavingProfile ? null : _saveProfile,
              icon: _isSavingProfile
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final specsCard = GlassCard(
      padding: EdgeInsets.all(isNarrow ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات واعتماد حساب المعلم',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'معلومات الربط الأكاديمي مع إدارة السنتر.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Domain ID tile with Copy Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.vpn_key_rounded,
                  size: 18,
                  color: AppColors.teacherRole,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كود المعلم بالسنتر (Teacher Domain ID)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        teacherDomainId.isNotEmpty ? teacherDomainId : 'غير مرتبط',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  color: textSecondary,
                  tooltip: 'نسخ الكود',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: teacherDomainId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم نسخ كود المعلم إلى الحافظة بنجاح'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Email Tile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'البريد الإلكتروني المعتمد',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail ?? 'teacher@academy.com',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'مفعل',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Permissions Tile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.security_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الصلاحيات الأكاديمية النشطة',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${permissions.length} صلاحيات تدريس وإدارة امتحانات مفعلة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          formCard,
          const SizedBox(height: 16),
          specsCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: formCard),
        const SizedBox(width: 16),
        Expanded(child: specsCard),
      ],
    );
  }

  // ─── Section 2: Finance ─────────────────────────────────────────────────────

  Widget _buildFinanceSection() {
    return widget.financeBuilder?.call(context) ??
        TeacherFinanceScreen(
          teacherId: widget.teacherId,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
        );
  }

  // ─── Section 3: Helpdesk ────────────────────────────────────────────────────

  Widget _buildHelpdeskSection() {
    return SizedBox(
      height: 600,
      child: widget.helpdeskBuilder?.call(context) ??
          const TeacherHelpdeskScreen(),
    );
  }

  // ─── Section 4: Settings & Security ─────────────────────────────────────────

  Widget _buildSettingsSection({
    required bool isDark,
    required bool isNarrow,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      children: [
        // App Settings & Preferences
        GlassCard(
          padding: EdgeInsets.all(isNarrow ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.teacherRole.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      size: 18,
                      color: AppColors.teacherRole,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تفضيلات وإعدادات التطبيق',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Open Full App Settings Screen
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleIcon(
                  icon: Icons.palette_outlined,
                  color: AppColors.teacherRole,
                ),
                title: Text(
                  'المظهر والوضع الليلي',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'تخصيص ألوان الواجهة والتبديل بين الوضع الليلي والنهاري',
                  style: TextStyle(fontSize: 10.5, color: textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: SafeArea(
                          child: AppSettingsScreen(
                            authViewModel: widget.authViewModel,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 20),
              // Switch / Manage Saved Accounts
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleIcon(
                  icon: Icons.switch_account_rounded,
                  color: Color(0xFF10B981),
                ),
                title: Text(
                  'الحسابات المحفوظة والتبديل السريع',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'إدارة الحسابات المسجلة والتبديل بينها بدون إعادة تسجيل الدخول',
                  style: TextStyle(fontSize: 10.5, color: textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (modalCtx) => Scaffold(
                        appBar: AppBar(title: const Text('الحسابات المحفوظة')),
                        body: SavedAccountsScreen(
                          viewModel: widget.authViewModel,
                          onNavigateToLogin: () => Navigator.pop(modalCtx),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 20),
              // Privacy & Terms
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleIcon(
                  icon: Icons.policy_outlined,
                  color: Color(0xFFF59E0B),
                ),
                title: Text(
                  'سياسة الخصوصية وشروط الاستخدام',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'بيان حماية البيانات والأحكام والشروط المنظمة للمنصة',
                  style: TextStyle(fontSize: 10.5, color: textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyAndTermsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Logout Section
        GlassCard(
          padding: EdgeInsets.all(isNarrow ? 14 : 18),
          borderColor: AppColors.error.withValues(alpha: 0.3),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل الخروج من البوابة',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'إنهاء الجلسة الحالية والعودة لشاشة الدخول الرئيسية.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: _showSignOutDialog,
                child: const Text(
                  'خروج',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // System Branding Footer
        Center(
          child: Text(
            'منظومة المعلم الذكية • الإصدار v2.5.0 Enterprise\nجميع الحقوق محفوظة © منصة السنتر التعليمي',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: textSecondary.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 1. Executive Teacher Hero Banner ─────────────────────────────────────────

class _TeacherAccountHero extends StatelessWidget {
  final dynamic user;
  final String bootstrapTeacherId;
  final String avatarUrl;
  final int permissionsCount;
  final bool isDark;
  final bool isNarrow;
  final bool isAr;
  final VoidCallback onAvatarTap;
  final VoidCallback onSignOut;

  const _TeacherAccountHero({
    required this.user,
    required this.bootstrapTeacherId,
    required this.avatarUrl,
    required this.permissionsCount,
    required this.isDark,
    required this.isNarrow,
    required this.isAr,
    required this.onAvatarTap,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = user?.fullName ?? 'معلم المنصة';
    final email = user?.email ?? 'teacher@academy.com';

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.teacherRole.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.teacherRole.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Avatar + Name + Teacher Badge + Edit Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Camera Tap Overlay
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(
                    children: [
                      EditableAvatar(
                        avatarUrl: avatarUrl,
                        name: fullName,
                        role: 'teacher',
                        userId: user?.id,
                        userEmail: email,
                        radius: isNarrow ? 34 : 40,
                        onAvatarChanged: (_) => onAvatarTap(),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.teacherRole,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Name, Role Badge & Domain ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: TextStyle(
                                fontSize: isNarrow ? 14.5 : 16.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.teacherRole.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: AppColors.teacherRole.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'معلم معتمد 🎓',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.teacherRole,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: isNarrow ? 11 : 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      // Copy Domain ID Chip
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: bootstrapTeacherId),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ كود المعلم بنجاح'),
                              duration: Duration(seconds: 2),
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
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.vpn_key_rounded,
                                size: 10,
                                color: AppColors.teacherRole,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'كود المعلم: ${bootstrapTeacherId.isNotEmpty ? bootstrapTeacherId : "غير محدد"}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.copy_rounded,
                                size: 10,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Bottom Badges Row: Active Status & Permissions
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'الحساب نشط ومفعل بالسنتر ✨',
                            style: TextStyle(
                              fontSize: isNarrow ? 9.5 : 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teacherRole.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.teacherRole.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.security_rounded,
                          size: 13,
                          color: AppColors.teacherRole,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$permissionsCount صلاحيات أكاديمية 🛡️',
                            style: TextStyle(
                              fontSize: isNarrow ? 9.5 : 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teacherRole,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 2. Segmented Section Switcher Bar ─────────────────────────────────────────

class _TeacherAccountSegmentBar extends StatelessWidget {
  final TeacherAccountSection selectedSection;
  final bool isDark;
  final bool isNarrow;
  final bool isAr;
  final ValueChanged<TeacherAccountSection> onSectionChanged;

  const _TeacherAccountSegmentBar({
    required this.selectedSection,
    required this.isDark,
    required this.isNarrow,
    required this.isAr,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        section: TeacherAccountSection.profile,
        label: isAr ? 'الملف الشخصي' : 'Profile',
        icon: Icons.person_rounded,
      ),
      (
        section: TeacherAccountSection.finance,
        label: isAr ? 'الماليات والمستحقات' : 'Finances',
        icon: Icons.account_balance_wallet_rounded,
      ),
      (
        section: TeacherAccountSection.helpdesk,
        label: isAr ? 'الدعم الفني' : 'Helpdesk',
        icon: Icons.support_agent_rounded,
      ),
      (
        section: TeacherAccountSection.settings,
        label: isAr ? 'الإعدادات والأمان' : 'Settings',
        icon: Icons.settings_rounded,
      ),
    ];

    return SingleChildScrollView(
      key: const Key('teacher_account_segment_scroll_view'),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildSegmentItem(sections[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentItem(({TeacherAccountSection section, String label, IconData icon}) item) {
    final isSelected = selectedSection == item.section;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSectionChanged(item.section),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 10 : 13,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.teacherRole
                : (isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.85)
                    : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.teacherRole
                  : (isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder),
              width: isSelected ? 1.4 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.teacherRole.withValues(alpha: 0.3),
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
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600),
              ),
              const SizedBox(width: 5),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: isNarrow ? 11 : 12,
                  fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
