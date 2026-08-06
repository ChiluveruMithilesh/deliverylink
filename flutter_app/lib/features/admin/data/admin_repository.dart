import '../../../core/network/api_client.dart';

class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> getAnalytics() async {
    final res = await _api.get('/admin/analytics');
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> listPendingDrivers() async {
    final res = await _api.get('/admin/drivers/pending');
    return res['data'] as List<dynamic>;
  }

  Future<void> reviewDriver(String driverId, String decision) async {
    await _api.patch('/admin/drivers/$driverId/review', data: {'decision': decision});
  }

  Future<List<dynamic>> listUsers({String? role, String? search}) async {
    final res = await _api.get('/admin/users', query: {
      if (role != null) 'role': role,
      if (search != null) 'search': search,
    });
    return res['data'] as List<dynamic>;
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    await _api.patch('/admin/users/$userId/active', data: {'isActive': isActive});
  }

  Future<List<dynamic>> listAllTrips({String? status}) async {
    final res = await _api.get('/admin/trips', query: status != null ? {'status': status} : null);
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> listPricingRules() async {
    final res = await _api.get('/admin/pricing-rules');
    return res['data'] as List<dynamic>;
  }
}
