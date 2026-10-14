import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../study_workspace/data/repositories/supabase_study_workspace_repository.dart';
import '../../../study_workspace/domain/models/study_workspace_models.dart';
import '../../../study_workspace/presentation/screens/study_workspace_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_curriculum_repositories.dart';
import '../../domain/models/curriculum_models.dart';

class TeacherCurriculumScreen extends StatefulWidget {
  final String teacherId;

  const TeacherCurriculumScreen({super.key, required this.teacherId});

  @override
  State<TeacherCurriculumScreen> createState() =>
      _TeacherCurriculumScreenState();
}

class _TeacherCurriculumScreenState extends State<TeacherCurriculumScreen> {
  late final SupabaseSemesterRepository _semesterRepo;
  late final SupabaseUnitRepository _unitRepo;
  late final SupabaseLessonRepository _lessonRepo;
  late final SupabaseLessonResourceRepository _resourceRepo;
  late final SupabaseTeacherRepository _teacherRepo;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
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
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected;
      if (_selectedGroup == null) {
        selected = groups.isNotEmpty ? groups.first : null;
      } else {
        for (final group in groups) {
          if (group.id == _selectedGroup!.id) {
            selected = group;
            break;
          }
        }
      }

      if (selected == null) {
        if (!mounted) return;
        setState(() {
          _groups = groups;
          _selectedGroup = null;
          _semesters = [];
          _isLoading = false;
        });
        return;
      }

      final sList = await _semesterRepo.fetchSemestersForSubject(
        selected.subjectId,
      );
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
          _groups = groups;
          _selectedGroup = selected;
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

  Future<void> _selectGroup(GroupEntity? group) async {
    setState(() => _selectedGroup = group);
    await _loadCurriculum();
  }

  String _lessonTypeName(LessonType type) {
    switch (type) {
      case LessonType.video:
        return 'فيديو مسجل (شرح تفصيلي)';
      case LessonType.pdf:
        return 'ملزمة ومذكرة PDF';
      case LessonType.quiz:
        return 'كويز واختبار تفاعلي';
      case LessonType.programming:
        return 'تحدي وتطبيق برمجي';
      case LessonType.text:
        return 'ملاحظات وشرح كتابي';
    }
  }

  String _lessonStatusName(LessonStatus status) {
    switch (status) {
      case LessonStatus.draft:
        return 'مسودة';
      case LessonStatus.published:
        return 'منشور ومتاح للطلاب';
      case LessonStatus.archived:
        return 'مؤرشف';
    }
  }

