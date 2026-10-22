/// A single tab's serialized configuration for the native method channel.
class NativeTabConfig {
  /// Creates a native tab configuration.
  const NativeTabConfig({
    required this.label,
    required this.symbol,
    String? selectedSymbol,
    this.badgeValue,
  }) : selectedSymbol = selectedSymbol ?? symbol;

  /// The tab's visible label.
  final String label;

  /// The icon used while the tab is not selected.
  ///
  /// An SF Symbol name, a bundle image name, or an absolute path to an image
  /// file on disk (anything starting with `/`).
  final String symbol;

  /// The icon used while the tab is selected. Same forms as [symbol].
  final String selectedSymbol;

  /// The native badge text, or null to hide the badge.
  final String? badgeValue;

  /// Serializes this tab without splitting its fields into parallel arrays.
  Map<String, String?> toMap() {
    return {
      'label': label,
      'symbol': symbol,
      'selectedSymbol': selectedSymbol,
      'badgeValue': badgeValue,
    };
  }
}

/// How the tab labels are drawn. Every field is optional; anything left null
/// keeps the system's own value.
class NativeTabLabelStyle {
  /// Creates a label style.
  const NativeTabLabelStyle({
    this.fontName,
    this.selectedFontName,
    this.fontSize,
    this.color,
    this.selectedColor,
    this.iconLabelGap,
    this.iconSize,
    this.letterSpacing,
  });

  /// PostScript name of the unselected label's font, e.g. `CircularStd-Book`.
  ///
  /// The font must be registered with UIKit — listed under `UIAppFonts` in the
  /// host's `Info.plist` and bundled with the Runner. A font declared only in
  /// `pubspec.yaml` is visible to Flutter, not to UIKit. An unknown name falls
  /// back to the system font.
  final String? fontName;

  /// PostScript name of the selected label's font. Defaults to [fontName].
  final String? selectedFontName;

  /// Point size of both labels. Defaults to the system tab bar's size.
  final double? fontSize;

  /// Unselected label colour, ARGB.
  final int? color;

  /// Selected label colour, ARGB. Defaults to the bar's tint colour.
  final int? selectedColor;

  /// Points between the icon box and the label. Defaults to 4.
  ///
  /// With any label style the bar draws icon and label together as one image,
  /// since the iOS 26 glass bar ignores title colours and offsets — so this
  /// gap, and both colours, are exactly what is drawn.
  final double? iconLabelGap;

  /// Side of the square box each icon is fitted into. Defaults to 28, the
  /// system tab bar's.
  final double? iconSize;

  /// Label tracking in points, as Flutter's `TextStyle.letterSpacing`.
  final double? letterSpacing;

  /// Serializes the style for the method channel.
  Map<String, Object?> toMap() => {
    'fontName': fontName,
    'selectedFontName': selectedFontName ?? fontName,
    'fontSize': fontSize,
    'color': color,
    'selectedColor': selectedColor,
    'iconLabelGap': iconLabelGap,
    'iconSize': iconSize,
    'letterSpacing': letterSpacing,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeTabLabelStyle &&
          fontName == other.fontName &&
          selectedFontName == other.selectedFontName &&
          fontSize == other.fontSize &&
          color == other.color &&
          selectedColor == other.selectedColor &&
          iconLabelGap == other.iconLabelGap &&
          iconSize == other.iconSize &&
          letterSpacing == other.letterSpacing;

  @override
  int get hashCode => Object.hash(
    fontName,
    selectedFontName,
    fontSize,
    color,
    selectedColor,
    iconLabelGap,
    iconSize,
    letterSpacing,
  );
}

/// Creates the complete argument payload sent to the native tab bar.
Map<String, Object?> createNativeTabBarParams({
  required Iterable<NativeTabConfig> tabs,
  required String? actionButtonSymbol,
  required int selectedIndex,
  required bool isDark,
  required int tintColor,
  NativeTabLabelStyle? labelStyle,
}) {
  return {
    'tabs': tabs.map((tab) => tab.toMap()).toList(growable: false),
    'actionButtonSymbol': actionButtonSymbol,
    'selectedIndex': selectedIndex,
    'isDark': isDark,
    'tintColor': tintColor,
    if (labelStyle != null) 'labelStyle': labelStyle.toMap(),
  };
}
