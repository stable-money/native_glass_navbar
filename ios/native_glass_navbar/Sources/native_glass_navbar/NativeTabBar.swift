import Flutter
import UIKit

class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
	private var messenger: FlutterBinaryMessenger

	init(messenger: FlutterBinaryMessenger) {
		self.messenger = messenger
		super.init()
	}

	func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
		-> FlutterPlatformView
	{
		return NativeTabBarPlatformView(
			frame: frame,
			viewId: viewId,
			args: args,
			messenger: messenger
		)
	}

	func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
		return FlutterStandardMessageCodec.sharedInstance()
	}
}

class NativeTabBarPlatformView: NSObject, FlutterPlatformView {
	private let controller: LiquidGlassTabBarController

	init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
		self.controller = LiquidGlassTabBarController(
			viewId: viewId,
			messenger: messenger,
			args: args
		)
		super.init()
	}

	func view() -> UIView {
		return controller.view
	}
}

struct NativeTabConfig: Equatable {
	let label: String
	let symbol: String
	let selectedSymbol: String
	let badgeValue: String?

	init(from dict: [String: Any]) {
		self.label = dict["label"] as? String ?? ""
		self.symbol = dict["symbol"] as? String ?? "questionmark"
		self.selectedSymbol = dict["selectedSymbol"] as? String ?? self.symbol
		self.badgeValue = dict["badgeValue"] as? String
	}
}

/// Font, size, colours and spacing of the tab labels.
///
/// When a host supplies one, the bar draws each tab's icon and label together
/// into a single image instead of using UIKit's own title. The iOS 26 glass
/// bar keeps a custom font but ignores title colours and position
/// adjustments — it draws every label in its own vibrant black — so this is
/// the only way the colours and the icon-to-label gap actually take effect.
struct TabLabelStyle: Equatable {
	var fontName: String?
	var selectedFontName: String?
	var fontSize: CGFloat?
	var colorARGB: Int?
	var selectedColorARGB: Int?
	var iconLabelGap: CGFloat
	/// Side of the square box each icon is fitted into.
	var iconSize: CGFloat
	/// Tracking, in points, like Flutter's `letterSpacing`.
	var letterSpacing: CGFloat?

	init?(from dict: [String: Any]?) {
		guard let dict = dict else { return nil }
		func number(_ key: String) -> CGFloat? {
			(dict[key] as? NSNumber).map { CGFloat($0.doubleValue) }
		}
		fontName = dict["fontName"] as? String
		selectedFontName = dict["selectedFontName"] as? String
		fontSize = number("fontSize")
		colorARGB = (dict["color"] as? NSNumber)?.intValue
		selectedColorARGB = (dict["selectedColor"] as? NSNumber)?.intValue
		iconLabelGap = number("iconLabelGap") ?? 4
		iconSize = number("iconSize") ?? 28
		letterSpacing = number("letterSpacing")
	}

	func color(selected: Bool, tint: UIColor) -> UIColor {
		guard let argb = selected ? selectedColorARGB : colorARGB else {
			return selected ? tint : .secondaryLabel
		}
		return TabBarConfig.uiColorFromARGB(argb)
	}

	/// Text attributes for one label state. An unregistered font name falls
	/// back to the system font at the requested size rather than to no label.
	func attributes(selected: Bool, tint: UIColor) -> [NSAttributedString.Key: Any] {
		let size = fontSize ?? 10
		let name = selected ? (selectedFontName ?? fontName) : fontName
		let font = name.flatMap { UIFont(name: $0, size: size) } ?? .systemFont(ofSize: size)
		var attributes: [NSAttributedString.Key: Any] = [
			.font: font, .foregroundColor: color(selected: selected, tint: tint),
		]
		if let letterSpacing = letterSpacing {
			attributes[.kern] = letterSpacing
		}
		return attributes
	}
}

struct TabBarConfig: Equatable {
	var tabs: [NativeTabConfig] = []
	var actionButtonSymbol: String = ""  // Default to empty
	var tintColor: UIColor = .systemBlue
	var tintColorARGB: Int = 0xFF007AFF
	var selectedIndex: Int = 0
	var isDark: Bool = false
	var labelStyle: TabLabelStyle?

	var standardItemCount: Int {
		return tabs.count
	}

