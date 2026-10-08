import 'package:injectable/injectable.dart';
import 'package:flutter_starter/core/exception.dart';
import 'package:flutter_starter/data/entities/account.dart';
import 'package:flutter_starter/data/entities/request/login_params.dart';
import 'package:flutter_starter/data/entities/request/register_params.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/repositories/auth_repository/exceptions.dart';
import 'package:flutter_starter/data/sources/network/network.dart';

@Singleton(as: AuthRepository)
class DefaultAuthRepository extends AuthRepository {
  final NetworkDataSource _networkDataSource;

  DefaultAuthRepository({required NetworkDataSource networkDataSource})
    : _networkDataSource = networkDataSource;

  @override
  Future<Account> verifyLoginStatus() async {
    return _networkDataSource.getCurrentAccount();
  }

  @override
  Future<Account> login({
    required String email,
    required String password,
  }) async {
    try {
      final account = await _networkDataSource.login(
        LoginParams(email: email.trim().toLowerCase(), password: password),
      );

      return account;
    } on UnauthorizedException {
      throw LoginInvalidEmailPasswordException();
    }
  }

  @override
  Future<Account> register({
    required String email,
    required String password,
    required String displayName,
    required bool acceptedTerms,
    String role = 'patient',
  }) async {
    if (!acceptedTerms) throw TermsNotAcceptedException();
    try {
      return await _networkDataSource.register(
        RegisterParams(
          email: email.trim().toLowerCase(),
          password: password,
          displayName: displayName.trim(),
          role: role,
        ),
      );
    } on ApiException catch (error) {
      if (error.code == 'identity.email_already_exists') {
        throw EmailAlreadyExistsException();
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() => _networkDataSource.logout();
}
