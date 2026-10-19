import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/academy/domain/repositories/academy_repositories.dart';
import 'package:brivio/features/assessment/domain/models/assessment_models.dart';
import 'package:brivio/features/assessment/domain/repositories/assessment_repositories.dart';
import 'package:brivio/features/assessment/presentation/screens/smart_exam_generator_dialog.dart';

class FakeTeacherRepository implements ITeacherRepository {
  final List<GroupEntity> groups;
  FakeTeacherRepository(this.groups);

  @override
  Future<List<GroupEntity>> fetchAssignedGroups(String teacherId) async => groups;

  @override
  Future<PaginatedResult<Teacher>> fetchTeachers({String? search, String? branchId, int page = 1, int pageSize = 20}) async =>
      PaginatedResult(total: 0, page: page, pageSize: pageSize, data: const []);

  @override
  Future<Teacher> getTeacherById(String id) => throw UnimplementedError();

  @override
  Future<Teacher> updateTeacher(Teacher teacher) => throw UnimplementedError();
}

class FakeSubjectRepository implements ISubjectRepository {
  final List<SubjectEntity> subjects;
  FakeSubjectRepository(this.subjects);

  @override
  Future<List<SubjectEntity>> fetchSubjects({String? search, String? status}) async => subjects;

  @override
  Future<SubjectEntity> createSubject(SubjectEntity subject) => throw UnimplementedError();

  @override
  Future<void> deleteSubject(String id) => throw UnimplementedError();

  @override
  Future<SubjectEntity> updateSubject(SubjectEntity subject) => throw UnimplementedError();
}

class FakeQuestionBankRepository implements IQuestionBankRepository {
  List<Question> questions;
  FakeQuestionBankRepository(this.questions);

  @override
  Future<List<Question>> fetchQuestionsForSubject(String subjectId) async => questions;

  @override
  Future<Question> createQuestion(Question question, List<QuestionOption> options) async {
    final created = Question(
      id: 'created-${DateTime.now().millisecondsSinceEpoch}',
      subjectId: question.subjectId,
      questionType: question.questionType,
      prompt: question.prompt,
      difficulty: question.difficulty,
      defaultPoints: question.defaultPoints,
      options: options,
    );
    questions.add(created);
    return created;
  }

  @override
  Future<void> updateQuestion(Question question, List<QuestionOption> options) async {}

  @override
  Future<void> deleteQuestion(String id) async {
    questions.removeWhere((q) => q.id == id);
  }
}

class FakeExamRepository implements IExamRepository {
  final List<Map<String, dynamic>> linked = [];

  @override
  Future<List<Exam>> fetchExamsForGroup(String groupId) async => [];

  @override
  Future<void> linkQuestion(String examId, String questionId, double points) async {
    linked.add({'exam_id': examId, 'question_id': questionId, 'points': points});
  }

  @override
  Future<void> unlinkQuestion(String examId, String questionId) async {}

  @override
  Future<void> closeExam(String id) async {}

  @override
  Future<void> deleteExam(String id) async {}

  @override
  Future<void> saveExamAnswer({required String attemptId, required String questionId, String? selectedOptionId, String? textAnswer}) async {}

  @override
  Future<ExamAttempt> startExam(String examId) => throw UnimplementedError();

  @override
  Future<ExamAttempt> submitExamAttempt(String attemptId) => throw UnimplementedError();
}

