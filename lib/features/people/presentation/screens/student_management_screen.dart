import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../widgets/account_password_dialog.dart';
import '../../../../core/services/report_generator_service.dart';

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
    final nameCtrl = TextEditingController(text: student.fullName);
    final codeCtrl = TextEditingController(text: student.studentCode);
    String? selectedBranchId = student.primaryBranchId.isEmpty
        ? null
        : student.primaryBranchId;
    if (selectedBranchId != null &&
        !_branches.any((b) => b.id == selectedBranchId)) {
      selectedBranchId = null;
    }
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تعديل بيانات الطالب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل للطالب',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'كود الطالب',
                  ),
                ),
                const SizedBox(height: 10),
                if (_branches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: const InputDecoration(
                      labelText: 'الفرع التابع له',
                    ),
                    items:
                        _branches
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
                      .update({'full_name': nameCtrl.text.trim()})
                      .eq('id', student.profileId);

                  await Supabase.instance.client
                      .from('students')
                      .update({
                        'student_code': codeCtrl.text.trim(),
                        'primary_branch_id': selectedBranchId,
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

  void _showProvisionStudentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    String? selectedBranchId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تسجيل وقيد طالب جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل للطالب',
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
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور (اختياري)',
                    helperText: 'اتركها فارغة إذا كان الطالب سيسجل بـ QR لأول مرة.',
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
                      content: Text('يجب ألا تقل كلمة المرور عن 6 أحرف.'),
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
                          'role': 'student',
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
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  return PortalListCard(
                    icon: Icons.school,
                    accentColor: AppColors.studentRole,
                    title: s.fullName,
                    subtitle:
                        'الكود: ${s.studentCode} | البريد: ${s.email}',
                    trailing: [
                      IconButton(
                        tooltip: 'رمز الاستجابة السريعة (QR)',
                        onPressed: () => _showLoginQr(s),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      IconButton(
                        tooltip: 'تعيين كلمة المرور',
                        onPressed: () => _showPasswordDialog(s),
                        icon: const Icon(Icons.password),
                      ),
                      if (s.status == 'suspended')
                        IconButton(
                          tooltip: 'تنشيط الحساب',
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.rpc(
                                'activate_user',
                                params: {'user_uid': s.profileId},
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم تنشيط حساب الطالب'),
                                  ),
                                );
                                _loadStudents();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        )
                      else
                        IconButton(
                          tooltip: 'إيقاف الحساب مؤقتاً',
                          onPressed: () async {
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
                                  params: {'user_uid': s.profileId},
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم إيقاف حساب الطالب'),
                                    ),
                                  );
                                  _loadStudents();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('خطأ: $e')),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.block, color: Colors.red),
                        ),
                      IconButton(
                        tooltip: 'تعديل البيانات',
                        onPressed: () => _showEditStudentDialog(s),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        tooltip: 'حذف الطالب',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حذف الطالب نهائياً'),
                              content: const Text(
                                'هل أنت متأكد من حذف حساب الطالب وسجلاته نهائياً من النظام؟',
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
                                params: {'target_user_id': s.profileId},
                              );
                              _loadStudents();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ: $e')),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                      PortalStatusChip(status: s.status),
                    ],
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
