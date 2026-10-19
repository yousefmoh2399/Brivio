import 'package:flutter/material.dart';

// ============================================================
//  AvatarConfig — Full Snapchat/Bitmoji-style avatar model
//  Uses DiceBear Avataaars v9 API for high-quality SVG rendering
// ============================================================

/// All customizable sections in the avatar studio (like Snapchat tabs)
enum AvatarSection {
  style,
  skin,
  hair,
  hairColor,
  eyes,
  eyebrows,
  mouth,
  facialHair,
  eyewear,
  headwear,
  outfit,
  background,
}

extension AvatarSectionLabel on AvatarSection {
  String get label => switch (this) {
        AvatarSection.style => 'النمط',
        AvatarSection.skin => 'البشرة',
        AvatarSection.hair => 'الشعر',
        AvatarSection.hairColor => 'لون الشعر',
        AvatarSection.eyes => 'العيون',
        AvatarSection.eyebrows => 'الحواجب',
        AvatarSection.mouth => 'الفم',
        AvatarSection.facialHair => 'اللحية',
        AvatarSection.eyewear => 'النظارة',
        AvatarSection.headwear => 'الغطاء',
        AvatarSection.outfit => 'الملابس',
        AvatarSection.background => 'الخلفية',
      };

  String get icon => switch (this) {
        AvatarSection.style => '🎭',
        AvatarSection.skin => '🤎',
        AvatarSection.hair => '💇',
        AvatarSection.hairColor => '🎨',
        AvatarSection.eyes => '👁️',
        AvatarSection.eyebrows => '〰️',
        AvatarSection.mouth => '😊',
        AvatarSection.facialHair => '🧔',
        AvatarSection.eyewear => '👓',
        AvatarSection.headwear => '🧢',
        AvatarSection.outfit => '👕',
        AvatarSection.background => '🖼️',
      };
}

/// Named option for any trait (shown as a labeled tile in the picker)
class AvatarOption {
  final String id; // DiceBear API value
  final String label; // Arabic display name
  final String? emoji;
  final Color? previewColor;

  const AvatarOption({
    required this.id,
    required this.label,
    this.emoji,
    this.previewColor,
  });
}

/// Full avatar configuration — maps 1:1 to DiceBear Avataaars v9 parameters
class AvatarConfig {
  // --- Core style ---
  final String style; // 'avataaars' | 'big-smile' | 'fun-emoji' | 'lorelei'
  final String seed; // randomizer seed

  // --- Skin & Face ---
  final String skinColor; // hex without # e.g. 'F9C9B6'
  final String faceShape; // not in DiceBear directly, affects style

  // --- Hair ---
  final String hairStyle; // top DiceBear option
  final String hairColor; // hex

  // --- Facial features ---
  final String eyes;
  final String eyebrows;
  final String mouth;
  final String facialHair;
  final String facialHairColor; // hex

  // --- Accessories ---
  final String eyewear; // accessories in DiceBear
  final String eyewearColor; // hex
  final String headwear; // hatStyle
  final String headwearColor; // hex

  // --- Outfit ---
  final String outfit; // clothingType
  final String outfitColor; // hex
  final String outfitGraphic; // clothingGraphic

  // --- Background ---
  final Color backgroundColor;
  final String backgroundStyle; // 'gradient' | 'solid' | 'transparent' | 'studio'

  const AvatarConfig({
    this.style = 'avataaars',
    this.seed = 'BrivioUser',
    this.skinColor = 'F9C9B6',
    this.faceShape = 'default',
    this.hairStyle = 'shortFlat',
    this.hairColor = '2C1B18',
    this.eyes = 'default',
    this.eyebrows = 'default',
    this.mouth = 'smile',
    this.facialHair = 'blank',
    this.facialHairColor = '2C1B18',
    this.eyewear = 'blank',
    this.eyewearColor = '1E293B',
    this.headwear = 'noHat',
    this.headwearColor = '0EA5E9',
    this.outfit = 'hoodie',
    this.outfitColor = '0EA5E9',
    this.outfitGraphic = 'blank',
    this.backgroundColor = const Color(0xFFE0F2FE),
    this.backgroundStyle = 'gradient',
  });

