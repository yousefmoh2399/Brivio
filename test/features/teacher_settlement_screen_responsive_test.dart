import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/payments/presentation/screens/teacher_settlement_screen.dart';

void main() {
  final testTeacher = Teacher(
    id: 't-101',
    profileId: 'p-101',
    primaryBranchId: 'b-101',
    fullName: 'أ. محمد صلاح الدين',
    email: 'm.salah@brivio.com',
    phoneNumber: '01012345678',
    status: 'active',
  );

  final testGroup = GroupEntity(
    id: 'g-101',
    name: 'مجموعة العباقرة - فيزياء 3 ث',
    code: 'GRP-PHYS-01',
    subjectId: 'sub-phys',
    branchId: 'b-101',
    teacherId: 't-101',
    status: 'active',
  );

  Widget buildTestWidget({
    Size screenSize = const Size(375, 812),
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Cairo',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Cairo',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      locale: const Locale('ar'),
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: TeacherSettlementScreen(
            initialTeachers: [testTeacher],
            initialGroups: [testGroup],
            initialSelectedTeacher: testTeacher,
            initialSelectedGroup: testGroup,
            initialCenterName: 'أكاديمية المتفوقين النموذجية',
          ),
        ),
      ),
    );
  }

  group('TeacherSettlementScreen Responsive & AAA UI Tests', () {
    testWidgets('renders cleanly on small mobile (320px) with 0 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(buildTestWidget(screenSize: const Size(320, 700)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('حاسبة وتصفية أرباح المدرسين والسنتر'), findsOneWidget);
      expect(find.text('أ. محمد صلاح الدين'), findsWidgets);
      expect(find.textContaining('صافي مستحق المدرس'), findsWidgets);
      expect(find.text('جاهز للصرف ✨'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly on standard mobile (375px) with 0 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildTestWidget(screenSize: const Size(375, 812)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('معايير ونسب الحصة'), findsOneWidget);
      expect(find.text('بيانات المدرس والمجموعة'), findsOneWidget);
      expect(find.text('الملخص المالي للتصفية'), findsOneWidget);
      expect(find.textContaining('صرف وتوثيق التصفية'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders executive 2-column layout on desktop (1024px+)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(buildTestWidget(screenSize: const Size(1024, 768)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('أكاديمية المتفوقين النموذجية'), findsOneWidget);
      expect(find.text('معاينة وطباعة الإيصال'), findsOneWidget);
      expect(find.text('مشاركة نص الإيصال'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('quick split presets update percentages and recalculate payouts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Find the preset chip for 80/20
      final preset8020 = find.text('80% مدرس / 20% سنتر');
      expect(preset8020, findsOneWidget);

      await tester.ensureVisible(preset8020);
      await tester.pumpAndSettle();
      await tester.tap(preset8020);
      await tester.pumpAndSettle();

      // 25 students * 75 EGP = 1875 EGP revenue. 80% = 1500 EGP
      expect(find.textContaining('1500.0 ج.م'), findsWidgets);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders flawlessly in dark theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildTestWidget(
        screenSize: const Size(375, 812),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('صافي مستحق المدرس'), findsWidgets);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
