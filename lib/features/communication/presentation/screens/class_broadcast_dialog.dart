import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class ClassBroadcastDialog extends StatefulWidget {
  final String groupName;
  final String? teacherName;

  const ClassBroadcastDialog({
    super.key,
    required this.groupName,
    this.teacherName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String groupName,
    String? teacherName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ClassBroadcastDialog(
        groupName: groupName,
        teacherName: teacherName,
      ),
    );
  }

  @override
  State<ClassBroadcastDialog> createState() => _ClassBroadcastDialogState();
}

class _ClassBroadcastDialogState extends State<ClassBroadcastDialog> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isUrgent = false;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _dispatchBroadcast() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء كتابة عنوان ونص التنبيه')),
      );
      return;
    }

    setState(() => _isSending = true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isSending = false);

    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('تم إرسال الإشعار والتنبيه لجميع طلاب المجموعة بنجاح 📢'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'إذاعة تنبيه جماعي للمجموعة 📢',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Group indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المجموعة المستهدفة: ${widget.groupName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان التنبيه (مثلاً: تأجيل موعد حصة المراجعة)',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'نص التنبيه والتفاصيل الموجهة للطلاب...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),

              // Urgency toggle
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('تنبيه عاجل وهام ⚠️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('يظهر كإشعار ذو أولوية حمراء لجميع الطلاب', style: TextStyle(fontSize: 11)),
                value: _isUrgent,
                activeThumbColor: Colors.red,
                onChanged: (val) => setState(() => _isUrgent = val),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _isUrgent ? Colors.red.shade700 : AppColors.primary,
                      ),
                      onPressed: _isSending ? null : _dispatchBroadcast,
                      icon: _isSending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label: const Text('إذاعة التنبيه الآن'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
