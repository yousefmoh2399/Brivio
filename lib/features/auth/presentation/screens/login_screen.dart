import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/components/text_fields.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/user_role.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../academy/presentation/screens/register_center_screen.dart';
import '../../../legal/presentation/screens/privacy_and_terms_screen.dart';
import '../../../../core/services/saved_accounts_service.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole? targetRole;
  final AuthViewModel viewModel;
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onNavigateToSavedAccounts;
  final bool hasSavedAccounts;

  const LoginScreen({
    super.key,
    this.targetRole,
    required this.viewModel,
    this.onLoginSuccess,
    this.onNavigateToSavedAccounts,
    this.hasSavedAccounts = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  UserRole? _selectedRole;
  String? _qrMessage;
  String? _pendingQrToken;

  Widget? _roleCircle;
  Widget? _purpleCircle;

  late final AnimationController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.targetRole;
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetRole != widget.targetRole) {
      setState(() {
        _selectedRole = widget.targetRole;
        _roleCircle = null;
      });
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('brivio_remember_login') ?? true;
      final savedEmail = prefs.getString('brivio_saved_email');
      if (mounted) {
        setState(() {
          _rememberMe = remember;
          if (remember && savedEmail != null && savedEmail.isNotEmpty) {
            _emailController.text = savedEmail;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _persistCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('brivio_remember_login', _rememberMe);
      if (_rememberMe) {
        await prefs.setString('brivio_saved_email', _emailController.text.trim());
      } else {
        await prefs.remove('brivio_saved_email');
      }
    } catch (_) {}
  }

  Color get _roleColor {
    final effectiveRole = _selectedRole ?? widget.targetRole;
    if (effectiveRole == null) return AppColors.primary;
    switch (effectiveRole) {
      case UserRole.student:
        return AppColors.studentRole;
      case UserRole.teacher:
        return AppColors.teacherRole;
      case UserRole.parent:
        return AppColors.parentRole;
      case UserRole.staff:
        return AppColors.staffRole;
      case UserRole.admin:
      case UserRole.superAdmin:
        return AppColors.adminRole;
      case UserRole.unknown:
        return AppColors.primary;
    }
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _persistCredentials();

    final enteredEmail = _emailController.text.trim();
    final enteredPassword = _passwordController.text;

    await widget.viewModel.signIn(
      email: enteredEmail,
      password: enteredPassword,
    );
    if (widget.viewModel.state.status == AuthStatus.authenticated) {
      await _consumePendingQrToken();
      await _handlePostLoginSaveAccount(
        email: enteredEmail,
        password: enteredPassword,
      );
      widget.onLoginSuccess?.call();
    }
  }

  Future<bool?> _showSaveLoginInfoDialog({
    required String name,
    required String email,
    required UserRole role,
    String? avatarUrl,
  }) async {
    if (!mounted) return false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = switch (role) {
      UserRole.admin || UserRole.superAdmin => AppColors.adminRole,
      UserRole.teacher => AppColors.teacherRole,
      UserRole.student => AppColors.studentRole,
      UserRole.parent => AppColors.parentRole,
      UserRole.staff => AppColors.staffRole,
      _ => AppColors.primary,
    };

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [roleColor, roleColor.withValues(alpha: 0.7)],
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'حفظ معلومات تسجيل الدخول؟',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'هل ترغب في حفظ حساب "$name" على هذا الجهاز؟',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'ستتمكن من تسجيل الدخول بنقرة واحدة في المرات القادمة دون الحاجة لإعادة كتابة كلمة المرور.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ليس الآن'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: roleColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.bookmark_added_rounded, size: 18),
                    label: const Text(
                      'حفظ الحساب',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _handlePostLoginSaveAccount({
    required String email,
    required String password,
  }) async {
    try {
      final profile = widget.viewModel.currentUser;
      final effectiveRole = profile?.role ?? _selectedRole ?? widget.targetRole ?? UserRole.student;
      final effectiveName = (profile?.fullName.isNotEmpty ?? false)
          ? profile!.fullName
          : email.split('@').first;
      final userId = profile?.id ?? '';

      final isAlreadySaved = await SavedAccountsService.isAccountSaved(email);
      if (!isAlreadySaved) {
        final shouldSave = await _showSaveLoginInfoDialog(
          name: effectiveName,
          email: email,
          role: effectiveRole,
          avatarUrl: profile?.avatarUrl,
        );
        if (shouldSave == true) {
          await SavedAccountsService.saveAccount(
            SavedAccount(
              id: userId,
              email: email,
              fullName: effectiveName,
              role: effectiveRole.toDbValue(),
              avatarUrl: profile?.avatarUrl,
              password: password.isNotEmpty ? password : null,
              lastLoginAt: DateTime.now(),
            ),
          );
        }
      } else {
        final accounts = await SavedAccountsService.getSavedAccounts();
        final existingIndex = accounts.indexWhere(
          (a) => a.email.toLowerCase() == email.toLowerCase() || (userId.isNotEmpty && a.id == userId),
        );
        if (existingIndex != -1) {
          final existing = accounts[existingIndex];
          await SavedAccountsService.saveAccount(
            existing.copyWith(
              password: password.isNotEmpty ? password : existing.password,
              lastLoginAt: DateTime.now(),
              avatarUrl: profile?.avatarUrl ?? existing.avatarUrl,
              fullName: effectiveName.isNotEmpty ? effectiveName : existing.fullName,
              role: effectiveRole.toDbValue(),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _consumePendingQrToken() async {
    final token = _pendingQrToken;
    if (token == null) return;

    try {
      await Supabase.instance.client.rpc(
        'consume_account_login_qr',
        params: {'p_token': token},
      );
      _pendingQrToken = null;
    } catch (_) {
      // Session established; token cleanup failure can be safely ignored.
    }
  }

  Future<void> _openQrLoginScanner() async {
    final result = await showModalBottomSheet<_QrLoginResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QrLoginScannerSheet(),
    );
    if (result == null || !mounted) return;

    if (result.isMagicQr) {
      setState(() {
        _qrMessage = 'جاري تسجيل الدخول التلقائي لحساب ${result.email}...';
      });
      await widget.viewModel.signInWithMagicQr(
        email: result.email,
        token: result.token,
      );
      if (widget.viewModel.state.status == AuthStatus.authenticated) {
        await _handlePostLoginSaveAccount(
          email: result.email,
          password: '',
        );
        widget.onLoginSuccess?.call();
      } else {
        setState(() {
          _qrMessage = null;
        });
      }
    } else {
      await _openAccountQrPasswordSetup(result);
    }
  }

  Future<void> _openAccountQrPasswordSetup(_QrLoginResult result) async {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QrPasswordSetupDialog(result: result),
    );
    if (password == null || !mounted) return;

    setState(() {
      _emailController.text = result.email;
      _pendingQrToken = null;
      _qrMessage = 'تم تعيين كلمة المرور بنجاح. جاري تسجيل دخول ${result.fullName}...';
    });

    await widget.viewModel.signIn(email: result.email, password: password);

    if (!mounted) return;
    if (widget.viewModel.state.status == AuthStatus.authenticated) {
      await _handlePostLoginSaveAccount(
        email: result.email,
        password: password,
      );
      widget.onLoginSuccess?.call();
    } else {
      setState(() => _qrMessage = null);
    }
  }

  void _fillQuickCredentials(String email, String password, UserRole role) {
    setState(() {
      _selectedRole = role;
      _roleCircle = null;
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  String _formatErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials') ||
        lower.contains('wrong password')) {
      return 'بيانات الدخول غير صحيحة. يرجى مراجعة البريد وكلمة المرور.';
    }
    if (lower.contains('email not confirmed')) {
      return 'البريد الإلكتروني غير مؤكد. يرجى تفعيل حسابك أولاً.';
    }
    if (lower.contains('network') || lower.contains('socketexception') || lower.contains('failed host lookup')) {
      return 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.';
    }
    if (lower.contains('too many requests')) {
      return 'محاولات دخول كثيرة خاطئة. يرجى الانتظار قليلاً ثم المحاولة.';
    }
    return raw;
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final state = widget.viewModel.state;

          return Scaffold(
            backgroundColor: isDark
                ? AppColors.darkBackground
                : AppColors.lightBackground,
            body: Stack(
              children: [
                // Animated ambient glow background
                if (isDark) ...[
                  Builder(
                    builder: (context) {
                      _roleCircle ??= Container(
                        width: 440,
                        height: 440,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _roleColor.withValues(alpha: 0.28),
                              _roleColor.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      );
                      _purpleCircle ??= Container(
                        width: 520,
                        height: 520,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.purple.withValues(alpha: 0.20),
                              AppColors.purple.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      );
                      return const SizedBox();
                    },
                  ),
                  AnimatedBuilder(
                    animation: _ambientCtrl,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Positioned(
                            top: -150 + math.sin(_ambientCtrl.value * 2 * math.pi) * 50,
                            right: -100 + math.cos(_ambientCtrl.value * 2 * math.pi) * 50,
                            child: _roleCircle!,
                          ),
                          Positioned(
                            bottom: -200 + math.cos(_ambientCtrl.value * 2 * math.pi) * 50,
                            left: -100 + math.sin(_ambientCtrl.value * 2 * math.pi) * 50,
                            child: _purpleCircle!,
                          ),
                        ],
                      );
                    },
                  ),
                ],

                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.hasSavedAccounts && widget.onNavigateToSavedAccounts != null) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: widget.onNavigateToSavedAccounts,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _roleColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _roleColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_forward_rounded, size: 16, color: _roleColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          'التبديل إلى الحسابات المحفوظة 👥',
                                          style: TextStyle(
                                            color: _roleColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ── 1. Hero Brand Panel ──
                            FadeInSlide(
                              duration: const Duration(milliseconds: 600),
                              child: _AppleHeroPanel(
                                roleColor: _roleColor,
                                role: _selectedRole ?? widget.targetRole,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── 2. Interactive Role Switcher ──
                            FadeInSlide(
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 100),
                              child: _buildRoleSelectorBar(isDark),
                            ),
                            const SizedBox(height: 16),

                            // ── 3. Main Glass Card Form ──
                            FadeInSlide(
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 150),
                              child: GlassCard(
                                padding: const EdgeInsets.all(24),
                                color: isDark
                                    ? AppColors.darkSurface.withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.94),
                                borderColor: isDark
                                    ? _roleColor.withValues(alpha: 0.25)
                                    : AppColors.lightGlassBorder,
                                blur: 0,
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'تسجيل الدخول',
                                                  style: AppTypography.displaySmall(textPrimary).copyWith(
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'أهلاً بك مجدداً! أدخل بيانات حسابك للمتابعة.',
                                                  style: AppTypography.bodySmall(textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: _roleColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.lock_person_rounded, color: _roleColor, size: 24),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // Alert banner
                                      if (state.status == AuthStatus.error && state.failure != null) ...[
                                        _AppleAlertBanner(
                                          message: _formatErrorMessage(state.failure!.message),
                                          isError: true,
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      if (_qrMessage != null) ...[
                                        _AppleAlertBanner(
                                          message: _qrMessage!,
                                          isError: false,
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      // Email Field
                                      CustomTextField(
                                        label: 'البريد الإلكتروني',
                                        hint: 'name@example.com',
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        prefixIcon: Icons.alternate_email_rounded,
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'يرجى إدخال البريد الإلكتروني';
                                          }
                                          if (!value.contains('@')) {
                                            return 'صيغة البريد الإلكتروني غير صالحة';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      // Password Field
                                      CustomTextField(
                                        label: 'كلمة المرور',
                                        hint: '••••••••',
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        prefixIcon: Icons.lock_outline_rounded,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: textSecondary,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'يرجى إدخال كلمة المرور';
                                          }
                                          if (value.length < 6) {
                                            return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      // Remember Me & Forgot Password Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          InkWell(
                                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: Checkbox(
                                                    value: _rememberMe,
                                                    activeColor: _roleColor,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    onChanged: (val) {
                                                      if (val != null) {
                                                        setState(() => _rememberMe = val);
                                                      }
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'تذكرني',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => ForgotPasswordScreen(
                                                    viewModel: widget.viewModel,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            child: Text(
                                              'نسيت كلمة المرور؟',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _roleColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 22),

                                      // Submit Button
                                      PrimaryButton(
                                        text: 'تسجيل الدخول',
                                        isLoading: state.status == AuthStatus.loading,
                                        onPressed: _handleLogin,
                                        icon: Icons.login_rounded,
                                        color: _roleColor,
                                        gradient: LinearGradient(
                                          colors: [
                                            _roleColor,
                                            HSLColor.fromColor(_roleColor)
                                                .withLightness(
                                                  math.max(
                                                    0.0,
                                                    HSLColor.fromColor(_roleColor).lightness - 0.12,
                                                  ),
                                                )
                                                .toColor(),
                                          ],
                                          begin: Alignment.topRight,
                                          end: Alignment.bottomLeft,
                                        ),
                                      ),

                                      // QR Login Button
                                      const SizedBox(height: 14),
                                      GhostButton(
                                        text: 'تسجيل الدخول السريع عبر QR Code 📷',
                                        icon: Icons.qr_code_scanner_rounded,
                                        onPressed: state.status == AuthStatus.loading
                                            ? null
                                            : _openQrLoginScanner,
                                        color: textPrimary,
                                      ),

                                      // Quick Demo Credentials Selector
                                      const SizedBox(height: 16),
                                      _buildQuickDemoAccounts(isDark),

                                      // Register Center CTA
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 46),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          side: BorderSide(
                                            color: AppColors.primary.withValues(alpha: 0.4),
                                            width: 1.2,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.add_business_rounded,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'صاحب سنتر؟ سجّل سنترك الآن مجاناً 🏢',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        onPressed: state.status == AuthStatus.loading
                                            ? null
                                            : () async {
                                                final res = await Navigator.of(context).push<bool>(
                                                  MaterialPageRoute(
                                                    builder: (_) => const RegisterCenterScreen(),
                                                  ),
                                                );
                                                if (res == true) {
                                                  widget.viewModel.restoreSession();
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── 4. Privacy & Security Footer ──
                            FadeInSlide(
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 250),
                              child: TextButton.icon(
                                onPressed: () => PrivacyAndTermsScreen.show(context),
                                icon: Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: textSecondary.withValues(alpha: 0.7),
                                ),
                                label: Text(
                                  'شروط الخدمة وسياسة الخصوصية وأمان البيانات',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary.withValues(alpha: 0.85),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleSelectorBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRoleChip(label: 'الكل', role: null, isDark: isDark),
          const SizedBox(width: 6),
          _buildRoleChip(label: '👨‍💼 الإدارة', role: UserRole.admin, isDark: isDark),
          const SizedBox(width: 6),
          _buildRoleChip(label: '👨‍🏫 المعلم', role: UserRole.teacher, isDark: isDark),
          const SizedBox(width: 6),
          _buildRoleChip(label: '🎓 الطالب', role: UserRole.student, isDark: isDark),
          const SizedBox(width: 6),
          _buildRoleChip(label: '👨‍👩‍👦 ولي الأمر', role: UserRole.parent, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildRoleChip({
    required String label,
    required UserRole? role,
    required bool isDark,
  }) {
    final isSelected = (_selectedRole == role);
    final chipColor = role == null
        ? AppColors.primary
        : switch (role) {
            UserRole.admin || UserRole.superAdmin => AppColors.adminRole,
            UserRole.teacher => AppColors.teacherRole,
            UserRole.student => AppColors.studentRole,
            UserRole.parent => AppColors.parentRole,
            _ => AppColors.primary,
          };

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _roleCircle = null;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.transparent,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? chipColor
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDemoAccounts(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                'تجربة سريعة بحسابات افتراضية:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildDemoFillChip('أدمن', 'admin@brivio.com', '123456', UserRole.admin, AppColors.adminRole),
              _buildDemoFillChip('معلم', 'teacher@brivio.com', '123456', UserRole.teacher, AppColors.teacherRole),
              _buildDemoFillChip('طالب', 'student@brivio.com', '123456', UserRole.student, AppColors.studentRole),
              _buildDemoFillChip('ولي أمر', 'parent@brivio.com', '123456', UserRole.parent, AppColors.parentRole),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoFillChip(
    String label,
    String email,
    String password,
    UserRole role,
    Color color,
  ) {
    return InkWell(
      onTap: () => _fillQuickCredentials(email, password, role),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _AppleHeroPanel extends StatelessWidget {
  final Color roleColor;
  final UserRole? role;

  const _AppleHeroPanel({required this.roleColor, required this.role});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final IconData roleIcon;
    final String roleSubtitle;
    if (role == null) {
      roleIcon = Icons.school_rounded;
      roleSubtitle = 'المنظومة الرقمية الشاملة لإدارة المراكز والسناتر التعليمية';
    } else {
      switch (role!) {
        case UserRole.admin:
        case UserRole.superAdmin:
          roleIcon = Icons.admin_panel_settings_rounded;
          roleSubtitle = 'مساحة عمل إدارة السنتر والفروع والخزينة';
          break;
        case UserRole.teacher:
          roleIcon = Icons.co_present_rounded;
          roleSubtitle = 'بوابة المعلم لإدارة الحصص والطلاب والواجبات';
          break;
        case UserRole.student:
          roleIcon = Icons.menu_book_rounded;
          roleSubtitle = 'بوابة الطالب لمتابعة الدروس والواجبات والمذكرات';
          break;
        case UserRole.parent:
          roleIcon = Icons.family_restroom_rounded;
          roleSubtitle = 'بوابة ولي الأمر لمتابعة حضور ونتائج الأبناء';
          break;
        case UserRole.staff:
          roleIcon = Icons.badge_rounded;
          roleSubtitle = 'بوابة موظفي الاستقبال والعمليات';
          break;
        case UserRole.unknown:
          roleIcon = Icons.school_rounded;
          roleSubtitle = 'تسجيل الدخول إلى حسابك';
          break;
      }
    }

    return Column(
      children: [
        GlowContainer(
          glowColor: roleColor,
          glowOpacity: 0.35,
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              roleColor,
              HSLColor.fromColor(roleColor)
                  .withLightness(
                    math.max(
                      0.0,
                      HSLColor.fromColor(roleColor).lightness - 0.1,
                    ),
                  )
                  .toColor(),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Icon(
            roleIcon,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'منظومة بريفيو التعليمية',
          style: AppTypography.hero(textPrimary).copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          roleSubtitle,
          style: AppTypography.bodySmall(textSecondary).copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        if (role != null) ...[
          const SizedBox(height: 10),
          StatusChip(
            label: 'مساحة ${role!.displayNameArabic}',
            status: ChipStatus.info,
          ),
        ],
      ],
    );
  }
}

class _AppleAlertBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _AppleAlertBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final accentColor = isError ? AppColors.error : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: accentColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium(
                accentColor,
              ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPasswordSetupDialog extends StatefulWidget {
  final _QrLoginResult result;

  const _QrPasswordSetupDialog({required this.result});

  @override
  State<_QrPasswordSetupDialog> createState() => _QrPasswordSetupDialogState();
}

class _QrPasswordSetupDialogState extends State<_QrPasswordSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'complete-account-login-qr',
        body: {
          'token': widget.result.token,
          'password': _passwordController.text,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        final message = data is Map ? data['error']?.toString() : null;
        throw Exception(message ?? 'فشل حفظ كلمة المرور للباركود.');
      }

      if (!mounted) return;
      Navigator.pop(context, _passwordController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyQrSetupError(e);
        _isSaving = false;
      });
    }
  }

  String _friendlyQrSetupError(Object error) {
    final text = error.toString();
    if (text.contains('Requested function was not found') ||
        text.contains('status: 404')) {
      return 'خدمة إعداد كلمة مرور QR غير منشورة حالياً بالسيرفر.';
    }
    return text;
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تعيين كلمة المرور لحسابك'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: .14),
                          child: const Icon(Icons.qr_code_2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.result.fullName,
                                style: AppTypography.titleMedium(textPrimary),
                              ),
                              Text(
                                widget.result.email,
                                style: AppTypography.bodySmall(textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'كلمة المرور يجب ألا تقل عن 6 أحرف.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'كلمات المرور غير متطابقة.';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _savePassword,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: const Text('حفظ ومتابعة الدخول'),
          ),
        ],
      ),
    );
  }
}

class _QrLoginResult {
  final String token;
  final String email;
  final String fullName;
  final String role;
  final bool isMagicQr;

  const _QrLoginResult({
    required this.token,
    required this.email,
    required this.fullName,
    required this.role,
    this.isMagicQr = false,
  });
}

class _QrLoginScannerSheet extends StatefulWidget {
  const _QrLoginScannerSheet();

  @override
  State<_QrLoginScannerSheet> createState() => _QrLoginScannerSheetState();
}

class _QrLoginScannerSheetState extends State<_QrLoginScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isResolving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_isResolving) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((raw) => raw.trim().isNotEmpty)
        .firstOrNull;
    if (value == null) return;

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map && decoded['type'] == 'magic_qr') {
        setState(() {
          _isResolving = true;
          _errorMessage = null;
        });
        if (!mounted) return;
        Navigator.pop(
          context,
          _QrLoginResult(
            token: decoded['token']?.toString() ?? '',
            email: decoded['email']?.toString() ?? '',
            fullName: 'حساب مسجل',
            role: '',
            isMagicQr: true,
          ),
        );
        return;
      }
    } catch (_) {}

    final token = _extractAccountQrToken(value);
    if (token == null) {
      setState(() => _errorMessage = 'هذا الرمز ليس كود QR صالح لتسجيل الدخول.');
      return;
    }

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'resolve_account_login_qr',
        params: {'p_token': token},
      );
      final json = Map<String, dynamic>.from(response as Map);
      if (!mounted) return;
      Navigator.pop(
        context,
        _QrLoginResult(
          token: token,
          email: json['email']?.toString() ?? '',
          fullName: json['full_name']?.toString() ?? 'مستخدم',
          role: json['role']?.toString() ?? '',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isResolving = false;
      });
    }
  }

  String? _extractAccountQrToken(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['type'] == 'account_login_qr') {
        return decoded['token']?.toString();
      }
    } catch (_) {}

    if (raw.startsWith('acctqr_')) return raw;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: MediaQuery.of(context).size.height * .75,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'مسح كود الدخول السريع (QR)',
                          style: AppTypography.displaySmall(textPrimary),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white12
                              : Colors.black12,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: _controller,
                            onDetect: _handleCapture,
                          ),
                          if (_isResolving)
                            Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorMessage ??
                        'وجّه الكاميرا نحو كود بطاقة الدخول أو الكارنيه للدخول فوراً.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(
                      _errorMessage != null
                          ? AppColors.error
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
