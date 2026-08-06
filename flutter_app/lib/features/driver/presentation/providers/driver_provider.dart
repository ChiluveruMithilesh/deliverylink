import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/driver_repository.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.watch(apiClientProvider));
});

final driverDashboardProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).getDashboard();
});

/// Placeholder location - in production this comes from Geolocator's
/// current position stream, updated continuously while online.
final driverCurrentLocationProvider = StateProvider<({double lat, double lng})>((ref) {
  return (lat: 17.385, lng: 78.4867);
});

final nearbyTripsProvider = FutureProvider.autoDispose((ref) {
  final location = ref.watch(driverCurrentLocationProvider);
  return ref.watch(driverRepositoryProvider).listNearbyTrips(location.lat, location.lng);
});

final driverTripHistoryProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).getTripHistory();
});

final driverEarningsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).getEarningsReport();
});