	var hasActionButton: Bool {
		return !actionButtonSymbol.isEmpty
	}

	init(from dict: [String: Any]?) {
		guard let dict = dict else { return }
		if let tabs = dict["tabs"] as? [[String: Any]] {
			self.tabs = tabs.map(NativeTabConfig.init)
		}

		if let action = dict["actionButtonSymbol"] as? String {
			self.actionButtonSymbol = action
		}

		if let colorInt = dict["tintColor"] as? NSNumber {
			self.tintColorARGB = colorInt.intValue
			self.tintColor = TabBarConfig.uiColorFromARGB(tintColorARGB)
		}
		if let idx = dict["selectedIndex"] as? Int {
			self.selectedIndex = idx
		}
		if let isDark = dict["isDark"] as? Bool {
			self.isDark = isDark
		}
		self.labelStyle = TabLabelStyle(from: dict["labelStyle"] as? [String: Any])
	}

	func structuralChange(from other: TabBarConfig) -> Bool {
		return standardItemCount != other.standardItemCount
			|| hasActionButton != other.hasActionButton
			// Every tab image is drawn from the style, so a new one redraws all.
			|| labelStyle != other.labelStyle
			|| tintColorARGB != other.tintColorARGB
	}

	static func == (lhs: TabBarConfig, rhs: TabBarConfig) -> Bool {
		return lhs.tabs == rhs.tabs
			&& lhs.actionButtonSymbol == rhs.actionButtonSymbol
			&& lhs.tintColorARGB == rhs.tintColorARGB
			&& lhs.selectedIndex == rhs.selectedIndex
			&& lhs.isDark == rhs.isDark
			&& lhs.labelStyle == rhs.labelStyle
	}

	static func uiColorFromARGB(_ argb: Int) -> UIColor {
		let a = CGFloat((argb >> 24) & 0xFF) / 255.0
		let r = CGFloat((argb >> 16) & 0xFF) / 255.0
		let g = CGFloat((argb >> 8) & 0xFF) / 255.0
		let b = CGFloat(argb & 0xFF) / 255.0
		return UIColor(red: r, green: g, blue: b, alpha: a)
	}
}

class LiquidGlassTabBarController: UITabBarController, UITabBarControllerDelegate {
	private static let actionTabIdentifier = "native_glass_navbar.action"

	private let channel: FlutterMethodChannel
	private var config: TabBarConfig
	private var currentAppearanceIsDark: Bool
	private var currentTintColorARGB: Int
	private var currentLabelStyle: TabLabelStyle?

	init(viewId: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
		self.channel = FlutterMethodChannel(
			name: "NativeTabBar_\(viewId)",
			binaryMessenger: messenger
		)
		self.config = TabBarConfig(from: args as? [String: Any])
		self.currentAppearanceIsDark = config.isDark
		self.currentTintColorARGB = config.tintColorARGB
		self.currentLabelStyle = config.labelStyle
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		self.view.backgroundColor = .clear
		self.view.isOpaque = false
		self.delegate = self
		overrideUserInterfaceStyle = config.isDark ? .dark : .light

		configureAppearance()
		performFullRebuild()

		channel.setMethodCallHandler { [weak self] call, result in
			self?.handle(call, result: result)
		}
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		self.view.backgroundColor = .clear
		// This runs before the tab bar lays out its own subviews, so the
		// capsule may not exist or be sized yet. Look again once the pass has
		// finished, and a few times after while UIKit settles the glass in.
		reportCapsuleFrame()
		for delay in [0.0, 0.1, 0.3, 0.8] {
			DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
				self?.reportCapsuleFrame()
			}
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		reportCapsuleFrame()
	}

	/// The last capsule frame sent to Flutter, so a layout pass that moves
	/// nothing sends nothing. Starts as a sentinel so the first result, even
	/// "none found", always reaches Flutter.
	private var lastCapsuleFrame: CGRect? = .infinite

