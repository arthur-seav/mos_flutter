import '../../utils/card_validators.dart';
import '../models/saved_card.dart';
import '../repositories/card_repository.dart';

/// Saved cards without a payment gateway. Works like a gateway's test
/// mode: any number that passes the Luhn check is accepted, and
/// [declinedTestNumber] is saved but declined when charged (TC-22).
///
/// Only the last four digits are kept, never the number or the CVV.
class MockCardRepository implements CardRepository {
  MockCardRepository({
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _now;

  /// Charges to a card ending in these digits are declined.
  static const declinedTestNumber = '4000000000000002';

  final List<SavedCard> _cards = [
    const SavedCard(
      id: 1,
      brand: 'Visa',
      last4: '4242',
      expiryMonth: 9,
      expiryYear: 2028,
      holderName: 'DARA SOK',
    ),
  ];
  int _nextId = 2;

  /// For MockOrderRepository: would the gateway decline this card?
  bool isDeclined(int cardId) =>
      _cards.where((c) => c.id == cardId).firstOrNull?.last4 ==
      declinedTestNumber.substring(declinedTestNumber.length - 4);

  SavedCard? card(int cardId) =>
      _cards.where((c) => c.id == cardId).firstOrNull;

  @override
  Future<List<SavedCard>> fetchCards() async {
    await Future<void>.delayed(latency);
    return List.unmodifiable(_cards);
  }

  @override
  Future<SavedCard> addCard(NewCard card) async {
    await Future<void>.delayed(latency);
    if (!passesLuhn(card.number)) {
      throw const CardException('This card number is not valid.');
    }
    final now = _now();
    final lastDay = DateTime(card.expiryYear, card.expiryMonth + 1);
    if (!now.isBefore(lastDay)) {
      throw const CardException('This card has expired.');
    }
    final saved = SavedCard(
      id: _nextId++,
      brand: _brandOf(card.number),
      last4: card.number.substring(card.number.length - 4),
      expiryMonth: card.expiryMonth,
      expiryYear: card.expiryYear,
      holderName: card.holderName.trim().toUpperCase(),
    );
    _cards.add(saved);
    return saved;
  }

  static String _brandOf(String number) {
    if (number.startsWith('4')) return 'Visa';
    final two = int.tryParse(number.substring(0, 2)) ?? 0;
    final four = int.tryParse(number.substring(0, 4)) ?? 0;
    if ((two >= 51 && two <= 55) || (four >= 2221 && four <= 2720)) {
      return 'Mastercard';
    }
    return 'Card';
  }
}