  void _showCreateSemesterDialog() {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.school_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('إضافة ترم / فصل دراسي جديد'),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الترم أو الفصل الدراسي',
                hintText: 'مثال: الترم الأول 2026/2027',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'يرجى إدخال اسم الترم الدراسي';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(isSaving ? 'جاري الإضافة...' : 'إضافة الترم'),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      if (_selectedGroup == null) return;
                      setDialogState(() => isSaving = true);
                      final nav = Navigator.of(ctx);
                      try {
                        final sem = Semester(
                          id: '',
                          subjectId: _selectedGroup!.subjectId,
                          name: titleCtrl.text.trim(),
                          code: titleCtrl.text
                              .trim()
                              .replaceAll(' ', '_')
                              .toLowerCase(),
                          orderNumber: _semesters.length + 1,
                          status: 'active',
                          units: [],
                        );

                        await _semesterRepo.createSemester(sem);
                        nav.pop();
                        _loadCurriculum();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل إضافة الترم: $e'),
                              backgroundColor: Colors.red,
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

  void _showCreateUnitDialog(Semester semester) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.folder_open_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إضافة وحدة جديدة إلى ${semester.name}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الوحدة الدراسية',
                    hintText: 'مثال: الوحدة الأولى: الدوال والمصفوفات',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'يرجى إدخال اسم الوحدة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'وصف ومحتوى الوحدة (اختياري)',
                    hintText: 'أبرز المفاهيم التي يتم تغطيتها',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(isSaving ? 'جاري الإضافة...' : 'إضافة الوحدة'),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      if (_selectedGroup == null) return;
                      setDialogState(() => isSaving = true);
                      final nav = Navigator.of(ctx);
                      try {
                        final unit = Unit(
                          id: '',
                          semesterId: semester.id,
                          name: titleCtrl.text.trim(),
                          code: titleCtrl.text
                              .trim()
                              .replaceAll(' ', '_')
                              .toLowerCase(),
                          orderNumber: semester.units.length + 1,
                          status: 'active',
                          lessons: [],
                        );

                        await _unitRepo.createUnit(unit);
                        nav.pop();
                        _loadCurriculum();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
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
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSemesterDialog(Semester semester) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: semester.name);
    final codeCtrl = TextEditingController(text: semester.code);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل الفصل الدراسي (الترم)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الترم',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الترم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'كود الترم',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'يرجى إدخال كود الترم' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final nav = Navigator.of(ctx);
                      try {
                        await _semesterRepo.updateSemester(
                          Semester(
                            id: semester.id,
                            subjectId: semester.subjectId,
                            name: titleCtrl.text.trim(),
                            code: codeCtrl.text.trim(),
                            orderNumber: semester.orderNumber,
                            startDate: semester.startDate,
                            endDate: semester.endDate,
                            status: semester.status,
                            units: semester.units,
                          ),
                        );
                        nav.pop();
                        _loadCurriculum();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل التحديث: $e')),
                        );
                      }
                    },
              child: Text(isSaving ? 'جاري الحفظ...' : 'حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUnitDialog(Unit unit) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: unit.name);
    final codeCtrl = TextEditingController(text: unit.code);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل بيانات الوحدة'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الوحدة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الوحدة' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'كود الوحدة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'يرجى إدخال كود الوحدة' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final nav = Navigator.of(ctx);
                      try {
                        await _unitRepo.updateUnit(
                          Unit(
                            id: unit.id,
                            semesterId: unit.semesterId,
                            name: titleCtrl.text.trim(),
                            code: codeCtrl.text.trim(),
                            orderNumber: unit.orderNumber,
                            status: unit.status,
                            lessons: unit.lessons,
                          ),
                        );
                        nav.pop();
                        _loadCurriculum();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل التحديث: $e')),
                        );
                      }
                    },
              child: Text(isSaving ? 'جاري الحفظ...' : 'حفظ التعديل'),
            ),
          ],
        ),
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
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل الحصة / الدرس'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الحصة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان الحصة' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: lessonTypeStr,
                  decoration: const InputDecoration(
                    labelText: 'نوع المحتوى',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'video', child: Text('فيديو مسجل (شرح)')),
                    DropdownMenuItem(value: 'pdf', child: Text('ملزمة ومذكرة PDF')),
                    DropdownMenuItem(value: 'text', child: Text('ملاحظات وشرح كتابي')),
                    DropdownMenuItem(value: 'programming', child: Text('تحدي وتطبيق برمجي')),
                    DropdownMenuItem(value: 'quiz', child: Text('كويز واختبار تفاعلي')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => lessonTypeStr = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'مدة الشرح المتوقعة (بالدقائق)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'يرجى تحديد المدة';
                    }
                    final d = int.tryParse(v.trim());
                    if (d == null || d <= 0) {
                      return 'يرجى إدخال رقم صحيح أكبر من 0';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final nav = Navigator.of(ctx);
                      try {
                        await _lessonRepo.updateLesson(
                          Lesson(
                            id: lesson.id,
                            unitId: lesson.unitId,
                            title: titleCtrl.text.trim(),
                            lessonType: LessonType.fromString(lessonTypeStr),
                            orderNumber: lesson.orderNumber,
                            status: lesson.status,
                            publishedAt: lesson.publishedAt,
                            estimatedDurationMinutes: int.tryParse(
                              durationCtrl.text.trim(),
                            ),
                            resources: lesson.resources,
                          ),
                        );
                        nav.pop();
                        _loadCurriculum();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل التحديث: $e')),
                        );
                      }
                    },
              child: Text(isSaving ? 'جاري الحفظ...' : 'حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditResourceDialog(LessonResource resource) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: resource.title);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل اسم المورد / الملزمة'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الملف / الملزمة',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المورد' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final nav = Navigator.of(ctx);
                      try {
                        await _resourceRepo.updateResource(
                          LessonResource(
                            id: resource.id,
                            lessonId: resource.lessonId,
                            resourceType: resource.resourceType,
                            title: titleCtrl.text.trim(),
                            bucket: resource.bucket,
                            objectPath: resource.objectPath,
                            orderNumber: resource.orderNumber,
                          ),
                        );
                        nav.pop();
                        _loadCurriculum();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل التحديث: $e')),
                        );
                      }
                    },
              child: Text(isSaving ? 'جاري الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(String title, String message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  void _showCreateLessonDialog(Unit unit) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '45');
    String lessonTypeStr = 'video';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.play_circle_outline_rounded, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'إضافة حصة جديدة في ${unit.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الحصة أو الدرس',
                      hintText: 'مثال: الحصة الأولى - الشرح التمهيدي',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'يرجى إدخال عنوان الحصة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: lessonTypeStr,
                    decoration: const InputDecoration(
                      labelText: 'نوع المحتوى الرئيسي',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'video',
                        child: Text('فيديو مسجل (شرح تفصيلي)'),
                      ),
                      DropdownMenuItem(
                        value: 'pdf',
                        child: Text('ملزمة ومذكرة PDF'),
                      ),
                      DropdownMenuItem(
                        value: 'quiz',
                        child: Text('كويز واختبار تفاعلي'),
                      ),
                      DropdownMenuItem(
                        value: 'programming',
                        child: Text('تحدي وتطبيق برمجي'),
                      ),
                      DropdownMenuItem(
                        value: 'text',
                        child: Text('ملاحظات وشرح كتابي'),
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
                      labelText: 'مدة الشرح المتوقعة (بالدقائق)',
                      hintText: 'مثال: 45',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'يرجى تحديد المدة';
                      }
                      final d = int.tryParse(v.trim());
                      if (d == null || d <= 0) {
                        return 'يرجى إدخال رقم صحيح أكبر من 0';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(isSaving ? 'جاري الإنشاء...' : 'إنشاء الحصة'),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setStateDialog(() => isSaving = true);
                        final nav = Navigator.of(ctx);
                        try {
                          final newLesson = Lesson(
                            id: '',
                            unitId: unit.id,
                            title: titleCtrl.text.trim(),
                            lessonType: LessonType.fromString(lessonTypeStr),
                            orderNumber: unit.lessons.length + 1,
                            status: LessonStatus.draft,
                            estimatedDurationMinutes:
                                int.tryParse(durationCtrl.text.trim()) ?? 45,
                          );

                          await _lessonRepo.createLesson(newLesson);
                          nav.pop();
                          _loadCurriculum();
                        } catch (e) {
                          setStateDialog(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل إنشاء الحصة: $e'),
                                backgroundColor: Colors.red,
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

  void _showUploadResourceDialog(Lesson lesson) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(
      text: 'شيت ملزمة ${lesson.title}',
    );
    XFile? selectedFile;
    bool isUploading = false;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'رفع ملزمة PDF (${lesson.title})',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الشيت أو الملزمة',
                    hintText: 'مثال: ملخص الدرس وأسئلة الواجب',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'يرجى كتابة عنوان الملزمة' : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final file = await openFile(
                            acceptedTypeGroups: const [
                              XTypeGroup(
                                label: 'PDF',
                                extensions: ['pdf'],
                                mimeTypes: ['application/pdf'],
                              ),
                            ],
                          );
                          if (file == null) return;
                          setDialogState(() {
                            selectedFile = file;
                            if (titleCtrl.text.trim().isEmpty) {
                              titleCtrl.text = file.name;
                            }
                          });
                        },
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('اختر ملف PDF من الجهاز'),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedFile == null
                      ? 'لم يتم اختيار ملف PDF بعد'
                      : 'الملف المختار: ${selectedFile!.name}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedFile == null ? Colors.grey : AppColors.primary,
                    fontWeight: selectedFile == null ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                if (isUploading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.cloud_upload_rounded),
              label: Text(isUploading ? 'جاري الرفع والإرفاق...' : 'رفع وإرفاق بالحصة'),
              onPressed: isUploading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final file = selectedFile;
                      if (file == null) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('يرجى اختيار ملف PDF أولاً من جهازك.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final nav = Navigator.of(ctx);
                      bool popped = false;
                      try {
                        setDialogState(() => isUploading = true);

                        final bytes = await file.readAsBytes();
                        final ext = file.name.split('.').last;
                        final objectPath =
                            'lessons/${lesson.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

                        await Supabase.instance.client.storage
                            .from('curriculum_assets')
                            .uploadBinary(
                              objectPath,
                              bytes,
                              fileOptions: const FileOptions(
                                contentType: 'application/pdf',
                                upsert: true,
                              ),
                            );

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
                        popped = true;
                        await _loadCurriculum();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('تم رفع وإرفاق ملزمة PDF بنجاح! 📄'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!popped) {
                          setDialogState(() => isUploading = false);
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('فشل الرفع: $e'),
                              backgroundColor: Colors.red,
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

  void _showCodeChallengesDialog(Lesson lesson) {
    showDialog(
      context: context,
      builder: (_) => _LessonCodeChallengeDialog(lesson: lesson),
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

    return RefreshIndicator(
      onRefresh: _loadCurriculum,
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
                          'حدث خطأ: $_errorMessage',
                          style: AppTypography.bodyMedium(AppColors.error),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadCurriculum,
                          child: Text(
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
          : _semesters.isEmpty
          ? Stack(
              children: [
                Column(
                  children: [
                    _GroupPicker(
                      groups: _groups,
                      selectedGroup: _selectedGroup,
                      onChanged: _selectGroup,
                    ),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverFillRemaining(
                            child: Center(
                              child: Text(
                                'لا توجد فصول دراسية (تيرمات) مسجلة لمادتك حتى الآن. يمكنك إضافة تيرم جديد للبدء.',
                                style: AppTypography.bodyMedium(subtitleColor),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_selectedGroup != null)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.extended(
                      onPressed: _showCreateSemesterDialog,
                      backgroundColor: AppColors.primary,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'إضافة ترم / فصل دراسي جديد',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            )
          : Column(
              children: [
                _GroupPicker(
                  groups: _groups,
                  selectedGroup: _selectedGroup,
                  onChanged: _selectGroup,
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _semesters.length,
                    itemBuilder: (ctx, semIdx) {
                      final sem = _semesters[semIdx];
                      return FadeInSlide(
                        delay: Duration(milliseconds: 50 * semIdx),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GlassCard(
                            color: surfaceColor,
                            padding: EdgeInsets.zero,
                            child: ExpansionTile(
                              leading: const CircleIcon(
                                icon: Icons.school_rounded,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                sem.name,
                                style: AppTypography.titleMedium(textColor).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'الكود: ${sem.code} | الوحدات: ${sem.units.length} وحدة',
                                style: AppTypography.bodySmall(subtitleColor),
                              ),
                              trailing: _CurriculumActionMenu(
                                actions: [
                                  _CurriculumAction(
                                    icon: Icons.edit_rounded,
                                    label: 'تعديل الترم',
                                    onPressed: () =>
                                        _showEditSemesterDialog(sem),
                                  ),
                                  _CurriculumAction(
                                    icon: Icons.add_circle_outline_rounded,
                                    color: AppColors.primary,
                                    label: 'إضافة وحدة دراسية',
                                    onPressed: () => _showCreateUnitDialog(sem),
                                  ),
                                  _CurriculumAction(
                                    icon: Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    label: 'حذف الترم بالكامل',
                                    onPressed: () async {
                                      if (!await _confirmDelete(
                                        'حذف الترم الدراسي',
                                        'هل أنت متأكد من حذف ${sem.name} وكافة الوحدات والحصص التابعة له؟',
                                      )) {
                                        return;
                                      }
                                      await _semesterRepo.deleteSemester(
                                        sem.id,
                                      );
                                      _loadCurriculum();
                                    },
                                  ),
                                ],
                              ),
                              children: sem.units.map((unit) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: ExpansionTile(
                                    leading: const CircleIcon(
                                      icon: Icons.folder_rounded,
                                      color: AppColors.warning,
                                    ),
                                    title: Text(
                                      unit.name,
                                      style: AppTypography.titleSmall(
                                        textColor,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'الحصص: ${unit.lessons.length} حصة',
                                      style: AppTypography.bodySmall(
                                        subtitleColor,
                                      ),
                                    ),
                                    trailing: _CurriculumActionMenu(
                                      actions: [
                                        _CurriculumAction(
                                          icon: Icons.edit_rounded,
                                          label: 'تعديل الوحدة',
                                          onPressed: () =>
                                              _showEditUnitDialog(unit),
                                        ),
                                        _CurriculumAction(
                                          icon: Icons.add_circle_outline_rounded,
                                          color: AppColors.warning,
                                          label: 'إضافة حصة / درس',
                                          onPressed: () =>
                                              _showCreateLessonDialog(unit),
                                        ),
                                        _CurriculumAction(
                                          icon: Icons.delete_outline_rounded,
                                          color: AppColors.error,
                                          label: 'حذف الوحدة',
                                          onPressed: () async {
                                            if (!await _confirmDelete(
                                              'حذف الوحدة الدراسية',
                                              'هل أنت متأكد من حذف ${unit.name} وكافة الحصص التابعة لها؟',
                                            )) {
                                              return;
                                            }
                                            await _unitRepo.deleteUnit(unit.id);
                                            _loadCurriculum();
                                          },
                                        ),
                                      ],
                                    ),
                                    children: unit.lessons.map((lesson) {
                                      final isPublished =
                                          lesson.status ==
                                          LessonStatus.published;

                                      return ExpansionTile(
                                        leading: const CircleIcon(
                                          icon: Icons.play_circle_outline_rounded,
                                          color: AppColors.success,
                                        ),
                                        title: Text(
                                          lesson.title,
                                          style: AppTypography.bodyLarge(
                                            textColor,
                                          ).copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'النوع: ${_lessonTypeName(lesson.lessonType)} | الحالة: ${_lessonStatusName(lesson.status)} | المدة: ${lesson.estimatedDurationMinutes ?? 45} دقيقة',
                                              style: AppTypography.bodySmall(
                                                subtitleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            ActionChip(
                                              avatar: const Icon(
                                                Icons.draw_rounded,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                              label: const Text(
                                                'سبورة شرح الدرس 🎨',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: () => _openLessonBoard(unit, lesson),
                                            ),
                                          ],
                                        ),
                                        trailing: _CurriculumActionMenu(
                                          actions: [
                                            _CurriculumAction(
                                              icon: Icons.draw_rounded,
                                              color: AppColors.primary,
                                              label: 'سبورة شرح الدرس',
                                              onPressed: () =>
                                                  _openLessonBoard(unit, lesson),
                                            ),
                                            _CurriculumAction(
                                              icon: Icons.edit_rounded,
                                              label: 'تعديل الحصة',
                                              onPressed: () =>
                                                  _showEditLessonDialog(lesson),
                                            ),
                                            _CurriculumAction(
                                              icon: Icons.attach_file_rounded,
                                              color: AppColors.purple,
                                              label: 'رفع ملزمة / مذكرة PDF',
                                              onPressed: () =>
                                                  _showUploadResourceDialog(
                                                    lesson,
                                                  ),
                                            ),
                                            _CurriculumAction(
                                              icon: Icons.code_rounded,
                                              color: AppColors.info,
                                              label: 'التحديات البرمجية',
                                              onPressed: () =>
                                                  _showCodeChallengesDialog(
                                                    lesson,
                                                  ),
                                            ),
                                            _CurriculumAction(
                                              icon: isPublished
                                                  ? Icons.visibility_rounded
                                                  : Icons.visibility_off_rounded,
                                              color: isPublished
                                                  ? AppColors.success
                                                  : AppColors.darkTextSecondary,
                                              label: isPublished ? 'إلغاء النشر (تحويل لمسودة)' : 'نشر الحصة للطلاب',
                                              onPressed: () async {
                                                await _lessonRepo.publishLesson(
                                                  lesson.id,
                                                  publish: !isPublished,
                                                );
                                                _loadCurriculum();
                                              },
                                            ),
                                            _CurriculumAction(
                                              icon: Icons.delete_outline_rounded,
                                              color: AppColors.error,
                                              label: 'حذف الحصة بالكامل',
                                              onPressed: () async {
                                                if (!await _confirmDelete(
                                                  'حذف الحصة',
                                                  'هل تريد حذف ${lesson.title} ومرفقاتها؟',
                                                )) {
                                                  return;
                                                }
                                                await _lessonRepo.deleteLesson(
                                                  lesson.id,
                                                );
                                                _loadCurriculum();
                                              },
                                            ),
                                          ],
                                        ),
                                        children: lesson.resources.map((res) {
                                          final resourceFileName = res
                                              .objectPath
                                              .split('/')
                                              .last;
                                          return Material(
                                            type: MaterialType.transparency,
                                            child: ListTile(
                                              leading: const Icon(
                                                Icons.picture_as_pdf_rounded,
                                                color: AppColors.error,
                                              ),
                                              title: Text(
                                                res.title,
                                                style: AppTypography.bodyMedium(
                                                  textColor,
                                                ),
                                              ),
                                              subtitle: Text(
                                                [
                                                  'ملزمة مرفقة',
                                                  resourceFileName.isEmpty
                                                      ? res.resourceType
                                                      : resourceFileName,
                                                ].join(' • '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.bodySmall(
                                                  subtitleColor,
                                                ),
                                              ),
                                              trailing: Wrap(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit_rounded,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _showEditResourceDialog(
                                                          res,
                                                        ),
                                                    tooltip: 'تعديل اسم المورد',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline_rounded,
                                                      color: AppColors.error,
                                                      size: 20,
                                                    ),
                                                    onPressed: () async {
                                                      if (!await _confirmDelete(
                                                        'حذف الملف المرفق',
                                                        'هل أنت متأكد من حذف ${res.title}؟',
                                                      )) {
                                                        return;
                                                      }
                                                      await _resourceRepo
                                                          .deleteResource(
                                                            res.id,
                                                          );
                                                      _loadCurriculum();
                                                    },
                                                    tooltip: 'حذف الملف',
                                                  ),
                                                ],
                                              ),
                                              onTap: () async {
                                                if (res.resourceType == 'pdf') {
                                                  final url = await Supabase
                                                      .instance
                                                      .client
                                                      .storage
                                                      .from(res.bucket)
                                                      .createSignedUrl(
                                                        res.objectPath,
                                                        3600,
                                                      );
                                                  if (!context.mounted) return;
                                                  final summary =
                                                      StudyLessonSummary(
                                                        id: lesson.id,
                                                        title: lesson.title,
                                                        pathName: 'Curriculum',
                                                        unitName: unit.name,
                                                        progressPercentage: 0,
                                                        estimatedMinutes: 30,
                                                        lastPage: 1,
                                                        totalPages: 0,
                                                        xp: 0,
                                                        hasPdf: true,
                                                        hasCodePlayground:
                                                            false,
                                                        pdfUrl: url,
                                                      );
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          StudyWorkspaceScreen(
                                                            lesson: summary,
                                                            teacherId: widget
                                                                .teacherId,
                                                            repository:
                                                                SupabaseStudyWorkspaceRepository(
                                                                  GetIt.I<
                                                                    SupabaseClientWrapper
                                                                  >(),
                                                                ),
                                                          ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openLessonBoard(Unit unit, Lesson lesson) async {
    String? pdfUrl;
    final pdfResource =
        lesson.resources.where((r) => r.resourceType == 'pdf').firstOrNull;
    if (pdfResource != null) {
      try {
        pdfUrl = await Supabase.instance.client.storage
            .from(pdfResource.bucket)
            .createSignedUrl(pdfResource.objectPath, 3600);
      } catch (_) {}
    }

    if (!mounted) return;
    final summary = StudyLessonSummary(
      id: lesson.id,
      title: lesson.title,
      pathName: 'المنهج الدراسي',
      unitName: unit.name,
      progressPercentage: 0,
      estimatedMinutes: lesson.estimatedDurationMinutes ?? 45,
      lastPage: 1,
      totalPages: 0,
      xp: 0,
      hasPdf: pdfUrl != null,
      hasCodePlayground: false,
      pdfUrl: pdfUrl,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudyWorkspaceScreen(
          lesson: summary,
          teacherId: widget.teacherId,
          repository: SupabaseStudyWorkspaceRepository(
            GetIt.I<SupabaseClientWrapper>(),
          ),
        ),
      ),
    );
  }
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
      tooltip: context.tr('Actions'),
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

class _LessonCodeChallengeDialog extends StatefulWidget {
  final Lesson lesson;

  const _LessonCodeChallengeDialog({required this.lesson});

  @override
  State<_LessonCodeChallengeDialog> createState() =>
      _LessonCodeChallengeDialogState();
}

class _LessonCodeChallengeDialogState
    extends State<_LessonCodeChallengeDialog> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _xpCtrl = TextEditingController(text: '50');
  final List<_ChallengeCaseDraft> _caseDrafts = [_ChallengeCaseDraft()];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String _difficulty = 'medium';
  String _status = 'published';
  List<_TeacherCodeChallenge> _challenges = [];

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _xpCtrl.dispose();
    for (final draft in _caseDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rows = await Supabase.instance.client.rpc(
        'get_teacher_lesson_code_challenges',
        params: {'p_lesson_id': widget.lesson.id},
      );
      if (!mounted) return;
      setState(() {
        _challenges = (rows as List)
            .whereType<Map>()
            .map(_TeacherCodeChallenge.fromJson)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createChallenge() async {
    final title = _titleCtrl.text.trim();
    final validCases = _caseDrafts
        .where((draft) => draft.expectedCtrl.text.trim().isNotEmpty)
        .toList();
    if (title.isEmpty || validCases.isEmpty) {
      setState(() {
        _errorMessage =
            'Challenge title and at least one expected output are required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.rpc(
        'create_code_challenge_with_cases',
        params: {
          'p_lesson_id': widget.lesson.id,
          'p_title': title,
          'p_description': _descriptionCtrl.text.trim(),
          'p_difficulty': _difficulty,
          'p_xp_reward': int.tryParse(_xpCtrl.text.trim()) ?? 50,
          'p_status': _status,
          'p_test_cases': validCases
              .asMap()
              .entries
              .map(
                (entry) => {
                  'name': entry.value.nameCtrl.text.trim().isEmpty
                      ? 'Case ${entry.key + 1}'
                      : entry.value.nameCtrl.text.trim(),
                  'stdin': entry.value.stdinCtrl.text,
                  'expected_stdout': entry.value.expectedCtrl.text,
                  'is_hidden': entry.value.isHidden,
                },
              )
              .toList(),
        },
      );

      _titleCtrl.clear();
      _descriptionCtrl.clear();
      _xpCtrl.text = '50';
      for (final draft in _caseDrafts) {
        draft.dispose();
      }
      _caseDrafts
        ..clear()
        ..add(_ChallengeCaseDraft());
      _difficulty = 'medium';
      _status = 'published';
      await _loadChallenges();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeStatus(
    _TeacherCodeChallenge challenge,
    String status,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'update_code_challenge_status',
        params: {'p_challenge_id': challenge.id, 'p_status': status},
      );
      await _loadChallenges();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.code_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'التحديات البرمجية - ${widget.lesson.title}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'تظهر التحديات المنشورة مباشرة للطلاب في المختبر البرمجي لحلها واختبارها.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث القائمة',
                    onPressed: _isLoading ? null : _loadChallenges,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const LinearProgressIndicator()
              else if (_challenges.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('لا توجد تحديات برمجية مضافة لهذه الحصة حتى الآن.'),
                )
              else
                ..._challenges.map(
                  (challenge) => Card(
                    child: ListTile(
                      leading: Icon(
                        challenge.status == 'published'
                            ? Icons.verified
                            : Icons.pending_outlined,
                        color: challenge.status == 'published'
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: Text(challenge.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'الصعوبة: ${challenge.difficulty == 'easy' ? 'سهل' : challenge.difficulty == 'medium' ? 'متوسط' : 'صعب'} | ${challenge.xpReward} نقطة XP | '
                        '${challenge.testCaseCount} حالات اختبار | '
                        '${challenge.passedCount}/${challenge.attemptsCount} اجتازوا التحدي',
                      ),
                      trailing: DropdownButton<String>(
                        value: challenge.status,
                        items: const [
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text('مسودة'),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('منشور'),
                          ),
                          DropdownMenuItem(
                            value: 'archived',
                            child: Text('مؤرشف'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null || value == challenge.status) {
                            return;
                          }
                          _changeStatus(challenge, value);
                        },
                      ),
                    ),
                  ),
                ),
              const Divider(height: 28),
              const Text(
                'إضافة تحدي برمجي جديد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'عنوان التحدي البرمجي',
                  hintText: 'مثال: جمع عددين صحيحين',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'شرح ومسألة التحدي البرمجي بالتفصيل',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'مستوى الصعوبة',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'easy',
                          child: Text('سهل'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('متوسط'),
                        ),
                        DropdownMenuItem(
                          value: 'hard',
                          child: Text('صعب'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _difficulty = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _xpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مكافأة XP',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'حالة التحدي',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('مسودة'),
                        ),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('منشور ومتاح'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('حالات الاختبار والتحقق (Test Cases):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (var i = 0; i < _caseDrafts.length; i++)
                _ChallengeCaseEditor(
                  index: i,
                  draft: _caseDrafts[i],
                  canRemove: _caseDrafts.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () {
                    setState(() {
                      final removed = _caseDrafts.removeAt(i);
                      removed.dispose();
                    });
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _caseDrafts.add(_ChallengeCaseDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة حالة اختبار أخرى'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _createChallenge,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ التحدي البرمجي'),
        ),
      ],
    );
  }
}

class _ChallengeCaseEditor extends StatelessWidget {
  final int index;
  final _ChallengeCaseDraft draft;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ChallengeCaseEditor({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'حالة الاختبار رقم ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Checkbox(
                  value: draft.isHidden,
                  onChanged: (value) {
                    draft.isHidden = value ?? false;
                    onChanged();
                  },
                ),
                const Text('مخفية عن الطالب'),
                IconButton(
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                ),
              ],
            ),
            TextField(
              controller: draft.nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم الحالة (اختياري)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.stdinCtrl,
              decoration: const InputDecoration(
                labelText: 'المدخلات (Input Stdin)',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.expectedCtrl,
              decoration: const InputDecoration(
                labelText: 'المخرجات المتوقعة (Expected Output)',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCaseDraft {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController stdinCtrl = TextEditingController();
  final TextEditingController expectedCtrl = TextEditingController();
  bool isHidden = false;

  void dispose() {
    nameCtrl.dispose();
    stdinCtrl.dispose();
    expectedCtrl.dispose();
  }
}

class _TeacherCodeChallenge {
  final String id;
  final String title;
  final String difficulty;
  final int xpReward;
  final String status;
  final int testCaseCount;
  final int attemptsCount;
  final int passedCount;

  const _TeacherCodeChallenge({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.xpReward,
    required this.status,
    required this.testCaseCount,
    required this.attemptsCount,
    required this.passedCount,
  });

  factory _TeacherCodeChallenge.fromJson(Map<dynamic, dynamic> json) {
    final testCases = json['test_cases'];
    return _TeacherCodeChallenge(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Challenge',
      difficulty: json['difficulty']?.toString() ?? 'medium',
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'draft',
      testCaseCount: testCases is List ? testCases.length : 0,
      attemptsCount: (json['attempts_count'] as num?)?.toInt() ?? 0,
      passedCount: (json['passed_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class _GroupPicker extends StatelessWidget {
  final List<GroupEntity> groups;
  final GroupEntity? selectedGroup;
  final ValueChanged<GroupEntity?> onChanged;

  const _GroupPicker({
    required this.groups,
    required this.selectedGroup,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<GroupEntity>(
        initialValue: selectedGroup,
        decoration: const InputDecoration(
          labelText: 'المجموعة الدراسية المسندة',
          border: OutlineInputBorder(),
        ),
        items: groups
            .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
            .toList(),
        onChanged: groups.isEmpty ? null : onChanged,
      ),
    );
  }
}
