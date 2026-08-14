import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/orders_provider.dart';

class OrderRequestsInboxScreen extends ConsumerWidget {
  const OrderRequestsInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivedAsync = ref.watch(receivedOrderRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order Requests')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(receivedOrderRequestsProvider),
        child: receivedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(receivedOrderRequestsProvider),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(
                      child: Text(
                        'No order requests yet.\nShopkeepers can reach you using your unique code from your Profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) =>
                  _RequestCard(request: requests[index] as Map<String, dynamic>),
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = request['status'] as String? ?? 'pending';
    final shopkeeperName = request['shopkeeper_name'] as String? ?? '';
    final shopkeeperCode = request['shopkeeper_code'] as String? ?? '';
    final shopkeeperPhone = request['shopkeeper_phone'] as String? ?? '';
    final message = request['message'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(shopkeeperName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                _StatusBadge(status: status),
              ],
            ),
            Text('$shopkeeperCode · $shopkeeperPhone', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontSize: 15)),
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => _updateStatus(context, ref, 'declined'),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: () => _updateStatus(context, ref, 'acknowledged'),
                      child: const Text('Acknowledge'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: () => _updateStatus(context, ref, 'fulfilled'),
                      child: const Text('Fulfill'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'acknowledged') ...[
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () => _updateStatus(context, ref, 'fulfilled'),
                child: const Text('Mark as Fulfilled'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(ordersRepositoryProvider).updateStatus(request['id'] as String, status);
      ref.invalidate(receivedOrderRequestsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'fulfilled' => Colors.green,
      'acknowledged' => Colors.blue,
      'declined' => Colors.red,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}