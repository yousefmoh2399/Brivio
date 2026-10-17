import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';
import '../../../../core/services/report_generator_service.dart';

Widget _dropdownText(String value) {
  return Text(value, maxLines: 1, overflow: TextOverflow.ellipsis);
}

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseEnrollmentRepository _enrollmentRepo;

  List<GroupEntity> _groups = [];
  List<SubjectEntity> _subjects = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _centerId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _enrollmentRepo = SupabaseEnrollmentRepository(wrapper);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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

      var bQuery = client.from('branches').select().eq('status', 'active');
      if (_centerId != null) {
        bQuery = bQuery.eq('center_id', _centerId!);
      }
      final bRes = await bQuery.order('name');
      final branches = (bRes as List)
          .map((json) => Branch.fromJson(json as Map<String, dynamic>))
          .toList();

      List<dynamic> sRes = [];
      try {
        var sQuery = client.from('subjects').select().eq('status', 'active');
        if (_centerId != null) {
          try {
            sRes = await sQuery.eq('center_id', _centerId!).order('name');
          } catch (_) {
            // Fallback if subjects table doesn't have center_id column
            sRes = await client.from('subjects').select().eq('status', 'active').order('name');
          }
        } else {
          sRes = await sQuery.order('name');
        }
      } catch (_) {
        sRes = [];
      }
      final subjects = sRes
          .map((json) => SubjectEntity.fromJson(json as Map<String, dynamic>))
          .toList();

      List<GroupEntity> groups;
      if (_centerId != null && branches.isNotEmpty) {
        final branchIds = branches.map((b) => b.id).toList();
        final gRes = await client
            .from('groups')
            .select()
            .inFilter('branch_id', branchIds)
            .order('name');
        groups = (gRes as List)
            .map((json) => GroupEntity.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (_centerId != null && branches.isEmpty) {
        groups = [];
      } else {
        groups = await _groupRepo.fetchGroups();
      }

      if (mounted) {
        setState(() {
          _groups = groups;
          _subjects = subjects;
          _branches = branches;
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

  void _showCreateGroupDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '20');
    String? selectedSubjectId = _subjects.isNotEmpty
        ? _subjects.first.id
        : null;
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.adminRole.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_work, color: AppColors.adminRole),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إضافة مجموعة دراسية جديدة',
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
                          labelText: 'اسم المجموعة *',
                          hintText: 'مثال: فيزياء 3 ثانوى - مجموعة الأحد',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المجموعة' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'كود المجموعة *',
                                hintText: 'مثال: PHY-G1',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'يرجى إدخال كود المجموعة' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: capacityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'السعة القصوى للطلاب *',
                                hintText: '20',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'أدخل السعة';
                                final num = int.tryParse(v.trim());
                                if (num == null || num <= 0) return 'أدخل رقم أكبر من صفر';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_subjects.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedSubjectId,
                          decoration: const InputDecoration(
                            labelText: 'المادة الدراسية *',
                            border: OutlineInputBorder(),
                          ),
                          items: _subjects
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: _dropdownText('${s.name} (${s.code})'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => selectedSubjectId = v),
                        ),
                      const SizedBox(height: 12),
                      if (_branches.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedBranchId,
                          decoration: const InputDecoration(
                            labelText: 'الفرع التابع له *',
                            border: OutlineInputBorder(),
                          ),
                          items: _branches
                              .map(
                                (b) => DropdownMenuItem(
                                  value: b.id,
                                  child: _dropdownText(b.name),
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
                  backgroundColor: AppColors.adminRole,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (selectedSubjectId == null || selectedBranchId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى اختيار المادة والفرع')),
                          );
                          return;
                        }

                        setStateDialog(() => isSubmitting = true);
                        final nav = Navigator.of(ctx);

                        try {
                          final cap = int.tryParse(capacityCtrl.text.trim()) ?? 20;
                          final g = GroupEntity(
                            id: '',
                            code: codeCtrl.text.trim(),
                            name: nameCtrl.text.trim(),
                            subjectId: selectedSubjectId!,
                            branchId: selectedBranchId!,
                            maxCapacity: cap,
                            status: 'active',
                          );

                          await _groupRepo.createGroup(g);
                          nav.pop();
                          _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إنشاء المجموعة بنجاح!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل إنشاء المجموعة: $e'),
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
                label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ المجموعة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditGroupDialog(GroupEntity group) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: group.name);
    final codeCtrl = TextEditingController(text: group.code);
    final capacityCtrl = TextEditingController(text: group.maxCapacity?.toString() ?? '20');
    String selectedSubjectId = group.subjectId;
    String selectedBranchId = group.branchId;
    String status = group.status;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.adminRole.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit, color: AppColors.adminRole),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تعديل بيانات المجموعة',
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
                          labelText: 'اسم المجموعة *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المجموعة' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'كود المجموعة *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'يرجى إدخال كود المجموعة' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: capacityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'السعة القصوى *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'أدخل السعة';
                                final num = int.tryParse(v.trim());
                                if (num == null || num <= 0) return 'أدخل رقم أكبر من صفر';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'الحالة التشغيلية',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('نشطة ومتاحة (Active)')),
                          DropdownMenuItem(value: 'archived', child: Text('مؤرشفة ومغلقة (Archived)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setStateDialog(() => status = v);
                        },
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
                  backgroundColor: AppColors.adminRole,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setStateDialog(() => isSubmitting = true);
                        final nav = Navigator.of(ctx);

                        try {
                          final cap = int.tryParse(capacityCtrl.text.trim()) ?? 20;
                          final updated = GroupEntity(
                            id: group.id,
                            code: codeCtrl.text.trim(),
                            name: nameCtrl.text.trim(),
                            subjectId: selectedSubjectId,
                            branchId: selectedBranchId,
                            maxCapacity: cap,
                            status: status,
                          );

                          await _groupRepo.updateGroup(updated);
                          nav.pop();
                          _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تحديث بيانات المجموعة بنجاح!'),
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
          );
        },
      ),
    );
  }

  void _openGroupDetails(GroupEntity group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailsScreen(
          group: group,
          studentRepo: _studentRepo,
          teacherRepo: _teacherRepo,
          enrollmentRepo: _enrollmentRepo,
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, GroupEntity g) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final subjectName = _subjects
        .where((s) => s.id == g.subjectId)
        .map((s) => s.name)
        .firstOrNull;

    final branchName = _branches
        .where((b) => b.id == g.branchId)
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
            backgroundColor: AppColors.adminRole.withValues(alpha: 0.12),
            child: const Icon(Icons.group_work, color: AppColors.adminRole, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: () => _openGroupDetails(g),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name,
                    style: AppTypography.titleMedium(textPrimary).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.adminRole.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'كود: ${g.code}',
                          style: const TextStyle(fontSize: 12, color: AppColors.adminRole, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (subjectName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            subjectName,
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
                            branchName,
                            style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'السعة: ${g.maxCapacity ?? "مفتوحة"}',
                          style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PortalStatusChip(status: g.status),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                tooltip: 'خيارات المجموعة',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'details':
                      _openGroupDetails(g);
                      break;
                    case 'edit':
                      _showEditGroupDialog(g);
                      break;
                    case 'delete':
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف المجموعة الدراسية'),
                          content: const Text(
                            'هل أنت متأكد من رغبتك في حذف هذه المجموعة نهائياً؟',
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
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await _groupRepo.deleteGroup(g.id);
                          _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حذف المجموعة بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل الحذف: $e')),
                            );
                          }
                        }
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: ListTile(
                      leading: Icon(Icons.open_in_new, size: 20),
                      title: Text('عرض التفاصيل والطلاب'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, size: 20, color: Colors.blue),
                      title: Text('تعديل المجموعة'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      title: Text('حذف المجموعة', style: TextStyle(color: Colors.red)),
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
    final filtered = _groups.where((g) {
      final q = _searchController.text.toLowerCase();
      return g.name.toLowerCase().contains(q) ||
          g.code.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'إدارة المجموعات والحصص',
      subtitle: 'إدارة المجموعات الدراسية، قيد وتسكين الطلاب، وتعيين المعلمين.',
      icon: Icons.group_work,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadData,
        ),
        PortalAction(
          icon: Icons.add,
          label: 'إضافة مجموعة جديدة',
          onPressed: _showCreateGroupDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'بحث باسم المجموعة أو الكود...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'لا توجد مجموعات دراسية مسجلة',
              emptySubtitle: 'قم بإنشاء مادة وفرع، ثم أضف المجموعة الأولى عبر زر (إضافة مجموعة جديدة) بالأعلى.',
              emptyIcon: Icons.group_work,
              onRetry: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _buildGroupCard(context, filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GroupDetailsScreen extends StatefulWidget {
  final GroupEntity group;
  final SupabaseStudentRepository studentRepo;
  final SupabaseTeacherRepository teacherRepo;
  final SupabaseEnrollmentRepository enrollmentRepo;

  const GroupDetailsScreen({
    super.key,
    required this.group,
    required this.studentRepo,
    required this.teacherRepo,
    required this.enrollmentRepo,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<Student> _allStudents = [];
  List<Teacher> _allTeachers = [];
  List<Student> _enrolledStudents = [];
  List<Teacher> _assignedTeachers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _centerName = 'المركز التعليمي';

  @override
  void initState() {
    super.initState();
    _loadCenterInfo();
    _loadTabResources();
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

  Future<void> _loadTabResources() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final sRes = await widget.studentRepo.fetchStudents();
      final tRes = await widget.teacherRepo.fetchTeachers();
      final enrolled = await widget.studentRepo.fetchStudentsForGroup(
        widget.group.id,
      );
      final assignments = await Supabase.instance.client
          .from('group_teachers')
          .select('teacher_id')
          .eq('group_id', widget.group.id);
      final assignedIds = (assignments as List<dynamic>)
          .map((item) => (item as Map)['teacher_id'] as String)
          .toSet();
      if (mounted) {
        setState(() {
          _allStudents = sRes.data;
          _allTeachers = tRes.data;
          _enrolledStudents = enrolled;
          _assignedTeachers = _allTeachers
              .where((teacher) => assignedIds.contains(teacher.id))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showEnrollStudentDialog() {
    final formKey = GlobalKey<FormState>();
    String? selectedStudentId = _allStudents.isNotEmpty
        ? _allStudents.first.id
        : null;
    final priceCtrl = TextEditingController(text: '0');
    final discountCtrl = TextEditingController(text: '0');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
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
                    'تسكين وقيد طالب في المجموعة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 460.0),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_allStudents.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedStudentId,
                          decoration: const InputDecoration(
                            labelText: 'اختر الطالب من القائمة *',
                            border: OutlineInputBorder(),
                          ),
                          items: _allStudents
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: _dropdownText(
                                    '${s.fullName} (${s.studentCode})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => selectedStudentId = v),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'السعر النهائي / الحصة (ج.م)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: discountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'قيمة الخصم إن وُجد (ج.م)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
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
                onPressed: (selectedStudentId == null || isSubmitting)
                    ? null
                    : () async {
                        setStateDialog(() => isSubmitting = true);
                        final nav = Navigator.of(ctx);
                        try {
                          final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                          final discount = int.tryParse(discountCtrl.text.trim()) ?? 0;
                          await widget.enrollmentRepo.enrollStudentInGroup(
                            studentId: selectedStudentId!,
                            groupId: widget.group.id,
                            totalMinor: price * 100,
                            discountMinor: discount * 100,
                          );
                          nav.pop();
                          _loadTabResources();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم قيد وتسكين الطالب بنجاح!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل قيد الطالب: $e'),
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
          );
        },
      ),
    );
  }

  void _showAssignTeacherDialog() {
    String? selectedTeacherId = _allTeachers.isNotEmpty
        ? _allTeachers.first.id
        : null;
    String role = 'primary';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
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
                    'تعيين معلم للمجموعة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 460.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_allTeachers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'اختر المعلم من القائمة *',
                        border: OutlineInputBorder(),
                      ),
                      items: _allTeachers
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: _dropdownText(t.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedTeacherId = v),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'الدور في المجموعة',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'primary',
                        child: Text('معلم أساسي (Primary)'),
                      ),
                      DropdownMenuItem(
                        value: 'assistant',
                        child: Text('معلم مساعد (Assistant)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => role = v);
                    },
                  ),
                ],
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
                onPressed: (selectedTeacherId == null || isSubmitting)
                    ? null
                    : () async {
                        setStateDialog(() => isSubmitting = true);
                        final nav = Navigator.of(ctx);
                        try {
                          await Supabase.instance.client.rpc(
                            'assign_teacher_to_group',
                            params: {
                              'p_teacher_id': selectedTeacherId,
                              'p_group_id': widget.group.id,
                              'p_role': role,
                            },
                          );
                          nav.pop();
                          _loadTabResources();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تعيين المعلم للمجموعة بنجاح!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل تعيين المعلم: $e'),
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
                label: Text(isSubmitting ? 'جاري التعيين...' : 'تأكيد التعيين'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printGroupCards() async {
    if (_enrolledStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب مسجلون في هذه المجموعة لطباعة الكارنيهات.'),
        ),
      );
      return;
    }

    try {
      final service = ReportGeneratorService();
      final studentsData = _enrolledStudents
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
        groupName: widget.group.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم توليد شيت كارنيهات طلاب مجموعة (${widget.group.name}) بنجاح (جاهز للطباعة والتغليف) 🪪',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل توليد الكارنيهات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: PortalPageShell(
        title: widget.group.name,
        subtitle:
            'الكود: ${widget.group.code} | السعة: ${widget.group.maxCapacity ?? "غير محدودة"}',
        icon: Icons.group_work,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.arrow_back,
            label: 'رجوع',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          PortalAction(
            icon: Icons.badge_outlined,
            label: 'طباعة الكارنيهات (PDF)',
            onPressed: _printGroupCards,
          ),
          PortalAction(
            icon: Icons.refresh,
            label: 'تحديث',
            onPressed: _loadTabResources,
          ),
        ],
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: Icon(Icons.info_outline_rounded), text: 'نظرة عامة'),
                Tab(
                  icon: Icon(Icons.people_outline_rounded),
                  text: 'الطلاب المقيدون',
                ),
                Tab(
                  icon: Icon(Icons.person_outline_rounded),
                  text: 'المعلمون المسندون',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PortalStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: false,
                emptyTitle: 'لا توجد بيانات للمجموعة',
                emptySubtitle: 'قم بتحديث الصفحة وحاول مرة أخرى.',
                emptyIcon: Icons.group_work,
                onRetry: _loadTabResources,
                child: TabBarView(
                  children: [
                    ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        PortalMetricGrid(
                          children: [
                            PortalMetricCard(
                              label: 'الطلاب المقيدون',
                              value: _enrolledStudents.length.toString(),
                              icon: Icons.school_rounded,
                              accentColor: AppColors.studentRole,
                            ),
                            PortalMetricCard(
                              label: 'المعلمون المسندون',
                              value: _assignedTeachers.length.toString(),
                              icon: Icons.person_rounded,
                              accentColor: AppColors.teacherRole,
                            ),
                            PortalMetricCard(
                              label: 'السعة الاستيعابية',
                              value:
                                  widget.group.maxCapacity?.toString() ?? 'مفتوحة',
                              icon: Icons.event_seat_rounded,
                              accentColor: AppColors.info,
                            ),
                            PortalMetricCard(
                              label: 'الحالة التشغيلية',
                              value: widget.group.status == 'active' ? 'نشطة' : 'مؤرشفة',
                              icon: Icons.verified_rounded,
                              accentColor: AppColors.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Stack(
                      children: [
                        _enrolledStudents.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا يوجد طلاب مقيدون في هذه المجموعة حالياً.',
                                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 72),
                                itemCount: _enrolledStudents.length,
                                separatorBuilder: (ctx, i) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final s = _enrolledStudents[i];
                                  return PortalListCard(
                                    icon: Icons.school,
                                    accentColor: AppColors.studentRole,
                                    title: s.fullName,
                                    subtitle:
                                        'الكود: ${s.studentCode} | البريد: ${s.email}',
                                    trailing: [
                                      IconButton(
                                        icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20),
                                        tooltip: 'إلغاء قيد الطالب من المجموعة',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('إلغاء قيد الطالب'),
                                              content: Text('هل أنت متأكد من إلغاء قيد الطالب ${s.fullName} من هذه المجموعة؟'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('إلغاء القيد'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            try {
                                              await Supabase.instance.client
                                                  .from('enrollments')
                                                  .delete()
                                                  .eq('group_id', widget.group.id)
                                                  .eq('student_id', s.id);
                                              _loadTabResources();
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('تم إلغاء قيد الطالب بنجاح')),
                                                );
                                              }
                                            } catch (err) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('فشل إلغاء القيد: $err')),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                      PortalStatusChip(status: s.status),
                                    ],
                                  );
                                },
                              ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.studentRole,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _showEnrollStudentDialog,
                            icon: const Icon(Icons.person_add),
                            label: const Text('تسكين طالب بالمجموعة'),
                          ),
                        ),
                      ],
                    ),
                    Stack(
                      children: [
                        _assignedTeachers.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا يوجد معلمون مسندون لهذه المجموعة حالياً.',
                                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 72),
                                itemCount: _assignedTeachers.length,
                                separatorBuilder: (ctx, i) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final t = _assignedTeachers[i];
                                  return PortalListCard(
                                    icon: Icons.person,
                                    accentColor: AppColors.teacherRole,
                                    title: t.fullName,
                                    subtitle:
                                        'البريد: ${t.email} | التخصص: ${t.specialization ?? "عام"}',
                                    trailing: [
                                      IconButton(
                                        icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20),
                                        tooltip: 'إلغاء إسناد المعلم من المجموعة',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('إلغاء إسناد المعلم'),
                                              content: Text('هل أنت متأكد من إلغاء إسناد المعلم ${t.fullName} من هذه المجموعة؟'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('إلغاء الإسناد'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            try {
                                              await Supabase.instance.client
                                                  .from('group_teachers')
                                                  .delete()
                                                  .eq('group_id', widget.group.id)
                                                  .eq('teacher_id', t.id);
                                              _loadTabResources();
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('تم إلغاء إسناد المعلم بنجاح')),
                                                );
                                              }
                                            } catch (err) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('فشل إلغاء الإسناد: $err')),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teacherRole,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _showAssignTeacherDialog,
                            icon: const Icon(Icons.person_add),
                            label: const Text('تعيين معلم للمجموعة'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
