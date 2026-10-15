import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_curriculum_repositories.dart';
import '../../domain/models/curriculum_models.dart';
import '../../../attendance/presentation/screens/teacher_session_board_screen.dart';

class CurriculumEditorScreen extends StatefulWidget {
  const CurriculumEditorScreen({super.key});

  @override
  State<CurriculumEditorScreen> createState() => _CurriculumEditorScreenState();
}

class _CurriculumAction {
  final IconData icon;
  final Color? color;
  final String label;
  final VoidCallback onPressed;

  const _CurriculumAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });
}

class _CurriculumActionMenu extends StatelessWidget {
  final List<_CurriculumAction> actions;

  const _CurriculumActionMenu({required this.actions});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'خيارات',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (index) => actions[index].onPressed(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actions[i].icon, color: actions[i].color, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(actions[i].label)),
              ],
            ),
          ),
      ],
    );
  }
}

class _CurriculumEditorScreenState extends State<CurriculumEditorScreen> {
  late final SupabaseSemesterRepository _semesterRepo;
  late final SupabaseUnitRepository _unitRepo;
  late final SupabaseLessonRepository _lessonRepo;
  late final SupabaseLessonResourceRepository _resourceRepo;
  late final SupabaseSubjectRepository _subjectRepo;

  List<SubjectEntity> _subjects = [];
  SubjectEntity? _selectedSubject;
  List<Semester> _semesters = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _semesterRepo = SupabaseSemesterRepository(wrapper);
    _unitRepo = SupabaseUnitRepository(wrapper);
    _lessonRepo = SupabaseLessonRepository(wrapper);
    _resourceRepo = SupabaseLessonResourceRepository(wrapper);
    _subjectRepo = SupabaseSubjectRepository(wrapper);
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subjects = await _subjectRepo.fetchSubjects(status: 'active');
      final selected =
          _selectedSubject ?? (subjects.isEmpty ? null : subjects.first);
      final sList = selected == null
          ? <Semester>[]
          : await _semesterRepo.fetchSemestersForSubject(selected.id);
      final List<Semester> populatedSemesters = [];

      for (final sem in sList) {
        final uList = await _unitRepo.fetchUnitsForSemester(sem.id);
        final List<Unit> populatedUnits = [];

        for (final unit in uList) {
          final lList = await _lessonRepo.fetchLessonsForUnit(unit.id);
          populatedUnits.add(
            Unit(
              id: unit.id,
              semesterId: unit.semesterId,
              name: unit.name,
              code: unit.code,
              orderNumber: unit.orderNumber,
              status: unit.status,
              lessons: lList,
            ),
          );
        }

        populatedSemesters.add(
          Semester(
            id: sem.id,
            subjectId: sem.subjectId,
            name: sem.name,
            code: sem.code,
            orderNumber: sem.orderNumber,
            startDate: sem.startDate,
            endDate: sem.endDate,
            status: sem.status,
            units: populatedUnits,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _subjects = subjects;
          _selectedSubject = selected;
          _semesters = populatedSemesters;
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

  void _showCreateSemesterDialog() {
    final selectedSubject = _selectedSubject;
    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مادة دراسية أولاً.')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة فصل دراسي جديد'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم الفصل الدراسي (مثال: الفصل الدراسي الأول)',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الفصل الدراسي' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'كود الفصل (مثال: TERM-1)',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الفصل' : null,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              final nav = Navigator.of(ctx);
              try {
                final newSem = Semester(
                  id: '',
                  subjectId: selectedSubject.id,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  orderNumber: _semesters.length + 1,
                  startDate: DateTime.now(),
                  endDate: DateTime.now().add(const Duration(days: 120)),
                  status: 'active',
                );

                await _semesterRepo.createSemester(newSem);
                nav.pop();
                _loadCurriculum();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل إضافة الفصل الدراسي: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('إضافة الفصل'),
          ),
        ],
      ),
    );
  }

