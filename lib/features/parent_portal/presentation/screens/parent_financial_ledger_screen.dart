import 'package:flutter/material.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class ParentFinancialLedgerScreen extends StatefulWidget {
  final String studentName;
  final String studentCode;
  final String parentName;
  final String parentPhone;
  final String groupName;
  final String centerName;

  const ParentFinancialLedgerScreen({
    super.key,
    this.studentName = 'عمر أحمد محمود',
    this.studentCode = 'STU-101',
    this.parentName = 'أ. أحمد محمود',
    this.parentPhone = '01011112222',
    this.groupName = 'ثانوية عامة - لغات A',
    this.centerName = 'سنتر الأوائل التعليمي',
  });

  @override
  State<ParentFinancialLedgerScreen> createState() => _ParentFinancialLedgerScreenState();
}

class _ParentFinancialLedgerScreenState extends State<ParentFinancialLedgerScreen> {
  bool _isExporting = false;

  final double _totalPaid = 950.0;
  final double _totalRemaining = 0.0;

  final List<Map<String, dynamic>> _ledgerRecords = [
    {
      'receipt_number': 'REC-8841',
      'date': '2026-10-01',
      'description': 'اشتراك شهر أكتوبر 2026 (مادة الفيزياء)',
      'amount': 400.0,
      'collector_name': 'أ. سارة (الاستقبال)',
      'payment_method': 'كاش فقط',
      'status': 'مدفوع معتمد',
    },
    {
      'receipt_number': 'REC-8512',
      'date': '2026-10-05',
      'description': 'شراء مذكرة بنك الأسئلة والتدريبات الشاملة',
      'amount': 150.0,
      'collector_name': 'خزينة ومخزن السنتر',
      'payment_method': 'كاش فقط',
      'status': 'مدفوع معتمد',
    },
    {
      'receipt_number': 'REC-7920',
      'date': '2026-09-01',
      'description': 'اشتراك شهر سبتمبر 2026 (مادة الفيزياء)',
      'amount': 400.0,
      'collector_name': 'أ. محمود (الاستقبال)',
      'payment_method': 'كاش فقط',
      'status': 'مدفوع معتمد',
    },
  ];

  Future<void> _exportPdf() async {
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
