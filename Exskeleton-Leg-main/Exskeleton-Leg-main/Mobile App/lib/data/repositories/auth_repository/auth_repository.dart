import 'package:flutter_starter/data/entities/account.dart';

abstract class AuthRepository {
  Future<Account> verifyLoginStatus();

  Future<Account> login({required String email, required String password});

  Future<Account> register({
    required String email,
    required String password,
    required String displayName,
    required bool acceptedTerms,
    String role = 'patient',
  });

  Future<void> logout();
}
