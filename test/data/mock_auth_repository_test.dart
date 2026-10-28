import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/repositories/auth_repository.dart';

void main() {
  final repo = MockAuthRepository(latency: Duration.zero);
  const pw = MockAuthRepository.demoPassword;

  test('signs in by email, ignoring case', () async {
    final user = await repo.signIn(
      identifier: 'Dara@Example.com',
      password: pw,
    );
    expect(user.fullName, 'Dara Sok');
  });

  test('signs in by phone in another format', () async {
    final user = await repo.signIn(identifier: '+855 12 345 678', password: pw);
    expect(user.email, 'dara@example.com');
  });

  test('wrong password and unknown account give the same error', () async {
    Future<Object?> errorFor(String id, String p) async {
      try {
        await repo.signIn(identifier: id, password: p);
        return null;
      } on AuthException catch (e) {
        return e.message;
      }
    }

    final wrongPassword = await errorFor('dara@example.com', 'nope');
    final unknownUser = await errorFor('nobody@example.com', pw);
    expect(wrongPassword, isNotNull);
    expect(wrongPassword, unknownUser);
  });
}
