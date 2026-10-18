import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';
import '../../domain/repositories/academy_repositories.dart';
import 'teacher_group_details_screen.dart';

class TeacherGroupsScreen extends StatefulWidget {
  final String teacherId;
  final ITeacherRepository? teacherRepo;
  final ISubjectRepository? subjectRepo;
  final IBranchRepository? branchRepo;
  final List<GroupEntity>? initialGroups;
  final List<SubjectEntity>? initialSubjects;
  final List<Branch>? initialBranches;
  final Map<String, int>? initialEnrolledCounts;

  const TeacherGroupsScreen({
    super.key,
    required this.teacherId,
    this.teacherRepo,
    this.subjectRepo,
    this.branchRepo,
    this.initialGroups,
    this.initialSubjects,
    this.initialBranches,
    this.initialEnrolledCounts,
  });

  @override
  State<TeacherGroupsScreen> createState() => _TeacherGroupsScreenState();
}

class _TeacherGroupsScreenState extends State<TeacherGroupsScreen> {
  late final ITeacherRepository _teacherRepo;
  late final ISubjectRepository _subjectRepo;
  late final IBranchRepository _branchRepo;

  List<GroupEntity> _groups = [];
  List<SubjectEntity> _subjects = [];
  List<Branch> _branches = [];
  Map<String, int> _enrolledCounts = {};

  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'active', 'archived'