void main() {
  group('SmartExamGeneratorDialog Tests', () {
    late FakeTeacherRepository teacherRepo;
    late FakeSubjectRepository subjectRepo;
    late FakeQuestionBankRepository questionRepo;
    late FakeExamRepository examRepo;

    final testGroup = const GroupEntity(
      id: 'grp-1',
      name: 'مجموعة الأبطال - فيزياء',
      code: 'GRP-PHYS-1',
      subjectId: 'sub-phys',
      branchId: 'br-1',
      status: 'active',
    );

    final testSubject = const SubjectEntity(
      id: 'sub-phys',
      name: 'الفيزياء الحديثة',
      code: 'PHYS-101',
      status: 'active',
    );

    final testQuestions = [
      Question(
        id: 'q-easy-1',
        subjectId: 'sub-phys',
        questionType: QuestionType.multipleChoice,
        prompt: 'سؤال سهل أول: ما هو قانون نيوتن الأول؟',
        difficulty: 'easy',
        defaultPoints: 1.0,
      ),
      Question(
        id: 'q-easy-2',
        subjectId: 'sub-phys',
        questionType: QuestionType.trueFalse,
        prompt: 'سؤال سهل ثانٍ: وحدة قياس القوة هي النيوتن.',
        difficulty: 'easy',
        defaultPoints: 1.0,
      ),
      Question(
        id: 'q-easy-3',
        subjectId: 'sub-phys',
        questionType: QuestionType.multipleChoice,
        prompt: 'سؤال سهل ثالث احتياطي للتبديل.',
        difficulty: 'easy',
        defaultPoints: 1.0,
      ),
      Question(
        id: 'q-med-1',
        subjectId: 'sub-phys',
        questionType: QuestionType.multipleChoice,
        prompt: 'سؤال متوسط أول: احسب التسارع المؤثر على الكتلة.',
        difficulty: 'medium',
        defaultPoints: 2.0,
      ),
      Question(
        id: 'q-med-2',
        subjectId: 'sub-phys',
        questionType: QuestionType.trueFalse,
        prompt: 'سؤال متوسط ثانٍ احتياطي.',
        difficulty: 'medium',
        defaultPoints: 2.0,
      ),
      Question(
        id: 'q-hard-1',
        subjectId: 'sub-phys',
        questionType: QuestionType.shortAnswer,
        prompt: 'سؤال فائقين: اشرح تأثير النسبية الخاصة عند السرعات العالية.',
        difficulty: 'hard',
        defaultPoints: 3.0,
      ),
    ];

    setUp(() {
      teacherRepo = FakeTeacherRepository([testGroup]);
      subjectRepo = FakeSubjectRepository([testSubject]);
      questionRepo = FakeQuestionBankRepository(List.from(testQuestions));
      examRepo = FakeExamRepository();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: SmartExamGeneratorDialog(
            teacherId: 'teacher-1',
            initialGroupId: 'grp-1',
            initialSubjectId: 'sub-phys',
            teacherRepo: teacherRepo,
            subjectRepo: subjectRepo,
            questionRepo: questionRepo,
            examRepo: examRepo,
          ),
        ),
      );
    }

    testWidgets('Renders properly without overflow on mobile (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('توليد امتحان ذكي متوازن ⚡'), findsOneWidget);
      expect(find.text('الفيزياء الحديثة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Loads bank questions and shows difficulty pools', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('سهل (مباشر)'), findsOneWidget);
      expect(find.text('متوسط (تطبيقي)'), findsOneWidget);
      expect(find.text('متقدم (فائقين)'), findsOneWidget);
      expect(find.text('(متاح: 3)'), findsOneWidget);
      expect(find.text('(متاح: 2)'), findsOneWidget);
      expect(find.text('(متاح: 1)'), findsOneWidget);
    });

    testWidgets('Generates questions, allows swapping and removing questions', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Ensure generate button is visible and tap it
      final generateBtn = find.text('سحب وتوليد الأسئلة فوراً ⚡');
      expect(generateBtn, findsOneWidget);
      await tester.ensureVisible(generateBtn);
      await tester.tap(generateBtn);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      // Verify questions preview is displayed
      expect(find.textContaining('معاينة مسودة الامتحان'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsWidgets);
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);

      // Tap swap on first question
      final firstSwapBtn = find.byIcon(Icons.swap_horiz_rounded).first;
      await tester.tap(firstSwapBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('معاينة مسودة الامتحان (6 أسئلة)'), findsOneWidget);

      // Tap remove on first question
      final firstDeleteBtn = find.byIcon(Icons.delete_outline_rounded).first;
      await tester.tap(firstDeleteBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('معاينة مسودة الامتحان (5 أسئلة)'), findsOneWidget);
    });

    testWidgets('Confirms and publishes exam successfully', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Exam? publishedExam;
      Map<String, dynamic>? calledRpcParams;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartExamGeneratorDialog(
              teacherId: 'teacher-1',
              initialGroupId: 'grp-1',
              initialSubjectId: 'sub-phys',
              teacherRepo: teacherRepo,
              subjectRepo: subjectRepo,
              questionRepo: questionRepo,
              examRepo: examRepo,
              onExamGenerated: (e) => publishedExam = e,
              createExamAssignmentOverride: (params) async {
                calledRpcParams = params;
                return {'id': 'exam-published-999'};
              },
              insertExamQuestionsOverride: (payload) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure generate button is visible and tap it
      final generateBtn = find.text('سحب وتوليد الأسئلة فوراً ⚡');
      await tester.ensureVisible(generateBtn);
      await tester.tap(generateBtn);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      // Tap publish button
      final publishBtn = find.textContaining('اعتماد ونشر الامتحان للطلاب الآن');
      expect(publishBtn, findsOneWidget);
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(calledRpcParams, isNotNull);
      expect(calledRpcParams!['p_group_id'], equals('grp-1'));
      expect(calledRpcParams!['p_subject_id'], equals('sub-phys'));
      expect(calledRpcParams!['p_status'], equals('published'));
      expect(publishedExam, isNotNull);
      expect(publishedExam!.id, equals('exam-published-999'));
    });
  });
}
