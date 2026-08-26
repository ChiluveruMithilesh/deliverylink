import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/network/api_exception.dart';
import '../providers/distributor_provider.dart';

class DistributorDashboardScreen extends ConsumerWidget {
  const DistributorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(distributorDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reports',
            onPressed: () => context.push('/distributor/reports'),
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
        onRefresh: () async => ref.invalidate(distributorDashboardProvider),
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(distributorDashboardProvider),
          ),
          data: (dashboard) {
            final statusCounts = (dashboard['statusCounts'] as Map<String, dynamic>? ?? {});
            final activeTrips = (dashboard['activeTrips'] as List<dynamic>? ?? []);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _StatsRow(statusCounts: statusCounts),
                const SizedBox(height: 24),
                Text('Active Trips', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (activeTrips.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No active trips. Tap + to create one.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...activeTrips.map((trip) => _TripCard(trip: trip as Map<String, dynamic>)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'orders-inbox',
            onPressed: () => context.push('/distributor/orders'),
            icon: const Icon(Icons.inbox_outlined),
            label: const Text('Requests'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F9D58),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new-trip',
            onPressed: () => context.push('/distributor/create-trip'),
            icon: const Icon(Icons.add),
            label: const Text('New Trip'),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.statusCounts});
  final Map<String, dynamic> statusCounts;

  @override
  Widget build(BuildContext context) {
    final completed = statusCounts['completed'] ?? 0;
    final inProgress =
        (statusCounts['in_progress'] ?? 0) + (statusCounts['assigned'] ?? 0) + (statusCounts['published'] ?? 0);
    final draft = statusCounts['draft'] ?? 0;

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Active', value: '$inProgress', color: Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Completed', value: '$completed', color: Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Drafts', value: '$draft', color: Colors.grey)),
      ],
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
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip});
  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = trip['status'] as String? ?? '';
    final stops = trip['total_stops'] ?? trip['totalStops'] ?? 0;
    final canCancel = !['completed', 'cancelled', 'in_progress'].contains(status);

    return Card(
      child: ListTile(
        onTap: () => context.push('/distributor/trips/${trip['id']}'),
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withOpacity(0.15),
          child: Icon(Icons.local_shipping, color: _statusColor(status)),
        ),
        title: Text(trip['goods_description'] ?? trip['goodsDescription'] ?? 'Trip'),
        subtitle: Text('$stops stops • ${status.replaceAll('_', ' ')}'),
        trailing: canCancel
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Cancel this trip',
                onPressed: () => _confirmCancel(context, ref),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: Text(
          'This will cancel "${trip['goods_description'] ?? trip['goodsDescription'] ?? 'this trip'}". '
          'If a driver has already been assigned, they will be notified.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, keep it')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel it', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(distributorRepositoryProvider).cancelTrip(trip['id'] as String);
      ref.invalidate(distributorDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip cancelled')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'assigned':
      case 'pickup_confirmed':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}