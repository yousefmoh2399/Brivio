import 'package:flutter/material.dart';

import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/payments/domain/models/payment_models.dart';

// ─── Main Parent Payments Tab Widget ─────────────────────────────────────────

enum PaymentsFilterCategory {
  all,
  invoices,
  receipts,
  unpaid,
}

class ParentPaymentsTab extends StatefulWidget {
  final Student? child;
  final List<Student> linkedChildren;
  final ValueChanged<Student> onChildSelected;
  final FinancialSummary? financialSummary;
  final List<Invoice> invoices;
  final List<Receipt> receipts;
  final List<GroupEntity> childGroups;
  final VoidCallback onExportLedger;
  final ValueChanged<Receipt> onShowReceipt;

  const ParentPaymentsTab({
    super.key,
    required this.child,
    required this.linkedChildren,
    required this.onChildSelected,
    required this.financialSummary,
    required this.invoices,
    required this.receipts,
    required this.childGroups,
    required this.onExportLedger,
    required this.onShowReceipt,
  });

  @override
  State<ParentPaymentsTab> createState() => _ParentPaymentsTabState();
}

class _ParentPaymentsTabState extends State<ParentPaymentsTab> {
  PaymentsFilterCategory _selectedCategory = PaymentsFilterCategory.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 380;
        final isMobile = screenWidth < 650;

