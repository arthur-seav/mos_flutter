import '../models/order.dart';
import '../models/saved_card.dart';
import '../repositories/card_repository.dart';
import '../repositories/order_repository.dart';
import 'api_client.dart';
import 'api_json.dart';

/// Orders and payments of the signed-in customer (`/api/app/orders/**`,
/// `/api/app/payments/**`). The backend works out every price (TC-23) and
/// checks BR-05/06/07 and FR-41 again.
class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._api);

  final ApiClient _api;

  @override
  Future<Order> createOrder(OrderRequest request) => _guard(
    () async => orderFrom(
      await _api.post('/api/app/orders', orderRequestTo(request)) as Json,
    ),
  );

  @override
  Future<Order> fetchOrder(int orderId) => _guard(
    () async => orderFrom(await _api.get('/api/app/orders/$orderId') as Json),
  );

  @override
  Future<List<Order>> fetchMyOrders() => _guard(() async {
    final json = await _api.get('/api/app/orders') as List;
    return [for (final o in json.cast<Json>()) orderFrom(o)];
  });

  @override
  Future<Order> cancelOrder(int orderId) => _guard(
    () async =>
        orderFrom(await _api.post('/api/app/orders/$orderId/cancel') as Json),
  );

  @override
  Future<KhqrCharge> startKhqr(int orderId) => _guard(
    () async => khqrChargeFrom(
      await _api.post('/api/app/orders/$orderId/payments/khqr') as Json,
    ),
  );

  @override
  Future<Payment> checkPayment(int paymentId) => _guard(
    () async =>
        paymentFrom(await _api.get('/api/app/payments/$paymentId') as Json),
  );

  @override
  Future<Payment> cancelPayment(int paymentId) => _guard(
    () async => paymentFrom(
      await _api.post('/api/app/payments/$paymentId/cancel') as Json,
    ),
  );

  @override
  Future<Payment> payWithCard({required int orderId, required int cardId}) =>
      _guard(
        () async => paymentFrom(
          await _api.post('/api/app/orders/$orderId/payments/card', {
                'cardId': cardId,
              })
              as Json,
        ),
      );

  /// Backend error codes → the reasons the checkout screens react to.
  static OrderFailure reasonFor(ApiException e) => switch (e.code) {
    'ordering_paused' => OrderFailure.orderingPaused,
    'slot_unavailable' => OrderFailure.slotUnavailable,
    'drink_unavailable' => OrderFailure.drinkUnavailable,
    'not_signed_in' => OrderFailure.notSignedIn,
    _ => OrderFailure.other,
  };

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw OrderException(e.message, reason: reasonFor(e));
    }
  }
}

/// Saved cards (`/api/app/cards`). The backend keeps only the gateway token
/// and the last four digits.
class ApiCardRepository implements CardRepository {
  ApiCardRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<SavedCard>> fetchCards() async {
    try {
      final json = await _api.get('/api/app/cards') as List;
      return [for (final c in json.cast<Json>()) savedCardFrom(c)];
    } on ApiException catch (e) {
      throw CardException(e.message);
    }
  }

  @override
  Future<SavedCard> addCard(NewCard card) async {
    try {
      final json = await _api.post('/api/app/cards', {
        'number': card.number.replaceAll(RegExp(r'\s'), ''),
        'holderName': card.holderName,
        'expiryMonth': card.expiryMonth,
        'expiryYear': card.expiryYear,
        'cvv': card.cvv,
      });
      return savedCardFrom(json as Json);
    } on ApiException catch (e) {
      throw CardException(e.message);
    }
  }
}
