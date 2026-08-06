import '../../../core/network/api_client.dart';

class DriverRepository {
  DriverRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> getDashboard() async {
    final res = await _api.get('/driver/dashboard');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _api.get('/driver/profile');
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> setOnlineStatus(bool isOnline, {double? lat, double? lng}) async {
    await _api.patch('/driver/status', data: {'isOnline': isOnline, if (lat != null) 'lat': lat, if (lng != null) 'lng': lng});
  }

  Future<List<dynamic>> listNearbyTrips(double lat, double lng, {double radiusKm = 20}) async {
    final res = await _api.get('/trips/nearby', query: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radiusKm': radiusKm.toString(),
    });
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> placeBid(String tripId, double offeredAmount) async {
    final res = await _api.post('/trips/$tripId/bids', data: {'offeredAmount': offeredAmount});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmPickup(String tripId) async {
    final res = await _api.post('/trips/$tripId/confirm-pickup');
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> sendLocationPing(String tripId, double lat, double lng) async {
    await _api.post('/trips/$tripId/location', data: {'lat': lat, 'lng': lng});
  }

  Future<Map<String, dynamic>> arriveAtStop(String tripId, String stopId) async {
    final res = await _api.post('/trips/$tripId/stops/$stopId/arrive');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deliverStop(
    String tripId,
    String stopId, {
    required String photoUrl,
    required double capturedLat,
    required double capturedLng,
    String? otp,
  }) async {
    final res = await _api.post('/trips/$tripId/stops/$stopId/deliver', data: {
      'photoUrl': photoUrl,
      'capturedLat': capturedLat,
      'capturedLng': capturedLng,
      if (otp != null) 'otp': otp,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTripHistory() async {
    final res = await _api.get('/driver/trips/history');
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getEarningsReport() async {
    final res = await _api.get('/driver/reports/earnings');
    return res['data'] as Map<String, dynamic>;
  }
}
