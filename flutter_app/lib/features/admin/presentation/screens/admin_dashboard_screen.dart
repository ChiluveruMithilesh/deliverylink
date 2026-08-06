import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final pendingDriversAsync = ref.watch(pendingDriversProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
        onRefresh: () async {
          ref.invalidate(adminAnalyticsProvider);
          ref.invalidate(pendingDriversProvider);
        },
        child: analyticsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ErrorView(message: err.toString(), onRetry: () => ref.invalidate(adminAnalyticsProvider)),
          data: (analytics) {
            final usersByRole = (analytics['usersByRole'] as Map<String, dynamic>? ?? {});
            final tripsByStatus = (analytics['tripsByStatus'] as Map<String, dynamic>? ?? {});
            final last30 = (analytics['last30Days'] as Map<String, dynamic>? ?? {});

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Last 30 Days', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Trips',
                        value: '${last30['trips_last_30_days'] ?? 0}',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'GMV (₹)',
                        value: '${last30['gmv_last_30_days'] ?? 0}',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Users by Role', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...usersByRole.entries.map(
                  (e) => ListTile(
                    leading: const Icon(Icons.people),
                    title: Text(e.key),
                    trailing: Text('${e.value}'),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Trips by Status', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...tripsByStatus.entries.map(
                  (e) => ListTile(
                    leading: const Icon(Icons.local_shipping),
                    title: Text((e.key as String).replaceAll('_', ' ')),
                    trailing: Text('${e.value}'),
                  ),
                ),
                const SizedBox(height: 24),
                pendingDriversAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (err, _) => const SizedBox.shrink(),
                  data: (pending) => Card(
                    color: pending.isNotEmpty ? Colors.orange.shade50 : null,
                    child: ListTile(
                      leading: Icon(
                        Icons.pending_actions,
                        color: pending.isNotEmpty ? Colors.orange : Colors.grey,
                      ),
                      title: Text('${pending.length} drivers awaiting verification'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin/pending-drivers'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.manage_accounts),
                    title: const Text('Manage Users'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/admin/users'),
                  ),
                ),
              ],
            );
          },
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
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
