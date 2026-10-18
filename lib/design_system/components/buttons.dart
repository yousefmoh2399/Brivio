import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  PrimaryButton — Gradient CTA with glow, loading state, press animation
/// ─────────────────────────────────────────────────────────────────────────────
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final double? width;
  final bool? expand;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Gradient? gradient;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 52,
    this.width,
    this.expand,
    this.padding,
    this.color,
    this.gradient,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _disabled => widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? AppColors.primaryGradient;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isBounded = constraints.hasBoundedWidth;
        final bool shouldExpand = widget.expand ?? isBounded;

        final double? effectiveWidth;
        if (widget.width != null) {
          if (widget.width!.isInfinite) {
            effectiveWidth = isBounded ? constraints.maxWidth : null;
          } else {
            effectiveWidth = isBounded
                ? math.min(widget.width!, constraints.maxWidth)
                : widget.width;
          }
        } else if (shouldExpand && isBounded) {
          effectiveWidth = double.infinity;
        } else {
          effectiveWidth = null;
        }

        final horizontalPadding =
            widget.padding ?? const EdgeInsets.symmetric(horizontal: 20);

        return GestureDetector(
          onTapDown: _disabled ? null : (_) => _ctrl.reverse(),
          onTapUp: _disabled ? null : (_) => _ctrl.forward(),
          onTapCancel: _disabled ? () {} : () => _ctrl.forward(),
          onTap: _disabled ? null : widget.onPressed,
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: effectiveWidth,
              height: widget.height,
              padding: effectiveWidth == null ? horizontalPadding : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _disabled ? null : gradient,
                color: _disabled ? AppColors.darkSurfaceSecondary : null,
                boxShadow: _disabled
                    ? null
                    : [
                        BoxShadow(
                          color: (widget.color ?? AppColors.primary).withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                          spreadRadius: -4,
                        ),
                      ],
              ),
              alignment: effectiveWidth != null ? Alignment.center : null,
              child: Align(
                alignment: Alignment.center,
                widthFactor: effectiveWidth == null ? 1.0 : null,
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Padding(
                        padding: effectiveWidth != null
                            ? (widget.padding ??
                                const EdgeInsets.symmetric(horizontal: 16))
                            : EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: _disabled
                                    ? AppColors.darkTextTertiary
                                    : Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                context.l10n.t(widget.text),
                                style: AppTypography.labelLarge(
                                  _disabled
                                      ? AppColors.darkTextTertiary
                                      : Colors.white,
                                ).copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  GhostButton — Transparent outlined button with subtle hover
/// ─────────────────────────────────────────────────────────────────────────────
class GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;
  final double? width;
  final bool? expand;
  final EdgeInsetsGeometry? padding;

  const GhostButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.height = 52,
    this.width,
    this.expand,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isBounded = constraints.hasBoundedWidth;
        final bool shouldExpand = expand ?? isBounded;

        final double? effectiveWidth;
        if (width != null) {
          if (width!.isInfinite) {
            effectiveWidth = isBounded ? constraints.maxWidth : null;
          } else {
            effectiveWidth = isBounded
                ? math.min(width!, constraints.maxWidth)
                : width;
          }
        } else if (shouldExpand && isBounded) {
          effectiveWidth = double.infinity;
        } else {
          effectiveWidth = null;
        }

        return SizedBox(
          width: effectiveWidth,
          height: height,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 18),
              foregroundColor: c,
              side: BorderSide(color: c.withValues(alpha: 0.4), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: c),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    context.l10n.t(text),
                    style: AppTypography.labelLarge(
                      c,
                    ).copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  IconPill — Small pill-shaped icon+label button
/// ─────────────────────────────────────────────────────────────────────────────
class IconPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const IconPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
