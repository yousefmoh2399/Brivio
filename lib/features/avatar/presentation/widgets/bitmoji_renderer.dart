import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../domain/models/bitmoji_traits.dart';
import '../painters/bitmoji_vector_library.dart';

/// Commercial-grade Snapchat Bitmoji 3D Renderer.
/// Combines high-resolution character graphics with a 3D pedestal stage,
/// smooth animated camera zoom, idle breathing, and high-res PNG export.
class BitmojiRenderer extends StatefulWidget {
  final BitmojiTraits traits;
  final AvatarCameraFocus cameraFocus;
  final bool isAnimated;
  final bool showPedestal;
  final double? width;
  final double? height;
  final GlobalKey? repaintKey;

  const BitmojiRenderer({
    super.key,
    required this.traits,
    this.cameraFocus = AvatarCameraFocus.fullBody,
    this.isAnimated = true,
    this.showPedestal = true,
    this.width,
    this.height,
    this.repaintKey,
  });

  /// Captures a high-resolution PNG image directly from a RepaintBoundary
  static Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  State<BitmojiRenderer> createState() => _BitmojiRendererState();
}

class _BitmojiRendererState extends State<BitmojiRenderer>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();

    // Gentle idle breathing oscillation
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _breathAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    if (widget.isAnimated) {
      _breathController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant BitmojiRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated != oldWidget.isAnimated) {
      if (widget.isAnimated) {
        _breathController.repeat(reverse: true);
      } else {
        _breathController.stop();
        _breathController.reset();
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  double get _cameraScale {
    switch (widget.cameraFocus) {
      case AvatarCameraFocus.fullBody:
        return 1.0;
      case AvatarCameraFocus.face:
        return 1.55;
      case AvatarCameraFocus.eyes:
        return 2.0;
      case AvatarCameraFocus.hair:
        return 1.65;
      case AvatarCameraFocus.outfit:
        return 1.25;
    }
  }

  Offset get _cameraSlideOffset {
    switch (widget.cameraFocus) {
      case AvatarCameraFocus.fullBody:
        return Offset.zero;
      case AvatarCameraFocus.face:
        return const Offset(0, 0.16);
      case AvatarCameraFocus.eyes:
        return const Offset(0, 0.22);
      case AvatarCameraFocus.hair:
        return const Offset(0, 0.12);
      case AvatarCameraFocus.outfit:
        return const Offset(0, -0.10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? 320.0;
    final h = widget.height ?? 380.0;
    final imageUrl = widget.traits.toImageUrl(size: 512);

    final characterContent = AnimatedBuilder(
      animation: _breathAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, widget.isAnimated ? _breathAnimation.value : 0),
          child: child,
        );
      },
      child: Center(
        child: Image.network(
          imageUrl,
          width: w * 0.92,
          height: h * 0.88,
          fit: BoxFit.contain,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: w * 0.92,
              height: h * 0.88,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.traits.outfitColor,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (ctx, err, stack) {
            // High quality fallback in case network is completely unavailable
            return CustomPaint(
              size: Size(w, h),
              painter: BitmojiCustomPainter(
                traits: widget.traits,
                showFullBody: widget.showPedestal,
              ),
            );
          },
        ),
      ),
    );

    // Full 3D Pedestal Stage
    final stage = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.95,
          colors: [
            widget.traits.backgroundColor.withValues(alpha: 0.9),
            widget.traits.backgroundColor.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Studio Spotlight Cone
          Positioned(
            top: 0,
            bottom: h * 0.08,
            width: w * 0.85,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.75,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3D Elliptical Pedestal Platform
          if (widget.showPedestal) ...[
            // Soft Floor Contact Shadow
            Positioned(
              bottom: h * 0.02,
              child: Container(
                width: w * 0.82,
                height: h * 0.08,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(w * 0.41, h * 0.04),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

            // Pedestal Lower Cylinder Body
            Positioned(
              bottom: h * 0.045,
              child: Container(
                width: w * 0.74,
                height: h * 0.065,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(w * 0.37, h * 0.032),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey.shade400.withValues(alpha: 0.85),
                      Colors.grey.shade700.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),

            // Pedestal Upper Disc Surface with Neon Bevel
            Positioned(
              bottom: h * 0.065,
              child: Container(
                width: w * 0.74,
                height: h * 0.075,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(w * 0.37, h * 0.037),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.65),
                    ],
                  ),
                  border: Border.all(
                    color: widget.traits.outfitColor.withValues(alpha: 0.55),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.traits.outfitColor.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Main Character with Camera Zoom
          ClipRect(
            child: AnimatedSlide(
              offset: _cameraSlideOffset,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              child: AnimatedScale(
                scale: _cameraScale,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                child: characterContent,
              ),
            ),
          ),
        ],
      ),
    );

    final result = RepaintBoundary(
      key: widget.repaintKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: stage,
      ),
    );

    if (widget.width != null || widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height, child: result);
    }
    return result;
  }
}
