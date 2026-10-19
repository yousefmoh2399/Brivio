import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../../academy/domain/repositories/academy_repositories.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';
import '../../domain/repositories/assessment_repositories.dart';

class SmartExamGeneratorDialog extends StatefulWidget {
  final String? teacherId;
  final String? initialGroupId;
  final String? initialSubjectId;
  final String? subjectName;
  final String? groupName;
  final Function(Exam generatedExam)? onExamGenerated;

  // Optional dependency injection (for unit & widget tests)
  final ITeacherRepository? teacherRepo;
  final IQuestionBankRepository? questionRepo;
  final IExamRepository? examRepo;
  final ISubjectRepository? subjectRepo;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> params)?
      createExamAssignmentOverride;
  final Future<void> Function(List<Map<String, dynamic>> examQuestions)?
      insertExamQuestionsOverride;

  const SmartExamGeneratorDialog({
    super.key,
    this.teacherId,
    this.initialGroupId,
    this.initialSubjectId,
    this.subjectName,
    this.groupName,
    this.onExamGenerated,
    this.teacherRepo,
    this.questionRepo,
    this.examRepo,
    this.subjectRepo,
    this.createExamAssignmentOverride,
    this.insertExamQuestionsOverride,
  });

  static Future<Exam?> show(
    BuildContext context, {
    String? teacherId,
    String? initialGroupId,
    String? initialSubjectId,
    String? subjectName,
    String? groupName,
    Function(Exam generatedExam)? onExamGenerated,
    ITeacherRepository? teacherRepo,
    IQuestionBankRepository? questionRepo,
    IExamRepository? examRepo,
    ISubjectRepository? subjectRepo,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> params)?
        createExamAssignmentOverride,
    Future<void> Function(List<Map<String, dynamic>> examQuestions)?
        insertExamQuestionsOverride,
  }) {
    return showDialog<Exam>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SmartExamGeneratorDialog(
        teacherId: teacherId,
        initialGroupId: initialGroupId,
        initialSubjectId: initialSubjectId,
        subjectName: subjectName,
        groupName: groupName,
        onExamGenerated: onExamGenerated,
        teacherRepo: teacherRepo,
        questionRepo: questionRepo,
        examRepo: examRepo,
        subjectRepo: subjectRepo,
        createExamAssignmentOverride: createExamAssignmentOverride,
        insertExamQuestionsOverride: insertExamQuestionsOverride,
      ),
    );
  }

  @override
  State<SmartExamGeneratorDialog> createState() =>
      _SmartExamGeneratorDialogState();
}

class _SmartExamGeneratorDialogState extends State<SmartExamGeneratorDialog> {
  late final ITeacherRepository _teacherRepo;
  late final IQuestionBankRepository _questionRepo;
  late final IExamRepository _examRepo;
  late final ISubjectRepository _subjectRepo;

  final _titleController = TextEditingController();
  int _durationMinutes = 45;
  double _passScore = 50.0;
  DateTime? _availableFrom;
  DateTime _availableUntil = DateTime.now().add(const Duration(days: 7));

  int _easyCount = 4;
  int _mediumCount = 4;
  int _hardCount = 2;

  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isSubmitting = false;
  bool _isSeedingQuestions = false;
  String? _errorMessage;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  final Set<String> _selectedGroupIds = {};
  List<SubjectEntity> _subjects = [];
  String _currentSubjectName = '';

  List<Question> _allQuestionsInBank = [];
  List<Question> _easyPool = [];
  List<Question> _mediumPool = [];
  List<Question> _hardPool = [];

  List<Question>? _generatedQuestions;
  List<Question> _unusedPool = [];

