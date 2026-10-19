import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/helpdesk/data/models/support_ticket.dart';
import '../../../features/helpdesk/data/models/ticket_reply.dart';
import '../../../features/helpdesk/data/repositories/helpdesk_repository.dart';

// ─── Status & Priority Helpers ───────────────────────────────────────────────

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
    'urgent' => 'عاجلة',
    'high' => 'عالية',
    'normal' => 'عادية',
    'low' => 'منخفضة',
    _ => priority,
  };
}

Color _statusColor(String status) {
  return switch (status.toLowerCase()) {
    'open' => const Color(0xFF2563EB),
    'in_progress' => const Color(0xFFF59E0B),
    'resolved' => const Color(0xFF10B981),
    'closed' => const Color(0xFF64748B),
    _ => Colors.grey,
  };
}

Color _priorityColor(String priority) {
  return switch (priority.toLowerCase()) {
    'urgent' => const Color(0xFFEF4444),
    'high' => const Color(0xFFF97316),
    'normal' => const Color(0xFF3B82F6),
    'low' => const Color(0xFF10B981),
    _ => Colors.grey,
  };
}

IconData _priorityIcon(String priority) {
  return switch (priority.toLowerCase()) {
    'urgent' => Icons.warning_amber_rounded,
    'high' => Icons.bolt_rounded,
    'normal' => Icons.info_outline_rounded,
    'low' => Icons.low_priority_rounded,
    _ => Icons.circle_outlined,
  };
}

// ─── Main Parent Helpdesk Tab Widget ─────────────────────────────────────────

class ParentHelpdeskTab extends StatefulWidget {
  final Student? child;
  final List<GroupEntity> childGroups;
  final HelpdeskRepository? repository;
  final List<SupportTicket>? initialTickets;
  final VoidCallback? onRefresh;

  const ParentHelpdeskTab({
    super.key,
    this.child,
    this.childGroups = const [],
    this.repository,
    this.initialTickets,
    this.onRefresh,
  });

  @override
  State<ParentHelpdeskTab> createState() => _ParentHelpdeskTabState();
}

class _ParentHelpdeskTabState extends State<ParentHelpdeskTab> {
  late final HelpdeskRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<SupportTicket> _tickets = [];
  List<HelpdeskGroupOption> _groups = [];

  String _statusFilter = 'all'; // all, open, in_progress, resolved, closed
  String _priorityFilter = 'all'; // all, urgent, high, normal, low
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    try {
      timeago.setLocaleMessages('ar', timeago.ArMessages());
    } catch (_) {}

    _repository = widget.repository ?? HelpdeskRepository();
    if (widget.initialTickets != null) {
      _tickets = widget.initialTickets!;
      _isLoading = false;
      _loadGroups();
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _repository.getAvailableGroups();
      if (mounted) {
        setState(() => _groups = groups);
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getTickets(),
        _repository.getAvailableGroups(),
      ]);

