import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/services/user_provisioning_service.dart';
import '../../../../design_system/components/editable_avatar.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../widgets/account_password_dialog.dart';

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
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'suspended'
  String _selectedChildrenFilter = 'all'; // 'all', 'has_children', 'no_children'

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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
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
                child: const Icon(Icons.edit_rounded, color: AppColors.parentRole, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات ولي الأمر',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 440.0),
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
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
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
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
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
                              behavior: SnackBarBehavior.floating,
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
                              behavior: SnackBarBehavior.floating,
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
                child: const Icon(Icons.person_add_rounded, color: AppColors.parentRole, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تسجيل وقيد ولي أمر جديد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 440.0),
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
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
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
                        hintText: 'parent@example.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v == null || !v.contains('@') ? 'يرجى إدخال بريد إلكتروني صحيح' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف / واتساب',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
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
                        helperText: 'اتركها فارغة إذا كان سيسجل برمز QR لأول مرة.',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setStateDialog(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 20,
                          ),
                        ),
                      ),
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
                            behavior: SnackBarBehavior.floating,
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
                          centerId: _centerId,
                          phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          password: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : null,
                        );

                        nav.pop();
                        _loadParents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تسجيل وقيد حساب ولي الأمر بنجاح!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
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
                              behavior: SnackBarBehavior.floating,
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
    String relationship = 'parent';
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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ربط طالب بولي الأمر (${parent.fullName})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 440.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_students.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedStudentId,
                      decoration: const InputDecoration(
                        labelText: 'اختر الطالب من القائمة *',
                        prefixIcon: Icon(Icons.school_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: _students
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.fullName} (${s.studentCode})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedStudentId = v),
                    )
                  else
                    const Text(
                      'لا يوجد طلاب متاحون للربط حالياً. قم بتسجيل الطلاب أولاً.',
                      style: TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: relationship,
                    decoration: const InputDecoration(
                      labelText: 'صلة القرابة',
                      prefixIcon: Icon(Icons.people_outline_rounded, size: 20),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'father', child: Text('الأب')),
                      DropdownMenuItem(value: 'mother', child: Text('الأم')),
                      DropdownMenuItem(value: 'guardian', child: Text('ولي أمر / وصي')),
                      DropdownMenuItem(value: 'parent', child: Text('أخرى')),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => relationship = v);
                    },
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: (_students.isEmpty || selectedStudentId == null || isSubmitting)
                  ? null
                  : () async {
                      setStateDialog(() => isSubmitting = true);
                      final nav = Navigator.of(ctx);

                      try {
                        await Supabase.instance.client.from('parent_students').insert({
                          'parent_id': parent.id,
                          'student_id': selectedStudentId,
                          'relationship': relationship,
                        });

                        nav.pop();
                        _loadParents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم ربط الطالب بولي الأمر بنجاح!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
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
                              behavior: SnackBarBehavior.floating,
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

  Widget _buildKpiSection(
    bool isDark,
    int total,
    int active,
    int withChildren,
    int suspended,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        final kpiTotal = _buildKpiItem(
          label: 'إجمالي أولياء الأمور',
          value: total.toString(),
          icon: Icons.family_restroom_rounded,
          color: AppColors.parentRole,
          isDark: isDark,
        );
        final kpiActive = _buildKpiItem(
          label: 'الحسابات النشطة',
          value: active.toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          isDark: isDark,
        );
        final kpiLinked = _buildKpiItem(
          label: 'المرتبطون بأبناء',
          value: withChildren.toString(),
          icon: Icons.child_care_rounded,
          color: Colors.blue,
          isDark: isDark,
        );
        final kpiSuspended = _buildKpiItem(
          label: 'الحسابات المعلقة',
          value: suspended.toString(),
          icon: Icons.block_rounded,
          color: Colors.grey,
          isDark: isDark,
        );

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: kpiTotal),
                const SizedBox(width: 8),
                Expanded(child: kpiActive),
                const SizedBox(width: 8),
                Expanded(child: kpiLinked),
                const SizedBox(width: 8),
                Expanded(child: kpiSuspended),
              ],
            ),
          );
        }

        // Mobile Layout: 2 rows of 2
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: kpiTotal),
                  const SizedBox(width: 8),
                  Expanded(child: kpiActive),
                ],
              ),
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: kpiLinked),
                  const SizedBox(width: 8),
                  Expanded(child: kpiSuspended),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: color),
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
        final isNarrow = constraints.maxWidth < 650;
        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'بحث باسم ولي الأمر، الهاتف، البريد، أو اسم الطالب...',
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
              borderSide: const BorderSide(color: AppColors.parentRole, width: 1.2),
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
            _buildChildrenFilterChip('all', 'جميع الحالات', isDark),
            const SizedBox(width: 4),
            _buildChildrenFilterChip('has_children', 'لديه أبناء', isDark),
            const SizedBox(width: 4),
            _buildChildrenFilterChip('no_children', 'بدون أبناء', isDark),
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
      selectedColor: AppColors.parentRole.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.parentRole
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.parentRole
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildChildrenFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedChildrenFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedChildrenFilter = value),
      selectedColor: Colors.blue.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.blue
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? Colors.blue
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildParentCard(BuildContext context, Parent p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isActive = p.status.toLowerCase() == 'active';
    final linked = _linkedStudents[p.id] ?? [];

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
          // Header: Avatar + Name + Phone + Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EditableAvatar(
                avatarUrl: p.avatarUrl,
                name: p.fullName,
                role: 'parent',
                userId: p.profileId,
                userEmail: p.email,
                radius: 18,
                onAvatarChanged: (_) => _loadParents(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName,
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
                      p.email,
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

          // Linked Children Section
          if (linked.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.child_care_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'الأبناء المرتبطون (${linked.length}):',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: linked
                  .map(
                    (child) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        '${child.fullName} (${child.studentCode})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else ...[
            InkWell(
              onTap: () => _showLinkChildDialog(p),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 0.6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_link_rounded, size: 12, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'لا يوجد أبناء مرتبطين بعد (انقر للربط)',
                      style: TextStyle(fontSize: 10.5, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (p.phoneNumber != null && p.phoneNumber!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _makePhoneCall(p.phoneNumber!),
              borderRadius: BorderRadius.circular(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    p.phoneNumber!,
                    style: const TextStyle(fontSize: 10.5, color: Colors.green, fontWeight: FontWeight.w600),
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
                    tooltip: 'ربط طالب جديد',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.primary),
                    onPressed: () => _showLinkChildDialog(p),
                  ),
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
                    icon: const Icon(Icons.edit_rounded, size: 17, color: AppColors.parentRole),
                    onPressed: () => _showEditParentDialog(p),
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
                    onPressed: () async {
                      if (isActive) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('إيقاف حساب ولي الأمر'),
                            content: Text('هل أنت متأكد من رغبتك في إيقاف حساب ولي الأمر "${p.fullName}" مؤقتاً؟'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
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
                                const SnackBar(content: Text('تم إيقاف حساب ولي الأمر بنجاح')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      } else {
                        try {
                          await Supabase.instance.client.rpc(
                            'activate_user',
                            params: {'user_uid': p.profileId},
                          );
                          _loadParents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تنشيط حساب ولي الأمر بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'حذف ولي الأمر نهائياً',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.redAccent),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف ولي الأمر نهائياً'),
                          content: Text(
                            'هل أنت متأكد من حذف حساب ولي الأمر "${p.fullName}" نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
                              SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    },
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
      final q = _searchController.text.toLowerCase().trim();
      final linked = _linkedStudents[p.id] ?? [];
      final linkedNames = linked.map((s) => s.fullName.toLowerCase()).join(' ');
      final linkedCodes = linked.map((s) => s.studentCode.toLowerCase()).join(' ');

      final matchesSearch = q.isEmpty ||
          p.fullName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          (p.phoneNumber != null && p.phoneNumber!.contains(q)) ||
          linkedNames.contains(q) ||
          linkedCodes.contains(q);

      if (!matchesSearch) return false;

      if (_selectedStatusFilter == 'active' && p.status.toLowerCase() != 'active') {
        return false;
      }
      if (_selectedStatusFilter == 'suspended' && p.status.toLowerCase() != 'suspended') {
        return false;
      }

      if (_selectedChildrenFilter == 'has_children' && linked.isEmpty) {
        return false;
      }
      if (_selectedChildrenFilter == 'no_children' && linked.isNotEmpty) {
        return false;
      }

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _parents.length;
    final activeCount = _parents.where((p) => p.status.toLowerCase() == 'active').length;
    final suspendedCount = _parents.where((p) => p.status.toLowerCase() == 'suspended').length;
    final withChildrenCount = _parents.where((p) => (_linkedStudents[p.id] ?? []).isNotEmpty).length;

    return PortalPageShell(
      title: 'إدارة أولياء الأمور',
      subtitle: 'تسجيل وقيد أولياء الأمور، ربط الأبناء، وتتبع متابعة مستوى الطلاب.',
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
      headerWidgets: [
        _buildKpiSection(isDark, totalCount, activeCount, withChildrenCount, suspendedCount),
        const SizedBox(height: 12),
        _buildSearchAndFilterBar(isDark),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: filtered.isEmpty,
              emptyTitle: _searchController.text.isNotEmpty ||
                      _selectedStatusFilter != 'all' ||
                      _selectedChildrenFilter != 'all'
                  ? 'لا توجد نتائج تطابق بحثك'
                  : 'لا يوجد أولياء أمور مسجلون',
              emptySubtitle: _searchController.text.isNotEmpty ||
                      _selectedStatusFilter != 'all' ||
                      _selectedChildrenFilter != 'all'
                  ? 'جرّب تعديل مصطلحات البحث أو تغيير فلاتر الحالة.'
                  : 'يمكنك قيد وتسجيل أولياء الأمور عبر زر (تسجيل ولي أمر جديد) بالأعلى.',
              emptyIcon: Icons.family_restroom_rounded,
              onRetry: _loadParents,
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
                      itemBuilder: (ctx, i) => _buildParentCard(context, filtered[i]),
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
                      itemBuilder: (ctx, i) => _buildParentCard(context, filtered[i]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildParentCard(context, filtered[i]),
                  );
                },
              ),
            ),
          );
        }
      }
