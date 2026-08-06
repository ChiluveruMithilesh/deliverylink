import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

/// A single queued location ping, kept until it's successfully synced.
class QueuedLocationPing {
  QueuedLocationPing({
    required this.tripId,
    required this.lat,
    required this.lng,
    required this.recordedAt,
  });

  final String tripId;
  final double lat;
  final double lng;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'lat': lat,
        'lng': lng,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory QueuedLocationPing.fromJson(Map<String, dynamic> json) => QueuedLocationPing(
        tripId: json['tripId'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}

/// Queues driver GPS pings (and other write actions) locally when the
/// device is offline, per the "Offline mode with automatic
/// synchronisation" requirement. Backed by a Hive box so the queue
/// survives app restarts, not just connectivity blips.
class OfflineQueue {
  OfflineQueue(this._box);

  final Box<String> _box;

  static Future<OfflineQueue> open() async {
    final box = await Hive.openBox<String>(HiveBoxes.offlineQueue);
    return OfflineQueue(box);
  }

  Future<void> enqueueLocationPing(QueuedLocationPing ping) async {
    final key = 'ping_${DateTime.now().microsecondsSinceEpoch}';
    await _box.put(key, jsonEncode(ping.toJson()));
  }

  List<MapEntry<String, QueuedLocationPing>> getAllPending() {
    return _box.keys
        .cast<String>()
        .map((key) {
          final raw = _box.get(key);
          if (raw == null) return null;
          return MapEntry(key, QueuedLocationPing.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        })
        .whereType<MapEntry<String, QueuedLocationPing>>()
        .toList();
  }

  Future<void> remove(String key) => _box.delete(key);

  int get pendingCount => _box.length;
}
