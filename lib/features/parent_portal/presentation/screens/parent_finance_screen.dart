import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../viewmodels/parent_finance_viewmodel.dart';
import 'parent_financial_ledger_screen.dart';

class ParentFinanceScreen extends StatefulWidget {
  final String? studentName;

  const ParentFinanceScreen({super.key, this.studentName});

  @override
  State<ParentFinanceScreen> createState() => _ParentFinanceScreenState();
}

class _ParentFinanceScreenState extends State<ParentFinanceScreen> {
  final ParentFinanceViewModel _viewModel = ParentFinanceViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChange() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Text(
            widget.studentName != null
                ? 'ماليات واشتراكات ${widget.studentName}'
                : 'الماليات والاشتراكات الدراسية 💳',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildBalanceCard(isDark, textPrimary, textSecondary),
            const SizedBox(height: 24),
            Text(
              'فواتير واشتراكات الحصص',
              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._viewModel.invoices.map((i) => _buildInvoiceCard(i, isDark, textPrimary, textSecondary)),
            const SizedBox(height: 24),
            Text(
              'سجل إيصالات السداد والمعاملات',
              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._viewModel.paymentHistory.map((p) => _buildPaymentCard(p, isDark, textPrimary, textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark, Color textPrimary, Color textSecondary) {
    final balance = _viewModel.outstandingBalance;

    return GlassCard(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المستحقات المتبقية للسداد',
                style: AppTypography.bodySmall(textSecondary).copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: balance > 0
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  balance > 0 ? 'مستحق للسداد' : 'لا توجد متأخرات ✅',
                  style: TextStyle(
                    color: balance > 0 ? AppColors.error : AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${balance.toStringAsFixed(0)} ج.م',
            style: TextStyle(
              color: balance > 0 ? AppColors.error : AppColors.success,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.point_of_sale_rounded, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('طريقة السداد: نقداً بالسنتر 💵', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المبلغ المستحق حالياً: ${balance.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'يتم سداد المستحقات والمصروفات الدراسية نقداً (كاش) بمكتب الاستقبال والخزينة داخل مقر السنتر التعليمي.\n\nفور السداد، يصدر موظف الاستقبال إيصالاً معتمداً ويتم إرسال إشعار ونسخة رقمية إليكم عبر واتساب وتحديث كشف الحساب.',
                          style: TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق'),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        label: const Text('كشف الحساب والإيصالات'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ParentFinancialLedgerScreen(
                                studentName: widget.studentName ?? 'الطالب',
                                initialTotalRemaining: balance,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.point_of_sale_rounded),
              label: const Text('تعليمات السداد نقداً بخزينة السنتر 💵'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, bool isDark, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.title,
                    style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تاريخ الاستحقاق: ${_formatDate(invoice.dueDate)}',
                    style: AppTypography.caption(textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${invoice.amount.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: invoice.isPaid
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: invoice.isPaid ? AppColors.success : AppColors.warning,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    invoice.isPaid ? 'تم السداد' : 'مستحق',
                    style: TextStyle(
                      color: invoice.isPaid ? AppColors.success : AppColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(
    PaymentHistory payment,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.description,
                    style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تاريخ الإيصال: ${_formatDate(payment.date)}',
                    style: AppTypography.caption(textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '${payment.amount.toStringAsFixed(0)} ج.م',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
