import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/reports/presentation/screens/groups_schedules_report_screen.dart';
import 'package:brivio/features/reports/presentation/viewmodels/groups_schedules_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GroupsSchedulesViewModel Unit Tests', () {
    test('formatDayOfWeek properly formats Arabic and English day representations', () {
      expect(GroupsSchedulesViewModel.formatDayOfWeek(6), equals('السبت'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek('6'), equals('السبت'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek(7), equals('الأحد'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek(0), equals('الأحد'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek(1), equals('الإثنين'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek(2), equals('الثلاثاء'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek(3), equals('الأربعاء'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek(4), equals('الخميس'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek(5), equals('الجمعة'));

      // English string checks
      expect(GroupsSchedulesViewModel.formatDayOfWeek('saturday'), equals('السبت'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek('Sunday'), equals('الأحد'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek('Monday'), equals('الإثنين'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek('Tuesday'), equals('الثلاثاء'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek('Wednesday'), equals('الأربعاء'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek('Thursday'), equals('الخميس'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek('Friday'), equals('الجمعة'));
      expect(GroupsSchedulesViewModel.formatDayOfWeek(null), equals(''));
    });

    test('formatTime properly formats 24h string into Arabic 12h format', () {
      expect(GroupsSchedulesViewModel.formatTime('10:00:00'), equals('10:00 ص'));
      expect(GroupsSchedulesViewModel.formatTime('14:30:00'), equals('2:30 م'));
      expect(GroupsSchedulesViewModel.formatTime('12:00:00'), equals('12:00 م'));
      expect(GroupsSchedulesViewModel.formatTime('00:00:00'), equals('12:00 ص'));
      expect(GroupsSchedulesViewModel.formatTime('18:05'), equals('6:05 م'));
      expect(GroupsSchedulesViewModel.formatTime(null), equals(''));
      expect(GroupsSchedulesViewModel.formatTime(''), equals(''));
    });
  });

  group('GroupsSchedulesReportScreen UI Tests', () {
    testWidgets('renders cleanly on mobile viewport (360x640) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: GroupsSchedulesReportScreen(
            teacherId: 'teacher-test-id',
          ),
        ),
      );

      // Verify header, search bar, and filter chips appear
      expect(find.text('تقرير المجموعات والجداول 📅'), findsOneWidget);
      expect(find.text('المجموعات الدراسية ومواعيد الحصص'), findsOneWidget);
      expect(find.text('إجمالي المجموعات'), findsOneWidget);
      expect(find.text('مجموعات نشطة'), findsOneWidget);
      expect(find.text('مجموعات متوقفة'), findsOneWidget);
      expect(find.textContaining('الكل'), findsOneWidget);
    });

    testWidgets('renders cleanly on desktop viewport (1024x768)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: GroupsSchedulesReportScreen(),
        ),
      );

      expect(find.text('تقرير المجموعات والجداول 📅'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
    });
  });
}
