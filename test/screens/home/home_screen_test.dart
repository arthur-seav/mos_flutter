import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/screens/home/home_screen.dart';
import 'package:mos_app/screens/menu/customize_drink_screen.dart';
import 'package:mos_app/screens/menu/menu_screen.dart';
import 'package:mos_app/widgets/menu/category_chips.dart';
import 'package:mos_app/widgets/menu/product_card.dart';

import '../../helpers.dart';

void main() {
  testWidgets('a guest sees "Guest" and the popular drinks', (tester) async {
    await pumpMosApp(tester);
    await continueAsGuest(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Popular now'), findsOneWidget);
    expect(find.widgetWithText(ProductCard, 'Caramel Latte'), findsOneWidget);
  });

  testWidgets('a customer sees their first name', (tester) async {
    await pumpMosApp(tester);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'dara@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      MockAuthRepository.demoPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Dara'), findsOneWidget);
  });

  testWidgets('Home has no category chips (they live on Menu)', (tester) async {
    await pumpMosApp(tester);
    await continueAsGuest(tester);
    expect(find.byType(CategoryChips), findsNothing);
  });

  testWidgets('"See all" opens Menu on All', (tester) async {
    await pumpMosApp(tester);
    await continueAsGuest(tester);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(MenuScreen), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);
  });

  testWidgets('the search box opens Menu with search ready', (tester) async {
    await pumpMosApp(tester);
    await continueAsGuest(tester);

    await tester.tap(find.text('Search drinks'));
    await tester.pumpAndSettle();

    expect(find.byType(MenuScreen), findsOneWidget);
    expect(find.byTooltip('Close search'), findsOneWidget);
  });

  testWidgets('"+" opens the drink\'s options', (tester) async {
    await pumpMosApp(tester);
    await continueAsGuest(tester);

    await tester.tap(find.byTooltip('Add Caramel Latte'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomizeDrinkScreen), findsOneWidget);
    expect(find.text('Caramel Latte'), findsOneWidget);
  });
}
