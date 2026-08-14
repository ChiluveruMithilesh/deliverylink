import '../../../core/network/api_client.dart';

class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _api.get('/auth/me');
    return res['data']['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? email,
    String? preferredLanguage,
  }) async {
    final res = await _api.patch('/auth/me', data: {
      if (fullName != null) 'fullName': fullName,
      if (email != null) 'email': email,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
    });
    return res['data']['user'] as Map<String, dynamic>;
  }
}