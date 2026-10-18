import 'package:flutter/material.dart';

import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/communication/domain/models/notification.dart';

// ─── Filter Category Enum for Notifications ──────────────────────────────────

enum ParentNotificationCategory {
  all,
  unread,
  academic,
  attendance,
  financial,
  general,
}

// ─── Main Parent Notifications Tab Widget ────────────────────────────────────

class ParentNotificationsTab extends StatefulWidget {
  final List<AppNotification> notifications;
  final int unreadCount;
  final Student? child;
  final VoidCallback onMarkAllRead;
  final ValueChanged<AppNotification> onNotificationTap;
  final ValueChanged<AppNotification>? onMarkRead;

  const ParentNotificationsTab({
    super.key,
    required this.notifications,
    required this.unreadCount,
    required this.child,
    required this.onMarkAllRead,
    required this.onNotificationTap,
    this.onMarkRead,
  });

  @override
  State<ParentNotificationsTab> createState() => _ParentNotificationsTabState();
}

class _ParentNotificationsTabState extends State<ParentNotificationsTab> {
  ParentNotificationCategory _selectedCategory = ParentNotificationCategory.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter by category
    final categoryFiltered = widget.notifications.where((n) {
      final t = n.type.toLowerCase();
      return switch (_selectedCategory) {
        ParentNotificationCategory.all => true,
        ParentNotificationCategory.unread => !n.isRead,
        ParentNotificationCategory.academic =>
          t.contains('exam') ||
              t.contains('grade') ||
              t.contains('homework') ||
              t.contains('quiz') ||
              t.contains('score') ||
              t.contains('assignment'),
        ParentNotificationCategory.attendance =>
          t.contains('attendance') ||
              t.contains('absence') ||
              t.contains('late') ||
              t.contains('session') ||
              t.contains('excuse') ||
              t.contains('leave'),
        ParentNotificationCategory.financial =>
          t.contains('payment') ||
              t.contains('invoice') ||
              t.contains('receipt') ||
              t.contains('fee') ||
              t.contains('money'),
        ParentNotificationCategory.general =>
          !t.contains('exam') &&
              !t.contains('grade') &&
              !t.contains('homework') &&
              !t.contains('attendance') &&
              !t.contains('absence') &&
              !t.contains('payment') &&
              !t.contains('invoice'),
      };
    }).toList();

