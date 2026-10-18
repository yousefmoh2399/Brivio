import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/digital_cash_receipt_dialog.dart';

class TeacherSettlementScreen extends StatefulWidget {
  final List<Teacher>? initialTeachers;
  final List<GroupEntity>? initialGroups;
  final Teacher? initialSelectedTeacher;
  final GroupEntity? initialSelectedGroup;
  final String? initialCenterName;

  const TeacherSettlementScreen({
    super.key,
    this.initialTeachers,
    this.initialGroups,
    this.initialSelectedTeacher,
    this.initialSelectedGroup,
    this.initialCenterName,
  });

  @override
  State<TeacherSettlementScreen> createState() => _TeacherSettlementScreenState();
}

class _TeacherSettlementScreenState extends State<TeacherSettlementScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseGroupRepository _groupRepo;

  List<Teacher> _teachers = [];
  Teacher? _selectedTeacher;
  List<GroupEntity> _allGroups = [];
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;

  final _studentCountCtrl = TextEditingController(text: '0');
  final _sessionPriceCtrl = TextEditingController(text: '0');
  final _teacherPercentCtrl = TextEditingController(text: '70');
  final _centerPercentCtrl = TextEditingController(text: '30');
  final _deductionsCtrl = TextEditingController(text: '0');
  final _deductionReasonCtrl = TextEditingController();

  // Booklet / Bookstore state
  bool _includeBooklets = true;
  bool _isLoadingBooklets = false;
  int _bookletsSold = 0;
  double _bookletRevenue = 0.0;
  List<Map<String, dynamic>> _bookletDetails = [];
  final _bookletTeacherPercentCtrl = TextEditingController(text: '100');
  final _bookletCenterCostCtrl = TextEditingController(text: '0');

  // Group Financial Overview details
  final Map<String, Map<String, dynamic>> _groupFinancials = {};
  int _groupPaidStudents = 0;
  int _groupTotalStudents = 0;
  double _groupPaidAmount = 0.0;
  double _groupTotalAmount = 0.0;
  double _groupRemainingAmount = 0.0;

  bool _isLoading = true;
  bool _isSettling = false;
  String _centerName = 'المركز التعليمي';
  String? _centerId;

  @override
  void initState() {
    super.initState();
    if (widget.initialCenterName != null) {
      _centerName = widget.initialCenterName!;
    }
    if (widget.initialTeachers != null || widget.initialGroups != null) {
      _teachers = widget.initialTeachers ?? [];
      _allGroups = widget.initialGroups ?? [];
      _selectedTeacher = widget.initialSelectedTeacher ??
          (_teachers.isNotEmpty ? _teachers.first : null);
      _groups = _allGroups
          .where((g) =>
              _selectedTeacher == null ||
              g.teacherId == _selectedTeacher!.id ||
              (_selectedTeacher!.profileId.isNotEmpty &&
                  g.teacherId == _selectedTeacher!.profileId))
          .toList();
      if (_groups.isEmpty) _groups = _allGroups;
      _selectedGroup = widget.initialSelectedGroup ??
          (_groups.isNotEmpty ? _groups.first : null);
      _studentCountCtrl.text = '25';
      _sessionPriceCtrl.text = '75';
      _isLoading = false;
    } else {
      try {
        final wrapper = SupabaseClientWrapper(Supabase.instance.client);
        _teacherRepo = SupabaseTeacherRepository(wrapper);
        _groupRepo = SupabaseGroupRepository(wrapper);
        _loadInitialData();
      } catch (e) {
        debugPrint('Supabase init failed in TeacherSettlementScreen: $e');
        _isLoading = false;
      }
    }
  }

  @override
  void dispose() {
    _studentCountCtrl.dispose();
    _sessionPriceCtrl.dispose();
    _teacherPercentCtrl.dispose();
    _centerPercentCtrl.dispose();
    _deductionsCtrl.dispose();
    _deductionReasonCtrl.dispose();
    _bookletTeacherPercentCtrl.dispose();
    _bookletCenterCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTeacherChanged(Teacher? t) async {
    setState(() {
      _selectedTeacher = t;
      _groupFinancials.clear();
      _bookletsSold = 0;
      _bookletRevenue = 0.0;
      _bookletDetails.clear();
    });

    if (t == null) {
      setState(() {
        _groups = _allGroups;
        _selectedGroup = _groups.isNotEmpty ? _groups.first : null;
      });
      return;
    }

    // 1. Fetch RPC get_teacher_financial_overview
    final client = Supabase.instance.client;
    final List<GroupEntity> matchedGroups = _allGroups.where(
      (g) => g.teacherId == t.id || (t.profileId.isNotEmpty && g.teacherId == t.profileId),
    ).toList();

    try {
      final res = await client.rpc(
        'get_teacher_financial_overview',
        params: {'p_teacher_id': t.id},
      );
      if (res is List) {
        for (final row in res) {
          if (row is Map) {
            final gMap = Map<String, dynamic>.from(row);
            final gId = gMap['group_id']?.toString() ?? '';
            if (gId.isNotEmpty) {
              _groupFinancials[gId] = gMap;

              // If group is not in matchedGroups, synthesize or find it
              final existingIndex = matchedGroups.indexWhere((g) => g.id == gId);
              if (existingIndex == -1) {
                final inAll = _allGroups.where((g) => g.id == gId).firstOrNull;
                if (inAll != null) {
                  matchedGroups.add(inAll);
                } else {
                  matchedGroups.add(GroupEntity(
                    id: gId,
                    name: gMap['group_name']?.toString() ?? 'مجموعة',
                    code: gMap['group_code']?.toString() ?? '',
                    subjectId: '',
                    branchId: '',
                    teacherId: t.id,
                    maxCapacity: 50,
                    status: 'active',
                  ));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting teacher financial overview: $e');
    }

    final effectiveGroups = matchedGroups.isNotEmpty ? matchedGroups : _allGroups;
    final firstGroup = effectiveGroups.isNotEmpty ? effectiveGroups.first : null;

    if (mounted) {
      setState(() {
        _groups = effectiveGroups;
        _selectedGroup = firstGroup;
      });
    }

    // 2. Load group details
    if (firstGroup != null) {
      await _updateGroupFinancialDetails(firstGroup.id);
    }

    // 3. Load teacher booklet sales
    await _loadTeacherBookletSales(t);
  }

  Future<void> _updateGroupFinancialDetails(String groupId) async {
    int paidStudents = 0;
    int totalStudents = 0;
    double paidAmount = 0.0;
    double totalAmount = 0.0;
    double remainingAmount = 0.0;
    double detectedSessionPrice = 0.0;

    // Check pre-loaded RPC data
    if (_groupFinancials.containsKey(groupId)) {
      final data = _groupFinancials[groupId]!;
      paidStudents = (data['paid_students'] as num?)?.toInt() ?? 0;
      totalStudents = (data['total_students'] as num?)?.toInt() ?? 0;
      paidAmount = ((data['paid_amount_minor'] as num?)?.toDouble() ?? 0.0) / 100.0;
      totalAmount = ((data['total_amount_minor'] as num?)?.toDouble() ?? 0.0) / 100.0;
      remainingAmount = ((data['remaining_amount_minor'] as num?)?.toDouble() ?? 0.0) / 100.0;

      if (paidStudents > 0 && paidAmount > 0) {
        detectedSessionPrice = paidAmount / paidStudents;
      } else if (totalStudents > 0 && totalAmount > 0) {
        detectedSessionPrice = totalAmount / totalStudents;
      }
    }

    // If still 0 or empty, query directly from Supabase
    if (totalStudents == 0 && paidAmount == 0.0) {
      try {
        final client = Supabase.instance.client;
        final enrollments = await client
            .from('enrollments')
            .select('id, base_price_minor, final_price_minor, payment_status, payment_exempt')
            .eq('group_id', groupId);

        final list = enrollments as List<dynamic>;
        totalStudents = list.length;

        for (final e in list) {
          final fPrice = (e['final_price_minor'] as num?)?.toDouble() ?? 
                         (e['base_price_minor'] as num?)?.toDouble() ?? 0.0;
          final price = fPrice > 0 ? (fPrice / 100.0) : 0.0;
          final isPaid = e['payment_status'] == 'paid' || e['payment_exempt'] == true;
          if (isPaid) {
            paidStudents++;
            paidAmount += price;
          } else {
            remainingAmount += price;
          }
          totalAmount += price;
          if (price > 0 && detectedSessionPrice == 0.0) {
            detectedSessionPrice = price;
          }
        }
      } catch (e) {
        debugPrint('Direct enrollments query error: $e');
      }
    }

    // Also check receipts table for any cash receipts collected for this group/teacher
    if (paidAmount == 0.0 && _selectedTeacher != null) {
      try {
        final client = Supabase.instance.client;
        final receipts = await client
            .from('receipts')
            .select('amount')
            .eq('group_id', groupId);
        if (receipts.isNotEmpty) {
          double rcptSum = 0.0;
          for (final r in receipts) {
            rcptSum += (r['amount'] as num?)?.toDouble() ?? 0.0;
          }
          if (rcptSum > 0) {
            paidAmount = rcptSum;
            if (paidStudents == 0) paidStudents = receipts.length;
          }
        }
      } catch (_) {}
    }

    if (detectedSessionPrice == 0.0) {
      if (paidStudents > 0 && paidAmount > 0) {
        detectedSessionPrice = paidAmount / paidStudents;
      } else {
        detectedSessionPrice = 75.0;
      }
    }

    if (mounted) {
      setState(() {
        _groupPaidStudents = paidStudents;
        _groupTotalStudents = totalStudents;
        _groupPaidAmount = paidAmount;
        _groupTotalAmount = totalAmount;
        _groupRemainingAmount = remainingAmount;
        _studentCountCtrl.text = (paidStudents > 0 ? paidStudents : totalStudents).toString();
        _sessionPriceCtrl.text = detectedSessionPrice.toStringAsFixed(0);
      });
    }
  }

  Future<void> _loadTeacherBookletSales(Teacher t) async {
    setState(() => _isLoadingBooklets = true);

    int totalSold = 0;
    double totalRevenue = 0.0;
    final List<Map<String, dynamic>> details = [];

    // 1. Try RPC get_teacher_bookstore_sales_summary
    try {
      final res = await Supabase.instance.client.rpc(
        'get_teacher_bookstore_sales_summary',
        params: {'p_teacher_id': t.id},
      );
      if (res is List && res.isNotEmpty) {
        final first = Map<String, dynamic>.from(res.first as Map);
        totalSold = (first['total_booklets_sold'] as num?)?.toInt() ?? 0;
        totalRevenue = (first['total_booklet_revenue'] as num?)?.toDouble() ?? 0.0;
        final list = first['booklet_details'] as List? ?? [];
        for (final item in list) {
          if (item is Map) {
            details.add(Map<String, dynamic>.from(item));
          }
        }
      }
    } catch (e) {
      debugPrint('Bookstore RPC error: $e');
    }

    // 2. Query bookstore_sales table directly if RPC yielded 0
    if (totalSold == 0 && totalRevenue == 0.0) {
      try {
        final rows = await Supabase.instance.client
            .from('bookstore_sales')
            .select('items, total_amount, teacher_id')
            .order('created_at', ascending: false);

        for (final row in (rows as List<dynamic>)) {
          final items = row['items'] as List<dynamic>? ?? [];
          final rowTeacherId = row['teacher_id']?.toString();

          for (final it in items) {
            if (it is Map) {
              final itTeacherId = it['teacher_id']?.toString();
              final itTeacherName = it['teacher']?.toString() ?? '';
              final matches = (itTeacherId != null && (itTeacherId == t.id || itTeacherId == t.profileId)) ||
                              (rowTeacherId != null && (rowTeacherId == t.id || rowTeacherId == t.profileId)) ||
                              (itTeacherName.isNotEmpty && (itTeacherName == t.fullName || itTeacherName.contains(t.fullName)));

              if (matches) {
                final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                final lineTotal = (it['total'] as num?)?.toDouble() ?? (qty * price);
                final title = it['title']?.toString() ?? 'مذكرة';

                totalSold += qty;
                totalRevenue += lineTotal;

                final existing = details.indexWhere((d) => d['title'] == title);
                if (existing != -1) {
                  details[existing]['sold_count'] = (details[existing]['sold_count'] as int) + qty;
                  details[existing]['total_revenue'] = (details[existing]['total_revenue'] as double) + lineTotal;
                } else {
                  details.add({
                    'title': title,
                    'price': price,
                    'sold_count': qty,
                    'total_revenue': lineTotal,
                  });
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Direct bookstore_sales query error: $e');
      }
    }

    // 3. Check local SharedPreferences daily sales
    try {
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('pos_daily_sales_$todayKey');
      if (localJson != null && totalSold == 0) {
        final List<dynamic> salesList = jsonDecode(localJson);
        for (final s in salesList) {
          final items = s['items'] as List<dynamic>? ?? [];
          for (final it in items) {
            if (it is Map) {
              final itTeacherId = it['teacher_id']?.toString();
              final itTeacherName = it['teacher']?.toString() ?? '';
              final matches = (itTeacherId != null && (itTeacherId == t.id || itTeacherId == t.profileId)) ||
                              (itTeacherName.isNotEmpty && (itTeacherName == t.fullName || itTeacherName.contains(t.fullName)));
              if (matches) {
                final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                final lineTotal = (it['total'] as num?)?.toDouble() ?? (qty * price);
                final title = it['title']?.toString() ?? 'مذكرة';

                totalSold += qty;
                totalRevenue += lineTotal;
                details.add({
                  'title': title,
                  'price': price,
                  'sold_count': qty,
                  'total_revenue': lineTotal,
                });
              }
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _bookletsSold = totalSold;
        _bookletRevenue = totalRevenue;
        _bookletDetails = details;
        _includeBooklets = totalRevenue > 0;
        _isLoadingBooklets = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final teachersResult = await _teacherRepo.fetchTeachers();
      final teachers = teachersResult.data;
      final groups = await _groupRepo.fetchGroups(status: 'active');

      String? centerId;
      String resolvedCenterName = _centerName;
      try {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          final p = await client.from('profiles').select('center_id').eq('id', user.id).maybeSingle();
          if (p != null && p['center_id'] != null) {
            centerId = p['center_id'].toString();
            final cRes = await client.from('educational_centers').select('name').eq('id', centerId).maybeSingle();
            if (cRes != null && cRes['name'] != null && (cRes['name'] as String).isNotEmpty) {
              resolvedCenterName = cRes['name'] as String;
            }
          }
        }
      } catch (_) {}

      final initialTeacher = teachers.isNotEmpty ? teachers.first : null;

      if (mounted) {
        setState(() {
          _centerId = centerId;
          _centerName = resolvedCenterName;
          _teachers = teachers;
          _allGroups = groups;
          _isLoading = false;
        });
        if (initialTeacher != null) {
          await _onTeacherChanged(initialTeacher);
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

  double get _bookletTeacherPercent => double.tryParse(_bookletTeacherPercentCtrl.text) ?? 100.0;
  double get _bookletCenterCost => double.tryParse(_bookletCenterCostCtrl.text) ?? 0.0;

  // Revenue breakdown
  double get _sessionRevenue => _studentCount * _sessionPrice;
  double get _sessionTeacherShare => _sessionRevenue * (_teacherPercent / 100.0);
  double get _sessionCenterShare => _sessionRevenue * (_centerPercent / 100.0);

  double get _effectiveBookletRevenue => _includeBooklets ? _bookletRevenue : 0.0;
  double get _bookletTeacherShare => _includeBooklets
      ? ((_bookletRevenue * (_bookletTeacherPercent / 100.0)) - _bookletCenterCost).clamp(0.0, double.infinity)
      : 0.0;
  double get _bookletCenterShare => _includeBooklets
      ? (_bookletRevenue - _bookletTeacherShare).clamp(0.0, double.infinity)
      : 0.0;

  double get _totalRevenue => _sessionRevenue + _effectiveBookletRevenue;
  double get _grossTeacherShare => _sessionTeacherShare + _bookletTeacherShare;
  double get _grossCenterShare => _sessionCenterShare + _bookletCenterShare;
  double get _netTeacherPayout => (_grossTeacherShare - _deductions).clamp(0.0, double.infinity);
  double get _netCenterProfit => _grossCenterShare + _deductions;

  Future<void> _recordSettlement() async {
    if (_selectedTeacher == null) return;

    setState(() => _isSettling = true);

    try {
      final client = Supabase.instance.client;
      final txRef = 'TCH-PAY-${DateTime.now().millisecondsSinceEpoch}';
      await client.from('payment_transactions').insert({
        'provider_transaction_id': txRef,
        'amount_minor': (_netTeacherPayout * 100).toInt(),
        'currency': 'EGP',
        'provider': 'cash',
        'status': 'succeeded',
        'transaction_type': 'payment',
        if (_centerId != null) 'center_id': _centerId,
        'metadata': {
          'teacher_id': _selectedTeacher!.id,
          'teacher_name': _selectedTeacher!.fullName,
          'group_id': _selectedGroup?.id,
          'group_name': _selectedGroup?.name,
          'session_revenue': _sessionRevenue,
          'booklet_revenue': _includeBooklets ? _bookletRevenue : 0.0,
          'booklets_sold': _includeBooklets ? _bookletsSold : 0,
          'net_payout': _netTeacherPayout,
          'deductions': _deductions,
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
      centerName: _centerName,
      receiptNumber: receiptNum,
      dateStr:
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
      recipientName: _selectedTeacher!.fullName,
      groupName: _selectedGroup?.name ?? 'المجموعة الدراسية',
      amount: _netTeacherPayout,
      paymentPurpose: _includeBooklets && _bookletsSold > 0
          ? 'تصفية أرباح الحصة ومبيعات الملازم - نقداً بالخزينة'
          : 'تصفية أرباح الحصة - نقداً بالخزينة',
      parentOrTeacherPhone: _selectedTeacher?.phoneNumber,
      studentCount: _studentCount,
      sessionPrice: _sessionPrice,
      totalRevenue: _totalRevenue,
      teacherPercent: _teacherPercent,
      centerShare: _netCenterProfit,
      deductions: _deductions,
      deductionReason: _deductionReasonCtrl.text,
      bookletsSold: _includeBooklets ? _bookletsSold : 0,
      bookletRevenue: _includeBooklets ? _bookletRevenue : 0.0,
    );
  }

  void _shareReceipt() {
    final bookletText = _includeBooklets && _bookletsSold > 0
        ? '\n📚 مبيعات الملازم: $_bookletsSold نسخة بقيمة ${_bookletRevenue.toStringAsFixed(1)} ج.م'
        : '';
    final text = '''
🧾 *إيصال تصفية حساب حصة مدرس*
🏫 *$_centerName*
━━━━━━━━━━━━━━━━━━
👤 المدرس: *${_selectedTeacher?.fullName ?? ''}*
📚 المجموعة: *${_selectedGroup?.name ?? ''}*
📅 التاريخ: ${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}

👥 عدد الطلاب الحاضرين: *$_studentCount طالب*
💵 سعر الحصة للطالب: *$_sessionPrice ج.م*
💰 إيراد الحصة الدراسية: *${_sessionRevenue.toStringAsFixed(1)} ج.م*$bookletText
💰 إجمالي الدخل الكلي: *${_totalRevenue.toStringAsFixed(1)} ج.م*
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

  void _applySplitPreset(double teacherP, double centerP) {
    setState(() {
      _teacherPercentCtrl.text = teacherP.toStringAsFixed(0);
      _centerPercentCtrl.text = centerP.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: const Text(
            'حاسبة وتصفية أرباح المدرسين والسنتر',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Right/Primary Column (Inputs & Selections) in RTL
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildExecutiveHero(isDark),
                                        const SizedBox(height: 16),
                                        _buildTeacherAndGroupSelector(isDark),
                                        const SizedBox(height: 16),
                                        _buildInputsCard(isDark),
                                        const SizedBox(height: 16),
                                        _buildBookletSalesCard(isDark),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Left Column (Executive Summary & Action Buttons)
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildSummaryCard(isDark),
                                        const SizedBox(height: 16),
                                        _buildActionButtons(isDark, isWide),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildExecutiveHero(isDark),
                                  const SizedBox(height: 16),
                                  _buildTeacherAndGroupSelector(isDark),
                                  const SizedBox(height: 16),
                                  _buildInputsCard(isDark),
                                  const SizedBox(height: 16),
                                  _buildBookletSalesCard(isDark),
                                  const SizedBox(height: 16),
                                  _buildSummaryCard(isDark),
                                  const SizedBox(height: 20),
                                  _buildActionButtons(isDark, isWide),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildExecutiveHero(bool isDark) {
    final teacherName = _selectedTeacher?.fullName ?? 'لم يُحدد مدرس';
    final groupName = _selectedGroup?.name ?? 'الحصة العامة';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Info Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final avatarAndInfo = Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: const Icon(Icons.school_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _centerName,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          teacherName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final groupBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded, color: Colors.cyanAccent, size: 14),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (constraints.maxWidth - 60).clamp(60.0, 400.0),
                      ),
                      child: Text(
                        groupName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatarAndInfo,
                    const SizedBox(height: 10),
                    groupBadge,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: avatarAndInfo),
                  const SizedBox(width: 8),
                  groupBadge,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Main Net Payout Card Highlight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_rounded, color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'صافي مستحق المدرس (للتسليم)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_netTeacherPayout.toStringAsFixed(1)} ج.م',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'جاهز للصرف ✨',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // KPI Mini Metrics
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildHeroKpiPill(
                icon: Icons.account_balance_wallet_rounded,
                label: 'إيراد كلي',
                value: '${_totalRevenue.toStringAsFixed(0)} ج.م',
                color: Colors.amber,
              ),
              _buildHeroKpiPill(
                icon: Icons.domain_rounded,
                label: 'حصة السنتر',
                value: '${_netCenterProfit.toStringAsFixed(0)} ج.م',
                color: Colors.cyanAccent,
              ),
              _buildHeroKpiPill(
                icon: Icons.savings_rounded,
                label: 'خزينة محصلة',
                value: '${_groupPaidAmount.toStringAsFixed(0)} ج.م',
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroKpiPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherAndGroupSelector(bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'بيانات المدرس والمجموعة',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;
                final teacherField = DropdownButtonFormField<Teacher>(
                  // ignore: deprecated_member_use
                  value: _teachers.contains(_selectedTeacher) ? _selectedTeacher : null,
                  isExpanded: true,
                  hint: Text(_teachers.isEmpty ? 'لا يوجد مدرسين مسجلين بالسنتر' : 'اختر المدرس'),
                  decoration: InputDecoration(
                    labelText: 'المدرس',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  items: _teachers.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.fullName, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (t) async => await _onTeacherChanged(t),
                );

                final groupField = DropdownButtonFormField<GroupEntity>(
                  // ignore: deprecated_member_use
                  value: _groups.contains(_selectedGroup) ? _selectedGroup : null,
                  isExpanded: true,
                  hint: Text(_groups.isEmpty ? 'لا توجد مجموعات نشطة' : 'اختر المجموعة'),
                  decoration: InputDecoration(
                    labelText: 'المجموعة / الحصة',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.groups_outlined),
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
                      _updateGroupFinancialDetails(g.id);
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
            if (_selectedGroup != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _groupPaidAmount > 0
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _groupPaidAmount > 0
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _groupPaidAmount > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: _groupPaidAmount > 0 ? Colors.green.shade700 : Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _groupPaidAmount > 0
                            ? 'المحصل الفعلي المسدد: ${_groupPaidAmount.toStringAsFixed(1)} ج.م من إجمالي ${_groupTotalAmount.toStringAsFixed(1)} ج.م (من $_groupPaidStudents طالب مسدد) • المتبقي والآجل: ${_groupRemainingAmount.toStringAsFixed(1)} ج.م'
                            : (_groupTotalStudents > 0
                                ? 'إجمالي الطلاب المسجلين: $_groupTotalStudents طالب • لا توجد مبالغ مسددة بالخزينة حتى الآن'
                                : 'لم يتم تسجيل اشتراكات مسددة لهذه المجموعة بعد'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _groupPaidAmount > 0 ? Colors.green.shade900 : Colors.amber.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputsCard(bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'معايير ونسب الحصة',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Split Percentage Presets
            const Text(
              'توزيع النسب المئوية السريع:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip('70% مدرس / 30% سنتر', 70, 30),
                  const SizedBox(width: 8),
                  _buildPresetChip('75% مدرس / 25% سنتر', 75, 25),
                  const SizedBox(width: 8),
                  _buildPresetChip('80% مدرس / 20% سنتر', 80, 20),
                  const SizedBox(width: 8),
                  _buildPresetChip('60% مدرس / 40% سنتر', 60, 40),
                  const SizedBox(width: 8),
                  _buildPresetChip('مناصفة 50% / 50%', 50, 50),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Student count & price
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final countField = TextField(
                  controller: _studentCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'عدد الطلاب الحاضرين',
                    suffixText: 'طالب',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.people_alt_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                );

                final priceField = TextField(
                  controller: _sessionPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر الحصة للطالب',
                    suffixText: 'ج.م',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      countField,
                      const SizedBox(height: 12),
                      priceField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: countField),
                    const SizedBox(width: 12),
                    Expanded(child: priceField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Percentages
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final teacherPercentField = TextField(
                  controller: _teacherPercentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'نسبة المدرس',
                    suffixText: '%',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  onChanged: (val) {
                    final p = double.tryParse(val) ?? 70;
                    _centerPercentCtrl.text = (100 - p).clamp(0, 100).toStringAsFixed(0);
                    setState(() {});
                  },
                );

                final centerPercentField = TextField(
                  controller: _centerPercentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'نسبة السنتر',
                    suffixText: '%',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.apartment_rounded),
                  ),
                  onChanged: (val) {
                    final p = double.tryParse(val) ?? 30;
                    _teacherPercentCtrl.text = (100 - p).clamp(0, 100).toStringAsFixed(0);
                    setState(() {});
                  },
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      teacherPercentField,
                      const SizedBox(height: 12),
                      centerPercentField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: teacherPercentField),
                    const SizedBox(width: 12),
                    Expanded(child: centerPercentField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Deductions
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final deductionsField = TextField(
                  controller: _deductionsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'خصومات ومصاريف',
                    suffixText: 'ج.م',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                );

                final reasonField = TextField(
                  controller: _deductionReasonCtrl,
                  decoration: InputDecoration(
                    labelText: 'سبب الخصم (ملازم / تصوير)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      deductionsField,
                      const SizedBox(height: 12),
                      reasonField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 2, child: deductionsField),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: reasonField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double teacherP, double centerP) {
    final isSelected = (_teacherPercent == teacherP && _centerPercent == centerP);
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
      ),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : null,
      ),
      onPressed: () => _applySplitPreset(teacherP, centerP),
    );
  }

  Widget _buildBookletSalesCard(bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مبيعات المذكرات والملازم الدراسية 📚',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _selectedTeacher != null
                            ? 'الملازم المربوطة بالأستاذ ${_selectedTeacher!.fullName}'
                            : 'اختر المدرس لعرض مبيعات ملازمه',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _includeBooklets,
                  activeThumbColor: Colors.indigo,
                  onChanged: (val) {
                    setState(() => _includeBooklets = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isLoadingBooklets)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_bookletsSold == 0 && _bookletDetails.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لا توجد مبيعات ملازم مسجلة لهذا المدرس حتى الآن.\nعند بيع ملازم من شاشة (المخزن ونقطة البيع POS) مربوطة بالمدرس ستظهر هنا تلقائياً.',
                        style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Metrics LayoutBuilder
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 360;
                  if (isCompact) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الكمية المباعة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '$_bookletsSold نسخة',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('إيراد المبيعات:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '${_bookletRevenue.toStringAsFixed(1)} ج.م',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('صافي مستحق المدرس:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '${_bookletTeacherShare.toStringAsFixed(1)} ج.م',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('الكمية المباعة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                '$_bookletsSold نسخة',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 30, width: 1, color: Colors.indigo.withValues(alpha: 0.2)),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('إجمالي إيراد المبيعات', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                '${_bookletRevenue.toStringAsFixed(1)} ج.م',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 30, width: 1, color: Colors.indigo.withValues(alpha: 0.2)),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('مستحق المدرس', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                '${_bookletTeacherShare.toStringAsFixed(1)} ج.م',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Inputs for Booklet share & printing cost
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;
                  final bookletPercentField = TextField(
                    controller: _bookletTeacherPercentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'نسبة المدرس من الملازم',
                      suffixText: '%',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  );

                  final bookletCostField = TextField(
                    controller: _bookletCenterCostCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'تكلفة الطباعة / السنتر',
                      suffixText: 'ج.م',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        bookletPercentField,
                        const SizedBox(height: 10),
                        bookletCostField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: bookletPercentField),
                      const SizedBox(width: 12),
                      Expanded(child: bookletCostField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Details List of sold items
              if (_bookletDetails.isNotEmpty) ...[
                const Text(
                  'تفاصيل الملازم المباعة:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ..._bookletDetails.map((b) {
                  final title = b['title']?.toString() ?? 'ملزمة';
                  final qty = (b['sold_count'] as num?)?.toInt() ?? 0;
                  final price = (b['price'] as num?)?.toDouble() ?? 0.0;
                  final lineTotal = (b['total_revenue'] as num?)?.toDouble() ?? (qty * price);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• $title ($qty نسخة × $price ج.م)',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${lineTotal.toStringAsFixed(1)} ج.م',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (!_includeBooklets) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ تم إيقاف تضمين أرباح الملازم في هذه التصفية.',
                    style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'الملخص المالي للتصفية',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'إيراد الحصة الدراسية:',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_sessionRevenue.toStringAsFixed(1)} ج.م',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_includeBooklets && _bookletRevenue > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'إيراد مبيعات الملازم والمذكرات:',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_bookletRevenue.toStringAsFixed(1)} ج.م',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'إجمالي الدخل الكلي:',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_totalRevenue.toStringAsFixed(1)} ج.م',
                style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 26),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_rounded, color: Colors.greenAccent, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'صافي مستحق المدرس الكلي:',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_includeBooklets && _bookletTeacherShare > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 24, top: 2),
                        child: Text(
                          '(حصة الحصة: ${_sessionTeacherShare.toStringAsFixed(1)} + الملازم: ${_bookletTeacherShare.toStringAsFixed(1)})',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_netTeacherPayout.toStringAsFixed(1)} ج.م',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.apartment_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'صافي أرباح السنتر الكلي:',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_includeBooklets && _bookletCenterShare > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 24, top: 2),
                        child: Text(
                          '(حصة الحصة: ${_sessionCenterShare.toStringAsFixed(1)} + الملازم: ${_bookletCenterShare.toStringAsFixed(1)})',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_netCenterProfit.toStringAsFixed(1)} ج.م',
                style: const TextStyle(color: AppColors.primary, fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_deductions > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '* تم خصم $_deductions ج.م (${_deductionReasonCtrl.text}) من حصة المدرس لصالح السنتر.',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            final printBtn = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _showDigitalReceiptModal,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('معاينة وطباعة الإيصال'),
            );

            final shareBtn = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _shareReceipt,
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة نص الإيصال'),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  printBtn,
                  const SizedBox(height: 8),
                  shareBtn,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: printBtn),
                const SizedBox(width: 10),
                Expanded(child: shareBtn),
              ],
            );
          },
        ),
      ],
    );
  }
}

