import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brivio/core/services/saved_accounts_service.dart';
import 'package:brivio/design_system/components/buttons.dart';
import 'package:brivio/features/auth/domain/models/auth_user_bootstrap.dart';
import 'package:brivio/features/auth/domain/models/user_profile.dart';
import 'package:brivio/features/auth/domain/models/user_role.dart';
import 'package:brivio/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:brivio/features/auth/presentation/screens/auth_gate_screen.dart';
import 'package:brivio/features/auth/presentation/screens/saved_accounts_screen.dart';
import 'package:brivio/features/auth/presentation/screens/login_screen.dart';
import 'package:brivio/features/auth/presentation/viewmodels/auth_viewmodel.dart';

class MockSuccessAuthRepository implements IAuthRepository {
  String? lastSignedInEmail;
  String? lastSignedInPassword;

  final UserProfile testUser = UserProfile(
    id: 'user-123',
    email: 'admin@brivio.com',
    fullName: 'أحمد محمود',
    role: UserRole.admin,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  Future<UserProfile?> getCurrentUser() async => null;

  @override
  Future<AuthUserBootstrap> fetchUserBootstrap() async {
    return AuthUserBootstrap(
      profile: testUser,
      role: UserRole.admin,
      accountStatus: AccountStatus.active,
      effectivePermissions: const [],
    );
  }

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastSignedInEmail = email;
    lastSignedInPassword = password;
    return testUser;
  }

