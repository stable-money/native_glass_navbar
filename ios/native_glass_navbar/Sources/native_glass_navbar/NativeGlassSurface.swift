import Flutter
import UIKit

/// A rounded panel of the system's own Liquid Glass, for Flutter content to sit
/// on.
///
/// The same material `UITabBar` uses on iOS 26, so a card docked above the
/// native tab bar reads as the same glass rather than a Flutter blur that only
/// approximates it. The view only draws the material: the card's content is
/// Flutter, composited above it, and the glass samples the Flutter page below
/// it exactly as the tab bar does.
///
/// Creation params (all optional):
/// - `cornerRadius`: Double, points. Continuous corners.
/// - `tintColor`: Int, ARGB. Tints the glass.
///
/// Below iOS 26 there is no `UIGlassEffect`; the panel falls back to the system
/// material blur so callers never get an empty frame.
class NativeGlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
	func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
		-> FlutterPlatformView
	{
		return NativeGlassSurfacePlatformView(frame: frame, args: args)
	}

	func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
		return FlutterStandardMessageCodec.sharedInstance()
	}
}

/// The glass panel, rounded the way Flutter rounds the same box.
///
/// The requested radius is capped at half the short side on every layout —
/// Flutter's `RRect` does the same — since the card is content-sized and the
/// cap is only known once it is. At that cap the corners are circular: a
/// continuous corner needs room along each edge beyond its radius, and a
/// capsule leaves none, so Core Animation draws the ends as a pointed lens
/// that no longer lines up with a Flutter shadow or border around it.
private final class GlassPanelView: UIVisualEffectView {
	var requestedCornerRadius: CGFloat = 0

	override func layoutSubviews() {
		super.layoutSubviews()
		let capsuleRadius = min(bounds.width, bounds.height) / 2
		let radius = min(requestedCornerRadius, capsuleRadius)
		layer.cornerRadius = radius
		layer.cornerCurve = radius >= capsuleRadius - 0.5 ? .circular : .continuous
	}
}

class NativeGlassSurfacePlatformView: NSObject, FlutterPlatformView {
	private let effectView: GlassPanelView

	init(frame: CGRect, args: Any?) {
		let params = args as? [String: Any] ?? [:]
		let cornerRadius = CGFloat((params["cornerRadius"] as? NSNumber)?.doubleValue ?? 0)
		let tint = (params["tintColor"] as? NSNumber).map { Self.color(argb: $0.uint32Value) }

		effectView = GlassPanelView(effect: Self.makeEffect(tint: tint))
		effectView.frame = frame
		effectView.clipsToBounds = true
		effectView.requestedCornerRadius = cornerRadius
		// Touches belong to the Flutter content above; the Dart side also wraps
		// the view in IgnorePointer, so this is belt and braces.
		effectView.isUserInteractionEnabled = false
		super.init()
	}

	func view() -> UIView {
		return effectView
	}

	private static func makeEffect(tint: UIColor?) -> UIVisualEffect {
		if #available(iOS 26.0, *) {
			let glass = UIGlassEffect(style: .regular)
			glass.tintColor = tint
			return glass
		}
		return UIBlurEffect(style: .systemMaterial)
	}

	private static func color(argb: UInt32) -> UIColor {
		return UIColor(
			red: CGFloat((argb >> 16) & 0xFF) / 255,
			green: CGFloat((argb >> 8) & 0xFF) / 255,
			blue: CGFloat(argb & 0xFF) / 255,
			alpha: CGFloat((argb >> 24) & 0xFF) / 255
		)
	}
}
