import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/reports/presentation/screens/attendance_reports_screen.dart';
import 'package:brivio/features/assessment/presentation/widgets/live_blitz_quiz_dialog.dart';

void main() {
  final mockStudentAttendance = [
    {
      'name': 'كريم أحمد حسانين',
      'present': 18,
      'absent': 2,
      'status': 'منتظم',
    },
    {
      'name': 'سلمى مصطفى كامل',
      'present': 14,
      'absent': 6,
      'status': 'منتظم',
    },
    {
      'name': 'عمر شريف الدسوقي',
      'present': 8,
      'absent': 12,
      'status': 'إنذار',
    },
  ];

  final mockTeacherAttendance = [
    {
      'name': 'أ. محمد صلاح الدين',
      'present': 24,
      'absent': 0,
      'status': 'ملتزم',
    },
  ];

  final mockStaffAttendance = [
    {
      'name': 'أ. أحمد طارق (شؤون طلاب)',
      'present': 22,
      'absent': 2,
      'status': 'ملتزم',
    },
  ];

  final mockConnectedStudents = [
    {
      'name': 'زياد أحمد كمال',
      'points': 80,
      'speed': '1.4 ث',
      'avatar': '🥇',
    },
    {
      'name': 'فاطمة محمود إبراهيم',
      'points': 60,
      'speed': '2.1 ث',
      'avatar': '🥈',
    },
  ];

  Widget buildAttendanceTestWidget({
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
          child: AttendanceReportsScreen(
            initialStudentsData: mockStudentAttendance,
            initialTeachersData: mockTeacherAttendance,
            initialStaffData: mockStaffAttendance,
          ),
        ),
      ),
    );
  }

  Widget buildBlitzQuizTestWidget({
    Size screenSize = const Size(375, 812),
    ThemeMode themeMode = ThemeMode.light,
    bool startInLiveMode = false,
    List<Map<String, dynamic>>? connectedStudents,
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
          child: Scaffold(
            body: Center(
              child: LiveBlitzQuizDialog(
                groupName: 'مجموعة النخبة 3 ث',
                subjectName: 'الكيمياء العضوية',
                initialConnectedStudents: connectedStudents ?? mockConnectedStudents,
                autoStartTimer: false,
                startInLiveMode: startInLiveMode,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('AttendanceReportsScreen Responsive & AAA UI Tests', () {
    testWidgets('renders cleanly on small mobile (320px) with 0 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(buildAttendanceTestWidget(screenSize: const Size(320, 700)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('كشوفات وتقارير الحضور والغياب 📋'), findsOneWidget);
      expect(find.text('كشف حضور وانضباط الطلاب'), findsOneWidget);
      expect(find.text('نسبة الحضور العامة'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('كريم أحمد حسانين'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly on standard mobile (375px)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildAttendanceTestWidget(screenSize: const Size(375, 812)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('تصدير كشف حضور الطلاب العام (PDF)'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('سلمى مصطفى كامل'), findsOneWidget);
      expect(find.text('عمر شريف الدسوقي'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders executive grid layout on desktop (1024px+)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(buildAttendanceTestWidget(screenSize: const Size(1024, 768)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('كريم أحمد حسانين'), findsOneWidget);
      expect(find.text('سلمى مصطفى كامل'), findsOneWidget);
      expect(find.byType(SliverGrid), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('search filters students accurately', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildAttendanceTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Search for "سلمى"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'سلمى');
      await tester.pumpAndSettle();

      expect(find.text('سلمى مصطفى كامل'), findsOneWidget);
      expect(find.text('كريم أحمد حسانين'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('filter chips filter attendance commitment groups', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildAttendanceTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Tap low commitment chip "إنذار غياب"
      final lowChip = find.widgetWithText(ChoiceChip, 'إنذار غياب 🔴 (1)');
      expect(lowChip, findsOneWidget);

      await tester.ensureVisible(lowChip);
      await tester.pumpAndSettle();
      await tester.tap(lowChip);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Only "عمر شريف الدسوقي" has rate 8/(8+12) = 40% < 60%
      expect(find.text('عمر شريف الدسوقي'), findsOneWidget);
      expect(find.text('كريم أحمد حسانين'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('individual PDF and parent notice trigger actions smoothly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildAttendanceTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap parent notice button for first student
      final noticeBtn = find.text('إشعار الغياب 📱').first;
      expect(noticeBtn, findsOneWidget);

      await tester.tap(noticeBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('تم إرسال إشعار غياب فوري لولي أمر الطالب'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly in dark theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildAttendanceTestWidget(
        screenSize: const Size(375, 812),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('كريم أحمد حسانين'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });

  group('LiveBlitzQuizDialog Responsive & AAA UI Tests', () {
    testWidgets('renders cleanly in lobby on small mobile (320px) with 0 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(buildBlitzQuizTestWidget(screenSize: const Size(320, 700)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('كويز الـ 5 دقائق التفاعلي ⚡'), findsOneWidget);
      expect(find.text('رمز الانضمام المباشر للطلاب في القاعة 📱'), findsOneWidget);
      expect(find.text('إطلاق كويز الـ 5 دقائق في القاعة 🚀'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly in lobby on standard mobile (375px)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildBlitzQuizTestWidget(screenSize: const Size(375, 812)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('2 طالب متصل وجاهز الآن في القاعة'), findsOneWidget);
      expect(find.text('عدد أسئلة الكويز:'), findsOneWidget);
      expect(find.text('وقت كل سؤال:'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly on desktop (1024px+)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(buildBlitzQuizTestWidget(screenSize: const Size(1024, 768)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('إطلاق كويز الـ 5 دقائق في القاعة 🚀'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('adds demo student when 0 connected students', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildBlitzQuizTestWidget(
        screenSize: const Size(375, 812),
        connectedStudents: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد طلاب متصلين حالياً (0 طلاب)'), findsOneWidget);
      final addDemoBtn = find.text('إضافة طالب تجريبي للتجربة 🧪');
      expect(addDemoBtn, findsOneWidget);

      await tester.tap(addDemoBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('طالب متصل وجاهز الآن في القاعة'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('starts live competition and renders active quiz view with 0 overflow on 320px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(buildBlitzQuizTestWidget(
        screenSize: const Size(320, 700),
        startInLiveMode: true,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('السؤال 1 من'), findsOneWidget);
      expect(find.text('لوحة صدارة المتفوقين في القاعة (Live Top 5) 🏆'), findsOneWidget);
      expect(find.text('زياد أحمد كمال'), findsOneWidget);
      expect(find.text('فاطمة محمود إبراهيم'), findsOneWidget);
      expect(find.text('السؤال التالي ➡️'), findsOneWidget);

      // Advance question
      await tester.tap(find.text('السؤال التالي ➡️'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('السؤال 2 من'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders active quiz flawlessly in dark theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildBlitzQuizTestWidget(
        screenSize: const Size(375, 812),
        themeMode: ThemeMode.dark,
        startInLiveMode: true,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('زياد أحمد كمال'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