  AvatarConfig copyWith({
    String? style,
    String? seed,
    String? skinColor,
    String? faceShape,
    String? hairStyle,
    String? hairColor,
    String? eyes,
    String? eyebrows,
    String? mouth,
    String? facialHair,
    String? facialHairColor,
    String? eyewear,
    String? eyewearColor,
    String? headwear,
    String? headwearColor,
    String? outfit,
    String? outfitColor,
    String? outfitGraphic,
    Color? backgroundColor,
    String? backgroundStyle,
  }) =>
      AvatarConfig(
        style: style ?? this.style,
        seed: seed ?? this.seed,
        skinColor: skinColor ?? this.skinColor,
        faceShape: faceShape ?? this.faceShape,
        hairStyle: hairStyle ?? this.hairStyle,
        hairColor: hairColor ?? this.hairColor,
        eyes: eyes ?? this.eyes,
        eyebrows: eyebrows ?? this.eyebrows,
        mouth: mouth ?? this.mouth,
        facialHair: facialHair ?? this.facialHair,
        facialHairColor: facialHairColor ?? this.facialHairColor,
        eyewear: eyewear ?? this.eyewear,
        eyewearColor: eyewearColor ?? this.eyewearColor,
        headwear: headwear ?? this.headwear,
        headwearColor: headwearColor ?? this.headwearColor,
        outfit: outfit ?? this.outfit,
        outfitColor: outfitColor ?? this.outfitColor,
        outfitGraphic: outfitGraphic ?? this.outfitGraphic,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      );

  /// Builds the DiceBear Avataaars v9 API URL
  String buildAvatarUrl({int size = 256}) {
    final bg = backgroundStyle == 'transparent' ? '' : _colorHex(backgroundColor);

    final params = {
      'seed': seed,
      'size': size.toString(),
      if (skinColor.isNotEmpty) 'skinColor': skinColor,
      if (hairStyle.isNotEmpty && hairStyle != 'blank') 'top': hairStyle,
      if (hairColor.isNotEmpty) 'hairColor': hairColor,
      if (eyes.isNotEmpty) 'eyes': eyes,
      if (eyebrows.isNotEmpty) 'eyebrows': eyebrows,
      if (mouth.isNotEmpty) 'mouth': mouth,
      if (facialHair.isNotEmpty) 'facialHair': facialHair,
      if (facialHairColor.isNotEmpty && facialHair != 'blank')
        'facialHairColor': facialHairColor,
      if (eyewear.isNotEmpty && eyewear != 'blank')
        'accessories': eyewear,
      if (eyewearColor.isNotEmpty && eyewear != 'blank')
        'accessoriesColor': eyewearColor,
      if (headwear.isNotEmpty && headwear != 'noHat')
        'hatColor': headwearColor,
      if (outfit.isNotEmpty) 'clothingType': outfit,
      if (outfitColor.isNotEmpty) 'clothingColor': outfitColor,
      if (outfitGraphic.isNotEmpty && outfitGraphic != 'blank')
        'clothingGraphic': outfitGraphic,
      if (bg.isNotEmpty) 'backgroundColor': bg,
    };

    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    // DiceBear v9 endpoint — PNG format (reliable on all Flutter platforms)
    return 'https://api.dicebear.com/9.x/avataaars/png?$query';
  }

  static String _colorHex(Color c) {
    return c.toARGB32().toRadixString(16).substring(2).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'style': style,
        'seed': seed,
        'skinColor': skinColor,
        'faceShape': faceShape,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'eyes': eyes,
        'eyebrows': eyebrows,
        'mouth': mouth,
        'facialHair': facialHair,
        'facialHairColor': facialHairColor,
        'eyewear': eyewear,
        'eyewearColor': eyewearColor,
        'headwear': headwear,
        'headwearColor': headwearColor,
        'outfit': outfit,
        'outfitColor': outfitColor,
        'outfitGraphic': outfitGraphic,
        'backgroundColor': backgroundColor.toARGB32(),
        'backgroundStyle': backgroundStyle,
      };

