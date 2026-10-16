import 'dart:math';

/// Configuration model holding all customizable traits for a Snapchat/Bitmoji-style avatar.
class AvatarConfig {
  final String style; // 'avataaars', 'bottts', 'adventurer', 'lorelei'
  final String seed;
  final String gender; // 'male', 'female', 'neutral'
  final String skinColor;
  final String hairStyle;
  final String hairColor;
  final String eyes;
  final String eyebrows;
  final String mouth;
  final String facialHair;
  final String facialHairColor;
  final String accessories;
  final String accessoriesColor;
  final String clothing;
  final String clothingColor;
  final String backgroundColor;

  const AvatarConfig({
    this.style = 'avataaars',
    this.seed = 'BrivioHero',
    this.gender = 'male',
    this.skinColor = 'edb98a',
    this.hairStyle = 'shortCurly',
    this.hairColor = '2c1b18',
    this.eyes = 'happy',
    this.eyebrows = 'defaultNatural',
    this.mouth = 'smile',
    this.facialHair = 'none',
    this.facialHairColor = '2c1b18',
    this.accessories = 'none',
    this.accessoriesColor = '262e33',
    this.clothing = 'hoodie',
    this.clothingColor = '65c9ff',
    this.backgroundColor = 'b6e3f4',
  });

  /// Palette of skin colors
  static const List<Map<String, String>> skinColors = [
    {'name': 'فاتح جداً', 'hex': 'ffdbb4'},
    {'name': 'قمحي فاتح', 'hex': 'edb98a'},
    {'name': 'قمحي', 'hex': 'f8d25c'},
    {'name': 'حنطي دافئ', 'hex': 'fd9841'},
    {'name': 'أسمر كلاسيكي', 'hex': 'd08b5b'},
    {'name': 'برونزي داكن', 'hex': 'ae5d29'},
    {'name': 'داكن غني', 'hex': '614335'},
  ];

  /// Palette of hair colors
  static const List<Map<String, String>> hairColors = [
    {'name': 'أسود ليلي', 'hex': '2c1b18'},
    {'name': 'بني غامق', 'hex': '4a312c'},
    {'name': 'كستنائي دافئ', 'hex': '724133'},
    {'name': 'نحاسي بني', 'hex': 'a55728'},
    {'name': 'أشقر داكن', 'hex': 'b58143'},
    {'name': 'أشقر ذهبي', 'hex': 'd6b370'},
    {'name': 'رمادي وقور', 'hex': 'e8e1e1'},
  ];

  /// Hairstyle and headwear presets (Boys, Girls, Hijab, etc.)
  static const List<Map<String, String>> hairStyles = [
    {'id': 'shortCurly', 'name': 'قصير كيرلي 👦', 'gender': 'male'},
    {'id': 'shortWaved', 'name': 'قصير مموج 💇‍♂️', 'gender': 'male'},
    {'id': 'theCaesar', 'name': 'سيزر كلاسيك ✂️', 'gender': 'male'},
    {'id': 'shortFlat', 'name': 'قصير ناعم 👨', 'gender': 'male'},
    {'id': 'frizzle', 'name': 'كيرلي كثيف 💥', 'gender': 'male'},
    {'id': 'sides', 'name': 'تدرج جانبي 💈', 'gender': 'male'},
    {'id': 'dreads01', 'name': 'ضفائر رجالية 🧶', 'gender': 'male'},
    {'id': 'hijab', 'name': 'حجاب أنيق 🧕', 'gender': 'female'},
    {'id': 'straight01', 'name': 'ناعم منسدل 👩', 'gender': 'female'},
    {'id': 'straight02', 'name': 'طويل مموج 💁‍♀️', 'gender': 'female'},
    {'id': 'bob', 'name': 'قصة بوب عصرية 💇‍♀️', 'gender': 'female'},
    {'id': 'bun', 'name': 'كعكة مرفوعة 👱‍♀️', 'gender': 'female'},
    {'id': 'curly', 'name': 'كيرلي طويل 🎀', 'gender': 'female'},
    {'id': 'bigHair', 'name': 'شعر كثيف واثق 🦁', 'gender': 'female'},
    {'id': 'turban', 'name': 'تربان عصري 👳‍♀️', 'gender': 'female'},
    {'id': 'hat', 'name': 'قبعة كاجوال 🧢', 'gender': 'neutral'},
    {'id': 'winterHat01', 'name': 'قبعة شتوية ❄️', 'gender': 'neutral'},
  ];

