import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/account/support_info.dart';
import 'package:mos_app/theme/app_theme.dart';
import 'package:mos_app/widgets/account/help_support_sheet.dart';

import '../../helpers.dart';

/// A page with one button that opens the help panel, standing in for the
/// Profile page while that page is being built.
class _HelpHost extends StatelessWidget {
  const _HelpHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showHelpSupportSheet(context),
          child: const Text('Help & support'),
        ),
      ),
    );
  }
}

void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...testBackend().overrides, ...overrides],
        child: MaterialApp(theme: AppTheme.light, home: const _HelpHost()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();
  }

  testWidgets('the panel shows the store phone and the opening hours', (
    tester,
  ) async {
    await pumpHost(tester);
    await openSheet(tester);

    expect(find.text('Help & Support'), findsOneWidget);
    expect(
      find.text(
        'For a problem with an order, call the store and give your '
        'order number.',
      ),
      findsOneWidget,
    );
    expect(find.text('Store Phone'), findsOneWidget);
    expect(find.text('012 345 678'), findsOneWidget);
    expect(find.text('Working Hours'), findsOneWidget);
    expect(find.text('7:00 AM – 9:00 PM'), findsOneWidget);
  });

  testWidgets('Close puts the panel away', (tester) async {
    await pumpHost(tester);
    await openSheet(tester);
    expect(find.text('Help & Support'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Help & Support'), findsNothing);
    expect(find.text('012 345 678'), findsNothing);
    // Back on the page that opened it.
    expect(find.text('Help & support'), findsOneWidget);
  });

  testWidgets('a spinner is shown while the store details load', (
    tester,
  ) async {
    final pending = Completer<SupportInfo>();
    addTearDown(
      () => pending.complete(
        const SupportInfo(phone: '012 345 678', hours: 'Closed today'),
      ),
    );
    await pumpHost(
      tester,
      overrides: [supportInfoProvider.overrideWith((ref) => pending.future)],
    );
    // Not pumpAndSettle: the spinner never stops animating.
    await tester.tap(find.text('Help & support'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Store Phone'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('a failed load says so instead of showing empty details', (
    tester,
  ) async {
    await pumpHost(
      tester,
      overrides: [
        supportInfoProvider.overrideWith(
          (ref) => Future<SupportInfo>.error(
            StateError('store unavailable'),
            StackTrace.empty,
          ),
        ),
      ],
    );
    await openSheet(tester);

    expect(find.text('Could not load the store details.'), findsOneWidget);
    expect(find.text('Store Phone'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });
}