  factory AvatarConfig.fromJson(Map<String, dynamic> json) => AvatarConfig(
        style: json['style'] as String? ?? 'avataaars',
        seed: json['seed'] as String? ?? 'BrivioUser',
        skinColor: json['skinColor'] as String? ?? 'F9C9B6',
        faceShape: json['faceShape'] as String? ?? 'default',
        hairStyle: json['hairStyle'] as String? ?? 'shortFlat',
        hairColor: json['hairColor'] as String? ?? '2C1B18',
        eyes: json['eyes'] as String? ?? 'default',
        eyebrows: json['eyebrows'] as String? ?? 'default',
        mouth: json['mouth'] as String? ?? 'smile',
        facialHair: json['facialHair'] as String? ?? 'blank',
        facialHairColor: json['facialHairColor'] as String? ?? '2C1B18',
        eyewear: json['eyewear'] as String? ?? 'blank',
        eyewearColor: json['eyewearColor'] as String? ?? '1E293B',
        headwear: json['headwear'] as String? ?? 'noHat',
        headwearColor: json['headwearColor'] as String? ?? '0EA5E9',
        outfit: json['outfit'] as String? ?? 'hoodie',
        outfitColor: json['outfitColor'] as String? ?? '0EA5E9',
        outfitGraphic: json['outfitGraphic'] as String? ?? 'blank',
        backgroundColor: Color(json['backgroundColor'] as int? ?? 0xFFE0F2FE),
        backgroundStyle: json['backgroundStyle'] as String? ?? 'gradient',
      );

  // ============================================================
  //  Static catalogs — All DiceBear Avataaars v9 valid values
  // ============================================================

  static List<AvatarOption> get skinOptions => const [
        AvatarOption(id: 'F9C9B6', label: 'فاتح جداً', emoji: '🏻', previewColor: Color(0xFFF9C9B6)),
        AvatarOption(id: 'F5CFA0', label: 'وردي فاتح', emoji: '🏼', previewColor: Color(0xFFF5CFA0)),
        AvatarOption(id: 'EAAD80', label: 'قمحي', emoji: '🏽', previewColor: Color(0xFFEAAD80)),
        AvatarOption(id: 'D08B5B', label: 'أسمر', emoji: '🏾', previewColor: Color(0xFFD08B5B)),
        AvatarOption(id: 'AE5D29', label: 'بني', emoji: '🏾', previewColor: Color(0xFFAE5D29)),
        AvatarOption(id: '614335', label: 'داكن', emoji: '🏿', previewColor: Color(0xFF614335)),
        AvatarOption(id: 'FDBCb4', label: 'وردي خفيف', emoji: '🏼', previewColor: Color(0xFFFDBCb4)),
      ];

  static List<AvatarOption> get hairStyleOptions => const [
        AvatarOption(id: 'shortFlat', label: 'قصير ناعم', emoji: '💇'),
        AvatarOption(id: 'shortRound', label: 'قصير مستدير', emoji: '💇'),
        AvatarOption(id: 'shortCurly', label: 'قصير مجعد', emoji: '👦'),
        AvatarOption(id: 'shortWaved', label: 'قصير موجي', emoji: '💈'),
        AvatarOption(id: 'longButNotTooLong', label: 'طويل', emoji: '👧'),
        AvatarOption(id: 'bigHair', label: 'أفرو كبير', emoji: '🎤'),
        AvatarOption(id: 'curly', label: 'مجعد كثيف', emoji: '🌀'),
        AvatarOption(id: 'curlyAndShavedSides', label: 'مجعد جانبي', emoji: '💫'),
        AvatarOption(id: 'dreads01', label: 'ضفائر 1', emoji: '🎵'),
        AvatarOption(id: 'dreads02', label: 'ضفائر 2', emoji: '🎶'),
        AvatarOption(id: 'frizzle', label: 'متمردي', emoji: '⚡'),
        AvatarOption(id: 'froBand', label: 'أفرو بنطاق', emoji: '🎀'),
        AvatarOption(id: 'miaWallace', label: 'بوب كلاسيك', emoji: '✂️'),
        AvatarOption(id: 'straight01', label: 'مستقيم ناعم', emoji: '💎'),
        AvatarOption(id: 'straight02', label: 'مستقيم بشريط', emoji: '🪮'),
        AvatarOption(id: 'shavedSides', label: 'محلوق الجانبين', emoji: '✨'),
        AvatarOption(id: 'theCaesar', label: 'قيصر', emoji: '👑'),
        AvatarOption(id: 'theCaesarAndSidePart', label: 'قيصر بفرقة', emoji: '🔥'),
        AvatarOption(id: 'sides', label: 'جانبي', emoji: '🌊'),
        AvatarOption(id: 'winterHat01', label: 'قبعة شتوية', emoji: '🧢'),
        AvatarOption(id: 'winterHat02', label: 'كاب ملون', emoji: '🎩'),
        AvatarOption(id: 'hijab', label: 'حجاب', emoji: '🧕'),
        AvatarOption(id: 'turban', label: 'عمامة', emoji: '👳'),
        AvatarOption(id: 'hat', label: 'قبعة', emoji: '🎩'),
        AvatarOption(id: 'eyepatch', label: 'رقعة العين', emoji: '🏴‍☠️'),
        AvatarOption(id: 'bob', label: 'قصة بوب', emoji: '🎭'),
        AvatarOption(id: 'bun', label: 'كعكة', emoji: '🍩'),
        AvatarOption(id: 'blank', label: 'لا شعر', emoji: '🤴'),
      ];

