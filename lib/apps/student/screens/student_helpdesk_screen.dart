import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../features/helpdesk/data/repositories/helpdesk_repository.dart';
import '../../../../features/helpdesk/data/models/support_ticket.dart';
import '../../../../features/helpdesk/data/models/ticket_reply.dart';

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

class StudentHelpdeskScreen extends StatefulWidget {
  const StudentHelpdeskScreen({super.key});

  @override
  State<StudentHelpdeskScreen> createState() => _StudentHelpdeskScreenState();
}

class _StudentHelpdeskScreenState extends State<StudentHelpdeskScreen> {
  final HelpdeskRepository _repo = HelpdeskRepository();
  bool _isLoading = true;
  List<SupportTicket> _tickets = [];
  String _filter = 'all';

  int get _openCount => _tickets.where((t) => t.status.toLowerCase() == 'open').length;
  int get _inProgressCount => _tickets.where((t) => t.status.toLowerCase() == 'in_progress').length;
  int get _closedCount => _tickets.where((t) => t.status.toLowerCase() == 'closed' || t.status.toLowerCase() == 'resolved').length;

  List<SupportTicket> get _filteredTickets {
    return switch (_filter) {
      'open' => _tickets.where((t) => t.status.toLowerCase() == 'open').toList(),
      'in_progress' => _tickets.where((t) => t.status.toLowerCase() == 'in_progress').toList(),
      'closed' => _tickets.where((t) => t.status.toLowerCase() == 'closed' || t.status.toLowerCase() == 'resolved').toList(),
      _ => _tickets,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final tickets = await _repo.getTickets();
      setState(() {
        _tickets = tickets;
      });
    } catch (e) {
      debugPrint('Error loading tickets: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateTicketDialog(
        repo: _repo,
        onCreated: () {
          Navigator.pop(context);
          _loadTickets();
        },
      ),
    );
  }

