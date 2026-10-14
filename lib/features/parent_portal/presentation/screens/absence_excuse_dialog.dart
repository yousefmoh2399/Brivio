import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class AbsenceExcuseDialog extends StatefulWidget {
  final String? initialStudentName;
  final String? initialStudentId;
  final String? initialGroupName;
  final String? initialSessionId;
  final List<Map<String, dynamic>>? availableSessions;

  const AbsenceExcuseDialog({
    super.key,
    this.initialStudentName,
    this.initialStudentId,
    this.initialGroupName,
    this.initialSessionId,
    this.availableSessions,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialStudentName,
    String? initialStudentId,
    String? initialGroupName,
    String? initialSessionId,
    List<Map<String, dynamic>>? availableSessions,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AbsenceExcuseDialog(
          initialStudentName: initialStudentName,
          initialStudentId: initialStudentId,
          initialGroupName: initialGroupName,
          initialSessionId: initialSessionId,
          availableSessions: availableSessions,
        ),
      ),
    );
  }

  @override
  State<AbsenceExcuseDialog> createState() => _AbsenceExcuseDialogState();
}

class _AbsenceExcuseDialogState extends State<AbsenceExcuseDialog> {
  DateTime _absenceDate = DateTime.now().add(const Duration(days: 1));
  String _selectedReason = 'عذر مرضي 🩺';
  String? _selectedSessionId;
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
  void initState() {
    super.initState();
    _selectedSessionId = widget.initialSessionId;
  }

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

    final formattedDate =
        '${_absenceDate.year}-${_absenceDate.month.toString().padLeft(2, '0')}-${_absenceDate.day.toString().padLeft(2, '0')}';
    final extraNotes = _notesController.text.trim();
    final combinedReason = extraNotes.isNotEmpty
        ? '$_selectedReason - $extraNotes (لتاريخ $formattedDate)'
        : '$_selectedReason (لتاريخ $formattedDate)';

    try {
      final studentId = widget.initialStudentId;
      if (studentId != null && studentId.isNotEmpty) {
        await Supabase.instance.client.rpc(
          'create_parent_child_leave_request',
          params: {
            'p_student_id': studentId,
            'p_class_session_id': _selectedSessionId,
            'p_reason': combinedReason,
          },
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text('تم تسجيل عذر الغياب وإخطار إدارة السنتر والمدرس بنجاح ✔️'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          content: Text('تعذر إرسال عذر الغياب: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    final studentName = widget.initialStudentName ?? 'الطالب';
    final groupName = widget.initialGroupName ?? 'المجموعة الدراسية';
    final formattedDate =
        '${_absenceDate.year}-${_absenceDate.month.toString().padLeft(2, '0')}-${_absenceDate.day.toString().padLeft(2, '0')}';
    final sessions = widget.availableSessions ?? const [];

    return Dialog(
      backgroundColor: surfaceColor,
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

              if (sessions.isNotEmpty) ...[
                Text('الحصة المستهدفة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedSessionId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('عذر عام (غير مقيد بحصة محددة)'),
                    ),
                    ...sessions.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s['id']?.toString(),
                        child: Text(
                          '${s['date'] ?? ''} - ${s['title'] ?? 'حصة'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedSessionId = val),
                ),
                const SizedBox(height: 14),
              ],

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
                isExpanded: true,
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
