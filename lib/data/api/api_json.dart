import '../models/category.dart';
import '../models/drink_option.dart';
import '../models/money.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/product_customization.dart';
import '../models/saved_card.dart';
import '../models/store_info.dart';
import '../models/user.dart';

/// Turns the backend's JSON (`API.md` in the mos_management repo) into the
/// app's models. Pure functions, so tests can feed them recorded responses.
///
/// Backend conventions: enums are lowercase with underscores
/// (`pending_payment`), money is a decimal number in USD, instants are UTC
/// ISO-8601 strings, opening times are store-local `HH:mm:ss`.
typedef Json = Map<String, dynamic>;

Money moneyFrom(Object? value) =>
    Money.cents(((value as num? ?? 0) * 100).round());

DateTime? instantFrom(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

DateTime? dateFrom(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// `2026-10-30` for a date of birth (no time, no time zone).
String? dateTo(DateTime? date) => date == null
    ? null
    : '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

/// `07:00:00` → 420.
int? minutesFrom(Object? value) {
  if (value == null) return null;
  final parts = (value as String).split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

T _enum<T extends Enum>(List<T> values, Object? wire) {
  final camel = (wire as String).replaceAllMapped(
    RegExp(r'_([a-z])'),
    (m) => m[1]!.toUpperCase(),
  );
  return values.firstWhere(
    (v) => v.name == camel,
    orElse: () => throw FormatException('Unknown ${T.toString()}: $wire'),
  );
}

OrderStatus orderStatusFrom(Object? wire) => _enum(OrderStatus.values, wire);
PaymentStatus paymentStatusFrom(Object? wire) =>
    _enum(PaymentStatus.values, wire);

User userFrom(Json j) => User(
  id: j['id'] as int,
  firstName: j['firstName'] as String,
  lastName: j['lastName'] as String? ?? '',
  role: _enum(UserRole.values, j['role']),
  email: j['email'] as String?,
  phone: j['phone'] as String?,
  dateOfBirth: dateFrom(j['dateOfBirth']),
  status: _enum(AccountStatus.values, j['status']),
);

Category categoryFrom(Json j) => Category(
  id: j['id'] as int,
  name: j['name'] as String,
  sortOrder: j['sortOrder'] as int,
  isActive: j['active'] as bool? ?? true,
);

Product productFrom(Json j, {String? Function(String?)? resolveUrl}) {
  final image = j['imageUrl'] as String?;
  return Product(
    id: j['id'] as int,
    categoryId: j['categoryId'] as int,
    name: j['name'] as String,
    description: j['description'] as String?,
    imageUrl: resolveUrl == null
        ? (image == '' ? null : image)
        : resolveUrl(image),
    basePrice: moneyFrom(j['basePrice']),
    isAvailable: j['isAvailable'] as bool? ?? true,
    isActive: j['isActive'] as bool? ?? true,
  );
}

/// The backend already applies each drink's own option prices (`extraPrice`
/// here is what this drink charges) and leaves out options it does not offer.
ProductCustomization customizationFrom(
  Json j, {
  String? Function(String?)? resolveUrl,
}) => ProductCustomization(
  product: productFrom(j['product'] as Json, resolveUrl: resolveUrl),
  groups: [
    for (final g in (j['groups'] as List).cast<Json>())
      ProductOptionGroup(
        group: OptionGroup(
          id: g['id'] as int,
          name: g['name'] as String,
          selectionType: _enum(SelectionType.values, g['selectionType']),
          isRequired: g['isRequired'] as bool,
          maxSelect: g['maxSelect'] as int,
          needsIcedDrink: g['needsIcedDrink'] as bool? ?? false,
          summaryNoun: g['summaryNoun'] as String?,
        ),
        options: [
          for (final o in (g['options'] as List).cast<Json>())
            DrinkOption(
              id: o['id'] as int,
              groupId: o['groupId'] as int,
              name: o['name'] as String,
              extraPrice: moneyFrom(o['extraPrice']),
              isIced: o['isIced'] as bool? ?? false,
            ),
        ],
        defaultOptionId: g['defaultOptionId'] as int?,
      ),
  ],
);

StoreInfo storeInfoFrom(Json j) {
  final s = j['settings'] as Json;
  return StoreInfo(
    settings: StoreSettings(
      storeName: s['storeName'] as String,
      address: s['address'] as String,
      phone: s['phone'] as String,
      slotIntervalMin: s['slotIntervalMin'] as int,
      minPrepMin: s['minPrepMin'] as int,
      pickupTimeoutMin: s['pickupTimeoutMin'] as int,
      asapPrepMin: s['asapPrepMin'] as int,
      onlineOrderingOpen: s['onlineOrderingOpen'] as bool,
    ),
    hours: [
      for (final h in (j['hours'] as List).cast<Json>())
        DayHours(
          dayOfWeek: h['dayOfWeek'] as int,
          openMinute: minutesFrom(h['openTime']),
          closeMinute: minutesFrom(h['closeTime']),
          isClosed: h['isClosed'] as bool? ?? false,
        ),
    ],
  );
}

Payment paymentFrom(Json j) => Payment(
  id: j['id'] as int,
  orderId: j['orderId'] as int,
  method: _enum(PaymentMethod.values, j['method']),
  amount: moneyFrom(j['amount']),
  status: paymentStatusFrom(j['status']),
  createdAt: instantFrom(j['createdAt'])!,
  transactionRef: j['transactionRef'] as String?,
  paidAt: instantFrom(j['paidAt']),
  failureReason: j['failureReason'] as String?,
);

Order orderFrom(Json j) => Order(
  id: j['id'] as int,
  status: orderStatusFrom(j['status']),
  pickupType: _enum(PickupType.values, j['pickupType']),
  items: [
    for (final i in (j['items'] as List).cast<Json>())
      OrderItem(
        productId: i['productId'] as int,
        productName: i['productName'] as String,
        optionIds: (i['optionIds'] as List).cast<int>(),
        optionNames: (i['optionNames'] as List).cast<String>(),
        unitPrice: moneyFrom(i['unitPrice']),
        quantity: i['quantity'] as int,
      ),
  ],
  totalAmount: moneyFrom(j['totalAmount']),
  createdAt: instantFrom(j['createdAt'])!,
  customerId: j['customerId'] as int?,
  pickupCode: j['pickupCode'] as String?,
  pickupTime: instantFrom(j['pickupTime']),
  note: j['note'] as String?,
  rejectReason: j['rejectReason'] as String?,
  placedAt: instantFrom(j['placedAt']),
  confirmedAt: instantFrom(j['confirmedAt']),
  preparingAt: instantFrom(j['preparingAt']),
  readyAt: instantFrom(j['readyAt']),
  completedAt: instantFrom(j['completedAt']),
  endedAt: instantFrom(j['endedAt']),
  payments: [
    for (final p in (j['payments'] as List? ?? const []).cast<Json>())
      paymentFrom(p),
  ],
);

Json orderRequestTo(OrderRequest r) => {
  'lines': [
    for (final l in r.lines)
      {
        'productId': l.productId,
        'optionIds': l.optionIds,
        'quantity': l.quantity,
      },
  ],
  'pickupType': r.pickupType.name,
  if (r.pickupTime != null)
    'pickupTime': r.pickupTime!.toUtc().toIso8601String(),
  if (r.note != null && r.note!.trim().isNotEmpty) 'note': r.note!.trim(),
};

KhqrCharge khqrChargeFrom(Json j) => KhqrCharge(
  paymentId: j['paymentId'] as int,
  orderId: j['orderId'] as int,
  qrData: j['qrData'] as String,
  amount: moneyFrom(j['amount']),
  merchantName: j['merchantName'] as String,
  expiresAt: instantFrom(j['expiresAt'])!,
);

SavedCard savedCardFrom(Json j) => SavedCard(
  id: j['id'] as int,
  brand: j['brand'] as String,
  last4: j['last4'] as String,
  expiryMonth: j['expiryMonth'] as int,
  expiryYear: j['expiryYear'] as int,
  holderName: j['holderName'] as String?,
);
