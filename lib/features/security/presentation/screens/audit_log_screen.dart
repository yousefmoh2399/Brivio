import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
    final criticalCount = _items.where((i) => i.isHighRisk).length;
    final financialCount = _items.where((i) => i.isFinancial).length;
    final gradesCount = _items.where((i) => i.isGradeRelated).length;

    return PortalPageShell(
      title: 'سجل التدقيق الأمني والرقابة الإدارية',
      subtitle: 'رصد فوري لجميع العمليات الحساسة (الحذف، استرداد الأموال، تعديل النتائج، الصلاحيات).',
      icon: Icons.shield_rounded,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.picture_as_pdf_rounded,
          label: 'تصدير تقرير أمني PDF',
          onPressed: _exportSecurityAuditPdf,
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildKpiCard(
                  label: 'إجمالي السجلات',
                  value: _items.length.toString(),
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  isSelected: _riskFilter == 'all',
                  onTap: () => setState(() => _riskFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  label: 'عمليات حرجة وحذف 🚨',
                  value: criticalCount.toString(),
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.error,
                  isSelected: _riskFilter == 'high_risk',
                  onTap: () => setState(() => _riskFilter = 'high_risk'),
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  label: 'معاملات واسترداد مالي 💸',
                  value: financialCount.toString(),
                  icon: Icons.monetization_on_rounded,
                  color: AppColors.success,
                  isSelected: _riskFilter == 'financial',
                  onTap: () => setState(() => _riskFilter = 'financial'),
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  label: 'تعديلات درجات وامتحانات 📝',
                  value: gradesCount.toString(),
                  icon: Icons.assignment_turned_in_rounded,
                  color: AppColors.purple,
                  isSelected: _riskFilter == 'grades',
                  onTap: () => setState(() => _riskFilter = 'grades'),
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  label: 'أمان وصلاحيات 🔐',
                  value: _items.where((i) => i.isSecurityRelated).length.toString(),
                  icon: Icons.admin_panel_settings_rounded,
                  color: Colors.indigo,
                  isSelected: _riskFilter == 'security',
                  onTap: () => setState(() => _riskFilter = 'security'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Search & Table Filter Row ──
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: 'بحث باسم المنفّذ، المعرف، أو تفاصيل العملية...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _tableFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الجدول / الكيان',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: tables
                      .map(
                        (table) => DropdownMenuItem(
                          value: table,
                          child: Text(table == 'all' ? 'جميع الجداول' : table),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _tableFilter = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Header count label ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عرض ${filtered.length} عملية تدقيق موثقة',
                style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
              ),
              if (_riskFilter != 'all' || _tableFilter != 'all' || _searchQuery.isNotEmpty)
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
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.isHighRisk
                            ? AppColors.error.withValues(alpha: 0.4)
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: item.isHighRisk ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.isHighRisk
                              ? AppColors.error.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Leading Icon Badge
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: item.color, size: 24),
                        ),
                        const SizedBox(width: 12),

                        // Center content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.humanDescription,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: item.color.withValues(alpha: 0.25)),
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
                              const SizedBox(height: 5),
                              Text(
                                'الجدول: ${item.tableName} • المعرف: ${item.recordId ?? "غير محدد"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 14, color: textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'المنفّذ: ${item.actorUserId ?? "النظام الذاتي"}',
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.access_time_rounded, size: 14, color: textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.createdLabel,
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Action Button
                        IconButton.filledTonal(
                          tooltip: 'فحص التغييرات والبيانات الكاملة',
                          onPressed: () => _showAuditDetails(item),
                          icon: const Icon(Icons.code_rounded, size: 18),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.color),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• وصف العملية: ${item.humanDescription}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('• المستخدم المنفّذ: ${item.actorUserId ?? "النظام التلقائي"}'),
                        const SizedBox(height: 4),
                        Text('• المعرف المرجعي: ${item.recordId ?? "غير محدد"}'),
                        const SizedBox(height: 4),
                        Text('• التوقيت: ${item.createdLabel}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (item.oldData != null) ...[
                    const Text('البيانات السابقة (قبل التعديل):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: SelectableText(
                        _formatJson(item.oldData),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (item.newData != null) ...[
                    const Text('البيانات الجديدة (بعد التعديل):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: SelectableText(
                        _formatJson(item.newData),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
    if (tbl == 'user_roles' || tbl == 'profiles' || tbl == 'permissions') return true;
    if ((tbl == 'invoices' || tbl == 'payments') && act == 'update') return true;
    return false;
  }

  bool get isFinancial {
    final tbl = tableName.toLowerCase();
    return tbl.contains('invoice') || tbl.contains('payment') || tbl.contains('ledger') || tbl.contains('cash') || tbl.contains('booklet_sale');
  }

  bool get isGradeRelated {
    final tbl = tableName.toLowerCase();
    return tbl.contains('exam') || tbl.contains('grade') || tbl.contains('score') || tbl.contains('attempt');
  }

  bool get isSecurityRelated {
    final tbl = tableName.toLowerCase();
    return tbl.contains('role') || tbl.contains('user') || tbl.contains('permission') || tbl.contains('auth');
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
