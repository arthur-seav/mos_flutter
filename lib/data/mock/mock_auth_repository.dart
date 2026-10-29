import '../../utils/validators.dart';
import '../models/profile_update.dart';
import '../models/sign_up_request.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

/// In-memory accounts for building and demoing the app without a backend.
///
/// Accounts created with [signUp] and passwords changed with
/// [resetPassword] last until the app is closed.
///
/// Passwords are kept in plain text here only because this is fake data;
/// the real backend stores hashes (NFR-05).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 600)}) {
    for (final user in _seedUsers) {
      _accounts[user.id] = (user: user, password: demoPassword);
    }
  }

  /// Fake network delay so loading states can be seen. Tests pass zero.
  final Duration latency;

  /// Password of every built-in demo account.
  static const demoPassword = 'password123';

  /// The demo customer (dara@example.com), who has past orders.
  static const daraId = 1;

  static const _seedUsers = <User>[
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

  final _accounts = <int, ({User user, String password})>{};

  /// Who is signed in, as the backend would know from the token. Orders
  /// use it for `orders.customer_id`.
  int? signedInUserId;

  /// Reset tickets handed out by [verifyAccountForReset], by token.
  final _resetTickets = <String, int>{};
  int _ticketCounter = 0;

  @override
  Future<User> signIn({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final account = _findByIdentifier(identifier);
    if (account == null || account.password != password) {
      // Same message for both cases, so the screen does not reveal
      // which emails or phone numbers have an account.
      throw const AuthException('Incorrect email/phone or password.');
    }
    signedInUserId = account.user.id;
    return account.user;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(latency);
    signedInUserId = null;
  }

  @override
  Future<User> signUp(SignUpRequest request) async {
    await Future<void>.delayed(latency);
    final email = request.email?.trim().toLowerCase();
    final phone = request.phone == null ? null : normalizePhone(request.phone!);

    if (email != null && _findByEmail(email) != null) {
      throw const AuthException('This email is already registered.');
    }
    if (phone != null && _findByPhone(phone) != null) {
      throw const AuthException('This phone number is already registered.');
    }

    final name = request.splitName;
    final user = User(
      id: _accounts.keys.fold(0, (max, id) => id > max ? id : max) + 1,
      firstName: name.first,
      lastName: name.last,
      email: email,
      phone: phone,
      role: UserRole.customer,
    );
    _accounts[user.id] = (user: user, password: request.password);
    signedInUserId = user.id;
    return user;
  }

  @override
  Future<PasswordResetTicket> verifyAccountForReset({
    required String phone,
  }) async {
    await Future<void>.delayed(latency);
    final account = _findByPhone(normalizePhone(phone));
    if (account == null || !account.user.isCustomer) {
      throw const AuthException('Account not found.');
    }
    final token = 'mock-reset-${++_ticketCounter}';
    _resetTickets[token] = account.user.id;
    return PasswordResetTicket(token);
  }

  @override
  Future<void> resetPassword({
    required PasswordResetTicket ticket,
    required String newPassword,
  }) async {
    await Future<void>.delayed(latency);
    // A ticket works once, like the real backend's short-lived token.
    final userId = _resetTickets.remove(ticket.token);
    final account = userId == null ? null : _accounts[userId];
    if (account == null) {
      throw const AuthException(
        'This reset link has expired. Please start again.',
      );
    }
    _accounts[userId!] = (user: account.user, password: newPassword);
  }

  @override
  Future<User> updateProfile(ProfileUpdate update) async {
    await Future<void>.delayed(latency);
    final account = _accounts[update.userId];
    if (account == null) throw const AuthException('Account not found.');
    final email = _blankToNull(update.email)?.toLowerCase();
    final phone = _blankToNull(update.phone);
    final normalized = phone == null ? null : normalizePhone(phone);
    if (email == null && normalized == null) {
      throw const AuthException('Keep an email or a phone number.');
    }
    final emailOwner = email == null ? null : _findByEmail(email);
    if (emailOwner != null && emailOwner.user.id != update.userId) {
      throw const AuthException('This email is already registered.');
    }
    final phoneOwner = normalized == null ? null : _findByPhone(normalized);
    if (phoneOwner != null && phoneOwner.user.id != update.userId) {
      throw const AuthException('This phone number is already registered.');
    }
    final name = update.splitName;
    final old = account.user;
    final user = User(
      id: old.id,
      firstName: name.first,
      lastName: name.last,
      role: old.role,
      email: email,
      phone: normalized,
      dateOfBirth: update.dateOfBirth,
      status: old.status,
    );
    _accounts[user.id] = (user: user, password: account.password);
    return user;
  }

  @override
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(latency);
    final account = _accounts[userId];
    if (account == null || account.password != currentPassword) {
      throw const AuthException('Your current password is incorrect.');
    }
    _accounts[userId] = (user: account.user, password: newPassword);
  }

  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  ({User user, String password})? _findByIdentifier(String identifier) {
    final value = identifier.trim();
    return isEmail(value)
        ? _findByEmail(value.toLowerCase())
        : _findByPhone(normalizePhone(value));
  }

  ({User user, String password})? _findByEmail(String email) =>
      _accounts.values.where((a) => a.user.email == email).firstOrNull;

  ({User user, String password})? _findByPhone(String phone) =>
      _accounts.values.where((a) => a.user.phone == phone).firstOrNull;
}
