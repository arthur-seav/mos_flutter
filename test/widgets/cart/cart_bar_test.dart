import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/widgets/cart/cart_bar.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required int count,
    required Money total,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartBar(count: count, total: total, onTap: onTap ?? () {}),
        ),
      ),
    );
  }

  testWidgets('shows the plural item count and total', (tester) async {
    await pumpBar(tester, count: 2, total: Money.dollars(8.10));

    expect(find.text('2 items'), findsOneWidget);
    expect(find.text(r'$8.10'), findsOneWidget);
    expect(find.text('View cart'), findsOneWidget);
  });

  testWidgets('shows the singular item count', (tester) async {
    await pumpBar(tester, count: 1, total: Money.dollars(2));

    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('tapping the bar calls onTap', (tester) async {
    var tapped = false;
    await pumpBar(
      tester,
      count: 2,
      total: Money.dollars(8.10),
      onTap: () => tapped = true,
    );

    await tester.tap(find.byType(CartBar));
    expect(tapped, isTrue);
  });
}
