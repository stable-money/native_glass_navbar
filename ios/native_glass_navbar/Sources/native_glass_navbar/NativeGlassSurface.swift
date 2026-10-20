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

class NativeGlassSurfacePlatformView: NSObject, FlutterPlatformView {
	private let effectView: UIVisualEffectView

	init(frame: CGRect, args: Any?) {
		let params = args as? [String: Any] ?? [:]
		let cornerRadius = CGFloat((params["cornerRadius"] as? NSNumber)?.doubleValue ?? 0)
		let tint = (params["tintColor"] as? NSNumber).map { Self.color(argb: $0.uint32Value) }

		effectView = UIVisualEffectView(effect: Self.makeEffect(tint: tint))
		effectView.frame = frame
		effectView.clipsToBounds = true
		effectView.layer.cornerRadius = cornerRadius
		effectView.layer.cornerCurve = .continuous
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
