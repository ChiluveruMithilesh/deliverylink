import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/driver_provider.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(driverDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History & Earnings',
            onPressed: () => context.push('/driver/history'),
          ),
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
        onRefresh: () async => ref.invalidate(driverDashboardProvider),
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              ErrorView(message: err.toString(), onRetry: () => ref.invalidate(driverDashboardProvider)),
          data: (dashboard) {
            final profile = dashboard['profile'] as Map<String, dynamic>? ?? {};
            final activeTrip = dashboard['activeTrip'] as Map<String, dynamic>?;
            final totalEarnings = dashboard['totalEarnings'] ?? 0;
            final completedTrips = dashboard['completedTrips'] ?? 0;
            final isOnline = profile['is_online'] == true;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _OnlineToggleCard(isOnline: isOnline),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _StatCard(label: 'Earnings', value: '₹$totalEarnings', color: Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'Trips', value: '$completedTrips', color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 24),
                if (activeTrip != null) ...[
                  Text('Active Trip', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping, color: Colors.orange),
                      title: Text(activeTrip['goods_description'] as String? ?? 'Trip'),
                      subtitle: Text('Status: ${activeTrip['status']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/driver/active-trip/${activeTrip['id']}'),
                    ),
                  ),
                ] else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.search, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('No active trip', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.push('/driver/nearby-trips'),
                            child: const Text('Browse nearby trips'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/driver/nearby-trips'),
        icon: const Icon(Icons.map),
        label: const Text('Nearby Trips'),
      ),
    );
  }
}

class _OnlineToggleCard extends ConsumerWidget {
  const _OnlineToggleCard({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: isOnline ? Colors.green.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isOnline ? Icons.wifi_tethering : Icons.wifi_tethering_off,
              color: isOnline ? Colors.green : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                isOnline ? 'You are Online' : 'You are Offline',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: isOnline,
              activeColor: Colors.green,
              onChanged: (value) async {
                final location = ref.read(driverCurrentLocationProvider);
                await ref
                    .read(driverRepositoryProvider)
                    .setOnlineStatus(value, lat: location.lat, lng: location.lng);
                ref.invalidate(driverDashboardProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
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
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
