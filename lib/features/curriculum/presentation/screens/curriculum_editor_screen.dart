import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../../attendance/presentation/screens/teacher_session_board_screen.dart';
import '../../data/repositories/supabase_curriculum_repositories.dart';
import '../../domain/models/curriculum_models.dart';

class CurriculumEditorScreen extends StatefulWidget {
  const CurriculumEditorScreen({super.key});

  @override
  State<CurriculumEditorScreen> createState() => _CurriculumEditorScreenState();
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

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'published', 'draft', 'has_resources'

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final semIds = sList.map((s) => s.id).toList();
      final List<Semester> populatedSemesters = [];

      if (semIds.isNotEmpty) {
        try {
          final unitsRes = await Supabase.instance.client
              .from('units')
              .select()
              .inFilter('semester_id', semIds)
              .order('order_number');

          final rawUnits = (unitsRes as List)
              .map((u) => Unit.fromJson(Map<String, dynamic>.from(u as Map)))
              .toList();

          final unitIds = rawUnits.map((u) => u.id).toList();
          final Map<String, List<Lesson>> lessonsByUnit = {
            for (final u in rawUnits) u.id: <Lesson>[],
          };

          if (unitIds.isNotEmpty) {
            try {
              final lessonsRes = await Supabase.instance.client
                  .from('lessons')
                  .select()
                  .inFilter('unit_id', unitIds)
                  .order('order_number');

              final rawLessons = (lessonsRes as List)
                  .map((l) => Lesson.fromJson(Map<String, dynamic>.from(l as Map)))
                  .toList();

              final lessonIds = rawLessons.map((l) => l.id).toList();
              final Map<String, List<LessonResource>> resourcesByLesson = {
                for (final l in rawLessons) l.id: <LessonResource>[],
              };

              if (lessonIds.isNotEmpty) {
                try {
                  final resourcesRes = await Supabase.instance.client
                      .from('lesson_resources')
                      .select()
                      .inFilter('lesson_id', lessonIds)
                      .order('order_number');

                  for (final r in resourcesRes as List) {
                    final res = LessonResource.fromJson(Map<String, dynamic>.from(r as Map));
                    resourcesByLesson[res.lessonId]?.add(res);
                  }
                } catch (_) {}
              }

              for (final l in rawLessons) {
                final populatedLesson = Lesson(
                  id: l.id,
                  unitId: l.unitId,
                  title: l.title,
                  lessonType: l.lessonType,
                  orderNumber: l.orderNumber,
                  status: l.status,
                  publishedAt: l.publishedAt,
                  estimatedDurationMinutes: l.estimatedDurationMinutes,
                  resources: resourcesByLesson[l.id] ?? [],
                );
                lessonsByUnit[l.unitId]?.add(populatedLesson);
              }
            } catch (_) {}
          }

          final Map<String, List<Unit>> unitsBySem = {
            for (final s in sList) s.id: <Unit>[],
          };

          for (final u in rawUnits) {
            final populated = Unit(
              id: u.id,
              semesterId: u.semesterId,
              name: u.name,
              code: u.code,
              orderNumber: u.orderNumber,
              status: u.status,
              lessons: lessonsByUnit[u.id] ?? [],
            );
            unitsBySem[u.semesterId]?.add(populated);
          }

          for (final sem in sList) {
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
                units: unitsBySem[sem.id] ?? [],
              ),
            );
          }
        } catch (_) {
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
        }
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
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: AppColors.primary),
            SizedBox(width: 8),
            Text('إضافة فصل دراسي جديد'),
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
                      labelText: 'اسم الفصل الدراسي (مثال: الفصل الدراسي الأول)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الفصل الدراسي' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'كود الفصل (مثال: TERM-1)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الفصل' : null,
                  ),
                ],
              ),
            ),
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
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.indigo),
            SizedBox(width: 8),
            Text('تعديل الفصل الدراسي'),
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
                      labelText: 'اسم الفصل الدراسي',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الفصل' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'كود الفصل',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الفصل' : null,
                  ),
                ],
              ),
            ),
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
        title: Row(
          children: [
            const Icon(Icons.create_new_folder, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('إضافة وحدة في ${semester.name}', overflow: TextOverflow.ellipsis)),
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
                      labelText: 'اسم الوحدة (مثال: الوحدة الأولى: الحركة والقوى)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الوحدة' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'كود الوحدة (مثال: U1)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الوحدة' : null,
                  ),
                ],
              ),
            ),
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
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.orange),
            SizedBox(width: 8),
            Text('تعديل الوحدة الدراسية'),
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
                      labelText: 'اسم الوحدة',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الوحدة' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'كود الوحدة',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الوحدة' : null,
                  ),
                ],
              ),
            ),
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
            title: Row(
              children: [
                const Icon(Icons.post_add, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text('إضافة درس في ${unit.name}', overflow: TextOverflow.ellipsis)),
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
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الدرس',
                          hintText: 'مثال: شرح قانون أوم والدائرة الكهربية',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال عنوان الدرس' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: lessonTypeStr,
                        decoration: const InputDecoration(
                          labelText: 'نوع الدرس والمحتوى',
                          border: OutlineInputBorder(),
                        ),
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
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
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
            title: const Row(
              children: [
                Icon(Icons.edit, color: Colors.teal),
                SizedBox(width: 8),
                Text('تعديل بيانات الدرس'),
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
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الدرس',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال عنوان الدرس' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: lessonTypeStr,
                        decoration: const InputDecoration(
                          labelText: 'نوع المحتوى',
                          border: OutlineInputBorder(),
                        ),
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
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
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
    final titleCtrl = TextEditingController(text: 'مذكرة ${lesson.title}');
    final objectPathCtrl = TextEditingController(text: 'lessons/${lesson.id}/');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(child: Text('إرفاق مذكرة / ملف PDF (${lesson.title})', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الملف أو المذكرة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: objectPathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'مسار التخزين (Object Path)',
                    hintText: 'lessons/<lesson-id>/lecture.pdf',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
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
              if (titleCtrl.text.trim().isEmpty || objectPathCtrl.text.trim().isEmpty) return;
              final nav = Navigator.of(ctx);
              try {
                final res = LessonResource(
                  id: '',
                  lessonId: lesson.id,
                  title: titleCtrl.text.trim(),
                  resourceType: 'pdf',
                  bucket: 'curriculum_assets',
                  objectPath: objectPathCtrl.text.trim(),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
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
      LessonType.programming => 'تطبيق برمجي',
    };
  }

  IconData _lessonTypeIcon(LessonType type) {
    return switch (type) {
      LessonType.video => Icons.play_circle_filled_rounded,
      LessonType.pdf => Icons.picture_as_pdf_rounded,
      LessonType.quiz => Icons.quiz_rounded,
      LessonType.text => Icons.article_rounded,
      LessonType.programming => Icons.code_rounded,
    };
  }

  Color _lessonTypeColor(LessonType type) {
    return switch (type) {
      LessonType.video => Colors.red,
      LessonType.pdf => Colors.deepOrange,
      LessonType.quiz => Colors.purple,
      LessonType.text => Colors.blue,
      LessonType.programming => Colors.teal,
    };
  }

  Widget _buildKpiSection(
    bool isDark,
    int totalSemesters,
    int totalUnits,
    int totalLessons,
    int totalResources,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final kpiCards = [
          _buildKpiCard(
            title: 'الفصول الدراسية',
            value: '$totalSemesters',
            icon: Icons.calendar_month_rounded,
            color: Colors.blue,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'الوحدات التعليمية',
            value: '$totalUnits',
            icon: Icons.folder_copy_rounded,
            color: Colors.orange,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'إجمالي الدروس',
            value: '$totalLessons',
            icon: Icons.menu_book_rounded,
            color: Colors.green,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'المذكرات والمرفقات',
            value: '$totalResources',
            icon: Icons.attach_file_rounded,
            color: Colors.purple,
            isDark: isDark,
          ),
        ];

        if (isNarrow) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: kpiCards,
          );
        }

        return Row(
          children: kpiCards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: card,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
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
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
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

  Widget _buildSubjectAndFilterBar(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        final subjectSelector = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : Colors.black12, width: 0.8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SubjectEntity>(
              value: _selectedSubject,
              isExpanded: true,
              hint: const Text('اختر المادة الدراسية...'),
              items: _subjects
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          const Icon(Icons.book_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s.name} (${s.code})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
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
        );

        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'بحث في عناوين الفصول، الوحدات والدروس...',
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
              borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.white,
          ),
        );

        final filterChips = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusFilterChip('all', 'جميع الدروس', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('published', 'المنشور فقط', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('draft', 'المسودات', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('has_resources', 'بها مذكرات PDF', isDark),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              subjectSelector,
              const SizedBox(height: 8),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(flex: 2, child: subjectSelector),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: searchField),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: filterChips,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.primary
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildSemesterCard(BuildContext context, Semester sem, bool isDark) {
    final q = _searchController.text.toLowerCase().trim();

    final filteredUnits = sem.units.where((unit) {
      if (q.isEmpty && _selectedFilter == 'all') return true;

      final unitMatches = unit.name.toLowerCase().contains(q) || unit.code.toLowerCase().contains(q);
      final hasMatchingLessons = unit.lessons.any((lesson) {
        final matchesQuery = q.isEmpty || lesson.title.toLowerCase().contains(q);
        if (!matchesQuery) return false;

        if (_selectedFilter == 'published' && lesson.status != LessonStatus.published) return false;
        if (_selectedFilter == 'draft' && lesson.status != LessonStatus.draft) return false;
        if (_selectedFilter == 'has_resources' && lesson.resources.isEmpty) return false;

        return true;
      });

      return unitMatches || hasMatchingLessons;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.blue, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  sem.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sem.code,
                  style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  '${sem.units.length} وحدات تعليمية',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const Text('•', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  '${sem.units.fold<int>(0, (sum, u) => sum + u.lessons.length)} درساً',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'إضافة وحدة',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.orange, size: 20),
                onPressed: () => _showCreateUnitDialog(sem),
              ),
              IconButton(
                tooltip: 'تعديل الفصل',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 19),
                onPressed: () => _showEditSemesterDialog(sem),
              ),
              IconButton(
                tooltip: 'حذف الفصل',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 19),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف الفصل الدراسي'),
                      content: Text('هل أنت متأكد من حذف الفصل "${sem.name}" وجميع وحداته ودروسه نهائياً؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('تأكيد الحذف'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _semesterRepo.deleteSemester(sem.id);
                    _loadCurriculum();
                  }
                },
              ),
            ],
          ),
          children: [
            if (filteredUnits.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    q.isNotEmpty ? 'لا توجد وحدات تطابق بحثك في هذا الفصل' : 'لا توجد وحدات تعليمية مضافة في هذا الفصل.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                child: Column(
                  children: filteredUnits
                      .map((unit) => _buildUnitCard(context, unit, isDark))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildUnitCard(BuildContext context, Unit unit, bool isDark) {
    final q = _searchController.text.toLowerCase().trim();

    final filteredLessons = unit.lessons.where((lesson) {
      final matchesQuery = q.isEmpty || lesson.title.toLowerCase().contains(q);
      if (!matchesQuery) return false;

      if (_selectedFilter == 'published' && lesson.status != LessonStatus.published) return false;
      if (_selectedFilter == 'draft' && lesson.status != LessonStatus.draft) return false;
      if (_selectedFilter == 'has_resources' && lesson.resources.isEmpty) return false;

      return true;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.folder_open_rounded, color: Colors.orange, size: 18),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  unit.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  unit.code,
                  style: const TextStyle(fontSize: 9.5, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${unit.lessons.length} دروس',
            style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.black54),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'إضافة درس',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded, color: Colors.green, size: 20),
                onPressed: () => _showCreateLessonDialog(unit),
              ),
              IconButton(
                tooltip: 'تعديل الوحدة',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, color: Colors.amber, size: 18),
                onPressed: () => _showEditUnitDialog(unit),
              ),
              IconButton(
                tooltip: 'حذف الوحدة',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف الوحدة'),
                      content: Text('هل أنت متأكد من حذف الوحدة "${unit.name}" وجميع دروسها؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('تأكيد الحذف'),
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
          children: [
            if (filteredLessons.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('لا توجد دروس مسجلة في هذه الوحدة حالياً.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                child: Column(
                  children: filteredLessons
                      .map((lesson) => _buildLessonItem(context, lesson, isDark))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLessonItem(BuildContext context, Lesson lesson, bool isDark) {
    final isPublished = lesson.status == LessonStatus.published;
    final typeColor = _lessonTypeColor(lesson.lessonType);
    final typeIcon = _lessonTypeIcon(lesson.lessonType);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black12,
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(typeIcon, color: typeColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _lessonTypeLabel(lesson.lessonType),
                            style: TextStyle(fontSize: 9.5, color: typeColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isPublished ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPublished ? 'منشور للطلاب' : 'مسودة',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isPublished ? Colors.green.shade700 : Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (lesson.estimatedDurationMinutes != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 10, color: Colors.grey),
                                const SizedBox(width: 3),
                                Text(
                                  '${lesson.estimatedDurationMinutes} دقيقة',
                                  style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        if (lesson.resources.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, size: 10, color: Colors.purple),
                                const SizedBox(width: 3),
                                Text(
                                  '${lesson.resources.length} مرفقات',
                                  style: const TextStyle(fontSize: 9.5, color: Colors.purple, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'السبورة التفاعلية لشرح الدرس 🎨',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.draw_rounded, size: 18, color: Colors.indigo),
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
                  IconButton(
                    tooltip: 'إرفاق مذكرة / PDF',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.attach_file_rounded, size: 18, color: Colors.purple),
                    onPressed: () => _showUploadResourceDialog(lesson),
                  ),
                  IconButton(
                    tooltip: 'تعديل بيانات الدرس',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.teal),
                    onPressed: () => _showEditLessonDialog(lesson),
                  ),
                  IconButton(
                    tooltip: isPublished ? 'إلغاء النشر (تحويل لمسودة)' : 'نشر للطلاب',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isPublished ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 18,
                      color: isPublished ? Colors.green : Colors.grey,
                    ),
                    onPressed: () async {
                      await _lessonRepo.publishLesson(lesson.id, publish: !isPublished);
                      _loadCurriculum();
                    },
                  ),
                  IconButton(
                    tooltip: 'حذف الدرس',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف الدرس'),
                          content: Text('هل أنت متأكد من حذف درس "${lesson.title}"؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('تأكيد الحذف'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _lessonRepo.deleteLesson(lesson.id);
                        _loadCurriculum();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),

          // Resources attachments sub-list
          if (lesson.resources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: lesson.resources.map((res) {
                  final resourceFileName = res.objectPath.split('/').last;
                  return Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, size: 14, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${res.title} (${resourceFileName.isEmpty ? res.resourceType : resourceFileName})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف المرفق',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                        onPressed: () => _deleteResource(res),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSemesters = _semesters.length;
    final totalUnits = _semesters.fold<int>(0, (sum, s) => sum + s.units.length);
    final totalLessons = _semesters.fold<int>(0, (sum, s) => sum + s.units.fold<int>(0, (uSum, u) => uSum + u.lessons.length));
    final totalResources = _semesters.fold<int>(0, (sum, s) => sum + s.units.fold<int>(0, (uSum, u) => uSum + u.lessons.fold<int>(0, (lSum, l) => lSum + l.resources.length)));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PortalPageShell(
      title: 'إدارة المناهج والدروس',
      subtitle: 'تنظيم الفصول الدراسية والوحدات والدروس ورفع المذكرات التعليمية التفاعلية.',
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
      headerWidgets: [
        _buildKpiSection(
          isDark,
          totalSemesters,
          totalUnits,
          totalLessons,
          totalResources,
        ),
        const SizedBox(height: 12),
        if (_subjects.isNotEmpty) _buildSubjectAndFilterBar(isDark),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'لا توجد بيانات مناهج',
        emptySubtitle: 'قم بإضافة مادة دراسية أولاً.',
        emptyIcon: Icons.auto_stories,
        onRetry: _loadCurriculum,
        child: _selectedSubject == null
                  ? const Center(child: Text('لا توجد مواد دراسية نشطة حالياً.'))
                  : _semesters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_stories, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'لا توجد فصول دراسية مضافة لهذه المادة حتى الآن.',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'ابدأ بإضافة أول فصل دراسي ثم أضف الوحدات والدروس والمذكرات.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('إضافة أول فصل دراسي'),
                            onPressed: _showCreateSemesterDialog,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _semesters.length,
                      itemBuilder: (ctx, semIdx) => _buildSemesterCard(context, _semesters[semIdx], isDark),
                    ),
      ),
    );
  }
}
