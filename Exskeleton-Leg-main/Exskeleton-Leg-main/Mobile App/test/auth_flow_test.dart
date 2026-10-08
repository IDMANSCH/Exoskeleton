import 'package:flutter_starter/data/entities/account.dart';
import 'package:flutter_starter/data/entities/auth_session.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/presenter/pages/register/register_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the documented auth response without exposing token on Account',
      () {
    final session = AuthSession.fromJson({
      'access_token': 'access-token',
      'access_token_expires_in': 900,
      'refresh_token': 'refresh-token',
      'refresh_token_expires_in': 2592000,
      'user': {
        'id': '01900000-0000-7000-8000-000000000001',
        'display_name': 'Nguyễn An',
        'roles': ['patient'],
      },
    });

    expect(session.accessTokenExpiresIn, 900);
    expect(session.user.displayName, 'Nguyễn An');
    expect(session.user.roles, ['patient']);
  });

  test('register cubit emits the authenticated patient account', () async {
    final repository = _FakeAuthRepository();
    final cubit = RegisterCubit(repository);
    final states = <RegisterState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.register(
      displayName: 'Nguyễn An',
      email: 'user@example.com',
      password: 'strong-password',
      acceptedTerms: true,
    );
    await Future<void>.delayed(Duration.zero);

    expect(states.map((state) => state.status), [
      RegisterStatus.submitting,
      RegisterStatus.success,
    ]);
    expect(states.last.account?.roles, ['patient']);
    expect(repository.registerCalls, 1);

    await subscription.cancel();
    await cubit.close();
  });
}

class _FakeAuthRepository implements AuthRepository {
  int registerCalls = 0;

  @override
  Future<Account> register({
    required String email,
    required String password,
    required String displayName,
    required bool acceptedTerms,
    String role = 'patient',
  }) async {
    registerCalls += 1;
    return Account(
      id: '01900000-0000-7000-8000-000000000001',
      displayName: displayName,
      roles: const ['patient'],
      email: email,
    );
  }

  @override
  Future<Account> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<Account> verifyLoginStatus() => throw UnimplementedError();
}
