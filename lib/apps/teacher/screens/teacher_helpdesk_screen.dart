import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../features/helpdesk/data/models/support_ticket.dart';
import '../../../../features/helpdesk/data/models/ticket_reply.dart';
import '../../../../features/helpdesk/data/repositories/helpdesk_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

String _statusArabic(String status) {
  return switch (status.toLowerCase()) {
    'open' => 'مفتوحة',
    'in_progress' => 'قيد المتابعة',
    'resolved' => 'تم الحل',
    'closed' => 'مغلقة',
    _ => status,
  };
}

String _priorityArabic(String priority) {
  return switch (priority.toLowerCase()) {
    'low' => 'منخفضة',
    'normal' => 'عادية',
    'high' => 'عالية',
    'urgent' => 'عاجلة',
    _ => priority,
  };
}

class TeacherHelpdeskScreen extends StatefulWidget {
  const TeacherHelpdeskScreen({super.key});

  @override
  State<TeacherHelpdeskScreen> createState() => _TeacherHelpdeskScreenState();
}

class _TeacherHelpdeskScreenState extends State<TeacherHelpdeskScreen> {
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
          title: const Text('إنشاء تذكرة دعم فني جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'موضوع التذكرة / الاستفسار'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل المشكلة بالتفصيل',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: priority,
                items: ['low', 'normal', 'high', 'urgent']
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(_priorityArabic(p)),
                      ),
                    )
                    .toList(),
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
    final canPop = Navigator.of(context).canPop();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bodyContent = FutureBuilder<List<SupportTicket>>(
      future: _ticketsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'تعذر تحميل تذاكر الدعم. يرجى المحاولة مرة أخرى.',
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
                  color: AppColors.secondary.withValues(alpha: 0.15),
                ),
                labelColor: AppColors.secondary,
                unselectedLabelColor: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color,
                tabs: [
                  Tab(
                    text: 'مفتوحة (${openTickets.length})',
                  ),
                  Tab(
                    text: 'قيد المتابعة (${inProgressTickets.length})',
                  ),
                  Tab(
                    text: 'مغلقة (${closedTickets.length})',
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
                    accentColor: AppColors.secondary,
                  ),
                  _TicketList(
                    tickets: inProgressTickets,
                    onStatusChange: _loadTickets,
                    accentColor: AppColors.secondary,
                  ),
                  _TicketList(
                    tickets: closedTickets,
                    onStatusChange: _loadTickets,
                    accentColor: AppColors.secondary,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (canPop) {
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            title: const Text(
              'الدعم الفني والشكاوى',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.95),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'رجوع',
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث',
                onPressed: _loadTickets,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateTicketDialog,
            backgroundColor: AppColors.secondary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('تذكرة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: bodyContent,
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: PortalPageShell(
        title: 'الدعم الفني والمساعدة',
        subtitle: 'متابعة استفساراتك وطلبات المساعدة الفنية والتقنية والشكاوى',
        icon: Icons.support_agent,
        accentColor: AppColors.secondary,
        eyebrow: 'بوابة المعلمين',
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
        child: bodyContent,
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final List<SupportTicket> tickets;
  final VoidCallback onStatusChange;
  final Color accentColor;

  const _TicketList({
    required this.tickets,
    required this.onStatusChange,
    required this.accentColor,
  });

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
        child: Text('لا توجد تذاكر مسجلة في هذا القسم.'),
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
        final dateFormatted = timeago.format(t.createdAt);

        return FadeInSlide(
          delay: Duration(milliseconds: 50 * i),
          child: GlassCard(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                                '#${t.id.length > 8 ? t.id.substring(0, 8) : t.id}',
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
                            'كود الحساب: ${t.userId.length > 8 ? t.userId.substring(0, 8) : t.userId}',
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
                                    color: priorityColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  _priorityArabic(t.priority),
                                  style: TextStyle(
                                    color: priorityColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PortalStatusChip(status: t.status),
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
        );
      },
    );
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
        return _TeacherTicketDetailsSheet(
          ticket: ticket,
          avatarColor: avatarColor,
          dateFormatted: dateFormatted,
          onStatusChange: onStatusChange,
          accentColor: accentColor,
        );
      },
    );
  }
}

class _TeacherTicketDetailsSheet extends StatefulWidget {
  final SupportTicket ticket;
  final Color avatarColor;
  final String dateFormatted;
  final VoidCallback onStatusChange;
  final Color accentColor;

  const _TeacherTicketDetailsSheet({
    required this.ticket,
    required this.avatarColor,
    required this.dateFormatted,
    required this.onStatusChange,
    required this.accentColor,
  });

  @override
  State<_TeacherTicketDetailsSheet> createState() =>
      _TeacherTicketDetailsSheetState();
}

class _TeacherTicketDetailsSheetState
    extends State<_TeacherTicketDetailsSheet> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final HelpdeskRepository _repository = HelpdeskRepository();

  List<TicketReply>? _replies;
  bool _isLoadingReplies = true;
  bool _isSending = false;
  late String _currentStatus;
  String? _currentUserId;

  static const List<String> _cannedReplies = [
    'تم الاطلاع وجاري المتابعة ⏳',
    'تم حل استفسارك بنجاح ✅',
    'يرجى مراجعتي أثناء موعد الحصة القادمة 🏫',
    'تم التنسيق مع إدارة السنتر لتنفيذ طلبك 📋',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ticket.status;
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    try {
      final replies = await _repository.getReplies(widget.ticket.id);
      if (!mounted) return;
      setState(() {
        _replies = replies;
        _isLoadingReplies = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingReplies = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendReply({String? customText}) async {
    final text = (customText ?? _replyController.text).trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final reply = await _repository.addReply(widget.ticket.id, text);
      if (!mounted) return;

      _replyController.clear();
      setState(() {
        _replies = [...(_replies ?? []), reply];
        if (_currentStatus == 'open') {
          _currentStatus = 'in_progress';
        }
        _isSending = false;
      });

      widget.onStatusChange();
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال ردك وإشعار صاحب التذكرة بنجاح! 🚀'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الرد: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleStatusChange(String newStatus) async {
    if (newStatus == _currentStatus) return;

    try {
      await _repository.updateTicketStatus(widget.ticket.id, newStatus);
      if (!mounted) return;

      setState(() => _currentStatus = newStatus);
      widget.onStatusChange();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث حالة التذكرة إلى (${_statusArabic(newStatus)}) وإشعار الطالب.',
          ),
          backgroundColor: AppColors.info,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديث الحالة: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(widget.ticket.priority);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return GlassCard(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Sheet Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'تذكرة #${widget.ticket.id.length > 8 ? widget.ticket.id.substring(0, 8).toUpperCase() : widget.ticket.id}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: priorityColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    'أولوية ${_priorityArabic(widget.ticket.priority)}',
                                    style: TextStyle(
                                      color: priorityColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.ticket.subject,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
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

                // Scrollable Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // User Info & Status Manager Bar
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: widget.avatarColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: widget.avatarColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'صاحب التذكرة: ${widget.ticket.userId.length > 8 ? widget.ticket.userId.substring(0, 8) : widget.ticket.userId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
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
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // Status Changer Dropdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'تغيير حالة التذكرة:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: _currentStatus,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  borderRadius: BorderRadius.circular(12),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'open',
                                      child: Text('مفتوحة 🔵'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'in_progress',
                                      child: Text('قيد المتابعة 🟠'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'resolved',
                                      child: Text('تم الحل 🟢'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'closed',
                                      child: Text('مغلقة ⚫'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) _handleStatusChange(val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Problem details description card
                      const Text(
                        'تفاصيل المشكلة / الاستفسار الأصلي:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Text(
                          widget.ticket.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Discussion / Replies header
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: widget.accentColor,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'سجل المتابعة والردود:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Replies list
                      if (_isLoadingReplies)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_replies == null || _replies!.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'لا توجد ردود مسجلة بعد على هذه التذكرة.\nاكتب أول رد الآن لتوجيه ومساعدة الطالب.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._replies!.map((r) => _buildReplyBubble(r, isDark)),
                    ],
                  ),
                ),

                // Quick Canned Replies Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.black.withValues(alpha: 0.02),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _cannedReplies.map((canned) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ActionChip(
                            label: Text(
                              canned,
                              style: const TextStyle(fontSize: 11),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () {
                              _replyController.text = canned;
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Reply Input Bar
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 14,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            decoration: InputDecoration(
                              hintText: 'اكتب ردك أو توجيهك للطالب هنا...',
                              hintStyle: const TextStyle(fontSize: 12.5),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSending ? null : () => _handleSendReply(),
                          style: IconButton.styleFrom(
                            backgroundColor: widget.accentColor,
                            padding: const EdgeInsets.all(12),
                          ),
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ],
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

  Widget _buildReplyBubble(TicketReply reply, bool isDark) {
    final isTeacher = reply.userId == _currentUserId;
    final isCreator = reply.userId == widget.ticket.userId;

    final bubbleBg = isTeacher
        ? widget.accentColor.withValues(alpha: 0.1)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9));

    final borderColor = isTeacher
        ? widget.accentColor.withValues(alpha: 0.3)
        : (isDark ? Colors.white12 : Colors.black12);

    final senderBadge = isTeacher
        ? 'أنت (المعلم) 👨‍🏫'
        : (isCreator ? 'صاحب التذكرة 👤' : 'إدارة السنتر / الدعم 🛡️');

    final badgeColor = isTeacher
        ? widget.accentColor
        : (isCreator ? Colors.blue : Colors.purple);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: badgeColor.withValues(alpha: 0.15),
            child: Icon(
              isTeacher
                  ? Icons.school_rounded
                  : (isCreator ? Icons.person_rounded : Icons.support_agent_rounded),
              size: 16,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        senderBadge,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: badgeColor,
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
                  const SizedBox(height: 6),
                  Text(
                    reply.message,
                    style: const TextStyle(fontSize: 13, height: 1.4),
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
