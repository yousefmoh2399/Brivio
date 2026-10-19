import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../domain/models/bitmoji_traits.dart';
import '../painters/bitmoji_vector_library.dart';

/// Commercial-grade Snapchat Bitmoji 3D Interactive Renderer.
/// Renders 100% live vector character graphics with real 3D perspective rotation,
/// dynamic specular highlights, stage pedestal, smooth camera zoom, natural eye blinking,
/// and high-resolution PNG export with transparent or studio background.
class BitmojiRenderer extends StatefulWidget {
  final BitmojiTraits traits;
  final AvatarCameraFocus cameraFocus;
  final bool isAnimated;
  final bool showPedestal;
  final double? width;
  final double? height;
  final GlobalKey? repaintKey;
  final double rotationY;
  final double pitchX;
  final bool? isTransparent;
  final bool isInteractive;
  final ValueChanged<double>? onRotationChanged;
  final ValueChanged<double>? onPitchChanged;

  const BitmojiRenderer({
    super.key,
    required this.traits,
    this.cameraFocus = AvatarCameraFocus.fullBody,
    this.isAnimated = true,
    this.showPedestal = true,
    this.width,
    this.height,
    this.repaintKey,
    this.rotationY = 0.0,
    this.pitchX = 0.0,
    this.isTransparent,
    this.isInteractive = false,
    this.onRotationChanged,
    this.onPitchChanged,
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
  Timer? _blinkTimer;

  double _localRotationY = 0.0;
  double _localPitchX = 0.0;

  @override
  void initState() {
    super.initState();
    _localRotationY = widget.rotationY;
    _localPitchX = widget.pitchX;

    // Gentle idle breathing oscillation
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _breathAnimation = Tween<double>(begin: -2.5, end: 2.5).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    // Natural Eye Blinking Animation
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    if (widget.isAnimated) {
      _breathController.repeat(reverse: true);
      _scheduleNextBlink();
    }
  }

  void _scheduleNextBlink() {
    if (!mounted || !widget.isAnimated) return;
    _blinkTimer?.cancel();
    final delayMs = 2800 + (math.Random().nextInt(2400));
    _blinkTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _blinkController.forward().then((_) {
        if (mounted) {
          _blinkController.reverse().then((_) => _scheduleNextBlink());
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant BitmojiRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rotationY != oldWidget.rotationY) {
      _localRotationY = widget.rotationY;
    }
    if (widget.pitchX != oldWidget.pitchX) {
      _localPitchX = widget.pitchX;
    }

    if (widget.isAnimated != oldWidget.isAnimated) {
      if (widget.isAnimated) {
        _breathController.repeat(reverse: true);
        _scheduleNextBlink();
      } else {
        _breathController.stop();
        _breathController.reset();
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

  double get _cameraScale {
    switch (widget.cameraFocus) {
      case AvatarCameraFocus.fullBody:
        return 1.0;
      case AvatarCameraFocus.bust:
        return 1.30;
      case AvatarCameraFocus.face:
        return 1.62;
      case AvatarCameraFocus.eyes:
        return 2.10;
      case AvatarCameraFocus.hair:
        return 1.72;
      case AvatarCameraFocus.outfit:
        return 1.28;
    }
  }

  Offset get _cameraSlideOffset {
    switch (widget.cameraFocus) {
      case AvatarCameraFocus.fullBody:
        return Offset.zero;
      case AvatarCameraFocus.bust:
        return const Offset(0, 0.08);
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

    final characterPainter = AnimatedBuilder(
      animation: Listenable.merge([_breathAnimation, _blinkController]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(w, h),
          painter: BitmojiCustomPainter(
            traits: widget.traits,
            blinkValue: _blinkController.value,
            breathOffset: widget.isAnimated ? _breathAnimation.value : 0.0,
            showFullBody: widget.showPedestal,
            rotationY: _localRotationY,
            pitchX: _localPitchX,
            isTransparent: widget.isTransparent,
          ),
        );
      },
    );

    // 3D Matrix Perspective Transformation
    final transformedCharacter = AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(
        _cameraSlideOffset.dx * w,
        _cameraSlideOffset.dy * h,
        0.0,
      )..multiply(Matrix4.diagonal3Values(_cameraScale, _cameraScale, 1.0)),
      alignment: Alignment.center,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(_localRotationY * 0.25)
          ..rotateX(_localPitchX * 0.25),
        alignment: Alignment.center,
        child: characterPainter,
      ),
    );

    Widget stageContent = RepaintBoundary(
      key: widget.repaintKey,
      child: SizedBox(
        width: w,
        height: h,
        child: ClipRect(
          child: transformedCharacter,
        ),
      ),
    );

    if (widget.isInteractive) {
      stageContent = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            _localRotationY = (_localRotationY + details.delta.dx * 0.015) % (2 * math.pi);
            _localPitchX = (_localPitchX - details.delta.dy * 0.008).clamp(-0.25, 0.25);
          });
          widget.onRotationChanged?.call(_localRotationY);
          widget.onPitchChanged?.call(_localPitchX);
        },
        child: stageContent,
      );
    }

    return stageContent;
  }
}
