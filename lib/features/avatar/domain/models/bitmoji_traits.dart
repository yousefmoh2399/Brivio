import 'package:flutter/material.dart';

/// Represents camera zoom focus in the Snapchat Bitmoji Studio
enum AvatarCameraFocus {
  fullBody,
  face,
  eyes,
  hair,
  outfit,
}

/// Category tabs in the Bitmoji Studio
enum AvatarCustomizationSection {
  genderBody,
  faceShape,
  skinTone,
  hairStyle,
  hairColor,
  eyes,
  eyeColor,
  eyebrows,
  nose,
  mouth,
  facialHair,
  eyewear,
  headwear,
  outfit,
  background,
}

/// Bitmoji Trait Configuration holding the full vector composition state
class BitmojiTraits {
  final String gender; // 'male', 'female'
  final String faceShape; // 'oval', 'square', 'round', 'heart', 'sharp'
  final Color skinColor;
  final String hairStyle;
  final Color hairColor;
  final String eyes;
  final Color eyeColor;
  final String eyebrows;
  final String nose;
  final String mouth;
  final String facialHair;
  final Color facialHairColor;
  final String eyewear;
  final Color eyewearColor;
  final String headwear;
  final Color headwearColor;
  final String outfit;
  final Color outfitColor;
  final Color outfitAccentColor;
  final String backgroundStyle;
  final Color backgroundColor;

  const BitmojiTraits({
    this.gender = 'male',
    this.faceShape = 'oval',
    this.skinColor = const Color(0xFFF3C7A8),
    this.hairStyle = 'short_curly',
    this.hairColor = const Color(0xFF2C1B18),
    this.eyes = 'happy_curved',
    this.eyeColor = const Color(0xFF4A312C),
    this.eyebrows = 'natural_soft',
    this.nose = 'straight_clean',
    this.mouth = 'warm_smile',
    this.facialHair = 'none',
    this.facialHairColor = const Color(0xFF2C1B18),
    this.eyewear = 'none',
    this.eyewearColor = const Color(0xFF1E293B),
    this.headwear = 'none',
    this.headwearColor = const Color(0xFF0EA5E9),
    this.outfit = 'hoodie',
    this.outfitColor = const Color(0xFF0EA5E9),
    this.outfitAccentColor = const Color(0xFF38BDF8),
    this.backgroundStyle = 'studio_pedestal',
    this.backgroundColor = const Color(0xFFE0F2FE),
  });

