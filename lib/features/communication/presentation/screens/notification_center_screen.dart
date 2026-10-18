import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/notification_localizer.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/notification.dart';
import '../viewmodels/notification_center_viewmodel.dart';

enum NotificationCategoryFilter { all, academic, financial, general }

class NotificationCenterScreen extends StatefulWidget {
  final NotificationCenterViewModel viewModel;
  final ValueChanged<AppNotification>? onNotificationTap;

  const NotificationCenterScreen({
    super.key,
    required this.viewModel,
    this.onNotificationTap,
  });

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  NotificationCategoryFilter _selectedFilter = NotificationCategoryFilter.all;
  bool _onlyUnread = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.viewModel.loadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  NotificationCategoryFilter _resolveCategory(AppNotification notif) {
    final t = notif.type.toLowerCase();
    final m = '${notif.title} ${notif.message}'.toLowerCase();

    if (t.contains('pay') ||
        t.contains('receipt') ||
        t.contains('fee') ||
        t.contains('finance') ||
        t.contains('invoice') ||
        m.contains('إيصال') ||
        m.contains('فاتورة') ||
        m.contains('مصاريف') ||
        m.contains('سداد') ||
        m.contains('دفعة') ||
        m.contains('كاش') ||
        m.contains('جنيه')) {
      return NotificationCategoryFilter.financial;
    }

    if (t.contains('exam') ||
        t.contains('homework') ||
        t.contains('grade') ||
        t.contains('quiz') ||
        t.contains('attendance') ||
        t.contains('absent') ||
        t.contains('absence') ||
        t.contains('lesson') ||
        t.contains('course') ||
        t.contains('curriculum') ||
        m.contains('امتحان') ||
        m.contains('اختبار') ||
        m.contains('واجب') ||
        m.contains('درجة') ||
        m.contains('غياب') ||
        m.contains('حضور') ||
        m.contains('كويز') ||
        m.contains('درس') ||
        m.contains('محاضرة') ||
        m.contains('منهج')) {
      return NotificationCategoryFilter.academic;
    }

    return NotificationCategoryFilter.general;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final isAr = AppLocalizations.of(context).isArabic;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isNarrow = width < 360;
          final isMobile = width < 720;
          final isDesktop = width >= 1024;
          final horizontalPadding = isNarrow ? 12.0 : (isMobile ? 16.0 : 24.0);

          return Scaffold(
            backgroundColor: backgroundColor,
            body: SafeArea(
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  final vm = widget.viewModel;
                  final allNotifs = vm.notifications;

                  final academicNotifs = allNotifs
                      .where(
                        (n) =>
                            _resolveCategory(n) ==
                            NotificationCategoryFilter.academic,
                      )
                      .toList();
                  final financialNotifs = allNotifs
                      .where(
                        (n) =>
                            _resolveCategory(n) ==
                            NotificationCategoryFilter.financial,
                      )
                      .toList();
                  final generalNotifs = allNotifs
                      .where(
                        (n) =>
                            _resolveCategory(n) ==
                            NotificationCategoryFilter.general,
                      )
                      .toList();

                  // Category filter
                  List<AppNotification> currentList = switch (_selectedFilter) {
                    NotificationCategoryFilter.academic => academicNotifs,
                    NotificationCategoryFilter.financial => financialNotifs,
                    NotificationCategoryFilter.general => generalNotifs,
                    NotificationCategoryFilter.all => allNotifs,
                  };

                  // Unread filter
                  if (_onlyUnread) {
                    currentList =
                        currentList.where((n) => !n.isRead).toList();
                  }

                  // Search query filter
                  if (_searchQuery.trim().isNotEmpty) {
                    final q = _searchQuery.trim().toLowerCase();
                    currentList = currentList.where((n) {
                      final localizedTitle = NotificationLocalizer.localizeTitle(
                        n.title,
                        isArabic: isAr,
                      ).toLowerCase();
                      final localizedMsg = NotificationLocalizer.localizeMessage(
                        n.message,
                        isArabic: isAr,
                      ).toLowerCase();
                      final rawTitle = n.title.toLowerCase();
                      final rawMsg = n.message.toLowerCase();

                      return localizedTitle.contains(q) ||
                          localizedMsg.contains(q) ||
                          rawTitle.contains(q) ||
                          rawMsg.contains(q);
                    }).toList();
                  }

                  final unreadCount =
                      allNotifs.where((n) => !n.isRead).length;

                  return RefreshIndicator(
                    onRefresh: vm.loadNotifications,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 1200 : double.infinity,
                        ),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            // ─── Header & Top Actions ─────────────────────────
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  16,
                                  horizontalPadding,
                                  12,
                                ),
                                child: _buildExecutiveHeader(
                                  context: context,
                                  isDark: isDark,
                                  isAr: isAr,
                                  isNarrow: isNarrow,
                                  unreadCount: unreadCount,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  onMarkAllRead: unreadCount > 0
                                      ? vm.markAllRead
                                      : null,
                                  onRefresh: vm.loadNotifications,
                                ),
                              ),
                            ),

