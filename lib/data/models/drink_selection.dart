import 'package:flutter/foundation.dart' show immutable;

import 'cart_item.dart';
import 'drink_option.dart';
import 'money.dart';
import 'product_customization.dart';

/// What the customer has picked so far on the customization page, and the
/// rules that apply to it (BR-01, BR-02, BR-03). Immutable: every change
/// returns a new selection.
@immutable
class DrinkSelection {
  const DrinkSelection._({
    required this.customization,
    required this.chosen,
    required this.quantity,
    this.showMissing = false,
  });

  /// TC-11: starts with each group's default option.
  factory DrinkSelection.initial(ProductCustomization customization) {
    return DrinkSelection._(
      customization: customization,
      chosen: {
        for (final g in customization.groups) g.group.id: [?g.defaultOptionId],
      },
      quantity: 1,
    );
  }

  /// "Edit options" from the cart: starts with the line's options and
  /// quantity. Groups the line has nothing for (e.g. ice level of a hot
  /// drink) keep their defaults. Prices come from [customization], so an
  /// edited line gets today's prices.
  factory DrinkSelection.fromCartItem(
    ProductCustomization customization,
    CartItem item,
  ) => DrinkSelection.fromOptionIds(customization, [
    for (final o in item.options) o.id,
  ], quantity: item.quantity);

  /// "Reorder" (TC-28): a past order's options on today's menu. Options
  /// the drink no longer offers are dropped; their groups keep today's
  /// defaults.
  factory DrinkSelection.fromOptionIds(
    ProductCustomization customization,
    List<int> optionIds, {
    int quantity = 1,
  }) {
    final initial = DrinkSelection.initial(customization);
    final chosen = Map.of(initial.chosen);
    for (final g in customization.groups) {
      final ids = [
        for (final id in optionIds)
          if (g.optionById(id) != null) id,
      ];
      if (ids.isNotEmpty) chosen[g.group.id] = ids;
    }
    return DrinkSelection._(
      customization: customization,
      chosen: chosen,
      quantity: quantity.clamp(1, maxQuantity),
    );
  }

  /// The most of one drink in one cart line.
  static const maxQuantity = 20;

  final ProductCustomization customization;

  /// Option ids per group id, in the order they were picked.
  final Map<int, List<int>> chosen;
  final int quantity;

  /// Set after "Add to cart" with a required group still empty, so the page
  /// can mark it (TC-12). Cleared by the next choice.
  final bool showMissing;

  bool isChosen(ProductOptionGroup group, DrinkOption option) =>
      chosen[group.group.id]?.contains(option.id) ?? false;

  /// BR-01: the ice level group disappears while a hot drink is chosen.
  bool isVisible(ProductOptionGroup group) {
    if (!group.group.needsIcedDrink) return true;
    for (final g in customization.groups) {
      final temperatures = g.options.where((o) => o.isIced);
      if (temperatures.isEmpty) continue;
      // This is the temperature group: ice only for the iced choice.
      return chosen[g.group.id]?.any(
            (id) => g.optionById(id)?.isIced ?? false,
          ) ??
          false;
    }
    // No temperature choice at all (e.g. frappés are always iced).
    return true;
  }

  List<ProductOptionGroup> get visibleGroups =>
      customization.groups.where(isVisible).toList();

  /// Options that count: those in visible groups, in group order.
  List<DrinkOption> get chosenOptions => [
    for (final g in visibleGroups)
      for (final id in chosen[g.group.id] ?? const <int>[]) ?g.optionById(id),
  ];

  /// BR-03: base price + every chosen option's extra price for this drink.
  Money get unitPrice => chosenOptions.fold(
    customization.product.basePrice,
    (sum, o) => sum + o.extraPrice,
  );

  /// BR-03: item price x quantity.
  Money get total => unitPrice * quantity;

  /// TC-12: required groups (that are shown) with nothing picked.
  List<ProductOptionGroup> get missingRequired => [
    for (final g in visibleGroups)
      if (g.group.isRequired && (chosen[g.group.id]?.isEmpty ?? true)) g,
  ];

  /// The price shown on an option's button, or null for none. In a
  /// single-choice group whose options cost different amounts (size,
  /// shots), it is relative to the current choice: "-$0.50", "+$0.00",
  /// "+$0.50". Add-ons keep their own price ("+$0.60"), groups where every
  /// option is free show none, and a group with nothing chosen yet shows
  /// the stored prices.
  String? priceOf(ProductOptionGroup group, DrinkOption option) {
    final own = option.extraPrice == Money.zero
        ? null
        : option.extraPrice.formatSigned();
    if (!hasPriceChoice(group)) return own;
    final ids = chosen[group.group.id] ?? const <int>[];
    final current = ids.isEmpty ? null : group.optionById(ids.first);
    // Every button in the row gets a price, "+$0.00" included.
    if (current == null) return option.extraPrice.formatSigned();
    return (option.extraPrice - current.extraPrice).formatSigned();
  }

  /// "Large +$0.50": name and [priceOf] on one line.
  String labelOf(ProductOptionGroup group, DrinkOption option) {
    final price = priceOf(group, option);
    return price == null ? option.name : '${option.name} $price';
  }

  /// True for a single-choice group whose options cost different amounts
  /// (size, shots): one choice is swapped for another, so prices are
  /// compared.
  bool hasPriceChoice(ProductOptionGroup group) =>
      !group.group.isMultiple &&
      group.options.map((o) => o.extraPrice).toSet().length > 1;

  /// TC-13: false when this would go over the group's limit.
  bool canChoose(ProductOptionGroup group, DrinkOption option) {
    if (!group.group.isMultiple || isChosen(group, option)) return true;
    return (chosen[group.group.id]?.length ?? 0) < group.group.maxSelect;
  }

  /// Picks or un-picks [option]. Single groups replace their choice;
  /// a required single choice cannot be cleared by tapping it again.
  /// Multiple groups toggle, up to the limit (check [canChoose] first).
  DrinkSelection choose(ProductOptionGroup group, DrinkOption option) {
    final current = chosen[group.group.id] ?? const <int>[];
    final List<int> next;
    if (group.group.isMultiple) {
      next = current.contains(option.id)
          ? (List.of(current)..remove(option.id))
          : (canChoose(group, option) ? [...current, option.id] : current);
    } else if (current.contains(option.id)) {
      next = group.group.isRequired ? current : const [];
    } else {
      next = [option.id];
    }
    return DrinkSelection._(
      customization: customization,
      chosen: {...chosen, group.group.id: next},
      quantity: quantity,
    );
  }

  DrinkSelection withQuantity(int value) => DrinkSelection._(
    customization: customization,
    chosen: chosen,
    quantity: value.clamp(1, maxQuantity),
    showMissing: showMissing,
  );

  DrinkSelection withMissingShown() => DrinkSelection._(
    customization: customization,
    chosen: chosen,
    quantity: quantity,
    showMissing: true,
  );

  /// The cart line for this selection. Prices and names are copied now
  /// (BR-04 is enforced when the order is placed).
  CartItem toCartItem() => CartItem(
    product: customization.product,
    options: chosenOptions,
    optionLabels: [
      for (final g in visibleGroups)
        for (final id in chosen[g.group.id] ?? const <int>[])
          if (g.optionById(id) case final option?)
            g.group.summaryNameOf(option),
    ],
    quantity: quantity,
  );
}
