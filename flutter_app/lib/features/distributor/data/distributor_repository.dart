import '../../../core/network/api_client.dart';

class DistributorRepository {
  DistributorRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> getDashboard() async {
    final res = await _api.get('/distributor/dashboard');
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> listTrips({String? status}) async {
    final res = await _api.get('/trips', query: status != null ? {'status': status} : null);
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getTrip(String tripId) async {
    final res = await _api.get('/trips/$tripId');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTrip(Map<String, dynamic> payload) async {
    final res = await _api.post('/trips', data: payload);
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> publishTrip(String tripId) async {
    final res = await _api.post('/trips/$tripId/publish');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelTrip(String tripId, {String? reason}) async {
    final res = await _api.post('/trips/$tripId/cancel', data: {
      if (reason != null) 'reason': reason,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> listBids(String tripId) async {
    final res = await _api.get('/trips/$tripId/bids');
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> selectBid(String tripId, String bidId) async {
    final res = await _api.post('/trips/$tripId/bids/$bidId/select');
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> searchShops(String query) async {
    final res = await _api.get('/distributor/shops/search', query: {'q': query});
    return res['data'] as List<dynamic>;
  }
  
  /// Looks up a shopkeeper's registered shop(s) by their unique code
  /// (e.g. "DL-7K2M9X"). Returns the shopkeeper's name plus every shop
  /// they've registered - usually one, occasionally more than one.
  Future<Map<String, dynamic>> lookupShopByCode(String code) async {
    final res = await _api.get('/distributor/shops/by-code', query: {'code': code});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReports({String? fromDate, String? toDate}) async {
    final res = await _api.get('/distributor/reports', query: {
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> trackTrip(String tripId) async {
    final res = await _api.get('/trips/$tripId/track');
    return res['data'] as Map<String, dynamic>;
  }
}
