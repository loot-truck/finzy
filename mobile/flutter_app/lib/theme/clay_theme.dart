import 'package:flutter/material.dart';

/// Design tokens for the "Pop-It" claymorphic style (Figma: Style F).
///
/// The whole style rests on one idea: a single hue, and depth carried by
/// form rather than colour. Surfaces are carved into the canvas; controls are
/// matte silicone domes seated in sockets. Nothing casts a shadow onto the
/// background, so nothing floats.
class Clay {
  const Clay._();

  // ---------------------------------------------------------------- palette
  // Deliberately near-monochrome: one lavender scale plus a single accent.
  static const canvas = Color(0xFFE8E6F5);
  static const surface = Color(0xFFE5E3F3);
  static const well = Color(0xFFDAD6EE);
  static const socketNeutral = Color(0xFFD8D3EE);
  static const socketAccent = Color(0xFFCFC8EE);

  static const accent = Color(0xFF7B6EF6);
  static const accentSoft = Color(0xFFC9C3FB);

  static const ink = Color(0xFF2C2842);
  static const dim = Color(0xFF8B85A8);
  static const onAccent = Color(0xFFFFFFFF);
  static const onAccentDim = Color(0xFFDCD8FE);

  /// Tint every shadow with the palette hue. Neutral grey shadows on a
  /// coloured canvas read as dirt.
  static const shadowTint = Color(0xFF665E99);
  static const shadowAccent = Color(0xFF33279F);

  // ------------------------------------------------------------- matte ramps
  // Three stops, no pure white anywhere. The absence of a specular highlight
  // is what separates matte silicone from glossy plastic.
  static const rampNeutral = [
    Color(0xFFF4F1FB),
    Color(0xFFE6E2F5),
    Color(0xFFCDC7E3),
  ];
  static const rampSoft = [
    Color(0xFFDFDAFB),
    Color(0xFFCDC6F5),
    Color(0xFFB0A8E4),
  ];
  static const rampAccent = [
    Color(0xFF948AF4),
    Color(0xFF8377EE),
    Color(0xFF6659D4),
  ];

  // ------------------------------------------------------------------- type
  static const _family = null; // system font; see note in README

  static const displayLarge = TextStyle(
    fontFamily: _family,
    fontSize: 38,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.2,
    color: onAccent,
  );
  static const title = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: ink,
  );
  static const sectionTitle = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
  );
  static const body = TextStyle(fontFamily: _family, fontSize: 14, color: ink);
  static const bodyMedium = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: ink,
  );
  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    color: dim,
  );
  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    color: dim,
  );
  static const amount = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  // ------------------------------------------------------------- animation
  /// Fast down, slower release — a press should feel immediate, a return
  /// should feel like silicone relaxing.
  static const pressDuration = Duration(milliseconds: 90);
  static const releaseDuration = Duration(milliseconds: 260);
  static const pressCurve = Curves.easeOutCubic;
  static const releaseCurve = Curves.easeOutBack;
}

/// Tone of a pop-it bubble. Governs which matte ramp and socket it uses.
enum PopTone { neutral, soft, accent }

extension PopToneRamp on PopTone {
  List<Color> get ramp => switch (this) {
        PopTone.neutral => Clay.rampNeutral,
        PopTone.soft => Clay.rampSoft,
        PopTone.accent => Clay.rampAccent,
      };

  Color get socket => switch (this) {
        PopTone.neutral => Clay.socketNeutral,
        _ => Clay.socketAccent,
      };

  Color get shadow => switch (this) {
        PopTone.accent => Clay.shadowAccent,
        _ => Clay.shadowTint,
      };
}
