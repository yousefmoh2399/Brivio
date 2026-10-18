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
  NotificationCategoryFilter _selectedFilter = NotificationCategoryFilter.all;

  @override
  void initState() {
    super.initState();
    widget.viewModel.loadNotifications();
  }

  NotificationCategoryFilter _resolveCategory(AppNotification notif) {
    final t = notif.type.toLowerCase();
    final m = '${notif.title} ${notif.message}'.toLowerCase();

    if (t.contains('pay') ||
        t.contains('receipt') ||
        t.contains('fee') ||
        t.contains('finance') ||
        m.contains('إيصال') ||
        m.contains('مصاريف') ||
        m.contains('سداد') ||
        m.contains('كاش') ||
        m.contains('جنيه')) {
      return NotificationCategoryFilter.financial;
    }

    if (t.contains('exam') ||
        t.contains('homework') ||
        t.contains('grade') ||
        t.contains('quiz') ||
        t.contains('attendance') ||
        m.contains('امتحان') ||
        m.contains('واجب') ||
        m.contains('درجة') ||
        m.contains('غياب') ||
        m.contains('حضور') ||
        m.contains('كويز')) {
      return NotificationCategoryFilter.academic;
    }

    return NotificationCategoryFilter.general;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final isAr = AppLocalizations.of(context).isArabic;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;

          final allNotifs = vm.notifications;
          final academicNotifs = allNotifs.where((n) => _resolveCategory(n) == NotificationCategoryFilter.academic).toList();
          final financialNotifs = allNotifs.where((n) => _resolveCategory(n) == NotificationCategoryFilter.financial).toList();
          final generalNotifs = allNotifs.where((n) => _resolveCategory(n) == NotificationCategoryFilter.general).toList();

          List<AppNotification> filteredList;
          switch (_selectedFilter) {
            case NotificationCategoryFilter.academic:
              filteredList = academicNotifs;
              break;
            case NotificationCategoryFilter.financial:
              filteredList = financialNotifs;
              break;
            case NotificationCategoryFilter.general:
              filteredList = generalNotifs;
              break;
            case NotificationCategoryFilter.all:
              filteredList = allNotifs;
          }

          final unreadCount = allNotifs.where((n) => !n.isRead).length;

          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: backgroundColor,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  Text(context.tr('Notifications')),
                  const SizedBox(width: 8),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAr ? '$unreadCount جديد' : '$unreadCount New',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              actions: [
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: vm.markAllRead,
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: Text(context.tr('Mark All Read')),
                  ),
              ],
            ),
            body: Column(
              children: [
                // Categories Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: context.tr('الكل'),
                        count: allNotifs.length,
                        filter: NotificationCategoryFilter.all,
                        icon: Icons.inbox_rounded,
                        activeColor: AppColors.primary,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: context.tr('أكاديمية 🔔'),
                        count: academicNotifs.length,
                        filter: NotificationCategoryFilter.academic,
                        icon: Icons.school_rounded,
                        activeColor: Colors.blue.shade700,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: context.tr('مالية 💳'),
                        count: financialNotifs.length,
                        filter: NotificationCategoryFilter.financial,
                        icon: Icons.payments_rounded,
                        activeColor: Colors.teal.shade700,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: context.tr('طوارئ وعامة 📢'),
                        count: generalNotifs.length,
                        filter: NotificationCategoryFilter.general,
                        icon: Icons.campaign_rounded,
                        activeColor: Colors.amber.shade800,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

              // Content List
              Expanded(
                child: vm.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : vm.errorMessage != null
                    ? Center(
                        child: Text(
                          '${context.tr('Error')}: ${vm.errorMessage}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 54, color: textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('No notifications in your inbox.'),
                              style: AppTypography.bodyMedium(textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: vm.loadNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final notif = filteredList[index];
                            final cat = _resolveCategory(notif);

                            Color accentColor;
                            IconData catIcon;
                            String catLabel;

                            switch (cat) {
                              case NotificationCategoryFilter.academic:
                                accentColor = Colors.blue.shade600;
                                catIcon = Icons.school_rounded;
                                catLabel = 'أكاديمي';
                                break;
                              case NotificationCategoryFilter.financial:
                                accentColor = Colors.teal.shade600;
                                catIcon = Icons.receipt_long_rounded;
                                catLabel = 'مالي كاش';
                                break;
                              case NotificationCategoryFilter.general:
                              default:
                                accentColor = Colors.amber.shade700;
                                catIcon = Icons.campaign_rounded;
                                catLabel = 'تنبيه سنتر';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: EdgeInsets.zero,
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                borderColor: notif.isRead
                                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                    : accentColor.withValues(alpha: 0.4),
                                child: InkWell(
                                  onTap: () {
                                    if (!notif.isRead) {
                                      vm.markRead(notif.id);
                                    }
                                    final localHandler = widget.onNotificationTap;
                                    if (localHandler != null) {
                                      localHandler(notif);
                                      return;
                                    }
                                    final pushService =
                                        GetIt.instance
                                            .isRegistered<PushNotificationService>()
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
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            catIcon,
                                            color: accentColor,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: accentColor.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      NotificationLocalizer.localizeCategory(catLabel, isArabic: isAr),
                                                      style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatNotificationTime(notif.createdAt),
                                                    style: AppTypography.caption(textSecondary).copyWith(fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                NotificationLocalizer.localizeTitle(notif.title, isArabic: isAr),
                                                style: AppTypography.titleSmall(textPrimary).copyWith(
                                                  fontWeight: notif.isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.w800,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                NotificationLocalizer.localizeMessage(notif.message, isArabic: isAr),
                                                style: AppTypography.bodySmall(textSecondary),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!notif.isRead) ...[
                                          const SizedBox(width: 10),
                                          Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: accentColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
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
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
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
              color: isSelected ? activeColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
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

String _formatNotificationTime(DateTime createdAt) {
  final hour = createdAt.hour.toString().padLeft(2, '0');
  final minute = createdAt.minute.toString().padLeft(2, '0');
  final month = createdAt.month.toString().padLeft(2, '0');
  final day = createdAt.day.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}
