import 'package:flutter_starter/data/entities/account.dart';

class AuthSession {
  final String accessToken;
  final int accessTokenExpiresIn;
  final String refreshToken;
  final int refreshTokenExpiresIn;
  final Account user;

  const AuthSession({
    required this.accessToken,
    required this.accessTokenExpiresIn,
    required this.refreshToken,
    required this.refreshTokenExpiresIn,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['access_token'] as String,
    accessTokenExpiresIn: json['access_token_expires_in'] as int,
    refreshToken: json['refresh_token'] as String,
    refreshTokenExpiresIn: json['refresh_token_expires_in'] as int,
    user: Account.fromJson(json['user'] as Map<String, dynamic>),
  );
}
