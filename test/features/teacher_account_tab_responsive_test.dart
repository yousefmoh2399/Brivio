import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/teacher/tabs/account_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/core/security/permission_gate.dart';
import 'package:brivio/core/testing/dummy_auth_repository.dart';
import 'package:brivio/features/auth/domain/models/user_profile.dart';
import 'package:brivio/features/auth/domain/models/user_role.dart';
import 'package:brivio/features/auth/presentation/viewmodels/auth_viewmodel.dart';

void main() {
  final testTeacher = UserProfile(
    id: 'teacher-101',
    email: 'dr.hossam@brivio-edu.com',
    fullName: 'أ. د. حسام فتحي',
    role: UserRole.teacher,
    phoneNumber: '01012345678',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget buildTestWidget({
    required Widget child,
    required AuthViewModel authViewModel,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
  }) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith((ref) => authViewModel),
      ],
      child: MaterialApp(
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
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        locale: locale,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Teacher Account Tab Responsive Architecture Tests', () {
    testWidgets('renders on ultra-compact mobile (320px) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = DummyAuthRepository(testTeacher);
      final authVM = AuthViewModel(repo);
      await authVM.restoreSession();

      await tester.pumpWidget(
        buildTestWidget(
          authViewModel: authVM,
          child: AccountTab(
            teacherId: testTeacher.id,
            authViewModel: authVM,
            financeBuilder: (_) => const Text('FINANCE_MOCK_CONTENT'),
            helpdeskBuilder: (_) => const Text('HELPDESK_MOCK_CONTENT'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Hero Header Elements
      expect(find.text('أ. د. حسام فتحي'), findsWidgets);
      expect(find.text('معلم معتمد 🎓'), findsOneWidget);
      expect(find.text('الحساب نشط ومفعل بالسنتر ✨'), findsOneWidget);
      expect(find.textContaining('كود المعلم:'), findsOneWidget);

      // Segment Pills
      expect(find.text('الملف الشخصي'), findsOneWidget);
      expect(find.text('الماليات والمستحقات'), findsOneWidget);
      expect(find.text('الدعم الفني'), findsOneWidget);
      expect(find.text('الإعدادات والأمان'), findsOneWidget);

      // Profile Form Fields
      expect(find.text('الاسم الكامل للمعلم'), findsOneWidget);
      expect(find.text('رقم الهاتف للتواصل'), findsOneWidget);
    });

    testWidgets('standard mobile (375x812): switching segments and logout dialog', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = DummyAuthRepository(testTeacher);
      final authVM = AuthViewModel(repo);
      await authVM.restoreSession();

      await tester.pumpWidget(
        buildTestWidget(
          authViewModel: authVM,
          child: AccountTab(
            teacherId: testTeacher.id,
            authViewModel: authVM,
            financeBuilder: (_) => const Center(child: Text('FINANCE_MOCK_CONTENT')),
            helpdeskBuilder: (_) => const Center(child: Text('HELPDESK_MOCK_CONTENT')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Settings & Security
      final settingsTab = find.text('الإعدادات والأمان');
      await tester.ensureVisible(settingsTab);
      await tester.tap(settingsTab);
      await tester.pumpAndSettle();

      expect(find.text('المظهر والوضع الليلي'), findsOneWidget);
      expect(find.text('الحسابات المحفوظة والتبديل السريع'), findsOneWidget);
      expect(find.text('سياسة الخصوصية وشروط الاستخدام'), findsOneWidget);

      // Verify Logout Dialog by scrolling down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final logoutTile = find.text('خروج');
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الخروج'), findsWidgets);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('تأكيد الخروج'), findsOneWidget);

      // Cancel logout
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('تأكيد الخروج'), findsNothing);

      // Scroll back up
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Switch to Finance tab
      final financeTab = find.text('الماليات والمستحقات');
      await tester.ensureVisible(financeTab);
      await tester.tap(financeTab);
      await tester.pumpAndSettle();
      expect(find.text('FINANCE_MOCK_CONTENT'), findsOneWidget);

      // Switch to Helpdesk tab
      final helpdeskTab = find.text('الدعم الفني');
      await tester.ensureVisible(helpdeskTab);
      await tester.tap(helpdeskTab);
      await tester.pumpAndSettle();
      expect(find.text('HELPDESK_MOCK_CONTENT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('standard mobile (375x812): editing profile fields and submitting form', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = DummyAuthRepository(testTeacher);
      final authVM = AuthViewModel(repo);
      await authVM.restoreSession();

      await tester.pumpWidget(
        buildTestWidget(
          authViewModel: authVM,
          child: AccountTab(
            teacherId: testTeacher.id,
            authViewModel: authVM,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find full name input and update it
      final nameInput = find.widgetWithText(TextFormField, 'أ. د. حسام فتحي');
      expect(nameInput, findsOneWidget);
      await tester.enterText(nameInput, 'أ. د. حسام فتحي المحترم');
      await tester.pumpAndSettle();

      // Submit form
      final saveButton = find.text('حفظ تعديلات الملف الشخصي');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop viewport (1024x768): renders side-by-side 2-column layout with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = DummyAuthRepository(testTeacher);
      final authVM = AuthViewModel(repo);
      await authVM.restoreSession();

      await tester.pumpWidget(
        buildTestWidget(
          authViewModel: authVM,
          child: AccountTab(
            teacherId: testTeacher.id,
            authViewModel: authVM,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Both columns should be visible in desktop viewport
      expect(find.text('البيانات الأساسية للمعلم'), findsOneWidget);
      expect(find.text('بيانات واعتماد حساب المعلم'), findsOneWidget);
      expect(find.text('البريد الإلكتروني المعتمد'), findsOneWidget);
      expect(find.text('الصلاحيات الأكاديمية النشطة'), findsOneWidget);
    });

    testWidgets('dark theme mode: renders with high contrast and zero overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = DummyAuthRepository(testTeacher);
      final authVM = AuthViewModel(repo);
      await authVM.restoreSession();

      await tester.pumpWidget(
        buildTestWidget(
          authViewModel: authVM,
          themeMode: ThemeMode.dark,
          child: AccountTab(
            teacherId: testTeacher.id,
            authViewModel: authVM,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('أ. د. حسام فتحي'), findsWidgets);
      expect(find.text('معلم معتمد 🎓'), findsOneWidget);
    });
  });
}
