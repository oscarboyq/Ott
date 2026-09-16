import 'package:flutter/material.dart';

/// A robust, high-contrast container for platform branding logos.
///
/// Prevents WebGL CanvasKit uninitialized texture / black box artifacts by
/// using Flutter's native [Image.network] pipeline with frameBuilder,
/// and guarantees crystal-clear contrast on both dark and light backgrounds.
class AppBrandingLogo extends StatelessWidget {
  final String logoUrl;
  final double height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool whiteTile;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppBrandingLogo({
    super.key,
    required this.logoUrl,
    this.height = 32,
    this.width,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.padding,
    this.whiteTile = true,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(height > 48 ? 16 : 8);
    final innerRadius = BorderRadius.circular(
      (effectiveRadius.topLeft.x - 2).clamp(2.0, 100.0),
    );

    final defaultFallback = Container(
      width: height,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF05454),
        borderRadius: effectiveRadius,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: height * 0.65,
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = whiteTile
        ? Colors.white
        : (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.04));

    final borderColor = whiteTile
        ? Colors.black.withValues(alpha: 0.08)
        : (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.08));

    return Container(
      height: height + 8,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: effectiveRadius,
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: whiteTile
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: innerRadius,
        child: Image.network(
          logoUrl,
          height: height,
          width: width,
          fit: fit,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return placeholder ?? defaultFallback;
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? defaultFallback;
          },
        ),
      ),
    );
  }
}
