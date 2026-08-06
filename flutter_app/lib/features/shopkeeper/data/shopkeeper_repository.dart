import '../../../core/network/api_client.dart';

class ShopkeeperRepository {
  ShopkeeperRepository(this._api);
  final ApiClient _api;

  Future<List<dynamic>> listMyShops() async {
    final res = await _api.get('/shopkeeper/shops');
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> addShop(Map<String, dynamic> payload) async {
    final res = await _api.post('/shopkeeper/shops', data: payload);
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTodaysDeliveries() async {
    final res = await _api.get('/shopkeeper/deliveries/today');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getDeliveryHistory() async {
    final res = await _api.get('/shopkeeper/deliveries/history');
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> trackTrip(String tripId) async {
    final res = await _api.get('/trips/$tripId/track');
    return res['data'] as Map<String, dynamic>;
  }
}
