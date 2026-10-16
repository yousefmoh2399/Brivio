import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/editable_avatar.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../widgets/account_password_dialog.dart';
import '../../../../core/services/user_provisioning_service.dart';

class ParentManagementScreen extends StatefulWidget {
  const ParentManagementScreen({super.key});

  @override
  State<ParentManagementScreen> createState() => _ParentManagementScreenState();
}

class _ParentManagementScreenState extends State<ParentManagementScreen> {
  late final SupabaseParentRepository _parentRepo;
  late final SupabaseStudentRepository _studentRepo;

  List<Parent> _parents = [];
  List<Student> _students = [];
  Map<String, List<Student>> _linkedStudents = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _centerId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _parentRepo = SupabaseParentRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _loadParents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCenterId() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('center_id')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && profile['center_id'] != null) {
          _centerId = profile['center_id'].toString();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadParents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_centerId == null) {
        await _fetchCenterId();
      }

      final res = await _parentRepo.fetchParents();
      final sRes = await _studentRepo.fetchStudents(pageSize: 500);

      List<String> centerBranchIds = [];
      if (_centerId != null) {
        try {
          final bRes = await Supabase.instance.client
              .from('branches')
              .select('id')
              .eq('center_id', _centerId!);
          centerBranchIds = (bRes as List).map((b) => b['id'].toString()).toList();
        } catch (_) {}
      }

      final scopedStudents = _centerId != null && centerBranchIds.isNotEmpty
          ? sRes.data.where((s) => centerBranchIds.contains(s.primaryBranchId)).toList()
          : sRes.data;

      final Map<String, Student> studentMap = {
        for (final s in scopedStudents) s.id: s,
      };

      final Map<String, List<Student>> linked = {
        for (final p in res.data) p.id: <Student>[],
      };

      final parentIds = res.data.map((p) => p.id).toList();
      if (parentIds.isNotEmpty) {
        try {
          final links = await Supabase.instance.client
              .from('parent_students')
              .select('parent_id, student_id')
              .inFilter('parent_id', parentIds);

          final missingStudentIds = <String>{};
          for (final l in links as List) {
            final sid = l['student_id']?.toString();
            if (sid != null && !studentMap.containsKey(sid)) {
              missingStudentIds.add(sid);
            }
          }

          if (missingStudentIds.isNotEmpty) {
            try {
              final missingRaw = await Supabase.instance.client
                  .from('students')
                  .select('*, profiles(*)')
                  .inFilter('id', missingStudentIds.toList());
              for (final s in missingRaw as List) {
                final Map<String, dynamic> item =
                    Map<String, dynamic>.from(s as Map);
                final prof = Map<String, dynamic>.from(
                  (item['profiles'] as Map?) ?? {},
                );
                final st = Student.fromJson({
                  ...item,
                  'full_name': prof['full_name'],
                  'email': prof['email'],
                  'avatar_url': prof['avatar_url'],
                  'phone_number': prof['phone_number'],
                });
                studentMap[st.id] = st;
              }
            } catch (_) {}
          }

          for (final l in links) {
            final pid = l['parent_id']?.toString();
            final sid = l['student_id']?.toString();
            if (pid != null && sid != null && studentMap.containsKey(sid)) {
              linked[pid]?.add(studentMap[sid]!);
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _parents = res.data;
          _students = scopedStudents;
          _linkedStudents = linked;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        final String friendlyMsg;
        if (errStr.contains('socketexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('clientexception') ||
            errStr.contains('network') ||
            errStr.contains('connection')) {
          friendlyMsg = 'تعذر الاتصال بالسيرفر. يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.';
        } else {
          friendlyMsg = 'حدث خطأ أثناء تحميل بيانات أولياء الأمور: ${e.toString()}';
        }
        setState(() {
          _errorMessage = friendlyMsg;
          _isLoading = false;
        });
      }
    }
  }

  void _showEditParentDialog(Parent parent) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: parent.fullName);
    final phoneCtrl = TextEditingController(text: parent.phoneNumber ?? '');
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
                  color: AppColors.parentRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: AppColors.parentRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات ولي الأمر',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل لولي الأمر *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'يرجى إدخال اسم ولي الأمر' : null,
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
                ],
              ),
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
                backgroundColor: AppColors.parentRole,
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
                            .eq('id', parent.profileId);

                        nav.pop();
                        _loadParents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تحديث بيانات ولي الأمر بنجاح!'),
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

  void _showProvisionParentDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
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
                  color: AppColors.parentRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: AppColors.parentRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تسجيل وقيد ولي أمر جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل لولي الأمر *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم ولي الأمر' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد';
                        if (!v.contains('@')) return 'بريد إلكتروني غير صالح';
                        return null;
                      },
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
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور (اختياري)',
                        helperText: 'اتركها فارغة إذا كان ولي الأمر سيسجل دخول برمز QR.',
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
                  ],
                ),
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
                backgroundColor: AppColors.parentRole,
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
                            content: Text('كلمة المرور يجب ألا تقل عن 6 أحرف.'),
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
                          role: 'parent',
                          phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          password: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : null,
                          centerId: _centerId,
                        );

                        nav.pop();
                        _loadParents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إنشاء وقيد حساب ولي الأمر بنجاح!'),
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

  void _showLinkChildDialog(Parent parent) {
    String? selectedStudentId = _students.isNotEmpty ? _students.first.id : null;
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
                  color: AppColors.parentRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1, color: AppColors.parentRole),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ربط ابن بـ ${parent.fullName}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
              children: [
                if (_students.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'اختر الطالب من القائمة',
                      border: OutlineInputBorder(),
                    ),
                    items: _students
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.fullName} (${s.studentCode})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => selectedStudentId = v),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('لا يوجد طلاب مسجلون متاحون للربط حالياً.', style: TextStyle(color: Colors.grey)),
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
                backgroundColor: AppColors.parentRole,
                foregroundColor: Colors.white,
              ),
              onPressed: (selectedStudentId == null || isSubmitting)
                  ? null
                  : () async {
                      setStateDialog(() => isSubmitting = true);
                      final nav = Navigator.of(ctx);
                      try {
                        await _parentRepo.linkParentToStudent(
                          parentId: parent.id,
                          studentId: selectedStudentId!,
                        );
                        nav.pop();
                        _loadParents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم ربط الطالب بولي الأمر بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل الربط: $e'),
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
              label: Text(isSubmitting ? 'جاري الربط...' : 'تأكيد الربط'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginQr(Parent parent) {
    showDialog(
      context: context,
      builder: (_) => AccountLoginQrDialog(
        profileId: parent.profileId,
        displayName: parent.fullName,
        email: parent.email,
      ),
    );
  }

  void _showPasswordDialog(Parent parent) {
    showDialog(
      context: context,
      builder: (_) => AccountPasswordDialog(
        profileId: parent.profileId,
        displayName: parent.fullName,
        email: parent.email,
      ),
    );
  }

  Widget _buildParentCard(BuildContext context, Parent p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final linked = _linkedStudents[p.id] ?? [];

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
          EditableAvatar(
            avatarUrl: p.avatarUrl,
            name: p.fullName,
            role: 'parent',
            userId: p.profileId,
            userEmail: p.email,
            radius: 22,
            onAvatarChanged: (_) => _loadParents(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  style: AppTypography.titleMedium(textPrimary).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.email,
                  style: AppTypography.caption(textSecondary),
                ),
                const SizedBox(height: 8),
                if (linked.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.child_care, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'الأبناء المرتبطون:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: linked
                        .map(
                          (child) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${child.fullName} (${child.studentCode})',
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  Text(
                    'لا يوجد أبناء مرتبطين بعد',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PortalStatusChip(status: p.status),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                tooltip: 'خيارات ولي الأمر',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'link_child':
                      _showLinkChildDialog(p);
                      break;
                    case 'qr':
                      _showLoginQr(p);
                      break;
                    case 'password':
                      _showPasswordDialog(p);
                      break;
                    case 'edit':
                      _showEditParentDialog(p);
                      break;
                    case 'activate':
                      try {
                        await Supabase.instance.client.rpc(
                          'activate_user',
                          params: {'user_uid': p.profileId},
                        );
                        _loadParents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تنشيط حساب ولي الأمر')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e')),
                          );
                        }
                      }
                      break;
                    case 'suspend':
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('إيقاف حساب ولي الأمر'),
                          content: const Text(
                            'هل أنت متأكد من رغبتك في إيقاف حساب ولي الأمر مؤقتاً؟',
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
                            params: {'user_uid': p.profileId},
                          );
                          _loadParents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إيقاف حساب ولي الأمر')),
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
                      break;
                    case 'delete':
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف ولي الأمر نهائياً'),
                          content: const Text(
                            'هل أنت متأكد من حذف حساب ولي الأمر نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.',
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
                            params: {'target_user_id': p.profileId},
                          );
                          _loadParents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حذف حساب ولي الأمر نهائياً')),
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
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'link_child',
                    child: ListTile(
                      leading: Icon(Icons.person_add_alt_1, size: 20),
                      title: Text('ربط ابن جديد'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
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
                  if (p.status == 'suspended')
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
                      title: Text('حذف ولي الأمر نهائياً', style: TextStyle(color: Colors.red)),
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
    final filtered = _parents.where((p) {
      final q = _searchController.text.toLowerCase();
      return p.fullName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'إدارة أولياء الأمور',
      subtitle: 'تسجيل حسابات أولياء الأمور، ربط الأبناء، ومتابعة التواصل.',
      icon: Icons.family_restroom,
      accentColor: AppColors.parentRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadParents,
        ),
        PortalAction(
          icon: Icons.person_add,
          label: 'تسجيل ولي أمر جديد',
          onPressed: _showProvisionParentDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'بحث باسم ولي الأمر أو البريد الإلكتروني...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'لا يوجد أولياء أمور مسجلون',
              emptySubtitle: 'يمكنك قيد وإضافة أولياء أمور جدد عبر زر (تسجيل ولي أمر جديد) بالأعلى.',
              emptyIcon: Icons.family_restroom,
              onRetry: _loadParents,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _buildParentCard(context, filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
