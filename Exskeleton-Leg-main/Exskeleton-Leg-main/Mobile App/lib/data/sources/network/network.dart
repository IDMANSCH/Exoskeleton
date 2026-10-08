import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import 'package:flutter_starter/data/entities/auth_session.dart';
import 'package:flutter_starter/data/entities/request/login_params.dart';
import 'package:flutter_starter/data/entities/request/register_params.dart';
import 'package:flutter_starter/data/entities/account.dart';
import 'package:flutter_starter/data/entities/patient_home.dart';
import 'package:flutter_starter/data/sources/network/dio.dart';

@singleton
class NetworkDataSource {
  final NetworkDio _dio;

  NetworkDataSource(this._dio);

  Future<Account> login(LoginParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/login',
      data: params.toJson(),
    );
    final session = AuthSession.fromJson(_data(response.data));
    await _dio.persistSession(session);
    return session.user;
  }

  Future<Account> register(RegisterParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/register',
      data: params.toJson(),
    );
    final session = AuthSession.fromJson(_data(response.data));
    await _dio.persistSession(session);
    return session.user;
  }

  Future<Account> getCurrentAccount() async {
    final response = await _dio.get<Map<String, dynamic>>('me');
    return Account.fromJson(_data(response.data));
  }

  Future<PatientHome> getPatientHome(String patientId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'patients/$patientId/home',
    );
    return PatientHome.fromJson(_data(response.data));
  }

  Future<List<Map<String, dynamic>>> getTodayPlanItems(String patientId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'patients/$patientId/plan-items/today',
    );
    return _dataList(response.data);
  }

  Future<List<Map<String, dynamic>>> getPlanItems(String patientId,
      {String scope = 'today'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'patients/$patientId/plan-items',
      queryParameters: {'scope': scope},
    );
    return _dataList(response.data);
  }

  Future<Map<String, dynamic>> getProgressOverview(String patientId,
      {String period = 'week'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'patients/$patientId/progress/overview',
      queryParameters: {'period': period},
    );
    return _data(response.data);
  }

  Future<List<Map<String, dynamic>>> getPatientAlerts(String patientId,
      {int limit = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'patients/$patientId/alerts',
      queryParameters: {'limit': limit},
    );
    return _dataList(response.data);
  }

  Future<Map<String, dynamic>> completeTrainingSession({
    required String patientId,
    required String sessionId,
    required String planItemId,
    required String exerciseCode,
    required int completedRepetitions,
    required int activeSeconds,
    double correctnessRatio = 1,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'patients/$patientId/training-sessions/complete',
      data: {
        'session_id': sessionId,
        'plan_item_id': planItemId,
        'exercise_code': exerciseCode,
        'completed_repetitions': completedRepetitions,
        'active_seconds': activeSeconds,
        'correctness_ratio': correctnessRatio,
      },
    );
    return _data(response.data);
  }

  Future<List<Map<String, dynamic>>> getDevices(String patientId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'devices',
      queryParameters: {'patient_id': patientId},
    );
    return _dataList(response.data);
  }

  Future<void> registerFcmToken(String token) async {
    await _dio.post<Map<String, dynamic>>(
      'me/fcm-token',
      data: {'token': token, 'platform': 'android'},
    );
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _dio.get<Map<String, dynamic>>('me/notifications');
    return _dataList(response.data);
  }

  Future<List<Map<String, dynamic>>> getMotionLibrary() async {
    final response = await _dio.get<Map<String, dynamic>>('motion-library');
    return _dataList(response.data);
  }

  Future<List<Map<String, dynamic>>> getMotionRoutines(String patientId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'patients/$patientId/motion-routines',
    );
    return _dataList(response.data);
  }

  Future<Map<String, dynamic>> createMotionRoutine({
    required String patientId,
    required String name,
    String description = '',
    required int repetitions,
    String executionMode = 'ONE_LEG',
    String startingSide = 'RIGHT',
    required List<Map<String, dynamic>> steps,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'patients/$patientId/motion-routines',
      data: {
        'name': name,
        'description': description,
        'repetitions': repetitions,
        'execution_mode': executionMode,
        'starting_side': startingSide,
        'steps': steps,
      },
    );
    return _data(response.data);
  }

  Future<Map<String, dynamic>> dispatchMotionRoutine({
    required String patientId,
    required String routineId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'patients/$patientId/motion-routines/$routineId/dispatch',
    );
    return _data(response.data);
  }

  Future<Map<String, dynamic>> getPatient(String patientId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('patients/$patientId');
    return _data(response.data);
  }

  Future<void> logout() async {
    final refreshToken = await _dio.getRefreshToken();
    try {
      if (refreshToken != null) {
        await _dio.post<dynamic>(
          'auth/logout',
          data: {'refresh_token': refreshToken},
          options: Options(
            responseType: ResponseType.bytes,
            // Logout is best-effort; always clear the local session below.
            validateStatus: (status) => status == null || status < 500,
          ),
        );
      }
    } finally {
      await _dio.clearSession();
    }
  }

  Future<List<Map<String, dynamic>>> getRelationships() async {
    final response = await _dio.get<Map<String, dynamic>>('me/relationships');
    return _dataList(response.data);
  }

  Future<Map<String, dynamic>> inviteRelationship(String email) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'me/relationships/invite',
      data: {'email': email.trim().toLowerCase()},
    );
    return _data(response.data);
  }

  Future<Map<String, dynamic>> updateRelationship(
      String id, String action) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'me/relationships/$id/$action',
    );
    return _data(response.data);
  }

  Future<Map<String, dynamic>> reportFall({
    required String patientId,
    String message = '',
    String? alertId,
    String? deviceId,
    double? probability,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'patients/$patientId/alerts/fall',
      data: {
        'message': message,
        if (alertId != null && alertId.isNotEmpty) 'alert_id': alertId,
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
        if (probability != null) 'fall_probability': probability,
      },
    );
    return _data(response.data);
  }

  Map<String, dynamic> _data(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid API envelope');
  }

  List<Map<String, dynamic>> _dataList(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    throw const FormatException('Invalid API list envelope');
  }
}
