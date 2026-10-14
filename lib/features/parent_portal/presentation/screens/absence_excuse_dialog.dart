import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class AbsenceExcuseDialog extends StatefulWidget {
  final String? initialStudentName;
  final String? initialStudentId;
  final String? initialGroupName;

  const AbsenceExcuseDialog({
    super.key,
    this.initialStudentName,
    this.initialStudentId,
    this.initialGroupName,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialStudentName,
    String? initialStudentId,
    String? initialGroupName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AbsenceExcuseDialog(
        initialStudentName: initialStudentName,
        initialStudentId: initialStudentId,
        initialGroupName: initialGroupName,
      ),
    );
  }

  @override
  State<AbsenceExcuseDialog> createState() => _AbsenceExcuseDialogState();
}

class _AbsenceExcuseDialogState extends State<AbsenceExcuseDialog> {
  DateTime _absenceDate = DateTime.now().add(const Duration(days: 1));
  String _selectedReason = 'عذر مرضي 🩺';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'عذر مرضي 🩺',
    'امتحانات الشهر المدرسية 📝',
    'سفر وظرف قاهر ✈️',
    'ظرف عائلي خاص 🏠',
    'سبب آخر',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _absenceDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _absenceDate = picked);
    }
  }

  Future<void> _submitExcuse() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('تم تسجيل عذر الغياب وإخطار سكرتارية السنتر والمدرس بنجاح ✔️'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final studentName = widget.initialStudentName ?? 'عمر أحمد محمود';
    final groupName = widget.initialGroupName ?? 'ثانوية عامة - لغات A';
    final formattedDate = '${_absenceDate.year}-${_absenceDate.month.toString().padLeft(2, '0')}-${_absenceDate.day.toString().padLeft(2, '0')}';

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_busy_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'إخطار بعذر غياب مسبق 🗓️',
                        style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Student & Group info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الطالب: $studentName', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 2),
                    Text('المجموعة: $groupName', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Date Picker Field
              Text('تاريخ الحصة المتوقع التغيب عنها:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formattedDate, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Reason Dropdown
              Text('سبب الغياب:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              const SizedBox(height: 14),

              // Notes
              Text('ملاحظات إضافية أو تفاصيل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'اكتب توضيح إضافي إن وجد...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
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
                      onPressed: _isSubmitting ? null : _submitExcuse,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded),
                      label: const Text('تأكيد وإرسال العذر'),
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
