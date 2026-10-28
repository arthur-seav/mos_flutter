import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/widgets/common/count_badge.dart';

void main() {
  Future<void> pumpBadge(WidgetTester tester, int count) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CountBadge(count: count)),
      ),
    );
  }

  testWidgets('shows nothing for 0', (tester) async {
    await pumpBadge(tester, 0);

    expect(find.byType(CountBadge), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows the count below 10', (tester) async {
    await pumpBadge(tester, 3);

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('caps at "9+" for 10 and above', (tester) async {
    await pumpBadge(tester, 12);

    expect(find.text('9+'), findsOneWidget);
    expect(find.text('12'), findsNothing);
  });
}