	/// Tells Flutter where the glass capsule is, in this view's coordinates
	/// (the same as the Flutter platform view's), so the host can draw around
	/// it — a shadow, say. UIKit has no public API for the capsule, so it is
	/// found by shape; see `findCapsuleFrame`.
	///
	/// When nothing matches, the view tree it searched goes along too, so the
	/// host can log why rather than silently drawing nothing.
	private func reportCapsuleFrame() {
		let frame = findCapsuleFrame()
		guard frame != lastCapsuleFrame else { return }
		lastCapsuleFrame = frame
		var arguments: [String: Any] = [:]
		if let frame = frame {
			arguments = ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
		} else {
			arguments["hierarchy"] = describeHierarchy()
		}
		channel.invokeMethod("capsuleFrame", arguments: arguments)
	}

	/// The largest capsule-proportioned view in the bar — the tab bar itself
	/// included — that is narrower than the whole platform view. On iOS 26
	/// that is the floating glass: either `tabBar` itself, inset by UIKit, or
	/// the platter inside it. The selected tab's highlight is capsule-shaped
	/// too, but always smaller. Without a floating bar nothing matches.
	private func findCapsuleFrame() -> CGRect? {
		let fullWidth = view.bounds.width
		guard fullWidth > 0 else { return nil }
		var best: CGRect?

		func consider(_ candidate: UIView) {
			guard !candidate.isHidden, candidate.alpha > 0.01 else { return }
			let frame = candidate.convert(candidate.bounds, to: view)
			let isCapsule =
				frame.width < fullWidth - 1
				&& frame.height >= 40
				&& frame.height <= 120
				&& frame.width >= frame.height * 2
			if isCapsule, frame.width * frame.height > (best.map { $0.width * $0.height } ?? 0) {
				best = frame
			}
			for child in candidate.subviews {
				consider(child)
			}
		}
		consider(tabBar)
		return best
	}

	/// The tab bar's view tree, three levels deep, with each frame in this
	/// view's coordinates — for diagnosing a capsule that was not found.
	private func describeHierarchy() -> String {
		var lines = ["root \(view.bounds)"]
		func walk(_ v: UIView, _ depth: Int) {
			let frame = v.convert(v.bounds, to: view)
			let flags = (v.isHidden ? " hidden" : "") + (v.alpha < 0.01 ? " transparent" : "")
			lines.append(
				String(repeating: "  ", count: depth)
					+ "\(type(of: v)) \(frame.integral) r=\(v.layer.cornerRadius)\(flags)"
			)
			if depth < 3 {
				v.subviews.forEach { walk($0, depth + 1) }
			}
		}
		walk(tabBar, 0)
		return lines.joined(separator: "\n")
	}

	private func configureAppearance() {
		let appearance = UITabBarAppearance()
		appearance.configureWithDefaultBackground()
		appearance.backgroundColor = .clear
		appearance.shadowColor = .clear

		// On iOS 26 the *default* background already is Liquid Glass. Assigning
		// a UIBlurEffect replaces it with the pre-26 frosted blur, which over
		// light content reads as flat and opaque — exactly what this package
		// exists to avoid. Only supply an explicit blur on older systems, where
		// there is no glass to preserve.
		if #unavailable(iOS 26.0) {
			appearance.backgroundEffect = UIBlurEffect(
				style: config.isDark ? .dark : .light
			)
		}

		let itemAppearance = UITabBarItemAppearance()
		// Deliberately no `iconColor` here. Setting it tints every icon as a
		// template, which flattens full-colour artwork to a silhouette. SF
		// Symbols still follow `tabBar.tintColor` when selected and the system
		// grey otherwise, while images loaded `.alwaysOriginal` keep their own
		// colours — which is what a host passing custom artwork wants.
		//
		// With a host label style the labels are drawn into the tab images
		// instead (see `tabImage`), so there is nothing to set here.

		appearance.stackedLayoutAppearance = itemAppearance
		appearance.inlineLayoutAppearance = itemAppearance
		appearance.compactInlineLayoutAppearance = itemAppearance

