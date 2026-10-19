import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/bitmoji_traits.dart';

/// High-performance native CustomPainter rendering a layered 3D Snapchat Bitmoji character.
/// Features true 3D spherical rotation, dynamic specular lighting, customizable stage pedestals,
/// transparent background mode, and 100% real-time responsive traits.
class BitmojiCustomPainter extends CustomPainter {
  final BitmojiTraits traits;
  final double blinkValue; // 0.0 (open) to 1.0 (closed)
  final double breathOffset; // subtle breathing animation
  final bool showFullBody;
  final double rotationY; // Horizontal 3D yaw in radians (-pi to pi)
  final double pitchX; // Vertical 3D pitch in radians (-0.35 to 0.35)
  final bool? isTransparent;

  BitmojiCustomPainter({
    required this.traits,
    this.blinkValue = 0.0,
    this.breathOffset = 0.0,
    this.showFullBody = true,
    this.rotationY = 0.0,
    this.pitchX = 0.0,
    this.isTransparent,
  });

  bool get _useTransparent => isTransparent ?? traits.isTransparent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.44 + breathOffset;

    // ── Layer 0: Background Studio & 3D Pedestal Stage ──
    _paintBackground(canvas, size, cx, h);

    // Save canvas state for 3D perspective transforms
    canvas.save();

    // 3D Projected offsets from yaw and pitch
    final double sinYaw = math.sin(rotationY);
    final double cosYaw = math.cos(rotationY);
    final double pitchOffset = math.sin(pitchX) * h * 0.06;

    // Body yaw dampening (neck turns more than torso)
    final double bodyYawOffset = sinYaw * w * 0.08;
    final double headYawOffset = sinYaw * w * 0.14;

    // ── Layer 1: Body, Neck & Outfits ──
    _paintBodyAndOutfit(canvas, size, cx, cy, bodyYawOffset, pitchOffset, cosYaw);

    // ── Layer 2: Head & Face Shape ──
    _paintHeadAndFace(canvas, size, cx, cy, headYawOffset, pitchOffset, cosYaw);

    // ── Layer 3: Ears & Cheeks ──
    _paintEarsAndCheeks(canvas, cx, cy, headYawOffset, pitchOffset, cosYaw);

    // ── Layer 4: Facial Features (Eyes, Eyebrows, Nose, Mouth) ──
    _paintFacialFeatures(canvas, cx, cy, headYawOffset, pitchOffset, cosYaw);

    // ── Layer 5: Facial Hair (Beard & Mustache) ──
    if (traits.facialHair != 'none') {
      _paintFacialHair(canvas, cx, cy, headYawOffset, pitchOffset, cosYaw);
    }

    // ── Layer 6: Hair Front & Headwear (Hijab, Caps, Hairstyles) ──
    _paintHairAndHeadwear(canvas, cx, cy, headYawOffset, pitchOffset, cosYaw);

    // ── Layer 7: Eyewear (Glasses, Sunglasses, Cyber Visor) ──
    if (traits.eyewear != 'none') {
      _paintEyewear(canvas, cx, cy, headYawOffset, pitchOffset, cosYaw);
    }

    // ── Layer 8: Honor Badge (if selected) ──
    if (traits.honorBadge != null && traits.honorBadge!.isNotEmpty) {
      _paintHonorBadge(canvas, cx, cy, bodyYawOffset, pitchOffset);
    }

