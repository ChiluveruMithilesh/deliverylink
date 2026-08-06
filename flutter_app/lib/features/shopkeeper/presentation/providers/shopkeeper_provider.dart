import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/shopkeeper_repository.dart';

final shopkeeperRepositoryProvider = Provider<ShopkeeperRepository>((ref) {
  return ShopkeeperRepository(ref.watch(apiClientProvider));
});

final todaysDeliveriesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(shopkeeperRepositoryProvider).getTodaysDeliveries();
});

final deliveryHistoryProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(shopkeeperRepositoryProvider).getDeliveryHistory();
});

final shopTrackingProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, tripId) {
  return ref.watch(shopkeeperRepositoryProvider).trackTrip(tripId);
});
