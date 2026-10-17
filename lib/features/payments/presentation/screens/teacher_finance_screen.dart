import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../core/utils/arabic_pdf_helper.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/widgets/portal_components.dart';

class TeacherFinanceScreen extends StatefulWidget {
  final String teacherId;

  const TeacherFinanceScreen({super.key, required this.teacherId});

  @override
  State<TeacherFinanceScreen> createState() => _TeacherFinanceScreenState();
}

class _TeacherFinanceScreenState extends State<TeacherFinanceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_TeacherFinanceGroup> _groups = [];

  int get _totalRequired =>
      _groups.fold(0, (sum, group) => sum + group.totalAmountMinor);
  int get _totalPaid =>
      _groups.fold(0, (sum, group) => sum + group.paidAmountMinor);
  int get _totalRemaining =>
      _groups.fold(0, (sum, group) => sum + group.remainingAmountMinor);
  int get _unpaidStudents =>
      _groups.fold(0, (sum, group) => sum + group.unpaidStudents);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'get_teacher_financial_overview',
        params: {'p_teacher_id': widget.teacherId},
      );
      final rows = response is List ? response : <dynamic>[];
      if (!mounted) return;
      setState(() {
        _groups = rows
            .whereType<Map>()
            .map((row) => _TeacherFinanceGroup.fromJson(row))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openGroupRoster(_TeacherFinanceGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _TeacherFinanceRosterSheet(group: group, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _groups.isEmpty,
        emptyTitle: 'لا توجد بيانات مالية حتى الآن',
        emptySubtitle:
            'ستظهر الإجماليات والمستحقات المالية فور تسجيل الطلاب في مجموعاتك الدراسية.',
        emptyIcon: Icons.payments_outlined,
        onRetry: _load,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PortalMetricGrid(
                children: [
                  PortalMetricCard(
                    label: 'إجمالي المستحق',
                    value: _money(_totalRequired),
                    icon: Icons.request_quote,
                    accentColor: AppColors.teacherRole,
                  ),
                  PortalMetricCard(
                    label: 'المحصل الفعلي',
                    value: _money(_totalPaid),
                    icon: Icons.price_check,
                    accentColor: Colors.green,
                  ),
                  PortalMetricCard(
                    label: 'المتبقي والآجل',
                    value: _money(_totalRemaining),
                    icon: Icons.pending_actions,
                    accentColor: Colors.orange,
                  ),
                  PortalMetricCard(
                    label: 'الطلاب غير المسددين',
                    value: '$_unpaidStudents',
                    icon: Icons.person_off,
                    accentColor: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const PortalSectionTitle(
                title: 'المجموعات الدراسية',
                subtitle:
                    'اضغط على أي مجموعة للاطلاع على كشف حساب الطلاب وتسجيل طلبات الخصم أو الإعفاء.',
              ),
              const SizedBox(height: 10),
              ..._groups.asMap().entries.map((entry) {
                final index = entry.key;
                final group = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeInSlide(
                    delay: Duration(milliseconds: 30 * index),
                    child: GlassCard(
                      onTap: () => _openGroupRoster(group),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleIcon(
                            icon: Icons.group,
                            color: AppColors.teacherRole,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.groupName,
                                  style: AppTypography.titleMedium(
                                    AppColors.darkTextPrimary,
                                  ),
                                ),
                                Text(
                                  '${group.subjectName} • ${group.paidStudents}/${group.totalStudents} مسدد • المتبقي: ${_money(group.remainingAmountMinor, group.currency)}',
                                  style: AppTypography.bodySmall(
                                    AppColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusChip(
                            label: group.unpaidStudents == 0
                                ? 'مسدد بالكامل'
                                : '${group.unpaidStudents} غير مسدد',
                            status: group.unpaidStudents == 0
                                ? ChipStatus.success
                                : ChipStatus.warning,
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.darkTextSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherFinanceRosterSheet extends StatefulWidget {
  final _TeacherFinanceGroup group;
  final VoidCallback onChanged;

  const _TeacherFinanceRosterSheet({
    required this.group,
    required this.onChanged,
  });

  @override
  State<_TeacherFinanceRosterSheet> createState() =>
      _TeacherFinanceRosterSheetState();
}

class _TeacherFinanceRosterSheetState
    extends State<_TeacherFinanceRosterSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_TeacherFinanceStudent> _students = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'get_teacher_group_finance_roster',
        params: {'p_group_id': widget.group.groupId},
      );
      final rows = response is List ? response : <dynamic>[];
      if (!mounted) return;
      setState(() {
        _students = rows
            .whereType<Map>()
            .map((row) => _TeacherFinanceStudent.fromJson(row))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _requestAdjustment(_TeacherFinanceStudent student) async {
    final result = await showDialog<_AdjustmentDraft>(
      context: context,
      builder: (_) => _AdjustmentDialog(student: student),
    );
    if (result == null || !mounted) return;

    try {
      await Supabase.instance.client.rpc(
        'request_teacher_payment_adjustment',
        params: {
          'p_enrollment_id': student.enrollmentId,
          'p_discount_minor': result.discountMinor,
          'p_reason': result.reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب التعديل بنجاح')),
      );
      await _load();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openReceipts(_TeacherFinanceStudent student) async {
    List<_TeacherReceipt> receipts;
    try {
      final response = await Supabase.instance.client.rpc(
        'get_teacher_student_receipts',
        params: {
          'p_student_id': student.studentId,
          'p_group_id': widget.group.groupId,
        },
      );
      receipts = (response is List ? response : <dynamic>[])
          .whereType<Map>()
          .map((row) => _TeacherReceipt.fromJson(row))
          .toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReceiptSheet(
        student: student,
        receipts: receipts,
        onPrint: _printReceipt,
      ),
    );
  }

  Future<void> _printReceipt(_TeacherReceipt receipt) async {
    final pdf = await ReportGeneratorService.createDocument();
    final amount = _money(receipt.amountMinor, receipt.currency);
    final issuedAt = _formatDateTime(receipt.issuedAt);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity)
            .copyWith(
              marginLeft: 5 * PdfPageFormat.mm,
              marginRight: 5 * PdfPageFormat.mm,
              marginTop: 6 * PdfPageFormat.mm,
              marginBottom: 6 * PdfPageFormat.mm,
            ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'إيصال استلام نقدية'.fixArabic,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('نظام إدارة المركز التعليمي'.fixArabic)),
            pw.Divider(thickness: 1),
            _receiptLine('رقم الإيصال', receipt.receiptNumber),
            _receiptLine('التاريخ', issuedAt),
            _receiptLine('اسم الطالب', receipt.studentName),
            _receiptLine('كود الطالب', receipt.studentCode),
            _receiptLine('المجموعة', receipt.groupName),
            _receiptLine('المادة', receipt.subjectName),
            _receiptLine('رقم الفاتورة', receipt.invoiceNumber),
            _receiptLine('طريقة الدفع', receipt.paymentMethod),
            _receiptLine('مزود الخدمة', receipt.provider),
            _receiptLine('الرقم المرجعي', receipt.providerTransactionId),
            pw.Divider(thickness: 1),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'الإجمالي'.fixArabic,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  amount.fixArabic,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('شكراً لكم'.fixArabic)),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      name: 'receipt_${receipt.receiptNumber}.pdf',
      onLayout: (_) => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .82,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.groupName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: PortalStateView(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  isEmpty: _students.isEmpty,
                  emptyTitle: 'لا يوجد طلاب مسجلون',
                  emptySubtitle:
                      'يظهر الطلاب هنا بعد تسجيلهم وانضمامهم لهذه المجموعة.',
                  emptyIcon: Icons.group_off,
                  onRetry: _load,
                  child: ListView.separated(
                    itemCount: _students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final canRequest =
                          student.remainingAmountMinor > 0 &&
                          student.pendingAdjustmentCount == 0;
                      return PortalListCard(
                        icon: student.isPaid
                            ? Icons.verified
                            : Icons.pending_actions,
                        accentColor: student.isPaid
                            ? Colors.green
                            : Colors.orange,
                        title: student.studentName,
                        subtitle:
                            '${student.studentCode.isNotEmpty ? '${student.studentCode} • ' : ''}الإجمالي: ${_money(student.finalPriceMinor, student.currency)} • المسدد: ${_money(student.paidAmountMinor, student.currency)} • المتبقي: ${_money(student.remainingAmountMinor, student.currency)}',
                        trailing: [
                          PortalStatusChip(
                            status: student.paymentExempt
                                ? 'exempt'
                                : student.paymentStatus,
                          ),
                          if (student.pendingAdjustmentCount > 0)
                            const PortalStatusChip(
                              status: 'طلب قيد المراجعة',
                            ),
                          IconButton.filledTonal(
                            tooltip: 'الإيصالات',
                            onPressed: () => _openReceipts(student),
                            icon: const Icon(Icons.receipt_long),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'طلب خصم أو إعفاء',
                            onPressed: canRequest
                                ? () => _requestAdjustment(student)
                                : null,
                            icon: const Icon(Icons.percent),
                          ),
                        ],
                      );
                    },
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

class _AdjustmentDialog extends StatefulWidget {
  final _TeacherFinanceStudent student;

  const _AdjustmentDialog({required this.student});

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _discountController;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: (widget.student.remainingAmountMinor / 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = double.tryParse(_discountController.text.trim()) ?? 0;
    Navigator.pop(
      context,
      _AdjustmentDraft(
        discountMinor: (value * 100).round(),
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'طلب تعديل رسوم: ${widget.student.studentName}',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    'قيمة الخصم (${widget.student.currency == 'EGP' ? 'ج.م' : widget.student.currency})',
                prefixIcon: const Icon(Icons.percent),
                helperText:
                    'استخدم ${_money(widget.student.finalPriceMinor, widget.student.currency)} للإعفاء الكامل.',
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || amount < 0) {
                  return 'يرجى إدخال مبلغ صحيح';
                }
                if ((amount * 100).round() > widget.student.finalPriceMinor) {
                  return 'قيمة الخصم لا يمكن أن تتجاوز السعر الإجمالي';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'السبب أو ملاحظات الطلب',
                prefixIcon: Icon(Icons.notes),
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
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send),
          label: const Text('إرسال الطلب'),
        ),
      ],
    );
  }
}

class _AdjustmentDraft {
  final int discountMinor;
  final String reason;

  const _AdjustmentDraft({required this.discountMinor, required this.reason});
}

class _ReceiptSheet extends StatelessWidget {
  final _TeacherFinanceStudent student;
  final List<_TeacherReceipt> receipts;
  final Future<void> Function(_TeacherReceipt receipt) onPrint;

  const _ReceiptSheet({
    required this.student,
    required this.receipts,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .72,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'إيصالات السداد - ${student.studentName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: receipts.isEmpty
                    ? const Center(child: Text('لا توجد إيصالات سداد لهذا الطالب.'))
                    : ListView.separated(
                        itemCount: receipts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final receipt = receipts[index];
                          return PortalListCard(
                            icon: Icons.receipt,
                            accentColor: AppColors.success,
                            title: receipt.receiptNumber,
                            subtitle:
                                '${_formatDateTime(receipt.issuedAt)} - ${receipt.invoiceNumber} - ${receipt.providerTransactionId}',
                            trailing: [
                              Text(
                                _money(receipt.amountMinor, receipt.currency),
                                style: AppTypography.titleSmall(
                                  AppColors.darkTextPrimary,
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'طباعة الإيصال',
                                onPressed: () => onPrint(receipt),
                                icon: const Icon(Icons.print),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherFinanceGroup {
  final String groupId;
  final String groupName;
  final String groupCode;
  final String subjectName;
  final int totalStudents;
  final int paidStudents;
  final int unpaidStudents;
  final int totalAmountMinor;
  final int paidAmountMinor;
  final int remainingAmountMinor;
  final String currency;

  const _TeacherFinanceGroup({
    required this.groupId,
    required this.groupName,
    required this.groupCode,
    required this.subjectName,
    required this.totalStudents,
    required this.paidStudents,
    required this.unpaidStudents,
    required this.totalAmountMinor,
    required this.paidAmountMinor,
    required this.remainingAmountMinor,
    required this.currency,
  });

  factory _TeacherFinanceGroup.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _TeacherFinanceGroup(
      groupId: json['group_id']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? 'مجموعة',
      groupCode: json['group_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? 'المادة',
      totalStudents: _asInt(json['total_students']),
      paidStudents: _asInt(json['paid_students']),
      unpaidStudents: _asInt(json['unpaid_students']),
      totalAmountMinor: _asInt(json['total_amount_minor']),
      paidAmountMinor: _asInt(json['paid_amount_minor']),
      remainingAmountMinor: _asInt(json['remaining_amount_minor']),
      currency: json['currency']?.toString() ?? 'ج.م',
    );
  }
}

class _TeacherFinanceStudent {
  final String enrollmentId;
  final String studentId;
  final String studentName;
  final String studentCode;
  final int finalPriceMinor;
  final int paidAmountMinor;
  final int remainingAmountMinor;
  final String currency;
  final String paymentStatus;
  final bool paymentExempt;
  final int pendingAdjustmentCount;

  const _TeacherFinanceStudent({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.finalPriceMinor,
    required this.paidAmountMinor,
    required this.remainingAmountMinor,
    required this.currency,
    required this.paymentStatus,
    required this.paymentExempt,
    required this.pendingAdjustmentCount,
  });

  bool get isPaid =>
      remainingAmountMinor <= 0 ||
      paymentStatus == 'paid' ||
      paymentStatus == 'exempt' ||
      paymentExempt;

  factory _TeacherFinanceStudent.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _TeacherFinanceStudent(
      enrollmentId: json['enrollment_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'طالب',
      studentCode: json['student_code']?.toString() ?? '',
      finalPriceMinor: _asInt(json['final_price_minor']),
      paidAmountMinor: _asInt(json['paid_amount_minor']),
      remainingAmountMinor: _asInt(json['remaining_amount_minor']),
      currency: json['currency']?.toString() ?? 'ج.م',
      paymentStatus: json['payment_status']?.toString() ?? 'paid',
      paymentExempt: json['payment_exempt'] == true,
      pendingAdjustmentCount: _asInt(json['pending_adjustment_count']),
    );
  }
}

class _TeacherReceipt {
  final String receiptId;
  final String receiptNumber;
  final String invoiceNumber;
  final String transactionId;
  final String provider;
  final String providerTransactionId;
  final String paymentMethod;
  final int amountMinor;
  final String currency;
  final DateTime issuedAt;
  final String studentName;
  final String studentCode;
  final String groupName;
  final String groupCode;
  final String subjectName;

  const _TeacherReceipt({
    required this.receiptId,
    required this.receiptNumber,
    required this.invoiceNumber,
    required this.transactionId,
    required this.provider,
    required this.providerTransactionId,
    required this.paymentMethod,
    required this.amountMinor,
    required this.currency,
    required this.issuedAt,
    required this.studentName,
    required this.studentCode,
    required this.groupName,
    required this.groupCode,
    required this.subjectName,
  });

  factory _TeacherReceipt.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _TeacherReceipt(
      receiptId: json['receipt_id']?.toString() ?? '',
      receiptNumber: json['receipt_number']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'cash',
      providerTransactionId: json['provider_transaction_id']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      amountMinor: _asInt(json['amount_minor']),
      currency: json['currency']?.toString() ?? 'ج.م',
      issuedAt:
          DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
          DateTime.now(),
      studentName: json['student_name']?.toString() ?? 'طالب',
      studentCode: json['student_code']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? '',
      groupCode: json['group_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _money(int minor, [String currency = 'ج.م']) {
  final curr = (currency == 'EGP' || currency.isEmpty) ? 'ج.م' : currency;
  final amount = minor / 100;
  final formatted = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$formatted $curr';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

pw.Widget _receiptLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label.fixArabic),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            (value.isEmpty ? '-' : value).fixArabic,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    ),
  );
}
