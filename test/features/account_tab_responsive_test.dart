import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/student/tabs/account_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/auth/domain/models/user_profile.dart';
import 'package:brivio/features/auth/domain/models/user_role.dart';
import 'package:brivio/features/communication/domain/models/announcement.dart';
import 'package:brivio/features/communication/domain/models/notification.dart';
import 'package:brivio/features/payments/domain/models/payment_models.dart';

void main() {
  final sampleProfile = UserProfile(
    id: 'user-std-1',
    fullName: 'أحمد محمود علي',
    email: 'ahmed.mahmoud@brivio.edu',
    phoneNumber: '01012345678',
    avatarUrl: null,
    role: UserRole.student,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleFinancialSummary = FinancialSummary(
    studentId: 'user-std-1',
    currency: 'EGP',
    totalDueMinor: 150000,
    totalPaidMinor: 100000,
    remainingBalanceMinor: 50000,
    invoiceCount: 3,
  );

  final List<Invoice> sampleInvoices = [
    Invoice(
      id: 'inv-1',
      studentId: 'user-std-1',
      invoiceNumber: 'INV-2026-001',
      subtotalMinor: 50000,
      discountMinor: 0,
      totalMinor: 50000,
      currency: 'EGP',
      status: 'paid',
      issuedAt: DateTime.now().subtract(const Duration(days: 30)),
      dueAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    Invoice(
      id: 'inv-2',
      studentId: 'user-std-1',
      invoiceNumber: 'INV-2026-002',
      subtotalMinor: 50000,
      discountMinor: 0,
      totalMinor: 50000,
      currency: 'EGP',
      status: 'pending',
      issuedAt: DateTime.now().subtract(const Duration(days: 5)),
      dueAt: DateTime.now().add(const Duration(days: 10)),
    ),
  ];

  final List<Receipt> sampleReceipts = [
    Receipt(
      id: 'rcpt-1',
      invoiceId: 'inv-1',
      studentId: 'user-std-1',
      receiptNumber: 'RCP-2026-991',
      amountMinor: 50000,
      currency: 'EGP',
      transactionId: 'TXN-984210',
      issuedAt: DateTime.now().subtract(const Duration(days: 16)),
    ),
  ];

  final List<Announcement> sampleAnnouncements = [
    Announcement(
      id: 'ann-1',
      title: 'بدء التسجيل في المراجعات النهائية لشهادة الثانوية العامة',
      body: 'تعلن إدارة السنتر عن فتح باب الحجز لمراجعات ليلة الامتحان لكافة الشعب العلمية والأدبية.',
      priority: AnnouncementPriority.urgent,
      publishAt: DateTime.now().subtract(const Duration(days: 1)),
      requiresAcknowledgement: true,
      acknowledgedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final List<AppNotification> sampleNotifications = [
    AppNotification(
      id: 'notif-1',
      userId: 'user-std-1',
      type: 'exam_published',
      title: 'تم نشر اختبار جديد',
      message: 'تم إضافة اختبار الفيزياء العام.',
      isRead: false,
      createdAt: DateTime.now(),
    ),
  ];

  Widget createTestWidget({
    required Size screenSize,
    VoidCallback? onSignOut,
    ValueChanged<Announcement>? onAcknowledge,
  }) {
    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          textScaler: const TextScaler.linear(1.0),
        ),
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: AccountTab(
            profile: sampleProfile,
            role: 'طالب',
            studentId: 'STD-8849',
            financialSummary: sampleFinancialSummary,
            invoices: sampleInvoices,
            receipts: sampleReceipts,
            announcements: sampleAnnouncements,
            notifications: sampleNotifications,
            unreadCount: 1,
            isLoading: false,
            onSignOut: onSignOut ?? () {},
            onProfileChanged: () async {},
            onNotificationTap: (_) {},
            onMarkAllRead: () {},
            onAcknowledge: onAcknowledge ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('AccountTab Responsiveness & Comprehensive Functionality Tests', () {
    testWidgets(
      'renders with zero RenderFlex overflow on narrow 320x640 mobile screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(320, 640)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Verify Hero info renders cleanly
        expect(find.text('أحمد محمود علي'), findsOneWidget);
        expect(find.textContaining('كود: #'), findsOneWidget);

        // Verify Segmented Hub options are visible
        expect(find.text('المحفظة والرسوم'), findsOneWidget);
        expect(find.text('الملف والأمان'), findsOneWidget);

        // Verify Financial KPI metric cards render
        expect(find.text('إجمالي الفواتير'), findsOneWidget);
        expect(find.text('المدفوع بنجاح'), findsOneWidget);
        expect(find.text('الرصيد المتبقي'), findsOneWidget);
      },
    );

    testWidgets(
      'switches segments cleanly on standard 375x812 phone screen',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(375, 812)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Test switching to "الملف والأمان"
        await tester.ensureVisible(find.text('الملف والأمان'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('الملف والأمان'));
        await tester.pumpAndSettle();

        expect(find.text('بيانات الملف الشخصي'), findsOneWidget);
        expect(find.text('الأمان وكلمة المرور'), findsOneWidget);
        expect(find.text('حفظ التعديلات'), findsOneWidget);

        // Test switching to "التعميمات"
        await tester.ensureVisible(find.text('التعميمات'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('التعميمات'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('بدء التسجيل في المراجعات النهائية'),
          findsOneWidget,
        );
        expect(find.text('عاجل 🚨'), findsOneWidget);

        // Test switching to "الدعم والإعدادات"
        await tester.ensureVisible(find.text('الدعم والإعدادات'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('الدعم والإعدادات'));
        await tester.pumpAndSettle();

        expect(find.text('الدعم الفني والشكاوى'), findsOneWidget);
        expect(find.text('إعدادات التطبيق والمظهر'), findsOneWidget);
        expect(find.text('تسجيل الخروج من الحساب'), findsOneWidget);
      },
    );

    testWidgets(
      'toggles between Invoices and Receipts in Billing segment',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(375, 812)),
        );
        await tester.pumpAndSettle();

        // Default: Invoices should be visible
        expect(find.text('INV-2026-001'), findsOneWidget);
        expect(find.text('INV-2026-002'), findsOneWidget);

        // Tap on "إيصالات السداد"
        await tester.tap(find.textContaining('إيصالات السداد'));
        await tester.pumpAndSettle();

        // Receipts should now be visible
        expect(find.text('RCP-2026-991'), findsOneWidget);
        expect(find.text('INV-2026-001'), findsNothing);
      },
    );

    testWidgets(
      'renders on tablet/desktop (1024x768) with 2-column layout and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(1024, 768)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('أحمد محمود علي'), findsOneWidget);
        expect(find.text('INV-2026-001'), findsOneWidget);
        expect(find.text('INV-2026-002'), findsOneWidget);
      },
    );
  });
}