    canvas.restore();
  }

  // ===========================================================================
  // Layer 0: Background & 3D Pedestal Stage
  // ===========================================================================
  void _paintBackground(Canvas canvas, Size size, double cx, double h) {
    final rect = Offset.zero & size;

    if (!_useTransparent) {
      // 1. Studio Lighting Background (Rich radial vignette)
      final bgPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 0.95,
          colors: [
            traits.backgroundColor.withValues(alpha: 0.95),
            traits.backgroundColor.withValues(alpha: 0.40),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, bgPaint);

      // Studio Spotlight Cone
      final conePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCenter(center: Offset(cx, h * 0.45), width: size.width * 0.9, height: h * 0.9));
      canvas.drawRect(rect, conePaint);
    }

    if (showFullBody && traits.pedestalStyle != 'none') {
      // 2. 3D Pedestal Platform with Stage Lighting
      final platformCenter = Offset(cx, h * 0.935);
      final platformWidth = size.width * 0.78;
      final platformHeight = size.height * 0.13;

      // Soft Floor Contact Shadow
      final shadowRect = Rect.fromCenter(
        center: platformCenter.translate(0, 10),
        width: platformWidth * 1.06,
        height: platformHeight * 0.92,
      );
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawOval(shadowRect, shadowPaint);

      // Pedestal Base (Lower Bevel Ring)
      final baseRect = Rect.fromCenter(
        center: platformCenter.translate(0, 5),
        width: platformWidth,
        height: platformHeight,
      );

      final style = traits.pedestalStyle;
      final (Color ringPrimary, Color ringGlow) = switch (style) {
        'royal_gold' => (const Color(0xFFF59E0B), const Color(0xFFFEF08A)),
        'emerald_crystal' => (const Color(0xFF10B981), const Color(0xFFA7F3D0)),
        'obsidian_holo' => (const Color(0xFF6366F1), const Color(0xFFC7D2FE)),
        'floating_halo' => (const Color(0xFF38BDF8), const Color(0xFFE0F2FE)),
        _ => (traits.outfitColor, traits.outfitAccentColor), // neon_disc default
      };

      final basePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ringPrimary.withValues(alpha: 0.75),
            Colors.black.withValues(alpha: 0.55),
          ],
        ).createShader(baseRect);
      canvas.drawOval(baseRect, basePaint);

      // Pedestal Top Surface (Glowing Disc)
      final topRect = Rect.fromCenter(
        center: platformCenter,
        width: platformWidth * 0.94,
        height: platformHeight * 0.86,
      );
      final topPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            ringGlow.withValues(alpha: 0.45),
          ],
        ).createShader(topRect);
      canvas.drawOval(topRect, topPaint);

      // Dynamic 3D Neon Ring
      final rimPaint = Paint()
        ..color = ringPrimary.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;
      canvas.drawOval(topRect, rimPaint);

      // Inner Concentric Target Ring
      final innerRect = Rect.fromCenter(
        center: platformCenter,
        width: platformWidth * 0.60,
        height: platformHeight * 0.55,
      );
      canvas.drawOval(
        innerRect,
        Paint()
          ..color = ringPrimary.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  // ===========================================================================
  // Layer 1: Body, Neck & Outfits
  // ===========================================================================
  void _paintBodyAndOutfit(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double bodyYawOffset,
    double pitchOffset,
    double cosYaw,
  ) {
    final neckW = size.width * 0.15;
    final neckH = size.height * 0.165;
    final neckTop = cy + size.height * 0.11 + pitchOffset;

    // ── Neck ──
    final neckCenter = Offset(cx + bodyYawOffset * 0.5, neckTop + neckH / 2);
    final neckRect = Rect.fromCenter(
      center: neckCenter,
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
      ..moveTo(neckCenter.dx - neckW / 2, neckTop)
      ..quadraticBezierTo(neckCenter.dx, neckTop + 18, neckCenter.dx + neckW / 2, neckTop)
      ..close();
    canvas.drawPath(shadowPath, Paint()..color = Colors.black.withValues(alpha: 0.18));

    // ── Shoulders & Torso ──
    final torsoTop = neckTop + neckH * 0.42;
    final torsoW = size.width * 0.66;
    final torsoCenterX = cx + bodyYawOffset;

    final outfitPath = Path();
    outfitPath.moveTo(torsoCenterX - neckW * 0.9, torsoTop);
    outfitPath.quadraticBezierTo(
      torsoCenterX - torsoW * 0.52,
      torsoTop + 24,
      torsoCenterX - torsoW * 0.56,
      size.height,
    );
    outfitPath.lineTo(torsoCenterX + torsoW * 0.56, size.height);
    outfitPath.quadraticBezierTo(
      torsoCenterX + torsoW * 0.52,
      torsoTop + 24,
      torsoCenterX + neckW * 0.9,
      torsoTop,
    );
    outfitPath.close();

    // Primary Outfit Base
    final outfitPaint = Paint()..color = traits.outfitColor;
    canvas.drawPath(outfitPath, outfitPaint);

    // Dynamic 3D Torso Lighting Shading
    final torsoShader = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-0.6 + bodyYawOffset / 100, -1.0),
        end: const Alignment(0.6, 1.0),
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.22),
        ],
      ).createShader(Rect.fromLTWH(torsoCenterX - torsoW / 2, torsoTop, torsoW, size.height - torsoTop));
    canvas.drawPath(outfitPath, torsoShader);

    // Accent line stroke
    final accentPaint = Paint()
      ..color = traits.outfitAccentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final outfit = traits.outfit;

    if (outfit == 'hoodie') {
      // 🧥 Streetwear Tech Hoodie
      final hoodCollar = Path()
        ..moveTo(torsoCenterX - neckW * 0.95, torsoTop)
        ..quadraticBezierTo(torsoCenterX, torsoTop + 36, torsoCenterX + neckW * 0.95, torsoTop);
      canvas.drawPath(hoodCollar, accentPaint);

      // Inner hood cavity shadow
      final innerShadow = Path()
        ..moveTo(torsoCenterX - neckW * 0.9, torsoTop)
        ..quadraticBezierTo(torsoCenterX, torsoTop + 28, torsoCenterX + neckW * 0.9, torsoTop)
        ..lineTo(torsoCenterX, torsoTop + 14)
        ..close();
      canvas.drawPath(innerShadow, Paint()..color = Colors.black.withValues(alpha: 0.22));

      // Drawstrings with metallic aglets
      final stringPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(torsoCenterX - 14, torsoTop + 26),
        Offset(torsoCenterX - 14, torsoTop + 74),
        stringPaint,
      );
      canvas.drawLine(
        Offset(torsoCenterX + 14, torsoTop + 26),
        Offset(torsoCenterX + 14, torsoTop + 74),
        stringPaint,
      );

      final agletPaint = Paint()..color = traits.outfitAccentColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(torsoCenterX - 16, torsoTop + 70, 4, 8), const Radius.circular(2)),
        agletPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(torsoCenterX + 12, torsoTop + 70, 4, 8), const Radius.circular(2)),
        agletPaint,
      );

      // Kangaroo Pocket Arc
      final pocketPath = Path()
        ..moveTo(torsoCenterX - 45, torsoTop + 95)
        ..lineTo(torsoCenterX - 35, torsoTop + 75)
        ..lineTo(torsoCenterX + 35, torsoTop + 75)
        ..lineTo(torsoCenterX + 45, torsoTop + 95);
      canvas.drawPath(
        pocketPath,
        Paint()
          ..color = traits.outfitAccentColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if (outfit == 'formal_blazer' || outfit == 'suit') {
      // 👔 Executive Blazer / Suit & Tie
      final shirtPath = Path()
        ..moveTo(torsoCenterX - neckW * 0.65, torsoTop)
        ..lineTo(torsoCenterX, torsoTop + 70)
        ..lineTo(torsoCenterX + neckW * 0.65, torsoTop)
        ..close();
      canvas.drawPath(shirtPath, Paint()..color = Colors.white);

      // Tie
      final tiePath = Path()
        ..moveTo(torsoCenterX - 7, torsoTop + 14)
        ..lineTo(torsoCenterX + 7, torsoTop + 14)
        ..lineTo(torsoCenterX + 11, torsoTop + 76)
        ..lineTo(torsoCenterX, torsoTop + 90)
        ..lineTo(torsoCenterX - 11, torsoTop + 76)
        ..close();
      canvas.drawPath(tiePath, Paint()..color = traits.outfitAccentColor);

      // Tie knot
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(torsoCenterX, torsoTop + 14), width: 15, height: 11),
          const Radius.circular(3),
        ),
        Paint()..color = traits.outfitAccentColor,
      );

      // Blazer Lapels
      canvas.drawLine(Offset(torsoCenterX - neckW * 0.9, torsoTop), Offset(torsoCenterX - 10, torsoTop + 86), accentPaint);
      canvas.drawLine(Offset(torsoCenterX + neckW * 0.9, torsoTop), Offset(torsoCenterX + 10, torsoTop + 86), accentPaint);

      // Blazer Button
      canvas.drawCircle(Offset(torsoCenterX, torsoTop + 94), 3, Paint()..color = Colors.white70);
    } else if (outfit == 'lab_coat') {
      // 🥼 Doctor / Scientist Lab Coat
      final coatInner = Path()
        ..moveTo(torsoCenterX - neckW * 0.6, torsoTop)
        ..lineTo(torsoCenterX, torsoTop + 65)
        ..lineTo(torsoCenterX + neckW * 0.6, torsoTop)
        ..close();
      canvas.drawPath(coatInner, Paint()..color = const Color(0xFF0284C7)); // Blue scrub under

      // Lapels
      canvas.drawLine(Offset(torsoCenterX - neckW * 0.85, torsoTop), Offset(torsoCenterX - 8, torsoTop + 82), Paint()..color = Colors.grey.shade400..strokeWidth = 2.5);
      canvas.drawLine(Offset(torsoCenterX + neckW * 0.85, torsoTop), Offset(torsoCenterX + 8, torsoTop + 82), Paint()..color = Colors.grey.shade400..strokeWidth = 2.5);

      // Stethoscope loop around neck
      final stethPaint = Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(torsoCenterX, torsoTop + 38), width: 44, height: 48),
        0.1,
        math.pi * 0.95,
        false,
        stethPaint,
      );
      // Chest piece bell
      canvas.drawCircle(Offset(torsoCenterX + 18, torsoTop + 65), 5.5, Paint()..color = const Color(0xFF94A3B8));
      canvas.drawCircle(Offset(torsoCenterX + 18, torsoTop + 65), 3, Paint()..color = const Color(0xFF475569));
    } else if (outfit == 'athletic') {
      // 🏃 Athletic Track Jacket with Dual Racing Stripes
      final stripe1 = Path()
        ..moveTo(torsoCenterX - neckW * 0.85, torsoTop)
        ..lineTo(torsoCenterX - torsoW * 0.48, torsoTop + 38);
      final stripe2 = Path()
        ..moveTo(torsoCenterX - neckW * 0.70, torsoTop)
        ..lineTo(torsoCenterX - torsoW * 0.43, torsoTop + 40);
      canvas.drawPath(stripe1, accentPaint..strokeWidth = 3.5);
      canvas.drawPath(stripe2, Paint()..color = Colors.white..strokeWidth = 3..style = PaintingStyle.stroke);

      final rStripe1 = Path()
        ..moveTo(torsoCenterX + neckW * 0.85, torsoTop)
        ..lineTo(torsoCenterX + torsoW * 0.48, torsoTop + 38);
      final rStripe2 = Path()
        ..moveTo(torsoCenterX + neckW * 0.70, torsoTop)
        ..lineTo(torsoCenterX + torsoW * 0.43, torsoTop + 40);
      canvas.drawPath(rStripe1, accentPaint);
      canvas.drawPath(rStripe2, Paint()..color = Colors.white..strokeWidth = 3..style = PaintingStyle.stroke);

      // Central Zip
      canvas.drawLine(
        Offset(torsoCenterX, torsoTop + 8),
        Offset(torsoCenterX, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.85)..strokeWidth = 2,
      );
      canvas.drawRect(Rect.fromCenter(center: Offset(torsoCenterX, torsoTop + 24), width: 5, height: 8), Paint()..color = Colors.white);
    } else if (outfit == 'graduation_gown') {
      // 🎓 Academic Graduation Gown with Sash
      final sashPath = Path()
        ..moveTo(torsoCenterX - neckW * 0.75, torsoTop)
        ..lineTo(torsoCenterX - 12, torsoTop + 85)
        ..lineTo(torsoCenterX + 12, torsoTop + 85)
        ..lineTo(torsoCenterX + neckW * 0.75, torsoTop)
        ..close();
      canvas.drawPath(sashPath, Paint()..color = traits.outfitAccentColor);

      // Sash gold trim
      canvas.drawPath(
        sashPath,
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      // 👕 Casual Modern Polo / Crew
      final collarPath = Path()
        ..moveTo(torsoCenterX - neckW * 0.82, torsoTop)
        ..quadraticBezierTo(torsoCenterX, torsoTop + 24, torsoCenterX + neckW * 0.82, torsoTop);
      canvas.drawPath(collarPath, accentPaint);

      // Placket & Buttons
      final placketRect = Rect.fromLTWH(torsoCenterX - 6, torsoTop + 18, 12, 38);
      canvas.drawRRect(
        RRect.fromRectAndRadius(placketRect, const Radius.circular(3)),
        Paint()..color = traits.outfitAccentColor.withValues(alpha: 0.35),
      );
      canvas.drawCircle(Offset(torsoCenterX, torsoTop + 26), 2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(torsoCenterX, torsoTop + 42), 2, Paint()..color = Colors.white);
    }
  }

  // ===========================================================================
  // Layer 2: Head & Face Shape (3D Spherical Contouring)
  // ===========================================================================
  void _paintHeadAndFace(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double headYawOffset,
    double pitchOffset,
    double cosYaw,
  ) {
    final headW = size.width * 0.385 * (0.88 + 0.12 * cosYaw.abs());
    final headH = size.height * 0.365;
    final headCenter = Offset(cx + headYawOffset, cy + pitchOffset);

    final headPath = Path();

    switch (traits.faceShape) {
      case 'square':
        headPath.moveTo(headCenter.dx - headW / 2, headCenter.dy - headH * 0.35);
        headPath.quadraticBezierTo(
          headCenter.dx - headW / 2,
          headCenter.dy + headH * 0.40,
          headCenter.dx - headW * 0.30,
          headCenter.dy + headH * 0.52,
        );
        headPath.quadraticBezierTo(
          headCenter.dx,
          headCenter.dy + headH * 0.55,
          headCenter.dx + headW * 0.30,
          headCenter.dy + headH * 0.52,
        );
        headPath.quadraticBezierTo(
          headCenter.dx + headW / 2,
          headCenter.dy + headH * 0.40,
          headCenter.dx + headW / 2,
          headCenter.dy - headH * 0.35,
        );
        headPath.quadraticBezierTo(
          headCenter.dx,
          headCenter.dy - headH * 0.54,
          headCenter.dx - headW / 2,
          headCenter.dy - headH * 0.35,
        );
        break;

      case 'round':
        headPath.addOval(
          Rect.fromCenter(
            center: headCenter,
            width: headW * 1.05,
            height: headH,
          ),
        );
        break;

      case 'heart':
        headPath.moveTo(headCenter.dx - headW / 2, headCenter.dy - headH * 0.35);
        headPath.quadraticBezierTo(
          headCenter.dx - headW * 0.45,
          headCenter.dy + headH * 0.25,
          headCenter.dx,
          headCenter.dy + headH * 0.53,
        );
        headPath.quadraticBezierTo(
          headCenter.dx + headW * 0.45,
          headCenter.dy + headH * 0.25,
          headCenter.dx + headW / 2,
          headCenter.dy - headH * 0.35,
        );
        headPath.quadraticBezierTo(
          headCenter.dx,
          headCenter.dy - headH * 0.52,
          headCenter.dx - headW / 2,
          headCenter.dy - headH * 0.35,
        );
        break;

      case 'diamond':
        headPath.moveTo(headCenter.dx, headCenter.dy - headH * 0.53);
        headPath.lineTo(headCenter.dx + headW * 0.50, headCenter.dy - headH * 0.05);
        headPath.lineTo(headCenter.dx, headCenter.dy + headH * 0.53);
        headPath.lineTo(headCenter.dx - headW * 0.50, headCenter.dy - headH * 0.05);
        headPath.close();
        break;

      case 'oval':
      default:
        headPath.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: headCenter, width: headW, height: headH),
            Radius.circular(headW * 0.46),
          ),
        );
        break;
    }

    // Face Base Skin Tone
    final facePaint = Paint()..color = traits.skinColor;
    canvas.drawPath(headPath, facePaint);

    // 3D Spherical Ambient Lighting (Specular light on forehead, shadow under jaw)
    final lightCenterX = headCenter.dx - headW * 0.25 - headYawOffset * 0.3;
    final lightCenterY = headCenter.dy - headH * 0.20;

    final edgeShader = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (lightCenterX - headCenter.dx) / (headW / 2),
          (lightCenterY - headCenter.dy) / (headH / 2),
        ),
        radius: 0.90,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.16),
        ],
      ).createShader(Rect.fromCenter(center: headCenter, width: headW, height: headH));
    canvas.drawPath(headPath, edgeShader);
  }

  // ===========================================================================
  // Layer 3: Ears & Cheeks
  // ===========================================================================
  void _paintEarsAndCheeks(
    Canvas canvas,
    double cx,
    double cy,
    double headYawOffset,
    double pitchOffset,
    double cosYaw,
  ) {
    final headCenter = Offset(cx + headYawOffset, cy + pitchOffset);
    const earW = 14.0;
    const earH = 26.0;
    const baseOffset = 68.0;

    final earPaint = Paint()..color = traits.skinColor;
    final innerEarPaint = Paint()..color = Colors.black.withValues(alpha: 0.10);

    // Perspective ear displacement
    final leftEarX = headCenter.dx - baseOffset * (0.85 + 0.15 * cosYaw);
    final rightEarX = headCenter.dx + baseOffset * (0.85 + 0.15 * cosYaw);

    // Left Ear
    canvas.drawOval(
      Rect.fromCenter(center: Offset(leftEarX, headCenter.dy), width: earW, height: earH),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(leftEarX + 2, headCenter.dy), width: earW * 0.5, height: earH * 0.5),
      innerEarPaint,
    );

    // Right Ear
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rightEarX, headCenter.dy), width: earW, height: earH),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rightEarX - 2, headCenter.dy), width: earW * 0.5, height: earH * 0.5),
      innerEarPaint,
    );

    // Cute Cheeks Blush (Snapchat signature glow)
    final blushPaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(headCenter.dx - 36 * cosYaw, headCenter.dy + 18), width: 24, height: 13),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(headCenter.dx + 36 * cosYaw, headCenter.dy + 18), width: 24, height: 13),
      blushPaint,
    );
  }

  // ===========================================================================
  // Layer 4: Facial Features (Eyes, Eyebrows, Nose, Mouth)
  // ===========================================================================
  void _paintFacialFeatures(
    Canvas canvas,
    double cx,
    double cy,
    double headYawOffset,
    double pitchOffset,
    double cosYaw,
  ) {
    final headCenter = Offset(cx + headYawOffset, cy + pitchOffset);
    final eyeSpacing = 32.0 * (0.85 + 0.15 * cosYaw.abs());
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
        ..moveTo(headCenter.dx - eyeSpacing - 12, headCenter.dy + eyeY)
        ..quadraticBezierTo(headCenter.dx - eyeSpacing, headCenter.dy + eyeY - 6, headCenter.dx - eyeSpacing + 12, headCenter.dy + eyeY);
      canvas.drawPath(leftBlink, blinkPaint);

      final rightBlink = Path()
        ..moveTo(headCenter.dx + eyeSpacing - 12, headCenter.dy + eyeY)
        ..quadraticBezierTo(headCenter.dx + eyeSpacing, headCenter.dy + eyeY - 6, headCenter.dx + eyeSpacing + 12, headCenter.dy + eyeY);
      canvas.drawPath(rightBlink, blinkPaint);
    } else if (traits.eyes == 'winking') {
      _drawEye(canvas, Offset(headCenter.dx - eyeSpacing, headCenter.dy + eyeY), isRight: false);
      final winkPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final rightWink = Path()
        ..moveTo(headCenter.dx + eyeSpacing - 12, headCenter.dy + eyeY)
        ..quadraticBezierTo(headCenter.dx + eyeSpacing, headCenter.dy + eyeY - 6, headCenter.dx + eyeSpacing + 12, headCenter.dy + eyeY);
      canvas.drawPath(rightWink, winkPaint);
    } else {
      // Both open eyes
      _drawEye(canvas, Offset(headCenter.dx - eyeSpacing, headCenter.dy + eyeY), isRight: false);
      _drawEye(canvas, Offset(headCenter.dx + eyeSpacing, headCenter.dy + eyeY), isRight: true);
    }

    // ── Eyebrows ──
    final browPaint = Paint()
      ..color = traits.hairColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;

    const browY = -22.0;
    final leftBrow = Path()
      ..moveTo(headCenter.dx - eyeSpacing - 14, headCenter.dy + browY + 2)
      ..quadraticBezierTo(headCenter.dx - eyeSpacing, headCenter.dy + browY - 4, headCenter.dx - eyeSpacing + 14, headCenter.dy + browY);
    canvas.drawPath(leftBrow, browPaint);

    final rightBrow = Path()
      ..moveTo(headCenter.dx + eyeSpacing - 14, headCenter.dy + browY)
      ..quadraticBezierTo(headCenter.dx + eyeSpacing, headCenter.dy + browY - 4, headCenter.dx + eyeSpacing + 14, headCenter.dy + browY + 2);
    canvas.drawPath(rightBrow, browPaint);

    // ── Nose ──
    final nosePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final nosePath = Path()
      ..moveTo(headCenter.dx, headCenter.dy + 8)
      ..lineTo(headCenter.dx + 3 * cosYaw, headCenter.dy + 20)
      ..quadraticBezierTo(headCenter.dx, headCenter.dy + 24, headCenter.dx - 4 * cosYaw, headCenter.dy + 22);
    canvas.drawPath(nosePath, nosePaint);

    // ── Mouth ──
    const mouthY = 40.0;
    if (traits.mouth == 'wide_grin') {
      final mouthPath = Path()
        ..moveTo(headCenter.dx - 18, headCenter.dy + mouthY)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy + mouthY + 18, headCenter.dx + 18, headCenter.dy + mouthY)
        ..close();
      canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF881337));

      canvas.save();
      canvas.clipPath(mouthPath);
      // Teeth
      canvas.drawRect(
        Rect.fromLTWH(headCenter.dx - 16, headCenter.dy + mouthY - 2, 32, 8),
        Paint()..color = Colors.white,
      );
      // Tongue
      canvas.drawOval(
        Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + mouthY + 14), width: 20, height: 12),
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
        ..moveTo(headCenter.dx - 14, headCenter.dy + mouthY + 2)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy + mouthY + 8, headCenter.dx + 16, headCenter.dy + mouthY - 3);
      canvas.drawPath(smirk, mouthPaint);
    } else if (traits.mouth == 'neutral') {
      final mouthPaint = Paint()
        ..color = const Color(0xFF881337)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(headCenter.dx - 12, headCenter.dy + mouthY + 4),
        Offset(headCenter.dx + 12, headCenter.dy + mouthY + 4),
        mouthPaint,
      );
    } else {
      // Warm Smile (default)
      final mouthPaint = Paint()
        ..color = const Color(0xFF881337)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final smile = Path()
        ..moveTo(headCenter.dx - 16, headCenter.dy + mouthY)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy + mouthY + 10, headCenter.dx + 16, headCenter.dy + mouthY);
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

  // ===========================================================================
  // Layer 5: Facial Hair (Beard & Mustache)
  // ===========================================================================
  void _paintFacialHair(
    Canvas canvas,
    double cx,
    double cy,
    double headYawOffset,
    double pitchOffset,
    double cosYaw,
  ) {
    final headCenter = Offset(cx + headYawOffset, cy + pitchOffset);
    final beardPaint = Paint()
      ..color = traits.facialHairColor
      ..strokeCap = StrokeCap.round;

    if (traits.facialHair == 'stubble') {
      final stubbleShader = Paint()
        ..color = traits.facialHairColor.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + 46), width: 56, height: 26),
        stubbleShader,
      );
    } else if (traits.facialHair == 'full_beard' || traits.facialHair == 'trimmed_beard') {
      final beardPath = Path()
        ..moveTo(headCenter.dx - 48, headCenter.dy + 12)
        ..quadraticBezierTo(headCenter.dx - 52, headCenter.dy + 62, headCenter.dx, headCenter.dy + 74)
        ..quadraticBezierTo(headCenter.dx + 52, headCenter.dy + 62, headCenter.dx + 48, headCenter.dy + 12)
        ..quadraticBezierTo(headCenter.dx + 36, headCenter.dy + 54, headCenter.dx, headCenter.dy + 56)
        ..quadraticBezierTo(headCenter.dx - 36, headCenter.dy + 54, headCenter.dx - 48, headCenter.dy + 12)
        ..close();
      canvas.drawPath(beardPath, beardPaint);
    } else if (traits.facialHair == 'mustache') {
      final mustachePath = Path()
        ..moveTo(headCenter.dx - 24, headCenter.dy + 34)
        ..quadraticBezierTo(headCenter.dx - 10, headCenter.dy + 28, headCenter.dx, headCenter.dy + 32)
        ..quadraticBezierTo(headCenter.dx + 10, headCenter.dy + 28, headCenter.dx + 24, headCenter.dy + 34)
        ..quadraticBezierTo(headCenter.dx + 10, headCenter.dy + 38, headCenter.dx, headCenter.dy + 35)
        ..quadraticBezierTo(headCenter.dx - 10, headCenter.dy + 38, headCenter.dx - 24, headCenter.dy + 34)
        ..close();
      canvas.drawPath(mustachePath, beardPaint);
    }
  }

  // ===========================================================================
  // Layer 6: Hair Front & Headwear (Hijab, Caps, Hairstyles)
  // ===========================================================================
  void _paintHairAndHeadwear(
    Canvas canvas,
    double cx,
    double cy,
    double headYawOffset,
    double pitchOffset,
    double cosYaw,
  ) {
    final headCenter = Offset(cx + headYawOffset, cy + pitchOffset);
    final hairPaint = Paint()..color = traits.hairColor;

    if (traits.hairStyle == 'hijab' ||
        traits.hairStyle == 'hijab_wrapped' ||
        traits.headwear == 'hijab') {
      // 🧕 Elegant Islamic Hijab Wrap (Snapchat/Bitmoji standard)
      final hijabColor = traits.headwearColor;
      final hijabPath = Path()
        ..moveTo(headCenter.dx - 68, headCenter.dy - 20)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 92, headCenter.dx + 68, headCenter.dy - 20)
        ..quadraticBezierTo(headCenter.dx + 74, headCenter.dy + 62, headCenter.dx + 38, headCenter.dy + 102)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy + 118, headCenter.dx - 38, headCenter.dy + 102)
        ..quadraticBezierTo(headCenter.dx - 74, headCenter.dy + 62, headCenter.dx - 68, headCenter.dy - 20)
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
            Colors.black.withValues(alpha: 0.20),
          ],
        ).createShader(Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + 10), width: 148, height: 210));
      canvas.drawPath(hijabPath, hijabGradient);

      // Inner Fold Line & Face Opening
      final innerFold = Path()
        ..moveTo(headCenter.dx - 54, headCenter.dy - 10)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 72, headCenter.dx + 54, headCenter.dy - 10)
        ..quadraticBezierTo(headCenter.dx + 46, headCenter.dy + 46, headCenter.dx, headCenter.dy + 66)
        ..quadraticBezierTo(headCenter.dx - 46, headCenter.dy + 46, headCenter.dx - 54, headCenter.dy - 10);
      canvas.drawPath(
        innerFold,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      // Decorative Metallic Hijab Pin / Brooch
      final pinPaint = Paint()..color = const Color(0xFFF59E0B);
      canvas.drawCircle(Offset(headCenter.dx, headCenter.dy + 68), 3.5, pinPaint);
      canvas.drawCircle(Offset(headCenter.dx, headCenter.dy + 68), 1.5, Paint()..color = Colors.white);
      return;
    }

    // ── Hairstyle Options ──
    if (traits.hairStyle == 'long_wavy') {
      final hairPath = Path()
        ..moveTo(headCenter.dx - 64, headCenter.dy + 55)
        ..quadraticBezierTo(headCenter.dx - 72, headCenter.dy - 74, headCenter.dx, headCenter.dy - 82)
        ..quadraticBezierTo(headCenter.dx + 72, headCenter.dy - 74, headCenter.dx + 64, headCenter.dy + 55)
        ..quadraticBezierTo(headCenter.dx + 50, headCenter.dy - 30, headCenter.dx, headCenter.dy - 56)
        ..quadraticBezierTo(headCenter.dx - 50, headCenter.dy - 30, headCenter.dx - 64, headCenter.dy + 55)
        ..close();
      canvas.drawPath(hairPath, hairPaint);
    } else if (traits.hairStyle == 'buzz_cut') {
      final buzzPath = Path()
        ..moveTo(headCenter.dx - 58, headCenter.dy - 10)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 74, headCenter.dx + 58, headCenter.dy - 10)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 50, headCenter.dx - 58, headCenter.dy - 10);
      canvas.drawPath(buzzPath, hairPaint);
    } else if (traits.hairStyle == 'fade_crop') {
      // 💈 Modern Fade Crop
      final fadePath = Path()
        ..moveTo(headCenter.dx - 60, headCenter.dy - 16)
        ..quadraticBezierTo(headCenter.dx - 62, headCenter.dy - 76, headCenter.dx, headCenter.dy - 86)
        ..quadraticBezierTo(headCenter.dx + 62, headCenter.dy - 76, headCenter.dx + 60, headCenter.dy - 16)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 64, headCenter.dx - 60, headCenter.dy - 16)
        ..close();
      canvas.drawPath(fadePath, hairPaint);
    } else if (traits.hairStyle == 'slick_back') {
      final slickPath = Path()
        ..moveTo(headCenter.dx - 62, headCenter.dy - 12)
        ..quadraticBezierTo(headCenter.dx - 58, headCenter.dy - 82, headCenter.dx, headCenter.dy - 92)
        ..quadraticBezierTo(headCenter.dx + 58, headCenter.dy - 82, headCenter.dx + 62, headCenter.dy - 12)
        ..quadraticBezierTo(headCenter.dx + 40, headCenter.dy - 48, headCenter.dx, headCenter.dy - 58)
        ..quadraticBezierTo(headCenter.dx - 40, headCenter.dy - 48, headCenter.dx - 62, headCenter.dy - 12)
        ..close();
      canvas.drawPath(slickPath, hairPaint);
    } else if (traits.hairStyle == 'bob') {
      // 💇‍♀️ Classic Bob with Fringe
      final bobPath = Path()
        ..moveTo(headCenter.dx - 66, headCenter.dy + 25)
        ..quadraticBezierTo(headCenter.dx - 70, headCenter.dy - 70, headCenter.dx, headCenter.dy - 80)
        ..quadraticBezierTo(headCenter.dx + 70, headCenter.dy - 70, headCenter.dx + 66, headCenter.dy + 25)
        ..lineTo(headCenter.dx + 48, headCenter.dy + 20)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 48, headCenter.dx - 48, headCenter.dy + 20)
        ..close();
      canvas.drawPath(bobPath, hairPaint);
    } else {
      // Default: 👦 Modern Textured Curly Crop (Bitmoji Hero)
      final hairPath = Path()
        ..moveTo(headCenter.dx - 64, headCenter.dy - 10)
        ..quadraticBezierTo(headCenter.dx - 70, headCenter.dy - 65, headCenter.dx - 30, headCenter.dy - 80)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 88, headCenter.dx + 30, headCenter.dy - 80)
        ..quadraticBezierTo(headCenter.dx + 70, headCenter.dy - 65, headCenter.dx + 64, headCenter.dy - 10)
        ..quadraticBezierTo(headCenter.dx + 50, headCenter.dy - 40, headCenter.dx + 18, headCenter.dy - 56)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 60, headCenter.dx - 20, headCenter.dy - 56)
        ..quadraticBezierTo(headCenter.dx - 50, headCenter.dy - 40, headCenter.dx - 64, headCenter.dy - 10)
        ..close();
      canvas.drawPath(hairPath, hairPaint);

      // Specular curl highlights
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(headCenter.dx - 16, headCenter.dy - 66), radius: 10),
        -math.pi / 2,
        math.pi,
        false,
        highlightPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(headCenter.dx + 14, headCenter.dy - 68), radius: 12),
        -math.pi / 2,
        math.pi,
        false,
        highlightPaint,
      );
    }

    // ── Headwear Overlays (Caps, Hats, Headphones) ──
    final headwear = traits.headwear;
    final headwearPaint = Paint()..color = traits.headwearColor;

    if (headwear == 'graduation_cap') {
      // 🎓 Academic Graduation Cap with Gold Tassel
      final capPath = Path()
        ..moveTo(headCenter.dx, headCenter.dy - 105)
        ..lineTo(headCenter.dx + 68, headCenter.dy - 78)
        ..lineTo(headCenter.dx, headCenter.dy - 55)
        ..lineTo(headCenter.dx - 68, headCenter.dy - 78)
        ..close();
      canvas.drawPath(capPath, headwearPaint);
      canvas.drawPath(capPath, Paint()..color = Colors.black.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 2);

      // Skullcap base
      final skullPath = Path()
        ..moveTo(headCenter.dx - 48, headCenter.dy - 68)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 52, headCenter.dx + 48, headCenter.dy - 68)
        ..lineTo(headCenter.dx + 44, headCenter.dy - 50)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 38, headCenter.dx - 44, headCenter.dy - 50)
        ..close();
      canvas.drawPath(skullPath, headwearPaint);

      // Gold Button and Dangling Tassel
      canvas.drawCircle(Offset(headCenter.dx, headCenter.dy - 78), 4, Paint()..color = const Color(0xFFF59E0B));
      final tasselPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(headCenter.dx, headCenter.dy - 78), Offset(headCenter.dx + 45, headCenter.dy - 40), tasselPaint);
      canvas.drawRect(Rect.fromLTWH(headCenter.dx + 42, headCenter.dy - 40, 6, 12), Paint()..color = const Color(0xFFF59E0B));
    } else if (headwear == 'baseball_cap' || headwear == 'hat') {
      // 🧢 Snapback Baseball Cap
      final crownPath = Path()
        ..moveTo(headCenter.dx - 58, headCenter.dy - 40)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 98, headCenter.dx + 58, headCenter.dy - 40)
        ..close();
      canvas.drawPath(crownPath, headwearPaint);

      // Visor / Bill
      final billPath = Path()
        ..moveTo(headCenter.dx - 60, headCenter.dy - 40)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 24, headCenter.dx + 60, headCenter.dy - 40)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 30, headCenter.dx - 60, headCenter.dy - 40);
      canvas.drawPath(billPath, Paint()..color = traits.outfitAccentColor);

      // Top Button
      canvas.drawCircle(Offset(headCenter.dx, headCenter.dy - 96), 3.5, Paint()..color = traits.outfitAccentColor);
    } else if (headwear == 'headphones') {
      // 🎧 Studio / Gaming RGB Headphones
      final bandPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy - 24), width: 140, height: 130),
        math.pi * 0.95,
        math.pi * 1.1,
        false,
        bandPaint,
      );

      // Left Earcup with glowing accent ring
      final leftEarcup = Rect.fromCenter(center: Offset(headCenter.dx - 66, headCenter.dy - 5), width: 18, height: 38);
      canvas.drawRRect(RRect.fromRectAndRadius(leftEarcup, const Radius.circular(8)), Paint()..color = const Color(0xFF0F172A));
      canvas.drawRRect(RRect.fromRectAndRadius(leftEarcup, const Radius.circular(8)), Paint()..color = traits.headwearColor..style = PaintingStyle.stroke..strokeWidth = 2.5);

      // Right Earcup with glowing accent ring
      final rightEarcup = Rect.fromCenter(center: Offset(headCenter.dx + 66, headCenter.dy - 5), width: 18, height: 38);
      canvas.drawRRect(RRect.fromRectAndRadius(rightEarcup, const Radius.circular(8)), Paint()..color = const Color(0xFF0F172A));
      canvas.drawRRect(RRect.fromRectAndRadius(rightEarcup, const Radius.circular(8)), Paint()..color = traits.headwearColor..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }
  }

  // ===========================================================================
  // Layer 7: Eyewear (Glasses, Sunglasses, Cyber Visor)
  // ===========================================================================
  void _paintEyewear(
    Canvas canvas,
    double cx,
    double cy,
    double headYawOffset,
    double pitchOffset,
    double cosYaw,
  ) {
    final headCenter = Offset(cx + headYawOffset, cy + pitchOffset);
    final eyeSpacing = 32.0 * (0.85 + 0.15 * cosYaw.abs());
    const glassesY = -4.0;
    const lensW = 34.0;
    const lensH = 26.0;

    final framePaint = Paint()
      ..color = traits.eyewearColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    if (traits.eyewear == 'cyber_visor') {
      // 💻 Cyberpunk HUD Visor with Holographic Glow
      final visorRect = Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + glassesY), width: 104, height: 28);
      final visorPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF06B6D4).withValues(alpha: 0.85),
            const Color(0xFF3B82F6).withValues(alpha: 0.85),
          ],
        ).createShader(visorRect);
      canvas.drawRRect(RRect.fromRectAndRadius(visorRect, const Radius.circular(6)), visorPaint);

      // Scanline glowing beam
      canvas.drawLine(
        Offset(headCenter.dx - 48, headCenter.dy + glassesY),
        Offset(headCenter.dx + 48, headCenter.dy + glassesY),
        Paint()..color = Colors.white.withValues(alpha: 0.75)..strokeWidth = 1.5,
      );
      return;
    }

    final lensTintPaint = Paint()
      ..color = (traits.eyewear == 'sunglasses')
          ? Colors.black.withValues(alpha: 0.80)
          : Colors.cyan.withValues(alpha: 0.10);

    // Left Lens
    final leftRect = Rect.fromCenter(
      center: Offset(headCenter.dx - eyeSpacing, headCenter.dy + glassesY),
      width: lensW,
      height: lensH,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(8)), lensTintPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(8)), framePaint);

    // Right Lens
    final rightRect = Rect.fromCenter(
      center: Offset(headCenter.dx + eyeSpacing, headCenter.dy + glassesY),
      width: lensW,
      height: lensH,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(8)), lensTintPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(8)), framePaint);

    // Bridge
    canvas.drawLine(
      Offset(headCenter.dx - eyeSpacing + lensW / 2, headCenter.dy + glassesY),
      Offset(headCenter.dx + eyeSpacing - lensW / 2, headCenter.dy + glassesY),
      framePaint,
    );

    // Glare shine reflection lines
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(headCenter.dx - eyeSpacing - 8, headCenter.dy + glassesY - 8),
      Offset(headCenter.dx - eyeSpacing + 4, headCenter.dy + glassesY + 4),
      shinePaint,
    );
    canvas.drawLine(
      Offset(headCenter.dx + eyeSpacing - 8, headCenter.dy + glassesY - 8),
      Offset(headCenter.dx + eyeSpacing + 4, headCenter.dy + glassesY + 4),
      shinePaint,
    );
  }

  // ===========================================================================
  // Layer 8: Honor Badge
  // ===========================================================================
  void _paintHonorBadge(
    Canvas canvas,
    double cx,
    double cy,
    double bodyYawOffset,
    double pitchOffset,
  ) {
    final badgeCenter = Offset(cx + bodyYawOffset + 38, cy + 105 + pitchOffset);

    // Golden Pin Backing
    canvas.drawCircle(badgeCenter, 9, Paint()..color = const Color(0xFFF59E0B));
    canvas.drawCircle(badgeCenter, 7, Paint()..color = const Color(0xFFFEF08A));

    // Star Motif
    final starPaint = Paint()..color = const Color(0xFFB45309);
    canvas.drawCircle(badgeCenter, 3.5, starPaint);
  }

  @override
  bool shouldRepaint(covariant BitmojiCustomPainter oldDelegate) {
    return oldDelegate.traits != traits ||
        oldDelegate.blinkValue != blinkValue ||
        oldDelegate.breathOffset != breathOffset ||
        oldDelegate.showFullBody != showFullBody ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.pitchX != pitchX ||
        oldDelegate.isTransparent != isTransparent;
  }
}
