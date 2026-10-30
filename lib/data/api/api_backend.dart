import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

import '../repository_providers.dart';
import 'api_auth_repository.dart';
import 'api_client.dart';
import 'api_menu_repository.dart';
import 'api_order_repository.dart';

/// Which backend `main.dart` uses, chosen at build time:
///
/// ```sh
/// flutter run                                   # the Spring Boot API (default)
/// flutter run --dart-define=MOS_API_URL=http://192.168.1.20:8080   # a phone on Wi-Fi
/// flutter run --dart-define=MOS_BACKEND=mock    # the built-in demo data, no server
/// ```
const _backend = String.fromEnvironment('MOS_BACKEND', defaultValue: 'api');
const _apiUrl = String.fromEnvironment('MOS_API_URL');

bool get useMockBackend => _backend == 'mock';

/// Where the Spring Boot backend is, when `MOS_API_URL` is not given:
/// the Android emulator reaches the computer at 10.0.2.2; web, desktop and
/// the iOS simulator use localhost.
Uri apiBaseUrl() {
  if (_apiUrl.isNotEmpty) return Uri.parse(_apiUrl);
  final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
  return Uri.parse('http://$host:8080');
}

/// Every API repository, sharing one [ApiClient] (and so one sign-in token),
/// as provider overrides (NFR-09). The demo staff panel stays hidden: with a
/// real backend the store dashboard moves orders on.
class ApiBackend {
  ApiBackend({required Uri baseUrl, http.Client? client})
    : api = ApiClient(baseUrl: baseUrl, client: client);

  final ApiClient api;

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(ApiAuthRepository(api)),
    menuRepositoryProvider.overrideWithValue(ApiMenuRepository(api)),
    storeRepositoryProvider.overrideWithValue(ApiStoreRepository(api)),
    orderRepositoryProvider.overrideWithValue(ApiOrderRepository(api)),
    cardRepositoryProvider.overrideWithValue(ApiCardRepository(api)),
  ];
}
