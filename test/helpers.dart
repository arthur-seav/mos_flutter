import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/app.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/drink_option.dart';
import 'package:mos_app/data/models/product_customization.dart';
import 'package:mos_app/data/repositories/menu_repository.dart';

/// Thursday 29 October 2026, 10:12 AM: the store (7 AM - 9 PM) is open,
/// so ASAP works and the first pickup slot is 10:20 (BR-07, 5 min lead).
DateTime testNow() => DateTime(2026, 10, 29, 10, 12);

/// The mock backend for tests: instant, at [testNow] unless [clock] is
/// given. Pass your own [menu] to change the drinks.
MockBackend testBackend({
  Duration latency = Duration.zero,
  DateTime Function()? clock,
  MenuRepository? menu,
  Duration? khqrPaysAfter = const Duration(seconds: 5),
}) => MockBackend(
  latency: latency,
  clock: clock ?? testNow,
  khqrPaysAfter: khqrPaysAfter,
  menu: menu is MockMenuRepository ? menu : null,
);

/// The demo menu, but no drink has a default size: the admin left
/// `default_option_id` empty (it is nullable). For TC-12, which the demo
/// menu cannot show because every drink has its defaults.
class NoDefaultSizeMenuRepository extends MockMenuRepository {
  NoDefaultSizeMenuRepository() : super(latency: Duration.zero);

  @override
  Future<ProductCustomization> fetchCustomization(int productId) async {
    final c = await super.fetchCustomization(productId);
    return ProductCustomization(
      product: c.product,
      groups: [
        for (final g in c.groups)
          g.group.name == 'Size'
              ? ProductOptionGroup(group: g.group, options: g.options)
              : g,
      ],
    );
  }
}

/// Starts the whole app with the mock backend, on a 412 x 917 screen
/// (the Figma frame size) instead of the default 800 x 600 test window.
///
/// Returns the [ProviderContainer] so tests can read the session.
Future<ProviderContainer> pumpMosApp(
  WidgetTester tester, {
  Duration latency = Duration.zero,
  MenuRepository? menu,
  MockBackend? backend,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = const Size(412, 917);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // ProviderScope owns the container, so it is disposed with the widget
  // tree at the end of the test, and with it any timer a provider runs
  // (the KHQR countdown).
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...(backend ?? testBackend(latency: latency, menu: menu)).overrides,
        ...extraOverrides,
      ],
      child: const MosApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MosApp)),
  );
  return container;
}

/// Taps "Continue as guest" on the login page and waits for Home.
Future<void> continueAsGuest(WidgetTester tester) async {
  await tester.tap(find.text('Continue as guest'));
  await tester.pumpAndSettle();
}
