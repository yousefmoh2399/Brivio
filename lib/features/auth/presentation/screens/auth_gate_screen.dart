import 'package:flutter/material.dart';
import '../../../../core/services/saved_accounts_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_screen.dart';
import 'saved_accounts_screen.dart';

/// Coordinator screen handling navigation between saved accounts (Facebook style)
/// and the standard login screen.
class AuthGateScreen extends StatefulWidget {
  final AuthViewModel viewModel;

  const AuthGateScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isLoading = true;
  bool _hasSavedAccounts = false;
  bool _forceShowLogin = false;

  @override
  void initState() {
    super.initState();
    _checkSavedAccounts();
  }

  Future<void> _checkSavedAccounts() async {
    final accounts = await SavedAccountsService.getSavedAccounts();
    if (mounted) {
      setState(() {
        _hasSavedAccounts = accounts.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasSavedAccounts && !_forceShowLogin) {
      return SavedAccountsScreen(
        key: const ValueKey('saved_accounts_screen'),
        viewModel: widget.viewModel,
        onNavigateToLogin: () {
          setState(() {
            _forceShowLogin = true;
          });
        },
      );
    }

    return LoginScreen(
      key: const ValueKey('standard_login_screen'),
      viewModel: widget.viewModel,
      hasSavedAccounts: _hasSavedAccounts,
      onNavigateToSavedAccounts: _hasSavedAccounts
          ? () {
              setState(() {
                _forceShowLogin = false;
              });
              _checkSavedAccounts();
            }
          : null,
    );
  }
}