  BitmojiTraits copyWith({
    String? gender,
    String? faceShape,
    Color? skinColor,
    String? hairStyle,
    Color? hairColor,
    String? eyes,
    Color? eyeColor,
    String? eyebrows,
    String? nose,
    String? mouth,
    String? facialHair,
    Color? facialHairColor,
    String? eyewear,
    Color? eyewearColor,
    String? headwear,
    Color? headwearColor,
    String? outfit,
    Color? outfitColor,
    Color? outfitAccentColor,
    String? backgroundStyle,
    Color? backgroundColor,
  }) {
    return BitmojiTraits(
      gender: gender ?? this.gender,
      faceShape: faceShape ?? this.faceShape,
      skinColor: skinColor ?? this.skinColor,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      eyes: eyes ?? this.eyes,
      eyeColor: eyeColor ?? this.eyeColor,
      eyebrows: eyebrows ?? this.eyebrows,
      nose: nose ?? this.nose,
      mouth: mouth ?? this.mouth,
      facialHair: facialHair ?? this.facialHair,
      facialHairColor: facialHairColor ?? this.facialHairColor,
      eyewear: eyewear ?? this.eyewear,
      eyewearColor: eyewearColor ?? this.eyewearColor,
      headwear: headwear ?? this.headwear,
      headwearColor: headwearColor ?? this.headwearColor,
      outfit: outfit ?? this.outfit,
      outfitColor: outfitColor ?? this.outfitColor,
      outfitAccentColor: outfitAccentColor ?? this.outfitAccentColor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'gender': gender,
    'faceShape': faceShape,
    'skinColor': skinColor.toARGB32(),
    'hairStyle': hairStyle,
    'hairColor': hairColor.toARGB32(),
    'eyes': eyes,
    'eyeColor': eyeColor.toARGB32(),
    'eyebrows': eyebrows,
    'nose': nose,
    'mouth': mouth,
    'facialHair': facialHair,
    'facialHairColor': facialHairColor.toARGB32(),
    'eyewear': eyewear,
    'eyewearColor': eyewearColor.toARGB32(),
    'headwear': headwear,
    'headwearColor': headwearColor.toARGB32(),
    'outfit': outfit,
    'outfitColor': outfitColor.toARGB32(),
    'outfitAccentColor': outfitAccentColor.toARGB32(),
    'backgroundStyle': backgroundStyle,
    'backgroundColor': backgroundColor.toARGB32(),
  };

  factory BitmojiTraits.fromJson(Map<String, dynamic> json) => BitmojiTraits(
    gender: json['gender'] as String? ?? 'male',
    faceShape: json['faceShape'] as String? ?? 'oval',
    skinColor: Color(json['skinColor'] as int? ?? 0xFFF3C7A8),
    hairStyle: json['hairStyle'] as String? ?? 'short_curly',
    hairColor: Color(json['hairColor'] as int? ?? 0xFF2C1B18),
    eyes: json['eyes'] as String? ?? 'happy_curved',
    eyeColor: Color(json['eyeColor'] as int? ?? 0xFF4A312C),
    eyebrows: json['eyebrows'] as String? ?? 'natural_soft',
    nose: json['nose'] as String? ?? 'straight_clean',
    mouth: json['mouth'] as String? ?? 'warm_smile',
    facialHair: json['facialHair'] as String? ?? 'none',
    facialHairColor: Color(json['facialHairColor'] as int? ?? 0xFF2C1B18),
    eyewear: json['eyewear'] as String? ?? 'none',
    eyewearColor: Color(json['eyewearColor'] as int? ?? 0xFF1E293B),
    headwear: json['headwear'] as String? ?? 'none',
    headwearColor: Color(json['headwearColor'] as int? ?? 0xFF0EA5E9),
    outfit: json['outfit'] as String? ?? 'hoodie',
    outfitColor: Color(json['outfitColor'] as int? ?? 0xFF0EA5E9),
    outfitAccentColor: Color(json['outfitAccentColor'] as int? ?? 0xFF38BDF8),
    backgroundStyle: json['backgroundStyle'] as String? ?? 'studio_pedestal',
    backgroundColor: Color(json['backgroundColor'] as int? ?? 0xFFE0F2FE),
  );

  /// Palette of authentic skin tones
  static const List<Color> skinPalette = [
    Color(0xFFFDDFCE), // Porcelain
    Color(0xFFF7D0B7), // Fair Warm
    Color(0xFFF3C7A8), // Honey Wheat
    Color(0xFFE5B592), // Golden Tan
    Color(0xFFD49B72), // Mediterranean
    Color(0xFFBE7E53), // Bronze
    Color(0xFFA26239), // Rich Chestnut
    Color(0xFF7A4526), // Deep Espresso
    Color(0xFF552D16), // Ebony Dark
  ];

  /// Palette of hair colors
  static const List<Color> hairPalette = [
    Color(0xFF1B1B1B), // Jet Black
    Color(0xFF3B261D), // Dark Mocha
    Color(0xFF5E3827), // Chestnut Brown
    Color(0xFF88492C), // Auburn Red
    Color(0xFFB5743D), // Warm Amber
    Color(0xFFDAB377), // Honey Blonde
    Color(0xFFEFE2C5), // Platinum Light
    Color(0xFF9E9E9E), // Silver Grey
    Color(0xFF7C3AED), // Creative Violet
    Color(0xFFEC4899), // Neon Pink
    Color(0xFF0EA5E9), // Cyber Sky
  ];

  /// Palette of eye colors
  static const List<Color> eyePalette = [
    Color(0xFF332018), // Deep Brown
    Color(0xFF5C3A21), // Amber Hazel
    Color(0xFF2E6347), // Emerald Green
    Color(0xFF1E40AF), // Ocean Sapphire
    Color(0xFF0284C7), // Sky Ice Blue
    Color(0xFF6B7280), // Cool Grey
  ];

  /// Palette of outfit colors
  static const List<Color> outfitPalette = [
    Color(0xFF0EA5E9), // Brivio Cyan
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF8B5CF6), // Royal Purple
    Color(0xFFEC4899), // Hot Pink
    Color(0xFFEF4444), // Crimson Red
    Color(0xFFF59E0B), // Warm Gold
    Color(0xFF10B981), // Emerald Green
    Color(0xFF0F172A), // Midnight Slate
    Color(0xFFF8FAFC), // Pure White
    Color(0xFF64748B), // Slate Grey
  ];

  /// Palette of background studio colors
  static const List<Color> backgroundPalette = [
    Color(0xFFE0F2FE), // Soft Sky
    Color(0xFFEDE9FE), // Lavender Dream
    Color(0xFFFCE7F3), // Pastel Rose
    Color(0xFFFEF3C7), // Sunshine Amber
    Color(0xFFD1FAE5), // Mint Green
    Color(0xFFF1F5F9), // Modern Crisp
    Color(0xFF0F172A), // Dark Studio Neon
    Color(0xFF1E1B4B), // Midnight Violet
  ];
}
