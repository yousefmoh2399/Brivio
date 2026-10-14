import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../data/repositories/supabase_center_repository.dart';

class CenterLinkDialog extends StatefulWidget {
  const CenterLinkDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => const CenterLinkDialog(),
    );
  }

  @override
  State<CenterLinkDialog> createState() => _CenterLinkDialogState();
}

class _CenterLinkDialogState extends State<CenterLinkDialog> {
  final _codeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLink() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = SupabaseCenterRepository(
        SupabaseClientWrapper(Supabase.instance.client),
      );

      await repo.linkCentersByCode(
        targetCenterCode: code,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب الربط والشراكة للسنتر بنجاح!'),
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
            Icon(Icons.link_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text('ربط وشراكة مع سنتر آخر', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'يتيح لك الربط مشاركة جداول المدرسين المشتركين، ومنع تعارض أوقات الحصص بينهم في السنترين، مع الحفاظ على سرية واستقلال بيانات كل سنتر ومالياته بالكامل.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'كود السنتر المراد الربط معه *',
                  hintText: 'مثال: CTR-A8F290',
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ملاحظات أو رسالة لإدارة السنتر (اختياري)',
                  hintText: 'مثال: طلب ربط لمشاركة جدول أستاذ محمد لمادة الفيزياء',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _isLoading ? null : _handleLink,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('إرسال طلب الربط'),
          ),
        ],
      ),
    );
  }
}
