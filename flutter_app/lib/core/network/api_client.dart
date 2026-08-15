import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio providing:
/// - automatic Bearer token attachment
/// - automatic access-token refresh on 401 (single retry)
/// - normalized ApiException on every failure path
class ApiClient {
  ApiClient(this._secureStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_isRefreshing) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final clonedRequest = await _retry(error.requestOptions);
              return handler.resolve(clonedRequest);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final SecureStorage _secureStorage;
  bool _isRefreshing = false;

  Future<bool> _tryRefreshToken() async {
    _isRefreshing = true;
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = response.data['data'];
      await _secureStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await _secureStorage.clearTokens();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response> _retry(RequestOptions requestOptions) {
    final token = _secureStorage.getAccessToken();
    return token.then((t) {
      final options = Options(method: requestOptions.method, headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $t',
      });
      return _dio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: options,
      );
    });
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    if (e.response == null) {
      return ApiException(message: 'Unable to reach the server. Check your connection.');
    }

    final body = e.response!.data;
    final errorObj = body is Map ? body['error'] as Map<String, dynamic>? : null;
    final genericMessage = errorObj?['message'] as String? ?? 'Something went wrong';
    final details = (errorObj?['details'] as List?) ?? [];
    final fieldErrors = details.map((d) => FieldError.fromJson(d as Map<String, dynamic>)).toList();

    // When the server rejects specific fields (e.g. "phone must be a valid
    // 10-digit number"), show that exact reason instead of the generic
    // "Validation failed" - it's the difference between a user knowing
    // what to fix and just seeing a dead end.
    final displayMessage =
        fieldErrors.isNotEmpty ? fieldErrors.map((f) => f.message).join('\n') : genericMessage;

    return ApiException(
      message: displayMessage,
      statusCode: e.response!.statusCode,
      fieldErrors: fieldErrors,
    );
  }
}
