import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../widgets/account_password_dialog.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/user_provisioning_service.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseBranchRepository _branchRepo;

  List<Student> _students = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _centerName = 'المركز التعليمي';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _gradeLevels = [
    'الصف الأول الإعدادي',
    'الصف الثاني الإعدادي',
    'الصف الثالث الإعدادي',
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
  ];

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _branchRepo = SupabaseBranchRepository(wrapper);
    _loadCenterInfo();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCenterInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('center_id')
            .eq('id', user.id)
            .maybeSingle();
        final centerId = profile?['center_id'];
        if (centerId != null) {
          final center = await Supabase.instance.client
              .from('educational_centers')
              .select('name')
              .eq('id', centerId)
              .maybeSingle();
          if (center != null && center['name'] != null) {
            setState(() => _centerName = center['name']);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _studentRepo.fetchStudents();
      final bRes = await _branchRepo.fetchBranches();
      if (mounted) {
        setState(() {
          _students = res.data;
          _branches = bRes;
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

  void _showEditStudentDialog(Student student) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: student.fullName);
    final codeCtrl = TextEditingController(text: student.studentCode);
    final phoneCtrl = TextEditingController(text: student.phoneNumber ?? '');
    String? selectedBranchId = student.primaryBranchId.isEmpty
        ? null
        : student.primaryBranchId;
    if (selectedBranchId != null &&
        !_branches.any((b) => b.id == selectedBranchId)) {
      selectedBranchId = null;
    }
    String? selectedGrade = student.gradeLevel;
    if (selectedGrade != null && !_gradeLevels.contains(selectedGrade)) {
      selectedGrade = null;
    }
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          actionsOverflowButtonSpacing: 8,
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowAlignment: OverflowBarAlignment.end,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.studentRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: AppColors.studentRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات الطالب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                          labelText: 'الاسم الكامل للطالب *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الطالب' : null,
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 460) {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: codeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'كود الطالب *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? 'يرجى إدخال كود الطالب' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: phoneCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم هاتف الطالب / واتساب',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: codeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'كود الطالب *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? 'يرجى إدخال كود الطالب' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: phoneCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم هاتف الطالب / واتساب',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'الصف / المرحلة التعليمية',
                        border: OutlineInputBorder(),
                      ),
                      items: _gradeLevels
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => selectedGrade = v),
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
        ),
        actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.studentRole,
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
                            .eq('id', student.profileId);

                        await Supabase.instance.client
                            .from('students')
                            .update({
                              'student_code': codeCtrl.text.trim(),
                              'primary_branch_id': selectedBranchId,
                              'grade_level': selectedGrade,
                            })
                            .eq('id', student.id);

                        nav.pop();
                        _loadStudents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تحديث بيانات الطالب بنجاح!'),
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

  void _showProvisionStudentDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    String? selectedBranchId;
    String? selectedGrade;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          actionsOverflowButtonSpacing: 8,
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowAlignment: OverflowBarAlignment.end,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.studentRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: AppColors.studentRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تسجيل وقيد طالب جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                          labelText: 'الاسم الكامل للطالب *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الطالب' : null,
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 480) {
                            return Column(
                              children: [
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
                              ],
                            );
                          }
                          return Row(
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
                                    if (!v.contains('@')) return 'بريد إلكتروني غير صالح';
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
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'الصف / المرحلة التعليمية',
                        border: OutlineInputBorder(),
                      ),
                      items: _gradeLevels
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => selectedGrade = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور (اختياري)',
                        helperText: 'اتركها فارغة إذا كان الطالب سيسجل بـ QR لأول مرة.',
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
        ),
        actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.studentRole,
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
                          role: 'student',
                          branchId: selectedBranchId,
                          phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          gradeLevel: selectedGrade,
                          password: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : null,
                        );

                        nav.pop();
                        _loadStudents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إنشاء وقيد حساب الطالب بنجاح!'),
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

  void _showLoginQr(Student student) {
    showDialog(
      context: context,
      builder: (_) => AccountLoginQrDialog(
        profileId: student.profileId,
        displayName: student.fullName,
        email: student.email,
      ),
    );
  }

  void _showPasswordDialog(Student student) {
    showDialog(
      context: context,
      builder: (_) => AccountPasswordDialog(
        profileId: student.profileId,
        displayName: student.fullName,
        email: student.email,
      ),
    );
  }

  Future<void> _exportStudentData() async {
    try {
      final service = ReportGeneratorService();
      final rosterData = _students
          .map(
            (s) => {
              'name': s.fullName,
              'code': s.studentCode,
              'email': s.email,
              'status': s.status,
            },
          )
          .toList();

      await service.generateStudentRosterReport(studentsData: rosterData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير كشف الطلاب بنجاح 📄')),
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

  Future<void> _printBulkIdCards() async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب مسجلون لطباعة الكارنيهات.')),
      );
      return;
    }

    try {
      final service = ReportGeneratorService();
      final studentsData = _students
          .map(
            (s) => {
              'name': s.fullName,
              'code': s.studentCode,
              'phone': s.phoneNumber ?? '',
              'grade': s.gradeLevel ?? 'المرحلة التعليمية',
            },
          )
          .toList();

      await service.generateBulkStudentIdCardsPdf(
        students: studentsData,
        centerName: _centerName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم توليد شيت كارنيهات الطلاب بنجاح (جاهز للطباعة والتغليف) 🪪'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل توليد الكارنيهات: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStudentCard(BuildContext context, Student s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final branchName = _branches
        .where((b) => b.id == s.primaryBranchId)
        .map((b) => b.name)
        .firstOrNull;

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
            backgroundColor: AppColors.studentRole.withValues(alpha: 0.12),
            child: const Icon(Icons.school, color: AppColors.studentRole, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.fullName,
                  style: AppTypography.titleMedium(textPrimary).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.email,
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
                        color: AppColors.studentRole.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'كود: ${s.studentCode}',
                        style: const TextStyle(fontSize: 12, color: AppColors.studentRole, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (s.gradeLevel != null && s.gradeLevel!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.gradeLevel!,
                          style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (branchName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'فرع: $branchName',
                          style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (s.phoneNumber != null && s.phoneNumber!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'هاتف: ${s.phoneNumber}',
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
              PortalStatusChip(status: s.status),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                tooltip: 'خيارات الطالب',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'qr':
                      _showLoginQr(s);
                      break;
                    case 'password':
                      _showPasswordDialog(s);
                      break;
                    case 'edit':
                      _showEditStudentDialog(s);
                      break;
                    case 'activate':
                      try {
                        await Supabase.instance.client.rpc(
                          'activate_user',
                          params: {'user_uid': s.profileId},
                        );
                        _loadStudents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تنشيط حساب الطالب')),
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
                          title: const Text('إيقاف حساب الطالب'),
                          content: const Text(
                            'هل أنت متأكد من رغبتك في إيقاف حساب هذا الطالب مؤقتاً؟',
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
                            params: {'user_uid': s.profileId},
                          );
                          _loadStudents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إيقاف حساب الطالب')),
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
                          title: const Text('حذف الطالب نهائياً'),
                          content: const Text(
                            'هل أنت متأكد من حذف حساب الطالب وسجلاته نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.',
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
                            params: {'target_user_id': s.profileId},
                          );
                          _loadStudents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حذف حساب الطالب نهائياً')),
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
                  if (s.status == 'suspended')
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
                      title: Text('حذف الطالب نهائياً', style: TextStyle(color: Colors.red)),
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
    final filtered = _students.where((s) {
      final q = _searchController.text.toLowerCase();
      return s.fullName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.studentCode.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'إدارة شؤون الطلاب',
      subtitle: 'تسجيل وقيد الطلاب، طباعة الكارنيهات والباركود، ومتابعة الفروع.',
      icon: Icons.school,
      accentColor: AppColors.studentRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadStudents,
        ),
        PortalAction(
          icon: Icons.badge_outlined,
          label: 'طباعة الكارنيهات (PDF)',
          onPressed: _printBulkIdCards,
          primary: false,
        ),
        PortalAction(
          icon: Icons.person_add,
          label: 'تسجيل طالب جديد',
          onPressed: _showProvisionStudentDialog,
          primary: true,
        ),
        PortalAction(
          icon: Icons.picture_as_pdf,
          label: 'تصدير كشف (PDF)',
          onPressed: _exportStudentData,
          primary: false,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'بحث بالاسم، الكود، أو البريد الإلكتروني...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'لا يوجد طلاب مسجلون',
              emptySubtitle: 'يمكنك قيد وإضافة طلاب جدد عبر زر (تسجيل طالب جديد) بالأعلى.',
              emptyIcon: Icons.school,
              onRetry: _loadStudents,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _buildStudentCard(context, filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
