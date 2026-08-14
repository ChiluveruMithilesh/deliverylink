import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/orders_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});

final sentOrderRequestsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(ordersRepositoryProvider).listSent();
});

final receivedOrderRequestsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(ordersRepositoryProvider).listReceived();
});