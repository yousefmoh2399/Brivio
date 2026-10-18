import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'core/config/app_config.dart';
import 'core/error/supabase_error_handler.dart';
import 'firebase_options.dart';
import 'apps/admin/admin_dashboard.dart';
import 'apps/parent/parent_dashboard.dart';
import 'apps/staff/staff_dashboard.dart';
import 'apps/student/student_dashboard.dart';
import 'apps/teacher/teacher_dashboard.dart';
import 'core/app/academy_material_app.dart';
import 'core/auth/auth_loading_screen.dart';
import 'core/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/security/access_denied_screen.dart';
import 'core/services/settings_service.dart';
import 'design_system/tokens/colors.dart';
import 'design_system/theme/app_theme.dart';
import 'features/auth/domain/models/user_role.dart';
import 'features/auth/presentation/screens/auth_gate_screen.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> globalScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void _showGlobalError(Object error) {
  if (!_shouldShowGlobalError(error)) return;
  final message = SupabaseErrorHandler.parseError(error);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (globalScaffoldMessengerKey.currentState != null) {
      globalScaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}

bool _shouldShowGlobalError(Object error) {
  final text = error.toString();
  return !text.contains(
    'ListTile background color or ink splashes may be invisible',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _showGlobalError(details.exception);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Unhandled async error', error, stack);
    _showGlobalError(error);
    return true;
  };

  try {
    await _initializeFirebaseIfAvailable();

    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    await Hive.openBox('study_workspace_cache');

    await setupDependencyInjection().timeout(const Duration(seconds: 20));
    runApp(const MainAppSelector());
  } catch (error, stackTrace) {
    AppLogger.error('Application startup failed', error, stackTrace);
    runApp(StartupFailureApp(error: error));
  }
}

bool get _supportsFirebaseRuntime {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

Future<void> _initializeFirebaseIfAvailable() async {
  if (!_supportsFirebaseRuntime || Firebase.apps.isNotEmpty) return;
  try {
    if (AppConfig.hasFirebaseConfig) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error, stackTrace) {
    AppLogger.warning('Firebase is not configured for this runtime.');
    AppLogger.error('Firebase startup skipped', error, stackTrace);
  }
}

class StartupFailureApp extends StatelessWidget {
  final Object error;

  const StartupFailureApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: globalScaffoldMessengerKey,
      title: 'Academy Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Startup failed',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      main();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainAppSelector extends StatefulWidget {
  const MainAppSelector({super.key});

  @override
  State<MainAppSelector> createState() => _MainAppSelectorState();
}

class _MainAppSelectorState extends State<MainAppSelector> {
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<AuthViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.restoreSession();
    });
  }

  Widget _buildRoleDashboard(UserRole role) {
    switch (role) {
      case UserRole.admin:
      case UserRole.superAdmin:
        return AdminDashboard(authViewModel: _viewModel);
      case UserRole.staff:
        return StaffDashboard(authViewModel: _viewModel);
      case UserRole.teacher:
        return TeacherDashboard(authViewModel: _viewModel);
      case UserRole.student:
        return StudentDashboard(authViewModel: _viewModel);
      case UserRole.parent:
        return ParentDashboard(authViewModel: _viewModel);
      case UserRole.unknown:
        return PortalDeniedScreen(
          currentRole: role,
          targetPortalName: 'Academy Platform',
          onSignOut: () => _viewModel.signOut(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AcademyMaterialApp(
      navigatorKey: globalNavigatorKey,
      scaffoldMessengerKey: globalScaffoldMessengerKey,
      titleKey: 'academy_platform',
      home: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;

          switch (state.status) {
            case AuthStatus.initial:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case AuthStatus.loading:
              if (_viewModel.isRestoringSession) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return AuthGateScreen(viewModel: _viewModel);
            case AuthStatus.authenticated:
              final role = _viewModel.userRole;
              if (role != null) {
                final isFresh = _viewModel.hasFreshlyAuthenticated;
                if (isFresh) {
                  _viewModel.consumeFreshlyAuthenticated();
                }
                return BiometricGate(
                  isFreshLogin: isFresh,
                  onSignOut: () {
                    BiometricGate.resetSessionLock();
                    _viewModel.signOut();
                  },
                  child: _buildRoleDashboard(role),
                );
              }
              return PortalDeniedScreen(
                currentRole: role,
                targetPortalName: 'Academy Platform',
                onSignOut: () {
                  BiometricGate.resetSessionLock();
                  _viewModel.signOut();
                },
              );
            case AuthStatus.restricted:
              return AccountRestrictedScreen(
                onSignOut: () {
                  BiometricGate.resetSessionLock();
                  _viewModel.signOut();
                },
              );
            case AuthStatus.unauthenticated:
            case AuthStatus.error:
              return AuthGateScreen(viewModel: _viewModel);
          }
        },
      ),
    );
  }
}

