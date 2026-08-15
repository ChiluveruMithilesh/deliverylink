import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/map_display.dart';
import '../providers/shopkeeper_provider.dart';

class ShopTrackingScreen extends ConsumerWidget {
  const ShopTrackingScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingAsync = ref.watch(shopTrackingProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: trackingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            ErrorView(message: err.toString(), onRetry: () => ref.invalidate(shopTrackingProvider(tripId))),
        data: (tracking) {
          final location = tracking['currentLocation'] as Map<String, dynamic>?;
          final stops = (tracking['stops'] as List<dynamic>? ?? []);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(shopTrackingProvider(tripId)),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (location != null)
                  MapDisplay(
                    markers: {
                      Marker(
                        markerId: const MarkerId('driver'),
                        position: LatLng(
                          (location['lat'] as num).toDouble(),
                          (location['lng'] as num).toDouble(),
                        ),
                        infoWindow: const InfoWindow(title: 'Driver'),
                      ),
                    },
                  )
                else
                  Card(
                    color: Colors.blue.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.location_on, size: 48, color: Colors.blue),
                          SizedBox(height: 8),
                          Text('Waiting for driver location...', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('Delivery Status: ${tracking['status']}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...stops.map((s) {
                  final stop = s as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(
                      stop['status'] == 'delivered' ? Icons.check_circle : Icons.circle_outlined,
                      color: stop['status'] == 'delivered' ? Colors.green : Colors.grey,
                    ),
                    title: Text(stop['shopName'] as String? ?? ''),
                    subtitle: Text(stop['status'] as String? ?? ''),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
