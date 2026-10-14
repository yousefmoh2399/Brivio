import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../data/models/support_ticket.dart';
import '../../data/models/ticket_reply.dart';
import '../../data/repositories/helpdesk_repository.dart';
import 'package:timeago/timeago.dart' as timeago;

class HelpdeskManagementScreen extends StatefulWidget {
  const HelpdeskManagementScreen({super.key});

  @override
  State<HelpdeskManagementScreen> createState() =>
      _HelpdeskManagementScreenState();
}

class _HelpdeskManagementScreenState extends State<HelpdeskManagementScreen> {
  final HelpdeskRepository _repository = HelpdeskRepository();
  late Future<List<SupportTicket>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _loadTickets();
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('فتح تذكرة دعم فني جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'موضوع التذكرة / المشكلة'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل الاستفسار أو البلاغ',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: priority,
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('منخفضة')),
                  DropdownMenuItem(value: 'normal', child: Text('عادية')),
                  DropdownMenuItem(value: 'high', child: Text('عالية')),
                  DropdownMenuItem(value: 'urgent', child: Text('عاجلة جداً')),
                ],
                onChanged: (val) {
                  if (val != null) priority = val;
                },
                decoration: const InputDecoration(labelText: 'درجة الأهمية'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty) {
                  Navigator.pop(context);
                  await _repository.createTicket(
                    subject: titleController.text,
                    description: descriptionController.text,
                    priority: priority,
                  );
                  _loadTickets();
                }
              },
              child: const Text('إرسال التذكرة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: PortalPageShell(
        title: 'الدعم الفني والتذاكر',
        subtitle: 'متابعة استفسارات ومشاكل الطلاب والمعلمين وأولياء الأمور.',
        icon: Icons.support_agent,
        accentColor: AppColors.info,
        eyebrow: 'إدارة المنظومة والسنتر',
        actions: [
          PortalAction(
            icon: Icons.add,
            label: 'تذكرة جديدة',
            onPressed: _showCreateTicketDialog,
          ),
          PortalAction(
            icon: Icons.refresh,
            label: 'تحديث',
            onPressed: _loadTickets,
          ),
        ],
        child: FutureBuilder<List<SupportTicket>>(
          future: _ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'تعذر تحميل تذاكر الدعم الفني. يرجى إعادة المحاولة.',
                ),
              );
            }

            final allTickets = snapshot.data ?? [];
            final openTickets = allTickets
                .where((t) => t.status == 'open')
                .toList();
            final inProgressTickets = allTickets
                .where((t) => t.status == 'in_progress')
                .toList();
            final closedTickets = allTickets
                .where((t) => t.status == 'resolved' || t.status == 'closed')
                .toList();

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.info.withValues(alpha: 0.15),
                    ),
                    labelColor: AppColors.info,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color,
                    tabs: [
                      Tab(
                        text: 'جديدة مفتوحة (${openTickets.length})',
                      ),
                      Tab(
                        text: 'قيد المتابعة (${inProgressTickets.length})',
                      ),
                      Tab(
                        text: 'مغلقة ومحلولة (${closedTickets.length})',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TicketList(
                        tickets: openTickets,
                        onStatusChange: _loadTickets,
                      ),
                      _TicketList(
                        tickets: inProgressTickets,
                        onStatusChange: _loadTickets,
                      ),
                      _TicketList(
                        tickets: closedTickets,
                        onStatusChange: _loadTickets,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final List<SupportTicket> tickets;
  final VoidCallback onStatusChange;

  const _TicketList({required this.tickets, required this.onStatusChange});

  Color _getPriorityColor(String priority) {
    switch (priority) {
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
    ];
    return colors[id.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Center(
        child: Text('لا توجد تذاكر دعم فني في هذا القسم.'),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: tickets.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        final priorityColor = _getPriorityColor(t.priority);
        final avatarColor = _getAvatarColor(t.userId);
        final dateFormatted = timeago.format(t.createdAt, locale: 'ar');

        return FadeInSlide(
          delay: Duration(milliseconds: 50 * i),
          child: GlassCard(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    _showTicketDetails(context, t, avatarColor, dateFormatted),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: avatarColor.withValues(alpha: 0.15),
                        child: Icon(Icons.person, color: avatarColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${t.id.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  dateFormatted,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.subject,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'معرف المستخدم: ${t.userId.substring(0, 8)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: priorityColor.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _priorityLabel(t.priority),
                                    style: TextStyle(
                                      color: priorityColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PortalStatusChip(status: _statusLabel(t.status)),
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

  static String _priorityLabel(String priority) {
    return switch (priority.toLowerCase()) {
      'urgent' => 'عاجلة جداً',
      'high' => 'عالية',
      'normal' => 'عادية',
      'low' => 'منخفضة',
      _ => priority,
    };
  }

  static String _statusLabel(String status) {
    return switch (status.toLowerCase()) {
      'open' => 'مفتوحة',
      'in_progress' => 'قيد المتابعة',
      'resolved' => 'تم الحل',
      'closed' => 'مغلقة',
      _ => status,
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

  Future<void> _loadReplies() async {
    try {
      final replies = await _repository.getReplies(widget.ticket.id);
      setState(() {
        _replies = replies;
        _isLoading = false;
      });
    } catch (e) {
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تذكرة #${widget.ticket.id.substring(0, 8)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.ticket.subject,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: widget.avatarColor.withValues(
                            alpha: 0.15,
                          ),
                          child: Icon(Icons.person, color: widget.avatarColor),
                        ),
                        title: Text(
                          'معرف المستخدم: ${widget.ticket.userId.substring(0, 8)}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تاريخ الإرسال: ${widget.dateFormatted}',
                            ),
                            if (widget.ticket.groupId != null)
                              Text(
                                'المجموعة: ${widget.ticket.groupId}',
                              ),
                          ],
                        ),
                        trailing: DropdownButton<String>(
                          value: _currentStatus,
                          items: const [
                            DropdownMenuItem(value: 'open', child: Text('مفتوحة')),
                            DropdownMenuItem(value: 'in_progress', child: Text('قيد المتابعة')),
                            DropdownMenuItem(value: 'resolved', child: Text('تم الحل')),
                            DropdownMenuItem(value: 'closed', child: Text('مغلقة')),
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
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'تفاصيل التذكرة والمشكلة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.ticket.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'الردود والمتابعات',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_replies != null)
                      ..._replies!.map((r) => _buildReplyRow(r, isDark)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: TextField(
                            controller: _replyController,
                            decoration: InputDecoration(
                              hintText: 'اكتب رداً أو متابعة على التذكرة...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        onPressed: _sendReply,
                        mini: true,
                        backgroundColor: AppColors.info,
                        elevation: 0,
                        child: const Icon(Icons.send, color: Colors.white),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reply.userId.substring(0, 8),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(reply.message),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(reply.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
