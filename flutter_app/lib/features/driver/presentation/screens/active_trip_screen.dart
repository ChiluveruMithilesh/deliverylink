import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../distributor/presentation/providers/distributor_provider.dart';
import '../../data/offline_sync_service.dart';
import '../providers/driver_provider.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  Timer? _pingTimer;

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  /// Starts sending a GPS ping every 15s while the trip is in progress.
  /// Pings go through OfflineSyncService, which queues them locally
  /// (via Hive) if the device has no connectivity and replays the
  /// queue automatically once connectivity returns.
  void _ensurePingTimerRunning(String status) {
    if (status != 'in_progress' || _pingTimer != null) return;

    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final syncServiceAsync = ref.read(offlineSyncServiceProvider);
      final location = ref.read(driverCurrentLocationProvider);
      syncServiceAsync.whenData((service) {
        service.sendLocationPing(widget.tripId, location.lat, location.lng);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Trip detail read model is shared across roles via the same /trips/:id endpoint.
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Active Trip')),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(tripDetailProvider(widget.tripId)),
        ),
        data: (trip) {
          final status = trip['status'] as String? ?? '';
          final stops = (trip['stops'] as List<dynamic>? ?? []);
          _ensurePingTimerRunning(status);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(tripDetailProvider(widget.tripId)),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Chip(label: Text(status.replaceAll('_', ' ').toUpperCase())),
                const SizedBox(height: 16),
                if (status == 'assigned')
                  PrimaryButton(
                    label: 'Confirm Pickup & Start Trip',
                    icon: Icons.check_circle,
                    onPressed: () async {
                      try {
                        await ref.read(driverRepositoryProvider).confirmPickup(widget.tripId);
                        ref.invalidate(tripDetailProvider(widget.tripId));
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
                  ),
                const SizedBox(height: 16),
                Text('Stops (${stops.length})', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...stops.map((s) => _StopTile(tripId: widget.tripId, stop: s as Map<String, dynamic>)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StopTile extends ConsumerWidget {
  const _StopTile({required this.tripId, required this.stop});
  final String tripId;
  final Map<String, dynamic> stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = stop['status'] as String? ?? 'pending';
    final stopId = stop['id'] as String;

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${stop['sequence_number'] ?? ''}')),
        title: Text(stop['shop_name'] as String? ?? ''),
        subtitle: Text('${stop['quantity']} ${stop['unit_type']} • $status'),
        trailing: switch (status) {
          'pending' => TextButton(
              onPressed: () async {
                try {
                  await ref.read(driverRepositoryProvider).arriveAtStop(tripId, stopId);
                  ref.invalidate(tripDetailProvider(tripId));
                } on ApiException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              child: const Text('Arrived'),
            ),
          'arrived' => TextButton(
              onPressed: () async {
                try {
                  // In production, photoUrl comes from the camera + /uploads endpoint,
                  // and lat/lng from the device GPS at the moment of delivery.
                  await ref.read(driverRepositoryProvider).deliverStop(
                        tripId,
                        stopId,
                        photoUrl: 'https://placeholder.deliverylink/proof.jpg',
                        capturedLat: 17.385,
                        capturedLng: 78.4867,
                      );
                  ref.invalidate(tripDetailProvider(tripId));
                } on ApiException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              child: const Text('Delivered'),
            ),
          'delivered' => const Icon(Icons.check_circle, color: Colors.green),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}
