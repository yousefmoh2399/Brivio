import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../domain/models/bitmoji_traits.dart';
import '../painters/bitmoji_vector_library.dart';

/// Interactive, live-animated Snapchat Bitmoji Renderer.
/// Supports camera zoom, idle breathing, organic blinking, and high-res PNG export.
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
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();

    // Idle breathing: continuous gentle sinusoidal floating
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _breathAnimation = Tween<double>(begin: -2.5, end: 2.5).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    // Natural Blinking animation
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    if (widget.isAnimated) {
      _breathController.repeat(reverse: true);
      _scheduleNextBlink();
    }
  }

  void _scheduleNextBlink() {
    if (!mounted || !widget.isAnimated) return;
    // Random interval between 2.5 and 5 seconds for natural blinking
    final randomMs = 2500 + math.Random().nextInt(2500);
    _blinkTimer = Timer(Duration(milliseconds: randomMs), () async {
      if (!mounted) return;
      await _blinkController.forward();
      if (!mounted) return;
      await _blinkController.reverse();
      _scheduleNextBlink();
    });
  }

  @override
  void didUpdateWidget(covariant BitmojiRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated != oldWidget.isAnimated) {
      if (widget.isAnimated) {
        _breathController.repeat(reverse: true);
        _scheduleNextBlink();
      } else {
        _breathController.stop();
        _blinkTimer?.cancel();
        _blinkController.reset();
      }
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  /// Calculates camera zoom scale based on focus
  double get _cameraScale {
    switch (widget.cameraFocus) {
      case AvatarCameraFocus.fullBody:
        return 1.0;
      case AvatarCameraFocus.face:
        return 1.62;
      case AvatarCameraFocus.eyes:
        return 2.15;
      case AvatarCameraFocus.hair:
        return 1.75;
      case AvatarCameraFocus.outfit:
        return 1.35;
    }
  }

  /// Calculates camera offset based on focus
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
        return const Offset(0, -0.12);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = AnimatedBuilder(
      animation: Listenable.merge([_breathAnimation, _blinkAnimation]),
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width ?? 320, widget.height ?? 380),
          painter: BitmojiCustomPainter(
            traits: widget.traits,
            blinkValue: _blinkAnimation.value,
            breathOffset: _breathAnimation.value,
            showFullBody: widget.showPedestal,
          ),
        );
      },
    );

    // Repaint boundary enables high resolution snapshots of the vector canvas
    final paintWithBoundary = RepaintBoundary(
      key: widget.repaintKey,
      child: ClipRect(
        child: AnimatedSlide(
          offset: _cameraSlideOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          child: AnimatedScale(
            scale: _cameraScale,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            child: body,
          ),
        ),
      ),
    );

    if (widget.width != null || widget.height != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: paintWithBoundary,
      );
    }

    return paintWithBoundary;
  }
}