  static List<AvatarOption> get hairColorOptions => const [
        AvatarOption(id: '2C1B18', label: 'أسود', previewColor: Color(0xFF2C1B18)),
        AvatarOption(id: '4A312C', label: 'بني داكن', previewColor: Color(0xFF4A312C)),
        AvatarOption(id: '724133', label: 'بني متوسط', previewColor: Color(0xFF724133)),
        AvatarOption(id: 'A55728', label: 'بني فاتح', previewColor: Color(0xFFA55728)),
        AvatarOption(id: 'B58143', label: 'أشقر داكن', previewColor: Color(0xFFB58143)),
        AvatarOption(id: 'D6B370', label: 'أشقر ذهبي', previewColor: Color(0xFFD6B370)),
        AvatarOption(id: 'E8E1E1', label: 'أبيض فضي', previewColor: Color(0xFFE8E1E1)),
        AvatarOption(id: 'F59797', label: 'وردي', previewColor: Color(0xFFF59797)),
        AvatarOption(id: 'EF5350', label: 'أحمر', previewColor: Color(0xFFEF5350)),
        AvatarOption(id: '795548', label: 'بني ترابي', previewColor: Color(0xFF795548)),
        AvatarOption(id: '1B5E20', label: 'أخضر داكن', previewColor: Color(0xFF1B5E20)),
        AvatarOption(id: '0D47A1', label: 'أزرق داكن', previewColor: Color(0xFF0D47A1)),
        AvatarOption(id: '7B1FA2', label: 'بنفسجي', previewColor: Color(0xFF7B1FA2)),
        AvatarOption(id: 'FF7043', label: 'برتقالي', previewColor: Color(0xFFFF7043)),
      ];

  static List<AvatarOption> get eyesOptions => const [
        AvatarOption(id: 'default', label: 'طبيعية', emoji: '👁️'),
        AvatarOption(id: 'closed', label: 'مغلقة', emoji: '😌'),
        AvatarOption(id: 'cry', label: 'حزينة', emoji: '😢'),
        AvatarOption(id: 'eyeRoll', label: 'تحريك العين', emoji: '🙄'),
        AvatarOption(id: 'happy', label: 'سعيدة', emoji: '😊'),
        AvatarOption(id: 'hearts', label: 'قلوب', emoji: '😍'),
        AvatarOption(id: 'side', label: 'جانبية', emoji: '👀'),
        AvatarOption(id: 'squint', label: 'ضيقة', emoji: '😏'),
        AvatarOption(id: 'surprised', label: 'مفاجأة', emoji: '😲'),
        AvatarOption(id: 'wink', label: 'غمزة', emoji: '😉'),
        AvatarOption(id: 'winkWacky', label: 'غمزة مبهجة', emoji: '🤪'),
        AvatarOption(id: 'xDizzy', label: 'دوخة', emoji: '😵'),
      ];

