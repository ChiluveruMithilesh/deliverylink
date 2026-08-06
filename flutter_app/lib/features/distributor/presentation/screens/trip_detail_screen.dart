import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/distributor_provider.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            ErrorView(message: err.toString(), onRetry: () => ref.invalidate(tripDetailProvider(tripId))),
        data: (trip) {
          final status = trip['status'] as String? ?? '';
          final stops = (trip['stops'] as List<dynamic>? ?? []);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tripDetailProvider(tripId));
              ref.invalidate(tripBidsProvider(tripId));
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Chip(label: Text(status.replaceAll('_', ' ').toUpperCase())),
                const SizedBox(height: 16),
                Text('Route (${stops.length} stops)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...stops.map((s) {
                  final stop = s as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(child: Text('${stop['sequence_number'] ?? ''}')),
                    title: Text(stop['shop_name'] as String? ?? ''),
                    subtitle: Text('${stop['quantity']} ${stop['unit_type']} • ${stop['status']}'),
                  );
                }),
                if (status == 'published') ...[
                  const SizedBox(height: 24),
                  Text('Driver Bids', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _BidsList(tripId: tripId),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BidsList extends ConsumerWidget {
  const _BidsList({required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(tripBidsProvider(tripId));

    return bidsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Text(err.toString(), style: const TextStyle(color: Colors.red)),
      data: (bids) {
        if (bids.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No bids yet. Nearby drivers have been notified.', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: bids.map((b) {
            final bid = b as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(bid['driver_name'] as String? ?? ''),
                subtitle: Text('${bid['vehicle_type']} • ${bid['vehicle_number']} • ⭐ ${bid['rating']}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('₹${bid['offered_amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(distributorRepositoryProvider)
                              .selectBid(tripId, bid['id'] as String);
                          ref.invalidate(tripDetailProvider(tripId));
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        }
                      },
                      child: const Text('Select'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
