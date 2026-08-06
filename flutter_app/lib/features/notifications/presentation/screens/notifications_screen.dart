import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsListProvider),
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              ErrorView(message: err.toString(), onRetry: () => ref.invalidate(notificationsListProvider)),
          data: (notifications) {
            if (notifications.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(
                      child: Text('No notifications yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index] as Map<String, dynamic>;
                final isRead = n['status'] == 'read';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey.shade200 : Colors.green.shade100,
                    child: Icon(
                      Icons.notifications,
                      color: isRead ? Colors.grey : const Color(0xFF0F9D58),
                    ),
                  ),
                  title: Text(
                    n['title'] as String? ?? '',
                    style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                  ),
                  subtitle: Text(n['body'] as String? ?? ''),
                  onTap: () async {
                    if (!isRead) {
                      await ref.read(notificationsRepositoryProvider).markAsRead(n['id'] as String);
                      ref.invalidate(notificationsListProvider);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
