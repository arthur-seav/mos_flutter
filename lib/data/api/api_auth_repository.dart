import '../models/profile_update.dart';
import '../models/sign_up_request.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import 'api_client.dart';
import 'api_json.dart';

/// Customer accounts on the backend (`/api/app/auth/**`, `/api/app/me`).
///
/// Signing in or up stores the returned token in the shared [ApiClient];
/// signing out forgets it (tokens are stateless, SA FR-03 note in API.md).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<User> signIn({required String identifier, required String password}) =>
      _session('/api/app/auth/sign-in', {
        'identifier': identifier.trim(),
        'password': password,
      });

  @override
  Future<void> signOut() async => _api.token = null;

  @override
  Future<User> signUp(SignUpRequest request) {
    final name = request.splitName;
    return _session('/api/app/auth/sign-up', {
      'firstName': name.first,
      'lastName': name.last,
      'email': request.email,
      'phone': request.phone,
      'password': request.password,
    });
  }

  @override
  Future<PasswordResetTicket> verifyAccountForReset({required String phone}) =>
      _guard(() async {
        final json = await _api.post('/api/app/auth/reset/verify', {
          'phone': phone,
        });
        return PasswordResetTicket((json as Json)['ticket'] as String);
      });

  @override
  Future<void> resetPassword({
    required PasswordResetTicket ticket,
    required String newPassword,
  }) => _guard(
    () => _api.post('/api/app/auth/reset', {
      'ticket': ticket.token,
      'newPassword': newPassword,
    }),
  );

  @override
  Future<User> updateProfile(ProfileUpdate update) => _guard(() async {
    final name = update.splitName;
    final json = await _api.put('/api/app/me', {
      'firstName': name.first,
      'lastName': name.last,
      'email': update.email,
      'phone': update.phone,
      'dateOfBirth': dateTo(update.dateOfBirth),
    });
    return userFrom(json as Json);
  });

  @override
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) => _guard(
    () => _api.post('/api/app/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }),
  );

  Future<User> _session(String path, Json body) => _guard(() async {
    final json = await _api.post(path, body) as Json;
    _api.token = json['token'] as String;
    return userFrom(json['user'] as Json);
  });

  /// Every failure the user can act on becomes an [AuthException] with the
  /// backend's own message ("Incorrect email/phone or password.", ...).
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }
}
