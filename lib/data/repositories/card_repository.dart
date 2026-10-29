import '../models/saved_card.dart';

/// Thrown when a card cannot be saved, with a message for the customer.
class CardException implements Exception {
  const CardException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The signed-in customer's saved cards (`saved_cards`).
abstract interface class CardRepository {
  Future<List<SavedCard>> fetchCards();

  /// Sends the card to the payment gateway and saves the token it returns.
  /// Throws [CardException] when the gateway refuses it.
  Future<SavedCard> addCard(NewCard card);
}