  void _showEditSemesterDialog(Semester semester) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: semester.name);
    final codeCtrl = TextEditingController(text: semester.code);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الفصل الدراسي'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الفصل الدراسي'),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الفصل' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'كود الفصل'),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الفصل' : null,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              final nav = Navigator.of(ctx);
              try {
                final updated = Semester(
                  id: semester.id,
                  subjectId: semester.subjectId,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  orderNumber: semester.orderNumber,
                  startDate: semester.startDate,
                  endDate: semester.endDate,
                  status: semester.status,
                  units: semester.units,
                );
                await _semesterRepo.updateSemester(updated);
                nav.pop();
                _loadCurriculum();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل تعديل الفصل: $e'), backgroundColor: Colors.red),
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

  void _showCreateUnitDialog(Semester semester) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة وحدة في ${semester.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم الوحدة (مثال: الوحدة الأولى: الحركة والقوى)',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الوحدة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'كود الوحدة (مثال: U1)',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الوحدة' : null,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              final nav = Navigator.of(ctx);
              try {
                final newUnit = Unit(
                  id: '',
                  semesterId: semester.id,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  orderNumber: semester.units.length + 1,
                  status: 'active',
                );

                await _unitRepo.createUnit(newUnit);
                nav.pop();
                _loadCurriculum();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل إضافة الوحدة: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('إضافة الوحدة'),
          ),
        ],
      ),
    );
  }

  void _showEditUnitDialog(Unit unit) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: unit.name);
    final codeCtrl = TextEditingController(text: unit.code);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الوحدة'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الوحدة'),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الوحدة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'كود الوحدة'),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الوحدة' : null,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              final nav = Navigator.of(ctx);
              try {
                final updated = Unit(
                  id: unit.id,
                  semesterId: unit.semesterId,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  orderNumber: unit.orderNumber,
                  status: unit.status,
                  lessons: unit.lessons,
                );
                await _unitRepo.updateUnit(updated);
                nav.pop();
                _loadCurriculum();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل تعديل الوحدة: $e'), backgroundColor: Colors.red),
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

  void _showCreateLessonDialog(Unit unit) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '45');
    String lessonTypeStr = 'video';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('إضافة درس في ${unit.name}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الدرس',
                      hintText: 'مثال: شرح قانون أوم والدائرة الكهربية',
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال عنوان الدرس' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: lessonTypeStr,
                    decoration: const InputDecoration(
                      labelText: 'نوع الدرس والمحتوى',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'video',
                        child: Text('فيديو شرح'),
                      ),
                      DropdownMenuItem(
                        value: 'pdf',
                        child: Text('مستند / مذكرة PDF'),
                      ),
                      DropdownMenuItem(
                        value: 'quiz',
                        child: Text('اختبار تفاعلي'),
                      ),
                      DropdownMenuItem(
                        value: 'text',
                        child: Text('محتوى نصي وملخص'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => lessonTypeStr = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المدة التقديرية بالدقائق',
                      suffixText: 'دقيقة',
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
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final nav = Navigator.of(ctx);
                  try {
                    final newLesson = Lesson(
                      id: '',
                      unitId: unit.id,
                      title: titleCtrl.text.trim(),
                      lessonType: LessonType.fromString(lessonTypeStr),
                      orderNumber: unit.lessons.length + 1,
                      status: LessonStatus.draft,
                      estimatedDurationMinutes: int.tryParse(durationCtrl.text.trim()) ?? 45,
                    );

                    await _lessonRepo.createLesson(newLesson);
                    nav.pop();
                    _loadCurriculum();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل إضافة الدرس: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('إضافة الدرس'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditLessonDialog(Lesson lesson) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: lesson.title);
    final durationCtrl = TextEditingController(
      text: (lesson.estimatedDurationMinutes ?? 45).toString(),
    );
    String lessonTypeStr = lesson.lessonType.toDbValue();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تعديل بيانات الدرس'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'عنوان الدرس'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال عنوان الدرس' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: lessonTypeStr,
                    decoration: const InputDecoration(labelText: 'نوع المحتوى'),
                    items: const [
                      DropdownMenuItem(value: 'video', child: Text('فيديو شرح')),
                      DropdownMenuItem(value: 'pdf', child: Text('مستند / مذكرة PDF')),
                      DropdownMenuItem(value: 'quiz', child: Text('اختبار تفاعلي')),
                      DropdownMenuItem(value: 'text', child: Text('محتوى نصي وملخص')),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => lessonTypeStr = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المدة التقديرية بالدقائق',
                      suffixText: 'دقيقة',
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
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final nav = Navigator.of(ctx);
                  try {
                    final updated = Lesson(
                      id: lesson.id,
                      unitId: lesson.unitId,
                      title: titleCtrl.text.trim(),
                      lessonType: LessonType.fromString(lessonTypeStr),
                      orderNumber: lesson.orderNumber,
                      status: lesson.status,
                      publishedAt: lesson.publishedAt,
                      estimatedDurationMinutes: int.tryParse(durationCtrl.text.trim()) ?? lesson.estimatedDurationMinutes,
                      resources: lesson.resources,
                    );
                    await _lessonRepo.updateLesson(updated);
                    nav.pop();
                    _loadCurriculum();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('فشل تعديل الدرس: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUploadResourceDialog(Lesson lesson) {
    final titleCtrl = TextEditingController(
      text: 'مذكرة ${lesson.title}',
    );
    final objectPathCtrl = TextEditingController(text: 'lessons/${lesson.id}/');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إرفاق مذكرة / ملف PDF (${lesson.title})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'عنوان الملف أو المذكرة',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: objectPathCtrl,
              decoration: const InputDecoration(
                labelText: 'مسار التخزين (Object Path)',
                hintText: 'lessons/<lesson-id>/lecture.pdf',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('إرفاق الملف'),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty ||
                  objectPathCtrl.text.trim().isEmpty) {
                return;
              }

              final nav = Navigator.of(ctx);
              try {
                final objectPath = objectPathCtrl.text.trim();

                final res = LessonResource(
                  id: '',
                  lessonId: lesson.id,
                  title: titleCtrl.text.trim(),
                  resourceType: 'pdf',
                  bucket: 'curriculum_assets',
                  objectPath: objectPath,
                  orderNumber: lesson.resources.length + 1,
                );

                await _resourceRepo.createResource(res);
                nav.pop();
                _loadCurriculum();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إرفاق الملف بنجاح!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل إرفاق الملف: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteResource(LessonResource res) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المرفق'),
        content: Text('هل أنت متأكد من حذف المرفق "${res.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _resourceRepo.deleteResource(res.id);
        _loadCurriculum();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المرفق بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل حذف المرفق: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _lessonTypeLabel(LessonType type) {
    return switch (type) {
      LessonType.video => 'فيديو شرح',
      LessonType.pdf => 'مستند PDF',
      LessonType.quiz => 'اختبار تفاعلي',
      LessonType.text => 'محتوى نصي',
      LessonType.programming => 'تطبيق برمجي / عملي',
    };
  }

  String _lessonStatusLabel(LessonStatus status) {
    return switch (status) {
      LessonStatus.published => 'منشور للطلاب',
      LessonStatus.draft => 'مسودة',
      LessonStatus.archived => 'مؤرشف',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'إدارة المناهج والدروس',
      subtitle: 'تنظيم الفصول الدراسية والوحدات والدروس ورفع المذكرات التعليمية.',
      icon: Icons.auto_stories,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadCurriculum,
        ),
        if (_selectedSubject != null)
          PortalAction(
            icon: Icons.add,
            label: 'إضافة فصل دراسي',
            onPressed: _showCreateSemesterDialog,
            primary: true,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'لا توجد بيانات مناهج',
        emptySubtitle: 'قم بإضافة مادة دراسية أولاً.',
        emptyIcon: Icons.auto_stories,
        onRetry: _loadCurriculum,
        child: Column(
          children: [
            if (_subjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<SubjectEntity>(
                  initialValue: _selectedSubject,
                  decoration: const InputDecoration(labelText: 'المادة الدراسية'),
                  items: _subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (${s.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (subject) {
                    if (subject == null) return;
                    setState(() => _selectedSubject = subject);
                    _loadCurriculum();
                  },
                ),
              ),
            Expanded(
              child: _selectedSubject == null
                  ? const Center(child: Text('لا توجد مواد دراسية نشطة حالياً.'))
                  : _semesters.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد فصول دراسية مضافة. أضف فصلاً دراسياً للبدء.',
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _semesters.length,
                      itemBuilder: (ctx, semIdx) {
                        final sem = _semesters[semIdx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: const Icon(
                              Icons.school,
                              color: Colors.blue,
                            ),
                            title: Text(
                              sem.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              'الكود: ${sem.code} | عدد الوحدات: ${sem.units.length}',
                            ),
                            trailing: _CurriculumActionMenu(
                              actions: [
                                _CurriculumAction(
                                  icon: Icons.add_circle,
                                  color: Colors.blue,
                                  label: 'إضافة وحدة',
                                  onPressed: () => _showCreateUnitDialog(sem),
                                ),
                                _CurriculumAction(
                                  icon: Icons.edit,
                                  color: Colors.indigo,
                                  label: 'تعديل الفصل الدراسي',
                                  onPressed: () => _showEditSemesterDialog(sem),
                                ),
                                _CurriculumAction(
                                  icon: Icons.delete,
                                  color: Colors.red,
                                  label: 'حذف الفصل الدراسي',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('حذف الفصل الدراسي'),
                                        content: const Text(
                                          'هل أنت متأكد من حذف هذا الفصل وجميع وحداته ودروسه؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('إلغاء'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('تأكيد الحذف'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _semesterRepo.deleteSemester(
                                        sem.id,
                                      );
                                      _loadCurriculum();
                                    }
                                  },
                                ),
                              ],
                            ),
                            children: sem.units.map((unit) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: ExpansionTile(
                                  leading: const Icon(
                                    Icons.folder,
                                    color: Colors.orange,
                                  ),
                                  title: Text(
                                    unit.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'عدد الدروس: ${unit.lessons.length}',
                                  ),
                                  trailing: _CurriculumActionMenu(
                                    actions: [
                                      _CurriculumAction(
                                        icon: Icons.add_circle_outline,
                                        color: Colors.orange,
                                        label: 'إضافة درس',
                                        onPressed: () =>
                                            _showCreateLessonDialog(unit),
                                      ),
                                      _CurriculumAction(
                                        icon: Icons.edit,
                                        color: Colors.amber.shade800,
                                        label: 'تعديل الوحدة',
                                        onPressed: () =>
                                            _showEditUnitDialog(unit),
                                      ),
                                      _CurriculumAction(
                                        icon: Icons.delete,
                                        color: Colors.red,
                                        label: 'حذف الوحدة',
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                    'حذف الوحدة',
                                                  ),
                                                  content: const Text(
                                                    'هل أنت متأكد من حذف هذه الوحدة وجميع دروسها؟',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'إلغاء',
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'تأكيد الحذف',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                          if (confirm == true) {
                                            await _unitRepo.deleteUnit(unit.id);
                                            _loadCurriculum();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  children: unit.lessons.map((lesson) {
                                    final isPublished =
                                        lesson.status == LessonStatus.published;

                                    return ExpansionTile(
                                      leading: const Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.green,
                                      ),
                                      title: Text(lesson.title),
                                      subtitle: Text(
                                        'النوع: ${_lessonTypeLabel(lesson.lessonType)} | الحالة: ${_lessonStatusLabel(lesson.status)} | المرفقات: ${lesson.resources.length}',
                                      ),
                                      trailing: _CurriculumActionMenu(
                                        actions: [
                                          _CurriculumAction(
                                            icon: Icons.draw_rounded,
                                            color: Colors.indigo,
                                            label: 'سبورة شرح الدرس التفاعلية 🎨',
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => TeacherSessionBoardScreen(
                                                    teacherId: Supabase.instance.client.auth.currentUser?.id ?? '',
                                                    groupName: _selectedSubject?.name ?? 'المادة الدراسية',
                                                    lessonTitle: lesson.title,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          _CurriculumAction(
                                            icon: Icons.attach_file,
                                            color: Colors.purple,
                                            label: 'إرفاق مذكرة / ملف PDF',
                                            onPressed: () =>
                                                _showUploadResourceDialog(
                                                  lesson,
                                                ),
                                          ),
                                          _CurriculumAction(
                                            icon: Icons.edit,
                                            color: Colors.teal,
                                            label: 'تعديل بيانات الدرس',
                                            onPressed: () =>
                                                _showEditLessonDialog(
                                                  lesson,
                                                ),
                                          ),
                                          _CurriculumAction(
                                            icon: isPublished
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: isPublished
                                                ? Colors.green
                                                : Colors.grey,
                                            label: isPublished
                                                ? 'إلغاء النشر (تحويل لمسودة)'
                                                : 'نشر للطلاب',
                                            onPressed: () async {
                                              await _lessonRepo.publishLesson(
                                                lesson.id,
                                                publish: !isPublished,
                                              );
                                              _loadCurriculum();
                                            },
                                          ),
                                          _CurriculumAction(
                                            icon: Icons.delete,
                                            color: Colors.red,
                                            label: 'حذف الدرس',
                                            onPressed: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                          title: const Text(
                                                            'حذف الدرس',
                                                          ),
                                                          content: const Text(
                                                            'هل أنت متأكد من حذف هذا الدرس؟',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    false,
                                                                  ),
                                                              child: const Text(
                                                                'إلغاء',
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    true,
                                                                  ),
                                                              child: const Text(
                                                                'تأكيد الحذف',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                    );
                                              if (confirm == true) {
                                                await _lessonRepo.deleteLesson(
                                                  lesson.id,
                                                );
                                                _loadCurriculum();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      children: lesson.resources.map((res) {
                                        final resourceFileName = res.objectPath
                                            .split('/')
                                            .last;
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.picture_as_pdf,
                                            color: Colors.red,
                                          ),
                                          title: Text(res.title),
                                          subtitle: Text(
                                            [
                                              res.bucket,
                                              resourceFileName.isEmpty
                                                  ? res.resourceType
                                                  : resourceFileName,
                                            ].join(' / '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            tooltip: 'حذف المرفق',
                                            onPressed: () =>
                                                _deleteResource(res),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }).toList(),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
