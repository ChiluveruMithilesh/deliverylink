import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/auth_repository.dart';
import '../../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(secureStorageProvider));
});

/// Represents the current authentication state of the app.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserModel user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthInitial()) {
    _restoreSession();
  }

  final AuthRepository _repository;

  Future<void> _restoreSession() async {
    state = const AuthLoading();
    final hasSession = await _repository.hasValidSession();
    if (!hasSession) {
      state = const AuthUnauthenticated();
      return;
    }
    try {
      final user = await _repository.getCurrentUser();
      state = AuthAuthenticated(user);
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login({required String phone, required String password}) async {
    state = const AuthLoading();
    try {
      final result = await _repository.login(phone: phone, password: password);
      state = AuthAuthenticated(result.user);
    } on ApiException catch (e) {
      state = AuthError(e.message);
    }
  }

  Future<void> register(Map<String, dynamic> payload) async {
    state = const AuthLoading();
    try {
      final result = await _repository.register(payload);
      state = AuthAuthenticated(result.user);
    } on ApiException catch (e) {
      state = AuthError(e.message);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
