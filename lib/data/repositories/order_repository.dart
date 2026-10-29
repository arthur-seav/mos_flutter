import '../models/order.dart';

/// Thrown when an order or payment cannot go ahead, with a message for
/// the customer.
class OrderException implements Exception {
  const OrderException(this.message, {this.reason = OrderFailure.other});

  final String message;
  final OrderFailure reason;

  @override
  String toString() => message;
}

enum OrderFailure {
  /// Staff paused online ordering (FR-41, TC-20).
  orderingPaused,

  /// The pickup time broke BR-07 (e.g. it became too soon).
  slotUnavailable,

  /// A drink sold out or left the menu (BR-05).
  drinkUnavailable,

  /// Guests cannot order (BR-06).
  notSignedIn,
  other,
}

/// Orders and their payments (FR-12 to FR-14). Mock today, the backend
/// later (NFR-09).
abstract interface class OrderRepository {
  /// Creates the order in "Pending payment". The backend works out every
  /// price from the menu (TC-23) and checks BR-05, BR-06, BR-07 and
  /// FR-41 again; it throws [OrderException] when one fails.
  Future<Order> createOrder(OrderRequest request);

  Future<Order> fetchOrder(int orderId);

  /// The signed-in customer's orders, newest first (FR-18). Orders still
  /// waiting for payment are left out.
  Future<List<Order>> fetchMyOrders();

  /// "Cancel order" (BR-09, TC-25): only while the order is Placed. A paid
  /// payment becomes refund_pending. Throws [OrderException] once the
  /// store has confirmed it (TC-26).
  Future<Order> cancelOrder(int orderId);

  /// Starts a KHQR payment for an order still waiting to be paid.
  Future<KhqrCharge> startKhqr(int orderId);

  /// The payment as it is now. The app asks every few seconds while the
  /// KHQR page is open; the bank tells the backend when it is paid.
  Future<Payment> checkPayment(int paymentId);

  /// "Cancel payment" on the KHQR page. The order stays unpaid.
  Future<Payment> cancelPayment(int paymentId);

  /// Charges a saved card. Returns the payment, paid or failed (a
  /// declined card is a failed payment, not an exception).
  Future<Payment> payWithCard({required int orderId, required int cardId});
}
