import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/drink_option.dart';
import 'package:mos_app/data/models/drink_selection.dart';
import 'package:mos_app/data/models/money.dart';

void main() {
  final repo = MockMenuRepository(latency: Duration.zero);
  const espresso = 1, americano = 2, caramelLatte = 4, latte = 18;
  const caramelFrappe = 11;

  Future<DrinkSelection> open(int productId) async =>
      DrinkSelection.initial(await repo.fetchCustomization(productId));

  ProductOptionGroup group(DrinkSelection s, String name) =>
      s.customization.groups.firstWhere((g) => g.group.name == name);

  DrinkOption option(DrinkSelection s, String groupName, String name) =>
      group(s, groupName).options.firstWhere((o) => o.name == name);

  DrinkSelection pick(DrinkSelection s, String groupName, String name) =>
      s.choose(group(s, groupName), option(s, groupName, name));

  List<String> visible(DrinkSelection s) =>
      s.visibleGroups.map((g) => g.group.name).toList();

  test('TC-10: Espresso has no ice level and is hot only', () async {
    final s = await open(espresso);
    expect(visible(s), isNot(contains('Ice level')));
    final temperature = group(s, 'Temperature');
    expect(temperature.options.map((o) => o.name), ['Hot']);
    expect(s.isChosen(temperature, temperature.options.single), isTrue);
  });

  test('TC-11: Caramel Latte opens with the admin defaults', () async {
    final s = await open(caramelLatte);
    expect(s.chosenOptions.map((o) => o.name), [
      'Medium',
      'Iced',
      'Less',
      'Regular',
    ]);
  });

  test('BR-01: ice level only shows for an iced drink', () async {
    var s = await open(caramelLatte);
    expect(visible(s), contains('Ice level'));

    s = pick(s, 'Temperature', 'Hot');
    expect(visible(s), isNot(contains('Ice level')));
    expect(s.chosenOptions.map((o) => o.name), isNot(contains('Less')));

    s = pick(s, 'Temperature', 'Iced');
    expect(s.chosenOptions.map((o) => o.name), contains('Less'));
  });

  test('always-cold drinks show ice level without a temperature', () async {
    final s = await open(caramelFrappe);
    expect(visible(s), ['Size', 'Ice level', 'Sweetness', 'Add-ons']);
  });

  test('TC-12: a required group with no default is missing', () async {
    final s = await open(americano);
    expect(s.missingRequired.map((g) => g.group.name), ['Size']);
    expect(pick(s, 'Size', 'Small').missingRequired, isEmpty);
  });

  test(
    'a required single choice cannot be cleared by tapping it again',
    () async {
      final s = await open(caramelLatte);
      final again = pick(s, 'Size', 'Medium');
      expect(again.missingRequired, isEmpty);
    },
  );

  test('TC-13: no more than 3 add-ons', () async {
    var s = await open(caramelLatte);
    for (final name in ['Oat milk', 'Extra shot', 'Vanilla syrup']) {
      s = pick(s, 'Add-ons', name);
    }
    final addOns = group(s, 'Add-ons');
    final fourth = option(s, 'Add-ons', 'Whipped cream');
    expect(s.canChoose(addOns, fourth), isFalse);
    expect(s.choose(addOns, fourth).chosen[addOns.group.id]!.length, 3);

    // Taking one off makes room again.
    s = pick(s, 'Add-ons', 'Oat milk');
    expect(s.canChoose(addOns, fourth), isTrue);
  });

  test('TC-14: Latte, Large + Oat milk, quantity 2 is \$9.20', () async {
    var s = await open(latte);
    expect(s.customization.product.basePrice, Money.dollars(3));
    s = pick(s, 'Size', 'Large');
    expect(s.unitPrice, Money.dollars(4));
    s = pick(s, 'Add-ons', 'Oat milk');
    expect(s.unitPrice, Money.dollars(4.6));
    s = s.withQuantity(2);
    expect(s.total, Money.dollars(9.2));
  });

  test(
    'TC-15: Large is +\$0.50 for Americano, not the Latte\'s +\$1.00',
    () async {
      var s = await open(americano);
      s = pick(s, 'Size', 'Large');
      expect(option(s, 'Size', 'Large').label, r'Large +$0.50');
      expect(s.unitPrice, Money.dollars(3));
    },
  );

  test('cart lines say which group a short name belongs to', () async {
    var s = await open(caramelLatte);
    expect(
      s.toCartItem().optionSummary,
      'Medium · Iced · Less ice · Regular sugar',
    );
    s = pick(s, 'Sweetness', 'No sugar');
    expect(s.toCartItem().optionSummary, 'Medium · Iced · Less ice · No sugar');
  });

  test('"Edit options" starts from the cart line', () async {
    var s = await open(caramelLatte);
    s = pick(s, 'Temperature', 'Hot');
    s = pick(s, 'Add-ons', 'Oat milk').withQuantity(2);
    final line = s.toCartItem();

    final edit = DrinkSelection.fromCartItem(s.customization, line);
    expect(edit.chosenOptions.map((o) => o.name), [
      'Medium',
      'Hot',
      'Regular',
      'Oat milk',
    ]);
    expect(edit.quantity, 2);
    // Ice level was hidden; back to Iced, it shows its default again.
    expect(
      pick(edit, 'Temperature', 'Iced').chosenOptions.map((o) => o.name),
      contains('Less'),
    );
  });

  test('Espresso: shots, double by default; a single is cheaper', () async {
    var s = await open(espresso);
    expect(visible(s), ['Shots', 'Temperature', 'Sweetness', 'Add-ons']);
    expect(s.unitPrice, Money.dollars(2));
    s = pick(s, 'Shots', 'Single');
    expect(s.unitPrice, Money.dollars(1.5));
    s = pick(s, 'Shots', 'Triple');
    s = pick(s, 'Add-ons', 'Extra shot');
    expect(s.unitPrice, Money.dollars(3));
    expect(
      s.toCartItem().optionSummary,
      'Triple shot · Hot · No sugar · Extra shot',
    );
  });

  test('size labels are relative to the current choice', () async {
    var s = await open(latte);
    String labels(String g) =>
        group(s, g).options.map((o) => s.labelOf(group(s, g), o)).join(', ');
    expect(labels('Size'), r'Small -$0.50, Medium +$0.00, Large +$0.50');
    s = pick(s, 'Size', 'Large');
    expect(labels('Size'), r'Small -$1.00, Medium -$0.50, Large +$0.00');
    expect(labels('Temperature'), 'Hot, Iced');
    expect(labels('Add-ons'), startsWith(r'Oat milk +$0.60'));

    // Nothing chosen yet (TC-12): the stored prices.
    final americano = await open(2);
    final size = group(americano, 'Size');
    expect(
      size.options.map((o) => americano.labelOf(size, o)).join(', '),
      r'Small, Medium +$0.50, Large +$0.50',
    );
  });

  test('quantity stays between 1 and 20', () async {
    final s = await open(latte);
    expect(s.withQuantity(0).quantity, 1);
    expect(s.withQuantity(99).quantity, DrinkSelection.maxQuantity);
  });

  test('the cart line copies options and price', () async {
    var s = await open(latte);
    s = pick(s, 'Size', 'Large').withQuantity(2);
    final item = s.toCartItem();
    expect(item.optionSummary, 'Large · Hot · Regular sugar');
    expect(item.lineTotal, Money.dollars(8));
  });
}
