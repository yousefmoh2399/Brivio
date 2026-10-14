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

  void _showCreatePlanDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String billingType = 'installment';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('إنشاء خطة اشتراك جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الخطة (مثال: الترم الأول رياضيات)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الوصف أو الملاحظات',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: billingType,
                    decoration: const InputDecoration(
                      labelText: 'طريقة المحاسبة',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'installment',
                        child: Text('أقساط مجدولة'),
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الإجمالي (ج.م)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;

                  final nav = Navigator.of(ctx);
                  final amtEgp = int.tryParse(amountCtrl.text);
                  if (amtEgp == null || amtEgp <= 0) return;
                  try {
                    await Supabase.instance.client
                        .from('subscription_plans')
                        .insert({
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'billing_type': billingType,
                          'total_amount_minor': amtEgp * 100,
                          'currency': 'EGP',
                          'installment_count': billingType == 'installment'
                              ? 3
                              : 1,
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
                child: const Text('حفظ الخطة'),
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
        const SnackBar(content: Text('يرجى اختيار طالب نشط أولاً.')),
      );
      return;
    }
    String? selectedPlanId = _plans.isNotEmpty ? _plans.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تسكين اشتراك لطالب'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_plans.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedPlanId,
                    decoration: const InputDecoration(
                      labelText: 'اختر خطة الاشتراك',
                    ),
                    items: _plans
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setStateDialog(() => selectedPlanId = v),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedPlanId == null) return;
                  final nav = Navigator.of(ctx);
                  try {
                    await Supabase.instance.client.rpc(
                      'assign_student_subscription',
                      params: {
                        'p_student_id': selectedStudent.id,
                        'p_plan_id': selectedPlanId,
                      },
                    );
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
                child: const Text('تأكيد التسكين'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecordPaymentDialog(Invoice inv) {
    final amountCtrl = TextEditingController(
      text: (inv.totalMinor / 100).toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'تسجيل سداد نقدي يدوي (${inv.invoiceNumber})',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'مبلغ التحصيل (ج.م)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظات أو رقم مرجعي',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final amtEgp =
                  double.tryParse(amountCtrl.text) ?? (inv.totalMinor / 100);
              try {
                await _paymentRepo.recordManualPayment(
                  invoiceId: inv.id,
                  amountMinor: (amtEgp * 100).round(),
                  paymentMethod: 'cash',
                  notes: notesCtrl.text.trim(),
                );
                nav.pop();
                _loadFinanceData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تسجيل السداد النقدي وإصدار الإيصال بنجاح!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
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
            child: const Text('تأكيد التحصيل'),
          ),
        ],
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
          'notes': inv.status,
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
    return DefaultTabController(
      length: 6,
      child: PortalPageShell(
        title: 'الإدارة المالية والاشتراكات',
        subtitle: 'إدارة خطط الاشتراكات، الفواتير، التحصيلات، وإيصالات السداد.',
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
                emptySubtitle: 'قم بإنشاء خطط اشتراك وتسجيل طلاب للبدء في المعاملات المالية.',
                emptyIcon: Icons.monetization_on,
                onRetry: _loadFinanceData,
                child: TabBarView(
                  children: [
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
                    _plans.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد خطط اشتراك مسجلة حالياً.',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _plans.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final p = _plans[i];
                              final billingTypeLabel = p.billingType == 'installment' ? 'أقساط مجدولة' : 'دفعة واحدة';
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
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_students.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: DropdownButtonFormField<Student>(
                                initialValue: _selectedStudent,
                                decoration: const InputDecoration(
                                  labelText: 'اختر الطالب',
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
                                onChanged: (student) {
                                  if (student == null) return;
                                  setState(() => _selectedStudent = student);
                                  _loadFinanceData();
                                },
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
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                    // Tab 3: Invoices
                    _invoices.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد فواتير مسجلة لهذا الطالب.',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _invoices.length,
                            separatorBuilder: (ctx, i) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final inv = _invoices[i];
                              final isUnpaid = inv.status != 'paid';

                              return PortalListCard(
                                icon: Icons.receipt_long_rounded,
                                accentColor: isUnpaid
                                    ? Colors.orange
                                    : Colors.green,
                                title: 'فاتورة #${inv.invoiceNumber}',
                                subtitle:
                                    'الإجمالي: ${(inv.totalMinor / 100).toStringAsFixed(0)} ج.م | المسدد: ${(inv.amountPaidMinor / 100).toStringAsFixed(0)} ج.م\nالحالة: ${_statusInArabic(inv.status)}',
                                trailing: [
                                  if (isUnpaid)
                                    ElevatedButton(
                                      onPressed: () =>
                                          _showRecordPaymentDialog(inv),
                                      child: const Text('تسجيل سداد'),
                                    )
                                  else
                                    PortalStatusChip(status: 'settled'),
                                ],
                              );
                            },
                          ),
                    // Tab 4: Receipts
                    _receipts.isEmpty
                        ? const Center(
                            child: Text(
                              'لم يتم إصدار إيصالات دفع حتى الآن.',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _receipts.length,
                            separatorBuilder: (ctx, i) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final rec = _receipts[i];
                              final receiptLabel = rec.receiptNumber.isEmpty
                                  ? '#${_shortId(rec.id)}'
                                  : rec.receiptNumber;
                              return PortalListCard(
                                icon: Icons.receipt_rounded,
                                accentColor: AppColors.adminRole,
                                title: 'إيصال تحصيل $receiptLabel',
                                subtitle:
                                    'المبلغ المسدد: ${(rec.amountMinor / 100).toStringAsFixed(0)} ج.م\nتاريخ السداد: ${rec.issuedAt.year}/${rec.issuedAt.month}/${rec.issuedAt.day}',
                              );
                            },
                          ),
                    _adjustmentRequests.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد طلبات خصم أو إعفاء معلقة.',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
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
