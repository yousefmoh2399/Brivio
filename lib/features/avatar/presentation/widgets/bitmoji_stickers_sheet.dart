import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/bitmoji_traits.dart';
import 'bitmoji_renderer.dart';

class BitmojiStickerItem {
  final String title;
  final String subtitle;
  final String emoji;
  final Color themeColor;
  final String mouthOverride;
  final String eyesOverride;

  const BitmojiStickerItem({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.themeColor,
    this.mouthOverride = 'warm_smile',
    this.eyesOverride = 'happy_curved',
  });
}

/// Snapchat-style Sticker Pack sheet generated from custom Bitmoji
class BitmojiStickersSheet extends StatelessWidget {
  final BitmojiTraits traits;
  final ValueChanged<BitmojiTraits>? onApplyStickerExpression;

  const BitmojiStickersSheet({
    super.key,
    required this.traits,
    this.onApplyStickerExpression,
  });

  static void show(
    BuildContext context, {
    required BitmojiTraits traits,
    ValueChanged<BitmojiTraits>? onApplyStickerExpression,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BitmojiStickersSheet(
        traits: traits,
        onApplyStickerExpression: onApplyStickerExpression,
      ),
    );
  }

  static const List<BitmojiStickerItem> stickers = [
    BitmojiStickerItem(
      title: 'أهلاً بك 👋',
      subtitle: 'تحية ترحيبية ودية',
      emoji: '👋',
      themeColor: Color(0xFF0EA5E9),
      mouthOverride: 'wide_grin',
      eyesOverride: 'winking',
    ),
    BitmojiStickerItem(
      title: 'طالب متفوق 🌟',
      subtitle: 'حاصل على الدرجات العلا',
      emoji: '🌟',
      themeColor: Color(0xFFF59E0B),
      mouthOverride: 'confident_smirk',
      eyesOverride: 'focused_round',
    ),
    BitmojiStickerItem(
      title: 'وقت المذاكرة 📖',
      subtitle: 'تركيز ومراجعة الدروس',
      emoji: '📖',
      themeColor: Color(0xFF8B5CF6),
      mouthOverride: 'neutral',
      eyesOverride: 'focused_round',
    ),
    BitmojiStickerItem(
      title: 'مبروك النجاح 🎓',
      subtitle: 'احتفال بالتفوق الدراسي',
      emoji: '🎓',
      themeColor: Color(0xFF10B981),
      mouthOverride: 'wide_grin',
      eyesOverride: 'happy_curved',
    ),
    BitmojiStickerItem(
      title: 'فكرة عبقرية 💡',
      subtitle: 'استيعاب وفهم كامل',
      emoji: '💡',
      themeColor: Color(0xFFEC4899),
      mouthOverride: 'warm_smile',
      eyesOverride: 'happy_curved',
    ),
    BitmojiStickerItem(
      title: 'جاهز للامتحان 💯',
      subtitle: 'استعداد 100% للتفوق',
      emoji: '💯',
      themeColor: Color(0xFFEF4444),
      mouthOverride: 'confident_smirk',
      eyesOverride: 'focused_round',
    ),
    BitmojiStickerItem(
      title: 'عاشق للتعلم 💖',
      subtitle: 'شغف وحب للدراسة',
      emoji: '💖',
      themeColor: Color(0xFFEC4899),
      mouthOverride: 'warm_smile',
      eyesOverride: 'heart_eyes',
    ),
    BitmojiStickerItem(
      title: 'مرح وتحدي 😜',
      subtitle: 'روح معنوية عالية ومرح',
      emoji: '😜',
      themeColor: Color(0xFFF97316),
      mouthOverride: 'playful_tongue',
      eyesOverride: 'winking',
    ),
    BitmojiStickerItem(
      title: 'إصرار وهدوء 🧘',
      subtitle: 'صفاء ذهني وتركيز عميق',
      emoji: '🧘',
      themeColor: Color(0xFF06B6D4),
      mouthOverride: 'neutral',
      eyesOverride: 'happy_curved',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth >= 1100
        ? 5
        : (screenWidth >= 800
            ? 4
            : (screenWidth >= 520 ? 3 : 2));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.80,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('✨', style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'ملصقات Bitmoji الخاصة بك 🎭',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'اختر أي ملصق لتطبيق تعبيراته على شخصيتك أو استخدامها في الدروس والمحادثات:',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stickers Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: crossAxisCount >= 4 ? 0.90 : 0.82,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: stickers.length,
                    itemBuilder: (context, index) {
                      final sticker = stickers[index];
                      final stickerTraits = traits.copyWith(
                        mouth: sticker.mouthOverride,
                        eyes: sticker.eyesOverride,
                      );

                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onApplyStickerExpression?.call(stickerTraits);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم تفعيل تعبير "${sticker.title}"!'),
                              backgroundColor: sticker.themeColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sticker.themeColor.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: sticker.themeColor.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BitmojiRenderer(
                                    traits: stickerTraits,
                                    cameraFocus: AvatarCameraFocus.face,
                                    isAnimated: false,
                                    showPedestal: false,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: sticker.themeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  sticker.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: sticker.themeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
