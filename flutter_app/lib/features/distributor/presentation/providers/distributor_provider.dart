import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/distributor_repository.dart';

final distributorRepositoryProvider = Provider<DistributorRepository>((ref) {
  return DistributorRepository(ref.watch(apiClientProvider));
});

final distributorDashboardProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(distributorRepositoryProvider).getDashboard();
});

final distributorTripsProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, status) {
  return ref.watch(distributorRepositoryProvider).listTrips(status: status);
});

final tripDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, tripId) {
  return ref.watch(distributorRepositoryProvider).getTrip(tripId);
});

final tripBidsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, tripId) {
  return ref.watch(distributorRepositoryProvider).listBids(tripId);
});

final shopSearchProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, query) {
  if (query.trim().isEmpty) return Future.value(<dynamic>[]);
  return ref.watch(distributorRepositoryProvider).searchShops(query);
});