  @override
  void initState() {
    super.initState();
    if (widget.initialGroups != null) {
      _groups = List.from(widget.initialGroups!);
      _subjects = widget.initialSubjects != null
          ? List.from(widget.initialSubjects!)
          : [];
      _branches = widget.initialBranches != null
          ? List.from(widget.initialBranches!)
          : [];
      _enrolledCounts = widget.initialEnrolledCounts != null
          ? Map.from(widget.initialEnrolledCounts!)
          : {};
      _isLoading = false;
    } else {
      try {
        final wrapper = SupabaseClientWrapper(Supabase.instance.client);
        _teacherRepo = widget.teacherRepo ?? SupabaseTeacherRepository(wrapper);
        _subjectRepo = widget.subjectRepo ?? SupabaseSubjectRepository(wrapper);
        _branchRepo = widget.branchRepo ?? SupabaseBranchRepository(wrapper);
        _loadGroups();
      } catch (e) {
        _errorMessage = e.toString();
        _isLoading = false;
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _teacherRepo.fetchAssignedGroups(widget.teacherId),
        _subjectRepo.fetchSubjects().catchError((_) => <SubjectEntity>[]),
        _branchRepo.fetchBranches().catchError((_) => <Branch>[]),
      ]);
      var groups = results[0] as List<GroupEntity>;
      var subjects = results[1] as List<SubjectEntity>;
      var branches = results[2] as List<Branch>;

      if (subjects.isEmpty) {
        try {
          final sRaw = await Supabase.instance.client
              .from('subjects')
              .select('id, name, code')
              .limit(50);
          subjects = (sRaw as List)
              .map(
                (s) => SubjectEntity(
                  id: s['id']?.toString() ?? '',
                  name: s['name']?.toString() ?? '',
                  code: s['code']?.toString() ?? '',
                  status: 'active',
                ),
              )
              .toList();
        } catch (_) {}
      }
      if (subjects.isEmpty) {
        try {
          final created = await Supabase.instance.client
              .from('subjects')
              .insert({
                'name': 'المادة العامة',
                'code': 'GEN-${DateTime.now().millisecondsSinceEpoch % 1000}',
              })
              .select('id, name, code')
              .single();
          subjects.add(
            SubjectEntity(
              id: created['id']?.toString() ?? '',
              name: created['name']?.toString() ?? 'المادة العامة',
              code: created['code']?.toString() ?? 'GEN',
              status: 'active',
            ),
          );
        } catch (_) {}
      }

      if (branches.isEmpty) {
        try {
          final bRaw = await Supabase.instance.client
              .from('branches')
              .select('id, name, code')
              .limit(50);
          branches = (bRaw as List)
              .map(
                (b) => Branch(
                  id: b['id']?.toString() ?? '',
                  name: b['name']?.toString() ?? '',
                  code: b['code']?.toString() ?? '',
                  status: 'active',
                ),
              )
              .toList();
        } catch (_) {}
      }
      if (branches.isEmpty) {
        try {
          final created = await Supabase.instance.client
              .from('branches')
              .insert({
                'name': 'الفرع الرئيسي',
                'code': 'BR-${DateTime.now().millisecondsSinceEpoch % 1000}',
              })
              .select('id, name, code')
              .single();
          branches.add(
            Branch(
              id: created['id']?.toString() ?? '',
              name: created['name']?.toString() ?? 'الفرع الرئيسي',
              code: created['code']?.toString() ?? 'BR-01',
              status: 'active',
            ),
          );
        } catch (_) {}
      }

      // Query enrolled student counts per group
      Map<String, int> enrolledCounts = {};
      try {
        if (groups.isNotEmpty) {
          final groupIds = groups.map((g) => g.id).toList();
          final enrollmentsData = await Supabase.instance.client
              .from('enrollments')
              .select('group_id')
              .inFilter('group_id', groupIds);
          for (final row in enrollmentsData) {
            final gId = row['group_id']?.toString() ?? '';
            if (gId.isNotEmpty) {
              enrolledCounts[gId] = (enrolledCounts[gId] ?? 0) + 1;
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _groups = groups;
          _subjects = subjects;
          _branches = branches;
          _enrolledCounts = enrolledCounts;
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

  int get _activeGroupsCount =>
      _groups.where((g) => g.status.toLowerCase() != 'archived').length;

  int get _archivedGroupsCount =>
      _groups.where((g) => g.status.toLowerCase() == 'archived').length;

  int get _totalEnrolledStudents =>
      _enrolledCounts.values.fold(0, (sum, count) => sum + count);

  List<GroupEntity> get _filteredGroups {
    return _groups.where((g) {
      if (_selectedFilter == 'active' &&
          g.status.toLowerCase() == 'archived') {
        return false;
      }
      if (_selectedFilter == 'archived' &&
          g.status.toLowerCase() != 'archived') {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = g.name.toLowerCase().contains(q);
        final matchCode = g.code.toLowerCase().contains(q);
        final matchSubject = _getSubjectName(g.subjectId).toLowerCase().contains(q);
        final matchBranch = _getBranchName(g.branchId).toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchSubject && !matchBranch) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _getSubjectName(String subjectId) {
    final sub = _subjects.where((s) => s.id == subjectId).firstOrNull;
    return sub?.name ?? 'المادة العامة';
  }

  String _getBranchName(String branchId) {
    final br = _branches.where((b) => b.id == branchId).firstOrNull;
    return br?.name ?? 'الفرع الرئيسي';
  }

  void _openGroupDetails(GroupEntity group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherGroupDetailsScreen(group: group),
      ),
    );
  }

  void _showGroupDialog({GroupEntity? group}) {
    final isEditing = group != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    final codeCtrl = TextEditingController(text: group?.code ?? '');
    final capacityCtrl = TextEditingController(
      text: (group?.maxCapacity ?? 30).toString(),
    );
    String? selectedSubjectId =
        group?.subjectId ?? (_subjects.isNotEmpty ? _subjects.first.id : null);
    String? selectedBranchId =
        group?.branchId ?? (_branches.isNotEmpty ? _branches.first.id : null);
    String status = group?.status ?? 'active';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dialogSurface = isDark
              ? AppColors.darkCard
              : AppColors.lightCard;

          return AlertDialog(
            backgroundColor: dialogSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teacherRole.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_rounded : Icons.group_add_rounded,
                    color: AppColors.teacherRole,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEditing
                        ? 'تعديل بيانات المجموعة'
                        : 'إنشاء مجموعة دراسية جديدة',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'اسم المجموعة *',
                            hintText: 'مثال: فيزياء 3ث - السبت والثلاثاء',
                            prefixIcon: const Icon(
                              Icons.groups_rounded,
                              color: AppColors.teacherRole,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى إدخال اسم المجموعة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: codeCtrl,
                          decoration: InputDecoration(
                            labelText: 'كود المجموعة *',
                            hintText: 'مثال: PHY-301',
                            prefixIcon: const Icon(
                              Icons.tag_rounded,
                              color: AppColors.teacherRole,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى إدخال كود المجموعة';
                            }
                            return null;
                          },
                        ),
                        if (!isEditing) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedSubjectId,
                            decoration: InputDecoration(
                              labelText: 'المادة الدراسية *',
                              prefixIcon: const Icon(
                                Icons.menu_book_rounded,
                                color: AppColors.teacherRole,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _subjects
                                .map(
                                  (subject) => DropdownMenuItem(
                                    value: subject.id,
                                    child: Text(
                                      subject.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (v) =>
                                v == null ? 'يرجى اختيار المادة' : null,
                            onChanged: (value) =>
                                setDialogState(() => selectedSubjectId = value),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedBranchId,
                            decoration: InputDecoration(
                              labelText: 'الفرع / السنتر *',
                              prefixIcon: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.teacherRole,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _branches
                                .map(
                                  (branch) => DropdownMenuItem(
                                    value: branch.id,
                                    child: Text(
                                      branch.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (v) =>
                                v == null ? 'يرجى اختيار الفرع' : null,
                            onChanged: (value) =>
                                setDialogState(() => selectedBranchId = value),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: capacityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'السعة القصوى (عدد الطلاب) *',
                            hintText: 'مثال: 30',
                            prefixIcon: const Icon(
                              Icons.people_alt_rounded,
                              color: AppColors.teacherRole,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى إدخال السعة القصوى';
                            }
                            final val = int.tryParse(v);
                            if (val == null || val <= 0) {
                              return 'أدخل سعة صحيحة أكبر من صفر';
                            }
                            return null;
                          },
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: InputDecoration(
                              labelText: 'حالة المجموعة *',
                              prefixIcon: const Icon(
                                Icons.toggle_on_rounded,
                                color: AppColors.teacherRole,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('نشطة حالياً ✔️'),
                              ),
                              DropdownMenuItem(
                                value: 'archived',
                                child: Text('مؤرشفة 📁'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => status = value);
                              }
                            },
                          ),
                        ],
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
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teacherRole,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isEditing ? Icons.save_rounded : Icons.add_rounded),
                label: Text(
                  isSubmitting
                      ? 'جاري الحفظ...'
                      : (isEditing ? 'حفظ التعديلات' : 'إنشاء المجموعة'),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);

                        final name = nameCtrl.text.trim();
                        final code = codeCtrl.text.trim();
                        final capacity =
                            int.tryParse(capacityCtrl.text.trim()) ?? 30;

                        bool success = false;
                        try {
                          if (isEditing) {
                            try {
                              await Supabase.instance.client.rpc(
                                'teacher_update_group',
                                params: {
                                  'p_group_id': group.id,
                                  'p_name': name,
                                  'p_code': code,
                                  'p_capacity': capacity,
                                  'p_status': status,
                                },
                              );
                            } catch (_) {
                              await Supabase.instance.client
                                  .from('groups')
                                  .update({
                                    'name': name,
                                    'code': code,
                                    'capacity': capacity,
                                    'status': status,
                                  })
                                  .eq('id', group.id);
                            }
                          } else {
                            try {
                              await Supabase.instance.client.rpc(
                                'teacher_create_group',
                                params: {
                                  'p_name': name,
                                  'p_code': code,
                                  'p_subject_id': selectedSubjectId,
                                  'p_branch_id': selectedBranchId,
                                  'p_capacity': capacity,
                                },
                              );
                            } catch (_) {
                              final newGroup = await Supabase.instance.client
                                  .from('groups')
                                  .insert({
                                    'name': name,
                                    'code': code,
                                    'subject_id': selectedSubjectId,
                                    'branch_id': selectedBranchId,
                                    'capacity': capacity,
                                    'status': 'active',
                                    if (widget.teacherId.isNotEmpty)
                                      'teacher_id': widget.teacherId,
                                  })
                                  .select('id')
                                  .single();
                              final groupId = newGroup['id']?.toString();
                              if (groupId != null &&
                                  widget.teacherId.isNotEmpty) {
                                await Supabase.instance.client
                                    .from('group_teachers')
                                    .insert({
                                      'group_id': groupId,
                                      'teacher_id': widget.teacherId,
                                      'role': 'primary',
                                      'is_primary': true,
                                    })
                                    .catchError((_) => null);
                              }
                            }
                          }
                          success = true;
                        } catch (e) {
                          if (ctx.mounted) {
                            try {
                              setDialogState(() => isSubmitting = false);
                            } catch (_) {}
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تعذر حفظ المجموعة: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }

                        if (success) {
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          await _loadGroups();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? 'تم تحديث بيانات المجموعة بنجاح'
                                      : 'تم إنشاء المجموعة الدراسية بنجاح 👥',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _archiveGroup(GroupEntity group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أرشفة المجموعة الدراسية 📁'),
        content: Text(
          'هل أنت متأكد من رغبتك في أرشفة مجموعة "${group.name}"؟\n'
          'ستبقى سجلات وبيانات الطلاب والامتحانات محفوظة بالكامل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('أرشفة الآن'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      try {
        await Supabase.instance.client.rpc(
          'teacher_archive_group',
          params: {'p_group_id': group.id},
        );
      } catch (_) {
        await Supabase.instance.client
            .from('groups')
            .update({'status': 'archived'})
            .eq('id', group.id);
      }
      await _loadGroups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت أرشفة المجموعة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر أرشفة المجموعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreGroup(GroupEntity group) async {
    try {
      try {
        await Supabase.instance.client.rpc(
          'teacher_update_group',
          params: {
            'p_group_id': group.id,
            'p_name': group.name,
            'p_code': group.code,
            'p_capacity': group.maxCapacity ?? 30,
            'p_status': 'active',
          },
        );
      } catch (_) {
        await Supabase.instance.client
            .from('groups')
            .update({'status': 'active'})
            .eq('id', group.id);
      }
      await _loadGroups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء أرشفة وتنشيط المجموعة بنجاح ✔️'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر استعادة المجموعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color surfaceColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required bool isSelected,
    required bool isDark,
    Color activeColor = AppColors.teacherRole,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? activeColor
                : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard({
    required GroupEntity group,
    required bool isDark,
    required Color surfaceColor,
    required Color textColor,
    required Color subtitleColor,
    required int enrolledCount,
  }) {
    final isArchived = group.status.toLowerCase() == 'archived';
    final capacity = group.maxCapacity ?? 30;
    final progress =
        capacity > 0 ? (enrolledCount / capacity).clamp(0.0, 1.0) : 0.0;
    final subjectName = _getSubjectName(group.subjectId);
    final branchName = _getBranchName(group.branchId);

    Color statusColor = isArchived
        ? Colors.grey
        : (progress >= 1.0 ? Colors.amber : Colors.green);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isArchived
              ? (isDark ? Colors.white10 : Colors.black12)
              : AppColors.teacherRole.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openGroupDetails(group),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row badges & status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 110),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.teacherRole.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.teacherRole.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.menu_book_rounded,
                                  size: 12,
                                  color: AppColors.teacherRole,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    subjectName,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.teacherRole,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 100),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: subtitleColor,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    branchName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: subtitleColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (isArchived ? Colors.grey : Colors.green)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isArchived ? Colors.grey : Colors.green)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isArchived ? Colors.grey : Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isArchived ? 'مؤرشفة' : 'نشطة',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isArchived ? Colors.grey : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      tooltip: 'خيارات المجموعة',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: subtitleColor,
                        size: 20,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') _showGroupDialog(group: group);
                        if (value == 'archive') _archiveGroup(group);
                        if (value == 'restore') _restoreGroup(group);
                        if (value == 'copy') {
                          Clipboard.setData(ClipboardData(text: group.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ كود المجموعة إلى الحافظة 📋'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                color: AppColors.teacherRole,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text('تعديل المجموعة'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'copy',
                          child: Row(
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                color: Colors.blueAccent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text('نسخ كود المجموعة'),
                            ],
                          ),
                        ),
                        if (!isArchived)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.archive_outlined,
                                  color: AppColors.warning,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text('أرشفة المجموعة'),
                              ],
                            ),
                          ),
                        if (isArchived)
                          const PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.unarchive_rounded,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text('تنشيط (إلغاء الأرشفة)'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Group Name
                Text(
                  group.name,
                  style: AppTypography.titleMedium(textColor).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Code tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'كود: ${group.code}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: AppColors.teacherRole,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Enrollment & Capacity Telemetry Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                size: 13,
                                color: subtitleColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$enrolledCount من $capacity طالب',
                                  style: AppTypography.bodySmall(
                                    textColor,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          progress >= 1.0
                              ? 'مكتملة ⚠️'
                              : '${(progress * 100).toInt()}% إشغال',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action Buttons Footer
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(
                            color: AppColors.teacherRole.withValues(alpha: 0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.dashboard_outlined,
                          size: 16,
                          color: AppColors.teacherRole,
                        ),
                        label: const Text(
                          'تفاصيل المجموعة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.teacherRole,
                          ),
                        ),
                        onPressed: () => _openGroupDetails(group),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'تعديل المجموعة',
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.teacherRole,
                      ),
                      onPressed: () => _showGroupDialog(group: group),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final filtered = _filteredGroups;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupDialog(),
        backgroundColor: AppColors.teacherRole,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text(
          'إنشاء مجموعة جديدة 👥',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        color: AppColors.teacherRole,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.teacherRole),
              )
            : _errorMessage != null
            ? CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'حدث خطأ في تحميل البيانات',
                              style: AppTypography.titleMedium(
                                textColor,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall(AppColors.error),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.teacherRole,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _loadGroups,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : _groups.isEmpty
            ? CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.teacherRole.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.group_off_rounded,
                                size: 56,
                                color: AppColors.teacherRole,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد مجموعات دراسية مسندة إليك حالياً',
                              style: AppTypography.titleMedium(
                                textColor,
                              ).copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اضغط على زر "إنشاء مجموعة جديدة" بالأسفل لبدء تدريس أول مجموعة دراسية.',
                              style: AppTypography.bodySmall(subtitleColor),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teacherRole,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => _showGroupDialog(),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('إنشاء أول مجموعة دراسية'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  // KPI Telemetry Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 680;
                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'إجمالي المجموعات',
                                value: '${_groups.length}',
                                icon: Icons.hub_rounded,
                                color: AppColors.teacherRole,
                                isDark: isDark,
                                surfaceColor: surfaceColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'المجموعات النشطة',
                                value: '$_activeGroupsCount',
                                icon: Icons.check_circle_rounded,
                                color: Colors.green,
                                isDark: isDark,
                                surfaceColor: surfaceColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'الطلاب المقيدين',
                                value: '$_totalEnrolledStudents',
                                icon: Icons.people_alt_rounded,
                                color: Colors.blueAccent,
                                isDark: isDark,
                                surfaceColor: surfaceColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'المجموعات المؤرشفة',
                                value: '$_archivedGroupsCount',
                                icon: Icons.archive_rounded,
                                color: Colors.amber,
                                isDark: isDark,
                                surfaceColor: surfaceColor,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.1,
                          children: [
                            _buildKpiCard(
                              title: 'إجمالي المجموعات',
                              value: '${_groups.length}',
                              icon: Icons.hub_rounded,
                              color: AppColors.teacherRole,
                              isDark: isDark,
                              surfaceColor: surfaceColor,
                            ),
                            _buildKpiCard(
                              title: 'المجموعات النشطة',
                              value: '$_activeGroupsCount',
                              icon: Icons.check_circle_rounded,
                              color: Colors.green,
                              isDark: isDark,
                              surfaceColor: surfaceColor,
                            ),
                            _buildKpiCard(
                              title: 'الطلاب المقيدين',
                              value: '$_totalEnrolledStudents',
                              icon: Icons.people_alt_rounded,
                              color: Colors.blueAccent,
                              isDark: isDark,
                              surfaceColor: surfaceColor,
                            ),
                            _buildKpiCard(
                              title: 'المجموعات المؤرشفة',
                              value: '$_archivedGroupsCount',
                              icon: Icons.archive_rounded,
                              color: Colors.amber,
                              isDark: isDark,
                              surfaceColor: surfaceColor,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Search & Filter Row
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مجموعة، كود، أو مادة...',
                      hintStyle: TextStyle(fontSize: 13, color: subtitleColor),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.teacherRole,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.teacherRole,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          id: 'all',
                          label: 'الكل (${_groups.length})',
                          isSelected: _selectedFilter == 'all',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          id: 'active',
                          label: 'النشطة ($_activeGroupsCount)',
                          isSelected: _selectedFilter == 'active',
                          isDark: isDark,
                          activeColor: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          id: 'archived',
                          label: 'المؤرشفة ($_archivedGroupsCount)',
                          isSelected: _selectedFilter == 'archived',
                          isDark: isDark,
                          activeColor: Colors.amber,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Group Cards List or Empty Filter Search
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'لم يتم العثور على مجموعات مطابقة',
                              style: AppTypography.titleMedium(
                                textColor,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'جرب البحث باسم آخر أو إزالة التصفية الحالية',
                              style: AppTypography.bodySmall(subtitleColor),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.teacherRole,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedFilter = 'all';
                                });
                              },
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: AppColors.teacherRole,
                              ),
                              label: const Text(
                                'إعادة تعيين البحث',
                                style: TextStyle(
                                  color: AppColors.teacherRole,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 768;
                        if (isWide) {
                          final columns = constraints.maxWidth >= 1050 ? 3 : 2;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 260,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final group = filtered[index];
                              final enrolled =
                                  _enrolledCounts[group.id] ?? 0;
                              return _buildGroupCard(
                                group: group,
                                isDark: isDark,
                                surfaceColor: surfaceColor,
                                textColor: textColor,
                                subtitleColor: subtitleColor,
                                enrolledCount: enrolled,
                              );
                            },
                          );
                        } else {
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final group = filtered[index];
                              final enrolled =
                                  _enrolledCounts[group.id] ?? 0;
                              return FadeInSlide(
                                delay: Duration(milliseconds: 30 * index),
                                child: _buildGroupCard(
                                  group: group,
                                  isDark: isDark,
                                  surfaceColor: surfaceColor,
                                  textColor: textColor,
                                  subtitleColor: subtitleColor,
                                  enrolledCount: enrolled,
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                ],
              ),
      ),
    );
  }
}
