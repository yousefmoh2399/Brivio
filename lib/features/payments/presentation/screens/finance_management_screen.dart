import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_payment_repositories.dart';
import '../../domain/models/payment_models.dart';
import 'daily_cash_register_screen.dart';
import 'teacher_settlement_screen.dart';
import '../widgets/digital_cash_receipt_dialog.dart';

class FinanceManagementScreen extends StatefulWidget {
  const FinanceManagementScreen({super.key});

  @override
  State<FinanceManagementScreen> createState() =>
      _FinanceManagementScreenState();
}

class _FinanceManagementScreenState extends State<FinanceManagementScreen> {
  late final SupabaseSubscriptionPlanRepository _planRepo;
  late final SupabaseInvoiceRepository _invoiceRepo;
  late final SupabasePaymentRepository _paymentRepo;
  late final SupabaseReceiptRepository _receiptRepo;
  late final SupabaseStudentRepository _studentRepo;

  List<Student> _students = [];
  Student? _selectedStudent;
  List<SubscriptionPlan> _plans = [];
  List<Invoice> _invoices = [];
  List<Receipt> _receipts = [];
  List<_PaymentAdjustmentRequest> _adjustmentRequests = [];
  SystemFinancialSummary? _systemSummary;
  bool _isLoading = false;
  String? _errorMessage;

  // Filter controllers for plans tab
  final TextEditingController _planSearchController = TextEditingController();
  String _planBillingFilter = 'all'; // all, installment, one_time

  // Filter controllers for invoices tab
  final TextEditingController _invoiceSearchController = TextEditingController();
  String _invoiceStatusFilter = 'all'; // all, unpaid, paid, overdue

  // Filter controllers for receipts tab
  final TextEditingController _receiptSearchController = TextEditingController();

