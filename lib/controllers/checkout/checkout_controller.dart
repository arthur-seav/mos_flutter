import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/order.dart';
import '../../data/models/pickup_schedule.dart';
import '../../data/models/store_info.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repository_providers.dart';
import '../../utils/clock.dart';
import '../auth/auth_controller.dart';
import '../cart/cart_controller.dart';

/// The checkout page's choices (SA §4.2.3.1).
@immutable
class CheckoutState {
  const CheckoutState({
    required this.store,
    required this.checkedAt,
    required this.pickupType,
    required this.paymentMethod,
    this.pickupTime,
    this.note = '',
  });

  final StoreInfo store;

  /// When [store] was read; the pickup times are worked out from it.
  final DateTime checkedAt;
  final PickupType pickupType;

  /// Set when [pickupType] is scheduled and a slot was confirmed.
  final DateTime? pickupTime;
  final PaymentMethod paymentMethod;
  final String note;

  PickupSchedule get schedule => PickupSchedule(store: store, now: checkedAt);

  /// FR-41, TC-20: the page says so and Pay is blocked.
  bool get isPaused => !store.settings.onlineOrderingOpen;

  /// The Pay button can be pressed.
  bool get canPay {
    if (isPaused) return false;
    return switch (pickupType) {
      PickupType.asap => schedule.canPickUpAsap,
      PickupType.scheduled =>
        pickupTime != null && schedule.allows(pickupTime!),
    };
  }

  CheckoutState copyWith({
    StoreInfo? store,
    DateTime? checkedAt,
    PickupType? pickupType,
    DateTime? pickupTime,
    bool clearPickupTime = false,
    PaymentMethod? paymentMethod,
    String? note,
  }) => CheckoutState(
    store: store ?? this.store,
    checkedAt: checkedAt ?? this.checkedAt,
    pickupType: pickupType ?? this.pickupType,
    pickupTime: clearPickupTime ? null : (pickupTime ?? this.pickupTime),
    paymentMethod: paymentMethod ?? this.paymentMethod,
    note: note ?? this.note,
  );
}

/// What happened when "Pay" was pressed.
sealed class CheckoutResult {
  const CheckoutResult();
}

/// The order exists and waits for payment: open the KHQR or card page.
class GoToPayment extends CheckoutResult {
  const GoToPayment(this.order, this.method);

  final Order order;
  final PaymentMethod method;
}

/// Not this time; show [message].
class CheckoutBlocked extends CheckoutResult {
  const CheckoutBlocked(this.message, {this.needsLogin = false});

  final String message;

  /// BR-06 / TC-18: a guest must log in first (the cart is kept).
  final bool needsLogin;
}

/// The longest note for the barista.
const maxNoteLength = 200;

final checkoutControllerProvider =
    AsyncNotifierProvider.autoDispose<CheckoutController, CheckoutState>(
      CheckoutController.new,
    );

/// Runs the checkout page: pickup time (FR-11, BR-07), payment method
/// (FR-13), note, and "Pay", which creates the order (FR-12).
///
/// The order is created once; going back from a failed payment and paying
/// again uses the same order, so its payments read "failed, then paid"
/// (TC-22). It is created again only if the cart or pickup changed.
class CheckoutController extends AsyncNotifier<CheckoutState> {
  Order? _pendingOrder;
  OrderRequest? _pendingRequest;

  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<CheckoutState> build() async {
    final store = await ref.read(storeRepositoryProvider).fetchStoreInfo();
    final now = _now();
    final schedule = PickupSchedule(store: store, now: now);
    return CheckoutState(
      store: store,
      checkedAt: now,
      // ASAP when possible; otherwise the customer must pick a time.
      pickupType: schedule.canPickUpAsap
          ? PickupType.asap
          : PickupType.scheduled,
      paymentMethod: PaymentMethod.khqr,
    );
  }

  CheckoutState? get _current => state.value;

  void _set(CheckoutState next) => state = AsyncData(next);

  void chooseAsap() {
    final s = _current;
    if (s == null) return;
    _set(s.copyWith(pickupType: PickupType.asap, clearPickupTime: true));
  }

