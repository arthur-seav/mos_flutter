import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  // Widget tests run as Android by default, where Material 3 would add a
  // StretchingOverscrollIndicator to every list.
  testWidgets('lists do not stretch when pulled past their end', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await continueAsGuest(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Menu'));
    await tester.pumpAndSettle();

    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
  });
}
