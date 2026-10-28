import '../../core/utils/validators.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

/// In-memory accounts for building and demoing the app without a backend.
///
/// Every demo account uses [demoPassword]. Passwords are compared in plain
/// text here only because this is fake data; the real backend stores hashes
/// (NFR-05).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 600)});

  /// Fake network delay so loading states can be seen. Tests pass zero.
  final Duration latency;

  static const demoPassword = 'password123';

  static const _accounts = <User>[
    User(
      id: 1,
      firstName: 'Dara',
      lastName: 'Sok',
      email: 'dara@example.com',
      phone: '012345678',
      role: UserRole.customer,
    ),
    User(
      id: 2,
      firstName: 'Sreyneang',
      lastName: 'Chan',
      phone: '098765432',
      role: UserRole.customer,
    ),
    User(
      id: 3,
      firstName: 'Visal',
      lastName: 'Kim',
      email: 'inactive@example.com',
      role: UserRole.customer,
      status: AccountStatus.inactive,
    ),
    User(
      id: 4,
      firstName: 'Bopha',
      lastName: 'Lim',
      email: 'staff@mos.coffee',
      role: UserRole.staff,
    ),
  ];

  @override
  Future<User> signIn({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final user = _find(identifier);
    if (user == null || password != demoPassword) {
      // Same message for both cases, so the screen does not reveal
      // which emails or phone numbers have an account.
      throw const AuthException('Incorrect email/phone or password.');
    }
    return user;
  }

  @override
  Future<void> signOut() => Future<void>.delayed(latency);

  User? _find(String identifier) {
    final value = identifier.trim();
    if (isEmail(value)) {
      final email = value.toLowerCase();
      return _accounts.where((u) => u.email == email).firstOrNull;
    }
    final phone = normalizePhone(value);
    return _accounts.where((u) => u.phone == phone).firstOrNull;
  }
}
