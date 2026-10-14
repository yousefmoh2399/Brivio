import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../data/parent_repository.dart';

class LinkChildScreen extends StatefulWidget {
  const LinkChildScreen({super.key});

  @override
  State<LinkChildScreen> createState() => _LinkChildScreenState();
}

class _LinkChildScreenState extends State<LinkChildScreen> {
  final _studentIdController = TextEditingController();
  final _parentRepository = ParentRepository();
  bool _isLoading = false;

  Future<void> _linkChild() async {
    final query = _studentIdController.text.trim();
    if (query.isEmpty) {
      _showSnackBar('يرجى إدخال كود الطالب أو المعرّف الخاص به', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _parentRepository.linkChildWithId(query);
      if (mounted) {
        _showSnackBar('تم ربط حساب الطالب بنجاح! تم تحديث قائمة الأبناء ✅', isError: false);
        _studentIdController.clear();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'تعذر ربط حساب الطالب. تأكد من كود الطالب أو راجع سكرتارية السنتر.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
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
        appBar: AppBar(
          title: const Text('ربط حساب طالب جديد'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.parentRole.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    size: 48,
                    color: AppColors.parentRole,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ربط ملف الطالب بحساب ولي الأمر',
                style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'أدخل كود الطالب المسلّم لك من سنتر الدروس أو المعرف الخاص به لمتابعة الحضور، الواجبات، والدرجات لحظياً.',
                style: AppTypography.bodyMedium(textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'كود الطالب بالسنتر:',
                      style: AppTypography.bodySmall(textSecondary).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _studentIdController,
                      decoration: InputDecoration(
                        hintText: 'مثال: STU-108 أو معرّف الطالب',
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.parentRole),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _linkChild(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يمكنك الحصول على كود الطالب من كارنيه السنتر أو من السكرتارية.',
                            style: AppTypography.caption(textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _linkChild,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.parentRole,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(
                    _isLoading ? 'جاري التحقق والربط...' : 'تأكيد وربط حساب الطالب 🔗',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
