import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  late final SupabaseStudentRepository _studentRepo;

  List<Student> _students = [];
  List<Branch> _branches = [];
  Map<String, int> _studentGroupCounts = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _centerId;
  String _centerName = 'المركز التعليمي';
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'suspended'
  String _selectedBranchFilter = 'all';
  String _selectedGradeFilter = 'all';

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
    _initData();
  }

  Future<void> _initData() async {
    await _loadCenterInfo();
    await _loadStudents();
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

  void _copyStudentCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ كود الطالب ($code) إلى الحافظة 📋'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        _centerId = centerId?.toString();
        if (centerId != null) {
          final center = await Supabase.instance.client
              .from('educational_centers')
              .select('name')
              .eq('id', centerId)
              .maybeSingle();
          if (center != null && center['name'] != null && mounted) {
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
      final client = Supabase.instance.client;
      if (_centerId == null) {
        await _loadCenterInfo();
      }

      final res = await _studentRepo.fetchStudents();

      var bQuery = client.from('branches').select();
      if (_centerId != null) {
        bQuery = bQuery.eq('center_id', _centerId!);
      }
      final bRes = await bQuery.order('name');
      final branches = (bRes as List)
          .map((b) => Branch.fromJson(b as Map<String, dynamic>))
          .toList();

      List<Student> filteredStudents = res.data;
      if (_centerId != null) {
        final profileRes = await client
            .from('profiles')
            .select('id')
            .eq('center_id', _centerId!)
            .eq('role', 'student');
        final centerProfileIds = (profileRes as List)
            .map((p) => p['id']?.toString())
            .whereType<String>()
            .toSet();
        final branchIds = branches.map((b) => b.id).toSet();

        filteredStudents = res.data.where((s) {
          return centerProfileIds.contains(s.profileId) ||
              (s.primaryBranchId.isNotEmpty && branchIds.contains(s.primaryBranchId));
        }).toList();
      }

      // Fetch group enrollment count per student
      final Map<String, int> groupCounts = {};
      try {
        final enrollRes = await client.from('enrollments').select('student_id');
        for (final e in (enrollRes as List)) {
          final sid = e['student_id']?.toString();
          if (sid != null) {
            groupCounts[sid] = (groupCounts[sid] ?? 0) + 1;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _students = filteredStudents;
          _branches = branches;
          _studentGroupCounts = groupCounts;
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
                child: const Icon(Icons.edit_rounded, color: AppColors.studentRole, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات الطالب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 480.0),
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
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الطالب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود الطالب *',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
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
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'الصف / المرحلة التعليمية',
                        prefixIcon: Icon(Icons.school_outlined, size: 20),
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
                        isExpanded: true,
                        initialValue: selectedBranchId,
                        decoration: const InputDecoration(
                          labelText: 'المقر / الفرع التابع له',
                          prefixIcon: Icon(Icons.domain_rounded, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('بدون فرع محدد'),
                          ),
                          ..._branches.map(
                            (b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          ),
                        ],
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

  void _showProvisionStudentDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
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
                child: const Icon(Icons.person_add_rounded, color: AppColors.studentRole, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تسجيل وقيد طالب جديد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 480.0),
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
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الطالب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني *',
                        hintText: 'student@example.com',
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
                        labelText: 'رقم هاتف الطالب / ولي الأمر',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'الصف / المرحلة التعليمية',
                        prefixIcon: Icon(Icons.school_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: _gradeLevels
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => selectedGrade = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود الطالب (اختياري - يولد تلقائياً)',
                        hintText: 'مثال: STU-2024-001',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور (اختياري)',
                        helperText: 'اتركها فارغة إذا كان الطالب سيسجل بـ QR لأول مرة.',
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
                    const SizedBox(height: 12),
                    if (_branches.isNotEmpty)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedBranchId,
                        decoration: const InputDecoration(
                          labelText: 'المقر / الفرع التابع له',
                          prefixIcon: Icon(Icons.domain_rounded, size: 20),
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
                          role: 'student',
                          studentCode: codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
                          branchId: selectedBranchId,
                          centerId: _centerId,
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
          const SnackBar(
            content: Text('تم تصدير كشف الطلاب بنجاح 📄'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير التقرير: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _printBulkIdCards() async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب مسجلون لطباعة الكارنيهات.'),
          behavior: SnackBarBehavior.floating,
        ),
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل توليد الكارنيهات: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildKpiSection(
    bool isDark,
    int total,
    int active,
    int enrolledCount,
    int suspendedCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        final kpiTotal = _buildKpiItem(
          label: 'إجمالي الطلاب',
          value: total.toString(),
          icon: Icons.school_rounded,
          color: AppColors.studentRole,
          isDark: isDark,
        );
        final kpiActive = _buildKpiItem(
          label: 'الطلاب النشطون',
          value: active.toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          isDark: isDark,
        );
        final kpiEnrolled = _buildKpiItem(
          label: 'الملتحقون بمجموعات',
          value: enrolledCount.toString(),
          icon: Icons.group_work_rounded,
          color: Colors.blue,
          isDark: isDark,
        );
        final kpiSuspended = _buildKpiItem(
          label: 'الحسابات المعلقة',
          value: suspendedCount.toString(),
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
                Expanded(child: kpiEnrolled),
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
                  Expanded(child: kpiEnrolled),
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
            hintText: 'بحث باسم الطالب، الكود، البريد، أو الهاتف...',
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
              borderSide: const BorderSide(color: AppColors.studentRole, width: 1.2),
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
            if (_branches.length > 1) ...[
              const SizedBox(width: 8),
              Container(
                height: 28,
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
                  child: DropdownButton<String>(
                    value: _selectedBranchFilter,
                    icon: const Icon(Icons.domain_rounded, size: 14),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('جميع الفروع')),
                      ..._branches.map(
                        (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedBranchFilter = v);
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Container(
              height: 28,
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
                child: DropdownButton<String>(
                  value: _selectedGradeFilter,
                  icon: const Icon(Icons.school_outlined, size: 14),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('جميع الصفوف')),
                    ..._gradeLevels.map(
                      (g) => DropdownMenuItem(value: g, child: Text(g)),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedGradeFilter = v);
                  },
                ),
              ),
            ),
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
      selectedColor: AppColors.studentRole.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.studentRole
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.studentRole
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildStudentCard(BuildContext context, Student s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isActive = s.status.toLowerCase() == 'active';

    final branchName = _branches
        .where((b) => b.id == s.primaryBranchId)
        .map((b) => b.name)
        .firstOrNull;

    final groupCount = _studentGroupCounts[s.id] ?? 0;

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
          // Header: Avatar + Name + Student Code + Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EditableAvatar(
                avatarUrl: s.avatarUrl,
                name: s.fullName,
                role: 'student',
                userId: s.profileId,
                userEmail: s.email,
                radius: 18,
                onAvatarChanged: (_) => _loadStudents(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => _copyStudentCode(context, s.studentCode),
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.studentRole.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: AppColors.studentRole.withValues(alpha: 0.2),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.copy_rounded,
                              size: 10,
                              color: AppColors.studentRole,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'كود: ${s.studentCode}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.studentRole,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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

          // Badges: Grade + Branch + Groups count + Phone
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (s.gradeLevel != null && s.gradeLevel!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_outlined, size: 11, color: Colors.blue),
                      const SizedBox(width: 3),
                      Text(
                        s.gradeLevel!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              if (branchName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.2),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.domain_rounded, size: 11, color: Colors.teal),
                      const SizedBox(width: 3),
                      Text(
                        branchName,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_work_rounded, size: 11, color: Colors.deepPurple),
                    const SizedBox(width: 3),
                    Text(
                      groupCount == 0 ? 'غير مسكن بمجموعة' : '$groupCount مجموعة',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
              if (s.phoneNumber != null && s.phoneNumber!.trim().isNotEmpty)
                InkWell(
                  onTap: () => _makePhoneCall(s.phoneNumber!),
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, size: 11, color: Colors.green),
                        const SizedBox(width: 3),
                        Text(
                          s.phoneNumber!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Email row
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.email_outlined, size: 12, color: textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  s.email,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

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
                    onPressed: () => _showLoginQr(s),
                  ),
                  IconButton(
                    tooltip: 'تعيين كلمة المرور',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.password_rounded, size: 18, color: Colors.indigo),
                    onPressed: () => _showPasswordDialog(s),
                  ),
                  IconButton(
                    tooltip: 'تعديل بيانات الطالب',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_rounded, size: 17, color: AppColors.studentRole),
                    onPressed: () => _showEditStudentDialog(s),
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
                            title: const Text('إيقاف حساب الطالب'),
                            content: Text('هل أنت متأكد من رغبتك في إيقاف حساب الطالب "${s.fullName}" مؤقتاً؟'),
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
                              params: {'user_uid': s.profileId},
                            );
                            _loadStudents();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم إيقاف حساب الطالب بنجاح')),
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
                            params: {'user_uid': s.profileId},
                          );
                          _loadStudents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تنشيط حساب الطالب بنجاح')),
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
                    tooltip: 'حذف الطالب نهائياً',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.redAccent),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف الطالب نهائياً'),
                          content: Text(
                            'هل أنت متأكد من حذف حساب الطالب "${s.fullName}" وسجلاته نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.',
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
    final filtered = _students.where((s) {
      final q = _searchController.text.toLowerCase().trim();
      final branchName = _branches
          .where((b) => b.id == s.primaryBranchId)
          .map((b) => b.name)
          .firstOrNull ?? '';

      final matchesSearch = q.isEmpty ||
          s.fullName.toLowerCase().contains(q) ||
          s.studentCode.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          (s.phoneNumber != null && s.phoneNumber!.contains(q)) ||
          (s.gradeLevel != null && s.gradeLevel!.toLowerCase().contains(q)) ||
          branchName.toLowerCase().contains(q);

      if (!matchesSearch) return false;

      if (_selectedStatusFilter == 'active' && s.status.toLowerCase() != 'active') {
        return false;
      }
      if (_selectedStatusFilter == 'suspended' && s.status.toLowerCase() != 'suspended') {
        return false;
      }

      if (_selectedBranchFilter != 'all' && s.primaryBranchId != _selectedBranchFilter) {
        return false;
      }

      if (_selectedGradeFilter != 'all' && s.gradeLevel != _selectedGradeFilter) {
        return false;
      }

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _students.length;
    final activeCount = _students.where((s) => s.status.toLowerCase() == 'active').length;
    final suspendedCount = _students.where((s) => s.status.toLowerCase() == 'suspended').length;
    final enrolledCount = _students.where((s) => (_studentGroupCounts[s.id] ?? 0) > 0).length;

    return PortalPageShell(
      title: 'إدارة شؤون الطلاب',
      subtitle: 'تسجيل وقيد الطلاب، طباعة الكارنيهات والباركود، ومتابعة الفروع والمراحل.',
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
          _buildKpiSection(isDark, totalCount, activeCount, enrolledCount, suspendedCount),
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
                      _selectedBranchFilter != 'all' ||
                      _selectedGradeFilter != 'all'
                  ? 'لا توجد نتائج تطابق بحثك'
                  : 'لا يوجد طلاب مسجلون',
              emptySubtitle: _searchController.text.isNotEmpty ||
                      _selectedStatusFilter != 'all' ||
                      _selectedBranchFilter != 'all' ||
                      _selectedGradeFilter != 'all'
                  ? 'جرّب تعديل مصطلحات البحث أو إعادة ضبط فلاتر الحالة والصف والفرع.'
                  : 'يمكنك قيد وإضافة طلاب جدد عبر زر (تسجيل طالب جديد) بالأعلى.',
              emptyIcon: Icons.school_rounded,
              onRetry: _loadStudents,
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
                      itemBuilder: (ctx, i) => _buildStudentCard(context, filtered[i]),
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
                      itemBuilder: (ctx, i) => _buildStudentCard(context, filtered[i]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildStudentCard(context, filtered[i]),
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
