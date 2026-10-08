import 'dart:io';

import 'package:flutter_starter/core/exception.dart';
import 'package:flutter_starter/data/entities/auth_session.dart';
import 'package:flutter_starter/data/repositories/auth_repository/exceptions.dart';
import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_starter/services/oauth_token_manager/oauth_token_manager.dart';

@singleton
class NetworkDio extends DioForNative implements Interceptor {
  final OauthTokenManager _tokenManager;
  Future<void>? _refreshing;

  NetworkDio._(this._tokenManager, BaseOptions options) : super(options);

  @factoryMethod
  factory NetworkDio({
    required OauthTokenManager tokenManager,
    @Named('baseUrl') required String baseUrl,
  }) {
    final BaseOptions options = BaseOptions(
      baseUrl: baseUrl,
      contentType: 'application/json; charset=utf-8',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
    );

    final instance = NetworkDio._(tokenManager, options);

    instance.interceptors.add(instance);

    return instance;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isPublicAuthRequest = options.path == 'auth/login' ||
        options.path == 'auth/register' ||
        options.path == 'auth/refresh';
    if (isPublicAuthRequest) return handler.next(options);

    return handler.next(
      options.copyWith(
        headers: await _tokenManager.getAuthenticatedHeaders(options.headers),
      ),
    );
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final errorType = err.type;
    final responseData = err.response?.data;

    if (err.error is SocketException ||
        errorType == DioExceptionType.connectionTimeout ||
        errorType == DioExceptionType.receiveTimeout ||
        errorType == DioExceptionType.sendTimeout) {
      return handler.next(NetworkException());
    }

    final isUnauthorized = err.response?.statusCode == 401;
    final path = err.requestOptions.path;
    final canRefresh = isUnauthorized &&
        path != 'auth/login' &&
        path != 'auth/register' &&
        path != 'auth/refresh' &&
        path != 'auth/logout';

    if (canRefresh && await _tokenManager.getRefreshToken() != null) {
      final refresh = _refreshing ??= _refreshAccessToken();
      try {
        await refresh;
        final headers = Map<String, dynamic>.from(err.requestOptions.headers)
          ..remove('Authorization');
        final retryOptions = err.requestOptions.copyWith(
          headers: await _tokenManager.getAuthenticatedHeaders(headers),
        );
        return handler.resolve(await fetch<dynamic>(retryOptions));
      } catch (_) {
        await _tokenManager.removeAllTokens();
        return handler.next(UnauthorizedException(data: responseData));
      } finally {
        if (identical(_refreshing, refresh)) _refreshing = null;
      }
    }

    if (isUnauthorized) {
      await _tokenManager.removeAllTokens();
      return handler.next(UnauthorizedException(data: responseData));
    }

    if (responseData is Map) {
      final error = responseData['error'];
      if (error is Map) {
        return handler.next(
          ApiException(
            message: error['message'] as String?,
            code: error['code'] as String?,
            data: error['details'],
            response: err.response,
          ),
        );
      }
    }

    return handler.next(err);
  }

  Future<void> persistSession(AuthSession session) async {
    await _tokenManager.saveAccessToken(session.accessToken);
    await _tokenManager.saveRefreshToken(session.refreshToken);
  }

  Future<String?> getRefreshToken() => _tokenManager.getRefreshToken();

  Future<void> clearSession() => _tokenManager.removeAllTokens();

  Future<void> _refreshAccessToken() async {
    final refreshToken = await _tokenManager.getRefreshToken();
    if (refreshToken == null) throw UnauthorizedException();

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: options.baseUrl,
        contentType: 'application/json; charset=utf-8',
        connectTimeout: options.connectTimeout,
        receiveTimeout: options.receiveTimeout,
      ),
    );
    final response = await refreshDio.post<Map<String, dynamic>>(
      'auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    final envelope = response.data;
    final data = envelope?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid refresh response');
    }
    await persistSession(AuthSession.fromJson(data));
  }
}