  /// Eyes options
  static const List<Map<String, String>> eyeOptions = [
    {'id': 'happy', 'name': 'مبتسمة 😊'},
    {'id': 'default', 'name': 'طبيعية 👁️'},
    {'id': 'wink', 'name': 'غمزة مرحة 😉'},
    {'id': 'squint', 'name': 'تركيز 🧐'},
    {'id': 'surprised', 'name': 'مندهشة 😲'},
    {'id': 'hearts', 'name': 'قلوب معجبة 😍'},
    {'id': 'side', 'name': 'نظرة جانبية 😏'},
  ];

  /// Eyebrow options
  static const List<Map<String, String>> eyebrowOptions = [
    {'id': 'defaultNatural', 'name': 'طبيعية'},
    {'id': 'raisedExcitedNatural', 'name': 'مرفوعة متفائلة'},
    {'id': 'flatNatural', 'name': 'مستقيمة هادئة'},
    {'id': 'frownNatural', 'name': 'جادة'},
    {'id': 'sadConcernedNatural', 'name': 'قلقة لطيفة'},
  ];

  /// Mouth & expressions
  static const List<Map<String, String>> mouthOptions = [
    {'id': 'smile', 'name': 'ابتسامة مشرقة 😄'},
    {'id': 'twinkle', 'name': 'ابتسامة دافئة 😊'},
    {'id': 'default', 'name': 'هادئ ومريح 😌'},
    {'id': 'serious', 'name': 'جاد وحازم 😐'},
    {'id': 'eating', 'name': 'طاقة وحيوية 😋'},
    {'id': 'tongue', 'name': 'مرح ومشاكس 😜'},
  ];

  /// Facial hair options
  static const List<Map<String, String>> facialHairOptions = [
    {'id': 'none', 'name': 'بدون لحية 🪒'},
    {'id': 'beardLight', 'name': 'لحية خفيفة مهذبة ✨'},
    {'id': 'beardMedium', 'name': 'لحية متوسطة عصرية 🧔'},
    {'id': 'beardMajestic', 'name': 'لحية وقورة كاملة 👑'},
    {'id': 'moustacheFancy', 'name': 'شارب كلاسيكي كشخة 👨'},
  ];

  /// Accessories / Eyewear
  static const List<Map<String, String>> accessoryOptions = [
    {'id': 'none', 'name': 'بدون إكسسوارات ❌'},
    {'id': 'prescription01', 'name': 'نظارة طبية مربعة 👓'},
    {'id': 'prescription02', 'name': 'نظارة أوفال أنيقة 🤓'},
    {'id': 'round', 'name': 'نظارة دائرية ذكية 🧑‍🎓'},
    {'id': 'sunglasses', 'name': 'نظارة شمسية كول 😎'},
    {'id': 'wayfarers', 'name': 'نظارة كاجوال عصرية 🕶️'},
  ];

  /// Clothes / Outfits
  static const List<Map<String, String>> clothingOptions = [
    {'id': 'hoodie', 'name': 'هودي رياضي 🧥'},
    {'id': 'collarAndSweater', 'name': 'قميص وسويتر دراسي 👔'},
    {'id': 'blazerAndShirt', 'name': 'بليزر رسمي فاخر 💼'},
    {'id': 'shirtCrewNeck', 'name': 'تيشيرت كرو عصري 👕'},
    {'id': 'shirtVNeck', 'name': 'تيشيرت في-نك كاجوال 👕'},
    {'id': 'graphicShirt', 'name': 'تيشيرت شبابي بطبعة 🎨'},
    {'id': 'overall', 'name': 'أوفرول عملي 👖'},
  ];

