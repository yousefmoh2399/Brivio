import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class ParentFinancialLedgerScreen extends StatefulWidget {
  final String? studentId;
  final String studentName;
  final String studentCode;
  final String parentName;
  final String parentPhone;
  final String groupName;
  final String centerName;
  final double? initialTotalPaid;
  final double? initialTotalRemaining;

  const ParentFinancialLedgerScreen({
    super.key,
    this.studentId,
    this.studentName = 'الطالب',
    this.studentCode = '',
    this.parentName = 'ولي الأمر',
    this.parentPhone = '',
    this.groupName = 'المجموعة الدراسية',
    this.centerName = 'السنتر التعليمي',
    this.initialTotalPaid,
    this.initialTotalRemaining,
  });

  @override
  State<ParentFinancialLedgerScreen> createState() => _ParentFinancialLedgerScreenState();
}

class _ParentFinancialLedgerScreenState extends State<ParentFinancialLedgerScreen> {
  bool _isExporting = false;
  bool _isLoading = false;

  late double _totalPaid;
  late double _totalRemaining;
  List<Map<String, dynamic>> _ledgerRecords = [];

  @override
  void initState() {
    super.initState();
    _totalPaid = widget.initialTotalPaid ?? 0.0;
    _totalRemaining = widget.initialTotalRemaining ?? 0.0;
    if (widget.studentId != null && widget.studentId!.isNotEmpty) {
      _loadRealFinancialData();
    }
  }

  Future<void> _loadRealFinancialData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final receiptsRes = await client
          .from('receipts')
          .select('id, receipt_number, amount_minor, currency, issued_at, notes, invoices(description, title)')
          .eq('student_id', widget.studentId!)
          .order('issued_at', ascending: false);

      final invoicesRes = await client
          .from('invoices')
          .select('id, invoice_number, amount_minor, status, title, description, due_date')
          .eq('student_id', widget.studentId!)
          .order('issued_at', ascending: false);

      double paidSum = 0.0;
      final List<Map<String, dynamic>> records = [];

      for (final r in (receiptsRes as List)) {
        final amount = ((r['amount_minor'] as num?)?.toDouble() ?? 0.0) / 100.0;
        paidSum += amount;
        final issuedAt = DateTime.tryParse(r['issued_at']?.toString() ?? '');
        final dateStr = issuedAt != null
            ? '${issuedAt.year}-${issuedAt.month.toString().padLeft(2, '0')}-${issuedAt.day.toString().padLeft(2, '0')}'
            : '';

        final inv = r['invoices'] as Map<String, dynamic>?;
        final desc = inv?['title']?.toString() ??
            inv?['description']?.toString() ??
            r['notes']?.toString() ??
            'سداد رسوم دراسية معتمدة';

        final recNum = r['receipt_number']?.toString();
        final idStr = r['id']?.toString() ?? '';
        final displayNum = (recNum != null && recNum.isNotEmpty)
            ? recNum
            : (idStr.length >= 8 ? idStr.substring(0, 8).toUpperCase() : 'REC');

        records.add({
          'receipt_number': displayNum,
          'date': dateStr,
          'description': desc,
          'amount': amount,
          'collector_name': 'خزينة السنتر الرسمية',
          'payment_method': 'إيصال معتمد',
          'status': 'مدفوع معتمد',
        });
      }

      double remainingSum = 0.0;
      for (final inv in (invoicesRes as List)) {
        final status = inv['status']?.toString().toLowerCase();
        if (status == 'pending' || status == 'unpaid' || status == 'overdue') {
          final amt = ((inv['amount_minor'] as num?)?.toDouble() ?? 0.0) / 100.0;
          remainingSum += amt;
        }
      }

      if (mounted) {
        setState(() {
          _ledgerRecords = records;
          _totalPaid = paidSum > 0 ? paidSum : (widget.initialTotalPaid ?? 0.0);
          _totalRemaining = remainingSum > 0 ? remainingSum : (widget.initialTotalRemaining ?? 0.0);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_ledgerRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد معاملات مسجلة لتصدير كشف الحساب.')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final reportService = ReportGeneratorService();
      await reportService.generateParentFinancialLedgerPdf(
        centerName: widget.centerName,
        studentName: widget.studentName,
        studentCode: widget.studentCode,
        parentName: widget.parentName,
        parentPhone: widget.parentPhone,
        groupName: widget.groupName,
        totalPaid: _totalPaid,
        totalRemaining: _totalRemaining,
        records: _ledgerRecords,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تصدير كشف الحساب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('كشف الحساب المالي لولي الأمر 💳'),
        actions: [
          IconButton(
            tooltip: 'تصدير كشف حساب PDF معتمد',
            onPressed: _isExporting ? null : _exportPdf,
            icon: _isExporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student & Parent Banner
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الطالب: ${widget.studentName}',
                          style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الكود: ${widget.studentCode} • ولي الأمر: ${widget.parentName}',
                          style: AppTypography.bodySmall(textSecondary),
                        ),
                        Text(
                          'المجموعة: ${widget.groupName} • ${widget.centerName}',
                          style: AppTypography.caption(textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Financial Summary Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي المسدد نقداً', style: TextStyle(fontSize: 11, color: Colors.green)),
                        const SizedBox(height: 6),
                        Text(
                          '${_totalPaid.toStringAsFixed(1)} ج.م',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 2),
                        const Text('مدفوع كاش بالكامل ✔️', style: TextStyle(fontSize: 10, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _totalRemaining > 0 ? Colors.red.withValues(alpha: 0.1) : Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _totalRemaining > 0 ? Colors.red.withValues(alpha: 0.3) : Colors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المتأخرات / المطلوب',
                          style: TextStyle(fontSize: 11, color: _totalRemaining > 0 ? Colors.red : Colors.teal),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_totalRemaining.toStringAsFixed(1)} ج.م',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _totalRemaining > 0 ? Colors.red : Colors.teal),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _totalRemaining == 0 ? 'لا توجد أي متأخرات 🌟' : 'مستحق السداد بالاستقبال',
                          style: TextStyle(fontSize: 10, color: _totalRemaining > 0 ? Colors.red : Colors.teal),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cash Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'جميع المعاملات النقدية مسجلة ومطابقة لخزينة السنتر الرسمية مع إصدار إيصال معتمد.',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Itemized Transaction History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سجل المعاملات والإيصالات (${_ledgerRecords.length})',
                  style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _isExporting ? null : _exportPdf,
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('طباعة الكشف'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_ledgerRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                child: GlassCard(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد إيصالات أو معاملات مالية مسجلة لهذا الطالب حتى الآن.',
                          style: AppTypography.bodyMedium(textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._ledgerRecords.map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'إيصال #${r['receipt_number']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            Text(
                              '${(r['amount'] as num).toStringAsFixed(1)} ج.م',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          r['description'],
                          style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تاريخ السداد: ${r['date']}',
                              style: TextStyle(fontSize: 11, color: textSecondary),
                            ),
                            Text(
                              'المستلم: ${r['collector_name']}',
                              style: TextStyle(fontSize: 11, color: textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
