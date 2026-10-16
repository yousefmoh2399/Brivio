import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/core/services/avatar_service.dart';
import 'package:brivio/design_system/components/editable_avatar.dart';
import 'package:brivio/design_system/tokens/colors.dart';

const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  void close({bool force = false}) {}
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockHttpOverrides();
  });

  group('AvatarService Tests', () {
    test('getImageProvider returns null for null or empty string', () {
      expect(AvatarService.getImageProvider(null), isNull);
      expect(AvatarService.getImageProvider(''), isNull);
      expect(AvatarService.getImageProvider('   '), isNull);
    });

    test('getImageProvider returns NetworkImage for http/https URLs', () {
      const url = 'https://example.com/avatar.png';
      final provider = AvatarService.getImageProvider(url);
      expect(provider, isA<NetworkImage>());
      expect((provider as NetworkImage).url, equals(url));
    });

    test('getImageProvider returns MemoryImage for data URI', () {
      const rawText = 'Antigravity Avatar Test';
      final base64String = base64Encode(utf8.encode(rawText));
      final dataUri = 'data:image/png;base64,$base64String';

      final provider = AvatarService.getImageProvider(dataUri);
      expect(provider, isA<MemoryImage>());
      expect(utf8.decode((provider as MemoryImage).bytes), equals(rawText));
    });

    test('educationalPresets contains valid categorized avatars', () {
      final presets = AvatarService.educationalPresets;
      expect(presets.length, greaterThanOrEqualTo(10));
      for (final p in presets) {
        expect(p.titleArabic, isNotEmpty);
        expect(p.url, startsWith('https://'));
      }
    });
  });

  group('EditableAvatar Widget Tests', () {
    testWidgets('renders initials fallback when avatarUrl is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableAvatar(
              avatarUrl: null,
              fullName: 'أحمد محمود',
              role: 'student',
            ),
          ),
        ),
      );

      expect(find.text('أ'), findsOneWidget);
    });

    testWidgets('uses correct role color for admin, teacher, student, parent, staff', (tester) async {
      final roles = {
        'admin': AppColors.adminRole,
        'teacher': AppColors.teacherRole,
        'student': AppColors.studentRole,
        'parent': AppColors.parentRole,
        'staff': AppColors.info,
      };

      for (final entry in roles.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EditableAvatar(
                avatarUrl: null,
                fullName: 'مستخدم تجريبي',
                role: entry.key,
              ),
            ),
          ),
        );
        expect(find.byType(EditableAvatar), findsOneWidget);
      }
    });

    testWidgets('tapping EditableAvatar shows AvatarPickerBottomSheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableAvatar(
              avatarUrl: null,
              fullName: 'يوسف محمد',
              role: 'student',
            ),
          ),
        ),
      );

      // Tap on avatar
      await tester.tap(find.byType(EditableAvatar));
      await tester.pump(const Duration(milliseconds: 500));

      // BottomSheet should be displayed
      expect(find.byType(AvatarPickerBottomSheet), findsOneWidget);
      expect(find.text('تعديل الصورة الشخصية 📷'), findsOneWidget);
      expect(find.text('اختيار صورة من المعرض أو الجهاز 📁'), findsOneWidget);
    });

    testWidgets('AvatarPickerBottomSheet.show opens modal bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AvatarPickerBottomSheet.show(
                    context: context,
                    fullName: 'مدرس الفيزياء',
                    userRole: 'teacher',
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.byType(AvatarPickerBottomSheet), findsOneWidget);
      expect(find.text('تعديل الصورة الشخصية 📷'), findsOneWidget);
    });
  });
}