		tabBar.standardAppearance = appearance
		if #available(iOS 15.0, *) {
			tabBar.scrollEdgeAppearance = appearance
		}

		tabBar.isTranslucent = true
		tabBar.tintColor = config.tintColor
	}

	private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
		if call.method == "update", let dict = call.arguments as? [String: Any] {
			let newConfig = TabBarConfig(from: dict)
			let oldConfig = self.config

			if newConfig == oldConfig {
				result(nil)
				return
			}

			if newConfig.structuralChange(from: oldConfig) {
				self.config = newConfig
				performFullRebuild()  // Destructive
			} else {
				// 2. Light Updates (In-Place)
				self.config = newConfig

				updateTabItemsInPlace(from: oldConfig)
				updateSelectionAndColors()
			}

			result(nil)
		} else {
			result(FlutterMethodNotImplemented)
		}
	}

	private func updateTabItemsInPlace(from oldConfig: TabBarConfig) {
		if #available(iOS 27.0, *) {
			updateModernTabsInPlace(from: oldConfig)
			return
		}

		guard let vcs = self.viewControllers else { return }

		for i in 0..<config.standardItemCount {
			guard i < vcs.count, let item = vcs[i].tabBarItem else { continue }
			let labelChanged = label(at: i, in: config) != label(at: i, in: oldConfig)

			if labelChanged {
				item.title = tabTitle(at: i)
				item.accessibilityLabel = label(at: i, in: config)
			}

			if labelChanged || symbol(at: i, in: config) != symbol(at: i, in: oldConfig) {
				item.image = tabImage(at: i, selected: false)
			}

			if labelChanged || config.tabs[i].selectedSymbol != oldConfig.tabs[i].selectedSymbol {
				item.selectedImage = tabImage(at: i, selected: true)
			}

			if config.tabs[i].badgeValue != oldConfig.tabs[i].badgeValue {
				item.badgeValue = config.tabs[i].badgeValue
			}
		}

		if oldConfig.actionButtonSymbol != config.actionButtonSymbol,
			let actionVC = vcs.first(where: { $0.tabBarItem.tag == 99 })
		{
			actionVC.tabBarItem.image = resolveSymbol(config.actionButtonSymbol)
		}
	}

	@available(iOS 27.0, *)
	private func updateModernTabsInPlace(from oldConfig: TabBarConfig) {
		performBatchUpdates {
			for i in 0..<config.standardItemCount {
				guard let tab = tab(forIdentifier: tabIdentifier(at: i)) else { continue }
				let labelChanged = label(at: i, in: config) != label(at: i, in: oldConfig)

				if labelChanged {
					tab.title = tabTitle(at: i)
				}

				if labelChanged || symbol(at: i, in: config) != symbol(at: i, in: oldConfig) {
					tab.image = tabImage(at: i, selected: false)
				}

				if labelChanged || config.tabs[i].selectedSymbol != oldConfig.tabs[i].selectedSymbol {
					tab.selectedImage = tabImage(at: i, selected: true)
				}

				if config.tabs[i].badgeValue != oldConfig.tabs[i].badgeValue {
					tab.badgeValue = config.tabs[i].badgeValue
				}
			}

			if oldConfig.actionButtonSymbol != config.actionButtonSymbol,
				let actionTab = tab(forIdentifier: Self.actionTabIdentifier)
			{
				actionTab.image = resolveSymbol(config.actionButtonSymbol)
			}
		}
	}

	private func label(at index: Int, in config: TabBarConfig) -> String {
		return config.tabs[index].label
	}

	private func symbol(at index: Int, in config: TabBarConfig) -> String {
		return config.tabs[index].symbol
	}

	private func tabIdentifier(at index: Int) -> String {
		return "native_glass_navbar.tab.\(index)"
	}

	/// UIKit's title for a tab: empty when the label is drawn into the image,
	/// so it is not shown twice. VoiceOver reads `accessibilityLabel` instead.
	private func tabTitle(at index: Int) -> String {
		return config.labelStyle == nil ? label(at: index, in: config) : ""
	}

	/// A tab's image for one state: the bare icon, or — with a host label
	/// style — the icon with its label drawn beneath it.
	private func tabImage(at index: Int, selected: Bool) -> UIImage? {
		let tab = config.tabs[index]
		let name = selected ? tab.selectedSymbol : tab.symbol
		guard let style = config.labelStyle else { return resolveSymbol(name) }
		let icon = resolveSymbol(name, side: style.iconSize)
		return Self.iconWithLabel(
			icon: icon,
			label: tab.label,
			style: style,
			selected: selected,
			tint: config.tintColor
		)
	}

	/// Draws `icon` in the standard icon box with `label` centred beneath it,
	/// `style.iconLabelGap` apart, as one `.alwaysOriginal` image so UIKit
	/// shows the label's font and colour exactly as given. SF Symbols, being
	/// templates, are coloured like the label beside them.
	private static func iconWithLabel(
		icon: UIImage?,
		label: String,
		style: TabLabelStyle,
		selected: Bool,
		tint: UIColor
	) -> UIImage {
		let attributes = style.attributes(selected: selected, tint: tint)
		let text = label as NSString
		let textSize = text.size(withAttributes: attributes)
		let side = style.iconSize
		let size = CGSize(
			width: ceil(max(side, textSize.width)),
			height: ceil(side + style.iconLabelGap + textSize.height)
		)

		let renderer = UIGraphicsImageRenderer(size: size)
		let image = renderer.image { _ in
			if var icon = icon {
				if icon.renderingMode != .alwaysOriginal {
					icon = icon.withTintColor(
						style.color(selected: selected, tint: tint),
						renderingMode: .alwaysOriginal
					)
				}
				let iconSize = icon.size
				icon.draw(
					in: CGRect(
						x: (size.width - iconSize.width) / 2,
						y: (side - iconSize.height) / 2,
						width: iconSize.width,
						height: iconSize.height
					)
				)
			}
			text.draw(
				at: CGPoint(
					x: (size.width - textSize.width) / 2,
					y: side + style.iconLabelGap
				),
				withAttributes: attributes
			)
		}
		return image.withRenderingMode(.alwaysOriginal)
	}

	private func performFullRebuild() {
		if #available(iOS 27.0, *) {
			performModernFullRebuild()
			return
		}

		var controllers: [UIViewController] = []
		let count = config.standardItemCount

		// Standard Tabs
		for i in 0..<count {
			let dummyVC = UIViewController()
			dummyVC.view.backgroundColor = .clear

			let item = UITabBarItem(
				title: tabTitle(at: i),
				image: tabImage(at: i, selected: false),
				selectedImage: tabImage(at: i, selected: true)
			)
			item.accessibilityLabel = label(at: i, in: config)
			item.tag = i
			item.badgeValue = config.tabs[i].badgeValue
			dummyVC.tabBarItem = item
			controllers.append(dummyVC)
		}

		// Action Button
		if !config.actionButtonSymbol.isEmpty {
			let actionVC = UIViewController()
			actionVC.view.backgroundColor = .clear

			let item = UITabBarItem(tabBarSystemItem: .search, tag: 99)
			item.image = resolveSymbol(config.actionButtonSymbol)

			actionVC.tabBarItem = item
			controllers.append(actionVC)
		}

		self.setViewControllers(controllers, animated: false)
		updateSelectionAndColors()
	}

	@available(iOS 27.0, *)
	private func performModernFullRebuild() {
		var newTabs: [UITab] = []

		for i in 0..<config.standardItemCount {
			let tab = UITab(
				title: tabTitle(at: i),
				image: tabImage(at: i, selected: false),
				identifier: tabIdentifier(at: i)
			) { _ in
				let viewController = UIViewController()
				viewController.view.backgroundColor = .clear
				return viewController
			}
			tab.selectedImage = tabImage(at: i, selected: true)
			tab.badgeValue = config.tabs[i].badgeValue
			tab.userInfo = i
			newTabs.append(tab)
		}

		if config.hasActionButton {
			let actionTab = UITab(
				title: "",
				image: resolveSymbol(config.actionButtonSymbol),
				identifier: Self.actionTabIdentifier
			) { _ in
				let viewController = UIViewController()
				viewController.view.backgroundColor = .clear
				return viewController
			}
			actionTab.preferredPlacement = .pinned
			newTabs.append(actionTab)
		}

		setTabs(newTabs, animated: false)
		prominentTabIdentifier = config.hasActionButton ? Self.actionTabIdentifier : nil
		updateSelectionAndColors()
	}

	private func updateSelectionAndColors() {
		let needsAppearanceUpdate =
			currentTintColorARGB != config.tintColorARGB
			|| currentAppearanceIsDark != config.isDark
			|| currentLabelStyle != config.labelStyle

		if needsAppearanceUpdate {
			tabBar.tintColor = config.tintColor
			currentTintColorARGB = config.tintColorARGB
			currentAppearanceIsDark = config.isDark
			currentLabelStyle = config.labelStyle
			overrideUserInterfaceStyle = config.isDark ? .dark : .light
			configureAppearance()
		}

		if #available(iOS 27.0, *) {
			guard config.selectedIndex >= 0,
				config.selectedIndex < config.standardItemCount,
				let requestedTab = tab(forIdentifier: tabIdentifier(at: config.selectedIndex))
			else { return }

			if selectedTab?.identifier != requestedTab.identifier {
				selectedTab = requestedTab
			}
			return
		}

		if self.selectedIndex != config.selectedIndex {
			if let vcs = self.viewControllers,
				config.selectedIndex >= 0,
				config.selectedIndex < vcs.count,
				vcs[config.selectedIndex].tabBarItem.tag != 99
			{
				self.selectedIndex = config.selectedIndex
			}
		}
	}
    
    /// Resolves a tab icon.
    ///
    /// Accepts, in order: an absolute path to an image file on disk, an SF
    /// Symbol name, or the name of an image in the host app's bundle.
    ///
    /// The file-path form exists for apps whose tab icons are not known at
    /// build time — server-driven navigation, remote theming, A/B tested
    /// artwork. Those icons cannot be SF Symbols and are not in the bundle, so
    /// the host downloads them, caches them, and passes the local path here.
    /// Icons loaded this way keep their own colours (`.alwaysOriginal`) rather
    /// than being tinted as a template, since they are usually full-colour
    /// artwork rather than monochrome glyphs.
    private func resolveSymbol(_ name: String, side: CGFloat = tabIconSide) -> UIImage? {
        if name.hasPrefix("/") {
            guard let raw = UIImage(contentsOfFile: name) else {
                // A path that does not resolve is better rendered as the
                // placeholder glyph than as a blank tab.
                return nil
            }
            return Self.fittedToTabBarIcon(raw, side: side).withRenderingMode(.alwaysOriginal)
        }
        return UIImage(systemName: name) ?? UIImage(named: name)
    }

    /// Point size of a tab bar icon. Matches what SF Symbols resolve to in a
    /// `UITabBar`, so symbol and file-backed icons sit at the same size.
    private static let tabIconSide: CGFloat = 28

    /// Redraws `image` to fit the tab bar's icon box, preserving aspect ratio.
    ///
    /// `UIImage(contentsOfFile:)` has no scale parameter and always loads at
    /// scale 1.0, so a 96px asset is treated as 96 *points* and renders about
    /// three times too large on a 3x screen. Bundle images and SF Symbols never
    /// hit this because the loader infers their scale; a bare file cannot.
    /// `UIGraphicsImageRenderer` draws at the current display scale, so the
    /// result is correct on 2x and 3x alike.
    private static func fittedToTabBarIcon(_ image: UIImage, side: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let aspect = size.width / size.height
        let target = aspect >= 1
            ? CGSize(width: side, height: side / aspect)
            : CGSize(width: side * aspect, height: side)

        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

	// MARK: - Delegate
	func tabBarController(
		_ tabBarController: UITabBarController,
		shouldSelect viewController: UIViewController
	) -> Bool {
		if viewController.tabBarItem.tag == 99 {
			channel.invokeMethod("actionButtonPressed", arguments: nil)
			return false
		}
		return true
	}

	func tabBarController(
		_ tabBarController: UITabBarController,
		didSelect viewController: UIViewController
	) {
		let tag = viewController.tabBarItem.tag
		if tag != 99 {
			config.selectedIndex = tag
			channel.invokeMethod("valueChanged", arguments: ["index": tag])
		}
	}

	@available(iOS 18.0, *)
	func tabBarController(
		_ tabBarController: UITabBarController,
		shouldSelectTab tab: UITab
	) -> Bool {
		if tab.identifier == Self.actionTabIdentifier {
			channel.invokeMethod("actionButtonPressed", arguments: nil)
			return false
		}
		return true
	}

	@available(iOS 18.0, *)
	func tabBarController(
		_ tabBarController: UITabBarController,
		didSelectTab selectedTab: UITab,
		previousTab: UITab?
	) {
		guard let index = selectedTab.userInfo as? Int else { return }
		config.selectedIndex = index
		channel.invokeMethod("valueChanged", arguments: ["index": index])
	}
}
