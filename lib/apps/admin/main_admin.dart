import 'package:flutter/material.dart';
import '../../core/app/academy_material_app.dart';
import '../../core/auth/auth_loading_screen.dart';
import '../../core/di/injection.dart';
import '../../design_system/tokens/colors.dart';
import '../../core/security/access_denied_screen.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencyInjection();
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<AuthViewModel>();
    _viewModel.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return AcademyMaterialApp(
      titleKey: 'admin_dashboard',
      home: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;

          if (state.status == AuthStatus.initial ||
              (state.status == AuthStatus.loading &&
                  _viewModel.isRestoringSession)) {
            return const AuthLoadingScreen(
              title: 'فتح لوحة تحكم الإدارة',
              subtitle:
                  'جاري تحميل أدوات الإدارة والصلاحيات والوصول الآمن...',
              icon: Icons.admin_panel_settings_rounded,
              accentColor: AppColors.adminRole,
            );
          }

          if (state.status == AuthStatus.authenticated) {
            final role = _viewModel.userRole;
            if (role == UserRole.admin || role == UserRole.superAdmin) {
              return AdminDashboard(authViewModel: _viewModel);
            }
            return PortalDeniedScreen(
              currentRole: role,
              targetPortalName: 'لوحة تحكم الإدارة',
              onSignOut: () => _viewModel.signOut(),
            );
          }

          if (state.status == AuthStatus.restricted) {
            return AccountRestrictedScreen(
              onSignOut: () => _viewModel.signOut(),
            );
          }

          return LoginScreen(targetRole: UserRole.admin, viewModel: _viewModel);
        },
      ),
    );
  }
}
