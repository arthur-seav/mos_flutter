import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/saved_card.dart';
import '../../data/repository_providers.dart';
import '../cart/cart_controller.dart';
import 'payment_outcome.dart';

@immutable
class CardPaymentState {
  const CardPaymentState({
    required this.cards,
    this.selectedCardId,
    this.isPaying = false,
  });

  final List<SavedCard> cards;

  /// Null when there is no saved card yet.
  final int? selectedCardId;
  final bool isPaying;

  SavedCard? get selectedCard =>
      cards.where((c) => c.id == selectedCardId).firstOrNull;

  bool get canPay => selectedCard != null && !isPaying;

  CardPaymentState copyWith({
    List<SavedCard>? cards,
    int? selectedCardId,
    bool? isPaying,
  }) => CardPaymentState(
    cards: cards ?? this.cards,
    selectedCardId: selectedCardId ?? this.selectedCardId,
    isPaying: isPaying ?? this.isPaying,
  );
}

/// The card page for one order (SA §4.2.3.3): saved cards (last four
/// digits only), "add a new card", and paying with the chosen one.
final cardPaymentProvider = AsyncNotifierProvider.autoDispose
    .family<CardPaymentController, CardPaymentState, int>(
      CardPaymentController.new,
    );

class CardPaymentController extends AsyncNotifier<CardPaymentState> {
  CardPaymentController(this.orderId);

  final int orderId;

  @override
  Future<CardPaymentState> build() async {
    final cards = await ref.read(cardRepositoryProvider).fetchCards();
    return CardPaymentState(
      cards: cards,
      selectedCardId: cards.firstOrNull?.id,
    );
  }

  void selectCard(int cardId) {
    final s = state.value;
    if (s == null || s.cards.every((c) => c.id != cardId)) return;
    state = AsyncData(s.copyWith(selectedCardId: cardId));
  }

  /// Saves a new card and selects it. Throws CardException with a message
  /// for the form when the gateway refuses it.
  Future<SavedCard> addCard(NewCard card) async {
    final saved = await ref.read(cardRepositoryProvider).addCard(card);
    final cards = await ref.read(cardRepositoryProvider).fetchCards();
    final s = state.value ?? CardPaymentState(cards: cards);
    state = AsyncData(s.copyWith(cards: cards, selectedCardId: saved.id));
    return saved;
  }

  /// Charges the selected card. Returns the outcome for the success or
  /// failure page (a declined card is a failed outcome, TC-22).
  Future<PaymentOutcome?> pay() async {
    final s = state.value;
    final card = s?.selectedCard;
    if (s == null || card == null || s.isPaying) return null;
    state = AsyncData(s.copyWith(isPaying: true));
    try {
      final repo = ref.read(orderRepositoryProvider);
      final payment = await repo.payWithCard(orderId: orderId, cardId: card.id);
      final order = await repo.fetchOrder(orderId);
      if (payment.isPaid) ref.read(cartControllerProvider.notifier).clear();
      return PaymentOutcome(order: order, payment: payment);
    } finally {
      if (ref.mounted) {
        state = AsyncData(state.requireValue.copyWith(isPaying: false));
      }
    }
  }
}
