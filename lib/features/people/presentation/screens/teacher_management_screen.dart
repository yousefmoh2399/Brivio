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

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseBranchRepository _branchRepo;

  List<Teacher> _teachers = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _branchRepo = SupabaseBranchRepository(wrapper);
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
      final res = await _teacherRepo.fetchTeachers();
      final bRes = await _branchRepo.fetchBranches();
      if (mounted) {
        setState(() {
          _teachers = res.data;
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

  void _showEditTeacherDialog(Teacher teacher) {
    final nameCtrl = TextEditingController(text: teacher.fullName);
    final specCtrl = TextEditingController(text: teacher.specialization ?? '');
    String? selectedBranchId = teacher.primaryBranchId.isEmpty
        ? null
        : teacher.primaryBranchId;
    if (selectedBranchId != null &&
        !_branches.any((b) => b.id == selectedBranchId)) {
      selectedBranchId = null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تعديل بيانات المعلم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل للمعلم',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(
                    labelText: 'المادة والتخصص الأكاديمي',
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
                      .eq('id', teacher.profileId);

                  await Supabase.instance.client
                      .from('teachers')
                      .update({
                        'specialization': specCtrl.text.trim().isEmpty
                            ? null
                            : specCtrl.text.trim(),
                        'primary_branch_id': selectedBranchId,
                      })
                      .eq('id', teacher.id);

                  nav.pop();
                  _loadTeachers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث بيانات المعلم بنجاح!'),
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

  void _showProvisionTeacherDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    String? selectedBranchId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تسجيل وقيد معلم جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل للمعلم',
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
                TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(
                    labelText: 'المادة والتخصص (مثال: فيزياء ثانوية عامة)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور (اختياري)',
                    helperText: 'اتركها فارغة إذا كان المعلم سيسجل دخول برمز QR.',
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
                          'role': 'teacher',
                          'branchId': selectedBranchId,
                          'specialization': specCtrl.text.trim().isEmpty
                              ? null
                              : specCtrl.text.trim(),
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

  Future<void> _exportTeacherData() async {
    try {
      final service = ReportGeneratorService();
      final rosterData = _teachers
          .map(
            (t) => {
              'name': t.fullName,
              'email': t.email,
              'specialization': t.specialization ?? 'عام',
              'status': t.status,
            },
          )
          .toList();

      await service.generateTeacherRosterReport(teachersData: rosterData);

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

  @override
  Widget build(BuildContext context) {
    final filtered = _teachers.where((t) {
      final q = _searchController.text.toLowerCase();
      return t.fullName.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q) ||
          (t.specialization?.toLowerCase().contains(q) ?? false);
    }).toList();

    return PortalPageShell(
      title: 'إدارة شؤون المعلمين',
      subtitle: 'قيد وتسجيل المعلمين، متابعة التخصصات والمواد، وإدارة الحسابات.',
      icon: Icons.person,
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
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'بحث بالاسم، التخصص، أو البريد الإلكتروني...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'لا يوجد معلمون مسجلون',
              emptySubtitle: 'يمكنك قيد وإضافة معلمين جدد عبر زر (تسجيل معلم جديد) بالأعلى.',
              emptyIcon: Icons.person,
              onRetry: _loadTeachers,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final t = filtered[i];
                  return PortalListCard(
                    icon: Icons.person,
                    accentColor: AppColors.teacherRole,
                    title: t.fullName,
                    subtitle:
                        'البريد: ${t.email} | التخصص: ${t.specialization ?? "عام"}',
                    trailing: [
                      IconButton(
                        tooltip: 'رمز الاستجابة السريعة (QR)',
                        onPressed: () => _showLoginQr(t),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      IconButton(
                        tooltip: 'تعيين كلمة المرور',
                        onPressed: () => _showPasswordDialog(t),
                        icon: const Icon(Icons.password),
                      ),
                      if (t.status == 'suspended')
                        IconButton(
                          tooltip: 'تنشيط الحساب',
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.rpc(
                                'activate_user',
                                params: {'user_uid': t.profileId},
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم تنشيط حساب المعلم'),
                                  ),
                                );
                                _loadTeachers();
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
                                title: const Text('إيقاف حساب المعلم'),
                                content: const Text(
                                  'هل أنت متأكد من رغبتك في إيقاف حساب هذا المعلم مؤقتاً؟',
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
                                  params: {'user_uid': t.profileId},
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم إيقاف حساب المعلم'),
                                    ),
                                  );
                                  _loadTeachers();
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
                        onPressed: () => _showEditTeacherDialog(t),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        tooltip: 'حذف المعلم',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حذف المعلم نهائياً'),
                              content: const Text(
                                'هل أنت متأكد من رغبتك في حذف حساب هذا المعلم نهائياً؟',
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
                                params: {'target_user_id': t.profileId},
                              );
                              _loadTeachers();
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
                      PortalStatusChip(status: t.status ?? 'active'),
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