  static List<AvatarOption> get eyebrowsOptions => const [
        AvatarOption(id: 'default', label: 'طبيعية', emoji: '〰️'),
        AvatarOption(id: 'angryNatural', label: 'غاضبة', emoji: '😠'),
        AvatarOption(id: 'defaultNatural', label: 'ناعمة', emoji: '😌'),
        AvatarOption(id: 'flatNatural', label: 'مستقيمة', emoji: '➖'),
        AvatarOption(id: 'frownNatural', label: 'عابسة', emoji: '😟'),
        AvatarOption(id: 'raisedExcited', label: 'مرفوعة', emoji: '😮'),
        AvatarOption(id: 'raisedExcitedNatural', label: 'مرفوعة طبيعية', emoji: '😲'),
        AvatarOption(id: 'sadConcerned', label: 'حزينة', emoji: '😢'),
        AvatarOption(id: 'sadConcernedNatural', label: 'قلقة', emoji: '😟'),
        AvatarOption(id: 'unibrow', label: 'أحادية', emoji: '🦁'),
        AvatarOption(id: 'upDown', label: 'متباينة', emoji: '🤔'),
        AvatarOption(id: 'upDownNatural', label: 'متباينة ناعمة', emoji: '🤨'),
      ];

  static List<AvatarOption> get mouthOptions => const [
        AvatarOption(id: 'smile', label: 'ابتسامة', emoji: '😊'),
        AvatarOption(id: 'default', label: 'طبيعي', emoji: '😐'),
        AvatarOption(id: 'concerned', label: 'قلق', emoji: '😟'),
        AvatarOption(id: 'disbelief', label: 'استغراب', emoji: '😳'),
        AvatarOption(id: 'eating', label: 'يأكل', emoji: '😋'),
        AvatarOption(id: 'grimace', label: 'تشويش', emoji: '😬'),
        AvatarOption(id: 'sad', label: 'حزين', emoji: '😢'),
        AvatarOption(id: 'scream', label: 'صرخة', emoji: '😱'),
        AvatarOption(id: 'serious', label: 'جدي', emoji: '😑'),
        AvatarOption(id: 'tongue', label: 'لسان', emoji: '😛'),
        AvatarOption(id: 'twinkle', label: 'بريق', emoji: '😄'),
        AvatarOption(id: 'vomit', label: 'مستاء', emoji: '🤢'),
      ];

  static List<AvatarOption> get facialHairOptions => const [
        AvatarOption(id: 'blank', label: 'بدون', emoji: '🧒'),
        AvatarOption(id: 'beardLight', label: 'لحية خفيفة', emoji: '🧔'),
        AvatarOption(id: 'beardMagestic', label: 'لحية كبيرة', emoji: '🧔‍♂️'),
        AvatarOption(id: 'beardMedium', label: 'لحية متوسطة', emoji: '👨‍🦱'),
        AvatarOption(id: 'moustacheFancy', label: 'شارب أنيق', emoji: '🧔'),
        AvatarOption(id: 'moustacheMagnum', label: 'شارب كثيف', emoji: '👨'),
      ];

  static List<AvatarOption> get eyewearOptions => const [
        AvatarOption(id: 'blank', label: 'بدون', emoji: '👤'),
        AvatarOption(id: 'kurt', label: 'مستديرة', emoji: '🔵'),
        AvatarOption(id: 'prescription01', label: 'مربعة', emoji: '🟦'),
        AvatarOption(id: 'prescription02', label: 'كلاسيك', emoji: '🟫'),
        AvatarOption(id: 'round', label: 'دائرية', emoji: '⭕'),
        AvatarOption(id: 'sunglasses', label: 'شمسية', emoji: '😎'),
        AvatarOption(id: 'wayfarers', label: 'ريترو', emoji: '🕶️'),
      ];

  static List<AvatarOption> get outfitOptions => const [
        AvatarOption(id: 'hoodie', label: 'هودي', emoji: '🧥'),
        AvatarOption(id: 'blazerAndShirt', label: 'بليزر قميص', emoji: '👔'),
        AvatarOption(id: 'blazerAndSweater', label: 'بليزر كنزة', emoji: '🧣'),
        AvatarOption(id: 'collarAndSweater', label: 'كولار كنزة', emoji: '🎽'),
        AvatarOption(id: 'graphicShirt', label: 'تيشرت مطبوع', emoji: '👕'),
        AvatarOption(id: 'overall', label: 'أوفرول', emoji: '🦺'),
        AvatarOption(id: 'shirtCrewNeck', label: 'قميص دائري', emoji: '👕'),
        AvatarOption(id: 'shirtScoopNeck', label: 'قميص فتحة', emoji: '👚'),
        AvatarOption(id: 'shirtVNeck', label: 'قميص V', emoji: '🩲'),
      ];