  @override
  Future<UserProfile> signInWithMagicQr({
    required String email,
    required String token,
  }) async => testUser;

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async => testUser;

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async => profile;

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<Map<String, dynamic>> provisionPrivilegedUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? branchId,
  }) async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedAccount Model Tests', () {
    test('serializes to JSON and deserializes correctly', () {
      final now = DateTime(2026, 10, 16, 20, 0, 0);
      final account = SavedAccount(
        id: 'acc-1',
        email: 'teacher@brivio.com',
        fullName: 'أستاذ محمد',
        role: 'teacher',
        avatarUrl: 'https://example.com/avatar.jpg',
        centerName: 'سنتر النور',
        password: 'secret_password_123',
        lastLoginAt: now,
      );

      final json = account.toJson();
      expect(json['id'], 'acc-1');
      expect(json['email'], 'teacher@brivio.com');
      expect(json['fullName'], 'أستاذ محمد');
      expect(json['role'], 'teacher');
      expect(json['password'], 'secret_password_123');

      final fromJson = SavedAccount.fromJson(json);
      expect(fromJson.id, account.id);
      expect(fromJson.email, account.email);
      expect(fromJson.fullName, account.fullName);
      expect(fromJson.role, account.role);
      expect(fromJson.password, account.password);
      expect(fromJson.lastLoginAt, now);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'id': 'acc-2',
        'email': 'student@brivio.com',
      };
      final account = SavedAccount.fromJson(json);
      expect(account.id, 'acc-2');
      expect(account.email, 'student@brivio.com');
      expect(account.fullName, '');
      expect(account.role, 'student');
      expect(account.password, isNull);
    });

    test('copyWith properly updates specific fields', () {
      final account = SavedAccount(
        id: 'acc-3',
        email: 'test@brivio.com',
        fullName: 'Test User',
        role: 'admin',
        lastLoginAt: DateTime.now(),
      );

      final updated = account.copyWith(
        fullName: 'Updated Name',
        password: 'new_password',
      );

      expect(updated.id, 'acc-3');
      expect(updated.fullName, 'Updated Name');
      expect(updated.password, 'new_password');
      expect(updated.role, 'admin');
    });
  });

  group('SavedAccountsService CRUD & Storage Tests', () {
    test('returns empty list when no accounts are saved', () async {
      final accounts = await SavedAccountsService.getSavedAccounts();
      expect(accounts, isEmpty);
    });

    test('saves account and retrieves it properly', () async {
      final account = SavedAccount(
        id: 'user-1',
        email: 'admin@brivio.com',
        fullName: 'مدير النظام',
        role: 'admin',
        password: 'password123',
        lastLoginAt: DateTime.now(),
      );

      await SavedAccountsService.saveAccount(account);
      final accounts = await SavedAccountsService.getSavedAccounts();

      expect(accounts.length, 1);
      expect(accounts.first.email, 'admin@brivio.com');
      expect(accounts.first.fullName, 'مدير النظام');
      expect(accounts.first.password, 'password123');
    });

    test('saving multiple accounts sorts them by lastLoginAt descending', () async {
      final acc1 = SavedAccount(
        id: 'user-1',
        email: 'older@brivio.com',
        fullName: 'حساب أقدم',
        role: 'student',
        lastLoginAt: DateTime(2026, 1, 1),
      );
      final acc2 = SavedAccount(
        id: 'user-2',
        email: 'newer@brivio.com',
        fullName: 'حساب أحدث',
        role: 'teacher',
        lastLoginAt: DateTime(2026, 10, 16),
      );

      await SavedAccountsService.saveAccount(acc1);
      await SavedAccountsService.saveAccount(acc2);

      final accounts = await SavedAccountsService.getSavedAccounts();
      expect(accounts.length, 2);
      expect(accounts.first.email, 'newer@brivio.com');
      expect(accounts.last.email, 'older@brivio.com');
    });

    test('saving existing account updates it without creating duplicates', () async {
      final initial = SavedAccount(
        id: 'user-1',
        email: 'teacher@brivio.com',
        fullName: 'الأستاذ خالد',
        role: 'teacher',
        password: 'pass1',
        lastLoginAt: DateTime(2026, 5, 1),
      );
      await SavedAccountsService.saveAccount(initial);

      final updated = SavedAccount(
        id: 'user-1',
        email: 'teacher@brivio.com',
        fullName: 'الأستاذ خالد (محدث)',
        role: 'teacher',
        password: 'pass2_updated',
        lastLoginAt: DateTime(2026, 10, 16),
      );
      await SavedAccountsService.saveAccount(updated);

      final accounts = await SavedAccountsService.getSavedAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.fullName, 'الأستاذ خالد (محدث)');
      expect(accounts.first.password, 'pass2_updated');
    });

    test('isAccountSaved detects case-insensitive emails', () async {
      await SavedAccountsService.saveAccount(
        SavedAccount(
          id: 'user-1',
          email: 'Student@Brivio.com',
          fullName: 'طالب',
          role: 'student',
          lastLoginAt: DateTime.now(),
        ),
      );

      expect(await SavedAccountsService.isAccountSaved('student@brivio.com'), isTrue);
      expect(await SavedAccountsService.isAccountSaved('STUDENT@BRIVIO.COM'), isTrue);
      expect(await SavedAccountsService.isAccountSaved('other@brivio.com'), isFalse);
    });

    test('removeAccount deletes by ID or email correctly', () async {
      final acc1 = SavedAccount(
        id: 'user-1',
        email: 'one@brivio.com',
        fullName: 'واحد',
        role: 'student',
        lastLoginAt: DateTime.now(),
      );
      final acc2 = SavedAccount(
        id: 'user-2',
        email: 'two@brivio.com',
        fullName: 'اثنان',
        role: 'teacher',
        lastLoginAt: DateTime.now(),
      );

      await SavedAccountsService.saveAccount(acc1);
      await SavedAccountsService.saveAccount(acc2);

      // Remove by email
      await SavedAccountsService.removeAccount('one@brivio.com');
      var list = await SavedAccountsService.getSavedAccounts();
      expect(list.length, 1);
      expect(list.first.id, 'user-2');

      // Remove by ID
      await SavedAccountsService.removeAccount('user-2');
      list = await SavedAccountsService.getSavedAccounts();
      expect(list, isEmpty);
    });

    test('clearAll removes all saved profiles', () async {
      await SavedAccountsService.saveAccount(
        SavedAccount(
          id: 'user-1',
          email: 'test@brivio.com',
          fullName: 'User',
          role: 'student',
          lastLoginAt: DateTime.now(),
        ),
      );

      await SavedAccountsService.clearAll();
      final list = await SavedAccountsService.getSavedAccounts();
      expect(list, isEmpty);
    });
  });

  group('AuthGateScreen Coordinator Widget Tests', () {
    testWidgets('shows LoginScreen when no saved accounts exist', (tester) async {
      final mockRepo = MockSuccessAuthRepository();
      final viewModel = AuthViewModel(mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGateScreen(viewModel: viewModel),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SavedAccountsScreen), findsNothing);
    });

    testWidgets('shows SavedAccountsScreen when accounts are saved on device', (tester) async {
      await SavedAccountsService.saveAccount(
        SavedAccount(
          id: 'user-1',
          email: 'admin@brivio.com',
          fullName: 'أحمد محمود',
          role: 'admin',
          password: 'pass',
          lastLoginAt: DateTime.now(),
        ),
      );

      final mockRepo = MockSuccessAuthRepository();
      final viewModel = AuthViewModel(mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGateScreen(viewModel: viewModel),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SavedAccountsScreen), findsOneWidget);
      expect(find.text('أحمد محمود'), findsOneWidget);
      expect(find.text('admin@brivio.com'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('switches to LoginScreen on tapping "تسجيل الدخول بحساب آخر ➕" and can return', (tester) async {
      await SavedAccountsService.saveAccount(
        SavedAccount(
          id: 'user-1',
          email: 'admin@brivio.com',
          fullName: 'أحمد محمود',
          role: 'admin',
          password: 'pass',
          lastLoginAt: DateTime.now(),
        ),
      );

      final mockRepo = MockSuccessAuthRepository();
      final viewModel = AuthViewModel(mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGateScreen(viewModel: viewModel),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 1. Verify on SavedAccountsScreen
      expect(find.byType(SavedAccountsScreen), findsOneWidget);

      // 2. Tap "تسجيل الدخول بحساب آخر ➕"
      final addAccountButton = find.text('تسجيل الدخول بحساب آخر ➕');
      expect(addAccountButton, findsOneWidget);
      await tester.tap(addAccountButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 3. Verify transitioned to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // 4. Verify return button exists and tap it
      final returnButton = find.text('التبديل إلى الحسابات المحفوظة 👥');
      expect(returnButton, findsOneWidget);
      await tester.tap(returnButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 5. Verify back on SavedAccountsScreen
      expect(find.byType(SavedAccountsScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('SavedAccountsScreen 1-Tap Login & Removal Tests', () {
    testWidgets('clicking saved profile triggers 1-tap signIn with saved credentials', (tester) async {
      await SavedAccountsService.saveAccount(
        SavedAccount(
          id: 'user-1',
          email: 'admin@brivio.com',
          fullName: 'أحمد محمود',
          role: 'admin',
          password: 'super_secret_123',
          lastLoginAt: DateTime.now(),
        ),
      );

      final mockRepo = MockSuccessAuthRepository();
      final viewModel = AuthViewModel(mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: SavedAccountsScreen(
            viewModel: viewModel,
            onNavigateToLogin: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on the account row
      final accountCard = find.text('أحمد محمود');
      expect(accountCard, findsOneWidget);
      await tester.tap(accountCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check repository was called with the saved email & password
      expect(mockRepo.lastSignedInEmail, 'admin@brivio.com');
      expect(mockRepo.lastSignedInPassword, 'super_secret_123');
    });

    testWidgets('clicking delete icon removes account and shows confirmation dialog', (tester) async {
      await SavedAccountsService.saveAccount(
        SavedAccount(
          id: 'user-1',
          email: 'student@brivio.com',
          fullName: 'طالب مجتهد',
          role: 'student',
          password: 'pass',
          lastLoginAt: DateTime.now(),
        ),
      );

      final mockRepo = MockSuccessAuthRepository();
      final viewModel = AuthViewModel(mockRepo);

      bool redirectedToLogin = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SavedAccountsScreen(
            viewModel: viewModel,
            onNavigateToLogin: () {
              redirectedToLogin = true;
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap delete button (IconButton with close_rounded)
      final deleteBtn = find.byIcon(Icons.close_rounded);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog should appear
      expect(find.text('إزالة الحساب من الجهاز'), findsOneWidget);

      // Confirm removal
      final confirmBtn = find.text('إزالة الحساب');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify account was removed from storage and redirected
      final remaining = await SavedAccountsService.getSavedAccounts();
      expect(remaining, isEmpty);
      expect(redirectedToLogin, isTrue);
    });
  });

  group('LoginScreen Post-Login Save Dialog Tests', () {
    testWidgets('prompts to save account upon successful login when account is not yet saved', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockSuccessAuthRepository();
      final viewModel = AuthViewModel(mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(viewModel: viewModel),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Enter email and password
      final emailFields = find.byType(TextField);
      expect(emailFields, findsWidgets);

      await tester.enterText(emailFields.at(0), 'admin@brivio.com');
      await tester.enterText(emailFields.at(1), 'password123');
      await tester.pump();

      // Submit login form
      final submitBtn = find.byType(PrimaryButton);
      expect(submitBtn, findsOneWidget);
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify the Facebook-style prompt dialog appears
      expect(find.text('حفظ معلومات تسجيل الدخول؟'), findsOneWidget);
      expect(find.text('حفظ الحساب'), findsOneWidget);
      expect(find.text('ليس الآن'), findsOneWidget);

      // Confirm saving
      await tester.tap(find.text('حفظ الحساب'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify account is now permanently saved in SavedAccountsService
      final saved = await SavedAccountsService.getSavedAccounts();
      expect(saved.length, 1);
      expect(saved.first.email, 'admin@brivio.com');
      expect(saved.first.password, 'password123');
    });

    testWidgets('dismisses dialog without saving if user clicks "ليس الآن"', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockSuccessAuthRepository();
      final viewModel = AuthViewModel(mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(viewModel: viewModel),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Enter email and password
      final emailFields = find.byType(TextField);
      await tester.enterText(emailFields.at(0), 'admin@brivio.com');
      await tester.enterText(emailFields.at(1), 'password123');
      await tester.pump();

      // Submit login
      final submitBtn = find.byType(PrimaryButton);
      expect(submitBtn, findsOneWidget);
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Dialog appears
      expect(find.text('حفظ معلومات تسجيل الدخول؟'), findsOneWidget);

      // Click "ليس الآن"
      await tester.tap(find.text('ليس الآن'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify storage remains empty
      final saved = await SavedAccountsService.getSavedAccounts();
      expect(saved, isEmpty);
    });
  });
}
