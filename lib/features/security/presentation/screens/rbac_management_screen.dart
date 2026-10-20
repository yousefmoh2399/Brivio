import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';

class RbacManagementScreen extends StatefulWidget {
  const RbacManagementScreen({super.key});

  @override
  State<RbacManagementScreen> createState() => _RbacManagementScreenState();
}

class _RbacManagementScreenState extends State<RbacManagementScreen> {
  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> _roles = [];
  Map<String, int> _rolePermCounts = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Search & filter controllers
  final TextEditingController _roleSearchController = TextEditingController();
  final TextEditingController _permissionSearchController = TextEditingController();
  String _selectedModuleFilter = 'all';

  // Core system roles that cannot be deleted
  static const Set<String> _protectedRoles = {
    'admin',
    'superadmin',
    'teacher',
    'student',
    'parent',
    'staff',
  };

  @override
  void initState() {
    super.initState();
    _loadRbacData();
  }

  @override
  void dispose() {
    _roleSearchController.dispose();
    _permissionSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadRbacData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pRes = await Supabase.instance.client
          .from('permissions')
          .select()
          .order('module');
      final rRes = await Supabase.instance.client
          .from('roles')
          .select()
          .order('name');

      final counts = <String, int>{};
      try {
        final rpRes = await Supabase.instance.client
            .from('role_permissions')
            .select('role_id');
        for (final row in rpRes) {
          final rid = row['role_id']?.toString() ?? '';
          if (rid.isNotEmpty) {
            counts[rid] = (counts[rid] ?? 0) + 1;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _permissions = (pRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _roles = (rRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _rolePermCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createRole(String roleName, String description) async {
    try {
      await Supabase.instance.client.from('roles').insert({
        'name': roleName.trim().toLowerCase(),
        'description': description.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الدور الأمني "$roleName" بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRbacData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إنشاء الدور: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRole(Map<String, dynamic> role) async {
    final roleName = role['name']?.toString() ?? '';
    if (_protectedRoles.contains(roleName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف الأدوار الأساسية للنظام.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الدور'),
        content: Text('هل أنت متأكد من حذف الدور الأمني "$roleName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف الدور'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('role_permissions')
          .delete()
          .eq('role_id', role['id']);
      await Supabase.instance.client
          .from('roles')
          .delete()
          .eq('id', role['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الدور "$roleName" بنجاح.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRbacData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف الدور: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateRoleModal() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.adminRole),
            SizedBox(width: 8),
            Text('إضافة دور أمني جديد'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدور (باللغة الإنجليزية)',
                      hintText: 'مثال: receptionist, cashier, supervisor...',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'يرجى إدخال اسم الدور.';
                      }
                      if (v.trim().length < 2) {
                        return 'يجب أن يكون الاسم حرفين على الأقل.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'الوصف والمسؤوليات (بالعربية)',
                      hintText: 'اكتب وصفاً لطبيعة صلاحيات هذا الدور...',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'يرجى إدخال وصف للدور.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _createRole(nameCtrl.text, descCtrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ وإنشاء الدور'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRolePermissions(
    Map<String, dynamic> role,
    List<String> selectedPerms,
  ) async {
    try {
      final roleId = role['id'];

      // Delete existing
      await Supabase.instance.client
          .from('role_permissions')
          .delete()
          .eq('role_id', roleId);

      // Insert new
      if (selectedPerms.isNotEmpty) {
        final inserts = selectedPerms
            .map((permId) => {'role_id': roleId, 'permission_id': permId})
            .toList();

        await Supabase.instance.client.from('role_permissions').insert(inserts);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث صلاحيات الدور "${role['name']}" بنجاح (${selectedPerms.length} صلاحية)!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadRbacData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث الصلاحيات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAssignPermissionModal(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (context) => _AssignPermissionDialog(
        role: role,
        allPermissions: _permissions,
        onSave: (selectedPerms) {
          _updateRolePermissions(role, selectedPerms);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildKpiSection() {
    final totalRoles = _roles.length;
    final totalPermissions = _permissions.length;
    final modules = _permissions
        .map((p) => (p['module'] as String? ?? 'core').toLowerCase())
        .toSet()
        .length;
    final customRoles = _roles
        .where((r) => !_protectedRoles.contains(r['name']?.toString().toLowerCase()))
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        final items = [
          _buildKpiCard(
            title: 'إجمالي أدوار النظام',
            value: totalRoles.toString(),
            icon: Icons.shield_rounded,
            color: AppColors.adminRole,
            subtitle: '$customRoles أدوار مخصصة إضافية',
          ),
          _buildKpiCard(
            title: 'دليل الصلاحيات الأمني',
            value: totalPermissions.toString(),
            icon: Icons.lock_open_rounded,
            color: Colors.teal,
            subtitle: 'صلاحيات وصول للبيانات والعمليات',
          ),
          _buildKpiCard(
            title: 'الوحدات والأنظمة الفرعية',
            value: modules.toString(),
            icon: Icons.widgets_rounded,
            color: Colors.indigo,
            subtitle: 'أكاديميا، مالية، حضور، وغيرها',
          ),
          _buildKpiCard(
            title: 'أدوار النظام الأساسية',
            value: (totalRoles - customRoles).toString(),
            icon: Icons.admin_panel_settings_rounded,
            color: Colors.green,
            subtitle: 'محمية من الحذف غير المقصود',
          ),
        ];

        if (isDesktop) {
          return Row(
            children: items
                .map((widget) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: widget,
                      ),
                    ))
                .toList(),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: items[0]),
                const SizedBox(width: 8),
                Expanded(child: items[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: items[2]),
                const SizedBox(width: 8),
                Expanded(child: items[3]),
              ],
            ),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PortalPageShell(
        title: 'إدارة الأدوار والصلاحيات (RBAC)',
        subtitle:
            'التحكم في أدوار المستخدمين، حوكمة الوصول، وإدارة مصفوفة الصلاحيات الأمنية.',
        icon: Icons.security_rounded,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.add_circle_outline_rounded,
            label: 'إضافة دور جديد',
            onPressed: _showCreateRoleModal,
            primary: true,
          ),
          PortalAction(
            icon: Icons.refresh_rounded,
            label: 'تحديث',
            onPressed: _loadRbacData,
          ),
        ],
        headerWidgets: [
          _buildKpiSection(),
          const SizedBox(height: 14),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: const Icon(Icons.shield_rounded),
                text: 'أدوار النظام (${_roles.length})',
              ),
              Tab(
                icon: const Icon(Icons.policy_rounded),
                text: 'دليل ومصفوفة الصلاحيات (${_permissions.length})',
              ),
            ],
          ),
        ],
        child: PortalStateView(
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          isEmpty: false,
          emptyTitle: 'لا توجد بيانات أمان',
          emptySubtitle: 'لم يتم العثور على أي أدوار أو صلاحيات مسجلة.',
          emptyIcon: Icons.security_rounded,
          onRetry: _loadRbacData,
          child: TabBarView(
            children: [
              _buildRolesTab(),
              _buildPermissionsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRolesTab() {
    final query = _roleSearchController.text.trim().toLowerCase();
    final filtered = _roles.where((r) {
      if (query.isEmpty) return true;
      final name = (r['name'] as String? ?? '').toLowerCase();
      final desc = (r['description'] as String? ?? '').toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: TextField(
            controller: _roleSearchController,
            decoration: InputDecoration(
              hintText: 'بحث باسم الدور أو الوصف...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              suffixIcon: _roleSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _roleSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        // Roles List / Grid
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 54,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _roles.isEmpty
                            ? 'لا توجد أدوار نظام مسجلة حالياً.'
                            : 'لا توجد أدوار مطابقة للبحث.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_roles.isEmpty)
                        ElevatedButton.icon(
                          onPressed: _showCreateRoleModal,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة أول دور أمني'),
                        ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 180,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildRoleCard(filtered[i]),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _buildRoleCard(filtered[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role) {
    final roleName = (role['name'] as String? ?? 'role').toUpperCase();
    final roleId = role['id']?.toString() ?? '';
    final permCount = _rolePermCounts[roleId] ?? 0;
    final isProtected = _protectedRoles.contains(role['name']?.toString().toLowerCase());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Icon, Name & Protected Chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppColors.adminRole,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      (role['description'] as String?) ?? 'دور في النظام',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isProtected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'أساسي',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          // Permissions Count Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_open_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$permCount صلاحية ممنوحة',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showAssignPermissionModal(role),
                  icon: const Icon(Icons.edit_attributes_rounded, size: 16),
                  label: const Text('تخصيص الصلاحيات'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.adminRole.withValues(alpha: 0.12),
                    foregroundColor: AppColors.adminRole,
                  ),
                ),
              ),
              if (!isProtected) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'حذف الدور',
                  onPressed: () => _deleteRole(role),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    final query = _permissionSearchController.text.trim().toLowerCase();
    final allModules = _permissions
        .map((p) => (p['module'] as String? ?? 'core').toLowerCase())
        .toSet()
        .toList()..sort();

    final filtered = _permissions.where((p) {
      if (_selectedModuleFilter != 'all') {
        final mod = (p['module'] as String? ?? 'core').toLowerCase();
        if (mod != _selectedModuleFilter) return false;
      }
      if (query.isEmpty) return true;
      final code = (p['code'] as String? ?? '').toLowerCase();
      final action = (p['action'] as String? ?? '').toLowerCase();
      final mod = (p['module'] as String? ?? '').toLowerCase();
      return code.contains(query) || action.contains(query) || mod.contains(query);
    }).toList();

    return Column(
      children: [
        // Search & Module Filters
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
              final isNarrow = constraints.maxWidth < 600;

              final searchField = TextField(
                controller: _permissionSearchController,
                decoration: InputDecoration(
                  hintText: 'بحث بكود الصلاحية أو العملية أو الوحدة...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: _permissionSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _permissionSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              );

              final filterChips = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'الكل (${_permissions.length})',
                      isSelected: _selectedModuleFilter == 'all',
                      onSelected: () =>
                          setState(() => _selectedModuleFilter = 'all'),
                    ),
                    const SizedBox(width: 6),
                    ...allModules.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _buildFilterChip(
                          label: m.toUpperCase(),
                          isSelected: _selectedModuleFilter == m,
                          onSelected: () =>
                              setState(() => _selectedModuleFilter = m),
                        ),
                      ),
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
                    filterChips,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  Expanded(child: filterChips),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Permissions List / Grid
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.policy_outlined,
                        size: 54,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد صلاحيات مسجلة مطابقة للبحث.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 110,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) =>
                            _buildPermissionCard(filtered[i]),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) =>
                          _buildPermissionCard(filtered[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPermissionCard(Map<String, dynamic> perm) {
    final code = perm['code'] as String? ?? 'permission.code';
    final module = (perm['module'] as String? ?? 'core').toUpperCase();
    final action = perm['action'] as String? ?? 'access';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.adminRole.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.adminRole,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'وحدة: $module',
                        style: const TextStyle(fontSize: 10, color: Colors.blue),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'العملية: $action',
                        style: const TextStyle(fontSize: 10, color: Colors.purple),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const PortalStatusChip(status: 'مفعّلة'),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppColors.adminRole,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AssignPermissionDialog extends StatefulWidget {
  final Map<String, dynamic> role;
  final List<Map<String, dynamic>> allPermissions;
  final Function(List<String>) onSave;

  const _AssignPermissionDialog({
    required this.role,
    required this.allPermissions,
    required this.onSave,
  });

  @override
  State<_AssignPermissionDialog> createState() =>
      _AssignPermissionDialogState();
}

class _AssignPermissionDialogState extends State<_AssignPermissionDialog> {
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedModule = 'all';

  @override
  void initState() {
    super.initState();
    _fetchExistingPermissions();
  }

  Future<void> _fetchExistingPermissions() async {
    try {
      final res = await Supabase.instance.client
          .from('role_permissions')
          .select('permission_id')
          .eq('role_id', widget.role['id']);

      final ids = (res as List<dynamic>)
          .map((e) => e['permission_id'].toString())
          .toSet();
      if (mounted) {
        setState(() {
          _selectedIds.addAll(ids);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleName = (widget.role['name'] as String? ?? '').toUpperCase();
    final allModules = widget.allPermissions
        .map((p) => (p['module'] as String? ?? 'core').toLowerCase())
        .toSet()
        .toList()..sort();

    final filtered = widget.allPermissions.where((p) {
      if (_selectedModule != 'all') {
        final mod = (p['module'] as String? ?? 'core').toLowerCase();
        if (mod != _selectedModule) return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final code = (p['code'] as String? ?? '').toLowerCase();
      final action = (p['action'] as String? ?? '').toLowerCase();
      final mod = (p['module'] as String? ?? '').toLowerCase();
      return code.contains(q) || action.contains(q) || mod.contains(q);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_attributes_rounded, color: AppColors.adminRole),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تعيين وتعديل الصلاحيات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'الدور المحدد: $roleName',
                  style: const TextStyle(fontSize: 12, color: AppColors.adminRole),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width.clamp(280.0, 580.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search & Bulk Actions
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث في الصلاحيات...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      for (final p in filtered) {
                        _selectedIds.add(p['id'].toString());
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('تحديد الكل', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      for (final p in filtered) {
                        _selectedIds.remove(p['id'].toString());
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('إلغاء الكل', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Modules strip
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('كل الوحدات', style: TextStyle(fontSize: 11)),
                    selected: _selectedModule == 'all',
                    onSelected: (_) => setState(() => _selectedModule = 'all'),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  ...allModules.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        label: Text(m.toUpperCase(), style: const TextStyle(fontSize: 11)),
                        selected: _selectedModule == m,
                        onSelected: (_) => setState(() => _selectedModule = m),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // List of permissions
            SizedBox(
              height: 320,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('لا توجد صلاحيات مطابقة للبحث.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final p = filtered[i];
                            final id = p['id'].toString();
                            final isSelected = _selectedIds.contains(id);

                            return CheckboxListTile(
                              value: isSelected,
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                              title: Text(
                                p['code'] as String? ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              subtitle: Text(
                                'الوحدة: ${(p['module'] as String? ?? '').toUpperCase()} • العملية: ${p['action'] ?? ""}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              activeColor: AppColors.adminRole,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => widget.onSave(_selectedIds.toList()),
          child: Text('حفظ الصلاحيات (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
