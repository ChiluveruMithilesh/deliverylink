import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/driver_provider.dart';

class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(driverTripHistoryProvider);
    final earningsAsync = ref.watch(driverEarningsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip History & Earnings')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverTripHistoryProvider);
          ref.invalidate(driverEarningsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            earningsAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text(err.toString(), style: const TextStyle(color: Colors.red)),
              data: (report) => _EarningsSummary(report: report),
            ),
            const SizedBox(height: 24),
            Text('Completed Trips', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(driverTripHistoryProvider),
              ),
              data: (trips) {
                if (trips.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No trips yet.', style: TextStyle(color: Colors.grey)),
                  );
                }
                return Column(
                  children: trips.map((t) {
                    final trip = t as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          trip['status'] == 'completed' ? Icons.check_circle : Icons.cancel,
                          color: trip['status'] == 'completed' ? Colors.green : Colors.red,
                        ),
                        title: Text(trip['goods_description'] as String? ?? 'Trip'),
                        subtitle: Text('₹${trip['payment_offered']} • ${trip['total_stops']} stops'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsSummary extends StatelessWidget {
  const _EarningsSummary({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Total Earnings',
            value: '₹${report['total_earnings'] ?? 0}',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Acceptance Rate',
            value: '${report['acceptanceRate'] ?? 0}%',
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
