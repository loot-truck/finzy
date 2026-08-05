import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/clay_theme.dart';
import 'clay_surface.dart';

/// A pop-it bubble: a matte silicone dome seated in a socket cut into the
/// surface.
///
/// Two states, and the animation between them is the whole point:
///
///  * **resting** — the dome is convex. A 45° light-to-dark ramp across the
///    face, rim light from the top-left, and a 2px contact shadow. It sits
///    *in* the surface; it never casts onto the background, so it never floats.
///  * **pressed** — the dome drops into the socket and takes on the recessed
///    recipe from Style D: contact shadow gone, ramp reversed, rim lighting
///    flipped so the dark edge is now top-left.
///
/// Because both states are the same three shadows with different values, the
/// press is a straight interpolation rather than a swap.
class PopIt extends StatefulWidget {
  const PopIt({
    super.key,
    this.child,
    this.onTap,
    this.tone = PopTone.neutral,
    this.size,
    this.width,
    this.height,
    this.radius,
    this.inset = 4,
    this.padding,
  });

  /// Convenience for a round bubble.
  const PopIt.circle({
    Key? key,
    required double size,
    Widget? child,
    VoidCallback? onTap,
    PopTone tone = PopTone.neutral,
    double inset = 4,
  }) : this(
          key: key,
          size: size,
          child: child,
          onTap: onTap,
          tone: tone,
          inset: inset,
        );

  final Widget? child;
  final VoidCallback? onTap;
  final PopTone tone;

  /// Shorthand for equal width and height.
  final double? size;
  final double? width;
  final double? height;

  /// Null means fully round (radius = half the shorter side).
  final BorderRadius? radius;

  /// How far the dome sits inside its socket.
  final double inset;
  final EdgeInsetsGeometry? padding;

  @override
  State<PopIt> createState() => _PopItState();
}

class _PopItState extends State<PopIt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Clay.pressDuration,
    reverseDuration: Clay.releaseDuration,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => _c.forward();
  void _up(_) => _c.reverse();
  void _cancel() => _c.reverse();

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? widget.size;
    final h = widget.height ?? widget.size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : _down,
      onTapUp: widget.onTap == null ? null : _up,
      onTapCancel: widget.onTap == null ? null : _cancel,
      onTap: widget.onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolvedW = w ?? constraints.maxWidth;
          final resolvedH = h ?? constraints.maxHeight;
          final round = BorderRadius.circular(
            (resolvedW.isFinite && resolvedH.isFinite)
                ? (resolvedW < resolvedH ? resolvedW : resolvedH) / 2
                : 999,
          );
          final socketRadius = widget.radius ?? round;
          final capRadius = widget.radius == null
              ? round
              : BorderRadius.circular(
                  (widget.radius!.topLeft.x - widget.inset).clamp(0.0, 999.0),
                );

          return ClaySurface(
            width: w,
            height: h,
            radius: socketRadius,
            color: widget.tone.socket,
            innerShadows: [
              InnerShadow(
                color: Clay.shadowTint.withValues(alpha: 0.52),
                offset: const Offset(2, 3),
                blur: 5,
              ),
              InnerShadow(
                color: Colors.white.withValues(alpha: 0.55),
                offset: const Offset(-2, -2),
                blur: 4,
              ),
            ],
            child: Padding(
              padding: EdgeInsets.all(widget.inset),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => _cap(capRadius, _curved()),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Ease out on the way down, a slight overshoot on release — silicone
  /// relaxing rather than a linear return.
  double _curved() {
    final curve = _c.status == AnimationStatus.reverse
        ? Clay.releaseCurve
        : Clay.pressCurve;
    return curve.transform(_c.value).clamp(0.0, 1.0);
  }

  Widget _cap(BorderRadius radius, double t) {
    final ramp = widget.tone.ramp;
    final dark = ramp.last;

    // Resting: light lands top-left. Pressed: the ramp reverses, so the dome
    // reads as a hollow lit from the opposite side.
    final gradient = LinearGradient.lerp(
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ramp,
        stops: const [0, 0.5, 1],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ramp.reversed.toList(),
        stops: const [0, 0.5, 1],
      ),
      t,
    )!;

    // Rim light swings from top-left (convex) to bottom-right (concave).
    final rimLight = InnerShadow.lerp(
      InnerShadow(
        color: Colors.white.withValues(alpha: 0.40),
        offset: const Offset(2, 3),
        blur: 9,
      ),
      InnerShadow(
        color: Colors.white.withValues(alpha: 0.55),
        offset: const Offset(-2, -2),
        blur: 4,
      ),
      t,
    );
    final rimShade = InnerShadow.lerp(
      InnerShadow(
        color: dark.withValues(alpha: 0.40),
        offset: const Offset(-2, -3),
        blur: 9,
      ),
      InnerShadow(
        color: widget.tone.shadow.withValues(alpha: 0.52),
        offset: const Offset(2, 3),
        blur: 5,
      ),
      t,
    );

    return Transform.translate(
      // The dome settles down and to the right as it enters the socket.
      offset: Offset(ui.lerpDouble(0, 0.5, t)!, ui.lerpDouble(0, 1.5, t)!),
      child: Transform.scale(
        scale: ui.lerpDouble(1.0, 0.965, t)!,
        child: ClaySurface(
          radius: radius,
          gradient: gradient,
          innerShadows: [rimLight, rimShade],
          shadows: [
            BoxShadow(
              // Contact shadow only — and it fades to nothing when pressed,
              // because a dome sunk into its socket touches all the way round.
              color: widget.tone.shadow
                  .withValues(alpha: ui.lerpDouble(0.32, 0.0, t)!),
              offset: Offset(0, ui.lerpDouble(2, 0, t)!),
              blurRadius: ui.lerpDouble(4, 0, t)!,
            ),
          ],
          padding: widget.padding,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

/// A recessed surface that deepens when pressed. Used for list rows, which are
/// tappable but are not bubbles — they stay carved in, they just sink further.
class PressableRecess extends StatefulWidget {
  const PressableRecess({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 26,
    this.depth = 0.7,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry? padding;

  @override
  State<PressableRecess> createState() => _PressableRecessState();
}

class _PressableRecessState extends State<PressableRecess>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Clay.pressDuration,
    reverseDuration: Clay.releaseDuration,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _c.forward(),
      onTapUp: widget.onTap == null ? null : (_) => _c.reverse(),
      onTapCancel: widget.onTap == null ? null : () => _c.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_c.value);
          final depth = ui.lerpDouble(widget.depth, widget.depth * 1.6, t)!;
          return ClaySurface(
            radius: BorderRadius.circular(widget.radius),
            color: Color.lerp(Clay.surface, Clay.socketNeutral, t * 0.6)!,
            padding: widget.padding,
            innerShadows: Recessed.shadowsFor(depth),
            shadows: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.65 * (1 - t)),
                offset: const Offset(1, 2),
                blurRadius: 3,
              ),
            ],
            child: child!,
          );
        },
      ),
    );
  }
}
