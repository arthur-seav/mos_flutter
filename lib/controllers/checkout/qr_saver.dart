import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';

import '../../data/models/order.dart';
import '../../widgets/checkout/khqr_receipt.dart';

/// "Save QR to photos" (SA §4.2.3.3): draws [KhqrReceipt] (logo, QR,
/// order, drinks, dates) off screen and saves it to the photo library.
/// Behind a provider so widget tests can swap in a fake instead of
/// touching the real gallery.
class QrSaver {
  const QrSaver();

  /// "MOS-KHQR-order12-20261029-1012", so files sort by time too.
  static String fileName(Order order) =>
      'MOS-KHQR-order${order.id}-'
      '${DateFormat('yyyyMMdd-HHmm').format(order.createdAt)}';

  /// The receipt as a PNG, 1080 px wide.
  static Future<Uint8List> render(KhqrCharge charge, Order order) =>
      ScreenshotController().captureFromWidget(
        KhqrReceipt(charge: charge, order: order),
        pixelRatio: 3,
        // Room for a long order; the picture is as tall as the receipt.
        targetSize: const Size(KhqrReceipt.width, 2400),
        delay: const Duration(milliseconds: 100),
      );

  Future<void> save(KhqrCharge charge, Order order) async {
    final bytes = await render(charge, order);
    // An empty file would look "saved" but show nothing: fail instead.
    if (bytes.isEmpty) throw StateError('The receipt could not be drawn.');
    await Gal.putImageBytes(bytes, name: fileName(order));
  }
}

final qrSaverProvider = Provider<QrSaver>((ref) => const QrSaver());
