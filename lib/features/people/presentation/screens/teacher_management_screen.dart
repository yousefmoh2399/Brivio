import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/user_provisioning_service.dart';
import '../../../../design_system/components/editable_avatar.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../widgets/account_password_dialog.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  late final SupabaseTeacherRepository _teacherRepo;

  List<Teacher> _teachers = [];
  List<Branch> _branches = [];
  Map<String, int> _teacherGroupCounts = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _centerId;

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'suspended'
  String? _selectedBranchFilter; // null = all
  String _selectedGroupFilter = 'all'; // 'all', 'has_groups', 'no_groups'

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
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

      final res = await _teacherRepo.fetchTeachers();

      var branchQuery = client
          .from('branches')
          .select()
          .eq('status', 'active');
      if (_centerId != null) {
        branchQuery = branchQuery.eq('center_id', _centerId!);
      }
      final bRes = await branchQuery.order('name');
      final branches = (bRes as List)
          .map((j) => Branch.fromJson(j as Map<String, dynamic>))
          .toList();

      List<Teacher> filteredTeachers = res.data;
      if (_centerId != null) {
        final centerProfilesRes = await client
            .from('profiles')
            .select('id')
            .eq('center_id', _centerId!)
            .eq('role', 'teacher');
        final centerProfileIds = (centerProfilesRes as List)
            .map((p) => p['id']?.toString())
            .whereType<String>()
            .toSet();
        final branchIds = branches.map((b) => b.id).toSet();

        filteredTeachers = res.data.where((t) {
          return centerProfileIds.contains(t.profileId) ||
              (t.primaryBranchId.isNotEmpty && branchIds.contains(t.primaryBranchId));
        }).toList();
      }

      // Fetch group counts for teachers
      final groupCounts = <String, int>{};
      try {
        final groupsRes = await client
            .from('groups')
            .select('id, teacher_id')
            .eq('status', 'active');
        for (final g in (groupsRes as List)) {
          final tId = g['teacher_id']?.toString();
          if (tId != null && tId.isNotEmpty) {
            groupCounts[tId] = (groupCounts[tId] ?? 0) + 1;
          }
        }
      } catch (_) {
        // Fallback silently if groups table is unavailable
      }

      if (mounted) {
        setState(() {
          _teachers = filteredTeachers;
          _branches = branches;
          _teacherGroupCounts = groupCounts;
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

  void _showEditTeacherDialog(Teacher teacher) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: teacher.fullName);
    final specCtrl = TextEditingController(text: teacher.specialization ?? '');
    final phoneCtrl = TextEditingController(text: teacher.phoneNumber ?? '');
    String? selectedBranchId = teacher.primaryBranchId.isEmpty
        ? null
        : teacher.primaryBranchId;
    if (selectedBranchId != null &&
        !_branches.any((b) => b.id == selectedBranchId)) {
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
                  color: AppColors.teacherRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: AppColors.teacherRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات المعلم',
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
                        labelText: 'الاسم الكامل للمعلم *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المعلم' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: specCtrl,
                      decoration: const InputDecoration(
                        labelText: 'المادة والتخصص الأكاديمي',
                        hintText: 'مثال: فيزياء للثانوية العامة',
                        border: OutlineInputBorder(),
                      ),
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
                    if (_branches.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedBranchId,
                        decoration: const InputDecoration(
                          labelText: 'الفرع التابع له',
                          border: OutlineInputBorder(),
                        ),
                        items: _branches
                            .map(
                              (b) => DropdownMenuItem<String>(
                                value: b.id,
                                child: Text(b.name),
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
                backgroundColor: AppColors.teacherRole,
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
                              'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            })
                            .eq('id', teacher.profileId);

                        await Supabase.instance.client
                            .from('teachers')
                            .update({
                              'specialization': specCtrl.text.trim().isEmpty ? null : specCtrl.text.trim(),
                              'primary_branch_id': selectedBranchId,
                            })
                            .eq('id', teacher.id);

                        nav.pop();
                        _loadTeachers();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حفظ تعديلات بيانات المعلم بنجاح!'),
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

  void _showProvisionTeacherDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
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
                  color: AppColors.teacherRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: AppColors.teacherRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تسجيل وقيد معلم جديد',
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
                        labelText: 'الاسم الكامل للمعلم *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المعلم' : null,
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
                    TextFormField(
                      controller: specCtrl,
                      decoration: const InputDecoration(
                        labelText: 'المادة والتخصص الأكاديمي',
                        hintText: 'مثال: فيزياء، لغة عربية، رياضيات...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور (اختياري)',
                        helperText: 'اتركها فارغة إذا كان المعلم سيسجل برمز QR.',
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
                                value: b.id,
                                child: Text(b.name),
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
                backgroundColor: AppColors.teacherRole,
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
                            content: Text('يجب ألا تقل كلمة المرور عن 6 أحرف.'),
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
                          role: 'teacher',
                          branchId: selectedBranchId,
                          centerId: _centerId,
                          phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          specialization: specCtrl.text.trim().isEmpty ? null : specCtrl.text.trim(),
                          password: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : null,
                        );

                        nav.pop();
                        _loadTeachers();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إنشاء وقيد حساب المعلم بنجاح!'),
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

  void _showLoginQr(Teacher teacher) {
    showDialog(
      context: context,
      builder: (_) => AccountLoginQrDialog(
        profileId: teacher.profileId,
        displayName: teacher.fullName,
        email: teacher.email,
      ),
    );
  }

  void _showPasswordDialog(Teacher teacher) {
    showDialog(
      context: context,
      builder: (_) => AccountPasswordDialog(
        profileId: teacher.profileId,
        displayName: teacher.fullName,
        email: teacher.email,
      ),
    );
  }

  Future<void> _toggleTeacherStatus(Teacher teacher) async {
    final isSuspended = teacher.status == 'suspended';
    if (!isSuspended) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('إيقاف حساب المعلم'),
          content: Text(
            'هل أنت متأكد من رغبتك في إيقاف حساب المعلم "${teacher.fullName}" مؤقتاً؟',
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
          params: {'user_uid': teacher.profileId},
        );
        _loadTeachers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إيقاف حساب المعلم مؤقتاً')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
      }
    } else {
      try {
        await Supabase.instance.client.rpc(
          'activate_user',
          params: {'user_uid': teacher.profileId},
        );
        _loadTeachers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تنشيط حساب المعلم بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteTeacher(Teacher teacher) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المعلم نهائياً'),
        content: Text(
          'هل أنت متأكد من حذف حساب المعلم "${teacher.fullName}" وسجلاته نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.',
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
          params: {'target_user_id': teacher.profileId},
        );
        _loadTeachers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف حساب المعلم نهائياً')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportTeacherData() async {
    try {
      final service = ReportGeneratorService();
      final teachersData = _teachers
          .map(
            (t) => {
              'name': t.fullName,
              'email': t.email,
              'specialization': t.specialization ?? 'عام',
              'status': t.status ?? 'active',
            },
          )
          .toList();

      await service.generateTeacherRosterReport(teachersData: teachersData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير كشف المعلمين بنجاح 📄')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تصدير التقرير: $e')),
        );
      }
    }
  }

  Widget _buildKpiSection(
    bool isDark,
    int totalTeachers,
    int activeTeachers,
    int totalAssignedGroups,
    int suspendedTeachers,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final kpiCards = [
          _buildKpiCard(
            title: 'إجمالي المعلمين',
            value: '$totalTeachers',
            icon: Icons.people_alt_rounded,
            color: AppColors.teacherRole,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'المعلمون النشطون',
            value: '$activeTeachers',
            icon: Icons.verified_user_rounded,
            color: Colors.green,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'المجموعات المسندة',
            value: '$totalAssignedGroups',
            icon: Icons.groups_rounded,
            color: Colors.teal,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'حسابات معلقة',
            value: '$suspendedTeachers',
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
            hintText: 'بحث باسم المعلم، التخصص، البريد، أو رقم الهاتف...',
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
              borderSide: const BorderSide(color: AppColors.teacherRole, width: 1.2),
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
            _buildGroupFilterChip('all', 'جميع الحالات', isDark),
            const SizedBox(width: 4),
            _buildGroupFilterChip('has_groups', 'لديه مجموعات', isDark),
            const SizedBox(width: 4),
            _buildGroupFilterChip('no_groups', 'بدون مجموعات', isDark),
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
                          value: b.id,
                          child: Text(b.name),
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
      selectedColor: AppColors.teacherRole.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.teacherRole
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.teacherRole
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildGroupFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedGroupFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedGroupFilter = value),
      selectedColor: Colors.teal.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.teal
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? Colors.teal
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildTeacherCard(BuildContext context, Teacher t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isActive = t.status?.toLowerCase() != 'suspended';
    final groupCount = _teacherGroupCounts[t.id] ?? 0;

    final branchName = _branches
        .where((b) => b.id == t.primaryBranchId)
        .map((b) => b.name)
        .firstOrNull;

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
                avatarUrl: t.avatarUrl,
                name: t.fullName,
                role: 'teacher',
                userId: t.profileId,
                userEmail: t.email,
                radius: 19,
                onAvatarChanged: (_) => _loadTeachers(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.fullName,
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
                      t.email,
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

          // Badges: Specialization, Branch, Groups Count
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (t.specialization != null && t.specialization!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.teacherRole.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.teacherRole.withValues(alpha: 0.25),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_outlined, size: 11, color: AppColors.teacherRole),
                      const SizedBox(width: 4),
                      Text(
                        t.specialization!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.teacherRole,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: (groupCount > 0 ? Colors.teal : Colors.grey).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (groupCount > 0 ? Colors.teal : Colors.grey).withValues(alpha: 0.25),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 11,
                      color: groupCount > 0 ? Colors.teal : Colors.grey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      groupCount > 0 ? '$groupCount مجموعات' : 'بدون مجموعات',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: groupCount > 0 ? Colors.teal : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Phone tap-to-call if present
          if (t.phoneNumber != null && t.phoneNumber!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _makePhoneCall(t.phoneNumber!),
              borderRadius: BorderRadius.circular(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    t.phoneNumber!,
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
                    onPressed: () => _showLoginQr(t),
                  ),
                  IconButton(
                    tooltip: 'تعيين كلمة المرور',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.password_rounded, size: 18, color: Colors.indigo),
                    onPressed: () => _showPasswordDialog(t),
                  ),
                  IconButton(
                    tooltip: 'تعديل البيانات',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_rounded, size: 17, color: AppColors.teacherRole),
                    onPressed: () => _showEditTeacherDialog(t),
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
                    onPressed: () => _toggleTeacherStatus(t),
                  ),
                  IconButton(
                    tooltip: 'حذف المعلم نهائياً',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                    onPressed: () => _deleteTeacher(t),
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
    final filtered = _teachers.where((t) {
      final q = _searchController.text.toLowerCase().trim();
      final branchName = _branches
          .where((b) => b.id == t.primaryBranchId)
          .map((b) => b.name.toLowerCase())
          .firstOrNull ?? '';

      final matchesSearch = q.isEmpty ||
          t.fullName.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q) ||
          (t.specialization?.toLowerCase().contains(q) ?? false) ||
          (t.phoneNumber != null && t.phoneNumber!.contains(q)) ||
          branchName.contains(q);

      if (!matchesSearch) return false;

      final isActive = t.status?.toLowerCase() != 'suspended';
      if (_selectedStatusFilter == 'active' && !isActive) {
        return false;
      }
      if (_selectedStatusFilter == 'suspended' && isActive) {
        return false;
      }

      if (_selectedBranchFilter != null && t.primaryBranchId != _selectedBranchFilter) {
        return false;
      }

      final groupCount = _teacherGroupCounts[t.id] ?? 0;
      if (_selectedGroupFilter == 'has_groups' && groupCount == 0) {
        return false;
      }
      if (_selectedGroupFilter == 'no_groups' && groupCount > 0) {
        return false;
      }

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalTeachers = _teachers.length;
    final activeTeachers = _teachers.where((t) => t.status?.toLowerCase() != 'suspended').length;
    final suspendedTeachers = _teachers.where((t) => t.status?.toLowerCase() == 'suspended').length;
    final totalAssignedGroups = _teacherGroupCounts.values.fold<int>(0, (sum, c) => sum + c);

    return PortalPageShell(
      title: 'إدارة المعلمين',
      subtitle: 'تسجيل وقيد المعلمين، تحديد التخصصات، إسناد المجموعات، وإدارة الصلاحيات والفروع.',
      icon: Icons.person_rounded,
      accentColor: AppColors.teacherRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadTeachers,
        ),
        PortalAction(
          icon: Icons.person_add,
          label: 'تسجيل معلم جديد',
          onPressed: _showProvisionTeacherDialog,
          primary: true,
        ),
        PortalAction(
          icon: Icons.picture_as_pdf,
          label: 'تصدير كشف (PDF)',
          onPressed: _exportTeacherData,
          primary: false,
        ),
      ],
      headerWidgets: [
        _buildKpiSection(
          isDark,
          totalTeachers,
          activeTeachers,
          totalAssignedGroups,
          suspendedTeachers,
        ),
        const SizedBox(height: 12),
        _buildSearchAndFilterBar(isDark),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: filtered.isEmpty,
              emptyTitle: _searchController.text.isNotEmpty ||
                      _selectedStatusFilter != 'all' ||
                      _selectedGroupFilter != 'all' ||
                      _selectedBranchFilter != null
                  ? 'لا توجد نتائج تطابق بحثك'
                  : 'لا يوجد معلمون مسجلون',
              emptySubtitle: _searchController.text.isNotEmpty ||
                      _selectedStatusFilter != 'all' ||
                      _selectedGroupFilter != 'all' ||
                      _selectedBranchFilter != null
                  ? 'جرّب تعديل مصطلحات البحث أو تغيير فلاتر الحالة والفرع.'
                  : 'يمكنك قيد وإضافة معلمين جدد عبر زر (تسجيل معلم جديد) بالأعلى.',
              emptyIcon: Icons.person_outline_rounded,
              onRetry: _loadTeachers,
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
                      itemBuilder: (ctx, i) => _buildTeacherCard(context, filtered[i]),
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
                      itemBuilder: (ctx, i) => _buildTeacherCard(context, filtered[i]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildTeacherCard(context, filtered[i]),
                  );
                },
              ),
            ),
          );
        }
      }