    // Filter by search query
    final displayed = categoryFiltered.where((n) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return n.title.toLowerCase().contains(q) || n.message.toLowerCase().contains(q);
    }).toList();

    // Counts for categories
    final unreadTotal = widget.notifications.where((n) => !n.isRead).length;
    final academicTotal = widget.notifications.where((n) {
      final t = n.type.toLowerCase();
      return t.contains('exam') ||
          t.contains('grade') ||
          t.contains('homework') ||
          t.contains('quiz') ||
          t.contains('score');
    }).length;
    final attendanceTotal = widget.notifications.where((n) {
      final t = n.type.toLowerCase();
      return t.contains('attendance') ||
          t.contains('absence') ||
          t.contains('late') ||
          t.contains('session') ||
          t.contains('excuse');
    }).length;
    final financialTotal = widget.notifications.where((n) {
      final t = n.type.toLowerCase();
      return t.contains('payment') ||
          t.contains('invoice') ||
          t.contains('receipt') ||
          t.contains('fee');
    }).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 380;
        final isMobile = screenWidth < 650;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Notification Center Hero
            _ExecutiveNotificationHero(
              child: widget.child,
              unreadCount: unreadTotal,
              totalCount: widget.notifications.length,
              isDark: isDark,
              isNarrow: isNarrow,
              isMobile: isMobile,
              onMarkAllRead: widget.notifications.isEmpty || unreadTotal == 0
                  ? null
                  : widget.onMarkAllRead,
            ),
            const SizedBox(height: 16),

            // 2. Search Field Bar
            _NotificationSearchBar(
              controller: _searchController,
              searchQuery: _searchQuery,
              isDark: isDark,
              isNarrow: isNarrow,
              onChanged: (val) => setState(() => _searchQuery = val),
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
            const SizedBox(height: 14),

            // 3. Category Filter Bar
            _NotificationCategoryFilterBar(
              selectedCategory: _selectedCategory,
              unreadCount: unreadTotal,
              academicCount: academicTotal,
              attendanceCount: attendanceTotal,
              financialCount: financialTotal,
              isDark: isDark,
              isNarrow: isNarrow,
              onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),
            ),
            const SizedBox(height: 18),

            // 4. Notifications List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: PortalSectionTitle(
                    title: _sectionTitleForCategory(_selectedCategory),
                    subtitle: 'إجمالي ${displayed.length} تنبيهات متاحة بالعرض الحالي.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 5. Notifications List / Empty State
            if (displayed.isEmpty)
              _buildEmptyNotificationsCard(
                category: _selectedCategory,
                hasSearch: _searchQuery.isNotEmpty,
                isDark: isDark,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayed.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final notif = displayed[index];
                  return _NotificationCard(
                    notification: notif,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: () => widget.onNotificationTap(notif),
                    onMarkRead: () {
                      if (widget.onMarkRead != null && !notif.isRead) {
                        widget.onMarkRead!(notif);
                      }
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }

  static String _sectionTitleForCategory(ParentNotificationCategory cat) {
    return switch (cat) {
      ParentNotificationCategory.all => 'كافة الإشعارات والتنبيهات',
      ParentNotificationCategory.unread => 'الإشعارات الجديدة غير المقروءة 🔔',
      ParentNotificationCategory.academic => 'تنبيهات الدرجات والاختبارات 📝',
      ParentNotificationCategory.attendance => 'تنبيهات الحضور والغياب 📅',
      ParentNotificationCategory.financial => 'تنبيهات الرسوم والمدفوعات 💳',
      ParentNotificationCategory.general => 'إعلانات وتنبيهات عامة 📢',
    };
  }
}

// ─── 1. Executive Notification Center Hero ───────────────────────────────────

class _ExecutiveNotificationHero extends StatelessWidget {
  final Student? child;
  final int unreadCount;
  final int totalCount;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final VoidCallback? onMarkAllRead;

  const _ExecutiveNotificationHero({
    required this.child,
    required this.unreadCount,
    required this.totalCount,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final accentColor =
        hasUnread ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    final statusBadge = hasUnread ? '$unreadCount تنبيهات جديدة 🔔' : 'محدث بالكامل ✨';
    final statusLabel = hasUnread
        ? 'توجد تنبيهات جديدة بانتظار اطلاع ولي الأمر'
        : 'تمت قراءة والاطلاع على كافة تنبيهات السنتر بنجاح';

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.40 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
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
            // Top Row: Bell Dial Badge + Student Title & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing Bell Badge Container
                Container(
                  width: isNarrow ? 50 : 58,
                  height: isNarrow ? 50 : 58,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        hasUnread
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        size: isNarrow ? 26 : 30,
                        color: accentColor,
                      ),
                      if (hasUnread)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Status
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
                            child?.fullName ?? 'ولي الأمر',
                            style: TextStyle(
                              fontSize: isNarrow ? 14 : 15.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              statusBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
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
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'كود الطالب: ${child?.studentCode ?? "---"} • مركز التنبيهات والرسائل الفورية',
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

            // Metric Counters Row: إجمالي التنبيهات / غير مقروءة / حالة المزامنة
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 8 : 12,
                vertical: 9,
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
                    child: _buildCountMetric(
                      label: 'إجمالي الإشعارات',
                      count: totalCount,
                      color: AppColors.parentRole,
                      icon: Icons.notifications_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  Expanded(
                    child: _buildCountMetric(
                      label: 'غير مقروءة',
                      count: unreadCount,
                      color: unreadCount > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      icon: Icons.mark_email_unread_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  Expanded(
                    child: _buildCountMetric(
                      label: 'حالة الاستقبال',
                      countText: 'مفعلة ⚡',
                      color: const Color(0xFF10B981),
                      icon: Icons.wifi_tethering_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action: Mark all read button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: hasUnread
                        ? AppColors.parentRole.withValues(alpha: 0.5)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                onPressed: onMarkAllRead,
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'تحديد كافة الإشعارات كمقروءة ✔️',
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

  Widget _buildCountMetric({
    required String label,
    int? count,
    String? countText,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                countText ?? '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: isNarrow ? 9 : 10,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── 2. Search Field Bar ─────────────────────────────────────────────────────

class _NotificationSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _NotificationSearchBar({
    required this.controller,
    required this.searchQuery,
    required this.isDark,
    required this.isNarrow,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: isNarrow ? 12 : 13,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
          hintText: 'بحث في عنوان أو محتوى الإشعار... 🔍',
          hintStyle: TextStyle(
            fontSize: isNarrow ? 11 : 12,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}

// ─── 3. Category Filter Switcher Bar ─────────────────────────────────────────

class _NotificationCategoryFilterBar extends StatelessWidget {
  final ParentNotificationCategory selectedCategory;
  final int unreadCount;
  final int academicCount;
  final int attendanceCount;
  final int financialCount;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<ParentNotificationCategory> onCategoryChanged;

  const _NotificationCategoryFilterBar({
    required this.selectedCategory,
    required this.unreadCount,
    required this.academicCount,
    required this.attendanceCount,
    required this.financialCount,
    required this.isDark,
    required this.isNarrow,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (
        category: ParentNotificationCategory.all,
        label: 'الكل',
        icon: Icons.all_inbox_rounded,
        count: null,
      ),
      (
        category: ParentNotificationCategory.unread,
        label: 'غير مقروءة',
        icon: Icons.mark_email_unread_rounded,
        count: unreadCount > 0 ? unreadCount : null,
      ),
      (
        category: ParentNotificationCategory.academic,
        label: 'الدرجات والاختبارات',
        icon: Icons.military_tech_rounded,
        count: academicCount > 0 ? academicCount : null,
      ),
      (
        category: ParentNotificationCategory.attendance,
        label: 'الحضور والغياب',
        icon: Icons.fact_check_rounded,
        count: attendanceCount > 0 ? attendanceCount : null,
      ),
      (
        category: ParentNotificationCategory.financial,
        label: 'الرسوم والمصروفات',
        icon: Icons.payments_rounded,
        count: financialCount > 0 ? financialCount : null,
      ),
      (
        category: ParentNotificationCategory.general,
        label: 'إعلانات السنتر',
        icon: Icons.campaign_rounded,
        count: null,
      ),
    ];

    return SizedBox(
      height: 40,
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
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.parentRole
                      : (isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.8)
                          : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.parentRole
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 1.4 : 0.8,
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
                      size: 13,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 5),
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
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : (item.category == ParentNotificationCategory.unread
                                  ? const Color(0xFFEF4444)
                                  : AppColors.parentRole.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${item.count}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : (item.category == ParentNotificationCategory.unread
                                    ? Colors.white
                                    : AppColors.parentRole),
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

// ─── 4. Executive Notification Card ──────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.isNarrow,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final t = notification.type.toLowerCase();
    final isUnread = !notification.isRead;

    final (IconData icon, Color color, String typeLabel) = _resolveTypeMetadata(t);

    final dateStr =
        '${notification.createdAt.year}-${notification.createdAt.month.toString().padLeft(2, '0')}-${notification.createdAt.day.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 10 : 12),
      color: isUnread
          ? color.withValues(alpha: isDark ? 0.12 : 0.06)
          : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
      borderColor: isUnread
          ? color.withValues(alpha: 0.35)
          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Icon Container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),

              // Title & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: isNarrow ? 12.5 : 13.5,
                              fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                width: 0.6,
                              ),
                            ),
                            child: const Text(
                              'جديد',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$typeLabel • $dateStr',
                      style: TextStyle(
                        fontSize: 9.5,
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
          const SizedBox(height: 8),

          // Message Body
          Text(
            notification.message,
            style: TextStyle(
              fontSize: isNarrow ? 11 : 12,
              height: 1.45,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),

          const SizedBox(height: 8),

          // Bottom Bar: Tap to navigate action hint
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 13,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'انقر للانتقال للتفاصيل',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onMarkRead,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'تحديد كمقروء',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static (IconData, Color, String) _resolveTypeMetadata(String t) {
    if (t.contains('payment') || t.contains('invoice') || t.contains('receipt')) {
      return (Icons.payments_rounded, const Color(0xFF10B981), 'شؤون مالية ومصروفات');
    }
    if (t.contains('exam') || t.contains('grade') || t.contains('homework') || t.contains('quiz')) {
      return (Icons.military_tech_rounded, const Color(0xFF8B5CF6), 'تحصيل واختبارات');
    }
    if (t.contains('attendance') || t.contains('absence') || t.contains('late') || t.contains('session')) {
      return (Icons.fact_check_rounded, const Color(0xFF3B82F6), 'حضور وغياب');
    }
    if (t.contains('warn') || t.contains('alert') || t.contains('danger')) {
      return (Icons.warning_amber_rounded, const Color(0xFFEF4444), 'تنبيه عاجل');
    }
    return (Icons.campaign_rounded, const Color(0xFF06B6D4), 'إعلان من السنتر');
  }
}

// ─── 5. Empty Notifications Card ─────────────────────────────────────────────

Widget _buildEmptyNotificationsCard({
  required ParentNotificationCategory category,
  required bool hasSearch,
  required bool isDark,
}) {
  final (String title, String subtitle, IconData icon) = hasSearch
      ? (
          'لم يتم العثور على نتائج',
          'لا توجد إشعارات مطابقة لكلمة البحث المدخلة. يرجى تجربة كلمات أخرى.',
          Icons.search_off_rounded
        )
      : switch (category) {
          ParentNotificationCategory.unread => (
              'جميع الإشعارات مقروءة ومحدثة 🎉',
              'رائع! لا توجد أي تنبيهات غير مقروءة حالياً في حسابك.',
              Icons.mark_email_read_rounded
            ),
          ParentNotificationCategory.academic => (
              'لا توجد تنبيهات اختبارات',
              'لم تسجل أي إشعارات خاصة بدرجات أو اختبارات الطالب حتى الآن.',
              Icons.military_tech_outlined
            ),
          ParentNotificationCategory.attendance => (
              'لا توجد تنبيهات غياب أو حضور',
              'سجل الحضور والغياب هادئ ولا توجد أي إشعارات مسجلة.',
              Icons.fact_check_outlined
            ),
          ParentNotificationCategory.financial => (
              'لا توجد تنبيهات مالية',
              'لا توجد مطالبات أو إيصالات سداد معلقة.',
              Icons.receipt_long_outlined
            ),
          _ => (
              'لا توجد إشعارات مسجلة حالياً',
              'ستظهر هنا كافة تنبيهات وتحديثات إدارة السنتر فور إرسالها لولي الأمر.',
              Icons.notifications_off_outlined
            ),
        };

  return GlassCard(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 34,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ),
  );
}
