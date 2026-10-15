import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../../payments/presentation/widgets/digital_cash_receipt_dialog.dart';

class ExpressStudentRegistrationDialog extends StatefulWidget {
  final List<GroupEntity> availableGroups;
  final String? defaultBranchId;
  final ValueChanged<Student>? onRegistered;

  const ExpressStudentRegistrationDialog({
    super.key,
    required this.availableGroups,
    this.defaultBranchId,
    this.onRegistered,
  });

  static Future<void> show({
    required BuildContext context,
    required List<GroupEntity> availableGroups,
    String? defaultBranchId,
    ValueChanged<Student>? onRegistered,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ExpressStudentRegistrationDialog(
        availableGroups: availableGroups,
        defaultBranchId: defaultBranchId,
        onRegistered: onRegistered,
      ),
    );
  }

  @override
  State<ExpressStudentRegistrationDialog> createState() =>
      _ExpressStudentRegistrationDialogState();
}

class _ExpressStudentRegistrationDialogState
    extends State<ExpressStudentRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _codeController = TextEditingController();

  String _selectedGrade = 'الصف الثالث الثانوي';
  final Set<String> _selectedGroupIds = {};

  bool _isSubmitting = false;
  Student? _newlyCreatedStudent;
  List<String> _enrolledGroupNames = [];

  final List<String> _gradeOptions = [
    'الصف الأول الإعدادي',
    'الصف الثاني الإعدادي',
    'الصف الثالث الإعدادي',
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
    'مرحلة جامعية',
  ];

  @override
  void initState() {
    super.initState();
    _codeController.text = 'STU-${1000 + Random().nextInt(9000)}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentPhoneController.dispose();
    _parentPhoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;
      final studentCode = _codeController.text.trim();
      final fullName = _nameController.text.trim();
      final studentPhone = _studentPhoneController.text.trim();
      final parentPhone = _parentPhoneController.text.trim();

      // 1. Insert profile & student record into Supabase
      String studentId;
      try {
        final profileRes = await client.from('profiles').insert({
          'full_name': fullName,
          'phone_number': studentPhone.isNotEmpty ? studentPhone : parentPhone,
          'role': 'student',
        }).select().single();

        final profileId = profileRes['id'].toString();

        final studentRes = await client.from('students').insert({
          'profile_id': profileId,
          'student_code': studentCode,
          'grade_level': _selectedGrade,
          'emergency_contact_phone': parentPhone,
          'status': 'active',
          if (widget.defaultBranchId != null)
            'primary_branch_id': widget.defaultBranchId,
        }).select().single();

        studentId = studentRes['id'].toString();
      } catch (_) {
        // Direct insertion fallback if profiles trigger is automatic
        final studentRes = await client.from('students').insert({
          'student_code': studentCode,
          'grade_level': _selectedGrade,
          'emergency_contact_phone': parentPhone,
          'status': 'active',
          if (widget.defaultBranchId != null)
            'primary_branch_id': widget.defaultBranchId,
        }).select().single();
        studentId = studentRes['id'].toString();
      }

      // 2. Enroll student into selected groups
      final selectedNames = <String>[];
      for (final groupId in _selectedGroupIds) {
        final group = widget.availableGroups.firstWhere(
          (g) => g.id == groupId,
          orElse: () => GroupEntity(
            id: groupId,
            name: 'مجموعة دراسية',
            code: '',
            subjectId: '',
            branchId: '',
            status: '',
          ),
        );
        selectedNames.add(group.name);

        try {
          await client.from('enrollments').insert({
            'group_id': groupId,
            'student_id': studentId,
            'status': 'active',
          });
        } catch (_) {}
      }

      final createdStudent = Student(
        id: studentId,
        profileId: '',
        studentCode: studentCode,
        primaryBranchId: widget.defaultBranchId ?? '',
        gradeLevel: _selectedGrade,
        status: 'active',
        fullName: fullName,
        email: '$studentCode@brivio.local',
        phoneNumber: studentPhone,
      );

      widget.onRegistered?.call(createdStudent);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _newlyCreatedStudent = createdStudent;
        _enrolledGroupNames = selectedNames;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التسجيل: $e')),
      );
    }
  }

  void _printIdCard() {
    if (_newlyCreatedStudent == null) return;
    ReportGeneratorService().generateBulkStudentIdCardsPdf(
      students: [
        {
          'id': _newlyCreatedStudent!.id,
          'full_name': _newlyCreatedStudent!.fullName,
          'student_code': _newlyCreatedStudent!.studentCode,
          'grade_level': _newlyCreatedStudent!.gradeLevel ?? _selectedGrade,
          'emergency_contact_phone': _parentPhoneController.text.trim(),
        },
      ],
      centerName: 'منظومة بريفيو التعليمية المتطورة',
      groupName: _enrolledGroupNames.isNotEmpty ? _enrolledGroupNames.first : 'السنتر التعليمي',
      printDirectly: true,
    );
  }

  Future<void> _sendWelcomeWhatsApp() async {
    if (_newlyCreatedStudent == null) return;
    final parentPhone = _parentPhoneController.text.trim();
    if (parentPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التأكد من كتابة رقم هاتف ولي الأمر أولاً.')),
      );
      return;
    }

    final sent = await WhatsAppService.sendStudentWelcomeRegistrationCard(
      parentPhone: parentPhone,
      studentName: _newlyCreatedStudent!.fullName,
      studentCode: _newlyCreatedStudent!.studentCode,
      centerName: 'منظومة بريفيو التعليمية المتطورة',
      gradeLevel: _selectedGrade,
      enrolledGroups: _enrolledGroupNames,
    );

    if (mounted && sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم فتح محادثة الواتساب وتجهيز كارت الترحيب بنجاح! 💬'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _openQuickPayment() {
    if (_newlyCreatedStudent == null) return;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final receiptNumber = 'REC-${now.millisecondsSinceEpoch.toString().substring(7)}';

    DigitalCashReceiptDialog.show(
      context: context,
      receiptType: ReceiptType.studentPayment,
      centerName: 'سنتر الأوائل التعليمي',
      receiptNumber: receiptNumber,
      dateStr: dateStr,
      recipientName: _newlyCreatedStudent!.fullName,
      studentCode: _newlyCreatedStudent!.studentCode,
      groupName: _enrolledGroupNames.isNotEmpty ? _enrolledGroupNames.first : 'اشتراك عام',
      amount: 400.0,
      paymentPurpose: 'رسوم التسجيل واشتراك الحصص الأولية',
      parentOrTeacherPhone: _parentPhoneController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _newlyCreatedStudent == null
              ? _buildFormView(isDark)
              : _buildSuccessView(isDark),
        ),
      ),
    );
  }

  Widget _buildFormView(bool isDark) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Color(0xFFF59E0B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'تسجيل طالب سريع (30 ثانية)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(width: 6),
                          Text('⚡', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'إدخال فوري للبيانات الأساسية وتوليد الباركود وكارت الواتساب في الحال',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Student Full Name
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم الطالب رباعي *',
                prefixIcon: Icon(Icons.badge_rounded),
                hintText: 'مثال: يوسف خالد إبراهيم مصطفى',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم الطالب' : null,
            ),
            const SizedBox(height: 12),

            // Phones Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _parentPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'هاتف ولي الأمر (واتساب) *',
                      prefixIcon: Icon(Icons.phone_android_rounded, color: Colors.green),
                      hintText: '01012345678',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب للمتابعة والواتساب' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _studentPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'هاتف الطالب (اختياري)',
                      prefixIcon: Icon(Icons.smartphone_rounded),
                      hintText: '01xxxxxxxxx',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grade Level & Auto Code Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'المرحلة الدراسية',
                      prefixIcon: Icon(Icons.school_rounded),
                    ),
                    items: _gradeOptions
                        .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedGrade = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'كود الطالب',
                      prefixIcon: Icon(Icons.qr_code_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Select Group(s)
            if (widget.availableGroups.isNotEmpty) ...[
              const Text(
                'اختر المجموعة الدراسية للاشتراك الفوري:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableGroups.take(6).map((group) {
                  final isSelected = _selectedGroupIds.contains(group.id);
                  return FilterChip(
                    label: Text(group.name, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : null)),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedGroupIds.add(group.id);
                        } else {
                          _selectedGroupIds.remove(group.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submitRegistration,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isSubmitting ? 'جارٍ تسجيل الطالب...' : 'تأكيد التسجيل وإصدار الكارنيه الفوري ⚡',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 44),
        ),
        const SizedBox(height: 12),
        const Text(
          'تم تسجيل الطالب بنجاح في 30 ثانية! 🎉',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green),
        ),
        const SizedBox(height: 4),
        Text(
          'تم تثبيت قيد الطالب وإصدار الباركود المعتمد في منظومة السنتر.',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Quick Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('اسم الطالب:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    _newlyCreatedStudent!.fullName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('كود الدخول والباركود:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _newlyCreatedStudent!.studentCode,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المرحلة والمجموعة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    '$_selectedGrade • ${_enrolledGroupNames.isNotEmpty ? _enrolledGroupNames.first : "عام"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3 High-Velocity Action Buttons
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _printIdCard,
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('طباعة الكارنيه الرقمي بالباركود فوراً 🪪', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _sendWelcomeWhatsApp,
            icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
            label: const Text('إرسال كارت الترحيب لولي الأمر على واتساب 💬', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _openQuickPayment,
            icon: const Icon(Icons.point_of_sale_rounded, color: Colors.green, size: 18),
            label: const Text('تحصيل أول اشتراك نقداً (إصدار إيصال) 💵', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 14),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إنهاء وإغلاق'),
        ),
      ],
    );
  }
}
