import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../widgets/account_password_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, role, status, center_id')
          .inFilter('role', ['staff', 'admin'])
          .order('full_name');

      final bRes = await Supabase.instance.client
          .from('branches')
          .select('id, name')
          .eq('status', 'active');

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
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    String selectedRole = 'staff';
    String? selectedBranchId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تسجيل وقيد موظف جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل للموظف',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'الدور الوظيفي',
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
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور (اختياري)',
                    helperText: 'اتركها فارغة إذا كان الموظف سيسجل دخول برمز QR.',
                    prefixIcon: const Icon(Icons.lock_outline),
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
                const SizedBox(height: 10),
                if (_branches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: const InputDecoration(
                      labelText: 'الفرع التابع له',
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    emailCtrl.text.trim().isEmpty) {
                  return;
                }
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

                final nav = Navigator.of(ctx);
                try {
                  final response = await Supabase.instance.client.functions
                      .invoke(
                        'provision-user',
                        body: {
                          'email': emailCtrl.text.trim(),
                          'fullName': nameCtrl.text.trim(),
                          'role': selectedRole,
                          'branchId': selectedBranchId,
                          if (passwordCtrl.text.isNotEmpty)
                            'password': passwordCtrl.text,
                        },
                      );

                  if (response.status < 200 || response.status >= 300) {
                    final data = response.data;
                    final message = data is Map
                        ? data['error']?.toString()
                        : null;
                    throw Exception(message ?? 'فشلت عملية إنشاء الحساب.');
                  }
                  final data = Map<String, dynamic>.from(response.data as Map);
                  if (data['success'] != true) {
                    throw Exception('فشلت عملية إنشاء الحساب.');
                  }

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
              child: const Text('تأكيد القيد'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    final nameCtrl = TextEditingController(text: staff['full_name'] as String? ?? '');
    String role = staff['role'] as String? ?? 'staff';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تعديل بيانات الموظف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم الكامل للموظف'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'الدور الوظيفي'),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('موظف استقبال / إداري')),
                  DropdownMenuItem(value: 'admin', child: Text('مشرف نظام / مدير فرع')),
                ],
                onChanged: (v) => setStateDialog(() => role = v ?? 'staff'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final nav = Navigator.of(ctx);
                try {
                  await Supabase.instance.client
                      .from('profiles')
                      .update({
                        'full_name': nameCtrl.text.trim(),
                        'role': role,
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
              child: const Text('حفظ التعديلات'),
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

  @override
  Widget build(BuildContext context) {
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
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _staffProfiles.isEmpty,
        emptyTitle: 'لا يوجد موظفون مسجلون',
        emptySubtitle: 'يمكنك قيد وإضافة موظفين جدد ومسؤولي فروع عبر زر (تسجيل موظف جديد) بالأعلى.',
        emptyIcon: Icons.badge,
        onRetry: _loadStaff,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _staffProfiles.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final p = _staffProfiles[i];
            return PortalListCard(
              icon: Icons.badge,
              accentColor: AppColors.info,
              title: (p['full_name'] as String?) ?? 'موظف',
              subtitle:
                  'البريد: ${p['email']} | الدور: ${_roleInArabic(p['role'] as String? ?? "staff")}',
              trailing: [
                IconButton(
                  tooltip: 'رمز الاستجابة السريعة (QR)',
                  onPressed: () => _showLoginQr(p),
                  icon: const Icon(Icons.qr_code_2),
                ),
                IconButton(
                  tooltip: 'تعيين كلمة المرور',
                  onPressed: () => _showPasswordDialog(p),
                  icon: const Icon(Icons.password),
                ),
                if (p['status'] == 'suspended')
                  IconButton(
                    tooltip: 'تنشيط الحساب',
                    onPressed: () async {
                      try {
                        await Supabase.instance.client.rpc(
                          'activate_user',
                          params: {'user_uid': p['id']},
                        );
                        _loadStaff();
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل التنشيط: $err')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                  )
                else
                  IconButton(
                    tooltip: 'إيقاف الحساب مؤقتاً',
                    onPressed: () async {
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
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'إيقاف مؤقت',
                                style: TextStyle(color: Colors.red),
                              ),
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
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل الإيقاف: $err')),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.block, color: Colors.red),
                  ),
                IconButton(
                  tooltip: 'تعديل البيانات',
                  onPressed: () => _showEditStaffDialog(p),
                  icon: const Icon(Icons.edit, color: Colors.blue),
                ),
                IconButton(
                  tooltip: 'حذف الموظف',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حذف الموظف نهائياً'),
                        content: const Text(
                          'هل أنت متأكد من حذف حساب الموظف نهائياً؟',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'حذف نهائي',
                              style: TextStyle(color: Colors.red),
                            ),
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
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الحذف: $err')),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                PortalStatusChip(status: p['status'] as String? ?? 'active'),
              ],
            );
          },
        ),
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
}
