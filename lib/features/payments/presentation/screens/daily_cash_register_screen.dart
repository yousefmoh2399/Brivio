import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../widgets/digital_cash_receipt_dialog.dart';

/// Screen for Reception Cashiers and Supervisors to Reconcile and Close Daily Cash Register Shifts.
/// Calculates gross receipts, cash payouts, and net drawer balance with banknote counting and PDF export.
class DailyCashRegisterScreen extends StatefulWidget {
  final String? centerName;
  final String? cashierName;

  const DailyCashRegisterScreen({
    super.key,
    this.centerName,
    this.cashierName,
  });

  @override
  State<DailyCashRegisterScreen> createState() => _DailyCashRegisterScreenState();
}

class _DailyCashRegisterScreenState extends State<DailyCashRegisterScreen> {
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'الوردية المسائية';

  String _centerName = 'المركز التعليمي';
  String _cashierName = 'مسؤول الخزينة';
  String? _centerId;

  // Financial aggregates
  double _grossCashReceipts = 0.0;
  int _receiptsCount = 0;
  double _teacherPayouts = 0.0;
  int _payoutsCount = 0;
  double _netExpectedCash = 0.0;

  // Transaction items
  List<Map<String, dynamic>> _transactions = [];

  // Banknotes counter controllers
  final TextEditingController _c200 = TextEditingController(text: '0');
  final TextEditingController _c100 = TextEditingController(text: '0');
  final TextEditingController _c50 = TextEditingController(text: '0');
  final TextEditingController _c20 = TextEditingController(text: '0');
  final TextEditingController _c10 = TextEditingController(text: '0');
  final TextEditingController _cCoins = TextEditingController(text: '0');
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.centerName != null && widget.centerName!.isNotEmpty) {
      _centerName = widget.centerName!;
    }
    if (widget.cashierName != null && widget.cashierName!.isNotEmpty) {
      _cashierName = widget.cashierName!;
    }
    _loadShiftData();
  }

  @override
  void dispose() {
    _c200.dispose();
    _c100.dispose();
    _c50.dispose();
    _c20.dispose();
    _c10.dispose();
    _cCoins.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _actualCountedCash {
    final n200 = (int.tryParse(_c200.text.trim()) ?? 0) * 200.0;
    final n100 = (int.tryParse(_c100.text.trim()) ?? 0) * 100.0;
    final n50 = (int.tryParse(_c50.text.trim()) ?? 0) * 50.0;
    final n20 = (int.tryParse(_c20.text.trim()) ?? 0) * 20.0;
    final n10 = (int.tryParse(_c10.text.trim()) ?? 0) * 10.0;
    final coins = double.tryParse(_cCoins.text.trim()) ?? 0.0;
    return n200 + n100 + n50 + n20 + n10 + coins;
  }

  double get _discrepancy => _actualCountedCash - _netExpectedCash;

  Future<void> _fetchCenterAndCashierInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, center_id')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          final fullName = profile['full_name'] as String?;
          if (fullName != null && fullName.isNotEmpty && widget.cashierName == null) {
            _cashierName = fullName;
          }
          final centerId = profile['center_id'];
          if (centerId != null) {
            _centerId = centerId.toString();
            if (widget.centerName == null) {
              final center = await Supabase.instance.client
                  .from('educational_centers')
                  .select('name')
                  .eq('id', centerId)
                  .maybeSingle();
              if (center != null && center['name'] != null) {
                _centerName = center['name'];
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);

    try {
      await _fetchCenterAndCashierInfo();

      final startOfDayUtc = DateTime.utc(_selectedDate.year, _selectedDate.month, _selectedDate.day).toIso8601String();
      final endOfDayUtc = DateTime.utc(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59, 999).toIso8601String();
      final startOfDayLocal = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toIso8601String();
      final endOfDayLocal = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59).toIso8601String();

      // Fetch today's receipts from Supabase
      List<dynamic> receiptsRes = [];
      try {
        var receiptsQuery = Supabase.instance.client
            .from('receipts')
            .select('id, receipt_number, amount_minor, currency, issued_at, center_id, student:students!left(profiles!left(full_name))');

        if (_centerId != null) {
          receiptsQuery = receiptsQuery.or('center_id.eq.$_centerId,center_id.is.null');
        }

        receiptsRes = await receiptsQuery
            .gte('issued_at', startOfDayUtc)
            .lte('issued_at', endOfDayUtc)
            .order('issued_at', ascending: false)
            .catchError((_) async {
              return await receiptsQuery
                  .gte('issued_at', startOfDayLocal)
                  .lte('issued_at', endOfDayLocal)
                  .order('issued_at', ascending: false);
            });
      } catch (_) {
        var fallbackReceiptsQuery = Supabase.instance.client
            .from('receipts')
            .select('id, receipt_number, amount_minor, currency, issued_at, student:students!left(profiles!left(full_name))');
        receiptsRes = await fallbackReceiptsQuery
            .gte('issued_at', startOfDayUtc)
            .lte('issued_at', endOfDayUtc)
            .order('issued_at', ascending: false)
            .catchError((_) async {
              return await fallbackReceiptsQuery
                  .gte('issued_at', startOfDayLocal)
                  .lte('issued_at', endOfDayLocal)
                  .order('issued_at', ascending: false);
            });
      }

      double grossInflow = 0.0;
      int countInflow = 0;
      final List<Map<String, dynamic>> logs = [];
      final Set<String> seenReceiptNumbers = {};

      for (final r in receiptsRes) {
        final recNum = r['receipt_number']?.toString() ?? r['id'].toString().substring(0, 8);
        if (seenReceiptNumbers.contains(recNum)) continue;
        seenReceiptNumbers.add(recNum);

        double amt = 0.0;
        if (r['amount_minor'] != null) {
          amt = ((r['amount_minor'] as num).toDouble() / 100.0);
        }

        grossInflow += amt;
        countInflow++;
        final studentName = r['student']?['profiles']?['full_name']?.toString() ?? 'طالب نقدي';
        logs.add({
          'type': 'receipt',
          'title': 'إيصال تحصيل نقدية #$recNum • $studentName',
          'amount': amt,
          'time': r['issued_at'] != null
              ? DateFormat('hh:mm a').format(DateTime.parse(r['issued_at']))
              : 'اليوم',
          'date_str': r['issued_at'] != null
              ? DateFormat('yyyy-MM-dd').format(DateTime.parse(r['issued_at']))
              : 'اليوم',
          'receipt_number': recNum,
          'student_name': studentName,
          'is_credit': true,
        });
      }

      // Fetch bookstore POS sales
      try {
        var salesQuery = Supabase.instance.client
            .from('bookstore_sales')
            .select('receipt_number, student_name, total_amount, created_at, center_id');

        if (_centerId != null) {
          salesQuery = salesQuery.or('center_id.eq.$_centerId,center_id.is.null');
        }

        final salesRes = await salesQuery
            .gte('created_at', startOfDayUtc)
            .lte('created_at', endOfDayUtc)
            .order('created_at', ascending: false)
            .catchError((_) async {
              return await salesQuery
                  .gte('created_at', startOfDayLocal)
                  .lte('created_at', endOfDayLocal)
                  .order('created_at', ascending: false);
            });

        for (final s in (salesRes as List<dynamic>)) {
          final recNum = s['receipt_number']?.toString() ?? '';
          if (recNum.isNotEmpty && seenReceiptNumbers.contains(recNum)) continue;
          if (recNum.isNotEmpty) seenReceiptNumbers.add(recNum);

          final amt = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
          grossInflow += amt;
          countInflow++;
          final studentName = s['student_name']?.toString() ?? 'طالب نقدي';
          logs.add({
            'type': 'receipt',
            'title': 'مبيعات مذكرات #$recNum • $studentName',
            'amount': amt,
            'time': s['created_at'] != null
                ? DateFormat('hh:mm a').format(DateTime.parse(s['created_at']))
                : 'اليوم',
            'is_credit': true,
          });
        }
      } catch (_) {}

      // Fetch local persistent POS sales log if not in remote
      try {
        final dateKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        final prefs = await SharedPreferences.getInstance();
        final localSalesJson = prefs.getString('pos_daily_sales_$dateKey');
        if (localSalesJson != null) {
          final localSales = jsonDecode(localSalesJson) as List;
          for (final ls in localSales) {
            final recNum = ls['receipt_number']?.toString() ?? '';
            if (recNum.isNotEmpty && seenReceiptNumbers.contains(recNum)) continue;
            if (recNum.isNotEmpty) seenReceiptNumbers.add(recNum);

            final amt = (ls['total_amount'] as num?)?.toDouble() ?? 0.0;
            grossInflow += amt;
            countInflow++;
            final sName = ls['student_name']?.toString() ?? 'طالب نقدي';
            logs.add({
              'type': 'receipt',
              'title': 'مبيعات مذكرات #$recNum • $sName',
              'amount': amt,
              'time': ls['created_at'] != null
                  ? DateFormat('hh:mm a').format(DateTime.parse(ls['created_at']))
                  : 'اليوم',
              'is_credit': true,
            });
          }
        }
      } catch (_) {}

      // Fetch today's cash refunds or payouts
      double payouts = 0.0;
      int countPayouts = 0;
      try {
        final txRes = await Supabase.instance.client
            .from('payment_transactions')
            .select('id, provider, amount_minor, currency, transaction_type, status, occurred_at')
            .eq('provider', 'cash')
            .gte('occurred_at', startOfDayUtc)
            .lte('occurred_at', endOfDayUtc)
            .order('occurred_at', ascending: false)
            .catchError((_) async {
              return await Supabase.instance.client
                  .from('payment_transactions')
                  .select('id, provider, amount_minor, currency, transaction_type, status, occurred_at')
                  .eq('provider', 'cash')
                  .gte('occurred_at', startOfDayLocal)
                  .lte('occurred_at', endOfDayLocal)
                  .order('occurred_at', ascending: false);
            });

        for (final p in (txRes as List<dynamic>)) {
          final type = p['transaction_type']?.toString();
          final amt = ((p['amount_minor'] as num? ?? 0) / 100.0).toDouble();
          if (type == 'refund') {
            payouts += amt;
            countPayouts++;
            logs.add({
              'type': 'refund',
              'title': 'استرداد / منصرف نقدي بالخزينة',
              'amount': amt,
              'time': p['occurred_at'] != null
                  ? DateFormat('hh:mm a').format(DateTime.parse(p['occurred_at']))
                  : 'اليوم',
              'is_credit': false,
            });
          }
        }
      } catch (_) {}

      final net = grossInflow - payouts;

      if (mounted) {
        setState(() {
          _grossCashReceipts = grossInflow;
          _receiptsCount = countInflow;
          _teacherPayouts = payouts;
          _payoutsCount = countPayouts;
          _netExpectedCash = net;
          _transactions = logs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _grossCashReceipts = 0.0;
          _receiptsCount = 0;
          _teacherPayouts = 0.0;
          _payoutsCount = 0;
          _netExpectedCash = 0.0;
          _transactions = [];
          _isLoading = false;
        });
      }
    }
  }

  void _fillDrawerWithExactNet() {
    int remaining = _netExpectedCash > 0 ? _netExpectedCash.toInt() : 0;
    final c200Count = remaining ~/ 200;
    remaining %= 200;
    final c100Count = remaining ~/ 100;
    remaining %= 100;
    final c50Count = remaining ~/ 50;
    remaining %= 50;
    final c20Count = remaining ~/ 20;
    remaining %= 20;
    final c10Count = remaining ~/ 10;
    final coins = remaining.toDouble();

    setState(() {
      _c200.text = '$c200Count';
      _c100.text = '$c100Count';
      _c50.text = '$c50Count';
      _c20.text = '$c20Count';
      _c10.text = '$c10Count';
      _cCoins.text = coins > 0 ? '$coins' : '0';
    });
  }

  void _clearDrawerCounts() {
    setState(() {
      _c200.text = '0';
      _c100.text = '0';
      _c50.text = '0';
      _c20.text = '0';
      _c10.text = '0';
      _cCoins.text = '0';
    });
  }

  Future<void> _exportClosingPdf({bool printDirectly = false}) async {
    final dateStr = DateFormat('yyyy/MM/dd').format(_selectedDate);
    final service = ReportGeneratorService();

    final denominationsMap = {
      '200': int.tryParse(_c200.text.trim()) ?? 0,
      '100': int.tryParse(_c100.text.trim()) ?? 0,
      '50': int.tryParse(_c50.text.trim()) ?? 0,
      '20': int.tryParse(_c20.text.trim()) ?? 0,
      '10': int.tryParse(_c10.text.trim()) ?? 0,
      'coins': (double.tryParse(_cCoins.text.trim()) ?? 0.0).toInt(),
    };

    try {
      await service.generateDailyCashRegisterClosingPdf(
        centerName: _centerName,
        shiftName: _selectedShift,
        cashierName: _cashierName,
        dateStr: dateStr,
        receiptsCount: _receiptsCount,
        totalGrossCashInflow: _grossCashReceipts,
        totalTeacherPayouts: _teacherPayouts,
        netExpectedCash: _netExpectedCash,
        actualCountedCash: _actualCountedCash,
        discrepancy: _discrepancy,
        notes: _notesCtrl.text.trim(),
        denominationsCount: denominationsMap,
        transactionLog: _transactions,
        printDirectly: printDirectly,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصدير محضر جرد وتقفيل الخزينة اليومية بنجاح 📄'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تصدير محضر التقفيل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final counted = _actualCountedCash;
    final diff = _discrepancy;
    final isMatching = diff.abs() < 0.01 && (counted > 0 || _netExpectedCash == 0);
    final isSurplus = diff > 0.01;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          elevation: 0.5,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جرد وتقفيل الخزينة اليومية',
                style: AppTypography.titleMedium(isDark ? Colors.white : Colors.black87)
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '$_centerName • $_cashierName • ${DateFormat('yyyy/MM/dd').format(_selectedDate)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_rounded, color: AppColors.primary),
              tooltip: 'طباعة فورية لمحضر الجرد',
              onPressed: () => _exportClosingPdf(printDirectly: true),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
              tooltip: 'تصدير PDF',
              onPressed: () => _exportClosingPdf(printDirectly: false),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadShiftData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shift Selector Bar
                      _buildShiftFilterBar(isDark),
                      const SizedBox(height: 16),

                      // Overview Metric Cards
                      _buildMetricCardsGrid(isDark),
                      const SizedBox(height: 18),

                      // Banknotes Counting Calculator Card
                      _buildCashDrawerCalculatorCard(isDark, counted, diff, isMatching, isSurplus),
                      const SizedBox(height: 18),

                      // Transaction Feed & Closing Action
                      _buildTransactionsFeedCard(isDark),
                      const SizedBox(height: 24),

                      // Official Action Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _exportClosingPdf(printDirectly: false),
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('اعتماد وتقفيل الوردية وتصدير محضر الجرد (PDF)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildShiftFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          final dropdown = Row(
            children: [
              const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedShift,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 'الوردية الصباحية',
                      child: Text('الوردية الصباحية', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'الوردية المسائية',
                      child: Text('الوردية المسائية', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'إجمالي اليوم بالكامل',
                      child: Text('إجمالي اليوم بالكامل', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedShift = v);
                  },
                ),
              ),
            ],
          );

          final dateButton = TextButton.icon(
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                setState(() => _selectedDate = d);
                _loadShiftData();
              }
            },
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                dropdown,
                const Divider(height: 8),
                Align(alignment: Alignment.centerLeft, child: dateButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: dropdown),
              const SizedBox(width: 8),
              dateButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCardsGrid(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth > 700 ? 1.4 : 1.35,
          children: [
            _metricCard(
              title: 'إجمالي المقبوضات النقدية',
              value: '${_grossCashReceipts.toStringAsFixed(1)} ج.م',
              subtitle: '$_receiptsCount عملية تحصيل',
              icon: Icons.payments_rounded,
              color: Colors.green,
              isDark: isDark,
            ),
            _metricCard(
              title: 'المنصرفات والاستردادات',
              value: '${_teacherPayouts.toStringAsFixed(1)} ج.م',
              subtitle: '$_payoutsCount عملية منصرفة',
              icon: Icons.assignment_return_rounded,
              color: Colors.orange,
              isDark: isDark,
            ),
            _metricCard(
              title: 'الصافي المطلوب بالدرج',
              value: '${_netExpectedCash.toStringAsFixed(1)} ج.م',
              subtitle: 'مقبوضات - منصرفات',
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.blue,
              isDark: isDark,
            ),
            _metricCard(
              title: 'حالة المطابقة',
              value: _discrepancy.abs() < 0.01 && _actualCountedCash > 0
                  ? 'مطابق تماماً'
                  : (_discrepancy > 0.01
                      ? 'فائض (+${_discrepancy.toStringAsFixed(1)})'
                      : (_actualCountedCash == 0 && _netExpectedCash > 0
                          ? 'بانتظار العد'
                          : 'عجز (${_discrepancy.toStringAsFixed(1)})')),
              subtitle: 'مقارنة الفعلي بالسيستم',
              icon: Icons.price_check_rounded,
              color: _discrepancy.abs() < 0.01 && _actualCountedCash > 0 ? Colors.green : Colors.teal,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _buildCashDrawerCalculatorCard(
    bool isDark,
    double counted,
    double diff,
    bool isMatching,
    bool isSurplus,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حاسبة عد النقدية الفعلية بالدرج',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'سجّل عدد الفئات النقدية بالدرج لمقارنتها مع رصيد النظام',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Discrepancy Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isMatching
                      ? Colors.green.withValues(alpha: 0.15)
                      : (isSurplus ? Colors.blue.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isMatching ? Colors.green : (isSurplus ? Colors.blue : Colors.red),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMatching ? Icons.check_circle_rounded : (isSurplus ? Icons.trending_up : Icons.warning_rounded),
                      size: 13,
                      color: isMatching ? Colors.green : (isSurplus ? Colors.blue : Colors.red),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMatching
                          ? 'مطابق 🎯'
                          : (isSurplus ? '+${diff.toStringAsFixed(1)} ج.م' : '${diff.toStringAsFixed(1)} ج.م'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isMatching ? Colors.green : (isSurplus ? Colors.blue : Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actions row (auto-fill & reset)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.flash_on_rounded, size: 14),
                label: const Text('ملء القيمة المطابقة', style: TextStyle(fontSize: 11)),
                onPressed: _fillDrawerWithExactNet,
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('تصفير العداد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onPressed: _clearDrawerCounts,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Banknote Inputs Grid
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 600;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _denominationField('فئة 200 جنيه', _c200, 200, isWide),
                  _denominationField('فئة 100 جنيه', _c100, 100, isWide),
                  _denominationField('فئة 50 جنيه', _c50, 50, isWide),
                  _denominationField('فئة 20 جنيه', _c20, 20, isWide),
                  _denominationField('فئة 10 جنيه', _c10, 10, isWide),
                  _denominationField('فكة / معدنية', _cCoins, 1, isWide, isAmount: true),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Total Counted Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'إجمالي النقدية المحصية بالدرج فعلياً:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${counted.toStringAsFixed(1)} ج.م',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Notes
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              hintText: 'ملاحظات مسؤول الوردية إن وُجد عجز أو تسليم عهدة...',
              labelText: 'ملاحظات الجرد والتسليم',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _denominationField(
    String label,
    TextEditingController controller,
    int multiplier,
    bool isWide, {
    bool isAmount = false,
  }) {
    final width = isWide ? 170.0 : 150.0;
    final count = int.tryParse(controller.text) ?? 0;
    final subtotal = isAmount ? (double.tryParse(controller.text) ?? 0.0) : (count * multiplier).toDouble();

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              suffixText: isAmount ? 'ج.م' : 'ورقة',
              suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 2),
          Text(
            '= ${subtotal.toStringAsFixed(0)} ج.م',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsFeedCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'حركات النقدية المسجلة خلال اليوم',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_transactions.length} حركة',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'لا توجد حركات نقدية مسجلة لهذا التاريخ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ستظهر المقبوضات وتصفيات الحصص فور تسجيلها بالسنتر',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final tx = _transactions[i];
                final isCredit = tx['is_credit'] == true;
                final amount = tx['amount'] as double? ?? 0.0;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  onTap: isCredit
                      ? () {
                          final recNum = tx['receipt_number']?.toString() ?? 'REC';
                          final studentName = tx['student_name']?.toString() ?? 'طالب نقدي';
                          final dateStr = tx['date_str']?.toString() ?? tx['time']?.toString() ?? 'اليوم';
                          DigitalCashReceiptDialog.show(
                            context: context,
                            receiptType: ReceiptType.studentPayment,
                            centerName: widget.centerName ?? 'منظومة بريفيو التعليمية المتطورة',
                            receiptNumber: recNum,
                            dateStr: dateStr,
                            recipientName: studentName,
                            groupName: 'خزينة التحصيل اليومية',
                            amount: amount,
                            paymentPurpose: tx['title']?.toString() ?? 'تحصيل نقدي معتمد بالخزينة',
                            paymentMethod: 'نقداً بالخزينة (كاش) 💵',
                          );
                        }
                      : null,
                  leading: CircleAvatar(
                    backgroundColor: isCredit
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    child: Icon(
                      isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: isCredit ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    tx['title']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    tx['time']?.toString() ?? '',
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                  trailing: Text(
                    '${isCredit ? '+' : '-'}${amount.toStringAsFixed(1)} ج.م',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.green : Colors.orange,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
