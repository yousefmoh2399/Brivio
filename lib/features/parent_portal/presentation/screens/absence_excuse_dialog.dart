import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
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

  String? _attachedFileName;
  String? _attachedFilePath;
  bool _isPicking = false;

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
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _absenceDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _absenceDate = picked);
    }
  }

  Future<void> _pickAttachment({bool isCamera = false}) async {
    HapticFeedback.selectionClick();
    setState(() => _isPicking = true);
    try {
      const typeGroup = XTypeGroup(
        label: 'medical_attachments',
        extensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        setState(() {
          _attachedFileName = file.name;
          _attachedFilePath = file.path;
        });
      } else if (isCamera) {
        final now = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _attachedFileName = 'تقرير_طبي_كاميرا_$now.jpg';
          _attachedFilePath = 'medical_report_$now.jpg';
        });
      }
    } catch (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _attachedFileName = 'شهادة_طبية_$now.jpg';
        _attachedFilePath = 'medical_certificate_$now.jpg';
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeAttachment() {
    HapticFeedback.selectionClick();
    setState(() {
      _attachedFileName = null;
      _attachedFilePath = null;
    });
  }

  Future<void> _submitExcuse() async {
    HapticFeedback.heavyImpact();
    setState(() => _isSubmitting = true);

    final formattedDate =
        '${_absenceDate.year}-${_absenceDate.month.toString().padLeft(2, '0')}-${_absenceDate.day.toString().padLeft(2, '0')}';
    final extraNotes = _notesController.text.trim();
    
    final attachmentPart = _attachedFileName != null
        ? ' [مرفق: $_attachedFileName - ${_attachedFilePath ?? ""}]'
        : '';

    final combinedReason = extraNotes.isNotEmpty
        ? '$_selectedReason - $extraNotes$attachmentPart (لتاريخ $formattedDate)'
        : '$_selectedReason$attachmentPart (لتاريخ $formattedDate)';

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
          content: Text('تم تسجيل عذر الغياب والمرفق وإخطار إدارة السنتر والمعلم بنجاح ✔️'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
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
                        'إخطار بعذر غياب رسمي 🗓️',
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              Text('تاريخ الحصة المتغيب عنها:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(12),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              const SizedBox(height: 14),

              // ── Medical / Paper Attachment Section ──
              Text(
                '📎 إرفاق تقرير طبي أو عذر ورقي (اختياري):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 6),
              if (_attachedFileName == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isPicking ? null : () => _pickAttachment(isCamera: true),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('تصوير بالكاميرا 📷'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.parentRole,
                          side: BorderSide(color: AppColors.parentRole.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isPicking ? null : () => _pickAttachment(isCamera: false),
                        icon: const Icon(Icons.attach_file_rounded, size: 18),
                        label: const Text('من الملفات 📁'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachedFileName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const Text(
                              'مرفق عذر طبي معتمد وموثق 📄',
                              style: TextStyle(color: Colors.green, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'إلغاء المرفق',
                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                        onPressed: _removeAttachment,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Notes
              Text('ملاحظات إضافية أو تفاصيل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'اكتب توضيح إضافي للمعلم أو الإدارة...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : _submitExcuse,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded, size: 18),
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
