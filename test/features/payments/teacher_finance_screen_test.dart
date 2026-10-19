import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/payments/presentation/screens/teacher_finance_screen.dart';

void main() {
  group('TeacherFinanceScreen Viewport & Unbounded Layout Tests', () {
    testWidgets('renders cleanly inside unbounded SliverToBoxAdapter without viewport exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: const TeacherFinanceScreen(
                    teacherId: 'teacher-test-123',
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify no assertion was thrown during performResize
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto-detects unbounded parent height and prevents viewport crash even with default args', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: const TeacherFinanceScreen(
                    teacherId: 'teacher-test-auto',
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify LayoutBuilder automatically set shouldShrinkWrap to true and prevented crash
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders properly in bounded standalone Scaffold', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeacherFinanceScreen(
              teacherId: 'teacher-test-standalone',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
