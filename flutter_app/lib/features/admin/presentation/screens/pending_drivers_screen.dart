import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/admin_provider.dart';

class PendingDriversScreen extends ConsumerWidget {
  const PendingDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingDriversProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Driver Verification')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingDriversProvider),
        child: pendingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              ErrorView(message: err.toString(), onRetry: () => ref.invalidate(pendingDriversProvider)),
          data: (drivers) {
            if (drivers.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(child: Text('No drivers awaiting verification.', style: TextStyle(color: Colors.grey))),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver['full_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('${driver['phone']} • ${driver['vehicle_type']} • ${driver['vehicle_number']}'),
                        Text('Licence: ${driver['driving_licence_number']}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () => _review(context, ref, driver['id'] as String, 'rejected'),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _review(context, ref, driver['id'] as String, 'approved'),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref, String driverId, String decision) async {
    try {
      await ref.read(adminRepositoryProvider).reviewDriver(driverId, decision);
      ref.invalidate(pendingDriversProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver $decision')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
