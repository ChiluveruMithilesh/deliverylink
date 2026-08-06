import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});

final adminAnalyticsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(adminRepositoryProvider).getAnalytics();
});

final pendingDriversProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(adminRepositoryProvider).listPendingDrivers();
});

final adminUsersProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, role) {
  return ref.watch(adminRepositoryProvider).listUsers(role: role);
});
