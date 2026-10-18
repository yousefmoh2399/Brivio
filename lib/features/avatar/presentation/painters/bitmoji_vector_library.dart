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

    // ── Layer 0: Background Studio & 3D Pedestal ──
    _paintBackground(canvas, size, cx, h);

    // ── Layer 1: Body, Neck & Outfits ──
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

    // 1. Studio Lighting Background (Radial glow)
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.25),
        radius: 0.95,
        colors: [
          traits.backgroundColor.withValues(alpha: 0.95),
          traits.backgroundColor.withValues(alpha: 0.45),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    if (showFullBody) {
      // 2. 3D Pedestal Platform with Concentric Rings and Lighting
      final platformCenter = Offset(cx, h * 0.93);
      final platformWidth = size.width * 0.76;
      final platformHeight = size.height * 0.13;

      // Soft Floor Contact Shadow
      final shadowRect = Rect.fromCenter(
        center: platformCenter.translate(0, 10),
        width: platformWidth * 1.05,
        height: platformHeight * 0.9,
      );
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawOval(shadowRect, shadowPaint);

      // Pedestal Base (Lower Ring)
      final baseRect = Rect.fromCenter(
        center: platformCenter.translate(0, 4),
        width: platformWidth,
        height: platformHeight,
      );
      final basePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.2),
          ],
        ).createShader(baseRect);
      canvas.drawOval(baseRect, basePaint);

      // Pedestal Top Surface (Glowing Disc)
      final topRect = Rect.fromCenter(
        center: platformCenter,
        width: platformWidth * 0.94,
        height: platformHeight * 0.85,
      );
      final topPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0.5),
          ],
        ).createShader(topRect);
      canvas.drawOval(topRect, topPaint);

      // Pedestal Inner Rim
      final rimPaint = Paint()
        ..color = traits.outfitColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawOval(topRect, rimPaint);
    }
  }

  void _paintBodyAndOutfit(Canvas canvas, Size size, double cx, double cy) {
    final neckW = size.width * 0.145;
    final neckH = size.height * 0.16;
    final neckTop = cy + size.height * 0.115;

    // Neck
    final neckRect = Rect.fromCenter(
      center: Offset(cx, neckTop + neckH / 2),
      width: neckW,
      height: neckH,
    );
    final neckPaint = Paint()..color = traits.skinColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(neckRect, const Radius.circular(8)),
      neckPaint,
    );

    // 3D Chin shadow on neck
    final shadowPath = Path()
      ..moveTo(cx - neckW / 2, neckTop)
      ..quadraticBezierTo(cx, neckTop + 16, cx + neckW / 2, neckTop)
      ..close();
    final chinShadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.16);
    canvas.drawPath(shadowPath, chinShadowPaint);

    // Shoulders & Torso
    final torsoTop = neckTop + neckH * 0.42;
    final torsoW = size.width * 0.65;

    final outfitPath = Path();
    outfitPath.moveTo(cx - neckW * 0.85, torsoTop);
    outfitPath.quadraticBezierTo(
      cx - torsoW * 0.5,
      torsoTop + 24,
      cx - torsoW * 0.55,
      size.height,
    );
    outfitPath.lineTo(cx + torsoW * 0.55, size.height);
    outfitPath.quadraticBezierTo(
      cx + torsoW * 0.5,
      torsoTop + 24,
      cx + neckW * 0.85,
      torsoTop,
    );
    outfitPath.close();

    final outfitPaint = Paint()..color = traits.outfitColor;
    canvas.drawPath(outfitPath, outfitPaint);

    // Subtle 3D Torso Gradient Shadow
    final torsoShader = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.15),
        ],
      ).createShader(Rect.fromLTWH(cx - torsoW / 2, torsoTop, torsoW, size.height - torsoTop));
    canvas.drawPath(outfitPath, torsoShader);

    // Outfit Specific Details (Hoodie strings, collar, tie, etc.)
    final accentPaint = Paint()
      ..color = traits.outfitAccentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    if (traits.outfit == 'hoodie') {
      // Hoodie neckline & pocket curve
      final hoodCollar = Path()
        ..moveTo(cx - neckW * 0.95, torsoTop)
        ..quadraticBezierTo(cx, torsoTop + 34, cx + neckW * 0.95, torsoTop);
      canvas.drawPath(hoodCollar, accentPaint);

      // Inner collar shadow
      final innerShadow = Path()
        ..moveTo(cx - neckW * 0.9, torsoTop)
        ..quadraticBezierTo(cx, torsoTop + 28, cx + neckW * 0.9, torsoTop)
        ..lineTo(cx, torsoTop + 14)
        ..close();
      canvas.drawPath(innerShadow, Paint()..color = Colors.black.withValues(alpha: 0.15));

      // Drawstrings with aglet tips
      final stringPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 14, torsoTop + 26), Offset(cx - 14, torsoTop + 72), stringPaint);
      canvas.drawLine(Offset(cx + 14, torsoTop + 26), Offset(cx + 14, torsoTop + 72), stringPaint);

      // Metal aglets
      final agletPaint = Paint()..color = traits.outfitAccentColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - 16, torsoTop + 68, 4, 8), const Radius.circular(2)),
        agletPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx + 12, torsoTop + 68, 4, 8), const Radius.circular(2)),
        agletPaint,
      );
    } else if (traits.outfit == 'formal_blazer' || traits.outfit == 'blazer') {
      // White shirt inner
      final shirtPath = Path()
        ..moveTo(cx - neckW * 0.6, torsoTop)
        ..lineTo(cx, torsoTop + 65)
        ..lineTo(cx + neckW * 0.6, torsoTop)
        ..close();
      canvas.drawPath(shirtPath, Paint()..color = Colors.white);

      // Tie
      final tiePath = Path()
        ..moveTo(cx - 7, torsoTop + 12)
        ..lineTo(cx + 7, torsoTop + 12)
        ..lineTo(cx + 10, torsoTop + 72)
        ..lineTo(cx, torsoTop + 86)
        ..lineTo(cx - 10, torsoTop + 72)
        ..close();
      canvas.drawPath(tiePath, Paint()..color = traits.outfitAccentColor);

      // Tie knot
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, torsoTop + 14), width: 14, height: 10), const Radius.circular(3)),
        Paint()..color = traits.outfitAccentColor,
      );

      // Blazer lapels
      canvas.drawLine(Offset(cx - neckW * 0.85, torsoTop), Offset(cx - 9, torsoTop + 82), accentPaint);
      canvas.drawLine(Offset(cx + neckW * 0.85, torsoTop), Offset(cx + 9, torsoTop + 82), accentPaint);
    } else if (traits.outfit == 'polo') {
      // Polo Collar
      final collarPath = Path()
        ..moveTo(cx - neckW * 0.85, torsoTop)
        ..quadraticBezierTo(cx, torsoTop + 22, cx + neckW * 0.85, torsoTop);
      canvas.drawPath(collarPath, accentPaint);

      // Placket & Buttons
      final placketPaint = Paint()
        ..color = traits.outfitAccentColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - 6, torsoTop + 18, 12, 38), const Radius.circular(3)),
        placketPaint,
      );

      final buttonPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(cx, torsoTop + 26), 2, buttonPaint);
      canvas.drawCircle(Offset(cx, torsoTop + 42), 2, buttonPaint);
    } else {
      // Casual Crew Collar
      final collarPath = Path()
        ..moveTo(cx - neckW * 0.75, torsoTop)
        ..quadraticBezierTo(cx, torsoTop + 20, cx + neckW * 0.75, torsoTop);
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
        headPath.quadraticBezierTo(
          cx - headW / 2,
          cy + headH * 0.38,
          cx - headW * 0.28,
          cy + headH * 0.5,
        );
        headPath.quadraticBezierTo(
          cx,
          cy + headH * 0.54,
          cx + headW * 0.28,
          cy + headH * 0.5,
        );
        headPath.quadraticBezierTo(
          cx + headW / 2,
          cy + headH * 0.38,
          cx + headW / 2,
          cy - headH * 0.35,
        );
        headPath.quadraticBezierTo(
          cx,
          cy - headH * 0.54,
          cx - headW / 2,
          cy - headH * 0.35,
        );
        break;

      case 'round':
        headPath.addOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: headW * 1.05,
            height: headH,
          ),
        );
        break;

      case 'heart':
        headPath.moveTo(cx - headW / 2, cy - headH * 0.35);
        headPath.quadraticBezierTo(
          cx - headW * 0.45,
          cy + headH * 0.25,
          cx,
          cy + headH * 0.52,
        );
        headPath.quadraticBezierTo(
          cx + headW * 0.45,
          cy + headH * 0.25,
          cx + headW / 2,
          cy - headH * 0.35,
        );
        headPath.quadraticBezierTo(
          cx,
          cy - headH * 0.52,
          cx - headW / 2,
          cy - headH * 0.35,
        );
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

    // 3D Ambient Lighting on Face
    final edgeShader = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.12, -0.15),
        radius: 0.88,
        colors: [
          Colors.white.withValues(alpha: 0.14),
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
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - earOffset, cy), width: earW, height: earH),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - earOffset + 2, cy), width: earW * 0.5, height: earH * 0.5),
      innerEarPaint,
    );

    // Right Ear
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + earOffset, cy), width: earW, height: earH),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + earOffset - 2, cy), width: earW * 0.5, height: earH * 0.5),
      innerEarPaint,
    );

    // Cute Cheeks Blush (Snapchat Bitmoji signature)
    final blushPaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 36, cy + 18), width: 24, height: 13),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 36, cy + 18), width: 24, height: 13),
      blushPaint,
    );
  }

  void _paintFacialFeatures(Canvas canvas, double cx, double cy) {
    const eyeSpacing = 32.0;
    const eyeY = -4.0;

    // ── Eyes ──
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
    } else if (traits.eyes == 'winking') {
      _drawEye(canvas, Offset(cx - eyeSpacing, cy + eyeY), isRight: false);
      // Right eye winks
      final winkPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final rightWink = Path()
        ..moveTo(cx + eyeSpacing - 12, cy + eyeY)
        ..quadraticBezierTo(cx + eyeSpacing, cy + eyeY - 6, cx + eyeSpacing + 12, cy + eyeY);
      canvas.drawPath(rightWink, winkPaint);
    } else {
      // Both open eyes
      _drawEye(canvas, Offset(cx - eyeSpacing, cy + eyeY), isRight: false);
      _drawEye(canvas, Offset(cx + eyeSpacing, cy + eyeY), isRight: true);
    }

    // ── Eyebrows ──
    final browPaint = Paint()
      ..color = traits.hairColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
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
      canvas.drawRect(
        Rect.fromLTWH(cx - 16, cy + mouthY - 2, 32, 8),
        Paint()..color = Colors.white,
      );
      // Tongue
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + mouthY + 14), width: 20, height: 12),
        Paint()..color = const Color(0xFFF43F5E),
      );
      canvas.restore();
    } else if (traits.mouth == 'confident_smirk') {
      final mouthPaint = Paint()
        ..color = const Color(0xFF881337)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final smirk = Path()
        ..moveTo(cx - 14, cy + mouthY + 2)
        ..quadraticBezierTo(cx, cy + mouthY + 8, cx + 16, cy + mouthY - 3);
      canvas.drawPath(smirk, mouthPaint);
    } else if (traits.mouth == 'neutral') {
      final mouthPaint = Paint()
        ..color = const Color(0xFF881337)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 12, cy + mouthY + 4), Offset(cx + 12, cy + mouthY + 4), mouthPaint);
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
    const eyeRadius = 11.5;

    // Sclera (White base)
    canvas.drawOval(
      Rect.fromCenter(center: center, width: eyeRadius * 2, height: eyeRadius * 1.65),
      Paint()..color = Colors.white,
    );

    // Subtle Sclera Top Shadow
    final scleraShadow = Path()
      ..moveTo(center.dx - eyeRadius, center.dy - 2)
      ..quadraticBezierTo(center.dx, center.dy - eyeRadius * 1.1, center.dx + eyeRadius, center.dy - 2)
      ..quadraticBezierTo(center.dx, center.dy - 4, center.dx - eyeRadius, center.dy - 2);
    canvas.drawPath(scleraShadow, Paint()..color = Colors.black.withValues(alpha: 0.08));

    // Iris (Rich Eye Color with Gradient)
    final irisCenter = center;
    final irisRadius = eyeRadius * 0.68;
    final irisPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.2),
        radius: 0.9,
        colors: [
          traits.eyeColor,
          traits.eyeColor.withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromCircle(center: irisCenter, radius: irisRadius));
    canvas.drawCircle(irisCenter, irisRadius, irisPaint);

    // Pupil (Black Center)
    canvas.drawCircle(irisCenter, eyeRadius * 0.40, Paint()..color = Colors.black87);

    // Dual Specular Catchlight Sparkles (Snapchat Signature Glow)
    canvas.drawCircle(
      Offset(center.dx - 3.2, center.dy - 3.2),
      2.4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(center.dx + 2.2, center.dy + 2.2),
      1.1,
      Paint()..color = Colors.white70,
    );

    // Upper Eyelid Lash Line
    final eyelidPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final eyelidPath = Path()
      ..moveTo(center.dx - eyeRadius - 1, center.dy - 2)
      ..quadraticBezierTo(
        center.dx,
        center.dy - eyeRadius * 1.08,
        center.dx + eyeRadius + 1,
        center.dy - 2,
      );
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
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 46), width: 56, height: 26),
        stubbleShader,
      );
    } else if (traits.facialHair == 'full_beard' || traits.facialHair == 'trimmed_beard') {
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

    if (traits.hairStyle == 'hijab' ||
        traits.hairStyle == 'hijab_wrapped' ||
        traits.headwear == 'hijab') {
      // 🧕 Elegant Islamic Hijab Wrap (Snapchat/Bitmoji standard)
      final hijabColor = traits.headwearColor;
      final hijabPath = Path()
        ..moveTo(cx - 68, cy - 20)
        ..quadraticBezierTo(cx, cy - 92, cx + 68, cy - 20)
        ..quadraticBezierTo(cx + 74, cy + 62, cx + 38, cy + 102)
        ..quadraticBezierTo(cx, cy + 118, cx - 38, cy + 102)
        ..quadraticBezierTo(cx - 74, cy + 62, cx - 68, cy - 20)
        ..close();

      canvas.drawPath(hijabPath, Paint()..color = hijabColor);

      // Hijab Fabric Lighting Gradient
      final hijabGradient = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.2),
          ],
        ).createShader(Rect.fromCenter(center: Offset(cx, cy + 10), width: 148, height: 210));
      canvas.drawPath(hijabPath, hijabGradient);

      // Inner Fold Line & Face Opening
      final innerFold = Path()
        ..moveTo(cx - 54, cy - 10)
        ..quadraticBezierTo(cx, cy - 72, cx + 54, cy - 10)
        ..quadraticBezierTo(cx + 46, cy + 46, cx, cy + 66)
        ..quadraticBezierTo(cx - 46, cy + 46, cx - 54, cy - 10);
      canvas.drawPath(
        innerFold,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      // Decorative Metallic Hijab Pin
      final pinPaint = Paint()..color = const Color(0xFFF59E0B);
      canvas.drawCircle(Offset(cx, cy + 68), 3.5, pinPaint);
      canvas.drawCircle(Offset(cx, cy + 68), 1.5, Paint()..color = Colors.white);
    } else if (traits.hairStyle == 'long_wavy') {
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
    } else if (traits.hairStyle == 'slick_back') {
      // Slicked back pompadour
      final slickPath = Path()
        ..moveTo(cx - 62, cy - 12)
        ..quadraticBezierTo(cx - 58, cy - 82, cx, cy - 90)
        ..quadraticBezierTo(cx + 58, cy - 82, cx + 62, cy - 12)
        ..quadraticBezierTo(cx + 40, cy - 48, cx, cy - 58)
        ..quadraticBezierTo(cx - 40, cy - 48, cx - 62, cy - 12)
        ..close();
      canvas.drawPath(slickPath, hairPaint);
    } else {
      // Default: Modern Textured Curly Crop (Bitmoji Hero)
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
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx - 16, cy - 66), radius: 10),
        -math.pi / 2,
        math.pi,
        false,
        highlightPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx + 14, cy - 68), radius: 12),
        -math.pi / 2,
        math.pi,
        false,
        highlightPaint,
      );
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
    final leftRect = Rect.fromCenter(
      center: Offset(cx - eyeSpacing, cy + glassesY),
      width: lensW,
      height: lensH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftRect, const Radius.circular(8)),
      lensTintPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftRect, const Radius.circular(8)),
      framePaint,
    );

    // Right Lens
    final rightRect = Rect.fromCenter(
      center: Offset(cx + eyeSpacing, cy + glassesY),
      width: lensW,
      height: lensH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightRect, const Radius.circular(8)),
      lensTintPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightRect, const Radius.circular(8)),
      framePaint,
    );

    // Bridge
    canvas.drawLine(
      Offset(cx - eyeSpacing + lensW / 2, cy + glassesY),
      Offset(cx + eyeSpacing - lensW / 2, cy + glassesY),
      framePaint,
    );

    // Glare shine reflection lines
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(cx - eyeSpacing - 8, cy + glassesY - 8),
      Offset(cx - eyeSpacing + 4, cy + glassesY + 4),
      shinePaint,
    );
    canvas.drawLine(
      Offset(cx + eyeSpacing - 8, cy + glassesY - 8),
      Offset(cx + eyeSpacing + 4, cy + glassesY + 4),
      shinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant BitmojiCustomPainter oldDelegate) {
    return oldDelegate.traits != traits ||
        oldDelegate.blinkValue != blinkValue ||
        oldDelegate.breathOffset != breathOffset ||
        oldDelegate.showFullBody != showFullBody;
  }
}
