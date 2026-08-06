import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/offline_queue.dart';
import '../data/driver_repository.dart';
import '../presentation/providers/driver_provider.dart';

/// Wraps driver GPS ping delivery with an offline-first fallback:
/// - try sending immediately
/// - on network failure, queue it locally (Hive)
/// - flush the queue automatically whenever connectivity returns
///
/// This satisfies "Offline mode with automatic synchronisation" for the
/// driver app's location tracking, which is the write path most likely
/// to happen while a driver is out of signal range mid-delivery.
class OfflineSyncService {
  OfflineSyncService(this._driverRepository, this._offlineQueue) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline) {
        flushQueue();
      }
    });
  }

  final DriverRepository _driverRepository;
  final OfflineQueue _offlineQueue;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Sends a location ping immediately if possible; queues it for later
  /// sync if the device is offline or the request fails.
  Future<void> sendLocationPing(String tripId, double lat, double lng) async {
    try {
      await _driverRepository.sendLocationPing(tripId, lat, lng);
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        await _offlineQueue.enqueueLocationPing(
          QueuedLocationPing(tripId: tripId, lat: lat, lng: lng, recordedAt: DateTime.now()),
        );
      }
      // Non-network errors (e.g. 403 - trip no longer yours) are dropped
      // rather than retried forever.
    }
  }

  /// Replays every queued ping in order. Stops on the first network
  /// failure (connectivity may have dropped again) but keeps going
  /// past non-network errors so one bad entry can't block the rest.
  Future<void> flushQueue() async {
    final pending = _offlineQueue.getAllPending();
    for (final entry in pending) {
      try {
        await _driverRepository.sendLocationPing(
          entry.value.tripId,
          entry.value.lat,
          entry.value.lng,
        );
        await _offlineQueue.remove(entry.key);
      } on ApiException catch (e) {
        if (e.isNetworkError) break;
        await _offlineQueue.remove(entry.key);
      }
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

final offlineSyncServiceProvider = Provider.autoDispose<AsyncValue<OfflineSyncService>>((ref) {
  final queueAsync = ref.watch(offlineQueueProvider);
  return queueAsync.whenData((queue) {
    final service = OfflineSyncService(ref.watch(driverRepositoryProvider), queue);
    ref.onDispose(service.dispose);
    return service;
  });
});
