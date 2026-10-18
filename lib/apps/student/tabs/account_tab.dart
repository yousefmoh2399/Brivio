import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client_wrapper.dart';
import '../../../core/settings/app_settings_screen.dart';
import '../../../design_system/components/editable_avatar.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/auth/data/repositories/supabase_auth_repository.dart';
import '../../../features/auth/domain/models/user_profile.dart';
import '../../../features/communication/domain/models/announcement.dart';
import '../../../features/communication/domain/models/notification.dart';
import '../../../features/legal/presentation/screens/privacy_and_terms_screen.dart';
import '../../../features/payments/domain/models/payment_models.dart';
import '../screens/student_helpdesk_screen.dart';

String _formatDate(DateTime? dt) =>
    dt == null ? '' : DateFormat('dd/MM/yyyy').format(dt);

String _formatMoney(int minor, String currency) {
  final value = minor / 100;
  final clean = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$clean ج.م';
}

String _shortId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}

enum _AccountTabSection { billing, profile, announcements, settings }

class AccountTab extends StatefulWidget {
  final UserProfile? profile;
  final String role;
  final String? studentId;
  final FinancialSummary? financialSummary;
  final List<Invoice> invoices;
  final List<Receipt> receipts;
  final List<Announcement> announcements;
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final VoidCallback onSignOut;
  final Future<void> Function() onProfileChanged;
  final ValueChanged<AppNotification> onNotificationTap;
  final VoidCallback onMarkAllRead;
  final ValueChanged<Announcement> onAcknowledge;

  const AccountTab({
    super.key,
    required this.profile,
    required this.role,
    required this.studentId,
    required this.financialSummary,
    required this.invoices,
    required this.receipts,
    required this.announcements,
    required this.notifications,
    required this.unreadCount,
    required this.isLoading,
    required this.onSignOut,
    required this.onProfileChanged,
    required this.onNotificationTap,
    required this.onMarkAllRead,
    required this.onAcknowledge,
  });

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  _AccountTabSection _selectedSection = _AccountTabSection.billing;
  bool _showReceiptsInBilling = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 360;
        final isMobile = width < 720;
        final isDesktop = width >= 1024;
        final horizontalPadding = isNarrow ? 12.0 : (isMobile ? 16.0 : 24.0);

