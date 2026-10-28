import 'package:flutter/foundation.dart' show immutable;

import 'money.dart';

/// How many options a group allows (data dictionary: `option_groups`).
enum SelectionType { single, multiple }

/// "Size", "Temperature", "Ice level", "Sweetness", "Add-ons"...
@immutable
class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.isRequired,
    required this.maxSelect,
    this.needsIcedDrink = false,
    this.summaryNoun,
  });

  final int id;
  final String name;
  final SelectionType selectionType;

  /// BR-02: size, ice level and sweetness are required.
  final bool isRequired;

  /// 1 for single-choice groups, 3 for add-ons (BR-02).
  final int maxSelect;

  /// Only applies to iced drinks (the ice level group). Hidden while a hot
  /// temperature is chosen (BR-01). Not in the SA data dictionary yet; see
  /// README "Open questions".
  final bool needsIcedDrink;

  /// Added after short option names in cart and order lines, so
  /// "Less" reads "Less ice" or "Less sugar". Null = names stand alone
  /// ("Medium", "Oat milk"). Not in the SA data dictionary yet.
  final String? summaryNoun;

  bool get isMultiple => selectionType == SelectionType.multiple;

  /// "Less" -> "Less sugar"; "No sugar" stays as it is.
  String summaryNameOf(DrinkOption option) {
    final noun = summaryNoun;
    if (noun == null) return option.name;
    if (option.name.toLowerCase().contains(noun.toLowerCase())) {
      return option.name;
    }
    return '${option.name} $noun';
  }
}

/// One choice in a group (data dictionary: `options`), with the price for
/// **this drink**: `product_options.extra_price` when the admin set one,
/// otherwise the option's own `extra_price`.
@immutable
class DrinkOption {
  const DrinkOption({
    required this.id,
    required this.groupId,
    required this.name,
    this.extraPrice = Money.zero,
    this.isIced = false,
  });

  final int id;
  final int groupId;
  final String name;
  final Money extraPrice;

  /// True for "Iced" in the temperature group; see
  /// [OptionGroup.needsIcedDrink].
  final bool isIced;

  /// "Medium +$0.50", or just "Small" when it is free.
  String get label =>
      extraPrice == Money.zero ? name : '$name +${extraPrice.format()}';
}

/// A group as offered for one drink (data dictionary:
/// `product_option_groups`): which options, and the admin's default.
@immutable
class ProductOptionGroup {
  const ProductOptionGroup({
    required this.group,
    required this.options,
    this.defaultOptionId,
  });

  final OptionGroup group;

  /// Only the options this drink offers, e.g. Espresso offers "Hot" only.
  final List<DrinkOption> options;

  /// TC-11: picked when the page opens. Null = the customer must choose.
  final int? defaultOptionId;

  DrinkOption? optionById(int id) =>
      options.where((o) => o.id == id).firstOrNull;
}
