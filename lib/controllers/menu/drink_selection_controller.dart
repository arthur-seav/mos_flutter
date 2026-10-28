import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/drink_option.dart';
import '../../data/models/drink_selection.dart';
import '../../data/repository_providers.dart';
import '../cart/cart_controller.dart';

/// The customization page's state for one drink (FR-08, FR-09).
///
/// One per product id (`drinkSelectionProvider(productId)`), loaded from the
/// repository and forgotten when the page closes. The screen reads the
/// [DrinkSelection]; every rule lives in that model.
final drinkSelectionProvider = AsyncNotifierProvider.autoDispose
    .family<DrinkSelectionController, DrinkSelection, int>(
      DrinkSelectionController.new,
    );

class DrinkSelectionController extends AsyncNotifier<DrinkSelection> {
  DrinkSelectionController(this.productId);

  final int productId;

  @override
  Future<DrinkSelection> build() async {
    final customization = await ref
        .watch(menuRepositoryProvider)
        .fetchCustomization(productId);
    return DrinkSelection.initial(customization);
  }

  DrinkSelection? get _selection => state.value;

  /// Picks or un-picks an option. Returns a message for the user when the
  /// pick is not allowed (TC-13: more than 3 add-ons), otherwise null.
  String? choose(ProductOptionGroup group, DrinkOption option) {
    final selection = _selection;
    if (selection == null) return null;
    if (!selection.canChoose(group, option)) {
      return 'You can choose up to ${group.group.maxSelect} '
          '${group.group.name.toLowerCase()}.';
    }
    state = AsyncData(selection.choose(group, option));
    return null;
  }

  void setQuantity(int quantity) {
    final selection = _selection;
    if (selection == null) return;
    state = AsyncData(selection.withQuantity(quantity));
  }

  /// Puts the drink in the cart and returns it, or returns null and marks
  /// the empty required groups when something is missing (TC-12).
  CartItem? addToCart() {
    final selection = _selection;
    if (selection == null) return null;
    if (selection.missingRequired.isNotEmpty) {
      state = AsyncData(selection.withMissingShown());
      return null;
    }
    final item = selection.toCartItem();
    ref.read(cartControllerProvider.notifier).add(item);
    return item;
  }

  /// "Please choose a size." / "Please choose a size and sweetness."
  static String missingMessage(DrinkSelection selection) {
    final names = selection.missingRequired
        .map((g) => g.group.name.toLowerCase())
        .toList();
    final list = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return 'Please choose a $list.';
  }
}