  // Filter controllers for adjustments tab
  final TextEditingController _adjustmentSearchController = TextEditingController();
  String _adjustmentStatusFilter = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _planRepo = SupabaseSubscriptionPlanRepository(wrapper);
    _invoiceRepo = SupabaseInvoiceRepository(wrapper);
    _paymentRepo = SupabasePaymentRepository(wrapper);
    _receiptRepo = SupabaseReceiptRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _loadFinanceData();
  }

  @override
  void dispose() {
    _planSearchController.dispose();
    _invoiceSearchController.dispose();
    _receiptSearchController.dispose();
    _adjustmentSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadFinanceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = await _planRepo.fetchPlans();
      final studentsPage = await _studentRepo.fetchStudents(pageSize: 100);
      final selected =
          _selectedStudent ??
          (studentsPage.data.isEmpty ? null : studentsPage.data.first);
      final inv = selected == null
          ? <Invoice>[]
          : await _invoiceRepo.fetchInvoicesForStudent(selected.id);
      final rec = selected == null
          ? <Receipt>[]
          : await _receiptRepo.fetchReceiptsForStudent(selected.id);

      List<_PaymentAdjustmentRequest> adjustments = [];
      try {
        final adjustmentsResponse = await Supabase.instance.client.rpc(
          'get_payment_adjustment_requests',
          params: {'p_status': null},
        );
        if (adjustmentsResponse is List) {
          adjustments = adjustmentsResponse
              .whereType<Map>()
              .map((row) => _PaymentAdjustmentRequest.fromJson(row))
              .toList();
        }
      } catch (_) {}

      final sysSummary = await _paymentRepo.fetchSystemFinancialSummary();

      if (mounted) {
        setState(() {
          _students = studentsPage.data;
          _selectedStudent = selected;
          _plans = p;
          _invoices = inv;
          _receipts = rec;
          _adjustmentRequests = adjustments;
          _systemSummary = sysSummary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onStudentChanged(Student? student) async {
    if (student == null) return;
    setState(() {
      _selectedStudent = student;
      _isLoading = true;
    });

    try {
      final inv = await _invoiceRepo.fetchInvoicesForStudent(student.id);
      final rec = await _receiptRepo.fetchReceiptsForStudent(student.id);
      if (mounted) {
        setState(() {
          _invoices = inv;
          _receipts = rec;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCreatePlanDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String billingType = 'installment';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.card_membership_rounded, color: AppColors.adminRole),
                SizedBox(width: 8),
                Text('إنشاء خطة اشتراك جديدة'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 500.0),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم الخطة (مثال: الترم الأول رياضيات)',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى إدخال اسم الخطة.';
                          }
                          if (v.trim().length < 3) {
                            return 'يجب أن يكون الاسم 3 أحرف على الأقل.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الوصف أو الملاحظات',
                          prefixIcon: Icon(Icons.description_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: billingType,
                        decoration: const InputDecoration(
                          labelText: 'طريقة المحاسبة',
                          prefixIcon: Icon(Icons.payment_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'installment',
                            child: Text('أقساط مجدولة (3 أقساط)'),
                          ),
                          DropdownMenuItem(
                            value: 'one_time',
                            child: Text('دفعة واحدة كاملة'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setStateDialog(() => billingType = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ الإجمالي (ج.م)',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى إدخال المبلغ الإجمالي.';
                          }
                          final amt = int.tryParse(v.trim());
                          if (amt == null || amt <= 0) {
                            return 'يرجى إدخال مبلغ صحيح أكبر من صفر.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setStateDialog(() => isSaving = true);
                        final nav = Navigator.of(ctx);
                        final amtEgp = int.parse(amountCtrl.text.trim());

                        try {
                          await Supabase.instance.client
                              .from('subscription_plans')
                              .insert({
                                'name': nameCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                                'billing_type': billingType,
                                'total_amount_minor': amtEgp * 100,
                                'currency': 'EGP',
                                'installment_count':
                                    billingType == 'installment' ? 3 : 1,
                                'status': 'active',
                              });
                          nav.pop();
                          _loadFinanceData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إنشاء خطة الاشتراك بنجاح!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل إنشاء الخطة: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ الخطة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignSubscriptionDialog() {
    final selectedStudent = _selectedStudent;
    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار طالب أولاً.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد خطط اشتراك متاحة. قم بإنشاء خطة أولاً.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String selectedPlanId = _plans.first.id;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final currentPlan =
              _plans.firstWhere((p) => p.id == selectedPlanId);

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.assignment_ind_rounded, color: AppColors.adminRole),
                SizedBox(width: 8),
                Text('تسكين اشتراك لطالب'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 500.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.adminRole.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.adminRole.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الطالب: ${selectedStudent.fullName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'كود الطالب: ${selectedStudent.studentCode}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPlanId,
                      decoration: const InputDecoration(
                        labelText: 'اختر خطة الاشتراك',
                        prefixIcon: Icon(Icons.card_membership_rounded),
                      ),
                      items: _plans
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.name} (${_money(p.totalAmountMinor)})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => selectedPlanId = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'طريقة السداد: ${currentPlan.billingType == "installment" ? "أقساط مجدولة (${currentPlan.installmentCount} أقساط)" : "دفعة كاملة"}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (currentPlan.billingType == "installment")
                            Text(
                              'قيمة القسط تقريباً: ${_money(currentPlan.totalAmountMinor ~/ currentPlan.installmentCount)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setStateDialog(() => isSaving = true);
                        final nav = Navigator.of(ctx);
                        try {
                          try {
                            await Supabase.instance.client.rpc(
                              'assign_student_subscription',
                              params: {
                                'p_student_id': selectedStudent.id,
                                'p_plan_id': selectedPlanId,
                              },
                            );
                          } catch (rpcErr) {
                            final errStr = rpcErr.toString();
                            if (errStr.contains('PGRST202') ||
                                errStr.contains('p_subscription_plan_id') ||
                                errStr.contains('schema cache')) {
                              await Supabase.instance.client.rpc(
                                'assign_student_subscription',
                                params: {
                                  'p_student_id': selectedStudent.id,
                                  'p_subscription_plan_id': selectedPlanId,
                                },
                              );
                            } else {
                              rethrow;
                            }
                          }
                          nav.pop();
                          _loadFinanceData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم تسكين الاشتراك وتوليد الفاتورة بنجاح!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل تسكين الاشتراك: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تأكيد التسكين'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecordPaymentDialog(Invoice inv) {
    final formKey = GlobalKey<FormState>();
    final remainingAmount =
        ((inv.totalMinor - inv.amountPaidMinor) / 100).clamp(0, double.infinity);
    final amountCtrl = TextEditingController(
      text: remainingAmount.toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController();
    String paymentMethod = 'cash';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payments_rounded, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تسجيل سداد (${inv.invoiceNumber})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 500.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المبلغ المتبقي للتحصيل:',
                            style: TextStyle(fontSize: 13),
                          ),
                          Text(
                            '${remainingAmount.toStringAsFixed(0)} ج.م',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'مبلغ التحصيل (ج.م)',
                        prefixIcon: Icon(Icons.money_rounded),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'يرجى إدخال مبلغ التحصيل.';
                        }
                        final amt = double.tryParse(v.trim());
                        if (amt == null || amt <= 0) {
                          return 'يرجى إدخال مبلغ صحيح أكبر من صفر.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('نقدي (خزينة السنتر) 💵'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => paymentMethod = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات أو رقم مرجعي للمعاملة',
                        prefixIcon: Icon(Icons.note_alt_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => isSaving = true);
                      final nav = Navigator.of(ctx);
                      final amtEgp = double.parse(amountCtrl.text.trim());

                      try {
                        await _paymentRepo.recordManualPayment(
                          invoiceId: inv.id,
                          amountMinor: (amtEgp * 100).round(),
                          paymentMethod: paymentMethod,
                          notes: notesCtrl.text.trim(),
                        );
                        nav.pop();
                        _loadFinanceData();
                        final recNum = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        final dateStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم تسجيل السداد النقدي وإصدار الإيصال بنجاح!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          DigitalCashReceiptDialog.show(
                            context: context,
                            receiptType: ReceiptType.studentPayment,
                            centerName: 'منظومة بريفيو التعليمية المتطورة',
                            receiptNumber: recNum,
                            dateStr: dateStr,
                            recipientName: _selectedStudent?.fullName ?? 'طالب المركز',
                            studentCode: _selectedStudent?.studentCode ?? '',
                            groupName: 'الاشتراك الدراسي المعتمد',
                            amount: amtEgp,
                            paymentPurpose: notesCtrl.text.trim().isNotEmpty
                                ? notesCtrl.text.trim()
                                : 'سداد فاتورة #${inv.invoiceNumber}',
                            parentOrTeacherPhone: _selectedStudent?.phoneNumber,
                            paymentMethod: paymentMethod == 'cash'
                                ? 'نقداً بالخزينة (كاش) 💵'
                                : paymentMethod,
                            invoiceNumber: inv.invoiceNumber,
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل تسجيل السداد: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تأكيد التحصيل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decideAdjustment(
    _PaymentAdjustmentRequest request,
    bool approve,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'apply_payment_adjustment_request',
        params: {
          'p_request_id': request.id,
          'p_approve': approve,
          'p_decision_note': approve
              ? 'تمت الموافقة من الإدارة المالية.'
              : 'تم الرفض من الإدارة المالية.',
        },
      );
      await _loadFinanceData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'تم اعتماد الخصم / الإعفاء بنجاح.'
                  : 'تم رفض طلب الخصم / الإعفاء.',
            ),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل اتخاذ القرار بشأن الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRescheduleInvoiceDialog(Invoice inv) {
    DateTime selectedDate = inv.dueAt.isAfter(DateTime.now())
        ? inv.dueAt
        : DateTime.now().add(const Duration(days: 7));
    final reasonCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final formattedCurrent =
              '${inv.dueAt.year}-${inv.dueAt.month.toString().padLeft(2, '0')}-${inv.dueAt.day.toString().padLeft(2, '0')}';
          final formattedSelected =
              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_calendar_rounded,
                      color: Colors.blue, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تعديل موعد استحقاق الفاتورة #${inv.invoiceNumber}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('تاريخ الاستحقاق الحالي:',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              Text(formattedCurrent,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المبلغ المستحق:',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              Text(_money(inv.totalMinor - inv.amountPaidMinor),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.red)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('اختر موعد الاستحقاق الجديد:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Quick Preset Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today, size: 14),
                          label: const Text('+3 أيام',
                              style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setStateDialog(() {
                              selectedDate =
                                  DateTime.now().add(const Duration(days: 3));
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today, size: 14),
                          label: const Text('+أسبوع (7 أيام)',
                              style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setStateDialog(() {
                              selectedDate =
                                  DateTime.now().add(const Duration(days: 7));
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today, size: 14),
                          label: const Text('+أسبوعين (14 يوم)',
                              style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setStateDialog(() {
                              selectedDate =
                                  DateTime.now().add(const Duration(days: 14));
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today, size: 14),
                          label: const Text('نهاية الشهر',
                              style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            final now = DateTime.now();
                            final end = DateTime(now.year, now.month + 1, 0);
                            setStateDialog(() {
                              selectedDate = end;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 30)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          helpText: 'اختر تاريخ استحقاق الفاتورة',
                        );
                        if (picked != null) {
                          setStateDialog(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded,
                                    color: AppColors.adminRole, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'الموعد المحدد: $formattedSelected',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            const Text('تغيير 📅',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.adminRole)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'سبب تمديد أو تعديل موعد السداد (اختياري)',
                        hintText:
                            'مثال: بناءً على طلب ولي الأمر / تأجيل لظروف السفر',
                        prefixIcon: Icon(Icons.comment_outlined, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سيتم تحديث موعد الاستحقاق فوراً وإشعار الطالب وولي الأمر بالموعد الجديد عبر الإشعارات.',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('حفظ موعد الاستحقاق الجديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminRole,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setStateDialog(() => isSaving = true);
                        final nav = Navigator.of(ctx);
                        try {
                          await _invoiceRepo.rescheduleDueDate(
                            invoiceId: inv.id,
                            newDueAt: selectedDate,
                            reason: reasonCtrl.text.trim().isNotEmpty
                                ? reasonCtrl.text.trim()
                                : null,
                          );
                          nav.pop();
                          _loadFinanceData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'تم تعديل موعد استحقاق الفاتورة #${inv.invoiceNumber} بنجاح وإشعار الطالب 📅'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('فشل تعديل موعد الاستحقاق: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMonthlyBillingCycleDialog() {
    DateTime targetMonth =
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    int dueDays = 7;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final monthLabel = 'شهر ${targetMonth.month} / ${targetMonth.year}';

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.electric_bolt_rounded,
                      color: Colors.deepPurple, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'توليد مطالبات ومصروفات الشهر الجديد',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 520.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.deepPurple, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تقوم هذه العملية الآلية بحصر جميع الطلاب المقيدين في المجموعات الدراسية النشطة، وإصدار فواتير ومطالبات الشهر الجديد تلقائياً مع تفادي التكرار، وتحديد موعد الاستحقاق وإرسال إشعارات فورية للطلاب وأولياء الأمور.',
                              style: TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('الشهر المستهدف للفوترة:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.today_rounded, size: 16),
                            label: Text(
                                'الشهر الحالي (${DateTime.now().month}/${DateTime.now().year})',
                                style: const TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  targetMonth.month == DateTime.now().month
                                      ? Colors.deepPurple
                                          .withValues(alpha: 0.1)
                                      : null,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                targetMonth = DateTime(DateTime.now().year,
                                    DateTime.now().month, 1);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.next_plan_outlined,
                                size: 16),
                            label: Text(
                              'الشهر القادم (${DateTime.now().month == 12 ? 1 : DateTime.now().month + 1}/${DateTime.now().month == 12 ? DateTime.now().year + 1 : DateTime.now().year})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  targetMonth.month != DateTime.now().month
                                      ? Colors.deepPurple
                                          .withValues(alpha: 0.1)
                                      : null,
                            ),
                            onPressed: () {
                              final now = DateTime.now();
                              setStateDialog(() {
                                targetMonth =
                                    DateTime(now.year, now.month + 1, 1);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('مهلة سداد المطالبة (أيام الاستحقاق):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: dueDays,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.timer_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 3,
                            child: Text('خلال 3 أيام من أول الشهر')),
                        DropdownMenuItem(
                            value: 7,
                            child:
                                Text('خلال أسبوع (7 أيام - الموصى به)')),
                        DropdownMenuItem(
                            value: 10,
                            child: Text('خلال 10 أيام من أول الشهر')),
                        DropdownMenuItem(
                            value: 14,
                            child: Text('خلال أسبوعين (14 يوماً)')),
                        DropdownMenuItem(
                            value: 30,
                            child: Text('حتى نهاية الشهر بالكامل')),
                      ],
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => dueDays = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bolt_rounded, size: 20),
                label: Text(isProcessing
                    ? 'جارٍ توليد المطالبات...'
                    : 'بدء توليد مطالبات $monthLabel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setStateDialog(() => isProcessing = true);
                        final nav = Navigator.of(ctx);
                        try {
                          final result =
                              await _paymentRepo.generateMonthlyBillingCycle(
                            billingMonth: targetMonth,
                            dueDays: dueDays,
                          );
                          nav.pop();
                          _loadFinanceData();

                          final created =
                              result['invoices_created'] ?? 0;
                          final totalMinor =
                              (result['total_amount_minor'] as num?)?.toInt() ??
                                  0;
                          final skipped =
                              result['invoices_skipped'] ?? 0;

                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: Colors.green, size: 24),
                                    SizedBox(width: 8),
                                    Text('اكتملت دورة الفوترة الشهرية ⚡'),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'تم الانتهاء بنجاح من دورة مطالبات $monthLabel:'),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.green
                                                .withValues(alpha: 0.2)),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              const Text(
                                                  'الفواتير الجديدة الصادرة:'),
                                              Text('$created فاتورة',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              const Text(
                                                  'إجمالي المبالغ المستحقة:'),
                                              Text(_money(totalMinor),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green)),
                                            ],
                                          ),
                                          if (skipped > 0) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                    'تم تخطيهم (تمت فوترتهم مسبقاً):'),
                                                Text('$skipped طالب',
                                                    style: const TextStyle(
                                                        color: Colors.grey)),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'تم إرسال إشعارات بالمطالبات ومواعيد السداد للطلاب وأولياء الأمور فوراً 📲.',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('تم'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isProcessing = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('فشل توليد مطالبات الشهر: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportFinancialData() async {
    try {
      final service = ReportGeneratorService();
      final financialData = <Map<String, dynamic>>[];
      for (var inv in _invoices) {
        financialData.add({
          'date': inv.dueAt.toIso8601String().substring(0, 10),
          'description': 'فاتورة #${inv.invoiceNumber}',
          'type': 'فاتورة مستحقة',
          'amount': (inv.totalMinor / 100).toStringAsFixed(2),
          'notes': _statusInArabic(inv.status),
        });
      }
      for (var rec in _receipts) {
        final receiptLabel = rec.receiptNumber.isEmpty
            ? '#${_shortId(rec.id)}'
            : rec.receiptNumber;
        financialData.add({
          'date': rec.issuedAt.toIso8601String().substring(0, 10),
          'description': 'إيصال سداد $receiptLabel',
          'type': 'تحصيل نقدي',
          'amount': (rec.amountMinor / 100).toStringAsFixed(2),
          'notes': 'المعاملة: ${rec.transactionId}',
        });
      }
      await service.generateFinancialReport(financialData: financialData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير التقرير المالي بنجاح 📄')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تصدير التقرير المالي: $e')),
        );
      }
    }
  }

  Widget _buildKpiSection() {
    if (_systemSummary == null) return const SizedBox.shrink();

    final collected = _systemSummary!.totalCollectedMinor;
    final outstanding = _systemSummary!.totalOutstandingMinor;
    final expected = _systemSummary!.expectedMonthlyRevenueMinor;
    final adjustments = _systemSummary!.totalAdjustmentsMinor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        final items = [
          _buildKpiCard(
            title: 'إجمالي المحصل الفعلي',
            value: _money(collected),
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.green,
            subtitle: 'تم إيداعه وتحصيله بالخزينة',
          ),
          _buildKpiCard(
            title: 'المبالغ المستحقة (غير مسددة)',
            value: _money(outstanding),
            icon: Icons.money_off_rounded,
            color: Colors.red,
            subtitle: 'فواتير قيد الانتظار أو متأخرة',
          ),
          _buildKpiCard(
            title: 'الإيراد الشهري المتوقع',
            value: _money(expected),
            icon: Icons.trending_up_rounded,
            color: Colors.blue,
            subtitle: 'تقدير الاشتراكات المستمرة',
          ),
          _buildKpiCard(
            title: 'الخصومات والتسويات',
            value: _money(adjustments),
            icon: Icons.percent_rounded,
            color: Colors.orange,
            subtitle: 'إعفاءات وتخفيضات معتمدة',
          ),
        ];

        if (isDesktop) {
          return Row(
            children: items
                .map((widget) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: widget,
                      ),
                    ))
                .toList(),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: items[0]),
                const SizedBox(width: 8),
                Expanded(child: items[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: items[2]),
                const SizedBox(width: 8),
                Expanded(child: items[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAdjustments =
        _adjustmentRequests.where((a) => a.status == 'pending').length;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final canPop = Navigator.of(context).canPop();
    final surfaceColor = Theme.of(context).scaffoldBackgroundColor;

    return DefaultTabController(
      length: 6,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: isMobile
              ? const EdgeInsets.fromLTRB(12, 10, 12, 0)
              : const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PortalHeader(
                      eyebrow: 'منظومة بريفيو التعليمية',
                      title: 'الإدارة المالية والاشتراكات',
                      subtitle:
                          'إدارة خطط الاشتراكات، الفواتير، التحصيلات، وإيصالات السداد.',
                      icon: Icons.monetization_on_rounded,
                      accentColor: AppColors.adminRole,
                      trailing: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (canPop)
                            IconButton.filledTonal(
                              tooltip: 'رجوع',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 10 : 14,
                                vertical: isMobile ? 6 : 8,
                              ),
                              minimumSize: isMobile ? const Size(36, 32) : const Size(48, 38),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _showMonthlyBillingCycleDialog,
                            icon: Icon(Icons.electric_bolt_rounded, size: isMobile ? 15 : 18),
                            label: Text(
                              isMobile ? 'المطالبات ⚡' : 'توليد مطالبات الشهر ⚡',
                              style: TextStyle(
                                fontSize: isMobile ? 11.5 : 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 12,
                                vertical: isMobile ? 6 : 8,
                              ),
                              minimumSize: isMobile ? const Size(36, 32) : const Size(48, 38),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DailyCashRegisterScreen(),
                                ),
                              );
                            },
                            icon: Icon(Icons.point_of_sale_rounded, size: isMobile ? 15 : 18),
                            label: Text(
                              isMobile ? 'الخزينة' : 'جرد الخزينة',
                              style: TextStyle(fontSize: isMobile ? 11.5 : 13),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 12,
                                vertical: isMobile ? 6 : 8,
                              ),
                              minimumSize: isMobile ? const Size(36, 32) : const Size(48, 38),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TeacherSettlementScreen(),
                                ),
                              );
                            },
                            icon: Icon(Icons.calculate_rounded, size: isMobile ? 15 : 18),
                            label: Text(
                              isMobile ? 'تصفية' : 'تصفية أرباح المدرسين',
                              style: TextStyle(fontSize: isMobile ? 11.5 : 13),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 12,
                                vertical: isMobile ? 6 : 8,
                              ),
                              minimumSize: isMobile ? const Size(36, 32) : const Size(48, 38),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _showCreatePlanDialog,
                            icon: Icon(Icons.add_circle_outline_rounded, size: isMobile ? 15 : 18),
                            label: Text(
                              isMobile ? 'خطة جديدة' : 'إضافة خطة اشتراك',
                              style: TextStyle(fontSize: isMobile ? 11.5 : 13),
                            ),
                          ),
                          IconButton.outlined(
                            tooltip: 'تصدير PDF',
                            visualDensity: VisualDensity.compact,
                            onPressed: _exportFinancialData,
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          ),
                          IconButton.outlined(
                            tooltip: 'تحديث',
                            visualDensity: VisualDensity.compact,
                            onPressed: _loadFinanceData,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildKpiSection(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      const Tab(
                        icon: Icon(Icons.analytics_rounded),
                        text: 'الملخص المالي',
                      ),
                      Tab(
                        icon: const Icon(Icons.card_membership_rounded),
                        text: 'خطط الاشتراكات (${_plans.length})',
                      ),
                      const Tab(
                        icon: Icon(Icons.assignment_ind_rounded),
                        text: 'تسكين الاشتراكات',
                      ),
                      Tab(
                        icon: const Icon(Icons.receipt_long_rounded),
                        text: 'الفواتير (${_invoices.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.receipt_rounded),
                        text: 'إيصالات السداد (${_receipts.length})',
                      ),
                      Tab(
                        icon: Badge(
                          isLabelVisible: pendingAdjustments > 0,
                          label: Text(pendingAdjustments.toString()),
                          child: const Icon(Icons.percent_rounded),
                        ),
                        text: 'طلبات الخصم',
                      ),
                    ],
                  ),
                  backgroundColor: surfaceColor,
                ),
              ),
            ],
            body: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: false,
              emptyTitle: 'لا توجد بيانات مالية',
              emptySubtitle:
                  'قم بإنشاء خطط اشتراك وتسجيل طلاب للبدء في المعاملات المالية.',
              emptyIcon: Icons.monetization_on_rounded,
              onRetry: _loadFinanceData,
              child: TabBarView(
                children: [
                  _buildOverviewTab(),
                  _buildPlansTab(),
                  _buildAssignTab(),
                  _buildInvoicesTab(),
                  _buildReceiptsTab(),
                  _buildAdjustmentsTab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_systemSummary == null) {
      return const Center(child: Text('جاري تحميل بيانات الملخص المالي...'));
    }

    final collected = _systemSummary!.totalCollectedMinor;
    final outstanding = _systemSummary!.totalOutstandingMinor;
    final totalExpected = collected + outstanding;
    final collectionRate = totalExpected > 0 ? (collected / totalExpected) : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collection Progress Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'نسبة التحصيل الفعلي',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${(collectionRate * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: collectionRate.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المحصل: ${_money(collected)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                    Text(
                      'المتبقي: ${_money(outstanding)}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Operations Quick Access
          const Text(
            'عمليات الإدارة المالية السريعة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;

              final cards = [
                _buildQuickActionTile(
                  icon: Icons.point_of_sale_rounded,
                  color: Colors.indigo,
                  title: 'جرد وتقفيل الخزينة اليومية',
                  subtitle: 'تسجيل المقبوضات والمصروفات ومطابقة العهدة',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DailyCashRegisterScreen(),
                    ),
                  ),
                ),
                _buildQuickActionTile(
                  icon: Icons.calculate_rounded,
                  color: Colors.teal,
                  title: 'تصفية أرباح المدرسين',
                  subtitle: 'احتساب نسب وحصص المعلمين واعتماد التحويلات',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeacherSettlementScreen(),
                    ),
                  ),
                ),
                _buildQuickActionTile(
                  icon: Icons.add_card_rounded,
                  color: AppColors.adminRole,
                  title: 'إضافة خطة اشتراك',
                  subtitle: 'تعريف باقة رسوم أو أقساط سنوية وترم',
                  onTap: _showCreatePlanDialog,
                ),
                _buildQuickActionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  color: Colors.deepOrange,
                  title: 'تصدير التقرير المالي (PDF)',
                  subtitle: 'تحميل بيان شامل لجميع الفواتير والإيصالات',
                  onTap: _exportFinancialData,
                ),
              ];

              if (isDesktop) {
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3.2,
                  children: cards,
                );
              }

              return Column(
                children: cards
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: c,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansTab() {
    final query = _planSearchController.text.trim().toLowerCase();
    final filtered = _plans.where((p) {
      if (_planBillingFilter != 'all') {
        if (p.billingType != _planBillingFilter) return false;
      }
      if (query.isEmpty) return true;
      final name = p.name.toLowerCase();
      final desc = (p.description ?? '').toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();

    return Column(
      children: [
        // Search & Filter
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              final searchField = TextField(
                controller: _planSearchController,
                decoration: InputDecoration(
                  hintText: 'بحث باسم خطة الاشتراك...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: _planSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _planSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              );

              final filterChips = Row(
                children: [
                  _buildFilterChip(
                    label: 'الكل (${_plans.length})',
                    isSelected: _planBillingFilter == 'all',
                    onSelected: () => setState(() => _planBillingFilter = 'all'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'أقساط',
                    isSelected: _planBillingFilter == 'installment',
                    onSelected: () =>
                        setState(() => _planBillingFilter = 'installment'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'دفعة كاملة',
                    isSelected: _planBillingFilter == 'one_time',
                    onSelected: () =>
                        setState(() => _planBillingFilter = 'one_time'),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: filterChips,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  filterChips,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Plans List / Grid
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.card_membership_rounded,
                        size: 54,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _plans.isEmpty
                            ? 'لا توجد خطط اشتراك مسجلة حالياً.'
                            : 'لا توجد خطط اشتراك مطابقة للبحث.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_plans.isEmpty)
                        ElevatedButton.icon(
                          onPressed: _showCreatePlanDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة أول خطة اشتراك'),
                        ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 170,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildPlanCard(filtered[i]),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _buildPlanCard(filtered[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isInstallment = plan.billingType == 'installment';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Name & Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.card_membership_rounded,
                  color: AppColors.adminRole,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PortalStatusChip(status: plan.status),
            ],
          ),
          if (plan.description != null && plan.description!.isNotEmpty)
            Text(
              plan.description!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          // Badges: Amount & Billing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _money(plan.totalAmountMinor),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isInstallment
                      ? 'أقساط مجدولة (${plan.installmentCount} أقساط)'
                      : 'دفعة كاملة',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.assignment_ind_rounded,
                      size: 28,
                      color: AppColors.adminRole,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تسكين خطط الاشتراكات والمصروفات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'اختر الطالب وخطة الاشتراك لإصدار الفاتورة وجدول الأقساط تلقائياً وتفعيل حسابه الأكاديمي.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                if (_students.isNotEmpty)
                  DropdownButtonFormField<Student>(
                    initialValue: _selectedStudent,
                    decoration: const InputDecoration(
                      labelText: 'الطالب المستهدف',
                      prefixIcon: Icon(Icons.person_search_rounded),
                    ),
                    items: _students
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.fullName} (${s.studentCode})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onStudentChanged,
                  ),
                const SizedBox(height: 16),
                if (_plans.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.adminRole.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.adminRole.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'عدد الخطط المتاحة: ${_plans.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        TextButton.icon(
                          onPressed: _showCreatePlanDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('إضافة خطة جديدة'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _selectedStudent == null || _plans.isEmpty
                      ? null
                      : _showAssignSubscriptionDialog,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('بدء تسكين الاشتراك للطالب المحدد'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoicesTab() {
    final query = _invoiceSearchController.text.trim().toLowerCase();
    final filtered = _invoices.where((inv) {
      if (_invoiceStatusFilter != 'all') {
        if (_invoiceStatusFilter == 'unpaid' && inv.status == 'paid') {
          return false;
        }
        if (_invoiceStatusFilter == 'paid' && inv.status != 'paid') {
          return false;
        }
        if (_invoiceStatusFilter == 'overdue' && inv.status != 'overdue') {
          return false;
        }
      }
      if (query.isNotEmpty) {
        return inv.invoiceNumber.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Student Picker & Filters
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              if (_students.isNotEmpty)
                DropdownButtonFormField<Student>(
                  initialValue: _selectedStudent,
                  decoration: const InputDecoration(
                    labelText: 'عرض فواتير الطالب',
                    prefixIcon: Icon(Icons.person_rounded, color: AppColors.adminRole),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _students
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.fullName} (${s.studentCode})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onStudentChanged,
                ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  final searchField = TextField(
                    controller: _invoiceSearchController,
                    decoration: InputDecoration(
                      hintText: 'بحث برقم الفاتورة...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: _invoiceSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _invoiceSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  );

                  final filterChips = Row(
                    children: [
                      _buildFilterChip(
                        label: 'الكل (${_invoices.length})',
                        isSelected: _invoiceStatusFilter == 'all',
                        onSelected: () =>
                            setState(() => _invoiceStatusFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: 'غير مسدد',
                        isSelected: _invoiceStatusFilter == 'unpaid',
                        onSelected: () =>
                            setState(() => _invoiceStatusFilter = 'unpaid'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: 'مسدد بالكامل',
                        isSelected: _invoiceStatusFilter == 'paid',
                        onSelected: () =>
                            setState(() => _invoiceStatusFilter = 'paid'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: 'متأخر',
                        isSelected: _invoiceStatusFilter == 'overdue',
                        onSelected: () =>
                            setState(() => _invoiceStatusFilter = 'overdue'),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: filterChips,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: filterChips,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Invoices List / Grid
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 54,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _invoices.isEmpty
                            ? 'لا توجد فواتير مسجلة لهذا الطالب حتى الآن.'
                            : 'لا توجد فواتير مطابقة للبحث أو الفلتر.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 200,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) =>
                            _buildInvoiceCard(filtered[i]),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _buildInvoiceCard(filtered[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(Invoice inv) {
    final isUnpaid = inv.status != 'paid';
    final remainingMinor = inv.totalMinor - inv.amountPaidMinor;
    final progress = inv.totalMinor > 0 ? (inv.amountPaidMinor / inv.totalMinor) : 0.0;
    final dueDateStr =
        '${inv.dueAt.year}-${inv.dueAt.month.toString().padLeft(2, '0')}-${inv.dueAt.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Invoice Number & Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isUnpaid ? Colors.orange : Colors.green)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: isUnpaid ? Colors.orange : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فاتورة #${inv.invoiceNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'تاريخ الاستحقاق: $dueDateStr',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isUnpaid ? Colors.orange : Colors.green)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusInArabic(inv.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isUnpaid ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          // Progress & Amounts
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الإجمالي: ${_money(inv.totalMinor)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'المتبقي: ${_money(remainingMinor)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isUnpaid ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUnpaid ? Colors.orange : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          // Actions
          if (isUnpaid)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showRecordPaymentDialog(inv),
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: const Text('تحصيل سداد نقدي'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRescheduleInvoiceDialog(inv),
                    icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                    label: const Text(
                      'تعديل موعد الاستحقاق / تمديد السداد 📅',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _openInvoiceReceipt(inv),
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('عرض الإيصال الرسمي 🧾'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openReceiptDialog(Receipt rec) {
    final s = _selectedStudent;
    final dateStr =
        '${rec.issuedAt.year}-${rec.issuedAt.month.toString().padLeft(2, '0')}-${rec.issuedAt.day.toString().padLeft(2, '0')}';
    final recNum = rec.receiptNumber.isNotEmpty
        ? rec.receiptNumber
        : 'REC-${rec.id.length >= 8 ? rec.id.substring(0, 8).toUpperCase() : rec.id}';

    DigitalCashReceiptDialog.show(
      context: context,
      receiptType: ReceiptType.studentPayment,
      centerName: 'منظومة بريفيو التعليمية المتطورة',
      receiptNumber: recNum,
      dateStr: dateStr,
      recipientName: s?.fullName ?? 'طالب المركز',
      studentCode: s?.studentCode ?? (rec.studentId.length >= 8 ? rec.studentId.substring(0, 8).toUpperCase() : rec.studentId),
      groupName: 'الاشتراك الدراسي المعتمد',
      amount: rec.amountMinor / 100.0,
      paymentPurpose: 'سداد رسوم واشتراك معتمد بالخزينة',
      parentOrTeacherPhone: s?.phoneNumber,
      paymentMethod: 'إيصال تحصيل رسمي معتمد',
      invoiceNumber: rec.invoiceId.isNotEmpty
          ? 'INV-${rec.invoiceId.length >= 8 ? rec.invoiceId.substring(0, 8).toUpperCase() : rec.invoiceId}'
          : null,
      transactionId: rec.transactionId.isNotEmpty ? rec.transactionId : null,
    );
  }

  void _openInvoiceReceipt(Invoice inv) {
    final s = _selectedStudent;
    final dateStr =
        '${inv.issuedAt.year}-${inv.issuedAt.month.toString().padLeft(2, '0')}-${inv.issuedAt.day.toString().padLeft(2, '0')}';
    final recNum = 'REC-${inv.invoiceNumber.isNotEmpty ? inv.invoiceNumber : (inv.id.length >= 8 ? inv.id.substring(0, 8).toUpperCase() : inv.id)}';

    DigitalCashReceiptDialog.show(
      context: context,
      receiptType: ReceiptType.studentPayment,
      centerName: 'منظومة بريفيو التعليمية المتطورة',
      receiptNumber: recNum,
      dateStr: dateStr,
      recipientName: s?.fullName ?? 'طالب المركز',
      studentCode: s?.studentCode ?? '',
      groupName: 'الاشتراك الدراسي المعتمد',
      amount: inv.amountPaidMinor > 0 ? (inv.amountPaidMinor / 100.0) : (inv.totalMinor / 100.0),
      paymentPurpose: 'سداد معتمد للفاتورة #${inv.invoiceNumber}',
      parentOrTeacherPhone: s?.phoneNumber,
      paymentMethod: 'إيصال دفع معتمد',
      invoiceNumber: inv.invoiceNumber,
    );
  }

  Widget _buildReceiptsTab() {
    final query = _receiptSearchController.text.trim().toLowerCase();
    final filtered = _receipts.where((rec) {
      if (query.isEmpty) return true;
      final num = rec.receiptNumber.toLowerCase();
      final tx = rec.transactionId.toLowerCase();
      return num.contains(query) || tx.contains(query);
    }).toList();

    return Column(
      children: [
        // Student Picker & Search
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              if (_students.isNotEmpty)
                DropdownButtonFormField<Student>(
                  initialValue: _selectedStudent,
                  decoration: const InputDecoration(
                    labelText: 'عرض إيصالات الطالب',
                    prefixIcon: Icon(Icons.person_rounded, color: AppColors.adminRole),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _students
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.fullName} (${s.studentCode})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onStudentChanged,
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _receiptSearchController,
                decoration: InputDecoration(
                  hintText: 'بحث برقم الإيصال أو المعاملة...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: _receiptSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _receiptSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Receipts List / Grid
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_rounded,
                        size: 54,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _receipts.isEmpty
                            ? 'لم يتم إصدار إيصالات دفع لهذا الطالب حتى الآن.'
                            : 'لا توجد إيصالات مطابقة للبحث.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 150,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildReceiptCard(filtered[i]),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _buildReceiptCard(filtered[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(Receipt rec) {
    final receiptLabel = rec.receiptNumber.isEmpty
        ? '#${_shortId(rec.id)}'
        : rec.receiptNumber;
    final dateStr =
        '${rec.issuedAt.year}-${rec.issuedAt.month.toString().padLeft(2, '0')}-${rec.issuedAt.day.toString().padLeft(2, '0')}';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openReceiptDialog(rec),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إيصال تحصيل $receiptLabel',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'تاريخ السداد: $dateStr',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _money(rec.amountMinor),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'رقم المعاملة: ${rec.transactionId.length >= 8 ? rec.transactionId.substring(0, 8) : rec.transactionId}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _openReceiptDialog(rec),
                  icon: const Icon(Icons.receipt_long_rounded, size: 14),
                  label: const Text('معاينة وطباعة 🧾', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustmentsTab() {
    final query = _adjustmentSearchController.text.trim().toLowerCase();
    final filtered = _adjustmentRequests.where((req) {
      if (_adjustmentStatusFilter != 'all') {
        if (req.status != _adjustmentStatusFilter) return false;
      }
      if (query.isEmpty) return true;
      final student = req.studentName.toLowerCase();
      final group = req.groupName.toLowerCase();
      final teacher = req.teacherName.toLowerCase();
      final reason = req.reason.toLowerCase();
      return student.contains(query) ||
          group.contains(query) ||
          teacher.contains(query) ||
          reason.contains(query);
    }).toList();

    return Column(
      children: [
        // Filter & Search
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              final searchField = TextField(
                controller: _adjustmentSearchController,
                decoration: InputDecoration(
                  hintText: 'بحث باسم الطالب، المعلم، أو السبب...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: _adjustmentSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _adjustmentSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              );

              final filterChips = Row(
                children: [
                  _buildFilterChip(
                    label: 'الكل (${_adjustmentRequests.length})',
                    isSelected: _adjustmentStatusFilter == 'all',
                    onSelected: () =>
                        setState(() => _adjustmentStatusFilter = 'all'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'قيد المراجعة',
                    isSelected: _adjustmentStatusFilter == 'pending',
                    onSelected: () =>
                        setState(() => _adjustmentStatusFilter = 'pending'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'معتمدة',
                    isSelected: _adjustmentStatusFilter == 'approved',
                    onSelected: () =>
                        setState(() => _adjustmentStatusFilter = 'approved'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'مرفوضة',
                    isSelected: _adjustmentStatusFilter == 'rejected',
                    onSelected: () =>
                        setState(() => _adjustmentStatusFilter = 'rejected'),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: filterChips,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: filterChips,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Adjustments List / Grid
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.percent_rounded,
                        size: 54,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد طلبات خصم أو إعفاء مطابقة.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 220,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) =>
                            _buildAdjustmentCard(filtered[i]),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) =>
                          _buildAdjustmentCard(filtered[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAdjustmentCard(_PaymentAdjustmentRequest req) {
    final isPending = req.status == 'pending';
    final isExemption = req.adjustmentType == 'exemption';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Student & Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isPending ? Colors.orange : AppColors.adminRole)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isExemption
                      ? Icons.volunteer_activism_rounded
                      : Icons.percent_rounded,
                  color: isPending ? Colors.orange : AppColors.adminRole,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${req.studentName} (${req.groupName})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'المعلم: ${req.teacherName}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              PortalStatusChip(status: req.status),
            ],
          ),
          // Price comparison breakdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الأصلي: ${_money(req.originalPriceMinor)}',
                  style: const TextStyle(
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'الخصم: ${_money(req.requestedDiscountMinor)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'النهائي: ${_money(req.requestedFinalPriceMinor)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          if (req.reason.isNotEmpty)
            Text(
              'السبب: ${req.reason}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          // Decision Buttons
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decideAdjustment(req, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decideAdjustment(req, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('موافقة'),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              child: Text(
                'تم اتخاذ القرار (${req.status})',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppColors.adminRole,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  String _shortId(String value) {
    if (value.length <= 8) return value;
    return value.substring(0, 8);
  }

  static String _statusInArabic(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'خالص المسدد';
      case 'partially_paid':
        return 'مدفوع جزئياً';
      case 'overdue':
        return 'متأخر';
      case 'pending':
      case 'issued':
        return 'مستحق';
      default:
        return status;
    }
  }
}

class _PaymentAdjustmentRequest {
  final String id;
  final String studentName;
  final String groupName;
  final String teacherName;
  final String adjustmentType;
  final int originalPriceMinor;
  final int requestedDiscountMinor;
  final int requestedFinalPriceMinor;
  final String currency;
  final String reason;
  final String status;

  const _PaymentAdjustmentRequest({
    required this.id,
    required this.studentName,
    required this.groupName,
    required this.teacherName,
    required this.adjustmentType,
    required this.originalPriceMinor,
    required this.requestedDiscountMinor,
    required this.requestedFinalPriceMinor,
    required this.currency,
    required this.reason,
    required this.status,
  });

  factory _PaymentAdjustmentRequest.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _PaymentAdjustmentRequest(
      id: json['request_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'الطالب',
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      teacherName: json['teacher_name']?.toString() ?? 'المعلم',
      adjustmentType: json['adjustment_type']?.toString() ?? 'discount',
      originalPriceMinor: _asInt(json['original_price_minor']),
      requestedDiscountMinor: _asInt(json['requested_discount_minor']),
      requestedFinalPriceMinor: _asInt(json['requested_final_price_minor']),
      currency: json['currency']?.toString() ?? 'EGP',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _money(int minor, [String currency = 'ج.م']) {
  final amount = minor / 100;
  final formatted = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$formatted $currency';
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  const _SliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
