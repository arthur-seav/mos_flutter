import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/app.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/features/auth/auth_controller.dart';

/// Starts the whole app with an instant (zero-latency) mock backend,
/// on a 412 x 917 screen (the Figma frame size) instead of the default
/// 800 x 600 test window.
Future<AuthController> pumpMosApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 917);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = AuthController(MockAuthRepository(latency: Duration.zero));
  await tester.pumpWidget(MosApp(authController: auth));
  await tester.pumpAndSettle();
  return auth;
}
