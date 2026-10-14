import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';
import 'teacher_group_details_screen.dart';

class TeacherGroupsScreen extends StatefulWidget {
  final String teacherId;

  const TeacherGroupsScreen({super.key, required this.teacherId});

  @override
  State<TeacherGroupsScreen> createState() => _TeacherGroupsScreenState();
}

class _TeacherGroupsScreenState extends State<TeacherGroupsScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseSubjectRepository _subjectRepo;
  late final SupabaseBranchRepository _branchRepo;
  List<GroupEntity> _groups = [];
  List<SubjectEntity> _subjects = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _subjectRepo = SupabaseSubjectRepository(wrapper);
    _branchRepo = SupabaseBranchRepository(wrapper);
    _loadGroups();
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
              .map((s) => SubjectEntity(
                    id: s['id']?.toString() ?? '',
                    name: s['name']?.toString() ?? '',
                    code: s['code']?.toString() ?? '',
                    status: 'active',
                  ))
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
          subjects.add(SubjectEntity(
            id: created['id']?.toString() ?? '',
            name: created['name']?.toString() ?? 'المادة العامة',
            code: created['code']?.toString() ?? 'GEN',
            status: 'active',
          ));
        } catch (_) {}
      }

      if (branches.isEmpty) {
        try {
          final bRaw = await Supabase.instance.client
              .from('branches')
              .select('id, name, code')
              .limit(50);
          branches = (bRaw as List)
              .map((b) => Branch(
                    id: b['id']?.toString() ?? '',
                    name: b['name']?.toString() ?? '',
                    code: b['code']?.toString() ?? '',
                    status: 'active',
                  ))
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
          branches.add(Branch(
            id: created['id']?.toString() ?? '',
            name: created['name']?.toString() ?? 'الفرع الرئيسي',
            code: created['code']?.toString() ?? 'BR-01',
            status: 'active',
          ));
        } catch (_) {}
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
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit_rounded : Icons.group_add_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'تعديل بيانات المجموعة' : 'إنشاء مجموعة دراسية جديدة',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المجموعة *',
                        hintText: 'مثال: مجموعة السبت والثلاثاء (4 عصراً)',
                        prefixIcon: Icon(Icons.group_rounded),
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
                      decoration: const InputDecoration(
                        labelText: 'كود المجموعة *',
                        hintText: 'مثال: G-101',
                        prefixIcon: Icon(Icons.tag_rounded),
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
                        decoration: const InputDecoration(
                          labelText: 'المادة الدراسية *',
                          prefixIcon: Icon(Icons.menu_book_rounded),
                        ),
                        items: _subjects
                            .map(
                              (subject) => DropdownMenuItem(
                                value: subject.id,
                                child: Text(subject.name),
                              ),
                            )
                            .toList(),
                        validator: (v) => v == null ? 'يرجى اختيار المادة' : null,
                        onChanged: (value) =>
                            setDialogState(() => selectedSubjectId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedBranchId,
                        decoration: const InputDecoration(
                          labelText: 'الفرع / السنتر *',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                        items: _branches
                            .map(
                              (branch) => DropdownMenuItem(
                                value: branch.id,
                                child: Text(branch.name),
                              ),
                            )
                            .toList(),
                        validator: (v) => v == null ? 'يرجى اختيار الفرع' : null,
                        onChanged: (value) =>
                            setDialogState(() => selectedBranchId = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: capacityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'السعة القصوى (عدد الطلاب) *',
                        hintText: 'مثال: 30',
                        prefixIcon: Icon(Icons.people_alt_rounded),
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
                        decoration: const InputDecoration(
                          labelText: 'حالة المجموعة *',
                          prefixIcon: Icon(Icons.toggle_on_rounded),
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
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
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
                      final capacity = int.tryParse(capacityCtrl.text.trim()) ?? 30;

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
                                  if (widget.teacherId.isNotEmpty) 'teacher_id': widget.teacherId,
                                })
                                .select('id')
                                .single();
                            final groupId = newGroup['id']?.toString();
                            if (groupId != null && widget.teacherId.isNotEmpty) {
                              await Supabase.instance.client
                                  .from('group_teachers')
                                  .insert({
                                    'group_id': groupId,
                                    'teacher_id': widget.teacherId,
                                    'role': 'primary',
                                    'is_primary': true,
                                  }).catchError((_) => null);
                            }
                          }
                        }
                        success = true;
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
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
        ),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('إنشاء مجموعة جديدة 👥'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'حدث خطأ في تحميل البيانات: $_errorMessage',
                            style: AppTypography.bodyMedium(AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadGroups,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              'إعادة المحاولة',
                              style: AppTypography.labelMedium(textColor),
                            ),
                          ),
                        ],
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
                            const Icon(
                              Icons.group_off_rounded,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد مجموعات دراسية مسندة إليك حالياً.',
                              style: AppTypography.titleMedium(textColor).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'اضغط على زر "إنشاء مجموعة جديدة" بالأسفل لبدء تدريس أول مجموعة.',
                              style: AppTypography.bodySmall(subtitleColor),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _groups.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final g = _groups[i];
                  final isArchived = g.status.toLowerCase() == 'archived';

                  return FadeInSlide(
                    delay: Duration(milliseconds: 40 * i),
                    child: GlassCard(
                      color: surfaceColor,
                      onTap: () => _openGroupDetails(g),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: (isArchived ? Colors.grey : AppColors.primary)
                                .withValues(alpha: 0.15),
                            child: Icon(
                              isArchived ? Icons.archive_outlined : Icons.group_rounded,
                              color: isArchived ? Colors.grey : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        g.name,
                                        style: AppTypography.titleMedium(textColor).copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (isArchived ? Colors.grey : Colors.green)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isArchived ? 'مؤرشفة' : 'نشطة',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isArchived ? Colors.grey : Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'كود: ${g.code}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'السعة: ${g.maxCapacity ?? "غير محددة"} طالب',
                                      style: AppTypography.bodySmall(subtitleColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'خيارات المجموعة',
                            icon: const Icon(Icons.more_vert_rounded),
                            onSelected: (value) {
                              if (value == 'edit') _showGroupDialog(group: g);
                              if (value == 'archive') _archiveGroup(g);
                              if (value == 'restore') _restoreGroup(g);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_rounded, color: AppColors.primary),
                                  title: Text('تعديل المجموعة'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              if (!isArchived)
                                const PopupMenuItem(
                                  value: 'archive',
                                  child: ListTile(
                                    leading: Icon(Icons.archive_outlined, color: AppColors.warning),
                                    title: Text('أرشفة المجموعة'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              if (isArchived)
                                const PopupMenuItem(
                                  value: 'restore',
                                  child: ListTile(
                                    leading: Icon(Icons.unarchive_rounded, color: Colors.green),
                                    title: Text('إلغاء الأرشفة (تنشيط)'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                            ],
                          ),
                          Icon(Icons.chevron_left_rounded, color: subtitleColor),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
