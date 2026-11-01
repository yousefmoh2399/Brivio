import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Pure, full-screen animated splash screen playing the provided Lottie logo animation.
/// Clean, fast, and completely free of any artificial widgets or text.
class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final bool isReadyToTransition;
  final Duration animationDuration;

  const AnimatedSplashScreen({
    super.key,
    required this.onFinish,
    this.isReadyToTransition = true,
    this.animationDuration = const Duration(milliseconds: 2500),
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;
  bool _animationCompleted = false;
  bool _hasTransitioned = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF06172A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _lottieController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationCompleted = true;
        _checkAndTransition();
      }
    });

    _lottieController.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedSplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReadyToTransition && !_hasTransitioned && _animationCompleted) {
      _checkAndTransition();
    }
  }

  void _checkAndTransition() {
    if (_animationCompleted && widget.isReadyToTransition && !_hasTransitioned) {
      _hasTransitioned = true;
      Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          widget.onFinish();
        }
      });
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06172A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _animationCompleted = true;
          _checkAndTransition();
        },
        child: SizedBox.expand(
          child: Center(
            child: Lottie.asset(
              'assets/logo_splash.json',
              controller: _lottieController,
              frameRate: FrameRate.max,
              fit: BoxFit.contain,
              repeat: false,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/branding/brivio_icon.png',
                  width: 200,
                  fit: BoxFit.contain,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
