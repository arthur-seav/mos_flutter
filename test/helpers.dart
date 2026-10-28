import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/app.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/repository_providers.dart';

/// A mock backend as a provider override. Instant by default; pass a
/// [latency] to see loading states.
List<Override> mockOverrides({Duration latency = Duration.zero}) => [
  authRepositoryProvider.overrideWithValue(
    MockAuthRepository(latency: latency),
  ),
];

/// Starts the whole app with the mock backend, on a 412 x 917 screen
/// (the Figma frame size) instead of the default 800 x 600 test window.
///
/// Returns the [ProviderContainer] so tests can read the session.
Future<ProviderContainer> pumpMosApp(
  WidgetTester tester, {
  Duration latency = Duration.zero,
}) async {
  tester.view.physicalSize = const Size(412, 917);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer.test(
    overrides: mockOverrides(latency: latency),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MosApp()),
  );
  await tester.pumpAndSettle();
  return container;
}
