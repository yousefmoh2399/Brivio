import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../data/models/support_ticket.dart';
import '../../data/models/ticket_reply.dart';
import '../../data/repositories/helpdesk_repository.dart';

class HelpdeskManagementScreen extends StatefulWidget {
  const HelpdeskManagementScreen({super.key});

  @override
  State<HelpdeskManagementScreen> createState() =>
      _HelpdeskManagementScreenState();
}

class _HelpdeskManagementScreenState extends State<HelpdeskManagementScreen>
    with SingleTickerProviderStateMixin {
  final HelpdeskRepository _repository = HelpdeskRepository();
  late Future<List<SupportTicket>> _ticketsFuture;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTickets() {
    setState(() {
      _ticketsFuture = _repository.getTickets();
    });
  }

  void _showCreateTicketDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String priority = 'normal';
    final dialogWidth = MediaQuery.of(context).size.width.clamp(280.0, 480.0);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: AppColors.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'فتح تذكرة دعم فني جديدة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'موضوع التذكرة / المشكلة',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'تفاصيل الاستفسار أو البلاغ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('منخفضة الأولوية')),
                      DropdownMenuItem(value: 'normal', child: Text('عادية')),
                      DropdownMenuItem(value: 'high', child: Text('عالية الأهمية')),
                      DropdownMenuItem(value: 'urgent', child: Text('عاجلة جداً 🚨')),
                    ],
                    onChanged: (val) {
                      if (val != null) priority = val;
                    },
                    decoration: InputDecoration(
                      labelText: 'درجة الأهمية',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.flag_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.info,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty &&
                    descriptionController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  await _repository.createTicket(
                    subject: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    priority: priority,
                  );
                  _loadTickets();
                }
              },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('إرسال التذكرة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PortalPageShell(
      title: 'الدعم الفني ومكتب المساعدة',
      subtitle: 'متابعة وحل استفسارات ومشاكل الطلاب، المعلمين، وأولياء الأمور بسرعة واحترافية.',
      icon: Icons.support_agent_rounded,
      accentColor: AppColors.info,
      eyebrow: 'إدارة المنظومة والسنتر',
      actions: [
        PortalAction(
          icon: Icons.add_rounded,
          label: 'تذكرة جديدة',
          onPressed: _showCreateTicketDialog,
          primary: true,
        ),
        PortalAction(
          icon: Icons.refresh_rounded,
          label: 'تحديث',
          onPressed: _loadTickets,
        ),
      ],
      child: FutureBuilder<List<SupportTicket>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.info));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text(
                      'تعذر تحميل تذاكر الدعم الفني. يرجى إعادة المحاولة.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadTickets,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allTickets = snapshot.data ?? [];
          final openTickets =
              allTickets.where((t) => t.status == 'open').toList();
          final inProgressTickets =
              allTickets.where((t) => t.status == 'in_progress').toList();
          final closedTickets = allTickets
              .where((t) => t.status == 'resolved' || t.status == 'closed')
              .toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Responsive KPI Stats Strip
                  _buildKpiStrip(
                    isMobile: isMobile,
                    openCount: openTickets.length,
                    inProgressCount: inProgressTickets.length,
                    closedCount: closedTickets.length,
                    totalCount: allTickets.length,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 10),

                  // Tab Bar Container
                  Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.info.withValues(alpha: 0.15),
                      ),
                      labelColor: AppColors.info,
                      unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        Tab(text: 'جديدة مفتوحة (${openTickets.length})'),
                        Tab(text: 'قيد المتابعة (${inProgressTickets.length})'),
                        Tab(text: 'مغلقة ومحلولة (${closedTickets.length})'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _TicketList(
                          tickets: openTickets,
                          onStatusChange: _loadTickets,
                          emptyMessage: 'لا توجد تذاكر جديدة مفتوحة حالياً 🎉',
                        ),
                        _TicketList(
                          tickets: inProgressTickets,
                          onStatusChange: _loadTickets,
                          emptyMessage: 'لا توجد تذاكر قيد المتابعة حالياً',
                        ),
                        _TicketList(
                          tickets: closedTickets,
                          onStatusChange: _loadTickets,
                          emptyMessage: 'لا توجد تذاكر مغلقة أو مؤرشفة',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildKpiStrip({
    required bool isMobile,
    required int openCount,
    required int inProgressCount,
    required int closedCount,
    required int totalCount,
    required bool isDark,
  }) {
    final cards = [
      _HelpdeskStatCard(
        label: 'مفتوحة وجديدة',
        value: '$openCount',
        icon: Icons.mark_email_unread_rounded,
        accentColor: Colors.blue,
        onTap: () => _tabController.animateTo(0),
      ),
      _HelpdeskStatCard(
        label: 'قيد المتابعة',
        value: '$inProgressCount',
        icon: Icons.hourglass_top_rounded,
        accentColor: Colors.orange,
        onTap: () => _tabController.animateTo(1),
      ),
      _HelpdeskStatCard(
        label: 'مغلقة ومحلولة',
        value: '$closedCount',
        icon: Icons.task_alt_rounded,
        accentColor: AppColors.success,
        onTap: () => _tabController.animateTo(2),
      ),
      _HelpdeskStatCard(
        label: 'إجمالي التذاكر',
        value: '$totalCount',
        icon: Icons.confirmation_number_outlined,
        accentColor: Colors.deepPurple,
        onTap: null,
      ),
    ];

    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 68,
        children: cards,
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _HelpdeskStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const _HelpdeskStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
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

class _TicketList extends StatelessWidget {
  final List<SupportTicket> tickets;
  final VoidCallback onStatusChange;
  final String emptyMessage;

  const _TicketList({
    required this.tickets,
    required this.onStatusChange,
    required this.emptyMessage,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getAvatarColor(String id) {
    final colors = [
      Colors.purple,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.teal,
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: tickets.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        final priorityColor = _getPriorityColor(t.priority);
        final avatarColor = _getAvatarColor(t.userId);
        final dateFormatted = timeago.format(t.createdAt, locale: 'ar');

        return FadeInSlide(
          delay: Duration(milliseconds: 30 * i),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showTicketDetails(
                  context,
                  t,
                  avatarColor,
                  dateFormatted,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarColor.withValues(alpha: 0.15),
                        child: Icon(Icons.person_rounded, color: avatarColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '#${t.id.length >= 8 ? t.id.substring(0, 8).toUpperCase() : t.id}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white60 : Colors.black45,
                                    fontSize: 11.5,
                                  ),
                                ),
                                Text(
                                  dateFormatted,
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black45,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'معرف المستخدم: ${t.userId.length >= 8 ? t.userId.substring(0, 8) : t.userId}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: priorityColor.withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    _priorityLabel(t.priority),
                                    style: TextStyle(
                                      color: priorityColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _buildStatusBadge(t.status),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final (Color color, IconData icon, String label) = switch (status.toLowerCase()) {
      'open' => (Colors.blue, Icons.mark_email_unread_rounded, 'مفتوحة'),
      'in_progress' => (Colors.orange, Icons.hourglass_bottom_rounded, 'قيد المتابعة'),
      'resolved' => (AppColors.success, Icons.check_circle_rounded, 'تم الحل'),
      'closed' => (Colors.grey, Icons.lock_outline_rounded, 'مغلقة'),
      _ => (AppColors.primary, Icons.info_outline_rounded, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _priorityLabel(String priority) {
    return switch (priority.toLowerCase()) {
      'urgent' => 'عاجلة جداً 🚨',
      'high' => 'عالية الأهمية',
      'normal' => 'عادية',
      'low' => 'منخفضة',
      _ => priority,
    };
  }

  void _showTicketDetails(
    BuildContext context,
    SupportTicket ticket,
    Color avatarColor,
    String dateFormatted,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _TicketDetailsSheet(
          ticket: ticket,
          avatarColor: avatarColor,
          dateFormatted: dateFormatted,
          onStatusChange: onStatusChange,
        );
      },
    );
  }
}

class _TicketDetailsSheet extends StatefulWidget {
  final SupportTicket ticket;
  final Color avatarColor;
  final String dateFormatted;
  final VoidCallback onStatusChange;

  const _TicketDetailsSheet({
    required this.ticket,
    required this.avatarColor,
    required this.dateFormatted,
    required this.onStatusChange,
  });

  @override
  State<_TicketDetailsSheet> createState() => _TicketDetailsSheetState();
}

class _TicketDetailsSheetState extends State<_TicketDetailsSheet> {
  final _replyController = TextEditingController();
  final _repository = HelpdeskRepository();
  List<TicketReply>? _replies;
  bool _isLoading = true;
  String _currentStatus = '';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ticket.status;
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    try {
      final replies = await _repository.getReplies(widget.ticket.id);
      if (!mounted) return;
      setState(() {
        _replies = replies;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    setState(() => _isLoading = true);

    try {
      await _repository.addReply(widget.ticket.id, text);
      await _loadReplies();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تذكرة #${widget.ticket.id.length >= 8 ? widget.ticket.id.substring(0, 8).toUpperCase() : widget.ticket.id}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.ticket.subject,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Details & Messages
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  children: [
                    // User info & Status changer card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: widget.avatarColor.withValues(alpha: 0.15),
                                child: Icon(Icons.person_rounded, color: widget.avatarColor, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'المستخدم: ${widget.ticket.userId.length >= 8 ? widget.ticket.userId.substring(0, 8) : widget.ticket.userId}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      'تاريخ الإرسال: ${widget.dateFormatted}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'حالة التذكرة:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                              DropdownButton<String>(
                                value: _currentStatus,
                                isDense: true,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'open', child: Text('مفتوحة 🔵')),
                                  DropdownMenuItem(value: 'in_progress', child: Text('قيد المتابعة 🟠')),
                                  DropdownMenuItem(value: 'resolved', child: Text('تم الحل 🟢')),
                                  DropdownMenuItem(value: 'closed', child: Text('مغلقة ⚫')),
                                ],
                                onChanged: (val) async {
                                  if (val != null) {
                                    setState(() => _currentStatus = val);
                                    await _repository.updateTicketStatus(
                                      widget.ticket.id,
                                      val,
                                    );
                                    widget.onStatusChange();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'نص وتفاصيل المشكلة / الاستفسار:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Text(
                        widget.ticket.description,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),

                    const SizedBox(height: 22),
                    const Text(
                      'الردود والمتابعات:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_replies != null && _replies!.isNotEmpty)
                      ..._replies!.map((r) => _buildReplyRow(r, isDark))
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'لم تتم إضافة أي ردود بعد. اكتب رداً بالأسفل.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Send Reply Bar
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: InputDecoration(
                            hintText: 'اكتب رداً أو توجيهاً على التذكرة...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sendReply,
                        style: IconButton.styleFrom(backgroundColor: AppColors.info),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyRow(TicketReply reply, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.info.withValues(alpha: 0.2),
            child: const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.info),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        reply.userId.length >= 8 ? reply.userId.substring(0, 8) : reply.userId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        timeago.format(reply.createdAt, locale: 'ar'),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reply.message, style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
