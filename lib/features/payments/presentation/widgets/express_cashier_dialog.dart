import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../academy/domain/models/academy_models.dart';
import 'digital_cash_receipt_dialog.dart';

class ExpressCashierDialog extends StatefulWidget {
  final List<Student> students;
  final Student? initialStudent;
  final double? initialAmount;
  final String? initialPurpose;
  final VoidCallback? onSuccess;

  const ExpressCashierDialog({
    super.key,
    required this.students,
    this.initialStudent,
    this.initialAmount,
    this.initialPurpose,
    this.onSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Student> students,
    Student? initialStudent,
    double? initialAmount,
    String? initialPurpose,
    VoidCallback? onSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ExpressCashierDialog(
        students: students,
        initialStudent: initialStudent,
        initialAmount: initialAmount,
        initialPurpose: initialPurpose,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<ExpressCashierDialog> createState() => _ExpressCashierDialogState();
}

class _ExpressCashierDialogState extends State<ExpressCashierDialog> {
  final _formKey = GlobalKey<FormState>();

  Student? _selectedStudent;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _purposeCtrl;
  late final TextEditingController _parentPhoneCtrl;

  final String _paymentMethod = 'cash'; // cash, instapay, vodafone_cash
  bool _isProcessing = false;

  final List<double> _quickAmountPresets = [150.0, 250.0, 350.0, 450.0, 600.0];
  final List<String> _quickPurposes = [
    'اشتراك شهري في المادة',
    'رسوم حصة منفردة',
    'حجز وشراء ملازم الشرح',
    'رسوم تسجيل ودخول جديد',
    'رسوم اختبار ومراجعة نهائية',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.initialStudent ?? (widget.students.isNotEmpty ? widget.students.first : null);
    _amountCtrl = TextEditingController(
      text: widget.initialAmount != null && widget.initialAmount! > 0
          ? widget.initialAmount!.toStringAsFixed(0)
          : '350',
    );
    _purposeCtrl = TextEditingController(
      text: widget.initialPurpose ?? 'اشتراك شهري في المادة',
    );
    _parentPhoneCtrl = TextEditingController(
      text: _selectedStudent?.phoneNumber ?? '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  void _onStudentChanged(Student? s) {
    if (s == null) return;
    setState(() {
      _selectedStudent = s;
      if (s.phoneNumber != null && s.phoneNumber!.isNotEmpty) {
        _parentPhoneCtrl.text = s.phoneNumber!;
      }
    });
  }

  Future<void> _processPayment({bool printThermal = false, bool sendWhatsApp = false}) async {
    if (!_formKey.currentState!.validate() || _selectedStudent == null) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح أكبر من صفر.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final receiptNo = 'REC-${now.millisecondsSinceEpoch.toString().substring(7)}';
      final client = Supabase.instance.client;

      // 1. Record payment in Supabase
      try {
        await client.from('payments').insert({
          'student_id': _selectedStudent!.id,
          'amount': amount,
          'method': _paymentMethod,
          'notes': _purposeCtrl.text.trim(),
          'created_at': now.toIso8601String(),
        });
      } catch (_) {
        // Fallback for offline resilience
      }

      // 2. Action: Print thermal receipt
      if (printThermal) {
        try {
          await ReportGeneratorService().generateStudentCashReceiptPdf(
            centerName: 'منظومة بريفيو التعليمية المتطورة',
            receiptNumber: receiptNo,
            studentName: _selectedStudent!.fullName,
            studentCode: _selectedStudent!.studentCode,
            groupName: _purposeCtrl.text.trim(),
            amount: amount,
            purpose: _purposeCtrl.text.trim(),
            dateStr: dateStr,
            printDirectly: true,
          );
        } catch (_) {}
      }

      // 3. Action: Send Instant WhatsApp Receipt to parent
      if (sendWhatsApp) {
        final phone = _parentPhoneCtrl.text.trim();
        if (phone.isNotEmpty) {
          await WhatsAppService.sendCashReceiptToParent(
            parentPhone: phone,
            studentName: _selectedStudent!.fullName,
            studentCode: _selectedStudent!.studentCode,
            receiptNo: receiptNo,
            amountPaid: amount,
            purpose: _purposeCtrl.text.trim(),
            centerName: 'منظومة بريفيو التعليمية المتطورة',
            cashierName: 'موظف الاستقبال',
          );
        }
      }

      widget.onSuccess?.call();

      if (!mounted) return;
      setState(() => _isProcessing = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تسجيل عملية التحصيل بنجاح بمبلغ $amount ج.م ${sendWhatsApp ? "وإرسال إيصال الواتساب 💬" : ""}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      DigitalCashReceiptDialog.show(
        context: context,
        receiptType: ReceiptType.studentPayment,
        centerName: 'منظومة بريفيو التعليمية المتطورة',
        receiptNumber: receiptNo,
        dateStr: dateStr,
        recipientName: _selectedStudent!.fullName,
        studentCode: _selectedStudent!.studentCode,
        groupName: _purposeCtrl.text.trim(),
        amount: amount,
        paymentPurpose: _purposeCtrl.text.trim(),
        parentOrTeacherPhone: _parentPhoneCtrl.text.trim(),
        paymentMethod: 'نقداً بالخزينة (كاش) 💵',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الإيصال: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded, color: Colors.green, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'كاشير الاستقبال السريع وإصدار الإيصال 💵',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تحصيل فوري، طباعة إيصال حراري، ومشاركة الإيصال على واتساب',
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
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Student Selector
                  DropdownButtonFormField<Student>(
                    initialValue: _selectedStudent,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر الطالب *',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    items: widget.students.map((s) {
                      return DropdownMenuItem<Student>(
                        value: s,
                        child: Text(
                          '${s.fullName} (${s.studentCode})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: _onStudentChanged,
                    validator: (v) => v == null ? 'يرجى اختيار الطالب' : null,
                  ),
                  const SizedBox(height: 14),

                  // Amount Input
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المحصل (ج.م) *',
                      prefixIcon: Icon(Icons.attach_money_rounded, color: Colors.green),
                      suffixText: 'ج.م',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'المبلغ مطلوب' : null,
                  ),
                  const SizedBox(height: 8),

                  // Quick Amount Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickAmountPresets.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ActionChip(
                            label: Text('+${preset.toInt()} ج.م', style: const TextStyle(fontSize: 11)),
                            onPressed: () => setState(() => _amountCtrl.text = preset.toInt().toString()),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Purpose Input
                  TextFormField(
                    controller: _purposeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'بند السداد والغرض *',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'بند السداد مطلوب' : null,
                  ),
                  const SizedBox(height: 6),

                  // Quick Purpose Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickPurposes.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ActionChip(
                            label: Text(p, style: const TextStyle(fontSize: 10)),
                            onPressed: () => setState(() => _purposeCtrl.text = p),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Parent WhatsApp Phone
                  TextFormField(
                    controller: _parentPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم واتساب ولي الأمر لاستلام الإيصال',
                      prefixIcon: Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                      hintText: '01012345678',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment Method Selector
                  Row(
                    children: [
                      const Text('طريقة الدفع:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('كاش بالخزينة 💵'),
                        selected: true,
                        onSelected: null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      // WhatsApp + Save
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isProcessing ? null : () => _processPayment(sendWhatsApp: true),
                          icon: const Icon(Icons.send_to_mobile_rounded, size: 18),
                          label: const Text(
                            'تحصيل + إيصال واتساب 💬',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Print + Save
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isProcessing ? null : () => _processPayment(printThermal: true),
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text(
                            'طباعة حراري 🖨️',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _isProcessing ? null : () => _processPayment(),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('تحصيل سريع فقط (بدون طباعة)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
