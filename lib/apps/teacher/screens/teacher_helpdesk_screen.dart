import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../features/helpdesk/data/models/support_ticket.dart';
import '../../../../features/helpdesk/data/repositories/helpdesk_repository.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return GlassCard(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                                '#${ticket.id.length > 8 ? ticket.id.substring(0, 8) : ticket.id}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ticket.subject,
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: avatarColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(Icons.person, color: avatarColor),
                          ),
                          title: Text(
                            'كود الحساب: ${ticket.userId.length > 8 ? ticket.userId.substring(0, 8) : ticket.userId}',
                          ),
                          subtitle: Text(
                            'تاريخ الإرسال: $dateFormatted',
                          ),
                          trailing: DropdownButton<String>(
                            value: ticket.status,
                            items: ['open', 'in_progress', 'resolved', 'closed']
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(_statusArabic(s)),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) async {
                              if (val != null) {
                                final repo = HelpdeskRepository();
                                await repo.updateTicketStatus(ticket.id, val);
                                if (context.mounted) Navigator.pop(context);
                                onStatusChange();
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'تفاصيل المشكلة / الاستفسار',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'سجل المتابعة والتحديثات',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey,
                              child: Icon(
                                Icons.support_agent,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'إدارة النظام',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'تم تسجيل التذكرة بنجاح وجاري المتابعة من قبل الدعم الفني.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: replyController,
                              decoration: InputDecoration(
                                hintText: 'اكتب ردك هنا...',
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
                          const SizedBox(width: 12),
                          FloatingActionButton(
                            onPressed: () {
                              if (replyController.text.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تم إرسال ردك إلى فريق الدعم الفني بنجاح!',
                                    ),
                                  ),
                                );
                                replyController.clear();
                              }
                            },
                            mini: true,
                            backgroundColor: accentColor,
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
      },
    );
  }
}