  /// Clothing colors
  static const List<Map<String, String>> clothingColors = [
    {'name': 'أزرق سماوي', 'hex': '65c9ff'},
    {'name': 'أزرق كحلي', 'hex': '25557c'},
    {'name': 'أزرق ملكي', 'hex': '5199e4'},
    {'name': 'أسود فحمي', 'hex': '262e33'},
    {'name': 'أبيض ناصع', 'hex': 'e6e6e6'},
    {'name': 'أحمر مرجاني', 'hex': 'ff5c5c'},
    {'name': 'وردي لطيف', 'hex': 'ffafb9'},
    {'name': 'رمادي أنيق', 'hex': '929598'},
  ];

  /// Background colors
  static const List<Map<String, String>> backgroundColors = [
    {'name': 'سماوي باستيل', 'hex': 'b6e3f4'},
    {'name': 'بنفسجي لافندر', 'hex': 'c0aede'},
    {'name': 'نيلي هادئ', 'hex': 'd1d4f9'},
    {'name': 'وردي خوخي', 'hex': 'ffd5dc'},
    {'name': 'مشيمشي دافئ', 'hex': 'ffdfbf'},
    {'name': 'أزرق بريفيو ⚡', 'hex': '0ea5e9'},
    {'name': 'أخضر زمردي', 'hex': '10b981'},
    {'name': 'عنبري دافئ', 'hex': 'f59e0b'},
    {'name': 'رمادي غامق دارك', 'hex': '1e293b'},
  ];

  /// Generates the direct high-speed CDN URL for this exact configuration.
  String toUrl({String format = 'png', int size = 256}) {
    if (style == 'bottts') {
      return 'https://api.dicebear.com/7.x/bottts/$format?seed=$seed&backgroundColor=$backgroundColor';
    }
    if (style == 'adventurer') {
      return 'https://api.dicebear.com/7.x/adventurer/$format?seed=$seed&backgroundColor=$backgroundColor';
    }
    if (style == 'lorelei') {
      return 'https://api.dicebear.com/7.x/lorelei/$format?seed=$seed&backgroundColor=$backgroundColor';
    }

    // Default: avataaars (Bitmoji style)
    final params = <String, String>{
      'seed': seed,
      'skinColor': skinColor,
      'top': hairStyle,
      'hairColor': hairColor,
      'eyes': eyes,
      'eyebrows': eyebrows,
      'mouth': mouth,
      'clothing': clothing,
      'clothesColor': clothingColor,
      'backgroundColor': backgroundColor,
    };

    if (facialHair != 'none') {
      params['facialHair'] = facialHair;
      params['facialHairColor'] = facialHairColor;
    }
    if (accessories != 'none') {
      params['accessories'] = accessories;
      params['accessoriesColor'] = accessoriesColor;
    }

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://api.dicebear.com/7.x/avataaars/$format?$query';
  }

