import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/distributor_provider.dart';

final _reportsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(distributorRepositoryProvider).getReports();
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(_reportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_reportsProvider),
        child: reportsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ErrorView(message: err.toString(), onRetry: () => ref.invalidate(_reportsProvider)),
          data: (reports) {
            final summary = reports['summary'] as Map<String, dynamic>? ?? {};
            final driverPerformance = (reports['driverPerformance'] as List<dynamic>? ?? []);
            final shopWise = (reports['shopWise'] as List<dynamic>? ?? []);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _MetricTile(label: 'Total Trips', value: '${summary['total_trips'] ?? 0}'),
                    _MetricTile(label: 'Completed', value: '${summary['completed_trips'] ?? 0}'),
                    _MetricTile(label: 'Pending', value: '${summary['pending_trips'] ?? 0}'),
                    _MetricTile(label: 'Goods Delivered', value: '${summary['goods_delivered'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Driver Performance', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (driverPerformance.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No completed trips yet.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...driverPerformance.map((d) {
                    final driver = d as Map<String, dynamic>;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(driver['driver_name'] as String? ?? ''),
                      subtitle: Text(driver['vehicle_number'] as String? ?? ''),
                      trailing: Text('${driver['trips_completed']} trips'),
                    );
                  }),
                const SizedBox(height: 24),
                Text('Shop-wise Deliveries', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (shopWise.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No delivery data yet.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...shopWise.map((s) {
                    final shop = s as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.store),
                      title: Text(shop['shop_name'] as String? ?? ''),
                      trailing: Text('${shop['delivered']}/${shop['deliveries']}'),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F9D58))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
