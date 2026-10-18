import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _tableFilter = 'all';
  String _riskFilter = 'all';
  String _searchQuery = '';
  List<_AuditLogItem> _items = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuditLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      var query = Supabase.instance.client
          .from('audit_logs')
          .select(
            'id, table_name, record_id, action, actor_id, old_data, new_data, created_at',
          );
      if (_tableFilter != 'all') {
        query = query.eq('table_name', _tableFilter);
      }
      final rows = await query.order('created_at', ascending: false).limit(150);
      if (!mounted) return;

      final parsedItems = (rows as List)
          .whereType<Map>()
          .map((row) => _AuditLogItem.fromJson(row))
          .toList();

      setState(() {
        _items = parsedItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _errorMessage = 'حدث خطأ أثناء تحميل سجل العمليات: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<_AuditLogItem> get _filteredItems {
    return _items.where((item) {
      // Risk / Category filter
      if (_riskFilter == 'high_risk' && !item.isHighRisk) return false;
      if (_riskFilter == 'financial' && !item.isFinancial) return false;
      if (_riskFilter == 'grades' && !item.isGradeRelated) return false;
      if (_riskFilter == 'security' && !item.isSecurityRelated) return false;

      // Table filter
      if (_tableFilter != 'all' && item.tableName != _tableFilter) return false;

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesTable = item.tableName.toLowerCase().contains(q);
        final matchesActor = (item.actorUserId ?? '').toLowerCase().contains(q);
        final matchesDesc = item.humanDescription.toLowerCase().contains(q);
        final matchesRecord = (item.recordId ?? '').toLowerCase().contains(q);
        if (!matchesTable && !matchesActor && !matchesDesc && !matchesRecord) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _exportSecurityAuditPdf() async {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سجلات مطابقة للشروط لتصديرها.')),
      );
      return;
    }

    try {
      final auditMaps = filtered.map((item) {
        return {
          'id': item.id,
          'tableName': item.tableName,
          'action': item.action,
          'actionLabel': item.actionLabel,
          'actorUserId': item.actorUserId,
          'recordId': item.recordId,
          'riskLevel': item.riskLabel,
          'riskRaw': item.riskLevel,
          'humanDescription': item.humanDescription,
          'createdLabel': item.createdLabel,
          'createdAt': item.createdLabel,
          'category': item.category,
        };
      }).toList();

      final filterText = switch (_riskFilter) {
        'high_risk' => 'العمليات الحرجة والحذف فقط 🚨',
        'financial' => 'المعاملات المالية واسترداد الأموال 💸',
        'grades' => 'تعديلات الدرجات والامتحانات 📝',
        'security' => 'الصلاحيات وإدارة الأمان 🔐',
        _ => _tableFilter == 'all' ? 'جميع السجلات الموثقة' : 'جدول $_tableFilter',
      };

      await ReportGeneratorService().generateSecurityAuditLogPdf(
        auditItems: auditMaps,
        filterName: filterText,
        centerName: 'منظومة بريفيو التعليمية المتطورة',
        branchName: 'المركز الرئيسي - رقابة أمنية',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تصدير تقرير التدقيق: $e')),
      );
    }
  }

  Widget _buildKpiSection() {
    final total = _items.length;
    final criticalCount = _items.where((i) => i.isHighRisk).length;
    final financialCount = _items.where((i) => i.isFinancial).length;
    final gradesCount = _items.where((i) => i.isGradeRelated).length;
    final securityCount = _items.where((i) => i.isSecurityRelated).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 950;
        final isTablet = constraints.maxWidth >= 600 && !isDesktop;

        final cards = [
          _buildKpiCard(
            title: 'إجمالي السجلات',
            value: total.toString(),
            icon: Icons.receipt_long_rounded,
            color: AppColors.primary,
            subtitle: 'جميع العمليات المسجلة',
            isSelected: _riskFilter == 'all',
            onTap: () => setState(() => _riskFilter = 'all'),
          ),
          _buildKpiCard(
            title: 'عمليات حرجة وحذف',
            value: criticalCount.toString(),
            icon: Icons.warning_amber_rounded,
            color: AppColors.error,
            subtitle: 'حذف بيانات وسجلات أمنية',
            isSelected: _riskFilter == 'high_risk',
            onTap: () => setState(() => _riskFilter = 'high_risk'),
          ),
          _buildKpiCard(
            title: 'معاملات واسترداد مالي',
            value: financialCount.toString(),
            icon: Icons.monetization_on_rounded,
            color: AppColors.success,
            subtitle: 'فواتير وسندات ودفعات',
            isSelected: _riskFilter == 'financial',
            onTap: () => setState(() => _riskFilter = 'financial'),
          ),
          _buildKpiCard(
            title: 'تعديلات درجات وامتحانات',
            value: gradesCount.toString(),
            icon: Icons.assignment_turned_in_rounded,
            color: AppColors.purple,
            subtitle: 'تصحيح ونتائج الطلاب',
            isSelected: _riskFilter == 'grades',
            onTap: () => setState(() => _riskFilter = 'grades'),
          ),
          _buildKpiCard(
            title: 'أمان وصلاحيات',
            value: securityCount.toString(),
            icon: Icons.admin_panel_settings_rounded,
            color: Colors.indigo,
            subtitle: 'تعديل الصلاحيات والأدوار',
            isSelected: _riskFilter == 'security',
            onTap: () => setState(() => _riskFilter = 'security'),
          ),
        ];

        if (isDesktop) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        } else if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[2]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: cards[3]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[4]),
                ],
              ),
            ],
          );
        }

        // Mobile layout
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 8),
                Expanded(child: cards[3]),
              ],
            ),
            const SizedBox(height: 8),
            cards[4],
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).dividerColor.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? color : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tables = {
      'all',
      ..._items.map((item) => item.tableName),
      'students',
      'groups',
      'enrollments',
      'invoices',
      'payments',
      'exams',
      'exam_attempts',
      'user_roles',
      'attendance_records',
    }.toList()..sort();

    final filtered = _filteredItems;

    return PortalPageShell(
      title: 'سجل العمليات والرقابة الأمنية',
      subtitle:
          'رصد فوري لجميع العمليات الحساسة (الحذف، استرداد الأموال، تعديل النتائج، الصلاحيات).',
      icon: Icons.manage_search_rounded,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.picture_as_pdf_rounded,
          label: 'تصدير تقرير أمني PDF',
          onPressed: _exportSecurityAuditPdf,
          primary: true,
        ),
        PortalAction(
          icon: Icons.refresh_rounded,
          label: 'تحديث',
          onPressed: _loadAuditLogs,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI Summary Strip ──
          _buildKpiSection(),
          const SizedBox(height: 14),

          // ── Search & Table Filter Section ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;

                final searchField = TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: 'بحث باسم المنفّذ، المعرف، أو تفاصيل العملية...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    isDense: true,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                );

                final tableDropdown = DropdownButtonFormField<String>(
                  initialValue: _tableFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الجدول / الكيان',
                    isDense: true,
                    prefixIcon: Icon(Icons.table_chart_rounded, size: 18),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: tables
                      .map(
                        (table) => DropdownMenuItem(
                          value: table,
                          child: Text(
                            table == 'all' ? 'جميع الجداول' : table,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _tableFilter = value);
                  },
                );

                final filterChips = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip(
                        label: 'الكل (${_items.length})',
                        isSelected: _riskFilter == 'all',
                        onTap: () => setState(() => _riskFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      _buildCategoryChip(
                        label: 'حرجة وحذف 🚨',
                        isSelected: _riskFilter == 'high_risk',
                        color: AppColors.error,
                        onTap: () => setState(() => _riskFilter = 'high_risk'),
                      ),
                      const SizedBox(width: 6),
                      _buildCategoryChip(
                        label: 'معاملات مالية 💸',
                        isSelected: _riskFilter == 'financial',
                        color: AppColors.success,
                        onTap: () => setState(() => _riskFilter = 'financial'),
                      ),
                      const SizedBox(width: 6),
                      _buildCategoryChip(
                        label: 'درجات وامتحانات 📝',
                        isSelected: _riskFilter == 'grades',
                        color: AppColors.purple,
                        onTap: () => setState(() => _riskFilter = 'grades'),
                      ),
                      const SizedBox(width: 6),
                      _buildCategoryChip(
                        label: 'صلاحيات وأمان 🔐',
                        isSelected: _riskFilter == 'security',
                        color: Colors.indigo,
                        onTap: () => setState(() => _riskFilter = 'security'),
                      ),
                    ],
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      tableDropdown,
                      const SizedBox(height: 8),
                      filterChips,
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 12),
                        SizedBox(width: 220, child: tableDropdown),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: filterChips,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── Header count label ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عرض ${filtered.length} عملية تدقيق موثقة',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_riskFilter != 'all' ||
                  _tableFilter != 'all' ||
                  _searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _riskFilter = 'all';
                      _tableFilter = 'all';
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('إلغاء التصفية'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ── List of Audit Entries ──
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'لا توجد سجلات مطابقة',
              emptySubtitle: 'جرب تغيير معايير البحث أو التصفية لعرض السجلات.',
              emptyIcon: Icons.shield_outlined,
              onRetry: _loadAuditLogs,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildAuditLogCard(filtered[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? AppColors.adminRole;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: activeColor,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAuditLogCard(_AuditLogItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isHighRisk
              ? AppColors.error.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor.withValues(alpha: 0.12),
          width: item.isHighRisk ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: item.isHighRisk
                ? AppColors.error.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Action & Table Badges + Risk + Inspect Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _actionColor(item.action).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.actionLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _actionColor(item.action),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'جدول: ${item.tableName}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        item.riskLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'فحص التغييرات',
                onPressed: () => _showAuditDetails(item),
                icon: const Icon(Icons.code_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Human Description
          Text(
            item.humanDescription,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          // Footer: Actor, Record ID, and Time
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'المنفّذ: ${item.actorUserId ?? "النظام التلقائي"}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              if (item.recordId != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(
                      'المعرف: ${item.recordId}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    item.createdLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    return switch (action.toLowerCase()) {
      'insert' => Colors.green,
      'delete' => Colors.red,
      'update' => Colors.blue,
      _ => Colors.grey,
    };
  }

  void _showAuditDetails(_AuditLogItem item) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              Icon(item.icon, color: item.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${item.actionLabel} - ${item.tableName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.riskLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 700.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• وصف العملية: ${item.humanDescription}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• المستخدم المنفّذ: ${item.actorUserId ?? "النظام التلقائي"}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• المعرف المرجعي: ${item.recordId ?? "غير محدد"}',
                        ),
                        const SizedBox(height: 4),
                        Text('• التوقيت: ${item.createdLabel}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (item.oldData != null) ...[
                    const Text(
                      'البيانات السابقة (قبل التعديل):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SelectableText(
                        _formatJson(item.oldData),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (item.newData != null) ...[
                    const Text(
                      'البيانات الجديدة (بعد التعديل):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SelectableText(
                        _formatJson(item.newData),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  static String _formatJson(Object? data) {
    if (data == null) return '{}';
    try {
      if (data is String) {
        final decoded = jsonDecode(data);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      }
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}

class _AuditLogItem {
  final String id;
  final String tableName;
  final String? recordId;
  final String action;
  final String? actorUserId;
  final Object? oldData;
  final Object? newData;
  final DateTime createdAt;

  const _AuditLogItem({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    required this.actorUserId,
    required this.oldData,
    required this.newData,
    required this.createdAt,
  });

  factory _AuditLogItem.fromJson(Map row) {
    return _AuditLogItem(
      id: row['id']?.toString() ?? '',
      tableName: row['table_name']?.toString() ?? 'unknown',
      recordId: row['record_id']?.toString(),
      action: row['action']?.toString() ?? 'UPDATE',
      actorUserId: row['actor_id']?.toString(),
      oldData: row['old_data'],
      newData: row['new_data'],
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get actionLabel {
    return switch (action.toLowerCase()) {
      'insert' => 'إضافة',
      'delete' => 'حذف',
      'update' => 'تعديل',
      _ => action,
    };
  }

  bool get isHighRisk {
    final act = action.toLowerCase();
    final tbl = tableName.toLowerCase();
    if (act == 'delete') return true;
    if (tbl == 'user_roles' || tbl == 'profiles' || tbl == 'permissions') {
      return true;
    }
    if ((tbl == 'invoices' || tbl == 'payments') && act == 'update') {
      return true;
    }
    return false;
  }

  bool get isFinancial {
    final tbl = tableName.toLowerCase();
    return tbl.contains('invoice') ||
        tbl.contains('payment') ||
        tbl.contains('ledger') ||
        tbl.contains('cash') ||
        tbl.contains('booklet_sale');
  }

  bool get isGradeRelated {
    final tbl = tableName.toLowerCase();
    return tbl.contains('exam') ||
        tbl.contains('grade') ||
        tbl.contains('score') ||
        tbl.contains('attempt');
  }

  bool get isSecurityRelated {
    final tbl = tableName.toLowerCase();
    return tbl.contains('role') ||
        tbl.contains('user') ||
        tbl.contains('permission') ||
        tbl.contains('auth');
  }

  String get category {
    if (isHighRisk) return 'security';
    if (isFinancial) return 'financial';
    if (isGradeRelated) return 'grades';
    if (isSecurityRelated) return 'security';
    return 'general';
  }

  String get riskLevel {
    if (isHighRisk) return 'critical';
    if (isFinancial) return 'financial';
    if (isGradeRelated) return 'warning';
    return 'info';
  }

  String get riskLabel {
    return switch (riskLevel) {
      'critical' => 'حرج 🚨',
      'financial' => 'مالي 💸',
      'warning' => 'تحذير ⚠️',
      _ => 'عادي ℹ️',
    };
  }

  Color get color {
    return switch (riskLevel) {
      'critical' => AppColors.error,
      'financial' => AppColors.success,
      'warning' => AppColors.warning,
      _ => AppColors.info,
    };
  }

  IconData get icon {
    if (isHighRisk) return Icons.delete_forever_rounded;
    if (isFinancial) return Icons.monetization_on_rounded;
    if (isGradeRelated) return Icons.edit_note_rounded;
    if (isSecurityRelated) return Icons.vpn_key_rounded;
    return switch (action.toLowerCase()) {
      'insert' => Icons.add_circle_outline_rounded,
      'delete' => Icons.delete_outline_rounded,
      _ => Icons.edit_rounded,
    };
  }

  String get humanDescription {
    final act = action.toLowerCase();
    final tbl = tableName.toLowerCase();

    if (act == 'delete') {
      if (tbl == 'students') return 'حذف سجل طالب نهائياً من المنظومة';
      if (tbl == 'enrollments') return 'إلغاء قيد واشتراك طالب في مجموعة دراسية';
      if (tbl == 'groups') return 'حذف مجموعة دراسية كاملة ومواعيدها';
      if (tbl == 'invoices') return 'شطب فاتورة مستحقة';
      if (tbl == 'exams') return 'حذف امتحان ورقي/إلكتروني';
      return 'عملية حذف سجل في جدول $tableName';
    }

    if (tbl == 'exam_attempts' || tbl == 'grades') {
      return 'تعديل درجات ونتائج طالب في الامتحان';
    }
    if (tbl == 'invoices' || tbl == 'payments') {
      if (act == 'insert') return 'تسجيل دفعة أو إصدار إيصال تحصيل جديد';
      return 'تعديل تفاصيل سند قبض أو استرداد مالي';
    }
    if (tbl == 'user_roles') {
      return 'تعديل صلاحيات وصول وأدوار مستخدم';
    }
    if (tbl == 'attendance_records') {
      return 'تعديل حالة حضور أو غياب طالب';
    }

    return '$actionLabel سجل في جدول $tableName';
  }

  String get createdLabel {
    final date =
        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