      if (mounted) {
        setState(() {
          _tickets = results[0] as List<SupportTicket>;
          _groups = results[1] as List<HelpdeskGroupOption>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل تذاكر الدعم. يرجى المحاولة مرة أخرى.';
          _isLoading = false;
        });
      }
    }
  }

  // ── Filtered Tickets ───────────────────────────────────────────────────────

  List<SupportTicket> get _filteredTickets {
    return _tickets.where((ticket) {
      // Status filter
      if (_statusFilter != 'all') {
        if (_statusFilter == 'open' && ticket.status != 'open') return false;
        if (_statusFilter == 'in_progress' && ticket.status != 'in_progress') return false;
        if (_statusFilter == 'resolved' && ticket.status != 'resolved') return false;
        if (_statusFilter == 'closed' && (ticket.status != 'closed' && ticket.status != 'resolved')) {
          return false;
        }
      }

      // Priority filter
      if (_priorityFilter != 'all' && ticket.priority.toLowerCase() != _priorityFilter) {
        return false;
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchSubject = ticket.subject.toLowerCase().contains(q);
        final matchDesc = ticket.description.toLowerCase().contains(q);
        final matchId = ticket.id.toLowerCase().contains(q);
        if (!matchSubject && !matchDesc && !matchId) return false;
      }

      return true;
    }).toList();
  }

  // ── Show Create Ticket Modal ───────────────────────────────────────────────

  void _showCreateTicketModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateTicketSheet(
        groups: _groups,
        childGroups: widget.childGroups,
        onSubmit: (subject, description, priority, groupId) async {
          final newTicket = await _repository.createTicket(
            subject: subject,
            description: description,
            priority: priority,
            groupId: groupId,
          );
          if (mounted) {
            setState(() {
              _tickets.insert(0, newTicket);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إرسال تذكرة الدعم بنجاح! سيتواصل معك فريق الدعم.'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  // ── Show Ticket Details Modal ─────────────────────────────────────────────

  void _showTicketDetails(SupportTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TicketDetailsSheet(
        ticket: ticket,
        repository: _repository,
        groups: _groups,
        onReplyAdded: () {
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 380;
        final isMobile = screenWidth < 650;

        // KPI Counts
        final totalCount = _tickets.length;
        final openCount = _tickets.where((t) => t.status == 'open').length;
        final inProgressCount = _tickets.where((t) => t.status == 'in_progress').length;
        final resolvedCount = _tickets.where((t) => t.status == 'resolved' || t.status == 'closed').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Helpdesk Hero Card
            _ExecutiveHelpdeskHero(
              isNarrow: isNarrow,
              isMobile: isMobile,
              totalCount: totalCount,
              openCount: openCount,
              inProgressCount: inProgressCount,
              resolvedCount: resolvedCount,
              activeStatusFilter: _statusFilter,
              onStatusFilterSelect: (status) {
                setState(() => _statusFilter = status);
              },
              onCreateTicket: _showCreateTicketModal,
            ),
            const SizedBox(height: 16),

            // 2. Search & Filter Bar
            _buildSearchAndFilterBar(isNarrow, isMobile),
            const SizedBox(height: 16),

            // 3. Status Tabs / Pills Bar
            _buildStatusFilterPills(
              totalCount: totalCount,
              openCount: openCount,
              inProgressCount: inProgressCount,
              resolvedCount: resolvedCount,
              isNarrow: isNarrow,
            ),
            const SizedBox(height: 16),

            // 4. Ticket Content (Loading / Error / Empty / List)
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: PortalErrorBanner(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  ),
                ),
              )
            else if (_filteredTickets.isEmpty)
              _buildEmptyState(isNarrow)
            else
              _buildTicketList(isNarrow),
          ],
        );
      },
    );
  }

  // ── Search & Filter Bar ────────────────────────────────────────────────────

  Widget _buildSearchAndFilterBar(bool isNarrow, bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GlassCard(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 10 : 14,
        vertical: 10,
      ),
      borderRadius: BorderRadius.circular(16),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Row(
        children: [
          // Search Icon
          Icon(
            Icons.search_rounded,
            color: textSecondary,
            size: isNarrow ? 20 : 22,
          ),
          const SizedBox(width: 8),

          // Search Input
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(
                fontSize: isNarrow ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: isNarrow
                    ? 'بحث برقم التذكرة أو الموضوع...'
                    : 'ابحث برقم التذكرة، الموضوع، أو التفاصيل...',
                hintStyle: TextStyle(
                  color: textSecondary,
                  fontSize: isNarrow ? 11 : 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          // Clear Button
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
              ),
            ),

          // Priority Filter Dropdown
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _priorityFilter,
                icon: const Icon(Icons.filter_list_rounded, size: 16),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('كل الأولويات')),
                  DropdownMenuItem(value: 'urgent', child: Text('🔥 ${_priorityArabic('urgent')}')),
                  DropdownMenuItem(value: 'high', child: Text('⚡ ${_priorityArabic('high')}')),
                  DropdownMenuItem(value: 'normal', child: Text('📌 ${_priorityArabic('normal')}')),
                  DropdownMenuItem(value: 'low', child: Text('🟢 ${_priorityArabic('low')}')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _priorityFilter = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Filter Pills ────────────────────────────────────────────────────

  Widget _buildStatusFilterPills({
    required int totalCount,
    required int openCount,
    required int inProgressCount,
    required int resolvedCount,
    required bool isNarrow,
  }) {
    final pills = [
      _StatusPillItem(key: 'all', label: 'الكل', count: totalCount, icon: Icons.inbox_rounded),
      _StatusPillItem(key: 'open', label: 'مفتوحة', count: openCount, icon: Icons.mark_email_unread_outlined),
      _StatusPillItem(key: 'in_progress', label: 'قيد المتابعة', count: inProgressCount, icon: Icons.pending_actions_outlined),
      _StatusPillItem(key: 'resolved', label: 'تم الحل', count: resolvedCount, icon: Icons.task_alt_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: pills.map((pill) {
          final isSelected = _statusFilter == pill.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () => setState(() => _statusFilter = pill.key),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 10 : 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.parentRole
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.parentRole
                        : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.parentRole.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pill.icon,
                      size: 15,
                      color: isSelected ? Colors.white : Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pill.label,
                      style: TextStyle(
                        fontSize: isNarrow ? 11 : 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.parentRole.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pill.count}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.parentRole,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Ticket List ────────────────────────────────────────────────────────────

  Widget _buildTicketList(bool isNarrow) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredTickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ticket = _filteredTickets[index];
        final groupName = _getGroupName(ticket.groupId);
        return _ExecutiveTicketCard(
          ticket: ticket,
          groupName: groupName,
          isNarrow: isNarrow,
          onTap: () => _showTicketDetails(ticket),
        );
      },
    );
  }

  String? _getGroupName(String? groupId) {
    if (groupId == null) return null;
    final match = _groups.where((g) => g.id == groupId).firstOrNull;
    if (match != null) return match.name;
    final childMatch = widget.childGroups.where((g) => g.id == groupId).firstOrNull;
    if (childMatch != null) return childMatch.name;
    return null;
  }

  // ── Empty State ────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isNarrow) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.parentRole.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 42,
                color: AppColors.parentRole,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد نتائج مطابقة لبحثك'
                  : 'لا توجد تذاكر دعم مسجلة في هذا القسم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isNarrow ? 15 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'جرب البحث بكلمات أخرى أو مسح محتوى شريط البحث.'
                  : 'هل تواجه أي مشكلة أو لديك استفسار؟ فريق السنتر متواجد للرد والمساعدة فوراً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isNarrow ? 12 : 13,
                color: textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _showCreateTicketModal,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.parentRole,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              label: const Text(
                'إنشاء تذكرة دعم جديدة 🎫',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Pill Item Data Class ──────────────────────────────────────────────

class _StatusPillItem {
  final String key;
  final String label;
  final int count;
  final IconData icon;

  const _StatusPillItem({
    required this.key,
    required this.label,
    required this.count,
    required this.icon,
  });
}

// ─── Executive Helpdesk Hero Card ────────────────────────────────────────────

class _ExecutiveHelpdeskHero extends StatelessWidget {
  final bool isNarrow;
  final bool isMobile;
  final int totalCount;
  final int openCount;
  final int inProgressCount;
  final int resolvedCount;
  final String activeStatusFilter;
  final ValueChanged<String> onStatusFilterSelect;
  final VoidCallback onCreateTicket;

  const _ExecutiveHelpdeskHero({
    required this.isNarrow,
    required this.isMobile,
    required this.totalCount,
    required this.openCount,
    required this.inProgressCount,
    required this.resolvedCount,
    required this.activeStatusFilter,
    required this.onStatusFilterSelect,
    required this.onCreateTicket,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                  const Color(0xFF0D1B2A),
                ]
              : [
                  const Color(0xFF1E3A8A),
                  const Color(0xFF2563EB),
                  const Color(0xFF1D4ED8),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF2563EB)).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient Decorative Circle
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(isNarrow ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Title, Eyebrow & Create Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Headset Icon Badge
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Eyebrow & Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'خدمة ورعاية أولياء الأمور 🛡️',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الدعم الفني والشكاوى',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isNarrow ? 17 : 20,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Button on wider screens
                      if (!isMobile)
                        FilledButton.icon(
                          onPressed: onCreateTicket,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'تذكرة جديدة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'تواصل فوري ومباشر مع إدارة السنتر والمعلمين لمتابعة أي استفسارات تخص أبنائك وسرعة معالجتها.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: isNarrow ? 11 : 12,
                      height: 1.4,
                    ),
                  ),

                  // Full-width Create Ticket Button on Mobile
                  if (isMobile) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onCreateTicket,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_comment_rounded, size: 18),
                        label: const Text(
                          'إنشاء تذكرة دعم واستفسار جديدة 🎫',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 4 Live KPI Stat Cards
                  _buildKpiGrid(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context) {
    final metrics = [
      _KpiData(
        title: 'إجمالي التذاكر',
        count: totalCount,
        filterKey: 'all',
        icon: Icons.confirmation_number_outlined,
        accentColor: const Color(0xFF60A5FA),
      ),
      _KpiData(
        title: 'مفتوحة',
        count: openCount,
        filterKey: 'open',
        icon: Icons.mark_email_unread_outlined,
        accentColor: const Color(0xFF38BDF8),
      ),
      _KpiData(
        title: 'قيد المتابعة',
        count: inProgressCount,
        filterKey: 'in_progress',
        icon: Icons.pending_actions_outlined,
        accentColor: const Color(0xFFFBBF24),
      ),
      _KpiData(
        title: 'تم الحل',
        count: resolvedCount,
        filterKey: 'resolved',
        icon: Icons.task_alt_outlined,
        accentColor: const Color(0xFF34D399),
      ),
    ];

    return Row(
      children: metrics.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        final isSelected = activeStatusFilter == data.filterKey;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : (isNarrow ? 4 : 6),
              right: index == metrics.length - 1 ? 0 : (isNarrow ? 4 : 6),
            ),
            child: InkWell(
              onTap: () => onStatusFilterSelect(data.filterKey),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  vertical: isNarrow ? 8 : 10,
                  horizontal: isNarrow ? 4 : 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    width: isSelected ? 1.5 : 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(data.icon, color: data.accentColor, size: isNarrow ? 16 : 18),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${data.count}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isNarrow ? 15 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: isNarrow ? 9 : 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _KpiData {
  final String title;
  final int count;
  final String filterKey;
  final IconData icon;
  final Color accentColor;

  const _KpiData({
    required this.title,
    required this.count,
    required this.filterKey,
    required this.icon,
    required this.accentColor,
  });
}

// ─── Executive Ticket Card ───────────────────────────────────────────────────

class _ExecutiveTicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final String? groupName;
  final bool isNarrow;
  final VoidCallback onTap;

  const _ExecutiveTicketCard({
    required this.ticket,
    required this.groupName,
    required this.isNarrow,
    required this.onTap,
  });

  String _formatDate(DateTime dt) {
    try {
      return timeago.format(dt, locale: 'ar');
    } catch (_) {
      return '${dt.year}/${dt.month}/${dt.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final statColor = _statusColor(ticket.status);
    final prioColor = _priorityColor(ticket.priority);
    final prioIcon = _priorityIcon(ticket.priority);
    final ticketShortId = ticket.id.length >= 8 ? ticket.id.substring(0, 8).toUpperCase() : ticket.id.toUpperCase();
    final timeStr = _formatDate(ticket.createdAt);

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(isNarrow ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Meta Row: Ticket ID & Timestamp (Clean 2-item row: ZERO overflow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Ticket ID Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '#$ticketShortId',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  // Relative Time
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Subject Title
              Text(
                ticket.subject,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: isNarrow ? 14 : 15,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Description Snippet
              Text(
                ticket.description,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: isNarrow ? 12 : 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Bottom Badges Wrap (Prevents any RenderFlex overflow!)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusArabic(ticket.status),
                          style: TextStyle(
                            color: statColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: prioColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: prioColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(prioIcon, size: 13, color: prioColor),
                        const SizedBox(width: 4),
                        Text(
                          _priorityArabic(ticket.priority),
                          style: TextStyle(
                            color: prioColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Group Tag if present
                  if (groupName != null)
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: isNarrow ? 200 : 250,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school_outlined, size: 12, color: AppColors.parentRole),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              groupName!,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // View Thread Action Indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'عرض الردود والمحادثة',
                        style: TextStyle(
                          color: AppColors.parentRole,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: AppColors.parentRole,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Create Ticket Bottom Sheet Modal ────────────────────────────────────────

class _CreateTicketSheet extends StatefulWidget {
  final List<HelpdeskGroupOption> groups;
  final List<GroupEntity> childGroups;
  final Future<void> Function(
    String subject,
    String description,
    String priority,
    String? groupId,
  ) onSubmit;

  const _CreateTicketSheet({
    required this.groups,
    required this.childGroups,
    required this.onSubmit,
  });

  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _priority = 'normal';
  String? _selectedGroupId;
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();

    if (subject.isEmpty) {
      setState(() => _validationError = 'يرجى كتابة عنوان للتذكرة.');
      return;
    }
    if (description.isEmpty) {
      setState(() => _validationError = 'يرجى كتابة تفاصيل الاستفسار أو الشكوى.');
      return;
    }

    setState(() {
      _validationError = null;
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(subject, description, _priority, _selectedGroupId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _validationError = 'حدث خطأ أثناء إرسال التذكرة. يرجى المحاولة مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Combine group options
    final groupOptions = <String, String>{};
    for (final g in widget.groups) {
      groupOptions[g.id] = g.name;
    }
    for (final cg in widget.childGroups) {
      groupOptions.putIfAbsent(cg.id, () => cg.name);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.parentRole.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_comment_rounded,
                      color: AppColors.parentRole,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إنشاء تذكرة دعم واستفسار 🎫',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'سيتم إشعار إدارة السنتر والمعلم فوراً للرد على طلبك.',
                          style: TextStyle(color: textSecondary, fontSize: 11),
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
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Validation Error Banner
              if (_validationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Subject Input
              Text(
                'عنوان التذكرة / الموضوع *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: 'مثال: استفسار عن مواعيد الحصص أو نتائج الاختبارات',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  prefixIcon: const Icon(Icons.title_rounded, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Description Input
              Text(
                'تفاصيل المشكلة أو الاستفسار *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب الشكوى أو الاستفسار بالتفصيل لتتمكن الإدارة من تقديم المساعدة بدقة...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 14),

              // Group Selector
              Text(
                'المجموعة أو المادة الدراسية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: _selectedGroupId,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  prefixIcon: const Icon(Icons.school_outlined, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('دعم عام (غير مرتبط بمجموعة محددة)'),
                  ),
                  ...groupOptions.entries.map(
                    (entry) => DropdownMenuItem<String?>(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedGroupId = val),
              ),
              const SizedBox(height: 16),

              // Priority Choice Chips
              Text(
                'درجة الأهمية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['low', 'normal', 'high', 'urgent'].map((p) {
                  final isSelected = _priority == p;
                  final pColor = _priorityColor(p);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => setState(() => _priority = p),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? pColor.withValues(alpha: 0.18)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? pColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_priorityIcon(p), size: 15, color: isSelected ? pColor : textSecondary),
                              const SizedBox(height: 2),
                              Text(
                                _priorityArabic(p),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? pColor : textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.parentRole,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting ? 'جاري الإرسال...' : 'إرسال التذكرة 🚀',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
}

// ─── Ticket Details & Discussion Bottom Sheet ────────────────────────────────

class _TicketDetailsSheet extends StatefulWidget {
  final SupportTicket ticket;
  final HelpdeskRepository repository;
  final List<HelpdeskGroupOption> groups;
  final VoidCallback onReplyAdded;

  const _TicketDetailsSheet({
    required this.ticket,
    required this.repository,
    required this.groups,
    required this.onReplyAdded,
  });

  @override
  State<_TicketDetailsSheet> createState() => _TicketDetailsSheetState();
}

class _TicketDetailsSheetState extends State<_TicketDetailsSheet> {
  final TextEditingController _replyController = TextEditingController();
  late Future<List<TicketReply>> _repliesFuture;
  bool _isSending = false;
  late String _currentStatus;

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

  void _loadReplies() {
    setState(() {
      _repliesFuture = widget.repository.getReplies(widget.ticket.id);
    });
  }

  Future<void> _handleSendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await widget.repository.addReply(widget.ticket.id, message);
      _replyController.clear();
      _loadReplies();
      if (_currentStatus == 'open') {
        setState(() => _currentStatus = 'in_progress');
      }
      widget.onReplyAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إرسال الرد، يرجى المحاولة مرة أخرى.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleResolveTicket() async {
    try {
      await widget.repository.updateTicketStatus(widget.ticket.id, 'resolved');
      if (!mounted) return;
      setState(() => _currentStatus = 'resolved');
      widget.onReplyAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد حل التذكرة بنجاح! شكراً لتواصلك مع السنتر.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديث حالة التذكرة.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    try {
      return timeago.format(dt, locale: 'ar');
    } catch (_) {
      return '${dt.year}/${dt.month}/${dt.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final statColor = _statusColor(_currentStatus);
    final prioColor = _priorityColor(widget.ticket.priority);
    final ticketShortId = widget.ticket.id.length >= 8
        ? widget.ticket.id.substring(0, 8).toUpperCase()
        : widget.ticket.id.toUpperCase();

    // Group Name
    final groupMatch = widget.groups.where((g) => g.id == widget.ticket.groupId).firstOrNull;
    final groupName = groupMatch?.name;
    final canResolve = _currentStatus != 'resolved' && _currentStatus != 'closed';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Top Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _statusArabic(_currentStatus),
                          style: TextStyle(
                            color: statColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (canResolve) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _handleResolveTicket,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                          label: const Text(
                            'تم الحل ✅',
                            style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تذكرة #$ticketShortId',
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
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

                // Scrollable Thread & Ticket Info
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Subject Title
                      Text(
                        widget.ticket.subject,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Meta Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Priority Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: prioColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: prioColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_priorityIcon(widget.ticket.priority), size: 12, color: prioColor),
                                const SizedBox(width: 4),
                                Text(
                                  'أولوية ${_priorityArabic(widget.ticket.priority)}',
                                  style: TextStyle(
                                    color: prioColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Group Tag
                          if (groupName != null)
                            Container(
                              constraints: const BoxConstraints(maxWidth: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school_outlined, size: 12, color: AppColors.parentRole),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      groupName,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Created Date
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 12, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(widget.ticket.createdAt),
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Original Inquiry Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
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
                                const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.parentRole,
                                  child: Icon(Icons.person, size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'تفاصيل الاستفسار الأصلي (ولي الأمر)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.ticket.description,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Discussion Header
                      Row(
                        children: [
                          const Icon(Icons.forum_outlined, size: 18, color: AppColors.parentRole),
                          const SizedBox(width: 8),
                          Text(
                            'سجل المحادثة والردود',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Replies Future
                      FutureBuilder<List<TicketReply>>(
                        future: _repliesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final replies = snapshot.data ?? [];
                          if (replies.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.mark_chat_unread_outlined, size: 32, color: textSecondary),
                                    const SizedBox(height: 8),
                                    Text(
                                      'لا توجد ردود بعد من الإدارة أو المعلم.',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'سيتم إشعارك فور قيام إدارة السنتر بالرد على تذكرتك.',
                                      style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: replies.map((reply) {
                              final isUserReply = reply.userId == widget.ticket.userId;
                              return _buildReplyItem(reply, isUserReply, textPrimary, textSecondary, isDark);
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Fast Reply Input Bar
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    left: 16,
                    right: 16,
                    top: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: InputDecoration(
                            hintText: 'اكتب ردك أو استفسارك هنا...',
                            hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.grey.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isSending ? null : _handleSendReply,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.parentRole,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplyItem(
    TicketReply reply,
    bool isUserReply,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: isUserReply ? AppColors.parentRole : AppColors.primary,
            child: Icon(
              isUserReply ? Icons.person_rounded : Icons.support_agent_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUserReply
                    ? AppColors.parentRole.withValues(alpha: 0.06)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUserReply
                      ? AppColors.parentRole.withValues(alpha: 0.25)
                      : AppColors.primary.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isUserReply ? 'أنت (ولي الأمر)' : 'إدارة السنتر / الدعم الفني 🛡️',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isUserReply ? AppColors.parentRole : AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(reply.createdAt),
                        style: TextStyle(color: textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reply.message,
                    style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4),
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