        // Unpaid or pending invoices
        final unpaidInvoices = widget.invoices.where((inv) {
          final s = inv.status.toLowerCase();
          return s == 'issued' || s == 'overdue' || s == 'partially_paid';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Financial Summary Hero Card
            _ExecutiveFinancialHero(
              child: widget.child,
              summary: widget.financialSummary,
              invoices: widget.invoices,
              isDark: isDark,
              isNarrow: isNarrow,
              isMobile: isMobile,
              onExportLedger: widget.onExportLedger,
            ),
            const SizedBox(height: 18),

            // 2. Interactive Category Filter Switcher Bar
            _PaymentsCategoryFilterBar(
              selectedCategory: _selectedCategory,
              invoicesCount: widget.invoices.length,
              receiptsCount: widget.receipts.length,
              unpaidCount: unpaidInvoices.length,
              isDark: isDark,
              isNarrow: isNarrow,
              onCategoryChanged: (category) {
                setState(() => _selectedCategory = category);
              },
            ),
            const SizedBox(height: 18),

            // 3. Dynamic Category Views
            if (_selectedCategory == PaymentsFilterCategory.all) ...[
              // Unpaid Invoices Alert Section (if any)
              if (unpaidInvoices.isNotEmpty) ...[
                _InvoicesSection(
                  title: 'فواتير واشتراكات بانتظار السداد ⚠️',
                  subtitle: 'يرجى سداد الاشتراكات في مواعيدها لضمان استمرار الحضور.',
                  invoices: unpaidInvoices,
                  isDark: isDark,
                  isNarrow: isNarrow,
                ),
                const SizedBox(height: 20),
              ],

              // All Invoices Section
              _InvoicesSection(
                title: 'فواتير واشتراكات الحصص',
                subtitle: 'سجل الفواتير الصادرة وقيمة كل اشتراك مع تاريخ الاستحقاق.',
                invoices: widget.invoices,
                limit: 4,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: () {
                  setState(() => _selectedCategory = PaymentsFilterCategory.invoices);
                },
              ),
              const SizedBox(height: 20),

              // Receipts Section
              _ReceiptsSection(
                receipts: widget.receipts,
                limit: 4,
                isDark: isDark,
                isNarrow: isNarrow,
                onShowReceipt: widget.onShowReceipt,
                onViewAll: () {
                  setState(() => _selectedCategory = PaymentsFilterCategory.receipts);
                },
              ),
              const SizedBox(height: 20),

              // Financial Policies & Payment Guidance Advice Card
              _FinancialPolicyAdviceCard(isDark: isDark, isNarrow: isNarrow),
            ] else if (_selectedCategory == PaymentsFilterCategory.invoices) ...[
              _InvoicesSection(
                title: 'كافة فواتير واشتراكات الحصص',
                subtitle: 'قائمة كاملة بجميع الفواتير والمطالبات المالية الصادرة للطالب.',
                invoices: widget.invoices,
                limit: null,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: null,
              ),
            ] else if (_selectedCategory == PaymentsFilterCategory.receipts) ...[
              _ReceiptsSection(
                receipts: widget.receipts,
                limit: null,
                isDark: isDark,
                isNarrow: isNarrow,
                onShowReceipt: widget.onShowReceipt,
                onViewAll: null,
              ),
            ] else if (_selectedCategory == PaymentsFilterCategory.unpaid) ...[
              _InvoicesSection(
                title: 'المتأخرات والمستحقات المتبقية للسداد',
                subtitle: 'الفواتير المستحقة حالياً التي لم يتم تسويتها بالكامل بعد.',
                invoices: unpaidInvoices,
                limit: null,
                isDark: isDark,
                isNarrow: isNarrow,
                onViewAll: null,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── 1. Executive Financial Summary Hero Card ─────────────────────────────────

class _ExecutiveFinancialHero extends StatelessWidget {
  final Student? child;
  final FinancialSummary? summary;
  final List<Invoice> invoices;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final VoidCallback onExportLedger;

  const _ExecutiveFinancialHero({
    required this.child,
    required this.summary,
    required this.invoices,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.onExportLedger,
  });

  @override
  Widget build(BuildContext context) {
    final currency = summary?.currency ?? 'EGP';
    final totalDueMinor = summary?.totalDueMinor ?? 0;
    final totalPaidMinor = summary?.totalPaidMinor ?? 0;
    final remainingMinor = summary?.remainingBalanceMinor ?? (totalDueMinor - totalPaidMinor);

    final double clearancePct =
        totalDueMinor > 0 ? ((totalPaidMinor / totalDueMinor) * 100).clamp(0.0, 100.0) : 100.0;
    final int pctInt = clearancePct.round();

    final hasOverdue = invoices.any((inv) => inv.status.toLowerCase() == 'overdue');
    final isClear = remainingMinor <= 0;

    final Color statusColor;
    final String statusLabel;
    final String statusBadge;

    if (isClear) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'تمت تصفية وسداد كافة المستحقات بالكامل ✔️';
      statusBadge = 'حساب خالص';
    } else if (hasOverdue) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'تنبيه عاجل: توجد فواتير متأخرة عن موعد السداد ⚠️';
      statusBadge = 'متأخرات عاجلة';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'يوجد رصيد متبقي بانتظار السداد بالخزينة ⏳';
      statusBadge = 'مستحق السداد';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.40 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Radial Clearance Dial + Child Identification & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radial Dial
                SizedBox(
                  width: isNarrow ? 56 : 66,
                  height: isNarrow ? 56 : 66,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: totalDueMinor > 0 ? (pctInt / 100).clamp(0.0, 1.0) : 1.0,
                        strokeWidth: isNarrow ? 5 : 6,
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            totalDueMinor > 0 ? '$pctInt%' : '100%',
                            style: TextStyle(
                              fontSize: isNarrow ? 12 : 14.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'السداد',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Financial Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            child?.fullName ?? 'الطالب',
                            style: TextStyle(
                              fontSize: isNarrow ? 14 : 15.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              statusBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: isNarrow ? 11 : 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'كود الطالب: ${child?.studentCode ?? "---"} • كشف حساب مالي لحظي وموثق',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Financial Metrics Row: إجمالي المستحق / المدفوع / المتبقي
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 8 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMoneyMetric(
                      label: 'إجمالي المستحق',
                      minor: totalDueMinor,
                      currency: currency,
                      color: AppColors.studentRole,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  Expanded(
                    child: _buildMoneyMetric(
                      label: 'المسدد بالخزينة',
                      minor: totalPaidMinor,
                      currency: currency,
                      color: const Color(0xFF10B981),
                      icon: Icons.verified_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  Expanded(
                    child: _buildMoneyMetric(
                      label: 'المتبقي للسداد',
                      minor: remainingMinor,
                      currency: currency,
                      color: remainingMinor > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      icon: Icons.pending_actions_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Export Financial Ledger Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: child == null ? null : onExportLedger,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'تحميل وطباعة كشف الحساب المالي المعتمد PDF 📄',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoneyMetric({
    required String label,
    required int minor,
    required String currency,
    required Color color,
    required IconData icon,
  }) {
    final amount = minor / 100;
    final formatted = amount == amount.truncateToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final cur = (currency == 'EGP') ? 'ج.م' : currency;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$formatted $cur',
            style: TextStyle(
              fontSize: isNarrow ? 12 : 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 2. Interactive Category Filter Switcher Bar ──────────────────────────────

class _PaymentsCategoryFilterBar extends StatelessWidget {
  final PaymentsFilterCategory selectedCategory;
  final int invoicesCount;
  final int receiptsCount;
  final int unpaidCount;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<PaymentsFilterCategory> onCategoryChanged;

  const _PaymentsCategoryFilterBar({
    required this.selectedCategory,
    required this.invoicesCount,
    required this.receiptsCount,
    required this.unpaidCount,
    required this.isDark,
    required this.isNarrow,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (
        category: PaymentsFilterCategory.all,
        label: 'نظرة شاملة',
        icon: Icons.dashboard_rounded,
        count: null,
      ),
      (
        category: PaymentsFilterCategory.invoices,
        label: 'فواتير واشتراكات',
        icon: Icons.receipt_long_rounded,
        count: invoicesCount,
      ),
      (
        category: PaymentsFilterCategory.receipts,
        label: 'إيصالات السداد',
        icon: Icons.receipt_rounded,
        count: receiptsCount,
      ),
      (
        category: PaymentsFilterCategory.unpaid,
        label: 'مستحق السداد',
        icon: Icons.pending_actions_rounded,
        count: unpaidCount,
      ),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final isSelected = selectedCategory == item.category;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onCategoryChanged(item.category),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 10 : 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.parentRole
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.parentRole
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.parentRole.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: isNarrow ? 11 : 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    if (item.count != null && item.count! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.parentRole.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${item.count}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.parentRole,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── 3. Invoices & Subscriptions Section ──────────────────────────────────────

class _InvoicesSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Invoice> invoices;
  final int? limit;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback? onViewAll;

  const _InvoicesSection({
    required this.title,
    required this.subtitle,
    required this.invoices,
    this.limit,
    required this.isDark,
    required this.isNarrow,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayed = limit != null ? invoices.take(limit!).toList() : invoices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: PortalSectionTitle(title: title, subtitle: subtitle),
            ),
            if (onViewAll != null && invoices.length > (limit ?? 0))
              TextButton.icon(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text(
                  'عرض الكل',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (displayed.isEmpty)
          _buildEmptyCard(
            message: 'لا توجد فواتير أو مطالبات مالية مسجلة.',
            icon: Icons.receipt_long_outlined,
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final inv = displayed[index];
              return _buildInvoiceCard(inv, context);
            },
          ),
      ],
    );
  }

  Widget _buildInvoiceCard(Invoice inv, BuildContext context) {
    final status = inv.status.toLowerCase();
    final isPaid = status == 'paid';
    final isOverdue = status == 'overdue';
    final isPartial = status == 'partially_paid';

    final Color statusColor;
    final String statusBadge;
    final IconData statusIcon;

    if (isPaid) {
      statusColor = const Color(0xFF10B981);
      statusBadge = 'تم السداد بنجاح ✔️';
      statusIcon = Icons.check_circle_rounded;
    } else if (isOverdue) {
      statusColor = const Color(0xFFEF4444);
      statusBadge = 'متأخرة عن الموعد ⚠️';
      statusIcon = Icons.warning_rounded;
    } else if (isPartial) {
      statusColor = const Color(0xFFF59E0B);
      statusBadge = 'مسددة جزئياً ⏳';
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      statusColor = const Color(0xFF3B82F6);
      statusBadge = 'صادرة بانتظار السداد 📄';
      statusIcon = Icons.receipt_long_rounded;
    }

    final amountStr = _formatAmount(inv.totalMinor, inv.currency);
    final invNum =
        inv.invoiceNumber.isNotEmpty ? inv.invoiceNumber : 'فاتورة #${inv.id.substring(0, 8)}';
    final dueDate =
        '${inv.dueAt.year}-${inv.dueAt.month.toString().padLeft(2, '0')}-${inv.dueAt.day.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, size: 20, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invNum,
                      style: TextStyle(
                        fontSize: isNarrow ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تاريخ الاستحقاق: $dueDate',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  amountStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Status Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusBadge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildEmptyCard({
    required String message,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAmount(int minor, String? currency) {
    final amount = minor / 100;
    final formatted = amount == amount.truncateToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final cur = (currency == null || currency == 'EGP') ? 'ج.م' : currency;
    return '$formatted $cur';
  }
}

// ─── 4. Receipts & Transactions Section ───────────────────────────────────────

class _ReceiptsSection extends StatelessWidget {
  final List<Receipt> receipts;
  final int? limit;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<Receipt> onShowReceipt;
  final VoidCallback? onViewAll;

  const _ReceiptsSection({
    required this.receipts,
    this.limit,
    required this.isDark,
    required this.isNarrow,
    required this.onShowReceipt,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayed = limit != null ? receipts.take(limit!).toList() : receipts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'إيصالات السداد والمعاملات',
                subtitle: 'إيصالات الدفع الإلكتروني والنقدي المعتمدة بالخزينة.',
              ),
            ),
            if (onViewAll != null && receipts.length > (limit ?? 0))
              TextButton.icon(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text(
                  'عرض الكل',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (displayed.isEmpty)
          _InvoicesSection._buildEmptyCard(
            message: 'لا توجد إيصالات سداد مسجلة حتى الآن.',
            icon: Icons.receipt_outlined,
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final receipt = displayed[index];
              return _buildReceiptCard(receipt, context);
            },
          ),
      ],
    );
  }

  Widget _buildReceiptCard(Receipt receipt, BuildContext context) {
    final amountStr = _InvoicesSection._formatAmount(receipt.amountMinor, receipt.currency);
    final recNum = receipt.receiptNumber.isNotEmpty
        ? receipt.receiptNumber
        : 'إيصال #${receipt.id.substring(0, 8)}';
    final dateStr =
        '${receipt.issuedAt.year}-${receipt.issuedAt.month.toString().padLeft(2, '0')}-${receipt.issuedAt.day.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      onTap: () => onShowReceipt(receipt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recNum,
                      style: TextStyle(
                        fontSize: isNarrow ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'سداد معتمد بالخزينة • $dateStr',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  amountStr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tap preview hint
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'انقر لعرض تفاصيل الإيصال وبيانات المعاملة 🔍',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 5. Financial Policies & Payment Guidance Advice Card ─────────────────────

class _FinancialPolicyAdviceCard extends StatelessWidget {
  final bool isDark;
  final bool isNarrow;

  const _FinancialPolicyAdviceCard({
    required this.isDark,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.parentRole.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.parentRole.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.parentRole,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إرشادات وضوابط السداد بالسنتر ℹ️',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.parentRole,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• يتم سداد الاشتراكات الشهرية في خزانة السنتر نقداً أو عبر المحافظ الإلكترونية المعتمدة.\n'
            '• يرجى الاحتفاظ برقم المعاملة أو إيصال السداد المالي لإبرازه عند تجديد البطاقة أو الاشتراك.\n'
            '• يمكنك تحميل كشف الحساب المالي الرسمي PDF في أي وقت من الزر أعلاه.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
