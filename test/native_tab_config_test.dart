import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_glass_navbar/src/native_tab_config.dart';

void main() {
  test('uses the normal symbol when no selected symbol is configured', () {
    const config = NativeTabConfig(label: 'Home', symbol: 'house');

    expect(config.toMap(), {
      'label': 'Home',
      'symbol': 'house',
      'selectedSymbol': 'house',
      'badgeValue': null,
    });
  });

  test('keeps each tab configuration together in the channel payload', () {
    final params = createNativeTabBarParams(
      tabs: const [
        NativeTabConfig(
          label: 'Home',
          symbol: 'house',
          selectedSymbol: 'house.fill',
          badgeValue: '3',
        ),
        NativeTabConfig(label: 'Search', symbol: 'magnifyingglass'),
      ],
      actionButtonSymbol: null,
      selectedIndex: 0,
      isDark: false,
      tintColor: 0xFF007AFF,
    );

    expect(params, {
      'tabs': [
        {
          'label': 'Home',
          'symbol': 'house',
          'selectedSymbol': 'house.fill',
          'badgeValue': '3',
        },
        {
          'label': 'Search',
          'symbol': 'magnifyingglass',
          'selectedSymbol': 'magnifyingglass',
          'badgeValue': null,
        },
      ],
      'actionButtonSymbol': null,
      'selectedIndex': 0,
      'isDark': false,
      'tintColor': 0xFF007AFF,
    });
    expect(params, isNot(contains('labels')));
    expect(params, isNot(contains('symbols')));
    expect(params, isNot(contains('labelStyle')));
    final encoded = const StandardMessageCodec().encodeMessage(params);
    expect(const StandardMessageCodec().decodeMessage(encoded), params);
  });

  test('sends the label style, defaulting the selected font', () {
    final params = createNativeTabBarParams(
      tabs: const [NativeTabConfig(label: 'Home', symbol: 'house')],
      actionButtonSymbol: null,
      selectedIndex: 0,
      isDark: false,
      tintColor: 0xFF007AFF,
      labelStyle: const NativeTabLabelStyle(
        fontName: 'CircularStd-Book',
        fontSize: 11,
        color: 0x80000000,
        selectedColor: 0xCC000000,
      ),
    );

    expect(params['labelStyle'], {
      'fontName': 'CircularStd-Book',
      'selectedFontName': 'CircularStd-Book',
      'fontSize': 11.0,
      'color': 0x80000000,
      'selectedColor': 0xCC000000,
      'iconLabelGap': null,
      'iconSize': null,
      'letterSpacing': null,
    });
    final encoded = const StandardMessageCodec().encodeMessage(params);
    expect(const StandardMessageCodec().decodeMessage(encoded), params);
  });
}
