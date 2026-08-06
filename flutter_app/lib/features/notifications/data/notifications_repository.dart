import '../../../core/network/api_client.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<List<dynamic>> list({int page = 1, int limit = 20}) async {
    final res = await _api.get('/notifications', query: {'page': '$page', 'limit': '$limit'});
    return res['data'] as List<dynamic>;
  }

  Future<void> markAsRead(String notificationId) async {
    await _api.patch('/notifications/$notificationId/read');
  }

  Future<void> registerDeviceToken(String fcmToken, String platform) async {
    await _api.post('/notifications/device-token', data: {'fcmToken': fcmToken, 'platform': platform});
  }
}
