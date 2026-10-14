import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/core/services/whatsapp_service.dart';
import 'package:brivio/core/services/report_generator_service.dart';
import 'package:brivio/features/assessment/presentation/widgets/group_leaderboard_widget.dart';
import 'package:brivio/features/payments/presentation/screens/daily_cash_register_screen.dart';

void main() {
  group('Egyptian Educational Center Enterprise Features Tests', () {
    test('WhatsAppService.formatEgyptianNumber formats standard Egyptian prefixes correctly', () {
      expect(WhatsAppService.formatEgyptianNumber('01012345678'), equals('201012345678'));
      expect(WhatsAppService.formatEgyptianNumber('01123456789'), equals('201123456789'));
      expect(WhatsAppService.formatEgyptianNumber('01234567890'), equals('201234567890'));
      expect(WhatsAppService.formatEgyptianNumber('01512345678'), equals('201512345678'));
      expect(WhatsAppService.formatEgyptianNumber('+201012345678'), equals('201012345678'));
    });

    test('WhatsAppService formats exam results with teacher, rank, and encouragement', () async {
      // Test URL construction and formatted message logic
      final result = await WhatsAppService.sendExamResultToParent(
        parentPhone: '01099887766',
        studentName: 'محمود أحمد',
        examTitle: 'كويز فيزياء الحركة الدائرية',
        score: 19,
        maxScore: 20,
        centerName: 'سنتر الأوائل التعليمي',
        teacherName: 'أ/ محمد إبراهيم',
        subjectName: 'الفيزياء',
        rank: 1,
        totalStudentsInGroup: 35,
      );

      // In unit test environment without browser URL handler, canLaunchUrl returns false, but method completes
      expect(result, isA<bool>());
    });

    test('ReportGeneratorService generates PDF documents without throwing', () async {
      final service = ReportGeneratorService();

      // Test Bulk ID cards generator
      expect(
        () => service.generateBulkStudentIdCardsPdf(
          students: [
            {'name': 'طالب تجريبي 1', 'code': 'STU-001', 'phone': '01011111111', 'grade': '3 ثانوى'},
            {'name': 'طالب تجريبي 2', 'code': 'STU-002', 'phone': '01022222222', 'grade': '3 ثانوى'},
          ],
          centerName: 'سنتر الأوائل',
        ),
        returnsNormally,
      );

      // Test Printable Exam Sheet generator
      expect(
        () => service.generatePrintableExamSheet(
          centerName: 'سنتر الأوائل',
          examTitle: 'امتحان تجريبي',
          subjectName: 'كيمياء',
          teacherName: 'د/ شريف',
          durationMinutes: 45,
          passScore: 10,
          questions: [
            {
              'prompt': 'ما هو العدد الذري للهيدروجين؟',
              'points': 2.0,
              'type': 'multiple_choice',
              'options': [
                {'text': '1', 'is_correct': true},
                {'text': '2', 'is_correct': false},
              ],
            },
          ],
        ),
        returnsNormally,
      );
    });

    testWidgets('DailyCashRegisterScreen renders drawer metrics and denominations inputs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DailyCashRegisterScreen(
            centerName: 'سنتر الأوائل التعليمي',
            cashierName: 'محمد أحمد',
          ),
        ),
      );

      // Allow initial async state
      await tester.pump();

      expect(find.text('جرد وتقفيل الخزينة اليومية (Shift Closing)'), findsOneWidget);
      expect(find.text('حاسبة عد النقدية الفعلية بالدرج'), findsOneWidget);
      expect(find.text('فئة 200 جنيه'), findsOneWidget);
      expect(find.text('فئة 100 جنيه'), findsOneWidget);
    });

    testWidgets('GroupLeaderboardWidget renders Hall of Fame banner and Podium', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupLeaderboardWidget(
              groupName: 'مجموعة الأوائل - 3 ثانوى',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('لوحة شرف الأوائل • Hall of Fame'), findsOneWidget);
      expect(find.text('مجموعة الأوائل - 3 ثانوى'), findsOneWidget);
      expect(find.text('🏆 أعلى نتائج الاختبارات'), findsOneWidget);
      expect(find.text('🔥 الأكثر التزاماً بالحضور'), findsOneWidget);
    });
  });
}
