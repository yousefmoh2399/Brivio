import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/components/glass_card.dart';

class RbacManagementScreen extends StatefulWidget {
  const RbacManagementScreen({super.key});

  @override
  State<RbacManagementScreen> createState() => _RbacManagementScreenState();
}

class _RbacManagementScreenState extends State<RbacManagementScreen> {
  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRbacData();
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

      if (mounted) {
        setState(() {
          _permissions = (pRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _roles = (rRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
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
        'name': roleName,
        'description': description,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إنشاء الدور "$roleName" بنجاح')),
        );
        _loadRbacData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء إنشاء الدور: $e')));
      }
    }
  }

  void _showCreateRoleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateRoleSheet(
        onSave: (roleName, description) {
          _createRole(roleName, description);
          Navigator.pop(context);
        },
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
          SnackBar(content: Text('تم تحديث صلاحيات الدور ${role['name']} بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحديث الصلاحيات: $e')),
        );
      }
    }
  }

  void _showAssignPermissionModal(Map<String, dynamic> role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssignPermissionSheet(
        role: role,
        allPermissions: _permissions,
        onSave: (selectedPerms) {
          _updateRolePermissions(role, selectedPerms);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PortalPageShell(
        title: 'إدارة الأدوار والصلاحيات (RBAC)',
        subtitle: 'التحكم في أدوار المستخدمين وصلاحيات الوصول لبيانات وعمليات السنتر.',
        icon: Icons.admin_panel_settings,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.add,
            label: 'إضافة دور جديد',
            onPressed: _showCreateRoleModal,
          ),
          PortalAction(
            icon: Icons.refresh,
            label: 'تحديث',
            onPressed: _loadRbacData,
          ),
        ],
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  color: AppColors.adminRole.withValues(alpha: 0.15),
                ),
                labelColor: AppColors.adminRole,
                unselectedLabelColor: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.shield_outlined),
                    text: 'أدوار النظام',
                  ),
                  Tab(
                    icon: Icon(Icons.policy_outlined),
                    text: 'دليل الصلاحيات',
                  ),
                ],
              ),
            ),
            Expanded(
              child: PortalStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: false, // handeled in tabs
                emptyTitle: 'لا توجد بيانات أمان',
                emptySubtitle: 'لم يتم العثور على أي أدوار أو صلاحيات مسجلة.',
                emptyIcon: Icons.security,
                onRetry: _loadRbacData,
                child: TabBarView(
                  children: [
                    _RolesTabView(
                      roles: _roles,
                      onAssignPermissions: _showAssignPermissionModal,
                    ),
                    _PermissionsTabView(permissions: _permissions),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolesTabView extends StatelessWidget {
  final List<Map<String, dynamic>> roles;
  final Function(Map<String, dynamic>) onAssignPermissions;

  const _RolesTabView({required this.roles, required this.onAssignPermissions});

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return const Center(child: Text('لا توجد أدوار نظام مسجلة حالياً.'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: roles.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final r = roles[i];
        final roleName = (r['name'] as String? ?? 'role').toUpperCase();
        return FadeInSlide(
          delay: Duration(milliseconds: 50 * i),
          child: GlassCard(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.success,
                  ),
                ),
                title: Text(
                  roleName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text((r['description'] as String?) ?? 'دور في النظام'),
                trailing: FilledButton.tonalIcon(
                  onPressed: () => onAssignPermissions(r),
                  icon: const Icon(Icons.edit_attributes),
                  label: const Text('الصلاحيات'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.adminRole.withValues(alpha: 0.1),
                    foregroundColor: AppColors.adminRole,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PermissionsTabView extends StatelessWidget {
  final List<Map<String, dynamic>> permissions;

  const _PermissionsTabView({required this.permissions});

  @override
  Widget build(BuildContext context) {
    if (permissions.isEmpty) {
      return const Center(child: Text('لا توجد صلاحيات مسجلة.'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group by module
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var p in permissions) {
      final mod = (p['module'] as String? ?? 'core').toUpperCase();
      grouped.putIfAbsent(mod, () => []).add(p);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: grouped.keys.length,
      itemBuilder: (ctx, i) {
        final module = grouped.keys.elementAt(i);
        final perms = grouped[module]!;

        return FadeInSlide(
          delay: Duration(milliseconds: 50 * i),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'الوحدة: $module',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassCard(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderColor: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: perms.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    itemBuilder: (context, index) {
                      final p = perms[index];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: const Icon(
                            Icons.lock_open,
                            color: AppColors.adminRole,
                          ),
                          title: Text(
                            p['code'] as String? ?? 'permission.code',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('العملية: ${p['action']}'),
                          trailing: const PortalStatusChip(status: 'مفعّلة'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreateRoleSheet extends StatefulWidget {
  final Function(String, String) onSave;

  const _CreateRoleSheet({required this.onSave});

  @override
  State<_CreateRoleSheet> createState() => _CreateRoleSheetState();
}

class _CreateRoleSheetState extends State<_CreateRoleSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassCard(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إضافة دور جديد للنظام',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الدور',
                hintText: 'مثال: manager, receptionist, cashier...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف والمهام',
                hintText: 'وصف المسؤوليات الموكلة لهذا الدور...',
                border: OutlineInputBorder(),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 32), // align top
                  child: Icon(Icons.description),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  widget.onSave(_nameController.text, _descController.text);
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.adminRole,
              ),
              child: const Text('حفظ وإنشاء الدور'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignPermissionSheet extends StatefulWidget {
  final Map<String, dynamic> role;
  final List<Map<String, dynamic>> allPermissions;
  final Function(List<String>) onSave;

  const _AssignPermissionSheet({
    required this.role,
    required this.allPermissions,
    required this.onSave,
  });

  @override
  State<_AssignPermissionSheet> createState() => _AssignPermissionSheetState();
}

class _AssignPermissionSheetState extends State<_AssignPermissionSheet> {
  final Set<String> _selectedIds = {};
  bool _isLoading = true;

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
                            'تعيين وتعديل الصلاحيات',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'الدور المحدد: ${(widget.role['name'] as String? ?? '').toUpperCase()}',
                            style: const TextStyle(
                              color: AppColors.adminRole,
                              fontWeight: FontWeight.w600,
                            ),
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.allPermissions.length,
                        itemBuilder: (ctx, i) {
                          final p = widget.allPermissions[i];
                          final id = p['id'].toString();
                          final isSelected = _selectedIds.contains(id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.add(id);
                                } else {
                                  _selectedIds.remove(id);
                                }
                              });
                            },
                            title: Text(p['code'] as String? ?? ''),
                            subtitle: Text('الوحدة: ${p['module']} • ${p['action'] ?? ""}'),
                            secondary: const Icon(
                              Icons.key,
                              color: Colors.grey,
                            ),
                            activeColor: AppColors.adminRole,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: () => widget.onSave(_selectedIds.toList()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: AppColors.adminRole,
                  ),
                  child: Text(
                    'حفظ الصلاحيات (${_selectedIds.length} محددة)',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
