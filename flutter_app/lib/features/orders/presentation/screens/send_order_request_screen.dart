import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/orders_provider.dart';

class SendOrderRequestScreen extends ConsumerStatefulWidget {
  const SendOrderRequestScreen({super.key});

  @override
  ConsumerState<SendOrderRequestScreen> createState() => _SendOrderRequestScreenState();
}

class _SendOrderRequestScreenState extends ConsumerState<SendOrderRequestScreen> {
  final _codeController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    final message = _messageController.text.trim();

    if (code.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the distributor\'s code and your message')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(ordersRepositoryProvider).sendOrderRequest(
            distributorCode: code,
            message: message,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order request sent!')),
        );
        _codeController.clear();
        _messageController.clear();
        ref.invalidate(sentOrderRequestsProvider);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order from Distributor')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('New Request', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Enter the distributor\'s unique code (found on their profile) and describe what you need.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Distributor Code (e.g. DL-7K2M9X)',
            controller: _codeController,
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'What do you need?',
            controller: _messageController,
            prefixIcon: Icons.message_outlined,
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Send Request',
            icon: Icons.send,
            onPressed: _submit,
            isLoading: _isSubmitting,
          ),
          const SizedBox(height: 32),
          Text('Your Sent Requests', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const _SentRequestsList(),
        ],
      ),
    );
  }
}

class _SentRequestsList extends ConsumerWidget {
  const _SentRequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentAsync = ref.watch(sentOrderRequestsProvider);

    return sentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(sentOrderRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No requests sent yet.', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: requests.map((r) {
            final request = r as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(request['distributor_name'] as String? ?? ''),
                subtitle: Text(request['message'] as String? ?? ''),
                trailing: _StatusChip(status: request['status'] as String? ?? 'pending'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
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