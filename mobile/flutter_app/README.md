# flutter_app

Finance Tracker client. The UI implements the "Pop-It" claymorphic design
(Figma: Style F) and currently runs on static data.

```bash
flutter run
flutter test
flutter analyze
```

## Layout

```
lib/
  main.dart                 App shell and theme
  theme/clay_theme.dart     Design tokens: palette, matte ramps, type, motion
  widgets/clay_surface.dart ClaySurface, InnerShadow, Recessed, ClayTrack
  widgets/pop_it.dart       PopIt bubble + PressableRecess, and the press animation
  data/static_data.dart     Hard-coded content — swap for api/api_client.dart
  screens/home_screen.dart  Home / expense tracker
  screens/scan_screen.dart  Scan & Pay
  api/api_client.dart       Gateway client (not wired to the UI yet)
```

## The style in one paragraph

One lavender hue, no second accent. Depth carries meaning: anything you only
read is **carved into** the canvas, anything you tap is a **matte silicone
bubble** seated in a socket. Nothing casts a shadow onto the background, so
nothing floats. Pressing a bubble drops it into its socket — contact shadow to
zero, gradient ramp reversed, rim lighting flipped — which is the same recipe
as the recessed surfaces, so the press is a straight interpolation between two
states rather than a swap.

## Inner shadows

Flutter has no `inset` box-shadow, and the entire style depends on one. See
`_InnerShadowPainter` in `widgets/clay_surface.dart`: it clips to the shape and
fills everything *outside* an offset copy of it, so the blurred edge of that
fill bleeds back across the clip boundary. Blur is halved on the way in because
Figma expresses blur as a diameter and `MaskFilter` wants a sigma.

Each bubble costs two inner shadows plus one for its socket. That is cheap at
the counts used here, but if a long transaction list ever scrolls at 120fps on
a low-end device, the rows are the first thing to profile.

## Fonts

The design specifies Inter; no font asset is bundled, so the app falls back to
the platform font (Roboto / SF). Add Inter to `pubspec.yaml` under `fonts:` to
match the Figma exactly.

## Wiring up the backend

`data/static_data.dart` is the only source of content. Replace its consts with
calls through `api/api_client.dart`; no widget reads the network directly.
