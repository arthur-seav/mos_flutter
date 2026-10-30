import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mos_app/data/api/api_auth_repository.dart';
import 'package:mos_app/data/api/api_backend.dart';
import 'package:mos_app/data/api/api_client.dart';
import 'package:mos_app/data/api/api_menu_repository.dart';
import 'package:mos_app/data/api/api_order_repository.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/data/models/profile_update.dart';
import 'package:mos_app/data/models/saved_card.dart';
import 'package:mos_app/data/models/sign_up_request.dart';
import 'package:mos_app/data/models/user.dart';
import 'package:mos_app/data/repositories/auth_repository.dart';
import 'package:mos_app/data/repositories/card_repository.dart';
import 'package:mos_app/data/repositories/order_repository.dart';

// Bodies below were recorded from the real Spring Boot backend (seeded demo
// database) on 2026-10-30 and trimmed. Expected values are worked out by hand
// from these bodies, never read back from the code under test.

const _latteCustomization = '''
{"product":{"id":7,"categoryId":1,"categoryName":"Coffee","name":"Latte","description":"Espresso with plenty of steamed milk","imageUrl":"","basePrice":3.0,"isAvailable":true,"isActive":true,"createdAt":"2026-10-30T03:36:31.329678Z"},
 "groups":[
  {"id":1,"name":"Size","selectionType":"single","isRequired":true,"maxSelect":1,"needsIcedDrink":false,"summaryNoun":null,
   "options":[{"id":1,"groupId":1,"name":"Small","extraPrice":0.0,"isIced":false},{"id":2,"groupId":1,"name":"Medium","extraPrice":0.5,"isIced":false},{"id":3,"groupId":1,"name":"Large","extraPrice":1.0,"isIced":false}],"defaultOptionId":2},
  {"id":3,"name":"Ice level","selectionType":"single","isRequired":true,"maxSelect":1,"needsIcedDrink":true,"summaryNoun":"ice",
   "options":[{"id":7,"groupId":3,"name":"Less","extraPrice":0.0,"isIced":false}],"defaultOptionId":7},
  {"id":5,"name":"Add-ons","selectionType":"multiple","isRequired":false,"maxSelect":3,"needsIcedDrink":false,"summaryNoun":null,
   "options":[{"id":17,"groupId":5,"name":"Oat milk","extraPrice":0.6,"isIced":false}],"defaultOptionId":null}],
 "lowestPrice":3.0}''';

const _order = '''
{"id":3,"pickupCode":"A003","source":"online","status":"refund_pending_never","pickupType":"scheduled","pickupTime":"2026-10-30T05:00:00Z","note":null,"totalAmount":9.2,"rejectReason":"Sold out","createdAt":"2026-10-30T06:41:40.237363273Z","placedAt":"2026-10-30T06:41:46Z","confirmedAt":null,"preparingAt":null,"readyAt":null,"completedAt":null,"endedAt":"2026-10-30T06:45:00Z","customerId":5,
 "customer":{"id":5,"name":"Probe User","email":"probe@mos.test","phone":null},"handledBy":null,
 "items":[{"productId":7,"productName":"Latte","optionIds":[3,5,7,12,17],"optionNames":["Large","Iced","Less ice","No sugar","Oat milk"],"unitPrice":4.6,"quantity":2,"lineTotal":9.2}],
 "payments":[{"id":3,"orderId":3,"method":"khqr","amount":9.2,"status":"refund_pending","transactionRef":"SIM-KHQR-3","paidAt":"2026-10-30T06:41:46Z","createdAt":"2026-10-30T06:41:40.300688Z","failureReason":null,"recordedBy":null}],"drinkCount":2}''';

String _orderWithStatus(String status) =>
    _order.replaceFirst('"refund_pending_never"', '"$status"');

/// Records every request and answers with [handler].
class _Server {
  _Server(this.handler);

  final http.Response Function(http.Request) handler;
  final requests = <http.Request>[];