                            // ─── KPI Metrics Overview Strip ───────────────────
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                  vertical: 4,
                                ),
                                child: _buildKpiMetricsStrip(
                                  isDark: isDark,
                                  isAr: isAr,
                                  isNarrow: isNarrow,
                                  isMobile: isMobile,
                                  totalCount: allNotifs.length,
                                  unreadCount: unreadCount,
                                  academicCount: academicNotifs.length,
                                  financialCount: financialNotifs.length,
                                  selectedFilter: _selectedFilter,
                                  onlyUnread: _onlyUnread,
                                  onSelectKpi: (filter, onlyUnread) {
                                    setState(() {
                                      _selectedFilter = filter;
                                      _onlyUnread = onlyUnread;
                                    });
                                  },
                                ),
                              ),
                            ),

                            // ─── Search & Category Filter Section ─────────────
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  12,
                                  horizontalPadding,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSearchBar(
                                      context: context,
                                      isDark: isDark,
                                      isAr: isAr,
                                      isNarrow: isNarrow,
                                      borderColor: borderColor,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCategoryPillFilters(
                                      context: context,
                                      isDark: isDark,
                                      allCount: allNotifs.length,
                                      academicCount: academicNotifs.length,
                                      financialCount: financialNotifs.length,
                                      generalCount: generalNotifs.length,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ─── Notification List / Grid ─────────────────────
                            if (vm.isLoading && allNotifs.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (vm.errorMessage != null && allNotifs.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: _buildErrorState(
                                      context: context,
                                      message: vm.errorMessage!,
                                      onRetry: vm.loadNotifications,
                                    ),
                                  ),
                                ),
                              )
                            else if (currentList.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: _buildEmptyState(
                                      context: context,
                                      isDark: isDark,
                                      isAr: isAr,
                                      textSecondary: textSecondary,
                                      hasFilter: _selectedFilter !=
                                              NotificationCategoryFilter.all ||
                                          _onlyUnread ||
                                          _searchQuery.isNotEmpty,
                                      onResetFilters: () {
                                        setState(() {
                                          _selectedFilter =
                                              NotificationCategoryFilter.all;
                                          _onlyUnread = false;
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              )
                            else if (!isMobile)
                              // Tablet & Desktop 2-column Grid
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  4,
                                  horizontalPadding,
                                  32,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 14,
                                    mainAxisExtent: 168,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final notif = currentList[index];
                                      return _ModernNotificationCard(
                                        key: ValueKey(notif.id),
                                        notification: notif,
                                        isDark: isDark,
                                        isAr: isAr,
                                        isCompact: false,
                                        category: _resolveCategory(notif),
                                        onTap: () => _handleNotificationTap(
                                          notif,
                                          vm,
                                        ),
                                        onMarkRead: !notif.isRead
                                            ? () => vm.markRead(notif.id)
                                            : null,
                                      );
                                    },
                                    childCount: currentList.length,
                                  ),
                                ),
                              )
                            else
                              // Mobile 1-column List
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  4,
                                  horizontalPadding,
                                  32,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final notif = currentList[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _ModernNotificationCard(
                                          key: ValueKey(notif.id),
                                          notification: notif,
                                          isDark: isDark,
                                          isAr: isAr,
                                          isCompact: isNarrow,
                                          category: _resolveCategory(notif),
                                          onTap: () => _handleNotificationTap(
                                            notif,
                                            vm,
                                          ),
                                          onMarkRead: !notif.isRead
                                              ? () => vm.markRead(notif.id)
                                              : null,
                                        ),
                                      );
                                    },
                                    childCount: currentList.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildExecutiveHeader({
    required BuildContext context,
    required bool isDark,
    required bool isAr,
    required bool isNarrow,
    required int unreadCount,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback? onMarkAllRead,
    required VoidCallback onRefresh,
  }) {
    return Row(
      children: [
        // Glowing Icon Badge
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Title and Live Unread Badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    isAr ? 'مركز الإشعارات' : 'Notifications',
                    style: AppTypography.titleLarge(textPrimary).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: isNarrow ? 16 : 19,
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        isAr ? '$unreadCount جديد' : '$unreadCount New',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAr ? 'محدّث بالكامل' : 'All Read',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isAr
                    ? 'متابعة أحدث التنبيهات والمهام الدراسية'
                    : 'Track academic alerts, assignments & fees',
                style: AppTypography.caption(textSecondary).copyWith(
                  fontSize: isNarrow ? 10.5 : 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Mark All Read Button
        if (unreadCount > 0)
          Tooltip(
            message: isAr ? 'تحديد الكل كمقروء' : 'Mark all read',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMarkAllRead,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 8 : 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      if (!isNarrow) ...[
                        const SizedBox(width: 6),
                        Text(
                          isAr ? 'قراءة الكل' : 'Mark Read',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(width: 4),

        // Refresh Button
        Tooltip(
          message: isAr ? 'تحديث' : 'Refresh',
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: onRefresh,
            visualDensity: VisualDensity.compact,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  // ─── KPI Metrics Overview Strip ─────────────────────────────────────────────
  Widget _buildKpiMetricsStrip({
    required bool isDark,
    required bool isAr,
    required bool isNarrow,
    required bool isMobile,
    required int totalCount,
    required int unreadCount,
    required int academicCount,
    required int financialCount,
    required NotificationCategoryFilter selectedFilter,
    required bool onlyUnread,
    required void Function(NotificationCategoryFilter filter, bool onlyUnread)
        onSelectKpi,
  }) {
    final cards = [
      _KpiData(
        title: isAr ? 'إجمالي التنبيهات' : 'Total Alerts',
        count: totalCount,
        icon: Icons.all_inbox_rounded,
        color: const Color(0xFF6366F1),
        isActive:
            selectedFilter == NotificationCategoryFilter.all && !onlyUnread,
        onTap: () => onSelectKpi(NotificationCategoryFilter.all, false),
      ),
      _KpiData(
        title: isAr ? 'غير مقروءة ⚡' : 'Unread',
        count: unreadCount,
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xFFF59E0B),
        isActive: onlyUnread,
        onTap: () => onSelectKpi(selectedFilter, !onlyUnread),
      ),
      _KpiData(
        title: isAr ? 'أكاديمية ودراسية' : 'Academic',
        count: academicCount,
        icon: Icons.school_rounded,
        color: const Color(0xFF3B82F6),
        isActive:
            selectedFilter == NotificationCategoryFilter.academic && !onlyUnread,
        onTap: () => onSelectKpi(NotificationCategoryFilter.academic, false),
      ),
      _KpiData(
        title: isAr ? 'مالية ومدفوعات' : 'Financial',
        count: financialCount,
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981),
        isActive:
            selectedFilter == NotificationCategoryFilter.financial &&
            !onlyUnread,
        onTap: () => onSelectKpi(NotificationCategoryFilter.financial, false),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final item = cards[i];
            return SizedBox(
              width: isNarrow ? 128 : 142,
              child: _buildKpiCard(item: item, isDark: isDark),
            );
          },
        ),
      );
    }

    return Row(
      children: cards
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildKpiCard(item: item, isDark: isDark),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKpiCard({required _KpiData item, required bool isDark}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: item.isActive
                ? item.color.withValues(alpha: isDark ? 0.22 : 0.14)
                : (isDark
                    ? const Color(0xFF161616)
                    : Colors.white.withValues(alpha: 0.9)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isActive
                  ? item.color
                  : (isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFE5E7EB)),
              width: item.isActive ? 1.4 : 0.8,
            ),
            boxShadow: item.isActive
                ? [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.count}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: item.isActive
                            ? item.color
                            : (isDark ? Colors.white : Colors.black87),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  // ─── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar({
    required BuildContext context,
    required bool isDark,
    required bool isAr,
    required bool isNarrow,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          hintText: isAr
              ? 'ابحث في التنبيهات (امتحان، إيصال، واجب...)'
              : 'Search alerts, exams, homework, fees...',
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.7),
            fontSize: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: textSecondary,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ─── Category Filter Pills ──────────────────────────────────────────────────
  Widget _buildCategoryPillFilters({
    required BuildContext context,
    required bool isDark,
    required int allCount,
    required int academicCount,
    required int financialCount,
    required int generalCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(
            label: context.tr('الكل'),
            count: allCount,
            filter: NotificationCategoryFilter.all,
            icon: Icons.inbox_rounded,
            activeColor: AppColors.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: context.tr('أكاديمية 📚'),
            count: academicCount,
            filter: NotificationCategoryFilter.academic,
            icon: Icons.school_rounded,
            activeColor: const Color(0xFF3B82F6),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: context.tr('مالية 💳'),
            count: financialCount,
            filter: NotificationCategoryFilter.financial,
            icon: Icons.payments_rounded,
            activeColor: const Color(0xFF10B981),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: context.tr('تنبيهات عامة 📢'),
            count: generalCount,
            filter: NotificationCategoryFilter.general,
            icon: Icons.campaign_rounded,
            activeColor: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required NotificationCategoryFilter filter,
    required IconData icon,
    required Color activeColor,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = filter),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.16)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? activeColor
                      : (isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade800),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
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
    );
  }

  // ─── Empty & Error States ───────────────────────────────────────────────────
  Widget _buildEmptyState({
    required BuildContext context,
    required bool isDark,
    required bool isAr,
    required Color textSecondary,
    required bool hasFilter,
    required VoidCallback onResetFilters,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: hasFilter
                ? Colors.amber.withValues(alpha: 0.12)
                : Colors.teal.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            hasFilter
                ? Icons.filter_list_off_rounded
                : Icons.mark_email_read_rounded,
            size: 36,
            color: hasFilter ? Colors.amber.shade700 : Colors.teal,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          hasFilter
              ? (isAr ? 'لا توجد نتائج مطابقة' : 'No matching notifications')
              : (isAr
                  ? 'صندوق التنبيهات منظم بالكامل'
                  : 'Inbox completely caught up'),
          style: AppTypography.titleMedium(
            isDark ? Colors.white : Colors.black87,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            hasFilter
                ? (isAr
                    ? 'لم يتم العثور على إشعارات تطابق خيارات البحث والتصنيف الحالية.'
                    : 'No notifications matched your active filter or search keywords.')
                : (isAr
                    ? 'لا توجد إشعارات جديدة حالياً، سيتم إعلامك بأي جديد فور صدوره.'
                    : 'There are no notifications here at the moment.'),
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(textSecondary),
          ),
        ),
        if (hasFilter) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onResetFilters,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              isAr ? 'إعادة ضبط الفلاتر' : 'Reset Filters',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState({
    required BuildContext context,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(
          '${context.tr('Error')}: $message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(context.tr('Retry')),
        ),
      ],
    );
  }

  // ─── Notification Tap Handler ───────────────────────────────────────────────
  void _handleNotificationTap(
    AppNotification notif,
    NotificationCenterViewModel vm,
  ) {
    if (!notif.isRead) {
      vm.markRead(notif.id);
    }
    final localHandler = widget.onNotificationTap;
    if (localHandler != null) {
      localHandler(notif);
      return;
    }
    final pushService =
        GetIt.instance.isRegistered<PushNotificationService>()
            ? GetIt.instance<PushNotificationService>()
            : PushNotificationService(
                GetIt.instance<SupabaseClientWrapper>(),
              );
    pushService.handleNotificationTap({
      'type': notif.type,
      'reference_id': notif.referenceId,
      'id': notif.id,
      'title': notif.title,
      'message': notif.message,
    });
  }
}

// ─── Modern Notification Card Widget ─────────────────────────────────────────
class _ModernNotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;
  final bool isAr;
  final bool isCompact;
  final NotificationCategoryFilter category;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  const _ModernNotificationCard({
    super.key,
    required this.notification,
    required this.isDark,
    required this.isAr,
    required this.isCompact,
    required this.category,
    required this.onTap,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final typeLower = notification.type.toLowerCase();
    final isAbsence = typeLower.contains('absent') ||
        notification.title.contains('غياب') ||
        notification.message.contains('غياب');

    Color accentColor;
    IconData catIcon;
    String catLabel;
    String actionHint;

    if (isAbsence) {
      accentColor = const Color(0xFFEF4444); // Red/Coral
      catIcon = Icons.person_off_rounded;
      catLabel = isAr ? 'غياب وحضور' : 'Attendance';
      actionHint = isAr ? 'عرض سجل الحضور' : 'View Attendance';
    } else {
      switch (category) {
        case NotificationCategoryFilter.academic:
          accentColor = const Color(0xFF2563EB); // Royal Blue
          catIcon = Icons.school_rounded;
          catLabel = isAr ? 'أكاديمي' : 'Academic';
          actionHint = isAr ? 'عرض التفاصيل والمهام' : 'Open Details';
          break;
        case NotificationCategoryFilter.financial:
          accentColor = const Color(0xFF059669); // Emerald Green
          catIcon = Icons.receipt_long_rounded;
          catLabel = isAr ? 'مالي كاش' : 'Financial';
          actionHint = isAr ? 'عرض الفاتورة والإيصال' : 'View Receipt';
          break;
        case NotificationCategoryFilter.general:
        default:
          accentColor = const Color(0xFFD97706); // Warm Amber
          catIcon = Icons.campaign_rounded;
          catLabel = isAr ? 'تنبيه سنتر' : 'Center Alert';
          actionHint = isAr ? 'عرض التنبيه' : 'View Notice';
      }
    }

    final localizedTitle = NotificationLocalizer.localizeTitle(
      notification.title,
      isArabic: isAr,
    );
    final localizedMessage = NotificationLocalizer.localizeMessage(
      notification.message,
      isArabic: isAr,
    );
    final localizedCategory = NotificationLocalizer.localizeCategory(
      catLabel,
      isArabic: isAr,
    );
    final formattedTime = _formatSmartNotificationTime(
      notification.createdAt,
      isArabic: isAr,
    );

    return GlassCard(
      padding: EdgeInsets.zero,
      color: notification.isRead
          ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
          : (isDark
              ? accentColor.withValues(alpha: 0.08)
              : accentColor.withValues(alpha: 0.04)),
      borderColor: notification.isRead
          ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
          : accentColor.withValues(alpha: 0.45),
      boxShadow: !notification.isRead
          ? [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Strip: Category Badge + Timestamp + Unread Indicator
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.28),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(catIcon, size: 11, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          localizedCategory,
                          style: TextStyle(
                            fontSize: 10,
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: AppTypography.caption(textSecondary).copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!notification.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Notification Body: Icon + Title & Message
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isCompact ? 36 : 40,
                    height: isCompact ? 36 : 40,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      catIcon,
                      color: accentColor,
                      size: isCompact ? 18 : 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedTitle,
                          style: AppTypography.titleSmall(textPrimary).copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            fontSize: isCompact ? 13 : 14,
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          localizedMessage,
                          style: AppTypography.bodySmall(textSecondary).copyWith(
                            fontSize: isCompact ? 11 : 12,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Bottom Action Footer
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionHint,
                        style: TextStyle(
                          fontSize: isCompact ? 9.5 : 10.5,
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        isAr
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 13,
                        color: accentColor,
                      ),
                    ],
                  ),
                  if (!notification.isRead && onMarkRead != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onMarkRead,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 12,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isAr ? 'تحديد كمقروء' : 'Mark Read',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
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

// ─── Helper Classes & Functions ───────────────────────────────────────────────
class _KpiData {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _KpiData({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });
}

String _formatSmartNotificationTime(DateTime createdAt, {required bool isArabic}) {
  final now = DateTime.now();
  final difference = now.difference(createdAt);

  if (difference.inSeconds < 60) {
    return isArabic ? 'الآن' : 'Just now';
  } else if (difference.inMinutes < 60) {
    final mins = difference.inMinutes;
    return isArabic ? 'منذ $mins د' : '${mins}m ago';
  } else if (difference.inHours < 24 && createdAt.day == now.day) {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return isArabic ? 'اليوم $hour:$minute' : 'Today $hour:$minute';
  } else if (difference.inDays == 1 ||
      (difference.inHours < 48 && createdAt.day == now.day - 1)) {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return isArabic ? 'أمس $hour:$minute' : 'Yesterday $hour:$minute';
  } else {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}
