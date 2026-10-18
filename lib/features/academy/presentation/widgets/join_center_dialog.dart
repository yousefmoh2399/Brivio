import 'package:flutter/material.dart';

import '../screens/join_center_screen.dart';

/// Screen / Dialog entry point allowing a teacher, student, or staff to join an educational center by code.
/// Delegates directly to the Executive AAA responsive [JoinCenterScreen].
class JoinCenterDialog extends StatelessWidget {
  final VoidCallback? onSuccess;
  final String role;

  const JoinCenterDialog({
    super.key,
    this.onSuccess,
    this.role = 'teacher',
  });

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onSuccess,
    VoidCallback? onJoined,
    String role = 'teacher',
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => JoinCenterScreen(
          role: role,
          onSuccess: onJoined ?? onSuccess,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return JoinCenterScreen(
      role: role,
      onSuccess: onSuccess,
    );
  }
}
