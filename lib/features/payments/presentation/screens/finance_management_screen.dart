import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_payment_repositories.dart';
import '../../domain/models/payment_models.dart';
import '../../../../core/services/report_generator_service.dart';
import 'daily_cash_register_screen.dart';
import 'teacher_settlement_screen.dart';

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

  // Invoice filtering
  String _invoiceStatusFilter = 'all';
  String _invoiceSearchQuery = '';

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
            title: const Text('إنشاء خطة اشتراك جديدة'),
            content: Form(
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
            title: const Text('تسكين اشتراك لطالب'),
            content: Column(
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
                            '${p.name} (${(p.totalAmountMinor / 100).toStringAsFixed(0)} ج.م)',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => selectedPlanId = v);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'طريقة السداد: ${currentPlan.billingType == "installment" ? "أقساط مجدولة" : "دفعة كاملة"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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
          title: Text('تسجيل سداد (${inv.invoiceNumber})'),
          content: Form(
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
                        child: Text('نقدي (خزينة السنتر)'),
                      ),
                      DropdownMenuItem(
                        value: 'vodafone_cash',
                        child: Text('محفظة إلكترونية (فودافون كاش)'),
                      ),
                      DropdownMenuItem(
                        value: 'instapay',
                        child: Text('تحويل إنستاباي (InstaPay)'),
                      ),
                      DropdownMenuItem(
                        value: 'pos_card',
                        child: Text('بطاقة بنكية / فيزا (POS)'),
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
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم تسجيل السداد النقدي وإصدار الإيصال بنجاح!',
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

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _invoices.where((inv) {
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
      if (_invoiceSearchQuery.isNotEmpty) {
        final q = _invoiceSearchQuery.toLowerCase();
        return inv.invoiceNumber.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return DefaultTabController(
      length: 6,
      child: PortalPageShell(
        title: 'الإدارة المالية والاشتراكات',
        subtitle:
            'إدارة خطط الاشتراكات، الفواتير، التحصيلات، وإيصالات السداد.',
        icon: Icons.monetization_on,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.refresh,
            label: 'تحديث',
            onPressed: _loadFinanceData,
          ),
          PortalAction(
            icon: Icons.point_of_sale_rounded,
            label: 'جرد وتقفيل الخزينة اليومية',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DailyCashRegisterScreen(),
                ),
              );
            },
            primary: true,
          ),
          PortalAction(
            icon: Icons.calculate_rounded,
            label: 'تصفية أرباح المدرسين',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TeacherSettlementScreen(),
                ),
              );
            },
            primary: false,
          ),
          PortalAction(
            icon: Icons.add,
            label: 'إضافة خطة اشتراك',
            onPressed: _showCreatePlanDialog,
            primary: false,
          ),
          PortalAction(
            icon: Icons.picture_as_pdf,
            label: 'تصدير تقرير (PDF)',
            onPressed: _exportFinancialData,
            primary: false,
          ),
        ],
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                  icon: Icon(Icons.analytics_rounded),
                  text: 'الملخص المالي',
                ),
                Tab(
                  icon: Icon(Icons.card_membership_rounded),
                  text: 'خطط الاشتراكات',
                ),
                Tab(
                  icon: Icon(Icons.assignment_ind_rounded),
                  text: 'تسكين الاشتراكات',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long_rounded),
                  text: 'الفواتير',
                ),
                Tab(
                  icon: Icon(Icons.receipt_rounded),
                  text: 'إيصالات السداد',
                ),
                Tab(
                  icon: Icon(Icons.percent_rounded),
                  text: 'طلبات الخصم',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PortalStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: false,
                emptyTitle: 'لا توجد بيانات مالية',
                emptySubtitle:
                    'قم بإنشاء خطط اشتراك وتسجيل طلاب للبدء في المعاملات المالية.',
                emptyIcon: Icons.monetization_on,
                onRetry: _loadFinanceData,
                child: TabBarView(
                  children: [
                    // Tab 1: System Financial Summary
                    _systemSummary == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: PortalMetricGrid(
                              children: [
                                PortalMetricCard(
                                  label: 'المبالغ المستحقة (غير مسددة)',
                                  value: _money(
                                    _systemSummary!.totalOutstandingMinor,
                                  ),
                                  icon: Icons.money_off_rounded,
                                  accentColor: Colors.red,
                                ),
                                PortalMetricCard(
                                  label: 'إجمالي المحصل الفعلي',
                                  value: _money(
                                    _systemSummary!.totalCollectedMinor,
                                  ),
                                  icon: Icons.account_balance_wallet_rounded,
                                  accentColor: Colors.green,
                                ),
                                PortalMetricCard(
                                  label: 'الإيراد الشهري المتوقع',
                                  value: _money(
                                    _systemSummary!.expectedMonthlyRevenueMinor,
                                  ),
                                  icon: Icons.trending_up_rounded,
                                  accentColor: Colors.blue,
                                ),
                                PortalMetricCard(
                                  label: 'إجمالي الخصومات والتسويات',
                                  value: _money(
                                    _systemSummary!.totalAdjustmentsMinor,
                                  ),
                                  icon: Icons.percent_rounded,
                                  accentColor: Colors.orange,
                                ),
                              ],
                            ),
                          ),
                    // Tab 2: Subscription Plans
                    _plans.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.card_membership_rounded,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'لا توجد خطط اشتراك مسجلة حالياً.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _showCreatePlanDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('إضافة أول خطة اشتراك'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _plans.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final p = _plans[i];
                              final billingTypeLabel =
                                  p.billingType == 'installment'
                                      ? 'أقساط مجدولة'
                                      : 'دفعة واحدة';
                              return PortalListCard(
                                icon: Icons.card_membership_rounded,
                                accentColor: AppColors.adminRole,
                                title: p.name,
                                subtitle:
                                    '${p.description ?? ""}\nطريقة المحاسبة: $billingTypeLabel | الإجمالي: ${(p.totalAmountMinor / 100).toStringAsFixed(0)} ج.م',
                                trailing: [PortalStatusChip(status: p.status)],
                              );
                            },
                          ),
                    // Tab 3: Assign Subscription
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_students.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: DropdownButtonFormField<Student>(
                                  initialValue: _selectedStudent,
                                  decoration: const InputDecoration(
                                    labelText: 'اختر الطالب المستهدف',
                                    prefixIcon: Icon(Icons.person_search_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _students
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(
                                            '${s.fullName} (${s.studentCode})',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _onStudentChanged,
                                ),
                              ),
                            const Icon(
                              Icons.assignment_ind_rounded,
                              size: 54,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'تسكين خطط الاشتراكات والمصروفات للطلاب',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'اختر الطالب وخطة الاشتراك لإصدار الفاتورة وجدول الأقساط تلقائياً.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed:
                                  _selectedStudent == null || _plans.isEmpty
                                      ? null
                                      : _showAssignSubscriptionDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('تسكين اشتراك للطالب المحدد'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tab 4: Invoices
                    Column(
                      children: [
                        // Student Switcher & Filters
                        if (_students.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<Student>(
                                        initialValue: _selectedStudent,
                                        decoration: const InputDecoration(
                                          labelText: 'عرض فواتير الطالب',
                                          prefixIcon: Icon(Icons.person_rounded),
                                          isDense: true,
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
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _invoiceStatusFilter,
                                        decoration: const InputDecoration(
                                          labelText: 'الحالة',
                                          isDense: true,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'all',
                                            child: Text('الكل'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'unpaid',
                                            child: Text('غير مسدد'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'paid',
                                            child: Text('مسدد بالكامل'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'overdue',
                                            child: Text('متأخر'),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() => _invoiceStatusFilter = v);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'بحث برقم الفاتورة...',
                                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                                    isDense: true,
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _invoiceSearchQuery = v.trim()),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: filteredInvoices.isEmpty
                              ? const Center(
                                  child: Text(
                                    'لا توجد فواتير مسجلة لهذا الطالب تطابق الفلتر.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: filteredInvoices.length,
                                  separatorBuilder: (ctx, i) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final inv = filteredInvoices[i];
                                    final isUnpaid = inv.status != 'paid';
                                    final remaining = ((inv.totalMinor -
                                                inv.amountPaidMinor) /
                                            100)
                                        .clamp(0, double.infinity);

                                    return PortalListCard(
                                      icon: Icons.receipt_long_rounded,
                                      accentColor: isUnpaid
                                          ? Colors.orange
                                          : Colors.green,
                                      title: 'فاتورة #${inv.invoiceNumber}',
                                      subtitle:
                                          'الإجمالي: ${(inv.totalMinor / 100).toStringAsFixed(0)} ج.م | المسدد: ${(inv.amountPaidMinor / 100).toStringAsFixed(0)} ج.م\nالمتبقي: ${remaining.toStringAsFixed(0)} ج.م | الحالة: ${_statusInArabic(inv.status)}',
                                      trailing: [
                                        if (isUnpaid)
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _showRecordPaymentDialog(inv),
                                            icon: const Icon(
                                              Icons.payments_rounded,
                                              size: 16,
                                            ),
                                            label: const Text('تحصيل سداد'),
                                          )
                                        else
                                          const PortalStatusChip(
                                            status: 'settled',
                                          ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                    // Tab 5: Receipts
                    Column(
                      children: [
                        if (_students.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<Student>(
                              initialValue: _selectedStudent,
                              decoration: const InputDecoration(
                                labelText: 'عرض إيصالات الطالب',
                                prefixIcon: Icon(Icons.person_rounded),
                                isDense: true,
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
                          ),
                        Expanded(
                          child: _receipts.isEmpty
                              ? const Center(
                                  child: Text(
                                    'لم يتم إصدار إيصالات دفع لهذا الطالب حتى الآن.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _receipts.length,
                                  separatorBuilder: (ctx, i) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final rec = _receipts[i];
                                    final receiptLabel =
                                        rec.receiptNumber.isEmpty
                                            ? '#${_shortId(rec.id)}'
                                            : rec.receiptNumber;
                                    return PortalListCard(
                                      icon: Icons.receipt_rounded,
                                      accentColor: AppColors.adminRole,
                                      title: 'إيصال تحصيل $receiptLabel',
                                      subtitle:
                                          'المبلغ المسدد: ${(rec.amountMinor / 100).toStringAsFixed(0)} ج.م\nتاريخ السداد: ${rec.issuedAt.year}/${rec.issuedAt.month.toString().padLeft(2, "0")}/${rec.issuedAt.day.toString().padLeft(2, "0")}',
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                    // Tab 6: Adjustment Requests
                    _adjustmentRequests.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد طلبات خصم أو إعفاء معلقة حالياً.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _adjustmentRequests.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final req = _adjustmentRequests[i];
                              final isPending = req.status == 'pending';
                              return PortalListCard(
                                icon: req.adjustmentType == 'exemption'
                                    ? Icons.volunteer_activism_rounded
                                    : Icons.percent_rounded,
                                accentColor: isPending
                                    ? Colors.orange
                                    : AppColors.adminRole,
                                title: '${req.studentName} - ${req.groupName}',
                                subtitle:
                                    'المعلم: ${req.teacherName}\nالسعر الأصلي: ${_money(req.originalPriceMinor)} | الخصم: ${_money(req.requestedDiscountMinor)} | النهائي: ${_money(req.requestedFinalPriceMinor)}${req.reason.isEmpty ? '' : '\nالسبب: ${req.reason}'}',
                                trailing: [
                                  PortalStatusChip(status: req.status),
                                  if (isPending)
                                    IconButton.filledTonal(
                                      tooltip: 'رفض',
                                      onPressed: () =>
                                          _decideAdjustment(req, false),
                                      icon: const Icon(Icons.close),
                                    ),
                                  if (isPending)
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _decideAdjustment(req, true),
                                      icon: const Icon(Icons.check),
                                      label: const Text('موافقة'),
                                    ),
                                ],
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
