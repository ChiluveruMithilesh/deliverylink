import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../storage/offline_queue.dart';
import '../storage/secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(secureStorageProvider));
});

/// Hive-backed queue for writes (like GPS pings) made while offline.
/// Opened once and kept alive for the app's lifetime.
final offlineQueueProvider = FutureProvider<OfflineQueue>((ref) => OfflineQueue.open());

/// App-wide theme mode (persisted via SharedPreferences in a real build;
/// kept in memory here as the default, toggleable from Settings).
final themeModeProvider = StateProvider<bool>((ref) => false); // false = light, true = dark

/// App-wide locale: 'en' or 'te'.
final localeProvider = StateProvider<String>((ref) => 'en');
