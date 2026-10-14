import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/repositories/supabase_center_repository.dart';

/// Dialog allowing a student, teacher, or parent to join an educational center by code.
class JoinCenterDialog extends StatefulWidget {
  final VoidCallback? onSuccess;

  const JoinCenterDialog({super.key, this.onSuccess});

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onSuccess,
    VoidCallback? onJoined,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => JoinCenterDialog(
        onSuccess: onJoined ?? onSuccess,
      ),
    );
  }

  @override
  State<JoinCenterDialog> createState() => _JoinCenterDialogState();
}

class _JoinCenterDialogState extends State<JoinCenterDialog> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كود السنتر');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = SupabaseCenterRepository(
        SupabaseClientWrapper(Supabase.instance.client),
      );
      final res = await repo.joinCenterByCode(code);

      if (!mounted) return;

      final centerName = res['center_name']?.toString() ?? '';

      // Reload auth bootstrap to update available centers
      try {
        await context.read<AuthViewModel>().reloadBootstrap();
      } catch (_) {}

      widget.onSuccess?.call();

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الانضمام بنجاح إلى: $centerName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.add_business_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text(
              'الانضمام إلى سنتر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل كود السنتر (المقدم لك من إدارة السنتر) للوصول إلى حصصك ومجموعاتك.',
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'كود السنتر (مثال: CTR-A8F21B)',
                prefixIcon: const Icon(Icons.qr_code_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.05),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: _isLoading ? null : _handleJoin,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('انضمام الآن'),
          ),
        ],
      ),
    );
  }
}