class BiometricGate extends StatefulWidget {
  final Widget child;
  final VoidCallback onSignOut;
  final bool isFreshLogin;

  const BiometricGate({
    super.key,
    required this.child,
    required this.onSignOut,
    this.isFreshLogin = false,
  });

  static bool _sessionUnlocked = false;

  static void resetSessionLock() {
    _sessionUnlocked = false;
  }

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  late bool _unlocked;
  late bool _checking;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final settings = getIt<SettingsService>();
    if (widget.isFreshLogin ||
        BiometricGate._sessionUnlocked ||
        !settings.biometricLogin ||
        kIsWeb) {
      BiometricGate._sessionUnlocked = true;
      _unlocked = true;
      _checking = false;
    } else {
      _unlocked = false;
      _checking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  Future<void> _unlock() async {
    final settings = getIt<SettingsService>();
    if (!settings.biometricLogin || kIsWeb) {
      BiometricGate._sessionUnlocked = true;
      if (mounted) {
        setState(() {
          _unlocked = true;
          _checking = false;
        });
      }
      return;
    }

    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final canCheckBiometrics = await auth.canCheckBiometrics;
      if (!supported && !canCheckBiometrics) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'خاصية الدخول بالبصمة مفعلة، ولكن الجهاز لا يحتوي على مستشعر بصمة متاح أو غير مهيأ.';
          _checking = false;
        });
        return;
      }

      final didAuthenticate = await auth.authenticate(
        localizedReason:
            'يرجى تأكيد الهوية باستخدام البصمة أو قفل الشاشة للدخول للمنظومة',
      );
      if (!mounted) return;
      if (didAuthenticate) {
        BiometricGate._sessionUnlocked = true;
      }
      setState(() {
        _unlocked = didAuthenticate;
        _checking = false;
        _errorMessage = didAuthenticate ? null : 'تم إلغاء تأكيد الهوية.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _errorMessage =
            'تعذر التحقق من البصمة حالياً. يمكنك إعادة المحاولة أو تعطيل القفل البيومتري للدخول.';
      });
    }
  }

  Future<void> _disableBiometricsAndEnter() async {
    final settings = getIt<SettingsService>();
    await settings.updateBiometricLogin(false);
    BiometricGate._sessionUnlocked = true;
    if (!mounted) return;
    setState(() {
      _unlocked = true;
      _checking = false;
      _errorMessage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تعطيل القفل بالبصمة بنجاح والدخول للمنصة.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    if (_checking) {
      return const AuthLoadingScreen(
        title: 'التحقق الآمن',
        subtitle: 'جارٍ التحقق من البصمة لفتح المنظومة التعليمية...',
        icon: Icons.fingerprint_rounded,
        accentColor: AppColors.primary,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'قفل التطبيق البيومتري',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage ??
                          'يرجى تأكيد الهوية بالبصمة أو رمز القفل للمتابعة.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _checking = true;
                            _errorMessage = null;
                          });
                          _unlock();
                        },
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('إعادة المحاولة بالبصمة'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _disableBiometricsAndEnter,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('تعطيل قفل البصمة والدخول'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: widget.onSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('تسجيل الخروج والعودة لشاشة الدخول'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