  ApiClient client() => ApiClient(
    baseUrl: Uri.parse('http://10.0.2.2:8080'),
    client: MockClient((request) async {
      requests.add(request);
      return handler(request);
    }),
  );
}

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(body is String ? body : jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _error(int status, String code, String message) =>
    _json({'code': code, 'message': message, 'fields': null}, status);

void main() {
  group('ApiClient', () {
    test('sends JSON with the bearer token to the base URL', () async {
      final server = _Server((_) => _json({'ok': true}));
      final api = server.client()..token = 'tok-1';
      await api.post('/api/app/orders/3/cancel');
      final r = server.requests.single;
      expect(r.url.toString(), 'http://10.0.2.2:8080/api/app/orders/3/cancel');
      expect(r.method, 'POST');
      expect(r.headers['Authorization'], 'Bearer tok-1');
      expect(r.headers['Content-Type'], startsWith('application/json'));
    });

    test('a backend error keeps its code and message', () async {
      final api = _Server(
        (_) => _error(409, 'ordering_paused', 'Online ordering is paused.'),
      ).client();
      await expectLater(
        api.get('/api/app/store'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.code, 'code', 'ordering_paused')
              .having(
                (e) => e.message,
                'message',
                'Online ordering is paused.',
              ),
        ),
      );
    });

    test('a 401 without a body asks the customer to sign in again', () async {
      final api = _Server((_) => http.Response('', 401)).client();
      await expectLater(
        api.get('/api/app/orders'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'not_signed_in')
              .having((e) => e.message, 'message', 'Please sign in again.'),
        ),
      );
    });

    test(
      'an unreachable server becomes a readable error, not a crash',
      () async {
        final api = ApiClient(
          baseUrl: Uri.parse('http://10.0.2.2:8080'),
          client: MockClient((_) => throw http.ClientException('refused')),
        );
        await expectLater(
          api.get('/api/app/menu'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', 0)
                .having(
                  (e) => e.message,
                  'message',
                  ApiClient.unreachableMessage,
                ),
          ),
        );
      },
    );
  });

  group('menu and store', () {
    test('menu: hidden categories and drinks are dropped, sold out kept, '
        'relative image paths become full URLs', () async {
      final api = _Server(
        (_) => _json({
          'categories': [
            {
              'id': 2,
              'name': 'Tea',
              'sortOrder': 2,
              'active': true,
              'productCount': 0,
            },
            {
              'id': 1,
              'name': 'Coffee',
              'sortOrder': 1,
              'active': true,
              'productCount': 0,
            },
            {
              'id': 9,
              'name': 'Old',
              'sortOrder': 0,
              'active': false,
              'productCount': 0,
            },
          ],
          'products': [
            {
              'id': 2,
              'categoryId': 1,
              'name': 'Americano',
              'description': null,
              'imageUrl': '',
              'basePrice': 2.5,
              'isAvailable': true,
              'isActive': true,
            },
            {
              'id': 5,
              'categoryId': 1,
              'name': 'Mocha',
              'description': null,
              'imageUrl': '/uploads/mocha.jpg',
              'basePrice': 3.6,
              'isAvailable': false,
              'isActive': true,
            },
            {
              'id': 8,
              'categoryId': 2,
              'name': 'Gone',
              'description': null,
              'imageUrl': null,
              'basePrice': 1,
              'isAvailable': true,
              'isActive': false,
            },
          ],
        }),
      ).client();
      final menu = await ApiMenuRepository(api).fetchMenu();
      expect(menu.categories.map((c) => c.name), ['Coffee', 'Tea']);
      expect(menu.products.map((p) => p.name), ['Americano', 'Mocha']);
      expect(menu.productById(2)!.basePrice, const Money.cents(250));
      expect(menu.productById(2)!.imageUrl, isNull);
      expect(menu.productById(5)!.isSoldOut, isTrue);
      expect(
        menu.productById(5)!.imageUrl,
        'http://10.0.2.2:8080/uploads/mocha.jpg',
      );
    });

    test(
      'customization keeps per-drink prices, defaults and ice rules',
      () async {
        final api = _Server((_) => _json(_latteCustomization)).client();
        final c = await ApiMenuRepository(api).fetchCustomization(7);
        expect(c.product.basePrice, const Money.cents(300));
        final size = c.groups[0];
        expect(size.group.isRequired, isTrue);
        expect(size.options.map((o) => o.extraPrice.cents), [0, 50, 100]);
        expect(size.defaultOptionId, 2);
        final ice = c.groups[1];
        expect(ice.group.needsIcedDrink, isTrue);
        expect(ice.group.summaryNameOf(ice.options.single), 'Less ice');
        final addOns = c.groups[2];
        expect(addOns.group.isMultiple, isTrue);
        expect(addOns.group.maxSelect, 3);
        expect(addOns.defaultOptionId, isNull);
        // Cheapest required choices: Small (+0) and Less ice (+0) on $3.00.
        expect(c.lowestPrice, const Money.cents(300));
      },
    );

    test(
      'an unknown drink is a StateError, as the interface promises',
      () async {
        final api = _Server(
          (_) => _error(404, 'not_found', 'Drink not found.'),
        ).client();
        await expectLater(
          ApiMenuRepository(api).fetchCustomization(999),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('sold-out check sends and reads product ids', () async {
      final server = _Server(
        (_) => _json({
          'productIds': [5],
        }),
      );
      final unavailable = await ApiMenuRepository(
        server.client(),
      ).fetchUnavailable([2, 5]);
      expect(unavailable, {5});
      expect(jsonDecode(server.requests.single.body), {
        'productIds': [2, 5],
      });
    });

    test('store hours "07:00:00" become minutes of the day', () async {
      final api = _Server(
        (_) => _json({
          'settings': {
            'storeName': 'MOS Coffee',
            'address': 'Phnom Penh',
            'phone': '012 345 678',
            'slotIntervalMin': 15,
            'minPrepMin': 30,
            'pickupTimeoutMin': 30,
            'asapPrepMin': 10,
            'onlineOrderingOpen': false,
          },
          'hours': [
            {
              'dayOfWeek': 0,
              'openTime': '07:00:00',
              'closeTime': '21:30:00',
              'isClosed': false,
            },
            {
              'dayOfWeek': 1,
              'openTime': null,
              'closeTime': null,
              'isClosed': true,
            },
          ],
          'timeZone': 'Asia/Phnom_Penh',
          'isOpenNow': false,
        }),
      ).client();
      final info = await ApiStoreRepository(api).fetchStoreInfo();
      expect(info.settings.onlineOrderingOpen, isFalse);
      expect(info.settings.minPrepMin, 30);
      expect(info.hours[0].openMinute, 420);
      expect(info.hours[0].closeMinute, 1290);
      expect(info.hours[1].isOpenDay, isFalse);
      // 2026-11-01 is a Sunday (dayOfWeek 0).
      expect(info.hoursOn(DateTime(2026, 11, 1)).openMinute, 420);
    });
  });

  group('orders', () {
    test('an order with its payment maps every field', () async {
      final api = _Server((_) => _json(_orderWithStatus('rejected'))).client();
      final o = await ApiOrderRepository(api).fetchOrder(3);
      expect(o.status, OrderStatus.rejected);
      expect(o.pickupType, PickupType.scheduled);
      expect(o.pickupCode, 'A003');
      expect(o.rejectReason, 'Sold out');
      expect(o.totalAmount, const Money.cents(920));
      expect(o.items.single.unitPrice, const Money.cents(460));
      expect(o.items.single.lineTotal, const Money.cents(920));
      expect(o.items.single.optionNames, [
        'Large',
        'Iced',
        'Less ice',
        'No sugar',
        'Oat milk',
      ]);
      expect(o.pickupTime!.toUtc(), DateTime.utc(2026, 10, 30, 5));
      expect(o.pickupTime!.isUtc, isFalse, reason: 'shown in local time');
      final paid = o.paidPayment!;
      expect(paid.status, PaymentStatus.refundPending);
      expect(paid.method, PaymentMethod.khqr);
      expect(paid.isRefund, isTrue);
    });

    test('every backend status name is understood', () async {
      const wire = {
        'pending_payment': OrderStatus.pendingPayment,
        'placed': OrderStatus.placed,
        'confirmed': OrderStatus.confirmed,
        'preparing': OrderStatus.preparing,
        'ready': OrderStatus.ready,
        'completed': OrderStatus.completed,
        'cancelled': OrderStatus.cancelled,
        'rejected': OrderStatus.rejected,
        'abandoned': OrderStatus.abandoned,
      };
      for (final entry in wire.entries) {
        final api = _Server((_) => _json(_orderWithStatus(entry.key))).client();
        expect(
          (await ApiOrderRepository(api).fetchOrder(3)).status,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('creating an order sends lines, UTC pickup time and a trimmed note; '
        'never a price', () async {
      final server = _Server(
        (_) => _json(_orderWithStatus('pending_payment'), 201),
      );
      await ApiOrderRepository(server.client()).createOrder(
        OrderRequest(
          lines: const [
            OrderLineRequest(productId: 7, optionIds: [3, 5], quantity: 2),
          ],
          pickupType: PickupType.scheduled,
          pickupTime: DateTime.utc(2026, 10, 30, 5, 15),
          note: '  less sweet  ',
        ),
      );
      final r = server.requests.single;
      expect(r.url.path, '/api/app/orders');
      expect(jsonDecode(r.body), {
        'lines': [
          {
            'productId': 7,
            'optionIds': [3, 5],
            'quantity': 2,
          },
        ],
        'pickupType': 'scheduled',
        'pickupTime': '2026-10-30T05:15:00.000Z',
        'note': 'less sweet',
      });
    });

    test('ASAP orders send no pickup time and no empty note', () async {
      final server = _Server(
        (_) => _json(_orderWithStatus('pending_payment'), 201),
      );
      await ApiOrderRepository(server.client()).createOrder(
        const OrderRequest(
          lines: [
            OrderLineRequest(productId: 7, optionIds: [2], quantity: 1),
          ],
          pickupType: PickupType.asap,
          note: '   ',
        ),
      );
      expect(jsonDecode(server.requests.single.body), {
        'lines': [
          {
            'productId': 7,
            'optionIds': [2],
            'quantity': 1,
          },
        ],
        'pickupType': 'asap',
      });
    });

    test('backend refusals become the reasons checkout reacts to', () async {
      Future<OrderException> refusal(http.Response response) async {
        final api = _Server((_) => response).client();
        try {
          await ApiOrderRepository(api).createOrder(
            const OrderRequest(lines: [], pickupType: PickupType.asap),
          );
        } on OrderException catch (e) {
          return e;
        }
        fail('expected OrderException');
      }

      final paused = await refusal(
        _error(409, 'ordering_paused', 'Online ordering is paused right now.'),
      );
      expect(paused.reason, OrderFailure.orderingPaused);
      expect(paused.message, 'Online ordering is paused right now.');
      expect(
        (await refusal(
          _error(409, 'slot_unavailable', 'Pick a later time.'),
        )).reason,
        OrderFailure.slotUnavailable,
      );
      expect(
        (await refusal(
          _error(409, 'drink_unavailable', 'Mocha is sold out.'),
        )).reason,
        OrderFailure.drinkUnavailable,
      );
      expect(
        (await refusal(http.Response('', 401))).reason,
        OrderFailure.notSignedIn,
      );
      expect(
        (await refusal(
          _error(400, 'invalid_options', 'Latte: Size is required.'),
        )).reason,
        OrderFailure.other,
      );
    });

    test('KHQR charge and payment polling', () async {
      final server = _Server(
        (r) => r.url.path.endsWith('/khqr')
            ? _json({
                'paymentId': 3,
                'orderId': 3,
                'qrData': 'MOSKHQR|payment=3|amount=3.50|USD',
                'amount': 3.5,
                'merchantName': 'MOS Coffee',
                'expiresAt': '2026-10-30T06:46:40.300688323Z',
              }, 201)
            : _json({
                'id': 3,
                'orderId': 3,
                'method': 'khqr',
                'amount': 3.5,
                'status': 'paid',
                'transactionRef': 'SIM',
                'paidAt': '2026-10-30T06:41:46Z',
                'createdAt': '2026-10-30T06:41:40Z',
                'failureReason': null,
                'recordedBy': null,
              }),
      );
      final repo = ApiOrderRepository(server.client());
      final charge = await repo.startKhqr(3);
      expect(charge.amount, const Money.cents(350));
      expect(charge.qrData, 'MOSKHQR|payment=3|amount=3.50|USD');
      expect(
        charge.expiresAt.toUtc(),
        DateTime.parse('2026-10-30T06:46:40.300688323Z'),
      );
      expect(charge.expiresAt.isUtc, isFalse, reason: 'shown in local time');
      final payment = await repo.checkPayment(charge.paymentId);
      expect(payment.isPaid, isTrue);
      expect(server.requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/app/orders/3/payments/khqr',
        'GET /api/app/payments/3',
      ]);
    });
  });

  group('accounts', () {
    const session = {
      'token': 'tok-dara',
      'user': {
        'id': 5,
        'firstName': 'Dara',
        'lastName': 'Kim Sok',
        'email': 'dara@mos.test',
        'phone': null,
        'role': 'customer',
        'status': 'active',
        'dateOfBirth': '2001-02-03',
        'createdAt': '2026-10-30T06:41:17Z',
      },
    };

    test(
      'sign-in keeps the token for later calls; sign-out forgets it',
      () async {
        final server = _Server(
          (r) => r.url.path.endsWith('/sign-in')
              ? _json(session)
              : _json(<Object>[]),
        );
        final api = server.client();
        final user = await ApiAuthRepository(
          api,
        ).signIn(identifier: ' dara@mos.test ', password: 'pw-123456');
        expect(user.fullName, 'Dara Kim Sok');
        expect(user.role, UserRole.customer);
        expect(user.dateOfBirth, DateTime(2001, 2, 3));
        expect(jsonDecode(server.requests.first.body), {
          'identifier': 'dara@mos.test',
          'password': 'pw-123456',
        });
        await ApiOrderRepository(api).fetchMyOrders();
        expect(
          server.requests.last.headers['Authorization'],
          'Bearer tok-dara',
        );
        await ApiAuthRepository(api).signOut();
        await ApiOrderRepository(api).fetchMyOrders();
        expect(
          server.requests.last.headers.containsKey('Authorization'),
          isFalse,
        );
      },
    );

    test('wrong password shows the backend message', () async {
      final api = _Server(
        (_) => _error(
          401,
          'bad_credentials',
          'Incorrect email/phone or password.',
        ),
      ).client();
      await expectLater(
        ApiAuthRepository(api).signIn(identifier: 'x', password: 'y'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Incorrect email/phone or password.',
          ),
        ),
      );
    });

    test(
      'sign-up splits the full name and signs the new customer in',
      () async {
        final server = _Server(
          (r) => r.url.path.endsWith('/sign-up')
              ? _json(session, 201)
              : _json(<Object>[]),
        );
        final api = server.client();
        await ApiAuthRepository(api).signUp(
          const SignUpRequest(
            fullName: '  Dara   Kim Sok ',
            password: 'pw-123456',
            email: 'dara@mos.test',
          ),
        );
        expect(jsonDecode(server.requests.single.body), {
          'firstName': 'Dara',
          'lastName': 'Kim Sok',
          'email': 'dara@mos.test',
          'phone': null,
          'password': 'pw-123456',
        });
        expect(api.token, 'tok-dara');
      },
    );

    test('profile update sends the date of birth as a plain date', () async {
      final server = _Server((_) => _json(session['user']));
      await ApiAuthRepository(server.client()).updateProfile(
        ProfileUpdate(
          userId: 5,
          fullName: 'Dara Kim',
          phone: '+85512345678',
          dateOfBirth: DateTime(2001, 2, 3),
        ),
      );
      final r = server.requests.single;
      expect(r.method, 'PUT');
      expect(jsonDecode(r.body), {
        'firstName': 'Dara',
        'lastName': 'Kim',
        'email': null,
        'phone': '+85512345678',
        'dateOfBirth': '2001-02-03',
      });
    });

    test(
      'password reset: verify by phone, then reset with the ticket',
      () async {
        final server = _Server(
          (r) => r.url.path.endsWith('/verify')
              ? _json({'ticket': 'reset-1'})
              : http.Response('', 204),
        );
        final repo = ApiAuthRepository(server.client());
        final ticket = await repo.verifyAccountForReset(phone: '+85512345678');
        await repo.resetPassword(ticket: ticket, newPassword: 'new-pw-123');
        expect(jsonDecode(server.requests.last.body), {
          'ticket': 'reset-1',
          'newPassword': 'new-pw-123',
        });
      },
    );

    test('unknown phone on reset: "Account not found." (TC-06)', () async {
      final api = _Server(
        (_) => _error(404, 'account_not_found', 'Account not found.'),
      ).client();
      await expectLater(
        ApiAuthRepository(api).verifyAccountForReset(phone: '+85512000999'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Account not found.',
          ),
        ),
      );
    });
  });

  group('cards', () {
    test(
      'adding a card strips spaces and returns only the last four digits',
      () async {
        final server = _Server(
          (_) => _json({
            'id': 1,
            'brand': 'Visa',
            'last4': '4242',
            'expiryMonth': 12,
            'expiryYear': 2030,
            'holderName': 'Dara Kim',
            'maskedNumber': '•••• •••• •••• 4242',
          }, 201),
        );
        final card = await ApiCardRepository(server.client()).addCard(
          const NewCard(
            number: '4242 4242 4242 4242',
            holderName: 'Dara Kim',
            expiryMonth: 12,
            expiryYear: 2030,
            cvv: '123',
          ),
        );
        expect(
          jsonDecode(server.requests.single.body)['number'],
          '4242424242424242',
        );
        expect(card.maskedNumber, '•••• •••• •••• 4242');
        expect(card.expiry, '12/30');
      },
    );

    test('a refused card shows the backend message', () async {
      final api = _Server(
        (_) => _error(400, 'card_rejected', 'This card number is not valid.'),
      ).client();
      await expectLater(
        ApiCardRepository(api).addCard(
          const NewCard(
            number: '1234',
            holderName: 'X',
            expiryMonth: 1,
            expiryYear: 2030,
            cvv: '1',
          ),
        ),
        throwsA(
          isA<CardException>().having(
            (e) => e.message,
            'message',
            'This card number is not valid.',
          ),
        ),
      );
    });
  });

  test(
    'default backend address: the Android emulator reaches the computer at 10.0.2.2',
    () {
      // flutter test runs as Android, without --dart-define.
      expect(useMockBackend, isFalse);
      expect(apiBaseUrl().toString(), 'http://10.0.2.2:8080');
    },
  );
}