  static List<AvatarOption> get outfitColorOptions => const [
        AvatarOption(id: '0EA5E9', label: 'أزرق', previewColor: Color(0xFF0EA5E9)),
        AvatarOption(id: '0D9488', label: 'تركواز', previewColor: Color(0xFF0D9488)),
        AvatarOption(id: '059669', label: 'أخضر', previewColor: Color(0xFF059669)),
        AvatarOption(id: '84CC16', label: 'ليمون', previewColor: Color(0xFF84CC16)),
        AvatarOption(id: 'EAB308', label: 'أصفر', previewColor: Color(0xFFEAB308)),
        AvatarOption(id: 'F59E0B', label: 'ذهبي', previewColor: Color(0xFFF59E0B)),
        AvatarOption(id: 'F97316', label: 'برتقالي', previewColor: Color(0xFFF97316)),
        AvatarOption(id: 'EF4444', label: 'أحمر', previewColor: Color(0xFFEF4444)),
        AvatarOption(id: 'EC4899', label: 'وردي', previewColor: Color(0xFFEC4899)),
        AvatarOption(id: 'A855F7', label: 'بنفسجي', previewColor: Color(0xFFA855F7)),
        AvatarOption(id: '6366F1', label: 'نيلي', previewColor: Color(0xFF6366F1)),
        AvatarOption(id: '0F172A', label: 'كحلي', previewColor: Color(0xFF0F172A)),
        AvatarOption(id: '334155', label: 'رمادي', previewColor: Color(0xFF334155)),
        AvatarOption(id: 'FFFFFF', label: 'أبيض', previewColor: Color(0xFFFFFFFF)),
        AvatarOption(id: 'F1F5F9', label: 'كريمي', previewColor: Color(0xFFF1F5F9)),
      ];

  static List<Color> get backgroundColors => const [
        Color(0xFFE0F2FE), // sky blue
        Color(0xFFDCFCE7), // mint green
        Color(0xFFFEF3C7), // warm yellow
        Color(0xFFFFE4E6), // light rose
        Color(0xFFF3E8FF), // lavender
        Color(0xFFE0E7FF), // indigo light
        Color(0xFFF9FAFB), // near white
        Color(0xFF0F172A), // dark navy
        Color(0xFF1A1A2E), // dark purple
        Color(0xFF0D1B2A), // dark midnight
        Color(0xFF064E3B), // deep forest
        Color(0xFF1E1B4B), // deep indigo
        Color(0xFFFFF7ED), // warm cream
        Color(0xFFF0FDF4), // light jade
        Color(0xFFFDF4FF), // soft violet
        Color(0xFFEFF6FF), // frost blue
      ];

  /// Builds a randomized config for quick exploration
  static AvatarConfig randomize({String? seed}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final s = seed ?? 'random_$ts';
    final skins = skinOptions;
    final hairs = hairStyleOptions;
    final hairColors = hairColorOptions;
    final eyeList = eyesOptions;
    final eyebrowList = eyebrowsOptions;
    final mouthList = mouthOptions;
    final facialHairList = facialHairOptions;
    final bgColors = backgroundColors;
    final outfitList = outfitOptions;
    final outfitColorList = outfitColorOptions;
    return AvatarConfig(
      seed: s,
      skinColor: skins[ts % skins.length].id,
      hairStyle: hairs[(ts ~/ 2) % hairs.length].id,
      hairColor: hairColors[(ts ~/ 3) % hairColors.length].id,
      eyes: eyeList[(ts ~/ 4) % eyeList.length].id,
      eyebrows: eyebrowList[(ts ~/ 5) % eyebrowList.length].id,
      mouth: mouthList[(ts ~/ 6) % mouthList.length].id,
      facialHair: facialHairList[(ts ~/ 7) % facialHairList.length].id,
      backgroundColor: bgColors[(ts ~/ 8) % bgColors.length],
      outfit: outfitList[(ts ~/ 9) % outfitList.length].id,
      outfitColor: outfitColorList[(ts ~/ 10) % outfitColorList.length].id,
    );
  }
}
