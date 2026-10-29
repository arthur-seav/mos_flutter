import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/checkout/qr_saver.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/widgets/checkout/khqr_receipt.dart';
import 'package:mos_app/widgets/common/brand_mark.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

// Order #12, made Thursday 29 Oct 2026 at 10:12 AM, pickup at 10:40 AM.
// 2 x Latte $3.50 = $7.00, 1 x Espresso $2.00: $9.00.
final order = Order(
  id: 12,
  status: OrderStatus.pendingPayment,
  pickupType: PickupType.scheduled,
  pickupTime: DateTime(2026, 10, 29, 10, 40),
  createdAt: DateTime(2026, 10, 29, 10, 12),
  totalAmount: const Money.cents(900),
  items: const [
    OrderItem(
      productId: 18,
      productName: 'Latte',
      optionNames: ['Medium', 'Hot', 'Regular sugar'],
      unitPrice: Money.cents(350),
      quantity: 2,
    ),
    OrderItem(
      productId: 1,
      productName: 'Espresso',
      optionNames: ['Double shot', 'Hot', 'No sugar'],
      unitPrice: Money.cents(200),
      quantity: 1,
    ),
  ],
);
final charge = KhqrCharge(
  paymentId: 3,
  orderId: 12,
  qrData: 'KHQR-DEMO-12',
  amount: const Money.cents(900),
  merchantName: 'MOS Coffee',
  expiresAt: DateTime(2026, 10, 29, 10, 17),
);

Future<void> pumpReceipt(WidgetTester tester, Order o) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SingleChildScrollView(
        child: KhqrReceipt(charge: charge, order: o),
      ),
    ),
  );
}

void main() {
  testWidgets('logo, order number, amount, QR and when it expires', (
    tester,
  ) async {
    await pumpReceipt(tester, order);
    expect(find.byType(BrandMark), findsOneWidget);
    // Header, and the KHQR strip's merchant line.
    expect(find.text('MOS Coffee'), findsNWidgets(2));
    expect(find.text('Order #12'), findsOneWidget);
    expect(find.text(r'$9.00'), findsNWidgets(2)); // amount and Total
    expect(find.byType(PrettyQrView), findsOneWidget);
    expect(find.text('Expires at 10:17 AM'), findsOneWidget);
    expect(
      find.text('This code is for order #12 only. Pay before 10:17 AM.'),
      findsOneWidget,
    );
  });

  testWidgets('full dates, never "Today", so old pictures can be told apart', (
    tester,
  ) async {
    await pumpReceipt(tester, order);
    expect(find.text('Thu, 29 Oct 2026 · 10:12 AM'), findsOneWidget);
    expect(find.text('Thu, 29 Oct 2026 · 10:40 AM'), findsOneWidget);
    expect(find.textContaining('Today'), findsNothing);
  });

  testWidgets('the drinks, their options and line totals', (tester) async {
    await pumpReceipt(tester, order);
    expect(find.text('2 × Latte'), findsOneWidget);
    expect(find.text('Medium · Hot · Regular sugar'), findsOneWidget);
    expect(find.text(r'$7.00'), findsOneWidget);
    expect(find.text('1 × Espresso'), findsOneWidget);
    expect(find.text('Double shot · Hot · No sugar'), findsOneWidget);
    expect(find.text(r'$2.00'), findsOneWidget);
  });

  testWidgets('ASAP orders say so', (tester) async {
    final asap = Order(
      id: 12,
      status: OrderStatus.pendingPayment,
      pickupType: PickupType.asap,
      createdAt: order.createdAt,
      totalAmount: order.totalAmount,
      items: order.items,
    );
    await pumpReceipt(tester, asap);
    expect(find.text('As soon as possible'), findsOneWidget);
  });

  test('file name has the order and when it was made', () {
    expect(QrSaver.fileName(order), 'MOS-KHQR-order12-20261029-1012');
  });

  testWidgets('renders to a PNG 1080 px wide (3x), as tall as the receipt', (
    tester,
  ) async {
    late Uint8List png;
    await tester.runAsync(() async {
      png = await QrSaver.render(charge, order);
    });
    // PNG signature, then the IHDR chunk: width and height, big-endian.
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    final header = ByteData.sublistView(png, 16, 24);
    expect(header.getUint32(0), 1080);
    final height = header.getUint32(4);
    expect(height, greaterThan(1080)); // taller than wide: a receipt
    expect(height, lessThan(2400 * 3)); // not the whole target area
  });
}
