import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/parent/tabs/parent_account_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/auth/domain/models/user_profile.dart';
import 'package:brivio/features/auth/domain/models/user_role.dart';
import 'package:brivio/features/payments/domain/models/payment_models.dart';

void main() {
  final sampleProfile = UserProfile(
    id: 'parent-usr-7711',
    fullName: 'المستشار محمد القاضي',
    email: 'mohamed.elkadi@brivio.edu',
    phoneNumber: '01012345678',
    avatarUrl: null,
    role: UserRole.parent,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  const sampleChild1 = Student(
    id: 'std-101',
    profileId: 'prof-101',
    studentCode: 'BRV-7711',
    primaryBranchId: 'branch-1',
    status: 'active',
    fullName: 'يوسف محمد القاضي',
    email: 'yousef@brivio.edu',
  );

  const sampleChild2 = Student(
    id: 'std-102',
    profileId: 'prof-102',
    studentCode: 'BRV-8822',
    primaryBranchId: 'branch-1',
    status: 'active',
    fullName: 'مريم محمد القاضي',
    email: 'mariam@brivio.edu',
  );

  final List<GroupEntity> sampleGroups = [
    const GroupEntity(
      id: 'grp-phys-3',
      name: 'الفيزياء 3ث - أ. أحمد فتحي',
      code: 'PHYS-3',
      subjectId: 'sub-phys',
      branchId: 'branch-1',
      teacherId: 'tch-1',
      status: 'active',
    ),
  ];

  final sampleFinancialSummary = FinancialSummary(
    studentId: 'std-101',
    invoiceCount: 3,
    totalDueMinor: 250000,
    totalPaidMinor: 175000,
    remainingBalanceMinor: 75000,
    currency: 'EGP',
  );

  final now = DateTime.now();

  final sampleInvoices = [
    Invoice(
      id: 'inv-1',
      invoiceNumber: 'INV-2026-001',
      studentId: 'std-101',
      subtotalMinor: 150000,
      totalMinor: 150000,
      amountPaidMinor: 150000,
      status: 'paid',
      dueAt: now.subtract(const Duration(days: 30)),
      issuedAt: now.subtract(const Duration(days: 35)),
    ),
    Invoice(
      id: 'inv-2',
      invoiceNumber: 'INV-2026-002',
      studentId: 'std-101',
      subtotalMinor: 100000,
      totalMinor: 100000,
      amountPaidMinor: 25000,
      status: 'partially_paid',
      dueAt: now.add(const Duration(days: 5)),
      issuedAt: now.subtract(const Duration(days: 10)),
    ),
  ];

  final sampleReceipts = [
    Receipt(
      id: 'rec-1',
      receiptNumber: 'REC-2026-881',
      transactionId: 'txn-1',
      invoiceId: 'inv-1',
      studentId: 'std-101',
      amountMinor: 150000,
      currency: 'EGP',
      issuedAt: now.subtract(const Duration(days: 28)),
    ),
  ];

  Widget createTestWidget({
    required Size screenSize,
    UserProfile? profile,
    Student? selectedChild,
    List<Student>? linkedChildren,
    FinancialSummary? financialSummary,
    List<Invoice>? invoices,
    List<Receipt>? receipts,
    ValueChanged<Student>? onChildSelected,
    VoidCallback? onLinkNewChild,
    VoidCallback? onSignOut,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Cairo',
        useMaterial3: true,
        brightness: brightness,
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          textScaler: const TextScaler.linear(1.0),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ParentAccountTab(
              profile: profile ?? sampleProfile,
              selectedChild: selectedChild ?? sampleChild1,
              linkedChildren: linkedChildren ?? [sampleChild1, sampleChild2],
              financialSummary: financialSummary ?? sampleFinancialSummary,
              invoices: invoices ?? sampleInvoices,
              receipts: receipts ?? sampleReceipts,
              childGroups: sampleGroups,
              unreadCount: 3,
              onChildSelected: onChildSelected,
              onLinkNewChild: onLinkNewChild,
              onSignOut: onSignOut,
            ),
          ),
        ),
      ),
    );
  }

  group('ParentAccountTab Responsiveness & Comprehensive Functionality Tests', () {
    setUp(() {
      FlutterError.onError = (details) {
        debugPrint('FLUTTER_ERROR_DETAILS: ${details.exceptionAsString()}');
        debugPrint('STACK / INFORMATION: ${details.informationCollector?.call().map((e) => e.toString()).join('\n')}');
      };
    });
    testWidgets(
      'renders with zero RenderFlex overflow on narrow 320x640 mobile screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(320, 640)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ParentAccountTab), findsOneWidget);
        expect(find.text('المستشار محمد القاضي'), findsAtLeastNWidgets(1));
        expect(find.text('ولي أمر معتمد 🛡️'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'segmented navigation switches between profile, children, finance, and settings on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(375, 812)),
        );
        await tester.pumpAndSettle();

        // 1. Initial tab: الملف والأمان
        expect(find.text('البيانات الشخصية لولي الأمر'), findsOneWidget);
        expect(find.text('الأمان وتغيير كلمة المرور'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Tab 1 Profile overflowed');

        // 2. Switch to إدارة الأبناء
        await tester.ensureVisible(find.text('إدارة الأبناء'));
        await tester.tap(find.text('إدارة الأبناء'));
        await tester.pumpAndSettle();

        expect(find.text('الطلاب المرتبطين بحسابك (2)'), findsOneWidget);
        expect(find.text('يوسف محمد القاضي'), findsOneWidget);
        expect(find.text('مريم محمد القاضي'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Tab 2 Children overflowed');

        // 3. Switch to المحفظة العائلية
        await tester.ensureVisible(find.text('المحفظة العائلية'));
        await tester.tap(find.text('المحفظة العائلية'));
        await tester.pumpAndSettle();

        expect(find.text('ملخص المحفظة العائلية المجمعة'), findsOneWidget);
        expect(find.text('فاتورة #INV-2026-001'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Tab 3 Finance overflowed');

        // 4. Switch to التفضيلات والنظام
        await tester.ensureVisible(find.text('التفضيلات والنظام'));
        await tester.tap(find.text('التفضيلات والنظام'));
        await tester.pumpAndSettle();

        expect(find.text('المظهر واللغة والإشعارات'), findsOneWidget);
        expect(find.text('تسجيل الخروج من الحساب'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Tab 4 Settings overflowed');
      },
    );

    testWidgets(
      'children management view lists students and invokes onChildSelected callback',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        Student? selectedStudent;

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            onChildSelected: (child) => selectedStudent = child,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to children tab
        await tester.ensureVisible(find.text('إدارة الأبناء'));
        await tester.tap(find.text('إدارة الأبناء'));
        await tester.pumpAndSettle();

        expect(find.text('المحدد حالياً'), findsOneWidget);
        expect(find.text('تحديد للمتابعة 🔄'), findsOneWidget);

        // Tap switch to child 2
        await tester.ensureVisible(find.text('تحديد للمتابعة 🔄'));
        await tester.tap(find.text('تحديد للمتابعة 🔄'));
        await tester.pumpAndSettle();

        expect(selectedStudent, isNotNull);
        expect(selectedStudent!.id, 'std-102');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'family finance view toggles between invoices and receipts',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(375, 812)),
        );
        await tester.pumpAndSettle();

        // Navigate to finance tab
        await tester.ensureVisible(find.text('المحفظة العائلية'));
        await tester.tap(find.text('المحفظة العائلية'));
        await tester.pumpAndSettle();

        // Invoices list displayed initially
        expect(find.text('فاتورة #INV-2026-001'), findsOneWidget);

        // Toggle to receipts
        await tester.ensureVisible(find.text('الإيصالات (1)'));
        await tester.tap(find.text('الإيصالات (1)'));
        await tester.pumpAndSettle();

        expect(find.text('إيصال #REC-2026-881'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'settings view opens confirmation dialog upon tapping sign out',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool signedOut = false;

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            onSignOut: () => signedOut = true,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to settings tab
        await tester.ensureVisible(find.text('التفضيلات والنظام'));
        await tester.tap(find.text('التفضيلات والنظام'));
        await tester.pumpAndSettle();

        // Tap sign out button
        await tester.ensureVisible(find.text('تسجيل الخروج من الحساب'));
        await tester.tap(find.text('تسجيل الخروج من الحساب'));
        await tester.pumpAndSettle();

        // Dialog should be visible
        expect(find.text('هل أنت متأكد من رغبتك في تسجيل الخروج من حساب ولي الأمر على هذا الجهاز؟'), findsOneWidget);
        expect(find.text('نعم، تسجيل الخروج'), findsOneWidget);
        expect(find.text('إلغاء'), findsOneWidget);

        // Tap confirm in dialog
        await tester.tap(find.text('نعم، تسجيل الخروج'));
        await tester.pumpAndSettle();

        expect(signedOut, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'empty states display gracefully when no children or invoices exist',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            linkedChildren: [],
            invoices: [],
            receipts: [],
          ),
        );
        await tester.pumpAndSettle();

        // Check children tab empty state
        await tester.ensureVisible(find.text('إدارة الأبناء'));
        await tester.tap(find.text('إدارة الأبناء'));
        await tester.pumpAndSettle();

        expect(find.text('لا يوجد طلاب مرتبطين بحسابك حالياً'), findsOneWidget);
        expect(find.text('ربط طالب جديد بالكود'), findsOneWidget);

        // Check finance tab empty state
        await tester.ensureVisible(find.text('المحفظة العائلية'));
        await tester.tap(find.text('المحفظة العائلية'));
        await tester.pumpAndSettle();

        expect(find.text('لا توجد فواتير مسجلة حالياً'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders with zero RenderFlex overflow on wide tablet/desktop 1024x768 screen',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(1024, 768)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ParentAccountTab), findsOneWidget);
        expect(find.text('المستشار محمد القاضي'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
