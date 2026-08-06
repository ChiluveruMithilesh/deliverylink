import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthResult {
  AuthResult({required this.user, required this.accessToken, required this.refreshToken});
  final UserModel user;
  final String accessToken;
  final String refreshToken;
}

class AuthRepository {
  AuthRepository(this._api, this._secureStorage);

  final ApiClient _api;
  final SecureStorage _secureStorage;

  Future<AuthResult> login({required String phone, required String password}) async {
    final response = await _api.post('/auth/login', data: {'phone': phone, 'password': password});
    return _handleAuthResponse(response);
  }

  Future<AuthResult> register(Map<String, dynamic> payload) async {
    final response = await _api.post('/auth/register', data: payload);
    return _handleAuthResponse(response);
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _api.get('/auth/me');
    return UserModel.fromJson(response['data']['user'] as Map<String, dynamic>);
  }

  Future<void> logout() => _secureStorage.clearTokens();

  Future<bool> hasValidSession() async {
    final token = await _secureStorage.getAccessToken();
    return token != null;
  }

  Future<AuthResult> _handleAuthResponse(Map<String, dynamic> response) async {
    final data = response['data'] as Map<String, dynamic>;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    await _secureStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

    return AuthResult(user: user, accessToken: accessToken, refreshToken: refreshToken);
  }
}
