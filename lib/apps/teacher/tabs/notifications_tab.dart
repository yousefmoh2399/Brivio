import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/notification_localizer.dart';
import '../../../core/network/supabase_client_wrapper.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../features/communication/domain/models/notification.dart';
import '../../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../../features/communication/presentation/viewmodels/notification_center_viewmodel.dart';

// ─── Filter Category Enum for Teacher Notifications ──────────────────────────

enum TeacherNotificationCategory {
  all,
  unread,
  submissions,
  requests,
  attendance,
  admin,
}

// ─── Main Teacher Notifications Tab Widget ───────────────────────────────────

class TeacherNotificationsTab extends StatefulWidget {
  final List<AppNotification>? notifications;
  final int? unreadCount;
  final NotificationCenterViewModel? viewModel;
  final ValueChanged<AppNotification>? onNotificationTap;
  final ValueChanged<AppNotification>? onMarkRead;
  final VoidCallback? onMarkAllRead;
  final Future<void> Function()? onRefresh;

  const TeacherNotificationsTab({
    super.key,
    this.notifications,
    this.unreadCount,
    this.viewModel,
    this.onNotificationTap,
    this.onMarkRead,
    this.onMarkAllRead,
    this.onRefresh,
  });

  @override
  State<TeacherNotificationsTab> createState() =>
      _TeacherNotificationsTabState();
}

class _TeacherNotificationsTabState extends State<TeacherNotificationsTab> {
  TeacherNotificationCategory _selectedCategory =
      TeacherNotificationCategory.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyUnread = false;

  NotificationCenterViewModel? _internalViewModel;

  NotificationCenterViewModel get _effectiveViewModel {
    if (widget.viewModel != null) return widget.viewModel!;
    _internalViewModel ??= NotificationCenterViewModel(
      GetIt.instance<INotificationRepository>(),
    );
    return _internalViewModel!;
  }

