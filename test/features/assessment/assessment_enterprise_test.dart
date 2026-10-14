import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/core/services/whatsapp_service.dart';
import 'package:brivio/core/services/report_generator_service.dart';
import 'package:brivio/features/assessment/domain/models/assessment_models.dart';
import 'package:brivio/features/assessment/presentation/screens/assessment_screens.dart';

void main() {
  group('Enterprise Exam & Homework Tests', () {
    test('WhatsAppService formats Egyptian numbers correctly', () {
      expect(WhatsAppService.formatEgyptianNumber('01012345678'), equals('201012345678'));
      expect(WhatsAppService.formatEgyptianNumber('+201123456789'), equals('201123456789'));
      expect(WhatsAppService.formatEgyptianNumber('012-3456-7890'), equals('201234567890'));
      expect(WhatsAppService.formatEgyptianNumber('01555555555'), equals('201555555555'));
    });

    test('ReportGeneratorService generates Homework PDF sheets without error', () async {
      final reportService = ReportGeneratorService();

      // Test Homework Roster PDF generation (does not throw)
      expect(
        () async => await reportService.generateHomeworkSubmissionsRosterPdf(
          centerName: 'سنتر الأوائل التعليمي',
          teacherName: 'أ. محمد عبد الله',
          groupName: 'ثانوية عامة - لغات A',
          subjectName: 'فيزياء',
          homeworkTitle: 'واجب قانون كيرشوف وقانون أوم',
          dueAt: DateTime.now().add(const Duration(days: 1)),
          maxScore: 20.0,
          submissionsData: [
            {
              'student_name': 'عمر أحمد محمود',
              'student_code': 'STU-101',
              'student_phone': '01011111111',
              'parent_phone': '01022222222',
              'is_submitted': true,
              'submitted_at': '2026-10-12 18:30',
              'score': 18.5,
              'feedback': 'ممتاز جداً، إجابات نموذجية',
            },
            {
              'student_name': 'سارة إبراهيم علي',
              'student_code': 'STU-102',
              'student_phone': '01133333333',
              'parent_phone': '01144444444',
              'is_submitted': false,
              'score': null,
              'feedback': null,
            },
          ],
        ),
        returnsNormally,
      );

      // Test Printable Homework Sheet PDF generation (does not throw)
      expect(
        () async => await reportService.generatePrintableHomeworkSheet(
          centerName: 'سنتر الأوائل التعليمي',
          teacherName: 'أ. محمد عبد الله',
          groupName: 'ثانوية عامة - لغات A',
          subjectName: 'فيزياء',
          homeworkTitle: 'شيت واجب أسبوعي: الدوائر الكهربية',
          dueAt: DateTime.now().add(const Duration(days: 3)),
          maxScore: 20.0,
          questions: [
            {
              'prompt': 'ما هي وحدة قياس المقاومة النوعية؟',
              'default_points': 2.0,
              'question_type': 'multiple_choice',
              'options': [
                {'text': 'أوم.متر', 'is_correct': true},
                {'text': 'أوم / متر', 'is_correct': false},
              ],
            },
            {
              'prompt': 'اذكر العوامل التي تتوقف عليها المقاومة الكهربية لسلك معدني.',
              'default_points': 3.0,
              'question_type': 'short_answer',
              'options': <Map<String, dynamic>>[],
            },
          ],
        ),
        returnsNormally,
      );
    });

    testWidgets('ExamRunnerScreen supports question palette and flag for review', (
      WidgetTester tester,
    ) async {
      final questions = [
        Question(
          id: 'q-1',
          subjectId: 'sub-1',
          questionType: QuestionType.multipleChoice,
          prompt: 'السؤال الأول: عاصمة مصر؟',
          defaultPoints: 5.0,
          options: [
            QuestionOption(id: 'o-1', questionId: 'q-1', text: 'القاهرة', isCorrect: true),
            QuestionOption(id: 'o-2', questionId: 'q-1', text: 'الإسكندرية', isCorrect: false),
          ],
        ),
        Question(
          id: 'q-2',
          subjectId: 'sub-1',
          questionType: QuestionType.trueFalse,
          prompt: 'السؤال الثاني: تقع مصر في قارة أفريقيا.',
          defaultPoints: 5.0,
          options: const [],
        ),
        Question(
          id: 'q-3',
          subjectId: 'sub-1',
          questionType: QuestionType.shortAnswer,
          prompt: 'السؤال الثالث: اشرح باختصار أهمية نهر النيل.',
          defaultPoints: 10.0,
          options: const [],
        ),
      ];

      final exam = Exam(
        id: 'exam-100',
        title: 'امتحان الجغرافيا الشامل',
        subjectId: 'sub-1',
        durationMinutes: 60,
        questions: questions,
      );

      final attempt = ExamAttempt(
        id: 'att-100',
        examId: 'exam-100',
        studentId: 'stu-100',
        startedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 60)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExamRunnerScreen(exam: exam, attempt: attempt),
        ),
      );

      // Verify exam header and title
      expect(find.text('امتحان الجغرافيا الشامل'), findsOneWidget);
      expect(find.text('السؤال الأول: عاصمة مصر؟'), findsOneWidget);
      expect(find.text('القاهرة'), findsOneWidget);

      // Verify Flag for review toggle button exists
      final flagTextFinder = find.text('تمييز');
      expect(flagTextFinder, findsOneWidget);

      // Toggle flag
      await tester.tap(flagTextFinder);
      await tester.pumpAndSettle();
      expect(find.text('مميز للمراجعة'), findsOneWidget);

      // Open Question Palette via appbar action
      final paletteFinder = find.byTooltip('لوحة الأسئلة');
      expect(paletteFinder, findsOneWidget);
      await tester.tap(paletteFinder);
      await tester.pumpAndSettle();

      // Verify bottom sheet title is shown
      expect(find.text('جدول الانتقال السريع بين الأسئلة 🔢'), findsOneWidget);

      // Close bottom sheet
      final closeIcon = find.byIcon(Icons.close_rounded);
      expect(closeIcon, findsOneWidget);
      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      // Navigate to Next question (Question 2: True/False)
      final nextBtn = find.text('Next');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Check True/False UI
      expect(find.text('السؤال الثاني: تقع مصر في قارة أفريقيا.'), findsOneWidget);
      expect(find.textContaining('صواب (True)'), findsOneWidget);
      expect(find.textContaining('خطأ (False)'), findsOneWidget);

      // Select 'صواب'
      await tester.tap(find.textContaining('صواب (True)'));
      await tester.pumpAndSettle();

      // Navigate to Next question (Question 3: Short Answer)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('السؤال الثالث: اشرح باختصار أهمية نهر النيل.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('HomeworkRunnerScreen renders multi-type question navigation and deadline', (
      WidgetTester tester,
    ) async {
      final questions = [
        Question(
          id: 'hw-q-1',
          subjectId: 'sub-1',
          questionType: QuestionType.multipleChoice,
          prompt: 'حل المعادلة: 2x = 10',
          defaultPoints: 5.0,
          options: [
            QuestionOption(id: 'o-1', questionId: 'hw-q-1', text: 'x = 5', isCorrect: true),
            QuestionOption(id: 'o-2', questionId: 'hw-q-1', text: 'x = 20', isCorrect: false),
          ],
        ),
      ];

      final homework = Homework(
        id: 'hw-100',
        title: 'واجب الجبر الأسبوعي',
        subjectId: 'sub-1',
        groupId: 'grp-1',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        questions: questions,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeworkRunnerScreen(
            homework: homework,
          ),
        ),
      );

      expect(find.text('واجب الجبر الأسبوعي'), findsOneWidget);
      expect(find.text('حل المعادلة: 2x = 10'), findsOneWidget);
      expect(find.text('x = 5'), findsOneWidget);
      expect(find.text('Submit Homework'), findsOneWidget);
    });
  });
}