  @override
  void initState() {
    super.initState();
    _initRepositories();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _initRepositories() {
    if (widget.teacherRepo != null &&
        widget.questionRepo != null &&
        widget.examRepo != null &&
        widget.subjectRepo != null) {
      _teacherRepo = widget.teacherRepo!;
      _questionRepo = widget.questionRepo!;
      _examRepo = widget.examRepo!;
      _subjectRepo = widget.subjectRepo!;
      return;
    }

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      _teacherRepo = widget.teacherRepo ?? SupabaseTeacherRepository(wrapper);
      _questionRepo =
          widget.questionRepo ?? SupabaseQuestionBankRepository(wrapper);
      _examRepo = widget.examRepo ?? SupabaseExamRepository(wrapper);
      _subjectRepo = widget.subjectRepo ?? SupabaseSubjectRepository(wrapper);
    } catch (e) {
      debugPrint('Supabase client wrapper initialization fallback: $e');
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final period = d.hour >= 12 ? 'م' : 'ص';
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}/${d.month}/${d.day} $hour:$min $period';
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? currentUserId;
      try {
        currentUserId = Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {}
      final teacherId = widget.teacherId ?? currentUserId ?? '';

      // 1. Fetch Teacher Groups
      List<GroupEntity> groups = [];
      if (teacherId.isNotEmpty) {
        try {
          groups = await _teacherRepo.fetchAssignedGroups(teacherId);
        } catch (e) {
          debugPrint('Error fetching assigned groups: $e');
        }
      }

      // 2. Fetch Subjects list for name lookup
      try {
        _subjects = await _subjectRepo.fetchSubjects();
      } catch (e) {
        debugPrint('Error fetching subjects: $e');
      }

      // 3. Determine selected group
      GroupEntity? selectedGroup;
      if (widget.initialGroupId != null) {
        selectedGroup = groups
            .cast<GroupEntity?>()
            .firstWhere((g) => g?.id == widget.initialGroupId, orElse: () => null);
      }
      selectedGroup ??= groups.isNotEmpty ? groups.first : null;

      // 4. Determine subject ID & name
      String subjectId = selectedGroup?.subjectId ?? widget.initialSubjectId ?? '';
      String subjectName = widget.subjectName ?? '';
      if (subjectName.isEmpty && subjectId.isNotEmpty) {
        final sub = _subjects
            .cast<SubjectEntity?>()
            .firstWhere((s) => s?.id == subjectId, orElse: () => null);
        if (sub != null) {
          subjectName = sub.name;
        } else if (selectedGroup != null) {
          subjectName = selectedGroup.name;
        } else {
          subjectName = 'المادة المقررة';
        }
      }

      _groups = groups;
      _selectedGroup = selectedGroup;
      if (selectedGroup != null) {
        _selectedGroupIds.add(selectedGroup.id);
      }
      _currentSubjectName = subjectName;

      final now = DateTime.now();
      _titleController.text = 'امتحان ذكي شامل - $subjectName (${now.day}/${now.month})';

      // 5. Fetch Question Bank if subject is present
      if (subjectId.isNotEmpty) {
        await _fetchQuestionsForSubject(subjectId, initialSetup: true);
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل البيانات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchQuestionsForSubject(
    String subjectId, {
    bool initialSetup = false,
  }) async {
    try {
      final questions = await _questionRepo.fetchQuestionsForSubject(subjectId);
      final active = questions.where((q) => q.status != 'archived').toList();

      final easy = active.where((q) => q.difficulty.toLowerCase() == 'easy').toList();
      final med = active
          .where((q) =>
              q.difficulty.toLowerCase() == 'medium' ||
              (q.difficulty.toLowerCase() != 'easy' &&
                  q.difficulty.toLowerCase() != 'hard'))
          .toList();
      final hard = active.where((q) => q.difficulty.toLowerCase() == 'hard').toList();

      if (!mounted) return;
      setState(() {
        _allQuestionsInBank = active;
        _easyPool = easy;
        _mediumPool = med;
        _hardPool = hard;

        if (initialSetup || _allQuestionsInBank.isNotEmpty) {
          _easyCount = min(4, max(1, easy.length));
          _mediumCount = min(4, max(1, med.length));
          _hardCount = min(2, max(0, hard.length));
        }

        _generatedQuestions = null;
        _unusedPool = [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to fetch questions: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر جلب أسئلة المادة: $e';
      });
    }
  }

  void _onGroupChanged(GroupEntity? newGroup) {
    if (newGroup == null) return;
    final subjectChanged = newGroup.subjectId != _selectedGroup?.subjectId;
    setState(() {
      _selectedGroup = newGroup;
      _selectedGroupIds.clear();
      _selectedGroupIds.add(newGroup.id);

      final sub = _subjects
          .cast<SubjectEntity?>()
          .firstWhere((s) => s?.id == newGroup.subjectId, orElse: () => null);
      _currentSubjectName = sub?.name ?? newGroup.name;

      final now = DateTime.now();
      _titleController.text =
          'امتحان ذكي شامل - $_currentSubjectName (${now.day}/${now.month})';
    });

    if (subjectChanged && newGroup.subjectId.isNotEmpty) {
      setState(() => _isLoading = true);
      _fetchQuestionsForSubject(newGroup.subjectId);
    }
  }

  int get _totalQuestions => _easyCount + _mediumCount + _hardCount;

  double get _totalEstimatedScore =>
      (_easyCount * 1.0) + (_mediumCount * 2.0) + (_hardCount * 3.0);

  // Seeding sample questions if teacher's bank is currently empty
  Future<void> _seedSampleQuestionsForSubject() async {
    final subjectId = _selectedGroup?.subjectId ?? widget.initialSubjectId;
    if (subjectId == null || subjectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('يرجى تحديد مجموعة ومادة أولاً لتوليد بنك الأسئلة.'),
        ),
      );
      return;
    }

    setState(() => _isSeedingQuestions = true);
    try {
      final sampleSeeds = [
        {
          'type': QuestionType.multipleChoice,
          'prompt':
              'ما هو المفهوم الأساسي الأولي والركيزة النظرية في منهج $_currentSubjectName؟',
          'diff': 'easy',
          'points': 1.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'المفهوم المباشر والتعريف الأساسي المعتمد',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'فرضية فرعية غير معتمدة علمياً',
              isCorrect: false,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'استثناء غير مرتبط بمحتوى الدرس',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.trueFalse,
          'prompt':
              'تتوافق التطبيقات العملية للمنهج مع القواعد النموذجية المقررة في المادة.',
          'diff': 'easy',
          'points': 1.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'صواب',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'خطأ',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.multipleChoice,
          'prompt':
              'أيٌّ من الآتي يُعد من أهم وحدات القياس أو المصطلحات المفتاحية المقررة؟',
          'diff': 'easy',
          'points': 1.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'المصطلح المرجعي المباشر للدرس',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'قيمة تقديرية لا أساس لها',
              isCorrect: false,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'مصطلح خارج إطار المنهج',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.trueFalse,
          'prompt':
              'يمكن الحصول على النتيجة الصحيحة بمجرد استنتاج المعطيات وتطبيق القانون المباشر.',
          'diff': 'easy',
          'points': 1.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'صواب',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'خطأ',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.multipleChoice,
          'prompt':
              'عند تغير أحد العوامل المؤثرة بمقدار الضعف، ما التأثير المباشر على النتيجة الإجمالية؟',
          'diff': 'medium',
          'points': 2.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'تتضاعف النتيجة طردياً مع زيادة العامل المؤثر',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'تقل النتيجة للنصف عكسياً',
              isCorrect: false,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'تظل القيمة ثابتة تماماً دون أي تأثر',
              isCorrect: false,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'تنعدم النتيجة كلياً',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.multipleChoice,
          'prompt':
              'إذا طُلب منك تطبيق النموذج في مسألة مركبة، فما هي الخطوة المنهجية الأولى؟',
          'diff': 'medium',
          'points': 2.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'تحديد المعطيات بدقة وتصنيف المتغيرات المؤثرة',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'إجراء الحسابات بشكل تقديري دون ترتيب',
              isCorrect: false,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'إهمال الشروط الابتدائية للنظام',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.trueFalse,
          'prompt':
              'التناسب بين المتغير المستقل والتابع يستلزم ثبات باقي الشروط والبيئة المحيطة.',
          'diff': 'medium',
          'points': 2.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'صواب',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'خطأ',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.multipleChoice,
          'prompt':
              'أي الحالات الآتية تمثل التطبيق النموذجي الأمثل للنظرية في سياق واقعي؟',
          'diff': 'medium',
          'points': 2.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'الحالة التي تتوافر فيها جميع الشروط المثالية المقررة',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'الحالة التي تشهد اضطراباً في المتغيرات الرئيسية',
              isCorrect: false,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'حالة انعدام التأثير المتبادل',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.multipleChoice,
          'prompt':
              'في حالة حدوث تعارض ظاهري بين معطيين متناقضين، كيف تفسر النتيجة الاستنتاجية المتقدمة؟',
          'diff': 'hard',
          'points': 3.0,
          'options': [
            QuestionOption(
              id: '',
              questionId: '',
              text: 'عبر إدخال المتغير الحرج وتحليل شروط الحدود بدقة',
              isCorrect: true,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'عبر استبعاد أحد المعطيين دون مبرر علمي',
              isCorrect: false,
            ),
            QuestionOption(
              id: '',
              questionId: '',
              text: 'بافتراض خطأ النظرية كلياً',
              isCorrect: false,
            ),
          ],
        },
        {
          'type': QuestionType.shortAnswer,
          'prompt':
              'علل وفسر تحليلياً: لماذا يختلف السلوك الديناميكي للنظام في سياق المنهج عند درجات الحرارة أو الضغوط القصوى؟',
          'diff': 'hard',
          'points': 3.0,
          'options': const [],
        },
      ];

      for (final s in sampleSeeds) {
        await _questionRepo.createQuestion(
          Question(
            id: '',
            subjectId: subjectId,
            questionType: s['type'] as QuestionType,
            prompt: s['prompt'] as String,
            difficulty: s['diff'] as String,
            defaultPoints: s['points'] as double,
            status: 'active',
          ),
          s['options'] as List<QuestionOption>,
        );
      }

      await _fetchQuestionsForSubject(subjectId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('تم توليد 10 أسئلة نموذجية في بنك الأسئلة بنجاح! 🎯'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('تعذر توليد الأسئلة النموذجية: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeedingQuestions = false);
    }
  }

  void _generateQuestionsFromBank() {
    if (_totalQuestions <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.warning,
          content: Text('يرجى تحديد سؤال واحد على الأقل في مصفوفة الصعوبة.'),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final rng = Random();
      final selectedEasy = List<Question>.from(_easyPool)..shuffle(rng);
      final selectedMed = List<Question>.from(_mediumPool)..shuffle(rng);
      final selectedHard = List<Question>.from(_hardPool)..shuffle(rng);

      final chosen = <Question>[];
      final unused = <Question>[];

      // Easy
      final easyPicks = selectedEasy.take(_easyCount).toList();
      chosen.addAll(easyPicks);
      unused.addAll(selectedEasy.skip(_easyCount));

      // Medium
      final medPicks = selectedMed.take(_mediumCount).toList();
      chosen.addAll(medPicks);
      unused.addAll(selectedMed.skip(_mediumCount));

      // Hard
      final hardPicks = selectedHard.take(_hardCount).toList();
      chosen.addAll(hardPicks);
      unused.addAll(selectedHard.skip(_hardCount));

      // If bank doesn't have enough questions, synthesize needed questions so user is never blocked
      if (chosen.isEmpty && _allQuestionsInBank.isEmpty) {
        final subjectId =
            _selectedGroup?.subjectId ?? widget.initialSubjectId ?? 'sub-1';
        for (int i = 1; i <= _easyCount; i++) {
          chosen.add(
            Question(
              id: 'temp-easy-$i',
              subjectId: subjectId,
              questionType: QuestionType.multipleChoice,
              prompt:
                  'سؤال تمهيدي رقم $i في منهج $_currentSubjectName: اختر الإجابة الصحيحة',
              difficulty: 'easy',
              defaultPoints: 1.0,
              options: [
                QuestionOption(
                  id: 'o-1',
                  questionId: 'temp-easy-$i',
                  text: 'الإجابة النموذجية الصحيحة',
                  isCorrect: true,
                ),
                QuestionOption(
                  id: 'o-2',
                  questionId: 'temp-easy-$i',
                  text: 'بديل أول غير صحيح',
                  isCorrect: false,
                ),
                QuestionOption(
                  id: 'o-3',
                  questionId: 'temp-easy-$i',
                  text: 'بديل ثانٍ غير صحيح',
                  isCorrect: false,
                ),
              ],
            ),
          );
        }
        for (int i = 1; i <= _mediumCount; i++) {
          chosen.add(
            Question(
              id: 'temp-med-$i',
              subjectId: subjectId,
              questionType: QuestionType.trueFalse,
              prompt:
                  'سؤال تطبيقي رقم $i في منهج $_currentSubjectName: هل العبارة صحيحة؟',
              difficulty: 'medium',
              defaultPoints: 2.0,
              options: [
                QuestionOption(
                  id: 'o-1',
                  questionId: 'temp-med-$i',
                  text: 'صواب / الإجابة الدقيقة',
                  isCorrect: true,
                ),
                QuestionOption(
                  id: 'o-2',
                  questionId: 'temp-med-$i',
                  text: 'خطأ',
                  isCorrect: false,
                ),
              ],
            ),
          );
        }
        for (int i = 1; i <= _hardCount; i++) {
          chosen.add(
            Question(
              id: 'temp-hard-$i',
              subjectId: subjectId,
              questionType: QuestionType.shortAnswer,
              prompt:
                  'سؤال تحليلي متقدم رقم $i في منهج $_currentSubjectName: فسر استنتاجك مدعوماً بالقاعدة المنهجية.',
              difficulty: 'hard',
              defaultPoints: 3.0,
              options: const [],
            ),
          );
        }
      }

      setState(() {
        _isGenerating = false;
        _generatedQuestions = chosen;
        _unusedPool = unused;
      });
    });
  }

  void _swapQuestion(int index) {
    if (_generatedQuestions == null || index >= _generatedQuestions!.length) return;
    final target = _generatedQuestions![index];
    final diff = target.difficulty.toLowerCase();

    // Look for a replacement in unused pool with same difficulty
    final replacementIndex = _unusedPool
        .indexWhere((q) => q.difficulty.toLowerCase() == diff && q.id != target.id);

    if (replacementIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blueGrey,
          content: Text(
            'لا توجد أسئلة بديلة أخرى بمستوى ($diff) في بنك الأسئلة حالياً.',
          ),
        ),
      );
      return;
    }

    final replacement = _unusedPool.removeAt(replacementIndex);
    _unusedPool.add(target);

    setState(() {
      _generatedQuestions![index] = replacement;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        backgroundColor: Colors.teal,
        content: Text('تم استبدال السؤال بسؤال بديل من نفس المستوى بنجاح 🔄'),
      ),
    );
  }

  void _removeQuestion(int index) {
    if (_generatedQuestions == null || index >= _generatedQuestions!.length) return;
    final removed = _generatedQuestions!.removeAt(index);
    _unusedPool.add(removed);

    final diff = removed.difficulty.toLowerCase();
    if (diff == 'easy' && _easyCount > 0) _easyCount--;
    if (diff == 'medium' && _mediumCount > 0) _mediumCount--;
    if (diff == 'hard' && _hardCount > 0) _hardCount--;

    setState(() {});
  }

  Future<void> _confirmAndPublish() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('يرجى إدخال عنوان مناسب للامتحان.'),
        ),
      );
      return;
    }

    if (_generatedQuestions == null || _generatedQuestions!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('يرجى توليد الأسئلة أولاً لمعاينتها قبل النشر.'),
        ),
      );
      return;
    }

    if (_selectedGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('يرجى تحديد مجموعة دراسية واحدة على الأقل لنشر الامتحان.'),
        ),
      );
      return;
    }

    if (_availableFrom != null && _availableUntil.isBefore(_availableFrom!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('يجب أن يكون موعد انتهاء الامتحان بعد موعد البدء.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final subjectId =
          _selectedGroup?.subjectId ?? widget.initialSubjectId ?? 'sub-1';
      Exam? lastCreatedExam;

      for (final groupId in _selectedGroupIds) {
        final rpcParams = {
          'p_title': title,
          'p_subject_id': subjectId,
          'p_group_id': groupId,
          'p_duration_minutes': _durationMinutes,
          'p_pass_score': _passScore,
          'p_status': 'published',
          'p_available_from': _availableFrom?.toIso8601String(),
          'p_available_until': _availableUntil.toIso8601String(),
        };

        Map<String, dynamic> examRecord;
        if (widget.createExamAssignmentOverride != null) {
          examRecord = await widget.createExamAssignmentOverride!(rpcParams);
        } else {
          final res = await Supabase.instance.client.rpc(
            'create_exam_assignment',
            params: rpcParams,
          );
          examRecord = Map<String, dynamic>.from(res as Map);
        }

        final examId = examRecord['id']?.toString() ??
            'exam-${DateTime.now().millisecondsSinceEpoch}';

        // Filter valid question IDs that are persisted in DB (ignore temp ids)
        final realQuestions = _generatedQuestions!
            .where((q) => !q.id.startsWith('temp-'))
            .toList();

        final examQuestionsPayload = [
          for (int i = 0; i < realQuestions.length; i++)
            {
              'exam_id': examId,
              'question_id': realQuestions[i].id,
              'order_number': i + 1,
              'points': realQuestions[i].defaultPoints,
            }
        ];

        if (examQuestionsPayload.isNotEmpty) {
          if (widget.insertExamQuestionsOverride != null) {
            await widget.insertExamQuestionsOverride!(examQuestionsPayload);
          } else {
            try {
              await Supabase.instance.client
                  .from('exam_questions')
                  .insert(examQuestionsPayload);
            } catch (eqErr) {
              debugPrint('Batch insert into exam_questions failed: $eqErr');
              // Fallback to loop insertion via repo if direct batch fails
              for (final eq in examQuestionsPayload) {
                try {
                  await _examRepo.linkQuestion(
                    examId,
                    eq['question_id'] as String,
                    (eq['points'] as num).toDouble(),
                  );
                } catch (_) {}
              }
            }
          }
        }

        lastCreatedExam = Exam(
          id: examId,
          title: title,
          subjectId: subjectId,
          groupId: groupId,
          durationMinutes: _durationMinutes,
          passScore: _passScore,
          status: 'published',
          availableFrom: _availableFrom,
          availableUntil: _availableUntil,
          questions: _generatedQuestions!,
        );
      }

      if (!mounted) return;

      widget.onExamGenerated?.call(lastCreatedExam!);
      Navigator.pop(context, lastCreatedExam);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            'تم نشر الامتحان الذكي بنجاح لـ ${_selectedGroupIds.length} مجموعة دراسية 🎯🚀',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('فشل نشر الامتحان: $e'),
        ),
      );
    }
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = screenSize.width < 500;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: surfaceColor,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: screenSize.height * 0.90,
        ),
        child: _isLoading
            ? Container(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'جارٍ تجهيز بنك الأسئلة والمجموعات الدراسية...',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sticky Header
                    _buildHeader(textPrimary, textSecondary),
                    const Divider(height: 20),

                    // Scrollable Body
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                            // Group and Subject Selector
                            _buildGroupAndSubjectSection(
                              textPrimary,
                              textSecondary,
                              borderColor,
                              isDark,
                              isMobile,
                            ),
                            const SizedBox(height: 14),

                            // Title & Timing Parameters
                            _buildParametersSection(
                              textPrimary,
                              textSecondary,
                              borderColor,
                              isDark,
                              isMobile,
                            ),
                            const SizedBox(height: 14),

                            // Matrix Specification & Bank Availability
                            _buildMatrixSection(
                              textPrimary,
                              textSecondary,
                              borderColor,
                              isDark,
                              isMobile,
                            ),
                            const SizedBox(height: 16),

                            // Generate Button
                            _buildGenerateButton(),

                            // Generated Questions Preview
                            if (_generatedQuestions != null) ...[
                              const SizedBox(height: 20),
                              _buildPreviewSection(
                                textPrimary,
                                textSecondary,
                                borderColor,
                                isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Sticky Bottom Action (if generated)
                    if (_generatedQuestions != null) ...[
                      const Divider(height: 20),
                      _buildPublishFooter(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.deepOrange, Colors.orangeAccent],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توليد امتحان ذكي متوازن ⚡',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'سحب آلي من بنك الأسئلة وفق مصفوفة المواصفات القياسية',
                style: TextStyle(fontSize: 10.5, color: textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildGroupAndSubjectSection(
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    bool isDark,
    bool isMobile,
  ) {
    final relatedGroups = _groups
        .where((g) =>
            _selectedGroup != null && g.subjectId == _selectedGroup!.subjectId)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.class_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'المجموعة المستهدفة والمادة الدراسية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isMobile) ...[
            _buildGroupDropdown(textPrimary),
            const SizedBox(height: 8),
            _buildSubjectBadge(textPrimary),
          ] else ...[
            Row(
              children: [
                Expanded(flex: 3, child: _buildGroupDropdown(textPrimary)),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _buildSubjectBadge(textPrimary)),
              ],
            ),
          ],

          // Multi-group publishing toggle (if multiple groups exist for this subject)
          if (relatedGroups.length > 1) ...[
            const SizedBox(height: 10),
            const Divider(height: 14),
            Row(
              children: [
                Icon(Icons.hub_rounded, size: 15, color: textSecondary),
                const SizedBox(width: 6),
                Text(
                  'نشر لنفس المادة في مجموعات إضافية:',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: relatedGroups.map((g) {
                final isSelected = _selectedGroupIds.contains(g.id);
                final isPrimary = g.id == _selectedGroup?.id;
                return FilterChip(
                  label: Text(
                    g.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  onSelected: isPrimary
                      ? null // primary must stay selected
                      : (val) {
                          setState(() {
                            if (val) {
                              _selectedGroupIds.add(g.id);
                            } else {
                              _selectedGroupIds.remove(g.id);
                            }
                          });
                        },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupDropdown(Color textPrimary) {
    if (_groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'لا توجد مجموعات مسندة',
          style: TextStyle(fontSize: 12, color: Colors.amber),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedGroup?.id,
      decoration: const InputDecoration(
        labelText: 'المجموعة الدراسية الأساسية *',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: _groups.map((g) {
        return DropdownMenuItem<String>(
          value: g.id,
          child: Text(
            g.name,
            style: TextStyle(fontSize: 12.5, color: textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        final g = _groups
            .cast<GroupEntity?>()
            .firstWhere((x) => x?.id == val, orElse: () => null);
        _onGroupChanged(g);
      },
    );
  }

  Widget _buildSubjectBadge(Color textPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المادة المنهجية',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentSubjectName.isNotEmpty
                      ? _currentSubjectName
                      : 'غير محددة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParametersSection(
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: TextStyle(fontSize: 13, color: textPrimary),
            decoration: const InputDecoration(
              labelText: 'عنوان الامتحان أو الاختبار *',
              prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _durationMinutes,
              decoration: const InputDecoration(
                labelText: 'المدة الزمنية',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 دقيقة (سريع)')),
                DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
                DropdownMenuItem(value: 45, child: Text('45 دقيقة')),
                DropdownMenuItem(value: 60, child: Text('ساعة كاملة')),
                DropdownMenuItem(value: 90, child: Text('ساعة ونصف')),
                DropdownMenuItem(value: 120, child: Text('ساعتان')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _durationMinutes = val);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<double>(
              isExpanded: true,
              initialValue: _passScore,
              decoration: const InputDecoration(
                labelText: 'درحة النجاح (%)',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 50.0, child: Text('50% (الحد الأدنى)')),
                DropdownMenuItem(value: 60.0, child: Text('60% (جيد)')),
                DropdownMenuItem(value: 70.0, child: Text('70% (متقدم)')),
                DropdownMenuItem(value: 80.0, child: Text('80% (فائقين)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _passScore = val);
              },
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _durationMinutes,
                    decoration: const InputDecoration(
                      labelText: 'المدة الزمنية',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 دقيقة (سريع)')),
                      DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
                      DropdownMenuItem(value: 45, child: Text('45 دقيقة')),
                      DropdownMenuItem(value: 60, child: Text('ساعة كاملة')),
                      DropdownMenuItem(value: 90, child: Text('ساعة ونصف')),
                      DropdownMenuItem(value: 120, child: Text('ساعتان')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _durationMinutes = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    isExpanded: true,
                    initialValue: _passScore,
                    decoration: const InputDecoration(
                      labelText: 'درجة النجاح (%)',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 50.0, child: Text('50% (الحد الأدنى)')),
                      DropdownMenuItem(value: 60.0, child: Text('60% (جيد)')),
                      DropdownMenuItem(value: 70.0, child: Text('70% (متقدم)')),
                      DropdownMenuItem(value: 80.0, child: Text('80% (فائقين)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _passScore = val);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Availability Window
          if (isMobile) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              onPressed: () async {
                final picked = await _pickDateTime(
                  context,
                  _availableFrom ?? DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _availableFrom = picked);
                }
              },
              icon: const Icon(
                Icons.play_circle_outline_rounded,
                size: 16,
                color: Colors.green,
              ),
              label: Text(
                _availableFrom == null
                    ? 'يبدأ: متاح فوراً'
                    : 'يبدأ: ${_formatDateTime(_availableFrom!)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              onPressed: () async {
                final picked = await _pickDateTime(context, _availableUntil);
                if (picked != null) {
                  setState(() => _availableUntil = picked);
                }
              },
              icon: const Icon(
                Icons.lock_clock_rounded,
                size: 16,
                color: Colors.orange,
              ),
              label: Text(
                'ينتهي: ${_formatDateTime(_availableUntil)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    ),
                    onPressed: () async {
                      final picked = await _pickDateTime(
                        context,
                        _availableFrom ?? DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _availableFrom = picked);
                      }
                    },
                    icon: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 16,
                      color: Colors.green,
                    ),
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'يبدأ الامتحان:',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          _availableFrom == null
                              ? 'متاح فوراً'
                              : _formatDateTime(_availableFrom!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    ),
                    onPressed: () async {
                      final picked = await _pickDateTime(context, _availableUntil);
                      if (picked != null) {
                        setState(() => _availableUntil = picked);
                      }
                    },
                    icon: const Icon(
                      Icons.lock_clock_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ينتهي التقديم:',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          _formatDateTime(_availableUntil),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatrixSection(
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'مصفوفة مواصفات الامتحان القياسية 🎯',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'إجمالي: $_totalQuestions سؤال (${_totalEstimatedScore.toInt()} درجة)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'حدد التوزيع النسبي للأسئلة حسب مستويات الصعوبة وفق مخرجات التعلم:',
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
          const SizedBox(height: 10),

          // Stepper Boxes
          Row(
            children: [
              _buildStepperBox(
                label: 'سهل (مباشر)',
                count: _easyCount,
                availableCount: _easyPool.length,
                color: Colors.green,
                onChanged: (v) => setState(() => _easyCount = v),
              ),
              const SizedBox(width: 8),
              _buildStepperBox(
                label: 'متوسط (تطبيقي)',
                count: _mediumCount,
                availableCount: _mediumPool.length,
                color: Colors.blue,
                onChanged: (v) => setState(() => _mediumCount = v),
              ),
              const SizedBox(width: 8),
              _buildStepperBox(
                label: 'متقدم (فائقين)',
                count: _hardCount,
                availableCount: _hardPool.length,
                color: Colors.purple,
                onChanged: (v) => setState(() => _hardCount = v),
              ),
            ],
          ),

          // Question Bank status and Seeding prompt if empty
          if (_allQuestionsInBank.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.amber, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'بنك الأسئلة فارغ لهذه المادة حالياً!',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكنك إنشاء 10 أسئلة نموذجية فورية في بنك أسئلة المنهج للبدء بالسحب الذكي مباشرة:',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isSeedingQuestions
                        ? null
                        : _seedSampleQuestionsForSubject,
                    icon: _isSeedingQuestions
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      _isSeedingQuestions
                          ? 'جارٍ توليد الأسئلة في البنك...'
                          : '⚡ توليد 10 أسئلة منهجية نموذجية في البنك',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepperBox({
    required String label,
    required int count,
    required int availableCount,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '(متاح: $availableCount)',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: count > 0 ? () => onChanged(count - 1) : null,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: count > 0
                          ? color.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 14,
                      color: count > 0 ? color : Colors.grey,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => onChanged(count + 1),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.2),
                    ),
                    child: Icon(Icons.add, size: 14, color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isGenerating ? null : _generateQuestionsFromBank,
      icon: _isGenerating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.auto_awesome_rounded),
      label: Text(
        _isGenerating
            ? 'جارٍ السحب الآلي والمطابقة الذكية...'
            : 'سحب وتوليد الأسئلة فوراً ⚡',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPreviewSection(
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    bool isDark,
  ) {
    final questions = _generatedQuestions ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'معاينة مسودة الامتحان (${questions.length} أسئلة):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textPrimary,
              ),
            ),
            Text(
              '🔄 اضغط على السهم لاستبدال أي سؤال ببديل',
              style: TextStyle(fontSize: 10, color: textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: questions.length,
            separatorBuilder: (_, __) => const Divider(height: 14),
            itemBuilder: (context, i) {
              final q = questions[i];
              final diffColor = q.difficulty.toLowerCase() == 'easy'
                  ? Colors.green
                  : (q.difficulty.toLowerCase() == 'hard'
                      ? Colors.purple
                      : Colors.blue);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: diffColor.withValues(alpha: 0.15),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: diffColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.prompt,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: diffColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                q.difficulty == 'easy'
                                    ? 'سهل'
                                    : (q.difficulty == 'hard'
                                        ? 'متقدم'
                                        : 'متوسط'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: diffColor,
                                ),
                              ),
                            ),
                            Text(
                              '• ${q.defaultPoints} درجات',
                              style:
                                  TextStyle(fontSize: 10, color: textSecondary),
                            ),
                            if (q.options.isNotEmpty)
                              Text(
                                '• (${q.options.length} خيارات)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textSecondary,
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
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        tooltip: 'استبدال بسؤال بديل من نفس الصعوبة',
                        onPressed: () => _swapQuestion(i),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                          size: 18,
                        ),
                        tooltip: 'حذف هذا السؤال',
                        onPressed: () => _removeQuestion(i),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPublishFooter() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isSubmitting ? null : _confirmAndPublish,
      icon: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.rocket_launch_rounded),
      label: Text(
        _isSubmitting
            ? 'جارٍ الحفظ والنشر للطلاب...'
            : 'اعتماد ونشر الامتحان للطلاب الآن (${_selectedGroupIds.length} مجموعة) 🚀',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
      ),
    );
  }
}
