import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_order_repository.dart';

/// The mock "staff" for the demo panel on the tracking page: confirm,
/// move on or reject an order by hand (TC-24, TC-26, TC-27). Null with a
/// real backend, so the panel is not shown.
final demoStaffProvider = Provider<MockOrderRepository?>((ref) => null);
