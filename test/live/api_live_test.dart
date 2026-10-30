@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mos_app/data/api/api_auth_repository.dart';
import 'package:mos_app/data/api/api_client.dart';
import 'package:mos_app/data/api/api_menu_repository.dart';
import 'package:mos_app/data/api/api_order_repository.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/data/models/sign_up_request.dart';
import 'package:mos_app/data/repositories/order_repository.dart';

/// Cross-end check against a REAL backend with the demo seed. Writes data, so
/// point it at a throwaway database only. Skipped unless MOS_LIVE_API is set:
///
/// ```sh
/// MOS_LIVE_API=http://127.0.0.1:8092 MOS_LIVE_STAFF_PASSWORD=... \
///   flutter test test/live --tags live
/// ```
///
/// The customer side uses the app's own API repositories; the store side
/// calls the dashboard API as staff@mos.test, as the dashboard would.
void main() {
  final base = Platform.environment['MOS_LIVE_API'] ?? '';
  final staffPassword = Platform.environment['MOS_LIVE_STAFF_PASSWORD'] ?? '';
  final skip = base.isEmpty || staffPassword.isEmpty
      ? 'set MOS_LIVE_API and MOS_LIVE_STAFF_PASSWORD'
      : null;

  test(
    'app order → KHQR → staff confirms and prepares → app sees it; '
    'staff pauses online ordering → app is refused',
    () async {
      final api = ApiClient(baseUrl: Uri.parse(base));
      final auth = ApiAuthRepository(api);
      final menu = ApiMenuRepository(api);
      final store = ApiStoreRepository(api);
      final orders = ApiOrderRepository(api);

      Future<Object?> staff(String method, String path, [Object? body]) async {
        final r = http.Request(method, Uri.parse(base).resolve(path))
          ..headers.addAll({
            'Content-Type': 'application/json',
            if (_staffToken != null) 'Authorization': 'Bearer $_staffToken',
          })
          ..body = jsonEncode(body ?? {});
        final response = await http.Response.fromStream(await r.send());
        expect(
          response.statusCode,
          lessThan(300),
          reason: '$method $path: ${response.body}',
        );
        return response.body.isEmpty ? null : jsonDecode(response.body);
      }

      _staffToken =
          ((await staff('POST', '/api/admin/auth/sign-in', {
                    'identifier': 'staff@mos.test',
                    'password': staffPassword,
                  }))
                  as Map)['token']
              as String;

      // Customer: sign up (signs in), read the menu the dashboard manages.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final user = await auth.signUp(
        SignUpRequest(
          fullName: 'Live Check',
          password: 'live-$stamp',
          email: 'live-$stamp@mos.test',
        ),
      );
      expect(user.isCustomer, isTrue);
      final catalog = await menu.fetchMenu();
      final latte = catalog.products.firstWhere((p) => p.name == 'Latte');
      final custom = await menu.fetchCustomization(latte.id);
      int pick(String group, String option) => custom.groups
          .firstWhere((g) => g.group.name == group)
          .options
          .firstWhere((o) => o.name == option)
          .id;
      // TC-14: 2 × Large iced Latte, less ice, no sugar, oat milk = $9.20.
      final options = [
        pick('Size', 'Large'),
        pick('Temperature', 'Iced'),
        pick('Ice level', 'Less'),
        pick('Sweetness', 'No sugar'),
        pick('Add-ons', 'Oat milk'),
      ];
      expect(
        (await store.fetchStoreInfo()).settings.onlineOrderingOpen,
        isTrue,
      );

      final created = await orders.createOrder(
        OrderRequest(
          lines: [
            OrderLineRequest(
              productId: latte.id,
              optionIds: options,
              quantity: 2,
            ),
          ],
          pickupType: PickupType.asap,
        ),
      );
      expect(created.status, OrderStatus.pendingPayment);
      expect(created.totalAmount, const Money.cents(920));

      final charge = await orders.startKhqr(created.id);
      expect(charge.amount, const Money.cents(920));
      var payment = await orders.checkPayment(charge.paymentId);
      for (var i = 0; i < 20 && !payment.isPaid; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        payment = await orders.checkPayment(charge.paymentId);
      }
      expect(
        payment.isPaid,
        isTrue,
        reason: 'simulated KHQR pays after about 5 s',
      );

      var mine = await orders.fetchOrder(created.id);
      expect(mine.status, OrderStatus.placed);
      expect(mine.pickupCode, isNotNull);

      // Store: the order is in the shared queue; confirm, then start preparing.
      final queue = (await staff('GET', '/api/admin/orders/queue')) as Map;
      expect(
        (queue['orders'] as List).map((e) => (e as Map)['order']['id']),
        contains(created.id),
      );
      await staff('POST', '/api/admin/orders/${created.id}/advance');
      await staff('POST', '/api/admin/orders/${created.id}/advance');

      // Customer: the tracking page's poll sees the store's change.
      mine = await orders.fetchOrder(created.id);
      expect(mine.status, OrderStatus.preparing);
      expect(mine.confirmedAt, isNotNull);
      expect(mine.preparingAt, isNotNull);
      expect(
        (await orders.fetchMyOrders()).map((o) => o.id),
        contains(created.id),
      );

      // Once confirmed, the customer can no longer cancel (TC-26).
      await expectLater(
        orders.cancelOrder(created.id),
        throwsA(isA<OrderException>()),
      );

      // Staff pauses online ordering (FR-41) → the app is refused (TC-20).
      await staff('PUT', '/api/admin/store/online-ordering', {'open': false});
      try {
        expect(
          (await store.fetchStoreInfo()).settings.onlineOrderingOpen,
          isFalse,
        );
        await expectLater(
          orders.createOrder(
            OrderRequest(
              lines: [
                OrderLineRequest(
                  productId: latte.id,
                  optionIds: options,
                  quantity: 1,
                ),
              ],
              pickupType: PickupType.asap,
            ),
          ),
          throwsA(
            isA<OrderException>().having(
              (e) => e.reason,
              'reason',
              OrderFailure.orderingPaused,
            ),
          ),
        );
      } finally {
        await staff('PUT', '/api/admin/store/online-ordering', {'open': true});
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

String? _staffToken;
