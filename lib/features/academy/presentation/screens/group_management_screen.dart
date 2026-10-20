import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

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
  List<Teacher> _teachers = [];
  Map<String, int> _groupEnrollmentCounts = {};
  Map<String, String> _groupTeacherNames = {};

  bool _isLoading = false;
  String? _errorMessage;
  String? _centerId;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'archived'
  String _selectedBranchFilter = 'all';

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
        try {
          final prof = await client
              .from('profiles')
              .select('center_id')
              .eq('id', userId)
              .maybeSingle();
          _centerId = prof?['center_id'] as String?;
        } catch (_) {}
      }

      // 1. Branches
      var bQuery = client.from('branches').select();
      if (_centerId != null) {
        bQuery = bQuery.eq('center_id', _centerId!);
      }
      final bRes = await bQuery.order('name');
      final branches = (bRes as List)
          .map((json) => Branch.fromJson(json as Map<String, dynamic>))
          .toList();

      // 2. Subjects
      List<dynamic> sRes = [];
      try {
        var sQuery = client.from('subjects').select();
        if (_centerId != null) {
          try {
            sRes = await sQuery.eq('center_id', _centerId!).order('name');
          } catch (_) {
            sRes = await client.from('subjects').select().order('name');
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

      // 3. Teachers
      List<Teacher> teachers = [];
      try {
        final tRes = await _teacherRepo.fetchTeachers();
        teachers = tRes.data;
      } catch (_) {}

      // 4. Groups
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

      // 5. Enrollment counts per group
      final Map<String, int> enrollmentCounts = {};
      try {
        final eRes = await client.from('enrollments').select('group_id');
        for (final e in (eRes as List)) {
          final gid = e['group_id']?.toString();
          if (gid != null) {
            enrollmentCounts[gid] = (enrollmentCounts[gid] ?? 0) + 1;
          }
        }
      } catch (_) {}

      // 6. Assigned teachers per group
      final Map<String, String> groupTeacherNames = {};
      try {
        final gtRes = await client.from('group_teachers').select('group_id, teacher_id');
        final teacherMap = {for (var t in teachers) t.id: t.fullName};
        for (final gt in (gtRes as List)) {
          final gid = gt['group_id']?.toString();
          final tid = gt['teacher_id']?.toString();
          if (gid != null && tid != null && teacherMap.containsKey(tid)) {
            groupTeacherNames[gid] = teacherMap[tid]!;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _groups = groups;
          _subjects = subjects;
          _branches = branches;
          _teachers = teachers;
          _groupEnrollmentCounts = enrollmentCounts;
          _groupTeacherNames = groupTeacherNames;
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

  void _copyGroupCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ كود المجموعة ($code) إلى الحافظة 📋'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleGroupStatus(GroupEntity g) async {
    final newStatus = g.status.toLowerCase() == 'active' ? 'archived' : 'active';
    try {
      final updated = GroupEntity(
        id: g.id,
        code: g.code,
        name: g.name,
        subjectId: g.subjectId,
        branchId: g.branchId,
        maxCapacity: g.maxCapacity,
        status: newStatus,
      );
      await _groupRepo.updateGroup(updated);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'active'
                  ? 'تم تنشيط مجموعة "${g.name}" بنجاح 🟢'
                  : 'تم أرشفة مجموعة "${g.name}" ⚪',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تعديل حالة المجموعة: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteGroupDialog(GroupEntity group) {
    final count = _groupEnrollmentCounts[group.id] ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text(
              'حذف المجموعة الدراسية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          count > 0
              ? 'تنبيه: يوجد ($count) طالب مقيد في مجموعة "${group.name}".\nهل أنت متأكد من حذف هذه المجموعة؟ سيؤدي ذلك إلى إلغاء تسكين الطلاب وجدول الحصص.'
              : 'هل أنت متأكد من حذف مجموعة "${group.name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                try {
                  await _groupRepo.deleteGroup(group.id);
                } catch (_) {
                  await Supabase.instance.client
                      .from('groups')
                      .delete()
                      .eq('id', group.id);
                }
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حذف مجموعة "${group.name}" بنجاح.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تعذر حذف المجموعة: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '20');
    String? selectedSubjectId = _subjects.isNotEmpty ? _subjects.first.id : null;
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;
    String? selectedTeacherId = _teachers.isNotEmpty ? _teachers.first.id : null;
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
                  child: const Icon(Icons.group_work_rounded, color: AppColors.adminRole, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إضافة مجموعة دراسية جديدة',
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
                          labelText: 'اسم المجموعة *',
                          hintText: 'مثال: فيزياء 3 ثانوى - مجموعة الأحد',
                          prefixIcon: Icon(Icons.title_rounded, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المجموعة' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'كود المجموعة *',
                          hintText: 'مثال: PHY-G1',
                          prefixIcon: Icon(Icons.tag_rounded, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال كود المجموعة' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: capacityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'السعة القصوى للطلاب *',
                          hintText: '20',
                          prefixIcon: Icon(Icons.people_outline_rounded, size: 20),
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
                      const SizedBox(height: 12),
                      if (_subjects.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedSubjectId,
                          decoration: const InputDecoration(
                            labelText: 'المادة الدراسية *',
                            prefixIcon: Icon(Icons.book_outlined, size: 20),
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
                            labelText: 'المقر / الفرع التابع له *',
                            prefixIcon: Icon(Icons.domain_rounded, size: 20),
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
                      if (_teachers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedTeacherId,
                          decoration: const InputDecoration(
                            labelText: 'المعلم المسند (اختياري)',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('تعيين المعلم لاحقاً'),
                            ),
                            ..._teachers.map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: _dropdownText(t.fullName),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setStateDialog(() => selectedTeacherId = v),
                        ),
                      ],
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
                            code: codeCtrl.text.trim().toUpperCase(),
                            name: nameCtrl.text.trim(),
                            subjectId: selectedSubjectId!,
                            branchId: selectedBranchId!,
                            maxCapacity: cap,
                            status: 'active',
                          );

                          final createdGroup = await _groupRepo.createGroup(g);

                          // Assign teacher if selected
                          if (selectedTeacherId != null && createdGroup.id.isNotEmpty) {
                            try {
                              await Supabase.instance.client.from('group_teachers').insert({
                                'group_id': createdGroup.id,
                                'teacher_id': selectedTeacherId,
                                'role': 'primary',
                              });
                            } catch (_) {}
                          }

                          nav.pop();
                          _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إنشاء المجموعة بنجاح!'),
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
                                content: Text('فشل إنشاء المجموعة: $e'),
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
                  child: const Icon(Icons.edit_rounded, color: AppColors.adminRole, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تعديل بيانات المجموعة',
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
                          labelText: 'اسم المجموعة *',
                          prefixIcon: Icon(Icons.title_rounded, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المجموعة' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'كود المجموعة *',
                          prefixIcon: Icon(Icons.tag_rounded, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال كود المجموعة' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: capacityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'السعة القصوى للطلاب *',
                          prefixIcon: Icon(Icons.people_outline_rounded, size: 20),
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
                      const SizedBox(height: 12),
                      if (_subjects.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedSubjectId,
                          decoration: const InputDecoration(
                            labelText: 'المادة الدراسية',
                            prefixIcon: Icon(Icons.book_outlined, size: 20),
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
                          onChanged: (v) {
                            if (v != null) setStateDialog(() => selectedSubjectId = v);
                          },
                        ),
                      const SizedBox(height: 12),
                      if (_branches.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedBranchId,
                          decoration: const InputDecoration(
                            labelText: 'المقر / الفرع',
                            prefixIcon: Icon(Icons.domain_rounded, size: 20),
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
                          onChanged: (v) {
                            if (v != null) setStateDialog(() => selectedBranchId = v);
                          },
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: status.toLowerCase() == 'archived' ? 'archived' : 'active',
                        decoration: const InputDecoration(
                          labelText: 'الحالة التشغيلية',
                          prefixIcon: Icon(Icons.toggle_on_outlined, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('نشطة ومتاحة (Active) 🟢'),
                          ),
                          DropdownMenuItem(
                            value: 'archived',
                            child: Text('مؤرشفة ومغلقة (Archived) ⚪'),
                          ),
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
                            code: codeCtrl.text.trim().toUpperCase(),
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
    ).then((_) => _loadData());
  }

  Widget _buildKpiSection(
    bool isDark,
    int total,
    int active,
    int archived,
    int totalStudents,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        final kpiTotal = _buildKpiItem(
          label: 'إجمالي المجموعات',
          value: total.toString(),
          icon: Icons.group_work_rounded,
          color: AppColors.adminRole,
          isDark: isDark,
        );
        final kpiActive = _buildKpiItem(
          label: 'المجموعات النشطة',
          value: active.toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          isDark: isDark,
        );
        final kpiStudents = _buildKpiItem(
          label: 'الطلاب المقيدون',
          value: totalStudents.toString(),
          icon: Icons.school_rounded,
          color: Colors.blue,
          isDark: isDark,
        );
        final kpiArchived = _buildKpiItem(
          label: 'المؤرشفة',
          value: archived.toString(),
          icon: Icons.archive_rounded,
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
                Expanded(child: kpiStudents),
                const SizedBox(width: 8),
                Expanded(child: kpiArchived),
              ],
            ),
          );
        }

        // Mobile Layout: 2 rows of 2 cards
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
                  Expanded(child: kpiStudents),
                  const SizedBox(width: 8),
                  Expanded(child: kpiArchived),
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
            hintText: 'بحث باسم المجموعة، الكود، المادة، أو المعلم...',
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
              borderSide: const BorderSide(color: AppColors.adminRole, width: 1.2),
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
            _buildStatusFilterChip('active', 'النشطة', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('archived', 'المؤرشفة', isDark),
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
                    icon: const Icon(Icons.filter_list_rounded, size: 14),
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
      selectedColor: AppColors.adminRole.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.adminRole
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.adminRole
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildGroupCard(BuildContext context, GroupEntity g) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isActive = g.status.toLowerCase() == 'active';

    final subjectName = _subjects
        .where((s) => s.id == g.subjectId)
        .map((s) => s.name)
        .firstOrNull;

    final branchName = _branches
        .where((b) => b.id == g.branchId)
        .map((b) => b.name)
        .firstOrNull;

    final teacherName = _groupTeacherNames[g.id];
    final enrolledCount = _groupEnrollmentCounts[g.id] ?? 0;
    final maxCap = g.maxCapacity;
    final hasCap = maxCap != null && maxCap > 0;
    final double progress = hasCap ? (enrolledCount / maxCap).clamp(0.0, 1.0) : 0.0;
    final isFull = hasCap && enrolledCount >= maxCap;

    return InkWell(
      onTap: () => _openGroupDetails(g),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
            // Top Header: Icon + Name + Status Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.adminRole.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.group_work_rounded,
                    color: AppColors.adminRole,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
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
                        onTap: () => _copyGroupCode(context, g.code),
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.adminRole.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: AppColors.adminRole.withValues(alpha: 0.2),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.copy_rounded,
                                size: 10,
                                color: AppColors.adminRole,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'كود: ${g.code}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.adminRole,
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
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'نشطة' : 'مؤرشفة',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Metadata Badges (Subject, Branch, Teacher)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (subjectName != null)
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
                        const Icon(Icons.book_outlined, size: 11, color: Colors.blue),
                        const SizedBox(width: 3),
                        Text(
                          subjectName,
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
                if (teacherName != null)
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
                        const Icon(Icons.person_outline_rounded, size: 11, color: Colors.deepPurple),
                        const SizedBox(width: 3),
                        Text(
                          teacherName,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Enrollment Progress & Occupancy Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 13,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasCap
                              ? '$enrolledCount / $maxCap طالب'
                              : '$enrolledCount طالب (سعة مفتوحة)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isFull ? Colors.red : textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (hasCap)
                      Text(
                        '${(progress * 100).toInt()}% إشغال',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: progress >= 1.0
                              ? Colors.red
                              : (progress >= 0.8 ? Colors.orange : Colors.green),
                        ),
                      ),
                  ],
                ),
                if (hasCap) ...[
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0
                            ? Colors.red
                            : (progress >= 0.8 ? Colors.orange : Colors.green),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const Divider(height: 10),

            // Action Toolbar Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: AppColors.adminRole.withValues(alpha: 0.3)),
                  ),
                  onPressed: () => _openGroupDetails(g),
                  icon: const Icon(Icons.people_outline_rounded, size: 13, color: AppColors.adminRole),
                  label: const Text(
                    'الطلاب والحصص',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.adminRole,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'تعديل المجموعة',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_rounded, size: 17, color: Colors.blue),
                      onPressed: () => _showEditGroupDialog(g),
                    ),
                    IconButton(
                      tooltip: isActive ? 'أرشفة المجموعة' : 'إلغاء الأرشفة والتنشيط',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                        size: 17,
                        color: isActive ? Colors.amber.shade800 : Colors.green,
                      ),
                      onPressed: () => _toggleGroupStatus(g),
                    ),
                    IconButton(
                      tooltip: 'حذف المجموعة',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _showDeleteGroupDialog(g),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _groups.where((g) {
      final q = _searchController.text.toLowerCase().trim();
      final subjectName = _subjects
          .where((s) => s.id == g.subjectId)
          .map((s) => s.name)
          .firstOrNull ?? '';
      final branchName = _branches
          .where((b) => b.id == g.branchId)
          .map((b) => b.name)
          .firstOrNull ?? '';
      final teacherName = _groupTeacherNames[g.id] ?? '';

      final matchesSearch = q.isEmpty ||
          g.name.toLowerCase().contains(q) ||
          g.code.toLowerCase().contains(q) ||
          subjectName.toLowerCase().contains(q) ||
          branchName.toLowerCase().contains(q) ||
          teacherName.toLowerCase().contains(q);

      if (!matchesSearch) return false;

      if (_selectedStatusFilter == 'active' && g.status.toLowerCase() != 'active') {
        return false;
      }
      if (_selectedStatusFilter == 'archived' && g.status.toLowerCase() != 'archived') {
        return false;
      }

      if (_selectedBranchFilter != 'all' && g.branchId != _selectedBranchFilter) {
        return false;
      }

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _groups.length;
    final activeCount = _groups.where((g) => g.status.toLowerCase() == 'active').length;
    final archivedCount = _groups.where((g) => g.status.toLowerCase() == 'archived').length;
    int totalStudents = 0;
    for (final c in _groupEnrollmentCounts.values) {
      totalStudents += c;
    }

    return PortalPageShell(
      title: 'إدارة المجموعات والحصص',
      subtitle: 'قيد وتسكين الطلاب، توزيع المعلمين، وإدارة الكثافة الاستيعابية.',
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
      headerWidgets: [
        _buildKpiSection(isDark, totalCount, activeCount, archivedCount, totalStudents),
        const SizedBox(height: 12),
        _buildSearchAndFilterBar(isDark),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: filtered.isEmpty,
              emptyTitle: _searchController.text.isNotEmpty || _selectedStatusFilter != 'all' || _selectedBranchFilter != 'all'
                  ? 'لا توجد نتائج تطابق بحثك'
                  : 'لا توجد مجموعات دراسية مسجلة',
              emptySubtitle: _searchController.text.isNotEmpty || _selectedStatusFilter != 'all' || _selectedBranchFilter != 'all'
                  ? 'جرّب تعديل مصطلحات البحث أو تغيير فلاتر الفروع والحالة.'
                  : 'قم بإضافة المادة والفرع أولاً، ثم أنشئ المجموعة الأولى عبر زر (إضافة مجموعة جديدة) بالأعلى.',
              emptyIcon: Icons.group_work_rounded,
              onRetry: _loadData,
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
                      itemBuilder: (ctx, i) => _buildGroupCard(context, filtered[i]),
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
                      itemBuilder: (ctx, i) => _buildGroupCard(context, filtered[i]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildGroupCard(context, filtered[i]),
                  );
                },
              ),
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
    String? selectedStudentId = _allStudents.isNotEmpty ? _allStudents.first.id : null;
    final priceCtrl = TextEditingController(text: '0');
    final discountCtrl = TextEditingController(text: '0');
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final dueDateStr =
              '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

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
                  child: const Icon(Icons.person_add_rounded, color: AppColors.studentRole, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تسكين وقيد طالب في المجموعة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(context).width.clamp(280.0, 460.0),
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
                            prefixIcon: Icon(Icons.school_outlined, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          items: _allStudents
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: _dropdownText('${s.fullName} (${s.studentCode})'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => selectedStudentId = v),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ المطلوب / الاشتراك (ج.م)',
                          prefixIcon: Icon(Icons.payments_outlined, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: discountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'قيمة الخصم إن وُجد (ج.م)',
                          prefixIcon: Icon(Icons.discount_outlined, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            helpText: 'اختر تاريخ استحقاق سداد الفاتورة',
                          );
                          if (picked != null) {
                            setStateDialog(() => dueDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.studentRole),
                                  const SizedBox(width: 8),
                                  Text(
                                    'تاريخ استحقاق السداد: $dueDateStr',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Text('تغيير 📅', style: TextStyle(fontSize: 11, color: AppColors.studentRole)),
                            ],
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
                            dueAt: dueDate,
                          );
                          nav.pop();
                          _loadTabResources();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم قيد وتسكين الطالب بنجاح!'),
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
                                content: Text('فشل قيد الطالب: $e'),
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
          );
        },
      ),
    );
  }

  void _showAssignTeacherDialog() {
    String? selectedTeacherId = _allTeachers.isNotEmpty ? _allTeachers.first.id : null;
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
                  child: const Icon(Icons.person_add_rounded, color: AppColors.teacherRole, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تعيين معلم للمجموعة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(context).width.clamp(280.0, 460.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_allTeachers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'اختر المعلم من القائمة *',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
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
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
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
                                behavior: SnackBarBehavior.floating,
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
          behavior: SnackBarBehavior.floating,
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
              'تم توليد شيت كارنيهات طلاب مجموعة (${widget.group.name}) بنجاح (جاهز للطباعة) 🪪',
            ),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: PortalPageShell(
        title: widget.group.name,
        subtitle: 'الكود: ${widget.group.code} | السعة: ${widget.group.maxCapacity ?? "مفتوحة"}',
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
                Tab(icon: Icon(Icons.school_outlined), text: 'الطلاب المقيدون'),
                Tab(icon: Icon(Icons.person_outline_rounded), text: 'المعلمون المسندون'),
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
                emptyIcon: Icons.group_work_rounded,
                onRetry: _loadTabResources,
                child: TabBarView(
                  children: [
                    // Tab 1: Overview
                    ListView(
                      padding: const EdgeInsets.only(bottom: 24),
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
                              value: widget.group.maxCapacity?.toString() ?? 'مفتوحة',
                              icon: Icons.event_seat_rounded,
                              accentColor: AppColors.info,
                            ),
                            PortalMetricCard(
                              label: 'الحالة التشغيلية',
                              value: widget.group.status == 'active' ? 'نشطة 🟢' : 'مؤرشفة ⚪',
                              icon: Icons.verified_rounded,
                              accentColor: AppColors.success,
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Tab 2: Enrolled Students
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'إجمالي الطلاب المقيدين: ${_enrolledStudents.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.studentRole,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _showEnrollStudentDialog,
                                icon: const Icon(Icons.person_add_rounded, size: 15),
                                label: const Text('قيد طالب بالمجموعة', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _enrolledStudents.isEmpty
                              ? const Center(
                                  child: Text(
                                    'لا يوجد طلاب مقيدون في هذه المجموعة حالياً.',
                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  itemCount: _enrolledStudents.length,
                                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final s = _enrolledStudents[i];
                                    return PortalListCard(
                                      icon: Icons.school_outlined,
                                      accentColor: AppColors.studentRole,
                                      title: s.fullName,
                                      subtitle: 'الكود: ${s.studentCode} | الهاتف: ${s.phoneNumber ?? "غير مسجل"}',
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
                                                    const SnackBar(
                                                      content: Text('تم إلغاء قيد الطالب بنجاح'),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                              } catch (err) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('فشل إلغاء القيد: $err'),
                                                      backgroundColor: Colors.red,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
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
                        ),
                      ],
                    ),

                    // Tab 3: Assigned Teachers
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المعلمون المسندون: ${_assignedTeachers.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.teacherRole,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _showAssignTeacherDialog,
                                icon: const Icon(Icons.person_add_rounded, size: 15),
                                label: const Text('تعيين معلم للمجموعة', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _assignedTeachers.isEmpty
                              ? const Center(
                                  child: Text(
                                    'لا يوجد معلمون مسندون لهذه المجموعة حالياً.',
                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  itemCount: _assignedTeachers.length,
                                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final t = _assignedTeachers[i];
                                    return PortalListCard(
                                      icon: Icons.person_outline_rounded,
                                      accentColor: AppColors.teacherRole,
                                      title: t.fullName,
                                      subtitle: 'البريد: ${t.email} | التخصص: ${t.specialization ?? "عام"}',
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
                                                    const SnackBar(
                                                      content: Text('تم إلغاء إسناد المعلم بنجاح'),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                              } catch (err) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('فشل إلغاء الإسناد: $err'),
                                                      backgroundColor: Colors.red,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
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
