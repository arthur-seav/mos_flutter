import 'package:flutter_riverpod/misc.dart' show Override;

import '../../utils/clock.dart';
import '../repository_providers.dart';
import 'demo_staff.dart';
import 'mock_auth_repository.dart';
import 'mock_card_repository.dart';
import 'mock_menu_repository.dart';
import 'mock_order_repository.dart';
import 'mock_store_repository.dart';

/// Every mock repository, wired to each other the way the backend's
/// tables are (orders read the menu, the store and the cards), as
/// provider overrides (NFR-09).
///
/// `main.dart` turns on the automatic staff ([StaffTimings]); tests
/// leave them off, pass zero latency and a fixed [clock].
class MockBackend {
  MockBackend({
    Duration latency = const Duration(milliseconds: 600),
    DateTime Function()? clock,
    Duration? khqrPaysAfter = const Duration(seconds: 5),
    StaffTimings? staffTimings,
    bool seedHistory = false,
    MockMenuRepository? menu,
  }) : clock = clock ?? DateTime.now,
       auth = MockAuthRepository(latency: latency),
       menu = menu ?? MockMenuRepository(latency: latency),
       store = MockStoreRepository(latency: latency ~/ 2) {
    cards = MockCardRepository(latency: latency, clock: this.clock);
    orders = MockOrderRepository(
      menu: this.menu,
      store: store,
      cards: cards,
      latency: latency,
      khqrPaysAfter: khqrPaysAfter,
      staffTimings: staffTimings,
      currentCustomerId: () => auth.signedInUserId,
      clock: this.clock,
    );
    if (seedHistory) orders.seedHistory(customerId: MockAuthRepository.daraId);
  }

  final DateTime Function() clock;
  final MockAuthRepository auth;
  final MockMenuRepository menu;
  final MockStoreRepository store;
  late final MockCardRepository cards;
  late final MockOrderRepository orders;

  List<Override> get overrides => [
    clockProvider.overrideWithValue(clock),
    authRepositoryProvider.overrideWithValue(auth),
    menuRepositoryProvider.overrideWithValue(menu),
    storeRepositoryProvider.overrideWithValue(store),
    cardRepositoryProvider.overrideWithValue(cards),
    orderRepositoryProvider.overrideWithValue(orders),
    demoStaffProvider.overrideWithValue(orders),
  ];
}