  void _viewTicket(SupportTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailsSheet(
        ticket: ticket,
        repo: _repo,
        onStatusChanged: _loadTickets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = RefreshIndicator(
      onRefresh: _loadTickets,
      color: AppColors.primary,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      children: [
                        _buildKpiSummary(isDark),
                        const SizedBox(height: 12),
                        _buildWhatsAppBanner(isDark),
                        const SizedBox(height: 14),
                        _buildFilterChips(isDark),
                      ],
                    ),
                  ),
                ),
                if (_filteredTickets.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(isDark),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ticket = _filteredTickets[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTicketCard(ticket, isDark),
                          );
                        },
                        childCount: _filteredTickets.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    );

    if (canPop) {
      return Scaffold(
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
          onPressed: _showCreateDialog,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('تذكرة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: content,
      );
    }

    return PortalPageShell(
      title: 'الدعم الفني والشكاوى',
      subtitle: 'متابعة تذاكر الدعم والطلبات والاستفسارات الفنية',
      icon: Icons.headset_mic,
      accentColor: AppColors.primary,
      eyebrow: 'بوابة الطلاب',
      actions: [
        PortalAction(
          icon: Icons.add,
          label: 'تذكرة جديدة',
          onPressed: _showCreateDialog,
        ),
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadTickets,
        ),
      ],
      child: content,
    );
  }

  Widget _buildKpiSummary(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem('مفتوحة', '$_openCount', AppColors.warning, Icons.mark_email_unread_rounded, isDark),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem('قيد المتابعة', '$_inProgressCount', AppColors.primary, Icons.pending_actions_rounded, isDark),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem('تم الحل', '$_closedCount', AppColors.success, Icons.task_alt_rounded, isDark),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
              : [const Color(0xFFD1FAE5), Colors.white],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فريق الدعم الفني متواجد للمساعدة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'متوسط وقت الرد على التذاكر أقل من ساعة خلال أوقات العمل الرسمية.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final chips = [
      {'key': 'all', 'label': 'جميع التذاكر (${_tickets.length})'},
      {'key': 'open', 'label': 'المفتوحة ($_openCount)'},
      {'key': 'in_progress', 'label': 'قيد المعالجة ($_inProgressCount)'},
      {'key': 'closed', 'label': 'المكتملة ($_closedCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) {
          final isSelected = _filter == c['key'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(c['label']!),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              onSelected: (_) => setState(() => _filter = c['key']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleIcon(
              icon: Icons.support_agent_rounded,
              color: textSecondary,
              size: 64,
              iconSize: 32,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد تذاكر في هذا القسم حالياً',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'إذا كانت لديك أي مشكلة أو استفسار دراسي أو مالي، افتح تذكرة وسنتابعها معك فوراً.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('فتح تذكرة جديدة الآن'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket, bool isDark) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return GlassCard(
      onTap: () => _viewTicket(ticket),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleIcon(
            icon: Icons.chat_bubble_outline_rounded,
            color: _getStatusColor(ticket.status),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ticket.subject,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    StatusChip(
                      label: _statusArabic(ticket.status),
                      status: _getChipStatus(ticket.status),
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ticket.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(ticket.priority).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _priorityArabic(ticket.priority),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(ticket.priority),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${_formatDate(ticket.createdAt)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textTertiary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    return switch (priority.toLowerCase()) {
      'urgent' => Colors.red,
      'high' => Colors.deepOrange,
      'normal' => Colors.blue,
      'low' => Colors.green,
      _ => Colors.blue,
    };
  }

  Color _getStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'open' => AppColors.warning,
      'in_progress' => AppColors.primary,
      'closed' => AppColors.success,
      _ => AppColors.darkTextSecondary,
    };
  }

  ChipStatus _getChipStatus(String status) {
    return switch (status.toLowerCase()) {
      'open' => ChipStatus.warning,
      'in_progress' => ChipStatus.info,
      'closed' => ChipStatus.success,
      _ => ChipStatus.neutral,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _CreateTicketDialog extends StatefulWidget {
  final HelpdeskRepository repo;
  final VoidCallback onCreated;

  const _CreateTicketDialog({required this.repo, required this.onCreated});

  @override
  State<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<_CreateTicketDialog> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedPriority = 'normal';
  String? _selectedGroup;
  bool _isSubmitting = false;
  late final Future<List<HelpdeskGroupOption>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = widget.repo.getAvailableGroups();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.isEmpty || _descCtrl.text.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.repo.createTicket(
        subject: _subjectCtrl.text,
        description: _descCtrl.text,
        priority: _selectedPriority,
        groupId: _selectedGroup,
      );
      widget.onCreated();
    } catch (e) {
      debugPrint('Error creating ticket: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'إنشاء تذكرة دعم فني'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _subjectCtrl,
                  label: 'عنوان التذكرة',
                  hint: 'وصف مختصر للمشكلة أو الاستفسار',
                  isDark: isDark,
                  textPrimary: textPrimary,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descCtrl,
                  label: 'تفاصيل المشكلة',
                  hint: 'يرجى كتابة التفاصيل بدقة لمساعدتك بشكل أسرع...',
                  maxLines: 4,
                  isDark: isDark,
                  textPrimary: textPrimary,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<HelpdeskGroupOption>>(
                  future: _groupsFuture,
                  builder: (context, snapshot) {
                    final groups = snapshot.data ?? const [];
                    if (_selectedGroup == null && groups.isNotEmpty) {
                      _selectedGroup = groups.first.id;
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedGroup,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      decoration: _inputDecoration(
                        'المجموعة أو الدورة المرتبطة',
                        isDark,
                      ),
                      style: TextStyle(color: textPrimary),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('دعم عام (غير مرتبط بمجموعة)'),
                        ),
                        ...groups.map(
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(
                              g.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedGroup = val),
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPriority,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  decoration: _inputDecoration('درجة الأهمية', isDark),
                  style: TextStyle(color: textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('منخفضة')),
                    DropdownMenuItem(value: 'normal', child: Text('عادية')),
                    DropdownMenuItem(value: 'high', child: Text('عالية')),
                    DropdownMenuItem(value: 'urgent', child: Text('عاجلة')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPriority = val);
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'إرسال التذكرة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    required Color textPrimary,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textPrimary),
      decoration: _inputDecoration(label, isDark).copyWith(hintText: hint),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}

class _TicketDetailsSheet extends StatefulWidget {
  final SupportTicket ticket;
  final HelpdeskRepository repo;
  final VoidCallback? onStatusChanged;

  const _TicketDetailsSheet({
    required this.ticket,
    required this.repo,
    this.onStatusChanged,
  });

  @override
  State<_TicketDetailsSheet> createState() => _TicketDetailsSheetState();
}

class _TicketDetailsSheetState extends State<_TicketDetailsSheet> {
  List<TicketReply> _replies = [];
  bool _isLoading = true;
  final _replyCtrl = TextEditingController();
  bool _isReplying = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ticket.status;
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    setState(() => _isLoading = true);
    try {
      final replies = await widget.repo.getReplies(widget.ticket.id);
      if (mounted) {
        setState(() => _replies = replies);
      }
    } catch (e) {
      debugPrint('Error loading replies: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _isReplying) return;

    setState(() => _isReplying = true);
    try {
      final newReply = await widget.repo.addReply(
        widget.ticket.id,
        text,
      );
      if (!mounted) return;
      setState(() {
        _replies.add(newReply);
        _replyCtrl.clear();
        if (_currentStatus == 'open') {
          _currentStatus = 'in_progress';
        }
      });
      widget.onStatusChanged?.call();
    } catch (e) {
      debugPrint('Error sending reply: $e');
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  Future<void> _resolveTicket() async {
    try {
      await widget.repo.updateTicketStatus(widget.ticket.id, 'resolved');
      if (!mounted) return;
      setState(() => _currentStatus = 'resolved');
      widget.onStatusChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد حل التذكرة بنجاح! شكراً لتواصلك مع السنتر.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Error resolving ticket: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(t, isDark, textPrimary, textSecondary),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _buildRepliesList(isDark, textPrimary, textSecondary),
          ),
          _buildReplyInput(isDark, surfaceColor, textPrimary),
        ],
      ),
    );
  }

  Widget _buildHeader(SupportTicket t, bool isDark, Color textPrimary, Color textSecondary) {
    final canResolve = _currentStatus != 'resolved' && _currentStatus != 'closed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.subject,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              StatusChip(
                label: _statusArabic(_currentStatus),
                status: _getChipStatus(_currentStatus),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.description,
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          if (canResolve) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _resolveTicket,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text(
                  'تم حل استفساري بنجاح ✅',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepliesList(bool isDark, Color textPrimary, Color textSecondary) {
    if (_replies.isEmpty) {
      return Center(
        child: Text(
          'لا توجد ردود مسجلة بعد على هذه التذكرة.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _replies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final reply = _replies[index];
        final isMine = reply.userId == widget.ticket.userId;
        final bubbleBg = isMine ? AppColors.primary : (isDark ? AppColors.darkSurface : Colors.grey.shade200);
        final bubbleText = isMine ? Colors.white : (isDark ? Colors.white : Colors.black87);
        final timeText = isMine ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54);

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                bottomLeft: !isMine ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMine ? Icons.person_rounded : Icons.school_rounded,
                      size: 13,
                      color: isMine ? Colors.white70 : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMine ? 'أنت (الطالب)' : 'المعلم / إدارة السنتر 👨‍🏫',
                      style: TextStyle(
                        color: isMine ? Colors.white : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.message,
                  style: TextStyle(color: bubbleText, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(reply.createdAt, locale: 'ar'),
                  style: TextStyle(
                    color: timeText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyInput(bool isDark, Color surfaceColor, Color textPrimary) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'اكتب ردك هنا...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _isReplying ? null : _sendReply,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _isReplying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  ChipStatus _getChipStatus(String status) {
    return switch (status.toLowerCase()) {
      'open' => ChipStatus.warning,
      'in_progress' => ChipStatus.info,
      'closed' => ChipStatus.success,
      _ => ChipStatus.neutral,
    };
  }
}
