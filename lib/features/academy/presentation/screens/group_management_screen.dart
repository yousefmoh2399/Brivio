import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
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
  late final SupabaseSubjectRepository _subjectRepo;
  late final SupabaseBranchRepository _branchRepo;
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseEnrollmentRepository _enrollmentRepo;

  List<GroupEntity> _groups = [];
  List<SubjectEntity> _subjects = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _subjectRepo = SupabaseSubjectRepository(wrapper);
    _branchRepo = SupabaseBranchRepository(wrapper);
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
      final g = await _groupRepo.fetchGroups();
      final s = await _subjectRepo.fetchSubjects();
      final b = await _branchRepo.fetchBranches();
      if (mounted) {
        setState(() {
          _groups = g;
          _subjects = s;
          _branches = b;
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
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '20');
    String? selectedSubjectId = _subjects.isNotEmpty
        ? _subjects.first.id
        : null;
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('إضافة مجموعة دراسية جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المجموعة (مثال: مجموعة الفيزياء - الأحد)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'كود المجموعة (مثال: PHY-G1)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: capacityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'السعة القصوى للطلاب',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  if (_subjects.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedSubjectId,
                      decoration: const InputDecoration(
                        labelText: 'المادة الدراسية',
                      ),
                      items: _subjects
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: _dropdownText(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedSubjectId = v),
                    ),
                  const SizedBox(height: 10),
                  if (_branches.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedBranchId,
                      decoration: const InputDecoration(
                        labelText: 'الفرع التابع له',
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      codeCtrl.text.trim().isEmpty ||
                      selectedSubjectId == null ||
                      selectedBranchId == null) {
                    return;
                  }

                  final nav = Navigator.of(ctx);
                  try {
                    final cap = int.tryParse(capacityCtrl.text.trim());
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
                child: const Text('حفظ المجموعة'),
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
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final g = filtered[i];
                  return PortalListCard(
                    icon: Icons.group_work,
                    accentColor: AppColors.adminRole,
                    title: g.name,
                    subtitle:
                        'الكود: ${g.code} | السعة: ${g.maxCapacity ?? "غير محدودة"}',
                    trailing: [
                      PortalStatusChip(status: g.status),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
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
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('فشل الحذف: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        tooltip: 'حذف المجموعة',
                      ),
                      const Icon(Icons.chevron_left_rounded),
                    ],
                    onTap: () => _openGroupDetails(g),
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
    String? selectedStudentId = _allStudents.isNotEmpty
        ? _allStudents.first.id
        : null;
    final priceCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تسكين وقيد طالب في المجموعة'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_allStudents.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedStudentId,
                      decoration: const InputDecoration(
                        labelText: 'اختر الطالب من القائمة',
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
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'السعر النهائي / الحصة (ج.م)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: discountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'قيمة الخصم إن وُجد (ج.م)',
                    ),
                    keyboardType: TextInputType.number,
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
                  if (selectedStudentId == null) return;
                  final nav = Navigator.of(ctx);
                  try {
                    final price = int.tryParse(priceCtrl.text) ?? 0;
                    final discount = int.tryParse(discountCtrl.text) ?? 0;
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
                child: const Text('تأكيد القيد'),
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تعيين معلم للمجموعة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_allTeachers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedTeacherId,
                    decoration: const InputDecoration(
                      labelText: 'اختر المعلم من القائمة',
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
                  decoration: const InputDecoration(labelText: 'الدور في المجموعة'),
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
            actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedTeacherId == null) return;
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
              child: const Text('تأكيد التعيين'),
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
                              value: widget.group.status == 'active' ? 'نشطة' : widget.group.status,
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
                                      PortalStatusChip(status: s.status),
                                    ],
                                  );
                                },
                              ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: FilledButton.icon(
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
                                  );
                                },
                              ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: FilledButton.icon(
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