  @override
  void initState() {
    super.initState();
    if (widget.notifications == null && widget.viewModel == null) {
      _effectiveViewModel.loadNotifications();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _internalViewModel?.dispose();
    super.dispose();
  }

  List<AppNotification> get _allNotifications {
    if (widget.notifications != null) {
      return widget.notifications!;
    }
    return _effectiveViewModel.notifications;
  }

  int get _allUnreadCount {
    if (widget.unreadCount != null) {
      return widget.unreadCount!;
    }
    return _effectiveViewModel.unreadCount;
  }

  Future<void> _handleRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
      return;
    }
    await _effectiveViewModel.loadNotifications();
  }

  void _handleMarkAllRead() {
    if (widget.onMarkAllRead != null) {
      widget.onMarkAllRead!();
      return;
    }
    _effectiveViewModel.markAllRead();
  }

  void _handleMarkSingleRead(AppNotification notification) {
    if (widget.onMarkRead != null) {
      widget.onMarkRead!(notification);
      return;
    }
    _effectiveViewModel.markRead(notification.id);
  }

  void _handleTap(AppNotification notification) {
    if (!notification.isRead) {
      _handleMarkSingleRead(notification);
    }
    if (widget.onNotificationTap != null) {
      widget.onNotificationTap!(notification);
      return;
    }

    final pushService = GetIt.instance.isRegistered<PushNotificationService>()
        ? GetIt.instance<PushNotificationService>()
        : PushNotificationService(GetIt.instance<SupabaseClientWrapper>());

    pushService.handleNotificationTap({
      'type': notification.type,
      'reference_id': notification.referenceId,
      'id': notification.id,
      'title': notification.title,
      'message': notification.message,
    });
  }

  static TeacherNotificationCategory resolveCategory(AppNotification n) {
    final t = n.type.toLowerCase();
    final text = '${n.title} ${n.message}'.toLowerCase();

    // 1. Exam reset & student assistance requests
    if (t.contains('reset') ||
        t.contains('retake') ||
        t.contains('request') ||
        t.contains('risk') ||
        t.contains('warning') ||
        text.contains('إعادة') ||
        text.contains('طلب إعادة') ||
        text.contains('تعثر') ||
        text.contains('خطر') ||
        text.contains('تحذير')) {
      return TeacherNotificationCategory.requests;
    }

    // 2. Student submissions, homework, exams, grading
    if (t.contains('submission') ||
        t.contains('solution') ||
        t.contains('homework') ||
        t.contains('exam') ||
        t.contains('quiz') ||
        t.contains('grading') ||
        t.contains('grade') ||
        text.contains('تسليم') ||
        text.contains('تصحيح') ||
        text.contains('واجب') ||
        text.contains('امتحان') ||
        text.contains('اختبار') ||
        text.contains('كويز') ||
        text.contains('حل الطالب')) {
      return TeacherNotificationCategory.submissions;
    }

    // 3. Attendance, absence, sessions
    if (t.contains('attendance') ||
        t.contains('absence') ||
        t.contains('absent') ||
        t.contains('session') ||
        t.contains('schedule') ||
        t.contains('class') ||
        text.contains('حضور') ||
        text.contains('غياب') ||
        text.contains('حصة') ||
        text.contains('مجموعة') ||
        text.contains('جدول')) {
      return TeacherNotificationCategory.attendance;
    }

    // 4. Center announcements, admin, billing/salary
    return TeacherNotificationCategory.admin;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isAr = AppLocalizations.of(context).isArabic;

    // Direct notifications list
    final allNotifs = _allNotifications;
    final totalUnread = _allUnreadCount;

    // Counts per category
    final submissionsCount = allNotifs
        .where((n) => resolveCategory(n) == TeacherNotificationCategory.submissions)
        .length;
    final requestsCount = allNotifs
        .where((n) => resolveCategory(n) == TeacherNotificationCategory.requests)
        .length;
    final attendanceCount = allNotifs
        .where((n) => resolveCategory(n) == TeacherNotificationCategory.attendance)
        .length;
    final adminCount = allNotifs
        .where((n) => resolveCategory(n) == TeacherNotificationCategory.admin)
        .length;

    // Category Filtering
    List<AppNotification> currentList = switch (_selectedCategory) {
      TeacherNotificationCategory.all => allNotifs,
      TeacherNotificationCategory.unread =>
        allNotifs.where((n) => !n.isRead).toList(),
      TeacherNotificationCategory.submissions => allNotifs
          .where(
            (n) => resolveCategory(n) == TeacherNotificationCategory.submissions,
          )
          .toList(),
      TeacherNotificationCategory.requests => allNotifs
          .where(
            (n) => resolveCategory(n) == TeacherNotificationCategory.requests,
          )
          .toList(),
      TeacherNotificationCategory.attendance => allNotifs
          .where(
            (n) => resolveCategory(n) == TeacherNotificationCategory.attendance,
          )
          .toList(),
      TeacherNotificationCategory.admin => allNotifs
          .where((n) => resolveCategory(n) == TeacherNotificationCategory.admin)
          .toList(),
    };

    // Unread toggle filter
    if (_onlyUnread && _selectedCategory != TeacherNotificationCategory.unread) {
      currentList = currentList.where((n) => !n.isRead).toList();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 360;
        final isMobile = screenWidth < 720;
        final isDesktop = screenWidth >= 1024;
        final horizontalPadding = isNarrow ? 12.0 : (isMobile ? 16.0 : 24.0);

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.teacherRole,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1100 : double.infinity,
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ─── 1. Executive Teacher Hero Header ─────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        10,
                      ),
                      child: _TeacherNotificationHero(
                        unreadCount: totalUnread,
                        totalCount: allNotifs.length,
                        isDark: isDark,
                        isNarrow: isNarrow,
                        isAr: isAr,
                        onMarkAllRead: totalUnread > 0 ? _handleMarkAllRead : null,
                        onRefresh: _handleRefresh,
                      ),
                    ),
                  ),

                  // ─── 2. KPI Metrics Strip ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 6,
                      ),
                      child: _TeacherKpiMetricsStrip(
                        isDark: isDark,
                        isAr: isAr,
                        isNarrow: isNarrow,
                        isMobile: isMobile,
                        totalCount: allNotifs.length,
                        unreadCount: totalUnread,
                        submissionsCount: submissionsCount,
                        requestsCount: requestsCount,
                        attendanceCount: attendanceCount,
                        selectedCategory: _selectedCategory,
                        onlyUnread: _onlyUnread,
                        onSelectCategory: (cat, onlyUnreadVal) {
                          setState(() {
                            _selectedCategory = cat;
                            _onlyUnread = onlyUnreadVal;
                          });
                        },
                      ),
                    ),
                  ),

                  // ─── 3. Search & Category Filters Bar ──────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        10,
                        horizontalPadding,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TeacherNotificationSearchBar(
                            controller: _searchController,
                            searchQuery: _searchQuery,
                            isDark: isDark,
                            isNarrow: isNarrow,
                            isAr: isAr,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            onClear: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                          const SizedBox(height: 12),
                          _TeacherCategoryFilterBar(
                            selectedCategory: _selectedCategory,
                            allCount: allNotifs.length,
                            unreadCount: totalUnread,
                            submissionsCount: submissionsCount,
                            requestsCount: requestsCount,
                            attendanceCount: attendanceCount,
                            adminCount: adminCount,
                            isDark: isDark,
                            isNarrow: isNarrow,
                            isAr: isAr,
                            onCategoryChanged: (cat) => setState(() {
                              _selectedCategory = cat;
                              _onlyUnread = false;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── 4. List Header Title ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _sectionTitleForCategory(_selectedCategory, isAr),
                              style: TextStyle(
                                fontSize: isNarrow ? 13 : 14.5,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${currentList.length} ${isAr ? 'تنبيه' : 'alerts'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ─── 5. Notifications List / Responsive Cards ──────────────
                  if (currentList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _TeacherEmptyStateCard(
                            category: _selectedCategory,
                            hasSearch: _searchQuery.trim().isNotEmpty,
                            isDark: isDark,
                            isAr: isAr,
                            onResetFilters: () {
                              setState(() {
                                _selectedCategory =
                                    TeacherNotificationCategory.all;
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
                    // Tablet & Desktop 2-column Grid with safe vertical layout
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        6,
                        horizontalPadding,
                        32,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 178,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final notif = currentList[index];
                            return _TeacherNotificationCard(
                              key: ValueKey(notif.id),
                              notification: notif,
                              isDark: isDark,
                              isAr: isAr,
                              isNarrow: false,
                              category: resolveCategory(notif),
                              onTap: () => _handleTap(notif),
                              onMarkRead: !notif.isRead
                                  ? () => _handleMarkSingleRead(notif)
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
                        6,
                        horizontalPadding,
                        32,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final notif = currentList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TeacherNotificationCard(
                                key: ValueKey(notif.id),
                                notification: notif,
                                isDark: isDark,
                                isAr: isAr,
                                isNarrow: isNarrow,
                                category: resolveCategory(notif),
                                onTap: () => _handleTap(notif),
                                onMarkRead: !notif.isRead
                                    ? () => _handleMarkSingleRead(notif)
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
    );
  }

  static String _sectionTitleForCategory(
    TeacherNotificationCategory cat,
    bool isAr,
  ) {
    if (!isAr) {
      return switch (cat) {
        TeacherNotificationCategory.all => 'All Academic Notifications',
        TeacherNotificationCategory.unread => 'Unread Alerts',
        TeacherNotificationCategory.submissions =>
          'Submissions & Pending Grading',
        TeacherNotificationCategory.requests =>
          'Re-Exam Requests & Assistance',
        TeacherNotificationCategory.attendance => 'Attendance & Session Logs',
        TeacherNotificationCategory.admin => 'Administration & Center Notices',
      };
    }
    return switch (cat) {
      TeacherNotificationCategory.all => 'كافة الإشعارات والتنبيهات الأكاديمية',
      TeacherNotificationCategory.unread => 'التنبيهات الجديدة غير المقروءة ⚡',
      TeacherNotificationCategory.submissions =>
        'تسليمات الطلاب بانتظار المراجعة والتصحيح 📝',
      TeacherNotificationCategory.requests =>
        'طلبات إعادة الاختبار ورادار المتابعة ⚠️',
      TeacherNotificationCategory.attendance => 'تنبيهات الحضور والغياب والحصص 📋',
      TeacherNotificationCategory.admin => 'إعلانات الإدارة وتنبيهات السنتر 📢',
    };
  }
}

// ─── 1. Executive Teacher Hero Banner ─────────────────────────────────────────

class _TeacherNotificationHero extends StatelessWidget {
  final int unreadCount;
  final int totalCount;
  final bool isDark;
  final bool isNarrow;
  final bool isAr;
  final VoidCallback? onMarkAllRead;
  final VoidCallback onRefresh;

  const _TeacherNotificationHero({
    required this.unreadCount,
    required this.totalCount,
    required this.isDark,
    required this.isNarrow,
    required this.isAr,
    required this.onMarkAllRead,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final accentColor =
        hasUnread ? AppColors.teacherRole : const Color(0xFF10B981);

    final statusBadge = hasUnread
        ? (isAr ? '$unreadCount تنبيه جديد ⚡' : '$unreadCount Unread ⚡')
        : (isAr ? 'محدّث بالكامل ✨' : 'All Caught Up ✨');

    final statusSubtitle = hasUnread
        ? (isAr
            ? 'توجد تسليمات أو طلبات طلاب بحاجة إلى مراجعة وتدقيق فوري.'
            : 'You have pending student submissions or exam requests.')
        : (isAr
            ? 'تم الاطلاع على كافة التنبيهات، صندوق المهام والتسليمات منظم.'
            : 'All notifications and grading queues are reviewed.');

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.22),
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
            // Top Section: Icon Avatar + Title & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing Bell Badge
                Container(
                  width: isNarrow ? 48 : 56,
                  height: isNarrow ? 48 : 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        hasUnread
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        size: isNarrow ? 26 : 30,
                        color: Colors.white,
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

                // Title & Badges
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
                            isAr
                                ? 'مركز تنبيهات المعلم 🔔'
                                : 'Teacher Notifications 🔔',
                            style: TextStyle(
                              fontSize: isNarrow ? 14.5 : 16.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
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
                      const SizedBox(height: 4),
                      Text(
                        statusSubtitle,
                        style: TextStyle(
                          fontSize: isNarrow ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bottom Actions Bar (Sync Status & Action Buttons)
            Row(
              children: [
                Icon(
                  Icons.hub_rounded,
                  size: 13,
                  color: accentColor,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    isAr
                        ? 'مزامنة مباشرة مع الفصول والواجبات'
                        : 'Live synced with classes & assignments',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasUnread && onMarkAllRead != null) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onMarkAllRead,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.teacherRole.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.teacherRole.withValues(alpha: 0.3),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.done_all_rounded,
                              size: 14,
                              color: AppColors.teacherRole,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAr ? 'تحديد الكل كمقروء' : 'Mark all read',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.teacherRole,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRefresh,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
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
}

// ─── 2. Teacher KPI Metrics Strip ─────────────────────────────────────────────

class _TeacherKpiMetricsStrip extends StatelessWidget {
  final bool isDark;
  final bool isAr;
  final bool isNarrow;
  final bool isMobile;
  final int totalCount;
  final int unreadCount;
  final int submissionsCount;
  final int requestsCount;
  final int attendanceCount;
  final TeacherNotificationCategory selectedCategory;
  final bool onlyUnread;
  final void Function(TeacherNotificationCategory cat, bool onlyUnread)
      onSelectCategory;

  const _TeacherKpiMetricsStrip({
    required this.isDark,
    required this.isAr,
    required this.isNarrow,
    required this.isMobile,
    required this.totalCount,
    required this.unreadCount,
    required this.submissionsCount,
    required this.requestsCount,
    required this.attendanceCount,
    required this.selectedCategory,
    required this.onlyUnread,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _TeacherKpiItem(
        title: isAr ? 'إجمالي التنبيهات' : 'All Alerts',
        count: totalCount,
        icon: Icons.all_inbox_rounded,
        color: AppColors.teacherRole,
        isActive:
            selectedCategory == TeacherNotificationCategory.all && !onlyUnread,
        onTap: () => onSelectCategory(TeacherNotificationCategory.all, false),
      ),
      _TeacherKpiItem(
        title: isAr ? 'غير مقروءة ⚡' : 'Unread ⚡',
        count: unreadCount,
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xFFF59E0B),
        isActive: onlyUnread ||
            selectedCategory == TeacherNotificationCategory.unread,
        onTap: () => onSelectCategory(TeacherNotificationCategory.unread, false),
      ),
      _TeacherKpiItem(
        title: isAr ? 'تسليمات وتصحيح' : 'Submissions',
        count: submissionsCount,
        icon: Icons.rate_review_rounded,
        color: const Color(0xFF3B82F6),
        isActive: selectedCategory == TeacherNotificationCategory.submissions &&
            !onlyUnread,
        onTap: () =>
            onSelectCategory(TeacherNotificationCategory.submissions, false),
      ),
      _TeacherKpiItem(
        title: isAr ? 'طلبات الإعادة' : 'Reset Requests',
        count: requestsCount,
        icon: Icons.replay_circle_filled_rounded,
        color: const Color(0xFFEC4899),
        isActive: selectedCategory == TeacherNotificationCategory.requests &&
            !onlyUnread,
        onTap: () =>
            onSelectCategory(TeacherNotificationCategory.requests, false),
      ),
      _TeacherKpiItem(
        title: isAr ? 'الحضور والحصص' : 'Attendance',
        count: attendanceCount,
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF10B981),
        isActive: selectedCategory == TeacherNotificationCategory.attendance &&
            !onlyUnread,
        onTap: () =>
            onSelectCategory(TeacherNotificationCategory.attendance, false),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 74,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final item = items[i];
            return SizedBox(
              width: isNarrow ? 124 : 138,
              child: _buildItemCard(item),
            );
          },
        ),
      );
    }

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildItemCard(item),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildItemCard(_TeacherKpiItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: item.isActive
                ? item.color.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark
                    ? const Color(0xFF18181B)
                    : Colors.white.withValues(alpha: 0.9)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isActive
                  ? item.color
                  : (isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFE4E4E7)),
              width: item.isActive ? 1.4 : 0.8,
            ),
            boxShadow: item.isActive
                ? [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.count}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherKpiItem {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _TeacherKpiItem({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });
}

// ─── 3. Search Bar ────────────────────────────────────────────────────────────

class _TeacherNotificationSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final bool isDark;
  final bool isNarrow;
  final bool isAr;
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _TeacherNotificationSearchBar({
    required this.controller,
    required this.searchQuery,
    required this.isDark,
    required this.isNarrow,
    required this.isAr,
    required this.textPrimary,
    required this.textSecondary,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
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
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          hintText: isAr
              ? 'ابحث في التنبيهات (اسم الطالب، الواجب، الامتحان...)'
              : 'Search alerts (student name, homework, exam...)',
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.7),
            fontSize: 11.5,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 19,
            color: textSecondary,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 17),
                  color: textSecondary,
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ─── 4. Category Filter Bar ───────────────────────────────────────────────────

class _TeacherCategoryFilterBar extends StatelessWidget {
  final TeacherNotificationCategory selectedCategory;
  final int allCount;
  final int unreadCount;
  final int submissionsCount;
  final int requestsCount;
  final int attendanceCount;
  final int adminCount;
  final bool isDark;
  final bool isNarrow;
  final bool isAr;
  final ValueChanged<TeacherNotificationCategory> onCategoryChanged;

  const _TeacherCategoryFilterBar({
    required this.selectedCategory,
    required this.allCount,
    required this.unreadCount,
    required this.submissionsCount,
    required this.requestsCount,
    required this.attendanceCount,
    required this.adminCount,
    required this.isDark,
    required this.isNarrow,
    required this.isAr,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (
        category: TeacherNotificationCategory.all,
        label: isAr ? 'الكل' : 'All',
        icon: Icons.all_inbox_rounded,
        count: allCount,
        color: AppColors.teacherRole,
      ),
      (
        category: TeacherNotificationCategory.unread,
        label: isAr ? 'غير مقروءة' : 'Unread',
        icon: Icons.mark_email_unread_rounded,
        count: unreadCount,
        color: const Color(0xFFF59E0B),
      ),
      (
        category: TeacherNotificationCategory.submissions,
        label: isAr ? 'تسليمات وتصحيح' : 'Submissions',
        icon: Icons.rate_review_rounded,
        count: submissionsCount,
        color: const Color(0xFF3B82F6),
      ),
      (
        category: TeacherNotificationCategory.requests,
        label: isAr ? 'طلبات الإعادة' : 'Requests',
        icon: Icons.replay_circle_filled_rounded,
        count: requestsCount,
        color: const Color(0xFFEC4899),
      ),
      (
        category: TeacherNotificationCategory.attendance,
        label: isAr ? 'الحضور والحصص' : 'Attendance',
        icon: Icons.fact_check_rounded,
        count: attendanceCount,
        color: const Color(0xFF10B981),
      ),
      (
        category: TeacherNotificationCategory.admin,
        label: isAr ? 'الإدارة والسنتر' : 'Admin & Center',
        icon: Icons.campaign_rounded,
        count: adminCount,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return SizedBox(
      height: 38,
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
                  horizontal: isNarrow ? 9 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? item.color
                      : (isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.85)
                          : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? item.color
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                    width: isSelected ? 1.4 : 0.8,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.3),
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
                          : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: isNarrow ? 11 : 12,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    if (item.count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${item.count}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : item.color,
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

// ─── 5. Executive Notification Card ──────────────────────────────────────────

class _TeacherNotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;
  final bool isAr;
  final bool isNarrow;
  final TeacherNotificationCategory category;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  const _TeacherNotificationCard({
    super.key,
    required this.notification,
    required this.isDark,
    required this.isAr,
    required this.isNarrow,
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

    final isUnread = !notification.isRead;
    final meta = _resolveCardMetadata(category, notification, isAr);

    final localizedTitle = NotificationLocalizer.localizeTitle(
      notification.title,
      isArabic: isAr,
    );
    final localizedMessage = NotificationLocalizer.localizeMessage(
      notification.message,
      isArabic: isAr,
    );
    final formattedTime = _formatTeacherSmartTime(
      notification.createdAt,
      isArabic: isAr,
    );

    return GlassCard(
      padding: EdgeInsets.zero,
      color: isUnread
          ? meta.color.withValues(alpha: isDark ? 0.12 : 0.05)
          : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
      borderColor: isUnread
          ? meta.color.withValues(alpha: 0.45)
          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      boxShadow: isUnread
          ? [
              BoxShadow(
                color: meta.color.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(isNarrow ? 10 : 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Strip: Category Badge + Timestamp + Unread Glow Dot
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: meta.color.withValues(alpha: 0.28),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(meta.icon, size: 11, color: meta.color),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              meta.label,
                              style: TextStyle(
                                fontSize: 10,
                                color: meta.color,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: textSecondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: meta.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: meta.color.withValues(alpha: 0.6),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 9),

              // Middle: Icon Box + Title & Message
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isNarrow ? 34 : 38,
                    height: isNarrow ? 34 : 38,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: meta.color.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      meta.icon,
                      color: meta.color,
                      size: isNarrow ? 17 : 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedTitle,
                          style: TextStyle(
                            fontSize: isNarrow ? 12.5 : 13.5,
                            fontWeight:
                                isUnread ? FontWeight.w900 : FontWeight.w700,
                            color: textPrimary,
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          localizedMessage,
                          style: TextStyle(
                            fontSize: isNarrow ? 11 : 12,
                            color: textSecondary,
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

              const SizedBox(height: 9),

              // Bottom Action Footer: CTA Hint + Mark Read button
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
                        meta.actionCta,
                        style: TextStyle(
                          fontSize: isNarrow ? 9.5 : 10.5,
                          color: meta.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        isAr
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 13,
                        color: meta.color,
                      ),
                    ],
                  ),
                  if (isUnread && onMarkRead != null)
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
                              const SizedBox(width: 3),
                              Text(
                                isAr ? 'تحديد كمقروء' : 'Mark Read',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w700,
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

  static _TeacherCardMetadata _resolveCardMetadata(
    TeacherNotificationCategory category,
    AppNotification notification,
    bool isAr,
  ) {
    final t = notification.type.toLowerCase();

    if (category == TeacherNotificationCategory.requests ||
        t.contains('reset') ||
        t.contains('retake')) {
      return _TeacherCardMetadata(
        icon: Icons.replay_circle_filled_rounded,
        color: const Color(0xFFF59E0B),
        label: isAr ? 'طلب إعادة ومتابعة' : 'Reset Request',
        actionCta: isAr ? 'مراجعة طلب الإعادة ⚠️' : 'Review Request ⚠️',
      );
    }

    if (category == TeacherNotificationCategory.submissions ||
        t.contains('submission') ||
        t.contains('homework') ||
        t.contains('exam')) {
      return _TeacherCardMetadata(
        icon: Icons.rate_review_rounded,
        color: AppColors.teacherRole,
        label: isAr ? 'تسليم وتصحيح' : 'Submission',
        actionCta: isAr ? 'الانتقال للتصحيح 📝' : 'Grade Submission 📝',
      );
    }

    if (category == TeacherNotificationCategory.attendance ||
        t.contains('attendance') ||
        t.contains('absence')) {
      return _TeacherCardMetadata(
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF0EA5E9),
        label: isAr ? 'حضور وحصص' : 'Attendance',
        actionCta: isAr ? 'عرض سجل الحضور 📋' : 'View Attendance 📋',
      );
    }

    return _TeacherCardMetadata(
      icon: Icons.campaign_rounded,
      color: const Color(0xFF8B5CF6),
      label: isAr ? 'إدارة وسنتر' : 'Center Alert',
      actionCta: isAr ? 'عرض تفاصيل التنبيه 📢' : 'View Notice 📢',
    );
  }
}

class _TeacherCardMetadata {
  final IconData icon;
  final Color color;
  final String label;
  final String actionCta;

  const _TeacherCardMetadata({
    required this.icon,
    required this.color,
    required this.label,
    required this.actionCta,
  });
}

// ─── 6. Empty State Card ──────────────────────────────────────────────────────

class _TeacherEmptyStateCard extends StatelessWidget {
  final TeacherNotificationCategory category;
  final bool hasSearch;
  final bool isDark;
  final bool isAr;
  final VoidCallback onResetFilters;

  const _TeacherEmptyStateCard({
    required this.category,
    required this.hasSearch,
    required this.isDark,
    required this.isAr,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final (String title, String subtitle, IconData icon) = hasSearch
        ? (
            isAr
                ? 'لم يتم العثور على نتائج'
                : 'No matching alerts found',
            isAr
                ? 'لا توجد إشعارات مطابقة لكلمة البحث المدخلة. جرّب كلمات أخرى.'
                : 'No notifications matched your active search query.',
            Icons.search_off_rounded,
          )
        : switch (category) {
            TeacherNotificationCategory.unread => (
                isAr
                    ? 'جميع الإشعارات مقروءة ومحدثة 🎉'
                    : 'All notifications read 🎉',
                isAr
                    ? 'رائع! لا توجد أي تنبيهات أو تسليمات معلقة بحاجة لقراءة حالياً.'
                    : 'Great! There are no unread notifications right now.',
                Icons.mark_email_read_rounded,
              ),
            TeacherNotificationCategory.submissions => (
                isAr
                    ? 'لا توجد تسليمات بانتظار التصحيح ✨'
                    : 'No pending submissions ✨',
                isAr
                    ? 'صندوق تسليمات الطلاب منتهٍ بالكامل ولا توجد واجبات غير مصححة.'
                    : 'All student submissions are graded and reviewed.',
                Icons.task_alt_rounded,
              ),
            TeacherNotificationCategory.requests => (
                isAr
                    ? 'لا توجد طلبات إعادة معلقة'
                    : 'No reset requests pending',
                isAr
                    ? 'لم يتم إرسال أي طلبات إعادة امتحانات من الطلاب حتى الآن.'
                    : 'There are no re-exam requests from your students.',
                Icons.replay_circle_filled_rounded,
              ),
            TeacherNotificationCategory.attendance => (
                isAr
                    ? 'سجل الحضور والغياب هادئ'
                    : 'Attendance logs are clear',
                isAr
                    ? 'لا توجد تنبيهات غياب أو حصص غير عادية مسجلة اليوم.'
                    : 'No irregular attendance or absence alerts logged.',
                Icons.fact_check_outlined,
              ),
            _ => (
                isAr
                    ? 'لا توجد إشعارات مسجلة حالياً'
                    : 'No notifications found',
                isAr
                    ? 'ستظهر هنا كافة إشعارات وتسليمات الطلاب وتنبيهات السنتر فور إرسالها.'
                    : 'Student submissions and center notices will appear here.',
                Icons.notifications_off_outlined,
              ),
          };

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.teacherRole.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: AppColors.teacherRole,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ),
            if (hasSearch || category != TeacherNotificationCategory.all) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onResetFilters,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: Text(
                  isAr ? 'عرض كافة الإشعارات' : 'View All Notifications',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teacherRole,
                  side: BorderSide(
                    color: AppColors.teacherRole.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 7. Smart Time Formatter for Teacher Notifications ────────────────────────

String _formatTeacherSmartTime(DateTime createdAt, {required bool isArabic}) {
  final now = DateTime.now();
  final diff = now.difference(createdAt);

  if (diff.inSeconds < 60) {
    return isArabic ? 'الآن' : 'Just now';
  } else if (diff.inMinutes < 60) {
    final mins = diff.inMinutes;
    return isArabic ? 'منذ $mins د' : '${mins}m ago';
  } else if (diff.inHours < 24 && createdAt.day == now.day) {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return isArabic ? 'اليوم $hour:$minute' : 'Today $hour:$minute';
  } else if (diff.inDays == 1 ||
      (diff.inHours < 48 && createdAt.day == now.day - 1)) {
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
