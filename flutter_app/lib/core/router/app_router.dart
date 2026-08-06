import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/manage_users_screen.dart';
import '../../features/admin/presentation/screens/pending_drivers_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/distributor/presentation/screens/create_trip_screen.dart';
import '../../features/distributor/presentation/screens/distributor_dashboard_screen.dart';
import '../../features/distributor/presentation/screens/reports_screen.dart';
import '../../features/distributor/presentation/screens/trip_detail_screen.dart';
import '../../features/driver/presentation/screens/active_trip_screen.dart';
import '../../features/driver/presentation/screens/driver_dashboard_screen.dart';
import '../../features/driver/presentation/screens/driver_history_screen.dart';
import '../../features/driver/presentation/screens/nearby_trips_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shopkeeper/presentation/screens/shop_tracking_screen.dart';
import '../../features/shopkeeper/presentation/screens/shopkeeper_dashboard_screen.dart';
import '../../shared/widgets/splash_screen.dart';

/// Maps each role to its dashboard route - the single source of truth
/// for "each user only sees features related to their role".
String _homeRouteForRole(String role) => switch (role) {
      'distributor' => '/distributor',
      'driver' => '/driver',
      'shopkeeper' => '/shopkeeper',
      'admin' => '/admin',
      _ => '/login',
    };

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';
      final isSplash = location == '/splash';

      if (authState is AuthInitial || authState is AuthLoading) {
        return isSplash ? null : '/splash';
      }

      if (authState is AuthAuthenticated) {
        final home = _homeRouteForRole(authState.user.role);
        if (isSplash || isAuthRoute) return home;
        // Prevent a distributor from navigating into /driver/* URLs etc.
        final role = authState.user.role;
        if (!location.startsWith('/$role') && !_isSharedRoute(location)) {
          return home;
        }
        return null;
      }

      // Unauthenticated
      if (!isAuthRoute) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),

      // Distributor
      GoRoute(path: '/distributor', builder: (context, state) => const DistributorDashboardScreen()),
      GoRoute(
        path: '/distributor/create-trip',
        builder: (context, state) => const CreateTripScreen(),
      ),
      GoRoute(
        path: '/distributor/trips/:tripId',
        builder: (context, state) => TripDetailScreen(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(path: '/distributor/reports', builder: (context, state) => const ReportsScreen()),

      // Driver
      GoRoute(path: '/driver', builder: (context, state) => const DriverDashboardScreen()),
      GoRoute(path: '/driver/nearby-trips', builder: (context, state) => const NearbyTripsScreen()),
      GoRoute(
        path: '/driver/active-trip/:tripId',
        builder: (context, state) => ActiveTripScreen(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(path: '/driver/history', builder: (context, state) => const DriverHistoryScreen()),

      // Shopkeeper
      GoRoute(path: '/shopkeeper', builder: (context, state) => const ShopkeeperDashboardScreen()),
      GoRoute(
        path: '/shopkeeper/track/:tripId',
        builder: (context, state) => ShopTrackingScreen(tripId: state.pathParameters['tripId']!),
      ),

      // Admin
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/pending-drivers', builder: (context, state) => const PendingDriversScreen()),
      GoRoute(path: '/admin/users', builder: (context, state) => const ManageUsersScreen()),

      // Shared across all authenticated roles
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});

bool _isSharedRoute(String location) {
  return location.startsWith('/notifications') || location.startsWith('/settings');
}
