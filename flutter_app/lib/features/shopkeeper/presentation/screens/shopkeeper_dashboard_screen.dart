import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/shopkeeper_provider.dart';

class ShopkeeperDashboardScreen extends ConsumerWidget {
  const ShopkeeperDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(todaysDeliveriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Deliveries"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todaysDeliveriesProvider),
        child: deliveriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              ErrorView(message: err.toString(), onRetry: () => ref.invalidate(todaysDeliveriesProvider)),
          data: (deliveries) {
            if (deliveries.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(
                      child: Text('No deliveries scheduled for today.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: deliveries.length,
              itemBuilder: (context, index) => _DeliveryCard(delivery: deliveries[index] as Map<String, dynamic>),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/shopkeeper/order'),
        icon: const Icon(Icons.shopping_cart_outlined),
        label: const Text('Order'),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery});
  final Map<String, dynamic> delivery;

  @override
  Widget build(BuildContext context) {
    final status = delivery['status'] as String? ?? 'pending';
    final distributorName = delivery['distributor_name'] as String? ?? '';
    final driverName = delivery['driver_name'] as String?;
    final vehicleNumber = delivery['vehicle_number'] as String?;
    final tripId = delivery['trip_id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(distributorName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text('${delivery['quantity']} ${delivery['unit_type']}', style: const TextStyle(color: Colors.grey)),
            if (driverName != null) ...[
              const SizedBox(height: 4),
              Text('Driver: $driverName ($vehicleNumber)', style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 12),
            if (status != 'delivered')
              OutlinedButton.icon(
                onPressed: () => context.push('/shopkeeper/track/$tripId'),
                icon: const Icon(Icons.location_on, size: 18),
                label: const Text('Live Track'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'delivered' => Colors.green,
      'arrived' => Colors.orange,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
