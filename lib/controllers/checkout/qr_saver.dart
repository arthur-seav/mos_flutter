import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../theme/app_colors.dart';

/// Renders KHQR data to a PNG and saves it to the photo library
/// ("Save QR to photos", SA §4.2.3.3). Wrapped behind a provider so
/// widget tests can swap in a fake instead of touching the real gallery.
class QrSaver {
  const QrSaver();

  /// Encodes [data] as a QR PNG and saves it as [name] (SA §4.2.3.3).
  Future<void> save(String data, String name) async {
    final qrImage = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L),
    );
    final bytes = await qrImage.toImageAsBytes(
      size: 1024,
      decoration: const PrettyQrDecoration(
        shape: PrettyQrSmoothSymbol(color: AppColors.espresso),
      ),
    );
    await Gal.putImageBytes(
      (bytes ?? ByteData(0)).buffer.asUint8List(),
      name: name,
    );
  }
}

final qrSaverProvider = Provider<QrSaver>((ref) => const QrSaver());
