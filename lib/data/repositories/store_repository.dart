import '../models/store_info.dart';

/// Store settings and opening hours (FR-36, FR-37, FR-40, FR-41).
abstract interface class StoreRepository {
  /// Read again before every checkout, so a pause (TC-20) shows at once.
  Future<StoreInfo> fetchStoreInfo();
}
