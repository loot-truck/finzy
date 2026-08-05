import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/clay_theme.dart';

/// An inner shadow. Flutter has no equivalent of CSS `inset` box-shadow or
/// Figma's INNER_SHADOW, so the whole claymorphic style depends on this.
@immutable
class InnerShadow {
  const InnerShadow({
    required this.color,
    required this.offset,
    required this.blur,
  });

  final Color color;
  final Offset offset;
  final double blur;

  static InnerShadow lerp(InnerShadow a, InnerShadow b, double t) {
    return InnerShadow(
      color: Color.lerp(a.color, b.color, t)!,
      offset: Offset.lerp(a.offset, b.offset, t)!,
      blur: ui.lerpDouble(a.blur, b.blur, t)!,
    );
  }
}

/// Paints inner shadows by clipping to the shape and filling everything
/// *outside* an offset copy of it. The blurred edge of that fill bleeds back
/// across the clip boundary, which is exactly an inner shadow.
class _InnerShadowPainter extends CustomPainter {
  const _InnerShadowPainter(this.shadows, this.radius);

  final List<InnerShadow> shadows;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final rrect = radius.toRRect(Offset.zero & size);

    canvas.save();
    canvas.clipRRect(rrect);
    for (final s in shadows) {
      if (s.color.a == 0) continue;
      final paint = Paint()
        ..color = s.color
        // Figma expresses blur as a diameter, MaskFilter wants a sigma.
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, s.blur / 2);

      // A rect far larger than the shape, minus the shape shifted by `offset`.
      final bleed = size.longestSide + s.blur * 4;
      final outer = Path()
        ..addRect(Rect.fromLTRB(
          -bleed,
          -bleed,
          size.width + bleed,
          size.height + bleed,
        ));
      final inner = Path()..addRRect(rrect.shift(s.offset));
      canvas.drawPath(
        Path.combine(PathOperation.difference, outer, inner),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerShadowPainter old) =>
      old.shadows != shadows || old.radius != radius;
}

/// The one primitive every clay element is built from: a rounded shape with a
/// fill (flat or gradient), outer shadows, and inner shadows painted above the
/// fill but below the child.
class ClaySurface extends StatelessWidget {
  const ClaySurface({
    super.key,
    required this.radius,
    this.color,
    this.gradient,
    this.innerShadows = const [],
    this.shadows = const [],
    this.width,
    this.height,
    this.padding,
    this.child,
  });

  final BorderRadius radius;
  final Color? color;
  final Gradient? gradient;
  final List<InnerShadow> innerShadows;
  final List<BoxShadow> shadows;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: Stack(
        children: [
          if (innerShadows.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _InnerShadowPainter(innerShadows, radius),
                ),
              ),
            ),
          if (child != null)
            Padding(padding: padding ?? EdgeInsets.zero, child: child!),
        ],
      ),
    );
  }
}

/// A surface carved *into* the canvas: dark inner shadow on the top-left,
/// light inner shadow on the bottom-right, and a faint white outer lip so the
/// edge reads as a cut rather than a sticker.
///
/// Used for everything you only read — cards, the spend hero, progress
/// tracks, the nav bar, the camera window, the sheet.
class Recessed extends StatelessWidget {
  const Recessed({
    super.key,
    required this.child,
    this.radius = 32,
    this.color = Clay.surface,
    this.gradient,
    this.depth = 0.85,
    this.padding,
    this.lip = true,
  });

  final Widget child;
  final double radius;
  final Color color;
  final Gradient? gradient;

  /// Scales the shadow geometry. Bigger elements need deeper cuts to read as
  /// the same material as small ones.
  final double depth;
  final EdgeInsetsGeometry? padding;
  final bool lip;

  static List<InnerShadow> shadowsFor(double depth, {Color? tint}) => [
        InnerShadow(
          color: (tint ?? Clay.shadowTint).withValues(alpha: 0.42),
          offset: Offset(6 * depth, 7 * depth),
          blur: 12 * depth,
        ),
        InnerShadow(
          color: Colors.white.withValues(alpha: 0.95),
          offset: Offset(-6 * depth, -7 * depth),
          blur: 12 * depth,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: BorderRadius.circular(radius),
      color: color,
      gradient: gradient,
      padding: padding,
      innerShadows: shadowsFor(depth),
      shadows: lip
          ? [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.65),
                offset: const Offset(1, 2),
                blurRadius: 3,
              ),
            ]
          : const [],
      child: child,
    );
  }
}

/// A progress track — the same recipe inverted and tightened, so it reads as a
/// narrow well rather than a raised bar.
class ClayTrack extends StatelessWidget {
  const ClayTrack({
    super.key,
    required this.value,
    this.height = 12,
    this.fill,
    this.background = Clay.well,
  });

  final double value; // 0..1
  final double height;
  final Color? fill;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClaySurface(
          radius: BorderRadius.circular(height / 2),
          color: background,
          height: height,
          innerShadows: [
            InnerShadow(
              color: Clay.shadowTint.withValues(alpha: 0.55),
              offset: const Offset(3, 4),
              blur: 6,
            ),
            InnerShadow(
              color: Colors.white.withValues(alpha: 0.85),
              offset: const Offset(-2, -2),
              blur: 4,
            ),
          ],
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: constraints.maxWidth * value.clamp(0.0, 1.0),
              height: height,
              decoration: BoxDecoration(
                color: fill ?? Clay.accent,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        );
      },
    );
  }
}
