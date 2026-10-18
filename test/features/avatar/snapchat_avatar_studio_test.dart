import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/avatar/domain/models/bitmoji_traits.dart';
import 'package:brivio/features/avatar/presentation/painters/bitmoji_vector_library.dart';
import 'package:brivio/features/avatar/presentation/widgets/bitmoji_renderer.dart';
import 'package:brivio/features/avatar/presentation/widgets/bitmoji_stickers_sheet.dart';
import 'package:brivio/features/avatar/presentation/screens/snapchat_avatar_studio_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BitmojiTraits Domain Tests', () {
    test('default BitmojiTraits initializes with proper defaults', () {
      const traits = BitmojiTraits();

      expect(traits.gender, equals('male'));
      expect(traits.faceShape, equals('oval'));
      expect(traits.hairStyle, equals('short_curly'));
      expect(traits.skinColor, equals(const Color(0xFFF3C7A8)));
      expect(traits.eyes, equals('happy_curved'));
      expect(traits.mouth, equals('warm_smile'));
      expect(traits.outfit, equals('hoodie'));
      expect(traits.backgroundStyle, equals('studio_pedestal'));
    });

    test('toJson and fromJson preserves all traits faithfully', () {
      const original = BitmojiTraits(
        gender: 'female',
        faceShape: 'heart',
        skinColor: Color(0xFFE5B592),
        hairStyle: 'hijab_wrapped',
        hairColor: Color(0xFF1B1B1B),
        eyes: 'confident_almond',
        eyeColor: Color(0xFF1E40AF),
        eyebrows: 'thick_arched',
        nose: 'soft_button',
        mouth: 'wide_grin',
        facialHair: 'none',
        eyewear: 'round_frames',
        headwear: 'hijab',
        outfit: 'formal_blazer',
        outfitColor: Color(0xFF2563EB),
        outfitAccentColor: Color(0xFF60A5FA),
        backgroundStyle: 'studio_pedestal',
        backgroundColor: Color(0xFFEDE9FE),
      );

      final json = original.toJson();
      final decoded = BitmojiTraits.fromJson(json);

      expect(decoded.gender, equals('female'));
      expect(decoded.faceShape, equals('heart'));
      expect(decoded.hairStyle, equals('hijab_wrapped'));
      expect(decoded.skinColor.toARGB32(), equals(original.skinColor.toARGB32()));
      expect(decoded.eyes, equals('confident_almond'));
      expect(decoded.eyewear, equals('round_frames'));
      expect(decoded.headwear, equals('hijab'));
      expect(decoded.outfit, equals('formal_blazer'));
      expect(decoded.backgroundColor.toARGB32(), equals(original.backgroundColor.toARGB32()));
    });

    test('copyWith updates specified properties while retaining others', () {
      const original = BitmojiTraits();
      final updated = original.copyWith(
        gender: 'female',
        eyewear: 'sunglasses',
        outfitColor: const Color(0xFFEC4899),
      );

      expect(updated.gender, equals('female'));
      expect(updated.eyewear, equals('sunglasses'));
      expect(updated.outfitColor, equals(const Color(0xFFEC4899)));
      // Unchanged
      expect(updated.faceShape, equals(original.faceShape));
      expect(updated.skinColor, equals(original.skinColor));
    });

    test('palettes contain valid, diverse color choices', () {
      expect(BitmojiTraits.skinPalette.length, greaterThanOrEqualTo(8));
      expect(BitmojiTraits.hairPalette.length, greaterThanOrEqualTo(8));
      expect(BitmojiTraits.eyePalette.length, greaterThanOrEqualTo(5));
      expect(BitmojiTraits.outfitPalette.length, greaterThanOrEqualTo(8));
      expect(BitmojiTraits.backgroundPalette.length, greaterThanOrEqualTo(6));
    });
  });

  group('BitmojiCustomPainter Tests', () {
    testWidgets('paints full body and face without rendering errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(300, 400),
              painter: BitmojiCustomPainter(
                traits: const BitmojiTraits(
                  gender: 'female',
                  hairStyle: 'hijab_wrapped',
                  headwear: 'hijab',
                  eyewear: 'square_frames',
                  facialHair: 'trimmed_beard',
                ),
                blinkValue: 0.5,
                breathOffset: 1.0,
                showFullBody: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('shouldRepaint detects changes in traits or animation values', () {
      const t1 = BitmojiTraits(hairStyle: 'short_curly');
      const t2 = BitmojiTraits(hairStyle: 'fade_crop');

      final painter1 = BitmojiCustomPainter(traits: t1, blinkValue: 0.0);
      final painter2 = BitmojiCustomPainter(traits: t2, blinkValue: 0.0);
      final painter3 = BitmojiCustomPainter(traits: t1, blinkValue: 0.5);

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isTrue);
      expect(painter1.shouldRepaint(painter1), isFalse);
    });
  });

  group('BitmojiRenderer Widget Tests', () {
    testWidgets('renders properly with static animation and camera zoom', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BitmojiRenderer(
              traits: BitmojiTraits(),
              cameraFocus: AvatarCameraFocus.face,
              isAnimated: false,
              showPedestal: true,
              width: 250,
              height: 300,
            ),
          ),
        ),
      );

      expect(find.byType(BitmojiRenderer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('BitmojiStickersSheet Widget Tests', () {
    testWidgets('renders stickers grid and invokes selection callback', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      BitmojiTraits? appliedTraits;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BitmojiStickersSheet(
              traits: const BitmojiTraits(),
              onApplyStickerExpression: (traits) {
                appliedTraits = traits;
              },
            ),
          ),
        ),
      );

      // Verify sticker headers & cards
      expect(find.text('ملصقات Bitmoji الخاصة بك 🎭'), findsOneWidget);
      expect(find.text('أهلاً بك 👋'), findsOneWidget);
      expect(find.text('طالب متفوق 🌟'), findsOneWidget);
      expect(find.text('وقت المذاكرة 📖'), findsOneWidget);

      // Tap on "طالب متفوق 🌟"
      await tester.tap(find.text('طالب متفوق 🌟'));
      await tester.pump();

      expect(appliedTraits, isNotNull);
      expect(appliedTraits!.mouth, equals('confident_smirk'));
    });
  });

  group('SnapchatAvatarStudioScreen Full UI Tests', () {
    testWidgets('renders 3D studio, camera switcher, category tabs and randomizer', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SnapchatAvatarStudioScreen(
            userId: 'snap_test_user',
            userEmail: 'snap@brivio.com',
          ),
        ),
      );

      // 1. Verify AppBar title and actions
      expect(find.text('استوديو الأفاتار (Bitmoji 3D)'), findsOneWidget);
      expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
      expect(find.text('حفظ ✨'), findsOneWidget);

      // 2. Verify floating camera switcher pill
      expect(find.text('تكبير الوجه'), findsOneWidget);

      // Tap camera focus switch
      await tester.tap(find.text('تكبير الوجه'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('عرض الجسم كامل'), findsOneWidget);

      // 3. Verify category ribbon
      expect(find.text('الجنس'), findsOneWidget);
      expect(find.text('البشرة'), findsOneWidget);
      expect(find.text('الشعر'), findsOneWidget);

      // Tap on "الشعر"
      await tester.tap(find.text('الشعر'));
      await tester.pump();

      // Verify haircut options appear
      expect(find.text('كيرلي عصري 👦'), findsOneWidget);
      expect(find.text('حجاب إسلامي 🧕'), findsOneWidget);

      // 4. Tap randomizer button
      await tester.tap(find.byIcon(Icons.casino_rounded));
      await tester.pump();

      expect(find.byType(SnapchatAvatarStudioScreen), findsOneWidget);
    });

    testWidgets('supports 3-way camera cycling, pedestal styles, and honor badges', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SnapchatAvatarStudioScreen(
            userId: 'snap_test_user_2',
          ),
        ),
      );

      // 1. Verify 3-way camera cycling: fullBody -> face -> bust -> fullBody
      expect(find.text('تكبير الوجه'), findsOneWidget);
      await tester.tap(find.text('تكبير الوجه'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('عرض الجسم كامل'), findsOneWidget);

      await tester.tap(find.text('عرض الجسم كامل'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('عرض المنصة 🕺'), findsOneWidget);

      await tester.tap(find.text('عرض المنصة 🕺'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('تكبير الوجه'), findsOneWidget);

      // 2. Test Pedestal Section
      expect(find.text('المنصة'), findsOneWidget);
      await tester.tap(find.text('المنصة'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ديسك النيون المشع ⚡'), findsOneWidget);
      expect(find.text('المنصة الملكية الذهبية 👑'), findsOneWidget);
      await tester.tap(find.text('المنصة الملكية الذهبية 👑'));
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Test Honor Badge Section
      expect(find.text('الأوسمة'), findsOneWidget);
      await tester.tap(find.text('الأوسمة'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('وسام الشرف والامتياز'), findsOneWidget);
      expect(find.text('نجم الإنجاز الأكاديمي'), findsOneWidget);
      await tester.tap(find.text('وسام الشرف والامتياز'));
      await tester.pump(const Duration(milliseconds: 300));

      // 4. Test Model Category Filtering
      await tester.tap(find.text('النمط'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('المواهب 🔬'), findsOneWidget);
      await tester.tap(find.text('المواهب 🔬'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('باحث علمي 🔬'), findsOneWidget);
    });
  });
}
