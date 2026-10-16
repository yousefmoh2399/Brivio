import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/bitmoji_traits.dart';

/// High-performance native CustomPainter rendering a layered 2D/3D Snapchat Bitmoji character.
class BitmojiCustomPainter extends CustomPainter {
  final BitmojiTraits traits;
  final double blinkValue; // 0.0 (open) to 1.0 (closed)
  final double breathOffset; // subtle breathing animation
  final bool showFullBody;

  BitmojiCustomPainter({
    required this.traits,
    this.blinkValue = 0.0,
    this.breathOffset = 0.0,
    this.showFullBody = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.44 + breathOffset;

    // ── Layer 0: Background Studio & Pedestal ──
    _paintBackground(canvas, size, cx, h);

    // ── Layer 1: Body, Neck & Clothes ──
    _paintBodyAndOutfit(canvas, size, cx, cy);

    // ── Layer 2: Head & Face Shape ──
    _paintHeadAndFace(canvas, size, cx, cy);

    // ── Layer 3: Ears & Cheeks ──
    _paintEarsAndCheeks(canvas, cx, cy);

    // ── Layer 4: Facial Features (Eyes, Eyebrows, Nose, Mouth) ──
    _paintFacialFeatures(canvas, cx, cy);

    // ── Layer 5: Facial Hair (Beard & Mustache) ──
    if (traits.facialHair != 'none') {
      _paintFacialHair(canvas, cx, cy);
    }

    // ── Layer 6: Hair Front & Headwear (Hijab, Caps, Hairstyles) ──
    _paintHairAndHeadwear(canvas, cx, cy);

    // ── Layer 7: Eyewear (Glasses & Sunglasses) ──
    if (traits.eyewear != 'none') {
      _paintEyewear(canvas, cx, cy);
    }
  }

  void _paintBackground(Canvas canvas, Size size, double cx, double h) {
    final rect = Offset.zero & size;

    // Background Gradient / Glow
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 0.9,
        colors: [
          traits.backgroundColor.withValues(alpha: 0.9),
          traits.backgroundColor.withValues(alpha: 0.4),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    if (showFullBody) {
      // 3D Pedestal Platform
      final platformRect = Rect.fromCenter(
        center: Offset(cx, h * 0.94),
        width: size.width * 0.72,
        height: size.height * 0.12,
      );

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawOval(platformRect.translate(0, 8), shadowPaint);

      final platformPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.4),
          ],
        ).createShader(platformRect);
      canvas.drawOval(platformRect, platformPaint);
    }
  }

  void _paintBodyAndOutfit(Canvas canvas, Size size, double cx, double cy) {
    final neckW = size.width * 0.14;
    final neckH = size.height * 0.16;
    final neckTop = cy + size.height * 0.12;

    // Neck
    final neckRect = Rect.fromCenter(
      center: Offset(cx, neckTop + neckH / 2),
      width: neckW,
      height: neckH,
    );
    final neckPaint = Paint()..color = traits.skinColor;
    canvas.drawRRect(RRect.fromRectAndRadius(neckRect, const Radius.circular(8)), neckPaint);

    // Chin shadow on neck
    final shadowPath = Path()
      ..moveTo(cx - neckW / 2, neckTop)
      ..quadraticBezierTo(cx, neckTop + 14, cx + neckW / 2, neckTop)
      ..close();
    final chinShadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.15);
    canvas.drawPath(shadowPath, chinShadowPaint);

    // Shoulders & Torso
    final torsoTop = neckTop + neckH * 0.45;
    final torsoW = size.width * 0.64;

    final outfitPath = Path();
    outfitPath.moveTo(cx - neckW * 0.8, torsoTop);
    outfitPath.quadraticBezierTo(cx - torsoW * 0.5, torsoTop + 24, cx - torsoW * 0.55, size.height);
    outfitPath.lineTo(cx + torsoW * 0.55, size.height);
    outfitPath.quadraticBezierTo(cx + torsoW * 0.5, torsoTop + 24, cx + neckW * 0.8, torsoTop);
    outfitPath.close();

    final outfitPaint = Paint()..color = traits.outfitColor;
    canvas.drawPath(outfitPath, outfitPaint);

    // Outfit Specific Details (Hoodie strings, collar, tie, etc.)
    final accentPaint = Paint()
      ..color = traits.outfitAccentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    if (traits.outfit == 'hoodie') {
      // Hoodie neckline & pocket curve
      final hoodCollar = Path()
        ..moveTo(cx - neckW * 0.9, torsoTop)
        ..quadraticBezierTo(cx, torsoTop + 32, cx + neckW * 0.9, torsoTop);
      canvas.drawPath(hoodCollar, accentPaint);

      // Drawstrings
      final stringPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 14, torsoTop + 26), Offset(cx - 14, torsoTop + 70), stringPaint);
      canvas.drawLine(Offset(cx + 14, torsoTop + 26), Offset(cx + 14, torsoTop + 70), stringPaint);
    } else if (traits.outfit == 'blazer') {
      // White shirt inner
      final shirtPath = Path()
        ..moveTo(cx - neckW * 0.6, torsoTop)
        ..lineTo(cx, torsoTop + 60)
        ..lineTo(cx + neckW * 0.6, torsoTop)
        ..close();
      canvas.drawPath(shirtPath, Paint()..color = Colors.white);

      // Red/Gold Tie
      final tiePath = Path()
        ..moveTo(cx - 7, torsoTop + 14)
        ..lineTo(cx + 7, torsoTop + 14)
        ..lineTo(cx + 10, torsoTop + 70)
        ..lineTo(cx, torsoTop + 85)
        ..lineTo(cx - 10, torsoTop + 70)
        ..close();
      canvas.drawPath(tiePath, Paint()..color = traits.outfitAccentColor);

      // Blazer lapels
      canvas.drawLine(Offset(cx - neckW * 0.8, torsoTop), Offset(cx - 8, torsoTop + 80), accentPaint);
      canvas.drawLine(Offset(cx + neckW * 0.8, torsoTop), Offset(cx + 8, torsoTop + 80), accentPaint);
    } else {
      // Casual Collar
      final collarPath = Path()
        ..moveTo(cx - neckW * 0.7, torsoTop)
        ..quadraticBezierTo(cx, torsoTop + 20, cx + neckW * 0.7, torsoTop);
      canvas.drawPath(collarPath, accentPaint);
    }
  }

  void _paintHeadAndFace(Canvas canvas, Size size, double cx, double cy) {
    final headW = size.width * 0.38;
    final headH = size.height * 0.36;

    final headPath = Path();

    switch (traits.faceShape) {
      case 'square':
        headPath.moveTo(cx - headW / 2, cy - headH * 0.35);
        headPath.quadraticBezierTo(cx - headW / 2, cy + headH * 0.38, cx - headW * 0.28, cy + headH * 0.5);
        headPath.quadraticBezierTo(cx, cy + headH * 0.54, cx + headW * 0.28, cy + headH * 0.5);
        headPath.quadraticBezierTo(cx + headW / 2, cy + headH * 0.38, cx + headW / 2, cy - headH * 0.35);
        headPath.quadraticBezierTo(cx, cy - headH * 0.54, cx - headW / 2, cy - headH * 0.35);
        break;

      case 'round':
        headPath.addOval(Rect.fromCenter(center: Offset(cx, cy), width: headW * 1.05, height: headH));
        break;

      case 'heart':
        headPath.moveTo(cx - headW / 2, cy - headH * 0.35);
        headPath.quadraticBezierTo(cx - headW * 0.45, cy + headH * 0.25, cx, cy + headH * 0.52);
        headPath.quadraticBezierTo(cx + headW * 0.45, cy + headH * 0.25, cx + headW / 2, cy - headH * 0.35);
        headPath.quadraticBezierTo(cx, cy - headH * 0.52, cx - headW / 2, cy - headH * 0.35);
        break;

      case 'oval':
      default:
        headPath.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: headW, height: headH),
            Radius.circular(headW * 0.45),
          ),
        );
        break;
    }

    // Face Base Color
    final facePaint = Paint()..color = traits.skinColor;
    canvas.drawPath(headPath, facePaint);

    // Subtle 3D Ambient Edge Shading
    final edgeShader = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.1, -0.1),
        radius: 0.85,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.08),
        ],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: headW, height: headH));
    canvas.drawPath(headPath, edgeShader);
  }

  void _paintEarsAndCheeks(Canvas canvas, double cx, double cy) {
    const earW = 14.0;
    const earH = 26.0;
    const earOffset = 68.0;

    final earPaint = Paint()..color = traits.skinColor;
    final innerEarPaint = Paint()..color = Colors.black.withValues(alpha: 0.08);

    // Left Ear
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - earOffset, cy), width: earW, height: earH), earPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - earOffset + 2, cy), width: earW * 0.5, height: earH * 0.5), innerEarPaint);

    // Right Ear
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + earOffset, cy), width: earW, height: earH), earPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + earOffset - 2, cy), width: earW * 0.5, height: earH * 0.5), innerEarPaint);

    // Cute Cheeks Blush
    final blushPaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 36, cy + 18), width: 22, height: 12), blushPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 36, cy + 18), width: 22, height: 12), blushPaint);
  }

  void _paintFacialFeatures(Canvas canvas, double cx, double cy) {
    // ── Eyes ──
    const eyeSpacing = 32.0;
    const eyeY = -4.0;

    if (blinkValue >= 0.7) {
      // Blinking Eyes (Happy arcs)
      final blinkPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final leftBlink = Path()
        ..moveTo(cx - eyeSpacing - 12, cy + eyeY)
        ..quadraticBezierTo(cx - eyeSpacing, cy + eyeY - 6, cx - eyeSpacing + 12, cy + eyeY);
      canvas.drawPath(leftBlink, blinkPaint);

      final rightBlink = Path()
        ..moveTo(cx + eyeSpacing - 12, cy + eyeY)
        ..quadraticBezierTo(cx + eyeSpacing, cy + eyeY - 6, cx + eyeSpacing + 12, cy + eyeY);
      canvas.drawPath(rightBlink, blinkPaint);
    } else {
      // Open Eyes
      _drawEye(canvas, Offset(cx - eyeSpacing, cy + eyeY), isRight: false);
      _drawEye(canvas, Offset(cx + eyeSpacing, cy + eyeY), isRight: true);
    }

    // ── Eyebrows ──
    final browPaint = Paint()
      ..color = traits.hairColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const browY = -22.0;
    final leftBrow = Path()
      ..moveTo(cx - eyeSpacing - 14, cy + browY + 2)
      ..quadraticBezierTo(cx - eyeSpacing, cy + browY - 4, cx - eyeSpacing + 14, cy + browY);
    canvas.drawPath(leftBrow, browPaint);

    final rightBrow = Path()
      ..moveTo(cx + eyeSpacing - 14, cy + browY)
      ..quadraticBezierTo(cx + eyeSpacing, cy + browY - 4, cx + eyeSpacing + 14, cy + browY + 2);
    canvas.drawPath(rightBrow, browPaint);

    // ── Nose ──
    final nosePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final nosePath = Path()
      ..moveTo(cx, cy + 8)
      ..lineTo(cx + 3, cy + 20)
      ..quadraticBezierTo(cx, cy + 24, cx - 4, cy + 22);
    canvas.drawPath(nosePath, nosePaint);

    // ── Mouth ──
    const mouthY = 40.0;
    if (traits.mouth == 'wide_grin') {
      final mouthPath = Path()
        ..moveTo(cx - 18, cy + mouthY)
        ..quadraticBezierTo(cx, cy + mouthY + 18, cx + 18, cy + mouthY)
        ..close();
      canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF881337));

      // Teeth
      canvas.save();
      canvas.clipPath(mouthPath);
      canvas.drawRect(Rect.fromLTWH(cx - 16, cy + mouthY - 2, 32, 8), Paint()..color = Colors.white);
      canvas.restore();
    } else {
      // Warm Smile
      final mouthPaint = Paint()
        ..color = const Color(0xFF881337)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final smile = Path()
        ..moveTo(cx - 16, cy + mouthY)
        ..quadraticBezierTo(cx, cy + mouthY + 10, cx + 16, cy + mouthY);
      canvas.drawPath(smile, mouthPaint);
    }
  }

  void _drawEye(Canvas canvas, Offset center, {required bool isRight}) {
    const eyeRadius = 11.0;

    // Sclera (White)
    canvas.drawOval(
      Rect.fromCenter(center: center, width: eyeRadius * 2, height: eyeRadius * 1.6),
      Paint()..color = Colors.white,
    );

    // Iris (Color)
    final irisPaint = Paint()..color = traits.eyeColor;
    canvas.drawCircle(center, eyeRadius * 0.65, irisPaint);

    // Pupil (Black)
    canvas.drawCircle(center, eyeRadius * 0.38, Paint()..color = Colors.black87);

    // Specular Catchlight Sparkle (Cute Anime / Bitmoji Reflection)
    canvas.drawCircle(Offset(center.dx - 3, center.dy - 3), 2.2, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(center.dx + 2, center.dy + 2), 1.0, Paint()..color = Colors.white70);

    // Eyelid line
    final eyelidPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final eyelidPath = Path()
      ..moveTo(center.dx - eyeRadius, center.dy - 2)
      ..quadraticBezierTo(center.dx, center.dy - eyeRadius * 1.05, center.dx + eyeRadius, center.dy - 2);
    canvas.drawPath(eyelidPath, eyelidPaint);
  }

  void _paintFacialHair(Canvas canvas, double cx, double cy) {
    final beardPaint = Paint()
      ..color = traits.facialHairColor
      ..strokeCap = StrokeCap.round;

    if (traits.facialHair == 'stubble') {
      final stubbleShader = Paint()
        ..color = traits.facialHairColor.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + 46), width: 56, height: 26), stubbleShader);
    } else if (traits.facialHair == 'full_beard') {
      final beardPath = Path()
        ..moveTo(cx - 48, cy + 12)
        ..quadraticBezierTo(cx - 52, cy + 62, cx, cy + 74)
        ..quadraticBezierTo(cx + 52, cy + 62, cx + 48, cy + 12)
        ..quadraticBezierTo(cx + 36, cy + 54, cx, cy + 56)
        ..quadraticBezierTo(cx - 36, cy + 54, cx - 48, cy + 12)
        ..close();
      canvas.drawPath(beardPath, beardPaint);
    } else if (traits.facialHair == 'mustache') {
      final mustachePath = Path()
        ..moveTo(cx - 24, cy + 34)
        ..quadraticBezierTo(cx - 10, cy + 28, cx, cy + 32)
        ..quadraticBezierTo(cx + 10, cy + 28, cx + 24, cy + 34)
        ..quadraticBezierTo(cx + 10, cy + 38, cx, cy + 35)
        ..quadraticBezierTo(cx - 10, cy + 38, cx - 24, cy + 34)
        ..close();
      canvas.drawPath(mustachePath, beardPaint);
    }
  }

  void _paintHairAndHeadwear(Canvas canvas, double cx, double cy) {
    final hairPaint = Paint()..color = traits.hairColor;

    if (traits.hairStyle == 'hijab') {
      // 🧕 Elegant Islamic Hijab Wrap (Snapchat/Bitmoji standard)
      final hijabPath = Path()
        ..moveTo(cx - 68, cy - 20)
        ..quadraticBezierTo(cx, cy - 90, cx + 68, cy - 20)
        ..quadraticBezierTo(cx + 74, cy + 60, cx + 38, cy + 100)
        ..quadraticBezierTo(cx, cy + 115, cx - 38, cy + 100)
        ..quadraticBezierTo(cx - 74, cy + 60, cx - 68, cy - 20)
        ..close();

      canvas.drawPath(hijabPath, Paint()..color = traits.headwearColor);

      // Inner Fold Line & Pin
      final innerFold = Path()
        ..moveTo(cx - 54, cy - 10)
        ..quadraticBezierTo(cx, cy - 70, cx + 54, cy - 10)
        ..quadraticBezierTo(cx + 46, cy + 45, cx, cy + 65)
        ..quadraticBezierTo(cx - 46, cy + 45, cx - 54, cy - 10);
      canvas.drawPath(innerFold, Paint()..color = Colors.black.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 3);
    } else if (traits.hairStyle == 'long_waves') {
      // Long Wavy Hair
      final hairPath = Path()
        ..moveTo(cx - 62, cy + 50)
        ..quadraticBezierTo(cx - 68, cy - 70, cx, cy - 78)
        ..quadraticBezierTo(cx + 68, cy - 70, cx + 62, cy + 50)
        ..quadraticBezierTo(cx + 48, cy - 30, cx, cy - 54)
        ..quadraticBezierTo(cx - 48, cy - 30, cx - 62, cy + 50)
        ..close();
      canvas.drawPath(hairPath, hairPaint);
    } else if (traits.hairStyle == 'buzz_cut') {
      // Clean short buzz
      final buzzPath = Path()
        ..moveTo(cx - 58, cy - 10)
        ..quadraticBezierTo(cx, cy - 74, cx + 58, cy - 10)
        ..quadraticBezierTo(cx, cy - 50, cx - 58, cy - 10);
      canvas.drawPath(buzzPath, hairPaint);
    } else {
      // Default: Short Modern Curly Crop (Bitmoji Hero)
      final hairPath = Path()
        ..moveTo(cx - 64, cy - 10)
        ..quadraticBezierTo(cx - 70, cy - 65, cx - 30, cy - 80)
        ..quadraticBezierTo(cx, cy - 88, cx + 30, cy - 80)
        ..quadraticBezierTo(cx + 70, cy - 65, cx + 64, cy - 10)
        ..quadraticBezierTo(cx + 50, cy - 40, cx + 18, cy - 56)
        ..quadraticBezierTo(cx, cy - 60, cx - 20, cy - 56)
        ..quadraticBezierTo(cx - 50, cy - 40, cx - 64, cy - 10)
        ..close();
      canvas.drawPath(hairPath, hairPaint);

      // Curls highlights
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx - 16, cy - 66), radius: 10), -math.pi / 2, math.pi, false, highlightPaint);
      canvas.drawArc(Rect.fromCircle(center: Offset(cx + 14, cy - 68), radius: 12), -math.pi / 2, math.pi, false, highlightPaint);
    }
  }

  void _paintEyewear(Canvas canvas, double cx, double cy) {
    const eyeSpacing = 32.0;
    const glassesY = -4.0;
    const lensW = 34.0;
    const lensH = 26.0;

    final framePaint = Paint()
      ..color = traits.eyewearColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final lensTintPaint = Paint()
      ..color = (traits.eyewear == 'sunglasses')
          ? Colors.black.withValues(alpha: 0.8)
          : Colors.cyan.withValues(alpha: 0.12);

    // Left Lens
    final leftRect = Rect.fromCenter(center: Offset(cx - eyeSpacing, cy + glassesY), width: lensW, height: lensH);
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(8)), lensTintPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(8)), framePaint);

    // Right Lens
    final rightRect = Rect.fromCenter(center: Offset(cx + eyeSpacing, cy + glassesY), width: lensW, height: lensH);
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(8)), lensTintPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(8)), framePaint);

    // Bridge
    canvas.drawLine(
      Offset(cx - eyeSpacing + lensW / 2, cy + glassesY),
      Offset(cx + eyeSpacing - lensW / 2, cy + glassesY),
      framePaint,
    );

    // Glare shine reflection line
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx - eyeSpacing - 8, cy + glassesY - 8), Offset(cx - eyeSpacing + 4, cy + glassesY + 4), shinePaint);
    canvas.drawLine(Offset(cx + eyeSpacing - 8, cy + glassesY - 8), Offset(cx + eyeSpacing + 4, cy + glassesY + 4), shinePaint);
  }

  @override
  bool shouldRepaint(covariant BitmojiCustomPainter oldDelegate) {
    return oldDelegate.traits != traits ||
        oldDelegate.blinkValue != blinkValue ||
        oldDelegate.breathOffset != breathOffset ||
        oldDelegate.showFullBody != showFullBody;
  }
}
