import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/drink_option.dart';
import '../../data/models/drink_selection.dart';
import '../../data/repository_providers.dart';
import '../cart/cart_controller.dart';

/// Which drink the customization page is for. [lineId] is set when it
/// was opened with "Edit options" from the cart.
typedef DrinkPage = ({int productId, int? lineId});

/// What "Add to cart" did: the line, and the cart before (for "Undo").
typedef CartUpdate = ({CartItem item, List<CartItem> before});

/// The customization page's state for one drink (FR-08, FR-09).
///
/// One per page (`drinkSelectionProvider((productId: 4, lineId: null))`),
/// loaded from the repository and forgotten when the page closes. The
/// screen reads the [DrinkSelection]; every rule lives in that model.
final drinkSelectionProvider = AsyncNotifierProvider.autoDispose
    .family<DrinkSelectionController, DrinkSelection, DrinkPage>(
      DrinkSelectionController.new,
    );

class DrinkSelectionController extends AsyncNotifier<DrinkSelection> {
  DrinkSelectionController(this.page);

  final DrinkPage page;

  /// True when editing a cart line: the button saves instead of adding.
  bool get isEditing => page.lineId != null;

  @override
  Future<DrinkSelection> build() async {
    final customization = await ref
        .watch(menuRepositoryProvider)
        .fetchCustomization(page.productId);
    final lineId = page.lineId;
    final line = lineId == null
        ? null
        : ref.read(cartControllerProvider.notifier).line(lineId);
    return line == null
        ? DrinkSelection.initial(customization)
        : DrinkSelection.fromCartItem(customization, line);
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

  /// Puts the drink in the cart (or saves the edited line) and returns
  /// what changed. Returns null and marks the empty required groups when
  /// something is missing (TC-12).
  CartUpdate? addToCart() {
    final selection = _selection;
    if (selection == null) return null;
    if (selection.missingRequired.isNotEmpty) {
      state = AsyncData(selection.withMissingShown());
      return null;
    }
    final item = selection.toCartItem();
    final cart = ref.read(cartControllerProvider.notifier);
    final lineId = page.lineId;
    if (lineId != null) {
      final before = ref.read(cartControllerProvider);
      cart.replace(lineId, item);
      return (item: item, before: before);
    }
    return (item: item, before: cart.add(item));
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
