import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/admin_provider.dart';

class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> {
  String? _roleFilter;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider(_roleFilter));

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(width: 0),
                for (final role in [null, 'distributor', 'driver', 'shopkeeper', 'admin'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(role ?? 'All'),
                      selected: _roleFilter == role,
                      onSelected: (_) => setState(() => _roleFilter = role),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(adminUsersProvider(_roleFilter)),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('No users found.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index] as Map<String, dynamic>;
                    final isActive = user['is_active'] == true;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
                        child: Icon(Icons.person, color: isActive ? Colors.green : Colors.red),
                      ),
                      title: Text(user['full_name'] as String? ?? ''),
                      subtitle: Text('${user['role']} • ${user['phone']}'),
                      trailing: Switch(
                        value: isActive,
                        onChanged: (value) async {
                          try {
                            await ref.read(adminRepositoryProvider).setUserActive(user['id'] as String, value);
                            ref.invalidate(adminUsersProvider(_roleFilter));
                          } on ApiException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
