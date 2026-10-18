import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/user_provisioning_service.dart';
import '../../../../design_system/components/editable_avatar.dart';
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
  String? _centerId;

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'suspended'
  String _selectedRoleFilter = 'all'; // 'all', 'staff', 'admin'
  String? _selectedBranchFilter; // null = all

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
          .select('id, full_name, email, role, status, center_id, phone_number, avatar_url, branch_id')
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
      final bRes = await branchesQuery.order('name');

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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (_) {}
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
                            .toList()
                          ..insert(
                            0,
                            const DropdownMenuItem(
                              value: null,
                              child: Text('بدون فرع محدد'),
                            ),
                          ),
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
    String? selectedBranchId = staff['branch_id'] as String?;
    if (selectedBranchId != null &&
        !_branches.any((b) => b['id']?.toString() == selectedBranchId)) {
      selectedBranchId = null;
    }
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
                            .toList()
                          ..insert(
                            0,
                            const DropdownMenuItem(
                              value: null,
                              child: Text('بدون فرع محدد'),
                            ),
                          ),
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
                      setStateDialog(() => isSubmitting = true);

                      final nav = Navigator.of(ctx);
                      try {
                        await Supabase.instance.client
                            .from('profiles')
                            .update({
                              'full_name': nameCtrl.text.trim(),
                              'role': role,
                              'branch_id': selectedBranchId,
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

  Future<void> _toggleStaffStatus(Map<String, dynamic> staff) async {
    final status = (staff['status'] as String? ?? 'active').toLowerCase();
    final isActive = status != 'suspended';

    if (isActive) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('إيقاف حساب الموظف'),
          content: Text(
            'هل أنت متأكد من رغبتك في إيقاف حساب الموظف "${staff['full_name']}" مؤقتاً؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إيقاف مؤقت'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await Supabase.instance.client.rpc(
          'suspend_user',
          params: {'user_uid': staff['id']},
        );
        _loadStaff();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إيقاف حساب الموظف مؤقتاً')),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الإيقاف: $err')),
          );
        }
      }
    } else {
      try {
        await Supabase.instance.client.rpc(
          'activate_user',
          params: {'user_uid': staff['id']},
        );
        _loadStaff();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تنشيط حساب الموظف بنجاح')),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل التنشيط: $err')),
          );
        }
      }
    }
  }

  Future<void> _deleteStaff(Map<String, dynamic> staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الموظف نهائياً'),
        content: Text(
          'هل أنت متأكد من حذف حساب الموظف "${staff['full_name']}" وسجلاته نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.',
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
          params: {'target_user_id': staff['id']},
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

  Widget _buildKpiSection(
    bool isDark,
    int totalCount,
    int receptionCount,
    int adminCount,
    int suspendedCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final kpiCards = [
          _buildKpiCard(
            title: 'إجمالي الكادر',
            value: '$totalCount',
            icon: Icons.badge_rounded,
            color: AppColors.info,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'موظفو الاستقبال',
            value: '$receptionCount',
            icon: Icons.support_agent_rounded,
            color: Colors.blue,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'المشرفون والمديرون',
            value: '$adminCount',
            icon: Icons.admin_panel_settings_rounded,
            color: AppColors.adminRole,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'حسابات معلقة',
            value: '$suspendedCount',
            icon: Icons.block_rounded,
            color: Colors.orange,
            isDark: isDark,
          ),
        ];

        if (isNarrow) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: kpiCards,
          );
        }

        return Row(
          children: kpiCards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: card,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'بحث باسم الموظف، البريد الإلكتروني، أو رقم الهاتف...',
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.info, width: 1.2),
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.white,
          ),
        );

        final filterChips = Row(
          mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _buildStatusFilterChip('all', 'الكل', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('active', 'النشطون', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('suspended', 'المعلقة', isDark),
            const SizedBox(width: 8),
            _buildRoleFilterChip('all', 'جميع الأدوار', isDark),
            const SizedBox(width: 4),
            _buildRoleFilterChip('staff', 'موظف استقبال', isDark),
            const SizedBox(width: 4),
            _buildRoleFilterChip('admin', 'مشرف نظام', isDark),
            if (_branches.length > 1) ...[
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.black12,
                    width: 0.8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedBranchFilter,
                    hint: const Text('جميع الفروع', style: TextStyle(fontSize: 11)),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('جميع الفروع'),
                      ),
                      ..._branches.map(
                        (b) => DropdownMenuItem<String?>(
                          value: b['id']?.toString(),
                          child: Text(b['name']?.toString() ?? ''),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedBranchFilter = val),
                  ),
                ),
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: filterChips,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            filterChips,
          ],
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
      selectedColor: AppColors.info.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.info
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.info
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildRoleFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedRoleFilter == value;
    final color = value == 'admin' ? AppColors.adminRole : AppColors.info;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedRoleFilter = value),
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? color
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? color
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildStaffCard(BuildContext context, Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final role = p['role'] as String? ?? 'staff';
    final isAdmin = role.toLowerCase() == 'admin';
    final status = (p['status'] as String? ?? 'active').toLowerCase();
    final isActive = status != 'suspended';
    final phoneNumber = p['phone_number'] as String?;
    final branchId = p['branch_id'] as String?;

    final branchName = branchId != null
        ? _branches
            .where((b) => b['id']?.toString() == branchId)
            .map((b) => b['name']?.toString())
            .firstOrNull
        : null;

    final roleColor = isAdmin ? AppColors.adminRole : AppColors.info;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black12,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Row: Avatar + Name/Email + Status Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EditableAvatar(
                avatarUrl: p['avatar_url'] as String?,
                name: (p['full_name'] as String?) ?? 'موظف',
                role: role,
                userId: p['id']?.toString(),
                userEmail: p['email']?.toString(),
                radius: 19,
                onAvatarChanged: (_) => _loadStaff(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['full_name'] as String?) ?? 'موظف',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p['email']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive ? 'نشط' : 'معلق',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Role & Branch Badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: roleColor.withValues(alpha: 0.25),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin ? Icons.admin_panel_settings_outlined : Icons.badge_outlined,
                      size: 11,
                      color: roleColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _roleInArabic(role),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (branchName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: Colors.blue),
                      const SizedBox(width: 3),
                      Text(
                        branchName,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Phone tap-to-call
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _makePhoneCall(phoneNumber),
              borderRadius: BorderRadius.circular(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    phoneNumber,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 10),

          // Action Toolbar Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'رمز الدخول السريع (QR)',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.blue),
                    onPressed: () => _showLoginQr(p),
                  ),
                  IconButton(
                    tooltip: 'تعيين كلمة المرور',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.password_rounded, size: 18, color: Colors.indigo),
                    onPressed: () => _showPasswordDialog(p),
                  ),
                  IconButton(
                    tooltip: 'تعديل البيانات',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_rounded, size: 17, color: AppColors.info),
                    onPressed: () => _showEditStaffDialog(p),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isActive ? 'إيقاف الحساب مؤقتاً' : 'تنشيط الحساب',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                      size: 17,
                      color: isActive ? Colors.orange : Colors.green,
                    ),
                    onPressed: () => _toggleStaffStatus(p),
                  ),
                  IconButton(
                    tooltip: 'حذف الموظف نهائياً',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                    onPressed: () => _deleteStaff(p),
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
      final q = _searchController.text.toLowerCase().trim();
      final name = (p['full_name'] as String? ?? '').toLowerCase();
      final email = (p['email'] as String? ?? '').toLowerCase();
      final phone = (p['phone_number'] as String? ?? '').toLowerCase();
      final branchId = p['branch_id'] as String?;
      final branchName = branchId != null
          ? (_branches.where((b) => b['id']?.toString() == branchId).map((b) => (b['name']?.toString() ?? '').toLowerCase()).firstOrNull ?? '')
          : '';

      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          branchName.contains(q);

      if (!matchesSearch) return false;

      final status = (p['status'] as String? ?? 'active').toLowerCase();
      final isActive = status != 'suspended';
      if (_selectedStatusFilter == 'active' && !isActive) {
        return false;
      }
      if (_selectedStatusFilter == 'suspended' && isActive) {
        return false;
      }

      final role = (p['role'] as String? ?? 'staff').toLowerCase();
      if (_selectedRoleFilter != 'all' && role != _selectedRoleFilter) {
        return false;
      }

      if (_selectedBranchFilter != null && branchId != _selectedBranchFilter) {
        return false;
      }

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _staffProfiles.length;
    final receptionCount = _staffProfiles.where((p) => (p['role'] as String? ?? '').toLowerCase() == 'staff').length;
    final adminCount = _staffProfiles.where((p) => (p['role'] as String? ?? '').toLowerCase() == 'admin').length;
    final suspendedCount = _staffProfiles.where((p) => (p['status'] as String? ?? '').toLowerCase() == 'suspended').length;

    return PortalPageShell(
      title: 'إدارة الكادر الإداري والموظفين',
      subtitle: 'تسجيل موظفي الاستقبال، مشرفي الفروع، تحديد الأدوار، وإدارة الصلاحيات.',
      icon: Icons.badge_rounded,
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
          _buildKpiSection(
            isDark,
            totalCount,
            receptionCount,
            adminCount,
            suspendedCount,
          ),
          const SizedBox(height: 12),
          _buildSearchAndFilterBar(isDark),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: _searchController.text.isNotEmpty ||
                      _selectedStatusFilter != 'all' ||
                      _selectedRoleFilter != 'all' ||
                      _selectedBranchFilter != null
                  ? 'لا توجد نتائج تطابق بحثك'
                  : 'لا يوجد موظفون مسجلون',
              emptySubtitle: _searchController.text.isNotEmpty ||
                      _selectedStatusFilter != 'all' ||
                      _selectedRoleFilter != 'all' ||
                      _selectedBranchFilter != null
                  ? 'جرّب تعديل مصطلحات البحث أو تغيير فلاتر الدور والفرع.'
                  : 'يمكنك قيد وإضافة موظفين جدد ومسؤولي فروع عبر زر (تسجيل موظف جديد) بالأعلى.',
              emptyIcon: Icons.badge_outlined,
              onRetry: _loadStaff,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 850;
                  final isMedium = constraints.maxWidth > 580;

                  if (isWide) {
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 215,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _buildStaffCard(context, filtered[i]),
                    );
                  }

                  if (isMedium) {
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 215,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _buildStaffCard(context, filtered[i]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildStaffCard(context, filtered[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