        return Scaffold(
          backgroundColor: bgColor,
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1000 : double.infinity,
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ─── Header & Profile Hero Card ───────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ExecutiveProfileHero(
                            profile: widget.profile,
                            role: widget.role,
                            studentId: widget.studentId,
                            financialSummary: widget.financialSummary,
                            invoicesCount: widget.invoices.length,
                            receiptsCount: widget.receipts.length,
                            announcementsCount: widget.announcements.length,
                            unreadCount: widget.unreadCount,
                            isDark: isDark,
                            isNarrow: isNarrow,
                            onProfileChanged: widget.onProfileChanged,
                            onSelectSection: (section) {
                              setState(() {
                                _selectedSection = section;
                              });
                            },
                            onMarkAllRead: widget.onMarkAllRead,
                          ),
                          const SizedBox(height: 16),

                          // ─── Segmented Navigation Hub ─────────────────────
                          _buildSegmentedHub(
                            context: context,
                            isDark: isDark,
                            isNarrow: isNarrow,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Selected Segment Content ─────────────────────────────
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      4,
                      horizontalPadding,
                      32,
                    ),
                    sliver: _buildActiveSectionContent(
                      isDark: isDark,
                      isNarrow: isNarrow,
                      isMobile: isMobile,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Segmented Navigation Hub ─────────────────────────────────────────────
  Widget _buildSegmentedHub({
    required BuildContext context,
    required bool isDark,
    required bool isNarrow,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final segments = [
      _SegmentItem(
        section: _AccountTabSection.billing,
        title: 'المحفظة والرسوم',
        icon: Icons.account_balance_wallet_rounded,
        badge: widget.invoices.isNotEmpty
            ? '${widget.invoices.length}'
            : null,
      ),
      _SegmentItem(
        section: _AccountTabSection.profile,
        title: 'الملف والأمان',
        icon: Icons.manage_accounts_rounded,
      ),
      _SegmentItem(
        section: _AccountTabSection.announcements,
        title: 'التعميمات',
        icon: Icons.campaign_rounded,
        badge: widget.announcements.isNotEmpty
            ? '${widget.announcements.length}'
            : null,
      ),
      _SegmentItem(
        section: _AccountTabSection.settings,
        title: 'الدعم والإعدادات',
        icon: Icons.settings_rounded,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: segments.map((item) {
          final isSelected = _selectedSection == item.section;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedSection = item.section),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 12 : 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.14)
                        : (isDark
                            ? const Color(0xFF161616)
                            : Colors.white.withValues(alpha: 0.85)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? const Color(0xFF262626)
                              : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.4 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
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
                        size: 16,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: isNarrow ? 11.5 : 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (item.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.badge!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade800),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Active Section Content Router ────────────────────────────────────────
  Widget _buildActiveSectionContent({
    required bool isDark,
    required bool isNarrow,
    required bool isMobile,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    switch (_selectedSection) {
      case _AccountTabSection.billing:
        return SliverToBoxAdapter(
          child: _BillingHubView(
            summary: widget.financialSummary,
            invoices: widget.invoices,
            receipts: widget.receipts,
            isDark: isDark,
            isNarrow: isNarrow,
            isMobile: isMobile,
            showReceipts: _showReceiptsInBilling,
            onToggleView: (showReceipts) {
              setState(() => _showReceiptsInBilling = showReceipts);
            },
          ),
        );

      case _AccountTabSection.profile:
        return SliverToBoxAdapter(
          child: _ProfileEditCard(
            profile: widget.profile,
            onProfileChanged: widget.onProfileChanged,
            isNarrow: isNarrow,
          ),
        );

      case _AccountTabSection.announcements:
        return SliverToBoxAdapter(
          child: _AnnouncementsHubView(
            announcements: widget.announcements,
            onAcknowledge: widget.onAcknowledge,
            isDark: isDark,
            isNarrow: isNarrow,
            isMobile: isMobile,
          ),
        );

      case _AccountTabSection.settings:
        return SliverToBoxAdapter(
          child: _SettingsAndSupportView(
            isDark: isDark,
            isNarrow: isNarrow,
            onSignOut: widget.onSignOut,
          ),
        );
    }
  }
}

class _SegmentItem {
  final _AccountTabSection section;
  final String title;
  final IconData icon;
  final String? badge;

  const _SegmentItem({
    required this.section,
    required this.title,
    required this.icon,
    this.badge,
  });
}

// ─── Executive Profile Hero Card ──────────────────────────────────────────────
class _ExecutiveProfileHero extends StatelessWidget {
  final UserProfile? profile;
  final String role;
  final String? studentId;
  final FinancialSummary? financialSummary;
  final int invoicesCount;
  final int receiptsCount;
  final int announcementsCount;
  final int unreadCount;
  final bool isDark;
  final bool isNarrow;
  final Future<void> Function()? onProfileChanged;
  final ValueChanged<_AccountTabSection> onSelectSection;
  final VoidCallback onMarkAllRead;

  const _ExecutiveProfileHero({
    required this.profile,
    required this.role,
    required this.studentId,
    required this.financialSummary,
    required this.invoicesCount,
    required this.receiptsCount,
    required this.announcementsCount,
    required this.unreadCount,
    required this.isDark,
    required this.isNarrow,
    required this.onProfileChanged,
    required this.onSelectSection,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final name = profile?.fullName ?? 'طالب منصة بريفيو';
    final email = profile?.email ?? '';
    final phone = profile?.phoneNumber ?? '';
    final avatarUrl = profile?.avatarUrl;

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 14 : 18),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Identity Info + Edit Shortcut
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3D Avatar
              EditableAvatar(
                avatarUrl: avatarUrl,
                fullName: name,
                radius: isNarrow ? 32 : 38,
                roleColor: AppColors.studentRole,
                userId: profile?.id,
                userEmail: profile?.email,
                onAvatarChanged: (_) => onProfileChanged?.call(),
              ),
              const SizedBox(width: 14),

              // Student Identity Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: isNarrow ? 16 : 18,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Role Chip + Student Code Chip
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            role == 'student' ? 'طالب رسمي' : role,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (studentId != null && studentId!.isNotEmpty)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: studentId!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم نسخ كود الطالب إلى الحافظة'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 11,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'كود: #${_shortId(studentId!)}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (email.isNotEmpty || phone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        email.isNotEmpty ? email : phone,
                        style: AppTypography.caption(textSecondary).copyWith(
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Quick Edit Profile Shortcut
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 22),
                tooltip: 'تعديل الملف الشخصي',
                color: AppColors.primary,
                visualDensity: VisualDensity.compact,
                onPressed: () => onSelectSection(_AccountTabSection.profile),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Unread Notifications Alert Banner (if any)
          if (unreadCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.28),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFEF4444),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'يوجد لديك $unreadCount تنبيهات جديدة',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: onMarkAllRead,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    child: const Text(
                      'تحديد كمقروء',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Quick Interactive Glance Micro-Stats
          SizedBox(
            height: 62,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildQuickGlanceChip(
                  label: 'المتبقي للدفع',
                  value: financialSummary != null
                      ? _formatMoney(
                          financialSummary!.remainingBalanceMinor,
                          financialSummary!.currency,
                        )
                      : '0 ج.م',
                  icon: Icons.account_balance_wallet_rounded,
                  color: (financialSummary?.remainingBalanceMinor ?? 0) > 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  onTap: () => onSelectSection(_AccountTabSection.billing),
                ),
                const SizedBox(width: 8),
                _buildQuickGlanceChip(
                  label: 'الفواتير',
                  value: '$invoicesCount فواتير',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => onSelectSection(_AccountTabSection.billing),
                ),
                const SizedBox(width: 8),
                _buildQuickGlanceChip(
                  label: 'الإيصالات',
                  value: '$receiptsCount إيصال',
                  icon: Icons.receipt_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => onSelectSection(_AccountTabSection.billing),
                ),
                const SizedBox(width: 8),
                _buildQuickGlanceChip(
                  label: 'التعميمات',
                  value: '$announcementsCount إعلان',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => onSelectSection(_AccountTabSection.announcements),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGlanceChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
}

// ─── Segment 0: Billing & Financial Hub View ──────────────────────────────────
class _BillingHubView extends StatelessWidget {
  final FinancialSummary? summary;
  final List<Invoice> invoices;
  final List<Receipt> receipts;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final bool showReceipts;
  final ValueChanged<bool> onToggleView;

  const _BillingHubView({
    required this.summary,
    required this.invoices,
    required this.receipts,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.showReceipts,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Financial KPI Overview Strip
        if (summary != null) ...[
          PortalMetricGrid(
            children: [
              PortalMetricCard(
                label: 'إجمالي الفواتير',
                value: _formatMoney(summary!.totalDueMinor, summary!.currency),
                icon: Icons.payments_rounded,
                accentColor: const Color(0xFFF59E0B),
              ),
              PortalMetricCard(
                label: 'المدفوع بنجاح',
                value: _formatMoney(summary!.totalPaidMinor, summary!.currency),
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF10B981),
              ),
              PortalMetricCard(
                label: 'الرصيد المتبقي',
                value: _formatMoney(
                  summary!.remainingBalanceMinor,
                  summary!.currency,
                ),
                icon: Icons.wallet_rounded,
                accentColor: summary!.remainingBalanceMinor > 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
              ),
              PortalMetricCard(
                label: 'عدد الفواتير',
                value: '${summary!.invoiceCount}',
                icon: Icons.receipt_long_rounded,
                accentColor: const Color(0xFF3B82F6),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Sub-filter Toggle: Invoices vs Receipts
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSubFilterButton(
                  title: 'الفواتير المستحقة (${invoices.length})',
                  icon: Icons.receipt_long_rounded,
                  isSelected: !showReceipts,
                  onTap: () => onToggleView(false),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSubFilterButton(
                  title: 'إيصالات السداد (${receipts.length})',
                  icon: Icons.receipt_rounded,
                  isSelected: showReceipts,
                  onTap: () => onToggleView(true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // List Display
        if (!showReceipts) ...[
          if (invoices.isEmpty)
            _buildEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'لا توجد فواتير مسجلة',
              subtitle: 'سجلك المالي نظيف تماماً ولا توجد فواتير مستحقة حالياً.',
            )
          else
            _buildInvoicesList(context, textPrimary, textSecondary),
        ] else ...[
          if (receipts.isEmpty)
            _buildEmptyState(
              icon: Icons.receipt_rounded,
              title: 'لا توجد إيصالات سداد مسجلة',
              subtitle: 'سيتم ظهور الإيصالات الإلكترونية المعتمدة فور تسديد المصاريف.',
            )
          else
            _buildReceiptsList(context, textPrimary, textSecondary),
        ],
      ],
    );
  }

  Widget _buildSubFilterButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF262626) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isNarrow ? 11 : 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoicesList(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (!isMobile) {
      // 2 Columns on Tablet / Desktop
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 12,
          mainAxisExtent: 110,
        ),
        itemCount: invoices.length,
        itemBuilder: (context, i) => _buildInvoiceCard(invoices[i]),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildInvoiceCard(invoices[i]),
    );
  }

  Widget _buildInvoiceCard(Invoice inv) {
    final isPaid = inv.status == 'paid';
    final accentColor =
        isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        inv.invoiceNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    PortalStatusChip(status: inv.status),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      _formatMoney(inv.totalMinor, inv.currency),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      'استحقاق: ${_formatDate(inv.dueAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (!isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 12,
          mainAxisExtent: 100,
        ),
        itemCount: receipts.length,
        itemBuilder: (context, i) => _buildReceiptCard(context, receipts[i]),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: receipts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildReceiptCard(context, receipts[i]),
    );
  }

  Widget _buildReceiptCard(BuildContext context, Receipt r) {
    return GlassCard(
      padding: EdgeInsets.zero,
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: InkWell(
        onTap: () => _showReceiptDialog(context, r),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      r.receiptNumber.isEmpty
                          ? 'إيصال دفع إلكتروني #${_shortId(r.id)}'
                          : r.receiptNumber,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          _formatMoney(r.amountMinor, r.currency),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          _formatDate(r.issuedAt),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptDialog(BuildContext context, Receipt receipt) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFF10B981),
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                receipt.receiptNumber.isEmpty
                    ? 'إيصال سداد إلكتروني'
                    : receipt.receiptNumber,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    'المبلغ المسدد بنجاح',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMoney(receipt.amountMinor, receipt.currency),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ReceiptDetailLine(
              label: 'تاريخ وساعة الإصدار',
              value: _formatDate(receipt.issuedAt),
            ),
            _ReceiptDetailLine(
              label: 'رقم الفاتورة المرجعية',
              value: _shortId(receipt.invoiceId),
            ),
            _ReceiptDetailLine(
              label: 'رقم المعاملة الإلكترونية',
              value: _shortId(receipt.transactionId),
            ),
            _ReceiptDetailLine(
              label: 'حالة الاعتماد',
              value: 'معتمد ومؤكد رسمياً ✓',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ReceiptDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Segment 1: Profile & Security View ───────────────────────────────────────
class _ProfileEditCard extends StatefulWidget {
  final UserProfile? profile;
  final Future<void> Function() onProfileChanged;
  final bool isNarrow;

  const _ProfileEditCard({
    required this.profile,
    required this.onProfileChanged,
    required this.isNarrow,
  });

  @override
  State<_ProfileEditCard> createState() => _ProfileEditCardState();
}

class _ProfileEditCardState extends State<_ProfileEditCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _avatarCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _savingProfile = false;
  bool _changingPw = false;
  bool _obscurePassword = true;
  String? _msg;
  String? _err;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: p?.phoneNumber ?? '');
    _avatarCtrl = TextEditingController(text: p?.avatarUrl ?? '');
  }

  @override
  void didUpdateWidget(covariant _ProfileEditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id ||
        oldWidget.profile?.updatedAt != widget.profile?.updatedAt) {
      _nameCtrl.text = widget.profile?.fullName ?? '';
      _phoneCtrl.text = widget.profile?.phoneNumber ?? '';
      _avatarCtrl.text = widget.profile?.avatarUrl ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _avatarCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final p = widget.profile;
    if (p == null || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _savingProfile = true;
      _msg = null;
      _err = null;
    });
    try {
      final repo = SupabaseAuthRepository(
        SupabaseClientWrapper(Supabase.instance.client),
      );
      await repo.updateProfile(
        p.copyWith(
          fullName: _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          avatarUrl: _avatarCtrl.text.trim().isEmpty
              ? null
              : _avatarCtrl.text.trim(),
        ),
      );
      await widget.onProfileChanged();
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _msg = 'تم حفظ وتحديث بيانات الحساب بنجاح.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _err = 'تعذر حفظ البيانات: $e';
      });
    }
  }

  Future<void> _changePassword() async {
    final pw = _passwordCtrl.text.trim();
    if (pw.length < 6) {
      setState(() {
        _err = 'كلمة المرور يجب أن تتكون من 6 أحرف على الأقل.';
      });
      return;
    }
    setState(() {
      _changingPw = true;
      _msg = null;
      _err = null;
    });
    try {
      final repo = SupabaseAuthRepository(
        SupabaseClientWrapper(Supabase.instance.client),
      );
      await repo.updatePassword(pw);
      _passwordCtrl.clear();
      if (!mounted) return;
      setState(() {
        _changingPw = false;
        _msg = 'تم تغيير كلمة المرور وتأمين الحساب بنجاح.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPw = false;
        _err = 'تعذر تحديث كلمة المرور: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NoticeBanner(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              text: _msg!,
            ),
          ),
        if (_err != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NoticeBanner(
              icon: Icons.error_outline_rounded,
              color: AppColors.error,
              text: _err!,
            ),
          ),

        // Personal Details Form Card
        GlassCard(
          padding: EdgeInsets.all(widget.isNarrow ? 14 : 18),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'بيانات الملف الشخصي',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'الاسم بالكامل',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF141414)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'يرجى إدخال الاسم بالكامل'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _phoneCtrl,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف / الواتساب',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF141414)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Shortcut to 3D Snapchat Avatar Studio
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final newUrl = await showModalBottomSheet<String?>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => AvatarPickerBottomSheet(
                        currentAvatarUrl: _avatarCtrl.text,
                        fullName: _nameCtrl.text.isNotEmpty
                            ? _nameCtrl.text
                            : 'طالب',
                        roleColor: AppColors.studentRole,
                        userId: widget.profile?.id,
                        userEmail: widget.profile?.email,
                      ),
                    );
                    if (newUrl != null) {
                      final actualUrl = newUrl.isEmpty ? null : newUrl;
                      setState(() {
                        _avatarCtrl.text = actualUrl ?? '';
                      });
                      await _saveProfile();
                    }
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text(
                    'تخصيص الأفاتار والشخصية الكرتونية 🎨',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _savingProfile ? null : _saveProfile,
                    icon: _savingProfile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text(
                      'حفظ التعديلات',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Security & Password Card
        GlassCard(
          padding: EdgeInsets.all(widget.isNarrow ? 14 : 18),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الأمان وكلمة المرور',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF141414)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'يجب ألا تقل كلمة المرور عن 6 أحرف وتتضمن أرقاماً لحماية حسابك.',
                style: TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _changingPw ? null : _changePassword,
                  icon: _changingPw
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.security_update_rounded, size: 18),
                  label: const Text(
                    'تحديث كلمة المرور',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Segment 2: Announcements Hub View ────────────────────────────────────────
class _AnnouncementsHubView extends StatelessWidget {
  final List<Announcement> announcements;
  final ValueChanged<Announcement> onAcknowledge;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;

  const _AnnouncementsHubView({
    required this.announcements,
    required this.onAcknowledge,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (announcements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
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
              Icons.campaign_outlined,
              size: 40,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد إعلانات منشورة حالياً',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'سيتم إشعارك بكافة التعميمات والقرارات الإدارية الجديدة فور صدورها.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: announcements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final a = announcements[index];
        final isUrgent = a.priority == AnnouncementPriority.urgent;
        final isImportant = a.priority == AnnouncementPriority.important;

        final Color priorityColor = isUrgent
            ? const Color(0xFFEF4444)
            : (isImportant
                ? const Color(0xFFF59E0B)
                : const Color(0xFF3B82F6));

        final String priorityLabel = isUrgent
            ? 'عاجل 🚨'
            : (isImportant ? 'مهم ⚠️' : 'عام 📢');

        return GlassCard(
          padding: EdgeInsets.all(isNarrow ? 14 : 16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isUrgent
              ? priorityColor.withValues(alpha: 0.45)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Strip: Priority Tag + Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: priorityColor.withValues(alpha: 0.28),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      priorityLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: priorityColor,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(a.publishAt),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                a.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Body text
              Text(
                a.body,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Acknowledgement Action
              if (a.requiresAcknowledgement)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: a.isAcknowledged
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'تم الاطلاع بنجاح',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: priorityColor,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => onAcknowledge(a),
                          icon: const Icon(Icons.check_rounded, size: 15),
                          label: const Text(
                            'تأكيد الاطلاع والاستلام',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Segment 3: Settings & Support View ───────────────────────────────────────
class _SettingsAndSupportView extends StatelessWidget {
  final bool isDark;
  final bool isNarrow;
  final VoidCallback onSignOut;

  const _SettingsAndSupportView({
    required this.isDark,
    required this.isNarrow,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Support and App Settings Group
        _AppleGroupedList(
          children: [
            _AccountActionTile(
              icon: Icons.support_agent_rounded,
              color: const Color(0xFF10B981),
              title: 'الدعم الفني والشكاوى',
              subtitle: 'إرسال تذكرة ومتابعة ردود الإدارة والدعم الفني',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StudentHelpdeskScreen(),
                ),
              ),
            ),
            _AccountActionTile(
              icon: Icons.tune_rounded,
              color: const Color(0xFF3B82F6),
              title: 'إعدادات التطبيق والمظهر',
              subtitle: 'المظهر الداكن/الفاتح، الإشعارات، واللغات',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AppSettingsScreen(),
                ),
              ),
            ),
            _AccountActionTile(
              icon: Icons.policy_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'سياسة الخصوصية والشروط',
              subtitle: 'معايير الأمان وحماية البيانات والخصوصية',
              onTap: () => PrivacyAndTermsScreen.show(context),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Sign Out Group
        _AppleGroupedList(
          children: [
            _AccountActionTile(
              icon: Icons.logout_rounded,
              color: const Color(0xFFEF4444),
              title: 'تسجيل الخروج من الحساب',
              subtitle: 'الخروج والعودة لشاشة الدخول الرئيسية',
              isDestructive: true,
              onTap: () => _confirmSignOut(context),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من هذا الحساب؟',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onSignOut();
            },
            child: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _AccountActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDestructive
                            ? const Color(0xFFEF4444)
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppleGroupedList extends StatelessWidget {
  final List<Widget> children;

  const _AppleGroupedList({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final dividerColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 64,
                endIndent: 0,
                color: dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _NoticeBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
