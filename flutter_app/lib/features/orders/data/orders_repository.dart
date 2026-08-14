import '../../../core/network/api_client.dart';

class OrdersRepository {
  OrdersRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> sendOrderRequest({
    required String distributorCode,
    required String message,
  }) async {
    final res = await _api.post('/orders', data: {
      'distributorCode': distributorCode,
      'message': message,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> listSent() async {
    final res = await _api.get('/orders/sent');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> listReceived({String? status}) async {
    final res = await _api.get('/orders/received', query: status != null ? {'status': status} : null);
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateStatus(String requestId, String status) async {
    final res = await _api.patch('/orders/$requestId/status', data: {'status': status});
    return res['data'] as Map<String, dynamic>;
  }
}