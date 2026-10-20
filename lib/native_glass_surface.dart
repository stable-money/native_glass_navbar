import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A rounded panel of the system's own Liquid Glass with Flutter content on
/// top — the same material the native tab bar uses.
///
/// The glass is a `UIVisualEffectView` with `UIGlassEffect` (iOS 26), drawn
/// through a platform view *behind* [child]. It samples the Flutter content
/// beneath it exactly as the native tab bar does, so a card docked above the
/// bar reads as the same glass. Below iOS 26 the native side falls back to the
/// system material blur.
///
/// Off iOS this renders [child] alone — callers own their non-iOS surface.
///
/// Touches go to [child]: the platform view is wrapped in [IgnorePointer], so
/// it never competes with the content's gestures.
class NativeGlassSurface extends StatelessWidget {
  /// Corner radius of the panel, in logical pixels. Corners are continuous.
  final double cornerRadius;

  /// Optional tint applied to the glass itself.
  final Color? tintColor;

  /// The content drawn on the glass. It sizes the panel.
  final Widget child;

  /// Creates a glass panel behind [child].
  const NativeGlassSurface({
    super.key,
    required this.child,
    this.cornerRadius = 0,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return child;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: UiKitView(
              // Creation params are read once; a new key rebuilds the native
              // view when the shape or tint changes.
              key: ValueKey((cornerRadius, tintColor?.toARGB32())),
              viewType: 'NativeGlassSurface',
              creationParams: <String, Object?>{
                'cornerRadius': cornerRadius,
                if (tintColor != null) 'tintColor': tintColor!.toARGB32(),
              },
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
