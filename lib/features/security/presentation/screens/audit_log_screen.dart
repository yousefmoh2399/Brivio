import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<_AuditLogItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
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
      final rows = await query.order('created_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() {
        _items = (rows as List)
            .whereType<Map>()
            .map((row) => _AuditLogItem.fromJson(row))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tables = {
      'all',
      ..._items.map((item) => item.tableName),
      'students',
      'groups',
      'enrollments',
      'homework',
      'exams',
      'invoices',
      'attendance_records',
    }.toList()..sort();

    return PortalPageShell(
      title: 'سجل تدقيق العمليات',
      subtitle: 'تتبع كافة التعديلات وعمليات الإضافة والحذف على النظام.',
      icon: Icons.manage_search,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadAuditLogs,
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  initialValue: _tableFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تصفية حسب الجدول'),
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
                    _loadAuditLogs();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: _items.isEmpty,
              emptyTitle: 'لا توجد سجلات عمليات',
              emptySubtitle:
                  'ستظهر السجلات هنا فور حدوث أي عمليات إضافة أو تعديل في قاعدة البيانات.',
              emptyIcon: Icons.manage_search,
              onRetry: _loadAuditLogs,
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return PortalListCard(
                    icon: item.icon,
                    accentColor: item.color,
                    title: '${item.actionLabel} • ${item.tableName}',
                    subtitle:
                        'المعرف: ${item.recordId ?? "غير محدد"} | ${item.createdLabel}',
                    trailing: [
                      PortalStatusChip(status: item.actionLabel),
                      IconButton(
                        tooltip: 'عرض التفاصيل',
                        onPressed: () => _showAuditDetails(item),
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuditDetails(_AuditLogItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.actionLabel} - ${item.tableName}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: SelectableText(
              'المنفّذ (المستخدم): ${item.actorUserId ?? "النظام التلقائي"}\n'
              'المعرف المرجعي: ${item.recordId ?? "غير محدد"}\n'
              'التاريخ والوقت: ${item.createdLabel}\n\n'
              'البيانات السابقة:\n${item.oldData ?? "{}"}\n\n'
              'البيانات الجديدة:\n${item.newData ?? "{}"}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
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

  IconData get icon {
    return switch (action.toLowerCase()) {
      'insert' => Icons.add_circle,
      'delete' => Icons.delete,
      _ => Icons.edit,
    };
  }

  Color get color {
    return switch (action.toLowerCase()) {
      'insert' => AppColors.success,
      'delete' => AppColors.error,
      _ => AppColors.warning,
    };
  }

  String get createdLabel {
    final date =
        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