  /// Generates a stylish, randomized avatar.
  static AvatarConfig randomize({String? targetGender}) {
    final rand = Random();
    final gender = targetGender ?? (rand.nextBool() ? 'male' : 'female');

    final availableStyles = hairStyles
        .where((h) => h['gender'] == gender || h['gender'] == 'neutral')
        .toList();
    final pickedHair = availableStyles[rand.nextInt(availableStyles.length)]['id']!;

    final pickedSkin = skinColors[rand.nextInt(skinColors.length)]['hex']!;
    final pickedHairColor = hairColors[rand.nextInt(hairColors.length)]['hex']!;
    final pickedEyes = eyeOptions[rand.nextInt(eyeOptions.length)]['id']!;
    final pickedEyebrows = eyebrowOptions[rand.nextInt(eyebrowOptions.length)]['id']!;
    final pickedMouth = mouthOptions[rand.nextInt(mouthOptions.length)]['id']!;
    final pickedClothes = clothingOptions[rand.nextInt(clothingOptions.length)]['id']!;
    final pickedClothesColor = clothingColors[rand.nextInt(clothingColors.length)]['hex']!;
    final pickedBg = backgroundColors[rand.nextInt(backgroundColors.length)]['hex']!;

    String pickedBeard = 'none';
    if (gender == 'male' && rand.nextInt(3) == 0) {
      pickedBeard = facialHairOptions[1 + rand.nextInt(facialHairOptions.length - 1)]['id']!;
    }

    String pickedAcc = 'none';
    if (rand.nextInt(3) == 0) {
      pickedAcc = accessoryOptions[1 + rand.nextInt(accessoryOptions.length - 1)]['id']!;
    }

    return AvatarConfig(
      style: 'avataaars',
      seed: 'Hero_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(9999)}',
      gender: gender,
      skinColor: pickedSkin,
      hairStyle: pickedHair,
      hairColor: pickedHairColor,
      eyes: pickedEyes,
      eyebrows: pickedEyebrows,
      mouth: pickedMouth,
      facialHair: pickedBeard,
      facialHairColor: pickedHairColor,
      accessories: pickedAcc,
      clothing: pickedClothes,
      clothingColor: pickedClothesColor,
      backgroundColor: pickedBg,
    );
  }

  AvatarConfig copyWith({
    String? style,
    String? seed,
    String? gender,
    String? skinColor,
    String? hairStyle,
    String? hairColor,
    String? eyes,
    String? eyebrows,
    String? mouth,
    String? facialHair,
    String? facialHairColor,
    String? accessories,
    String? accessoriesColor,
    String? clothing,
    String? clothingColor,
    String? backgroundColor,
  }) {
    return AvatarConfig(
      style: style ?? this.style,
      seed: seed ?? this.seed,
      gender: gender ?? this.gender,
      skinColor: skinColor ?? this.skinColor,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      eyes: eyes ?? this.eyes,
      eyebrows: eyebrows ?? this.eyebrows,
      mouth: mouth ?? this.mouth,
      facialHair: facialHair ?? this.facialHair,
      facialHairColor: facialHairColor ?? this.facialHairColor,
      accessories: accessories ?? this.accessories,
      accessoriesColor: accessoriesColor ?? this.accessoriesColor,
      clothing: clothing ?? this.clothing,
      clothingColor: clothingColor ?? this.clothingColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'style': style,
    'seed': seed,
    'gender': gender,
    'skinColor': skinColor,
    'hairStyle': hairStyle,
    'hairColor': hairColor,
    'eyes': eyes,
    'eyebrows': eyebrows,
    'mouth': mouth,
    'facialHair': facialHair,
    'facialHairColor': facialHairColor,
    'accessories': accessories,
    'accessoriesColor': accessoriesColor,
    'clothing': clothing,
    'clothingColor': clothingColor,
    'backgroundColor': backgroundColor,
  };

  factory AvatarConfig.fromJson(Map<String, dynamic> json) => AvatarConfig(
    style: json['style'] as String? ?? 'avataaars',
    seed: json['seed'] as String? ?? 'BrivioHero',
    gender: json['gender'] as String? ?? 'male',
    skinColor: json['skinColor'] as String? ?? 'edb98a',
    hairStyle: json['hairStyle'] as String? ?? 'shortCurly',
    hairColor: json['hairColor'] as String? ?? '2c1b18',
    eyes: json['eyes'] as String? ?? 'happy',
    eyebrows: json['eyebrows'] as String? ?? 'defaultNatural',
    mouth: json['mouth'] as String? ?? 'smile',
    facialHair: json['facialHair'] as String? ?? 'none',
    facialHairColor: json['facialHairColor'] as String? ?? '2c1b18',
    accessories: json['accessories'] as String? ?? 'none',
    accessoriesColor: json['accessoriesColor'] as String? ?? '262e33',
    clothing: json['clothing'] as String? ?? 'hoodie',
    clothingColor: json['clothingColor'] as String? ?? '65c9ff',
    backgroundColor: json['backgroundColor'] as String? ?? 'b6e3f4',
  );
}
