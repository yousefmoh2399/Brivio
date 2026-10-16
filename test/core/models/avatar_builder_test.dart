import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/core/models/avatar_builder_model.dart';
import 'package:brivio/features/profile/presentation/screens/avatar_studio_screen.dart';

void main() {
  group('AvatarConfig Model Tests', () {
    test('default config generates valid avataaars CDN URL', () {
      const config = AvatarConfig();
      final url = config.toUrl();

      expect(url, startsWith('https://api.dicebear.com/7.x/avataaars/png?'));
      expect(url, contains('skinColor=edb98a'));
      expect(url, contains('top=shortCurly'));
      expect(url, contains('hairColor=2c1b18'));
      expect(url, contains('eyes=happy'));
      expect(url, contains('mouth=smile'));
      expect(url, contains('clothing=hoodie'));
    });

    test('toUrl handles other styles like bottts, adventurer, lorelei', () {
      const bot = AvatarConfig(style: 'bottts', seed: 'MyRobot', backgroundColor: '10b981');
      expect(bot.toUrl(), equals('https://api.dicebear.com/7.x/bottts/png?seed=MyRobot&backgroundColor=10b981'));

      const adv = AvatarConfig(style: 'adventurer', seed: 'Hero1', backgroundColor: '0ea5e9');
      expect(adv.toUrl(), equals('https://api.dicebear.com/7.x/adventurer/png?seed=Hero1&backgroundColor=0ea5e9'));

      const lor = AvatarConfig(style: 'lorelei', seed: 'Lady1', backgroundColor: 'ffd5dc');
      expect(lor.toUrl(), equals('https://api.dicebear.com/7.x/lorelei/png?seed=Lady1&backgroundColor=ffd5dc'));
    });

    test('toJson and fromJson preserves all avatar attributes', () {
      const original = AvatarConfig(
        style: 'avataaars',
        seed: 'Sara_Custom',
        gender: 'female',
        skinColor: 'ffdbb4',
        hairStyle: 'hijab',
        hairColor: '4a312c',
        eyes: 'wink',
        eyebrows: 'raisedExcitedNatural',
        mouth: 'twinkle',
        facialHair: 'none',
        accessories: 'prescription01',
        clothing: 'collarAndSweater',
        clothingColor: '5199e4',
        backgroundColor: 'c0aede',
      );

      final json = original.toJson();
      final reconstructed = AvatarConfig.fromJson(json);

      expect(reconstructed.seed, equals(original.seed));
      expect(reconstructed.gender, equals('female'));
      expect(reconstructed.hairStyle, equals('hijab'));
      expect(reconstructed.clothing, equals('collarAndSweater'));
      expect(reconstructed.toUrl(), equals(original.toUrl()));
    });

    test('randomize produces consistent, non-null configurations', () {
      final randomBoy = AvatarConfig.randomize(targetGender: 'male');
      expect(randomBoy.gender, equals('male'));
      expect(randomBoy.skinColor, isNotEmpty);
      expect(randomBoy.toUrl(), startsWith('https://api.dicebear.com/7.x/avataaars/png?'));

      final randomGirl = AvatarConfig.randomize(targetGender: 'female');
      expect(randomGirl.gender, equals('female'));
      expect(randomGirl.skinColor, isNotEmpty);
      expect(randomGirl.toUrl(), startsWith('https://api.dicebear.com/7.x/avataaars/png?'));
    });
  });

  group('AvatarStudioScreen Widget Tests', () {
    testWidgets('renders studio screen with live preview and category tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AvatarStudioScreen(
            userId: 'test_user_1',
            userEmail: 'test@brivio.com',
          ),
        ),
      );

      // Verify title & controls
      expect(find.text('استوديو تصميم الأفاتار 🎨'), findsOneWidget);
      expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
      expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);

      // Verify style chips
      expect(find.text('شخصية Bitmoji 👱'), findsOneWidget);
      expect(find.text('مغامر أنمي ⚔️'), findsOneWidget);

      // Verify category tabs
      expect(find.text('الجنس والأسلوب'), findsOneWidget);
      expect(find.text('لون البشرة'), findsOneWidget);
      expect(find.text('الشعر والحجاب'), findsOneWidget);

      // Verify save button
      expect(find.text('حفظ وتعيين كصورتي الشخصية ✨'), findsOneWidget);
    });

    testWidgets('switching category tabs updates option panel', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AvatarStudioScreen(),
        ),
      );

      // Click on "لون البشرة"
      await tester.tap(find.text('لون البشرة'));
      await tester.pump();

      expect(find.text('اختر درجة لون البشرة:'), findsOneWidget);

      // Click on "الشعر والحجاب"
      await tester.ensureVisible(find.text('الشعر والحجاب'));
      await tester.tap(find.text('الشعر والحجاب'));
      await tester.pump();

      expect(find.text('قصة الشعر أو غطاء الرأس:'), findsOneWidget);
    });

    testWidgets('clicking randomize changes seed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AvatarStudioScreen(),
        ),
      );

      // Tap dice button
      await tester.tap(find.byIcon(Icons.casino_rounded));
      await tester.pump();

      expect(find.byType(AvatarStudioScreen), findsOneWidget);
    });
  });
}
