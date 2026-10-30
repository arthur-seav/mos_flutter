import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/product.dart';
import 'package:mos_app/widgets/menu/product_image.dart';
import 'package:mos_app/widgets/menu/product_tile.dart';

const _latteUrl = 'http://10.0.2.2:8080/demo-images/latte.jpg';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

/// The NetworkImage URLs currently on screen.
Iterable<String> _networkUrls(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((i) => i.image)
    .map((p) => p is ResizeImage ? p.imageProvider : p)
    .whereType<NetworkImage>()
    .map((n) => n.url);

void main() {
  testWidgets('no photo: the Latte square with a cup, no network request', (
    tester,
  ) async {
    await _pump(tester, const ProductImage(width: 72, height: 72));
    expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'a photo URL loads that photo, with the cup shown until it arrives',
    (tester) async {
      await _pump(
        tester,
        const ProductImage(imageUrl: _latteUrl, width: 72, height: 72),
      );
      expect(_networkUrls(tester), [_latteUrl]);
      // Not decoded yet in the test: the placeholder stands in.
      expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    },
  );

  testWidgets('a photo that cannot be loaded falls back to the cup', (
    tester,
  ) async {
    await _pump(
      tester,
      const ProductImage(
        imageUrl: 'http://10.0.2.2:8080/demo-images/missing.jpg',
        width: 72,
        height: 72,
      ),
    );
    // flutter_test answers every HTTP request with 400, like a missing file.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a menu row shows the drink\'s own photo', (tester) async {
    await _pump(
      tester,
      ProductTile(
        product: const Product(
          id: 7,
          categoryId: 1,
          name: 'Latte',
          basePrice: Money.cents(300),
          imageUrl: _latteUrl,
        ),
        onAdd: () {},
      ),
    );
    expect(_networkUrls(tester), [_latteUrl]);
  });
}
