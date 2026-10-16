import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../widgets/account_password_dialog.dart';
import '../../../../core/services/user_provisioning_service.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<Map<String, dynamic>> _staffProfiles = [];
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _centerId;

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        final prof = await client
            .from('profiles')
            .select('center_id')
            .eq('id', userId)
            .maybeSingle();
        _centerId = prof?['center_id'] as String?;
      }

      var profilesQuery = client
          .from('profiles')
          .select('id, full_name, email, role, status, center_id, phone_number')
          .inFilter('role', ['staff', 'admin']);
      if (_centerId != null) {
        profilesQuery = profilesQuery.eq('center_id', _centerId!);
      }
      final res = await profilesQuery.order('full_name');

      var branchesQuery = client
          .from('branches')
          .select('id, name')
          .eq('status', 'active');
      if (_centerId != null) {
        branchesQuery = branchesQuery.eq('center_id', _centerId!);
      }
      final bRes = await branchesQuery;

      if (mounted) {
        setState(() {
          _staffProfiles = (res as List).cast<Map<String, dynamic>>();
          _branches = (bRes as List).cast<Map<String, dynamic>>();
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

  void _showProvisionStaffDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    String selectedRole = 'staff';
    String? selectedBranchId;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: AppColors.info),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تسجيل وقيد موظف جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل للموظف *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الموظف' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد';
                              if (!v.contains('@')) return 'بريد غير صالح';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف / واتساب',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'الدور الوظيفي والصلاحيات',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'staff',
                          child: Text('موظف استقبال / إداري (Staff)'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('مشرف نظام / مدير فرع (Admin)'),
                        ),
                      ],
                      onChanged: (v) =>
                          setStateDialog(() => selectedRole = v ?? 'staff'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور (اختياري)',
                        helperText: 'اتركها فارغة إذا كان الموظف سيسجل دخول برمز QR.',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setStateDialog(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_branches.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedBranchId,
                        decoration: const InputDecoration(
                          labelText: 'الفرع التابع له',
                          border: OutlineInputBorder(),
                        ),
                        items: _branches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b['id']?.toString(),
                                child: Text(b['name']?.toString() ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setStateDialog(() => selectedBranchId = v),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      if (passwordCtrl.text.isNotEmpty &&
                          passwordCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('كلمة المرور لا تقل عن 6 أحرف.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setStateDialog(() => isSubmitting = true);
                      final nav = Navigator.of(ctx);

                      try {
                        await UserProvisioningService.provisionUser(
                          email: emailCtrl.text.trim(),
                          fullName: nameCtrl.text.trim(),
                          role: selectedRole,
                          branchId: selectedBranchId,
                          centerId: _centerId,
                          phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          password: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : null,
                        );

                        nav.pop();
                        _loadStaff();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إنشاء وقيد حساب الموظف بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطأ في القيد: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(isSubmitting ? 'جاري القيد...' : 'تأكيد القيد'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: staff['full_name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: staff['phone_number'] as String? ?? '');
    String role = staff['role'] as String? ?? 'staff';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: AppColors.info),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات الموظف',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 460.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل للموظف *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الموظف' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف / واتساب',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'الدور الوظيفي',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('موظف استقبال / إداري')),
                      DropdownMenuItem(value: 'admin', child: Text('مشرف نظام / مدير فرع')),
                    ],
                    onChanged: (v) => setStateDialog(() => role = v ?? 'staff'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => isSubmitting = true);

                      final nav = Navigator.of(ctx);
                      try {
                        await Supabase.instance.client
                            .from('profiles')
                            .update({
                              'full_name': nameCtrl.text.trim(),
                              'role': role,
                              'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            })
                            .eq('id', staff['id']);

                        nav.pop();
                        _loadStaff();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تحديث بيانات الموظف بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل التحديث: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginQr(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (_) => AccountLoginQrDialog(
        profileId: staff['id']?.toString() ?? '',
        displayName: staff['full_name']?.toString() ?? 'موظف',
        email: staff['email']?.toString() ?? '',
      ),
    );
  }

  void _showPasswordDialog(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (_) => AccountPasswordDialog(
        profileId: staff['id']?.toString() ?? '',
        displayName: staff['full_name']?.toString() ?? 'موظف',
        email: staff['email']?.toString() ?? '',
      ),
    );
  }

  static String _roleInArabic(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'مشرف نظام / مدير فرع';
      case 'staff':
        return 'موظف استقبال / إداري';
      default:
        return role;
    }
  }

  Widget _buildStaffCard(BuildContext context, Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final role = p['role'] as String? ?? 'staff';
    final isAdmin = role.toLowerCase() == 'admin';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: (isAdmin ? AppColors.adminRole : AppColors.info).withValues(alpha: 0.12),
            child: Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.badge,
              color: isAdmin ? AppColors.adminRole : AppColors.info,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (p['full_name'] as String?) ?? 'موظف',
                  style: AppTypography.titleMedium(textPrimary).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p['email']?.toString() ?? '',
                  style: AppTypography.caption(textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isAdmin ? AppColors.adminRole : AppColors.info).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _roleInArabic(role),
                        style: TextStyle(
                          fontSize: 12,
                          color: isAdmin ? AppColors.adminRole : AppColors.info,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (p['phone_number'] != null && p['phone_number'].toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'هاتف: ${p['phone_number']}',
                          style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PortalStatusChip(status: p['status'] as String? ?? 'active'),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                tooltip: 'خيارات الموظف',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'qr':
                      _showLoginQr(p);
                      break;
                    case 'password':
                      _showPasswordDialog(p);
                      break;
                    case 'edit':
                      _showEditStaffDialog(p);
                      break;
                    case 'activate':
                      try {
                        await Supabase.instance.client.rpc(
                          'activate_user',
                          params: {'user_uid': p['id']},
                        );
                        _loadStaff();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تنشيط حساب الموظف')),
                          );
                        }
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل التنشيط: $err')),
                          );
                        }
                      }
                      break;
                    case 'suspend':
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('إيقاف حساب الموظف'),
                          content: const Text(
                            'هل أنت متأكد من رغبتك في إيقاف حساب هذا الموظف مؤقتاً؟',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('إيقاف مؤقت'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await Supabase.instance.client.rpc(
                            'suspend_user',
                            params: {'user_uid': p['id']},
                          );
                          _loadStaff();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إيقاف حساب الموظف')),
                            );
                          }
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل الإيقاف: $err')),
                            );
                          }
                        }
                      }
                      break;
                    case 'delete':
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف الموظف نهائياً'),
                          content: const Text(
                            'هل أنت متأكد من حذف حساب الموظف نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('حذف نهائي'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await Supabase.instance.client.rpc(
                            'hard_delete_user',
                            params: {'target_user_id': p['id']},
                          );
                          _loadStaff();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حذف حساب الموظف نهائياً')),
                            );
                          }
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل الحذف: $err')),
                            );
                          }
                        }
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'qr',
                    child: ListTile(
                      leading: Icon(Icons.qr_code_2, size: 20),
                      title: Text('رمز الدخول السريع (QR)'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'password',
                    child: ListTile(
                      leading: Icon(Icons.password, size: 20),
                      title: Text('تعيين كلمة المرور'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, size: 20, color: Colors.blue),
                      title: Text('تعديل البيانات'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (p['status'] == 'suspended')
                    const PopupMenuItem(
                      value: 'activate',
                      child: ListTile(
                        leading: Icon(Icons.check_circle, size: 20, color: Colors.green),
                        title: Text('تنشيط الحساب'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'suspend',
                      child: ListTile(
                        leading: Icon(Icons.block, size: 20, color: Colors.orange),
                        title: Text('إيقاف الحساب مؤقتاً'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      title: Text('حذف الموظف نهائياً', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _staffProfiles.where((p) {
      final q = _searchController.text.toLowerCase();
      final name = (p['full_name'] as String? ?? '').toLowerCase();
      final email = (p['email'] as String? ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return PortalPageShell(
      title: 'إدارة الكادر الإداري والموظفين',
      subtitle: 'تسجيل موظفي الاستقبال ومشرفي الفروع وإدارة الصلاحيات التشغيلية.',
      icon: Icons.badge,
      accentColor: AppColors.info,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadStaff,
        ),
        PortalAction(
          icon: Icons.person_add,
          label: 'تسجيل موظف جديد',
          onPressed: _showProvisionStaffDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'بحث بالاسم أو البريد الإلكتروني للموظف...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'لا يوجد موظفون مسجلون',
              emptySubtitle: 'يمكنك قيد وإضافة موظفين جدد ومسؤولي فروع عبر زر (تسجيل موظف جديد) بالأعلى.',
              emptyIcon: Icons.badge,
              onRetry: _loadStaff,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _buildStaffCard(context, filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
