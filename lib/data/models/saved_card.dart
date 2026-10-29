import 'package:flutter/foundation.dart' show immutable;

/// A card saved for paying (`saved_cards`). The full number and the CVV
/// are never kept: the gateway returns a token and the app shows only the
/// last four digits (SA §4.2.3.3).
@immutable
class SavedCard {
  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    this.holderName,
  });

  final int id;

  /// "Visa", "Mastercard".
  final String brand;
  final String last4;
  final int expiryMonth;

  /// Four digits, e.g. 2028.
  final int expiryYear;

  /// Shown on the card picture (Figma). Not in the data dictionary yet
  /// (README: Open questions).
  final String? holderName;

  /// "•••• •••• •••• 4242": last four digits only (SA).
  String get maskedNumber => '•••• •••• •••• $last4';

  /// "09/28"
  String get expiry =>
      '${expiryMonth.toString().padLeft(2, '0')}/'
      '${(expiryYear % 100).toString().padLeft(2, '0')}';
}

/// What the customer types to add a card. Sent to the payment gateway to
/// be turned into a token; never stored by the app.
@immutable
class NewCard {
  const NewCard({
    required this.number,
    required this.holderName,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cvv,
  });

  /// Digits only.
  final String number;
  final String holderName;
  final int expiryMonth;
  final int expiryYear;
  final String cvv;
}
