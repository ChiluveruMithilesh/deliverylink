import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/driver_provider.dart';

class NearbyTripsScreen extends ConsumerWidget {
  const NearbyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(nearbyTripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Trips')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(nearbyTripsProvider),
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              ErrorView(message: err.toString(), onRetry: () => ref.invalidate(nearbyTripsProvider)),
          data: (trips) {
            if (trips.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(
                      child: Text('No trips nearby right now.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (context, index) => _RideCard(trip: trips[index] as Map<String, dynamic>),
            );
          },
        ),
      ),
    );
  }
}

class _RideCard extends ConsumerWidget {
  const _RideCard({required this.trip});
  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentOffered = trip['payment_offered'];
    final distanceKm = trip['distanceFromDriverKm'];
    final totalStops = trip['total_stops'];
    final distributorName = trip['distributor_name'];
    final durationMin = trip['estimated_duration_min'];

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
                  child: Text(
                    distributorName as String? ?? 'Distributor',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '₹$paymentOffered',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F9D58)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _InfoChip(icon: Icons.storefront, label: '$totalStops stops'),
                _InfoChip(icon: Icons.social_distance, label: '${distanceKm ?? '-'} km'),
                _InfoChip(icon: Icons.timer, label: '${durationMin ?? '-'} min'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _bid(context, ref, trip, isAccept: false),
                    child: const Text('Counter Offer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Accept',
                    onPressed: () => _bid(context, ref, trip, isAccept: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bid(BuildContext context, WidgetRef ref, Map<String, dynamic> trip,
      {required bool isAccept}) async {
    double amount = double.parse(trip['payment_offered'].toString());

    if (!isAccept) {
      final controller = TextEditingController(text: amount.toStringAsFixed(0));
      final entered = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Counter Offer'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Your offer'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (entered == null) return;
      amount = entered;
    }

    try {
      await ref.read(driverRepositoryProvider).placeBid(trip['id'] as String, amount);
      ref.invalidate(nearbyTripsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAccept ? 'Trip accepted!' : 'Counter offer sent')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }
}
