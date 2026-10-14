import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
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

  Future<void> _loadParents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _parentRepo.fetchParents();
      final sRes = await _studentRepo.fetchStudents();

      final Map<String, List<Student>> linked = {};
      final futures = res.data.map((p) async {
        try {
          linked[p.id] = await _parentRepo.fetchLinkedStudents(p.id);
        } catch (_) {
          linked[p.id] = [];
        }
      });
      await Future.wait(futures);

      if (mounted) {
        setState(() {
          _parents = res.data;
          _students = sRes.data;
          _linkedStudents = linked;
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

  void _showEditParentDialog(Parent parent) {
    final nameCtrl = TextEditingController(text: parent.fullName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات ولي الأمر'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم الكامل لولي الأمر'),
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
    );
  }

  void _showProvisionParentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تسجيل وقيد ولي أمر جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل لولي الأمر',
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
                    helperText: 'اتركها فارغة إذا كان ولي الأمر سيسجل دخول برمز QR.',
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
                          'role': 'parent',
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

  void _showLinkChildDialog(Parent parent) {
    String? selectedStudentId = _students.isNotEmpty ? _students.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('ربط ابن بـ ${parent.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_students.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedStudentId,
                  decoration: const InputDecoration(
                    labelText: 'اختر الطالب من القائمة',
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
                const Text('لا يوجد طلاب متاحين للربط حالياً.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: selectedStudentId == null
                  ? null
                  : () async {
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
              child: const Text('تأكيد الربط'),
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
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final p = filtered[i];
                  final linked = _linkedStudents[p.id] ?? [];
                  final childrenNames = linked
                      .map((s) => s.fullName)
                      .join('، ');

                  return PortalListCard(
                    icon: Icons.family_restroom,
                    accentColor: AppColors.parentRole,
                    title: p.fullName,
                    subtitle:
                        'البريد: ${p.email}\nالأبناء المرتبطون: ${childrenNames.isEmpty ? "لا يوجد أبناء مرتبطين بعد" : childrenNames}',
                    trailing: [
                      IconButton(
                        tooltip: 'ربط ابن جديد',
                        onPressed: () => _showLinkChildDialog(p),
                        icon: const Icon(Icons.person_add_alt_1),
                      ),
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
                      if (p.status == 'suspended')
                        IconButton(
                          tooltip: 'تنشيط الحساب',
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.rpc(
                                'activate_user',
                                params: {'user_uid': p.profileId},
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم تنشيط حساب ولي الأمر'),
                                  ),
                                );
                                _loadParents();
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
                                title: const Text('إيقاف حساب ولي الأمر'),
                                content: const Text(
                                  'هل أنت متأكد من رغبتك في إيقاف حساب ولي الأمر مؤقتاً؟',
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
                                  params: {'user_uid': p.profileId},
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم إيقاف حساب ولي الأمر'),
                                    ),
                                  );
                                  _loadParents();
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
                        onPressed: () => _showEditParentDialog(p),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        tooltip: 'حذف ولي الأمر',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حذف ولي الأمر نهائياً'),
                              content: const Text(
                                'هل أنت متأكد من حذف حساب ولي الأمر نهائياً من النظام؟',
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
                                params: {'target_user_id': p.profileId},
                              );
                              _loadParents();
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
                      PortalStatusChip(status: p.status),
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
