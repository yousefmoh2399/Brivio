import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/study_workspace/presentation/screens/study_replay_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudyReplayScreen Layout and Responsive Tests', () {
    testWidgets('renders cleanly when isEmbedded: true on compact viewport (640x480) without overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudyReplayScreen(
              teacherId: 'teacher-123',
              isEmbedded: true,
            ),
          ),
        ),
      );

      // Verify KPI metrics ribbon rendered without exception
      expect(find.text('إجمالي الجلسات المسجلة'), findsOneWidget);
      expect(find.text('إجمالي ساعات المذاكرة'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on phone viewport (360x640) in embedded mode', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudyReplayScreen(
              teacherId: 'teacher-123',
              isEmbedded: true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly in standalone mode (PortalPageShell) on desktop', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudyReplayScreen(
              teacherId: 'teacher-123',
              isEmbedded: false,
            ),
          ),
        ),
      );

      expect(find.text('تسجيلات الحصص ومسارات المذاكرة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
