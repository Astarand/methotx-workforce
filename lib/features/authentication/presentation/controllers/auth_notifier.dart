import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_entity.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthLoginStatus { initial, loading, success, error }

class AuthLoginState {
  final AuthLoginStatus status;
  final AuthEntity? user;
  final String? errorMessage;

  const AuthLoginState({
    this.status = AuthLoginStatus.initial,
    this.user,
    this.errorMessage,
  });

  bool get isLoading => status == AuthLoginStatus.loading;
  bool get isSuccess => status == AuthLoginStatus.success;
  bool get isError => status == AuthLoginStatus.error;
  bool get isAuthenticated => status == AuthLoginStatus.success && user != null;

  AuthLoginState copyWith({
    AuthLoginStatus? status,
    AuthEntity? user,
    String? errorMessage,
  }) {
    return AuthLoginState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() =>
      'AuthLoginState(status: $status, user: ${user?.fullName}, error: $errorMessage)';
}

class AuthNotifier extends StateNotifier<AuthLoginState> {
  final AuthRepository authRepository;

  AuthNotifier({required this.authRepository}) : super(const AuthLoginState()) {
    checkSession();
  }

  /// Verifies if an existing session token is cached and refreshes profile
  Future<void> checkSession() async {
    try {
      // First, get the cached user to show UI immediately
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(
          status: AuthLoginStatus.success,
          user: user,
          errorMessage: null,
        );

        // Then dynamically refresh the profile (for latest designation etc.)
        final updatedUser = await authRepository.refreshProfile();
        if (updatedUser != null) {
          state = state.copyWith(user: updatedUser);
        }
      } else {
        state = state.copyWith(status: AuthLoginStatus.initial, user: null);
      }
    } catch (_) {
      state = state.copyWith(status: AuthLoginStatus.initial);
    }
  }

  /// Performs user login through clean architecture pipeline
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthLoginStatus.loading, errorMessage: null);

    try {
      final user = await authRepository.login(email, password);
      state = state.copyWith(
        status: AuthLoginStatus.success,
        user: user,
        errorMessage: null,
      );

      // Fetch latest profile details (designation, etc.) immediately after login
      final updatedUser = await authRepository.refreshProfile();
      if (updatedUser != null) {
        state = state.copyWith(user: updatedUser);
      }

      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthLoginStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthLoginStatus.error,
        errorMessage:
            'An unexpected error occurred during login. Please try again.',
      );
      return false;
    }
  }

  /// Updates the in-memory user information (e.g. after profile edit)
  void updateUserInfo({String? fullName, String? email}) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(
          fullName: fullName ?? state.user!.fullName,
          email: email ?? state.user!.email,
        ),
      );
    }
  }

  /// Logs out the user and clears state
  Future<void> logout() async {
    state = state.copyWith(status: AuthLoginStatus.loading);
    try {
      await authRepository.logout();
    } catch (_) {
      // Unconditionally succeed local logout even on unexpected error
    } finally {
      state = const AuthLoginState(
        status: AuthLoginStatus.initial,
        user: null,
        errorMessage: null,
      );
    }
  }
}

/// Riverpod Provider exposing AuthNotifier and its clean reactive state
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthLoginState>((ref) {
      final authRepository = ref.watch(authRepositoryDomainProvider);
      return AuthNotifier(authRepository: authRepository);
    });
