import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
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
          error: (err, _) =>
              ErrorView(message: err.toString(), onRetry: () => ref.invalidate(adminAnalyticsProvider)),
          data: (analytics) {
            final overview = (analytics['overview'] as Map<String, dynamic>? ?? {});
            final today = (analytics['today'] as Map<String, dynamic>? ?? {});
            final thisWeek = (analytics['thisWeek'] as Map<String, dynamic>? ?? {});
            final thisMonth = (analytics['thisMonth'] as Map<String, dynamic>? ?? {});
            final dailyTrend = (analytics['dailyTrend'] as List<dynamic>? ?? []);
            final topDistributors = (analytics['topDistributors'] as List<dynamic>? ?? []);
            final topDrivers = (analytics['topDrivers'] as List<dynamic>? ?? []);
            final usersByRole = (analytics['usersByRole'] as Map<String, dynamic>? ?? {});
            final tripsByStatus = (analytics['tripsByStatus'] as Map<String, dynamic>? ?? {});

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Overview', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.7,
                  children: [
                    _MetricCard(
                      label: 'Total GMV',
                      value: '₹${_formatNumber(overview['totalGmv'])}',
                      color: const Color(0xFF0F9D58),
                      icon: Icons.currency_rupee,
                    ),
                    _MetricCard(
                      label: 'Completion Rate',
                      value: '${overview['completionRate'] ?? 0}%',
                      color: Colors.blue,
                      icon: Icons.check_circle_outline,
                    ),
                    _MetricCard(
                      label: 'Total Trips',
                      value: '${overview['totalTrips'] ?? 0}',
                      color: Colors.orange,
                      icon: Icons.local_shipping_outlined,
                    ),
                    _MetricCard(
                      label: 'Avg. Order Value',
                      value: '₹${_formatNumber(overview['avgOrderValue'])}',
                      color: Colors.purple,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Activity by Period', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PeriodCard(
                        label: 'Today',
                        trips: today['trips'] ?? 0,
                        gmv: today['gmv'] ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PeriodCard(
                        label: 'This Week',
                        trips: thisWeek['trips'] ?? 0,
                        gmv: thisWeek['gmv'] ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PeriodCard(
                        label: 'This Month',
                        trips: thisMonth['trips'] ?? 0,
                        gmv: thisMonth['gmv'] ?? 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('GMV Trend (Last 30 Days)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
                    child: SizedBox(
                      height: 220,
                      child: dailyTrend.isEmpty
                          ? const Center(child: Text('No trend data yet'))
                          : _GmvTrendChart(dailyTrend: dailyTrend),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (topDistributors.isNotEmpty) ...[
                  Text('Top Distributors', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...topDistributors.map((d) {
                    final dist = d as Map<String, dynamic>;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.storefront)),
                      title: Text(dist['businessName'] as String? ?? ''),
                      subtitle: Text('${dist['completedTrips']} completed trips'),
                      trailing: Text(
                        '₹${_formatNumber(dist['totalGmv'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                if (topDrivers.isNotEmpty) ...[
                  Text('Top Drivers', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...topDrivers.map((d) {
                    final driver = d as Map<String, dynamic>;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
                      title: Text(driver['driverName'] as String? ?? ''),
                      subtitle: Text('${driver['completedTrips']} completed trips'),
                      trailing: Text(
                        '₹${_formatNumber(driver['totalEarnings'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                Text('Users by Role', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...usersByRole.entries.map(
                  (e) => ListTile(
                    leading: const Icon(Icons.people),
                    title: Text(e.key),
                    trailing: Text('${e.value}'),
                  ),
                ),
                const SizedBox(height: 16),

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

  static String _formatNumber(dynamic value) {
    final n = (value is num) ? value : num.tryParse('$value') ?? 0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.label, required this.trips, required this.gmv});
  final String label;
  final dynamic trips;
  final dynamic gmv;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('$trips trips', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(
              '₹$gmv',
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F9D58), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _GmvTrendChart extends StatelessWidget {
  const _GmvTrendChart({required this.dailyTrend});
  final List<dynamic> dailyTrend;

  @override
  Widget build(BuildContext context) {
    final points = dailyTrend.asMap().entries.map((entry) {
      final day = entry.value as Map<String, dynamic>;
      final gmv = (day['gmv'] as num?)?.toDouble() ?? 0;
      return FlSpot(entry.key.toDouble(), gmv);
    }).toList();

    final maxGmv = points.map((p) => p.y).fold<double>(0, (a, b) => a > b ? a : b);
    final interval = maxGmv > 0 ? maxGmv / 4 : 1.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval == 0 ? 1 : interval,
              getTitlesWidget: (value, meta) => Text(
                value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (dailyTrend.length / 5).clamp(1, dailyTrend.length).toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dailyTrend.length) return const SizedBox.shrink();
                final date = (dailyTrend[idx] as Map<String, dynamic>)['date'] as String? ?? '';
                final shortDate = date.length >= 10 ? date.substring(5) : date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(shortDate, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            color: const Color(0xFF0F9D58),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF0F9D58).withOpacity(0.12)),
          ),
        ],
      ),
    );
  }
}