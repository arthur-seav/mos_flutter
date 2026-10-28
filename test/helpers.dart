import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/app.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/repository_providers.dart';

/// An instant (zero-latency) mock backend, as a provider override.
List<Override> mockOverrides() => [
  authRepositoryProvider.overrideWithValue(
    MockAuthRepository(latency: Duration.zero),
  ),
];

/// Starts the whole app with the mock backend, on a 412 x 917 screen
/// (the Figma frame size) instead of the default 800 x 600 test window.
///
/// Returns the [ProviderContainer] so tests can read the session.
Future<ProviderContainer> pumpMosApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 917);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer.test(overrides: mockOverrides());
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MosApp()),
  );
  await tester.pumpAndSettle();
  return container;
}
