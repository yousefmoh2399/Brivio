import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/notification_localizer.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../viewmodels/parent_comms_view_model.dart';

class ParentCommsScreen extends StatefulWidget {
  const ParentCommsScreen({super.key});

  @override
  State<ParentCommsScreen> createState() => _ParentCommsScreenState();
}

class _ParentCommsScreenState extends State<ParentCommsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ParentCommsViewModel _viewModel = ParentCommsViewModel();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.removeListener(_onViewModelChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime date) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'م' : 'ص';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final isAr = AppLocalizations.of(context).isArabic;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Text(
            context.tr('مركز التواصل والإعلانات 📢'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.parentRole,
            labelColor: AppColors.parentRole,
            unselectedLabelColor: textSecondary,
            tabs: [
              Tab(text: context.tr('إعلانات السنتر'), icon: const Icon(Icons.campaign_outlined)),
              Tab(text: context.tr('المحادثة والرسائل'), icon: const Icon(Icons.chat_bubble_outline_rounded)),
            ],
          ),
        ),
        body: _viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [_buildAnnouncementsTab(), _buildMessagesTab()],
              ),
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = AppLocalizations.of(context).isArabic;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (_viewModel.announcements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign_outlined, size: 64, color: textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                context.tr('لا توجد إعلانات عامة أو تنبيهات منشورة من السنتر حالياً.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _viewModel.announcements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final announcement = _viewModel.announcements[index];
        return GlassCard(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.parentRole.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr(announcement.author),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.parentRole,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(announcement.date),
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                NotificationLocalizer.localizeTitle(announcement.title, isArabic: isAr),
                style: AppTypography.titleMedium(textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                NotificationLocalizer.localizeMessage(announcement.content, isArabic: isAr),
                style: AppTypography.bodySmall(textSecondary).copyWith(height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      children: [
        Expanded(
          child: _viewModel.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined, size: 56, color: textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('تواصل مباشرة مع إدارة السنتر وسكرتارية المعلم.'),
                          style: TextStyle(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _viewModel.messages.length,
                  itemBuilder: (context, index) {
                    final message = _viewModel.messages[index];
                    return _buildChatBubble(message);
                  },
                ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatBubble(Message message) {
    final isMe = message.isFromMe;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? AppColors.parentRole : surfaceColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 0 : 18),
              bottomRight: Radius.circular(isMe ? 18 : 0),
            ),
            border: isMe ? null : Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    message.sender,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: context.tr('اكتب رسالتك للإدارة أو المدرس...'),
                  hintStyle: TextStyle(color: textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  _viewModel.sendMessage(value);
                  _messageController.clear();
                },
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              backgroundColor: AppColors.parentRole,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                onPressed: () {
                  _viewModel.sendMessage(_messageController.text);
                  _messageController.clear();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
