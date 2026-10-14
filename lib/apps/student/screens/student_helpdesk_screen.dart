import 'package:flutter/material.dart';

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
      builder: (context) => _TicketDetailsSheet(ticket: ticket, repo: _repo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PortalPageShell(
      title: 'الدعم الفني والشكاوى',
      subtitle: 'متابعة تذاكر الدعم والطلبات والاستفسارات الفنية',
      icon: Icons.headset_mic,
      accentColor: AppColors.primary,
      actions: [
        PortalAction(
          icon: Icons.add,
          label: 'تذكرة جديدة',
          onPressed: _showCreateDialog,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _tickets.isEmpty
          ? _buildEmptyState(isDark)
          : _buildTicketsList(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
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
            'لا توجد تذاكر دعم مسجلة حالياً',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أنشئ تذكرة للتواصل مع الإدارة أو الدعم الفني بشأن دوراتك أو حسابك.',
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList(bool isDark) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return GlassCard(
          onTap: () => _viewTicket(ticket),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleIcon(
                icon: Icons.chat_bubble_outline_rounded,
                color: _getStatusColor(ticket.status),
              ),
              const SizedBox(width: 16),
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
                              fontSize: 16,
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
                    const SizedBox(height: 4),
                    Text(
                      ticket.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الأولوية: ${_priorityArabic(ticket.priority)} • ${_formatDate(ticket.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

  const _TicketDetailsSheet({required this.ticket, required this.repo});

  @override
  State<_TicketDetailsSheet> createState() => _TicketDetailsSheetState();
}

class _TicketDetailsSheetState extends State<_TicketDetailsSheet> {
  List<TicketReply> _replies = [];
  bool _isLoading = true;
  final _replyCtrl = TextEditingController();
  bool _isReplying = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    setState(() => _isLoading = true);
    try {
      final replies = await widget.repo.getReplies(widget.ticket.id);
      setState(() => _replies = replies);
    } catch (e) {
      debugPrint('Error loading replies: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.isEmpty) return;
    setState(() => _isReplying = true);
    try {
      final newReply = await widget.repo.addReply(
        widget.ticket.id,
        _replyCtrl.text,
      );
      setState(() {
        _replies.add(newReply);
        _replyCtrl.clear();
      });
    } catch (e) {
      debugPrint('Error sending reply: $e');
    } finally {
      if (mounted) setState(() => _isReplying = false);
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
                label: _statusArabic(t.status),
                status: _getChipStatus(t.status),
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
              maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                Text(
                  reply.message,
                  style: TextStyle(color: bubbleText, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reply.createdAt.hour}:${reply.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: timeText,
                    fontSize: 11,
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