  /// The schedule panel opens with the slots as of now.
  PickupSchedule scheduleNow() {
    final s = _current!;
    final now = _now();
    _set(s.copyWith(checkedAt: now));
    return PickupSchedule(store: s.store, now: now);
  }

  /// "Confirm 10:45 AM". Returns false (and changes nothing) when the slot
  /// breaks BR-07, e.g. TC-19: after 8:00 PM when the store closes at 9.
  bool chooseSlot(DateTime time) {
    final s = _current;
    if (s == null) return false;
    final now = _now();
    if (!PickupSchedule(store: s.store, now: now).allows(time)) return false;
    _set(
      s.copyWith(
        checkedAt: now,
        pickupType: PickupType.scheduled,
        pickupTime: time,
      ),
    );
    return true;
  }

  void choosePaymentMethod(PaymentMethod method) {
    final s = _current;
    if (s == null || method == PaymentMethod.cash) return;
    _set(s.copyWith(paymentMethod: method));
  }

  void setNote(String note) {
    final s = _current;
    if (s == null) return;
    final trimmed = note.length > maxNoteLength
        ? note.substring(0, maxNoteLength)
        : note;
    _set(s.copyWith(note: trimmed));
  }

  /// "Pay $8.10".
  Future<CheckoutResult> pay() async {
    final s = _current;
    if (s == null) return const CheckoutBlocked('Still loading. Try again.');

    // BR-06 / TC-18.
    if (!ref.read(authControllerProvider).isCustomer) {
      return const CheckoutBlocked(
        'Log in to place your order. Your cart will be kept.',
        needsLogin: true,
      );
    }

    // TC-20: staff may have paused ordering since the page opened.
    final store = await ref.read(storeRepositoryProvider).fetchStoreInfo();
    final now = _now();
    final fresh = s.copyWith(store: store, checkedAt: now);
    _set(fresh);
    if (fresh.isPaused) {
      return const CheckoutBlocked(
        'Online ordering is paused right now. Please try again later.',
      );
    }
    if (!fresh.canPay) {
      return CheckoutBlocked(
        fresh.pickupType == PickupType.asap
            ? 'The store is closed now. Choose a later pickup time.'
            : 'That pickup time is no longer available. Choose another.',
      );
    }

    // BR-05: drinks that sold out since they were added.
    final cart = ref.read(cartControllerProvider.notifier);
    final removed = await cart.removeUnavailable();
    if (removed.isNotEmpty) {
      return CheckoutBlocked(CartController.unavailableMessage(removed));
    }
    final lines = ref.read(cartControllerProvider);
    if (lines.isEmpty) return const CheckoutBlocked('Your cart is empty.');

    final request = _requestFor(lines, fresh);
    try {
      final order = _sameRequest(request, _pendingRequest)
          ? _pendingOrder!
          : await ref.read(orderRepositoryProvider).createOrder(request);
      _pendingOrder = order;
      _pendingRequest = request;
      return GoToPayment(order, fresh.paymentMethod);
    } on OrderException catch (e) {
      return CheckoutBlocked(e.message);
    }
  }

  static OrderRequest _requestFor(List<CartItem> lines, CheckoutState s) =>
      OrderRequest(
        lines: [
          for (final l in lines)
            OrderLineRequest(
              productId: l.product.id,
              optionIds: [for (final o in l.options) o.id],
              quantity: l.quantity,
            ),
        ],
        pickupType: s.pickupType,
        pickupTime: s.pickupType == PickupType.scheduled ? s.pickupTime : null,
        note: s.note.trim().isEmpty ? null : s.note.trim(),
      );

  static bool _sameRequest(OrderRequest a, OrderRequest? b) {
    if (b == null) return false;
    if (a.pickupType != b.pickupType ||
        a.pickupTime != b.pickupTime ||
        a.note != b.note ||
        a.lines.length != b.lines.length) {
      return false;
    }
    for (var i = 0; i < a.lines.length; i++) {
      final x = a.lines[i], y = b.lines[i];
      if (x.productId != y.productId ||
          x.quantity != y.quantity ||
          !listEquals(x.optionIds, y.optionIds)) {
        return false;
      }
    }
    return true;
  }
}
