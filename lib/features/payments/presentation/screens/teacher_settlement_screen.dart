import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/digital_cash_receipt_dialog.dart';

class TeacherSettlementScreen extends StatefulWidget {
  const TeacherSettlementScreen({super.key});

  @override
  State<TeacherSettlementScreen> createState() => _TeacherSettlementScreenState();
}

class _TeacherSettlementScreenState extends State<TeacherSettlementScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseStudentRepository _studentRepo;

  List<Teacher> _teachers = [];
  Teacher? _selectedTeacher;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;

  final _studentCountCtrl = TextEditingController(text: '30');
  final _sessionPriceCtrl = TextEditingController(text: '60');
  final _teacherPercentCtrl = TextEditingController(text: '70');
  final _centerPercentCtrl = TextEditingController(text: '30');
  final _deductionsCtrl = TextEditingController(text: '50'); // e.g. photocopies
  final _deductionReasonCtrl = TextEditingController(text: 'ملازم وتصوير ورق');

  bool _isLoading = true;
  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _loadInitialData();
  }

  @override
  void dispose() {
    _studentCountCtrl.dispose();
    _sessionPriceCtrl.dispose();
    _teacherPercentCtrl.dispose();
    _centerPercentCtrl.dispose();
    _deductionsCtrl.dispose();
    _deductionReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateStudentCountForGroup(String groupId) async {
    try {
      final students = await _studentRepo.fetchStudentsForGroup(groupId);
      if (students.isNotEmpty && mounted) {
        setState(() {
          _studentCountCtrl.text = students.length.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final teachersResult = await _teacherRepo.fetchTeachers();
      final teachers = teachersResult.data;
      final groups = await _groupRepo.fetchGroups(status: 'active');

      if (mounted) {
        setState(() {
          _teachers = teachers;
          _selectedTeacher = teachers.isNotEmpty ? teachers.first : null;
          _groups = groups;
          _selectedGroup = groups.isNotEmpty ? groups.first : null;
          _isLoading = false;
        });
        if (groups.isNotEmpty) {
          _updateStudentCountForGroup(groups.first.id);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Calculations
  int get _studentCount => int.tryParse(_studentCountCtrl.text) ?? 0;
  double get _sessionPrice => double.tryParse(_sessionPriceCtrl.text) ?? 0.0;
  double get _teacherPercent => double.tryParse(_teacherPercentCtrl.text) ?? 70.0;
  double get _centerPercent => double.tryParse(_centerPercentCtrl.text) ?? 30.0;
  double get _deductions => double.tryParse(_deductionsCtrl.text) ?? 0.0;

  double get _totalRevenue => _studentCount * _sessionPrice;
  double get _grossTeacherShare => _totalRevenue * (_teacherPercent / 100);
  double get _grossCenterShare => _totalRevenue * (_centerPercent / 100);
  double get _netTeacherPayout => (_grossTeacherShare - _deductions).clamp(0, double.infinity);
  double get _netCenterProfit => _grossCenterShare + _deductions;

  Future<void> _recordSettlement() async {
    if (_selectedTeacher == null) return;

    setState(() => _isSettling = true);

    try {
      final client = Supabase.instance.client;
      await client.from('payment_transactions').insert({
        'amount': _netTeacherPayout,
        'direction': 'payout',
        'provider': 'cash',
        'status': 'settled',
        'metadata': {
          'type': 'teacher_settlement',
          'teacher_id': _selectedTeacher!.id,
          'teacher_name': _selectedTeacher!.fullName,
          'group_name': _selectedGroup?.name ?? '',
          'students_count': _studentCount,
          'session_price': _sessionPrice,
          'total_revenue': _totalRevenue,
          'teacher_share': _netTeacherPayout,
          'center_share': _netCenterProfit,
          'deductions': _deductions,
          'deduction_reason': _deductionReasonCtrl.text,
          'settled_at': DateTime.now().toIso8601String(),
        },
      });

      if (!mounted) return;

      setState(() => _isSettling = false);

      _showDigitalReceiptModal();
    } catch (e) {
      if (mounted) {
        setState(() => _isSettling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في توثيق التصفية: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDigitalReceiptModal() {
    if (_selectedTeacher == null) return;
    final receiptNum = 'TCH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    DigitalCashReceiptDialog.show(
      context: context,
      receiptType: ReceiptType.teacherSettlement,
      centerName: 'السنتر التعليمي',
      receiptNumber: receiptNum,
      dateStr:
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
      recipientName: _selectedTeacher!.fullName,
      groupName: _selectedGroup?.name ?? 'المجموعة الدراسية',
      amount: _netTeacherPayout,
      paymentPurpose: 'تصفية أرباح الحصة - نقداً بالخزينة',
      parentOrTeacherPhone: _selectedTeacher?.phoneNumber,
      studentCount: _studentCount,
      sessionPrice: _sessionPrice,
      totalRevenue: _totalRevenue,
      teacherPercent: _teacherPercent,
      centerShare: _netCenterProfit,
      deductions: _deductions,
      deductionReason: _deductionReasonCtrl.text,
    );
  }

  void _shareReceipt() {
    final text = '''
🧾 *إيصال تصفية حساب حصة مدرس*
🏫 *سنتر تعليمي*
━━━━━━━━━━━━━━━━━━
👤 المدرس: *${_selectedTeacher?.fullName ?? ''}*
📚 المجموعة: *${_selectedGroup?.name ?? ''}*
📅 التاريخ: ${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}

👥 عدد الطلاب الحاضرين: *$_studentCount طالب*
💵 سعر الحصة للطالب: *$_sessionPrice ج.م*
💰 إجمالي دخل الحصة: *${_totalRevenue.toStringAsFixed(1)} ج.م*
━━━━━━━━━━━━━━━━━━
📊 نسبة المدرس ($_teacherPercent%): *${_grossTeacherShare.toStringAsFixed(1)} ج.م*
✂️ الاستقطاعات (${_deductionReasonCtrl.text}): *- ${_deductions.toStringAsFixed(1)} ج.م*
━━━━━━━━━━━━━━━━━━
💵 *الصافي المستلم نقداً للمدرس: ${_netTeacherPayout.toStringAsFixed(1)} ج.م*
🏛️ *صافي حصة السنتر: ${_netCenterProfit.toStringAsFixed(1)} ج.م*

تمت التصفية والتسليم بنجاح ✔️
'''.trim();

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ نص الإيصال بالكامل! يمكنك لصقه في واتساب فوراً.'),
        backgroundColor: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حاسبة وتصفية أرباح المدرسين والسنتر'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'طباعة الإيصال PDF',
              onPressed: _showDigitalReceiptModal,
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'نسخ الإيصال',
              onPressed: _shareReceipt,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTeacherAndGroupSelector(),
                    const SizedBox(height: 16),
                    _buildInputsCard(),
                    const SizedBox(height: 16),
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSettling ? null : _recordSettlement,
                      icon: _isSettling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        'صرف وتوثيق التصفية (${_netTeacherPayout.toStringAsFixed(1)} ج.م)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _showDigitalReceiptModal,
                            icon: const Icon(Icons.receipt_long_rounded),
                            label: const Text('معاينة وطباعة الإيصال'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _shareReceipt,
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('مشاركة نص الإيصال'),
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

  Widget _buildTeacherAndGroupSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات المدرس والمجموعة',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;
                final teacherField = DropdownButtonFormField<Teacher>(
                  initialValue: _selectedTeacher,
                  isExpanded: true,
                  hint: Text(_teachers.isEmpty ? 'لا يوجد مدرسين مسجلين بالسنتر' : 'اختر المدرس'),
                  decoration: const InputDecoration(
                    labelText: 'المدرس',
                    border: OutlineInputBorder(),
                  ),
                  items: _teachers.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.fullName, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (t) {
                    setState(() => _selectedTeacher = t);
                  },
                );

                final groupField = DropdownButtonFormField<GroupEntity>(
                  initialValue: _selectedGroup,
                  isExpanded: true,
                  hint: Text(_groups.isEmpty ? 'لا توجد مجموعات نشطة' : 'اختر المجموعة'),
                  decoration: const InputDecoration(
                    labelText: 'المجموعة / الحصة',
                    border: OutlineInputBorder(),
                  ),
                  items: _groups.map((g) {
                    return DropdownMenuItem(
                      value: g,
                      child: Text(g.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (g) {
                    setState(() => _selectedGroup = g);
                    if (g != null) {
                      _updateStudentCountForGroup(g.id);
                    }
                  },
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      teacherField,
                      const SizedBox(height: 12),
                      groupField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: teacherField),
                    const SizedBox(width: 12),
                    Expanded(child: groupField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معايير ونسب الحصة',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _studentCountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد الطلاب الحاضرين',
                      suffixText: 'طالب',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _sessionPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر الحصة للطالب',
                      suffixText: 'ج.م',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _teacherPercentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة المدرس',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final p = double.tryParse(val) ?? 70;
                      _centerPercentCtrl.text = (100 - p).clamp(0, 100).toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _centerPercentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة السنتر',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final p = double.tryParse(val) ?? 30;
                      _teacherPercentCtrl.text = (100 - p).clamp(0, 100).toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _deductionsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'خصومات ومصاريف',
                      suffixText: 'ج.م',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _deductionReasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'سبب الخصم (ملازم / تصوير)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي إيراد الحصة:', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text(
                '${_totalRevenue.toStringAsFixed(1)} ج.م',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'صافي مستحق المدرس ($_teacherPercent%):',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_netTeacherPayout.toStringAsFixed(1)} ج.م',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'صافي أرباح السنتر ($_centerPercent%):',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_netCenterProfit.toStringAsFixed(1)} ج.م',
                style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_deductions > 0) ...[
            const SizedBox(height: 8),
            Text(
              '* تم خصم $_deductions ج.م (${_deductionReasonCtrl.text}) من حصة المدرس لصالح السنتر.',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
