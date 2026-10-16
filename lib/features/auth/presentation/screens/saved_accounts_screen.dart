import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/services/saved_accounts_service.dart';
import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/user_role.dart';
import '../viewmodels/auth_viewmodel.dart';

class SavedAccountsScreen extends StatefulWidget {
  final AuthViewModel viewModel;
  final VoidCallback onNavigateToLogin;
  final VoidCallback? onLoginSuccess;

  const SavedAccountsScreen({
    super.key,
    required this.viewModel,
    required this.onNavigateToLogin,
    this.onLoginSuccess,
  });

  @override
  State<SavedAccountsScreen> createState() => _SavedAccountsScreenState();
}

class _SavedAccountsScreenState extends State<SavedAccountsScreen>
    with SingleTickerProviderStateMixin {
  List<SavedAccount> _accounts = [];
  bool _isLoading = true;
  String? _loggingInAccountId;
  String? _errorMessage;

  late final AnimationController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadAccounts();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final list = await SavedAccountsService.getSavedAccounts();
    if (mounted) {
      setState(() {
        _accounts = list;
        _isLoading = false;
      });
      // If all accounts were removed, seamlessly redirect to standard login
      if (list.isEmpty) {
        widget.onNavigateToLogin();
      }
    }
  }

  Color _getRoleColor(String roleStr) {
    final role = UserRole.fromString(roleStr);
    return switch (role) {
      UserRole.admin || UserRole.superAdmin => AppColors.adminRole,
      UserRole.teacher => AppColors.teacherRole,
      UserRole.student => AppColors.studentRole,
      UserRole.parent => AppColors.parentRole,
      UserRole.staff => AppColors.staffRole,
      _ => AppColors.primary,
    };
  }

  String _getRoleArabicLabel(String roleStr) {
    final role = UserRole.fromString(roleStr);
    return switch (role) {
      UserRole.admin || UserRole.superAdmin => '👨‍💼 إدارة السنتر',
      UserRole.teacher => '👨‍🏫 المعلم',
      UserRole.student => '🎓 الطالب',
      UserRole.parent => '👨‍👩‍👦 ولي الأمر',
      UserRole.staff => '💼 موظف العمليات',
      _ => 'مستخدم',
    };
  }

  Future<void> _handleAccountTap(SavedAccount account) async {
    if (_loggingInAccountId != null) return;

    if (account.password == null || account.password!.isEmpty) {
      // If no password saved, show quick password input dialog
      _promptPasswordForAccount(account);
      return;
    }

    setState(() {
      _loggingInAccountId = account.id.isNotEmpty ? account.id : account.email;
      _errorMessage = null;
    });

    try {
      await widget.viewModel.signIn(
        email: account.email,
        password: account.password!,
      );

      if (!mounted) return;

      if (widget.viewModel.state.status == AuthStatus.authenticated) {
        // Update last login timestamp
        await SavedAccountsService.saveAccount(
          account.copyWith(lastLoginAt: DateTime.now()),
        );
        widget.onLoginSuccess?.call();
      } else {
        setState(() {
          _loggingInAccountId = null;
          _errorMessage = 'تعذر تسجيل الدخول التلقائي. يرجى إدخال كلمة المرور.';
        });
        _promptPasswordForAccount(account);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loggingInAccountId = null;
          _errorMessage = 'حدث خطأ أثناء تسجيل الدخول: $e';
        });
      }
    }
  }

  void _promptPasswordForAccount(SavedAccount account) {
    final passCtrl = TextEditingController();
    bool obscure = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(account.role).withValues(alpha: 0.15),
                  child: Icon(Icons.lock_rounded, color: _getRoleColor(account.role)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تسجيل الدخول: ${account.fullName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.email,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscure,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _getRoleColor(account.role),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (passCtrl.text.isEmpty) return;
                        setDialogState(() => isSubmitting = true);

                        await widget.viewModel.signIn(
                          email: account.email,
                          password: passCtrl.text,
                        );

                        if (widget.viewModel.state.status == AuthStatus.authenticated) {
                          // Update saved password & timestamp
                          await SavedAccountsService.saveAccount(
                            account.copyWith(
                              password: passCtrl.text,
                              lastLoginAt: DateTime.now(),
                            ),
                          );
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          widget.onLoginSuccess?.call();
                        } else {
                          setDialogState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('كلمة المرور غير صحيحة، يرجى المحاولة ثانية.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text('دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveAccount(SavedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إزالة الحساب من الجهاز'),
          content: Text('هل أنت متأكد من إزالة حساب "${account.fullName}" من هذا الجهاز؟\n(يمكنك تسجيل الدخول به مجدداً في أي وقت).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إزالة الحساب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await SavedAccountsService.removeAccount(account.id.isNotEmpty ? account.id : account.email);
      await _loadAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: Stack(
          children: [
            // Background ambient animation
            if (isDark)
              AnimatedBuilder(
                animation: _ambientCtrl,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: -100 + math.sin(_ambientCtrl.value * 2 * math.pi) * 40,
                        right: -100 + math.cos(_ambientCtrl.value * 2 * math.pi) * 40,
                        child: Container(
                          width: 420,
                          height: 420,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.22),
                                AppColors.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -150 + math.cos(_ambientCtrl.value * 2 * math.pi) * 40,
                        left: -80 + math.sin(_ambientCtrl.value * 2 * math.pi) * 40,
                        child: Container(
                          width: 460,
                          height: 460,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.purple.withValues(alpha: 0.16),
                                AppColors.purple.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── 1. Hero Brand Header ──
                        FadeInSlide(
                          duration: const Duration(milliseconds: 600),
                          child: Column(
                            children: [
                              GlowContainer(
                                glowColor: AppColors.primary,
                                glowOpacity: 0.35,
                                padding: const EdgeInsets.all(16),
                                borderRadius: BorderRadius.circular(22),
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.purple],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                child: const Icon(
                                  Icons.account_circle_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'منظومة بريفيو التعليمية',
                                style: AppTypography.hero(textPrimary).copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'اختر حسابك للمتابعة والدخول السريع بنقرة واحدة ⚡',
                                style: AppTypography.bodySmall(textSecondary).copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── 2. Saved Accounts List / Grid ──
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          )
                        else ...[
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _accounts.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final acc = _accounts[index];
                              final isCurrentLoggingIn =
                                  (_loggingInAccountId == (acc.id.isNotEmpty ? acc.id : acc.email));
                              final roleColor = _getRoleColor(acc.role);

                              return FadeInSlide(
                                duration: const Duration(milliseconds: 500),
                                delay: Duration(milliseconds: 80 * index),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(14),
                                  color: isDark
                                      ? AppColors.darkSurface.withValues(alpha: 0.85)
                                      : Colors.white.withValues(alpha: 0.94),
                                  borderColor: isCurrentLoggingIn
                                      ? roleColor
                                      : (isDark ? Colors.white12 : AppColors.lightGlassBorder),
                                  blur: 0,
                                  child: InkWell(
                                    onTap: isCurrentLoggingIn ? null : () => _handleAccountTap(acc),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Row(
                                      children: [
                                        // Profile Avatar with Role Ring
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [roleColor, roleColor.withValues(alpha: 0.6)],
                                                ),
                                              ),
                                              padding: const EdgeInsets.all(2),
                                              child: CircleAvatar(
                                                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                                backgroundImage: acc.avatarUrl != null && acc.avatarUrl!.isNotEmpty
                                                    ? NetworkImage(acc.avatarUrl!)
                                                    : null,
                                                child: acc.avatarUrl == null || acc.avatarUrl!.isEmpty
                                                    ? Text(
                                                        acc.fullName.isNotEmpty ? acc.fullName[0].toUpperCase() : 'U',
                                                        style: TextStyle(
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                          color: roleColor,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            if (isCurrentLoggingIn)
                                              Container(
                                                width: 52,
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  color: Colors.black45,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 14),

                                        // Name, Role Badge, and Email
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                acc.fullName.isNotEmpty ? acc.fullName : acc.email,
                                                style: AppTypography.titleMedium(textPrimary).copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: roleColor.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      _getRoleArabicLabel(acc.role),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: roleColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      acc.email,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Remove Account Button
                                        IconButton(
                                          tooltip: 'إزالة الحساب من الجهاز',
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: textSecondary.withValues(alpha: 0.6),
                                          ),
                                          onPressed: () => _confirmRemoveAccount(acc),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          // ── 3. Action: Log in with another account (Facebook style "+") ──
                          FadeInSlide(
                            duration: const Duration(milliseconds: 600),
                            delay: const Duration(milliseconds: 200),
                            child: PrimaryButton(
                              text: 'تسجيل الدخول بحساب آخر ➕',
                              onPressed: widget.onNavigateToLogin,
                              icon: Icons.person_add_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
