import 'package:flutter/material.dart';

import '../data/static_data.dart';
import '../theme/clay_theme.dart';
import '../widgets/clay_surface.dart';
import '../widgets/pop_it.dart';

/// Style F — Scan & Pay.
///
/// The camera window is the deepest cut on the screen; every control around it
/// is a bubble.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Clay.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Row(
                children: [
                  PopIt.circle(
                    size: 46,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: Clay.ink,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan & Pay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Clay.ink,
                      ),
                    ),
                  ),
                  PopIt.circle(
                    size: 46,
                    onTap: () {},
                    child: const Icon(
                      Icons.flash_on_rounded,
                      size: 20,
                      color: Clay.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: Center(child: _CameraWindow())),
            const _Sheet(),
          ],
        ),
      ),
    );
  }
}

class _CameraWindow extends StatelessWidget {
  const _CameraWindow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve room for the hint pill below, then take the largest square
        // that still fits. On a phone this lands on the design's 310pt.
        final available = [
          310.0,
          constraints.maxWidth - 40,
          constraints.maxHeight - 90,
        ].reduce((a, b) => a < b ? a : b);
        final size = available.clamp(140.0, 310.0);
        return _window(size);
      },
    );
  }

  Widget _window(double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClaySurface(
          width: size,
          height: size,
          radius: BorderRadius.circular(size * 0.174),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A3560), Color(0xFF211D3B)],
          ),
          innerShadows: [
            InnerShadow(
              color: const Color(0xFF080520).withValues(alpha: 0.8),
              offset: const Offset(10, 12),
              blur: 22,
            ),
            InnerShadow(
              color: Colors.white.withValues(alpha: 0.18),
              offset: const Offset(-10, -12),
              blur: 22,
            ),
          ],
          child: Center(child: _Viewfinder(size: size * 0.6)),
        ),
        const SizedBox(height: 26),
        ClaySurface(
          radius: BorderRadius.circular(24),
          color: Clay.surface,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          innerShadows: Recessed.shadowsFor(0.5),
          child: const Text(
            'Hold steady over the QR code',
            style: TextStyle(fontSize: 12, color: Clay.dim),
          ),
        ),
      ],
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (final corner in const [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(alignment: corner, child: _Bracket(corner: corner)),
          Center(
            child: Container(
              height: 4,
              width: size * 0.84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bracket extends StatelessWidget {
  const _Bracket({required this.corner});

  final Alignment corner;

  @override
  Widget build(BuildContext context) {
    const len = 40.0;
    const thick = 5.0;
    final isTop = corner.y < 0;
    final isLeft = corner.x < 0;
    final bar = BoxDecoration(
      color: Clay.accentSoft,
      borderRadius: BorderRadius.circular(3),
    );

    return SizedBox(
      width: len,
      height: len,
      child: Stack(
        children: [
          Align(
            alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            child: Container(width: len, height: thick, decoration: bar),
          ),
          Align(
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(width: thick, height: len, decoration: bar),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: const BorderRadius.vertical(top: Radius.circular(44)),
      color: Clay.surface,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      innerShadows: Recessed.shadowsFor(1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Clay.well,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recent payees', style: Clay.label),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final p in kPayees) ...[
                Expanded(
                  child: Column(
                    children: [
                      PopIt.circle(
                        size: 50,
                        tone: p.tone,
                        onTap: () {},
                        child: Text(
                          p.initial,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.tone == PopTone.accent
                                ? Colors.white
                                : Clay.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(p.name, style: Clay.caption),
                    ],
                  ),
                ),
                if (p != kPayees.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PopIt(
                  height: 56,
                  radius: BorderRadius.circular(24),
                  onTap: () {},
                  child: const Text(
                    'Gallery',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Clay.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PopIt(
                  height: 56,
                  radius: BorderRadius.circular(24),
                  tone: PopTone.accent,
                  onTap: () {},
                  child: const Text(
                    'Pay via UPI ID',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
