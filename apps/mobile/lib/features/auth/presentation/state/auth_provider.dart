import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/network/api_exceptions.dart';
import 'package:pingo_mobile/core/network/providers.dart';
import 'package:pingo_mobile/features/auth/data/auth_api_service.dart';
import 'package:pingo_mobile/features/auth/domain/auth_models.dart';

/// Authentication UI state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final AuthResponse? session;
  final UserProfile? profile;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.session,
    this.profile,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    AuthResponse? session,
    UserProfile? profile,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      session: session ?? this.session,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _apiService;

  AuthNotifier(this._apiService) : super(const AuthState());

  Future<bool> register({
    required String email,
    required String password,
    String? clientSalt,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _apiService.register(
        email: email,
        password: password,
        clientSalt: clientSalt,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        session: session,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.detail);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Registration failed. Please check connection.',
      );
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _apiService.login(
        email: email,
        password: password,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        session: session,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.detail);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed. Please check credentials.',
      );
      return false;
    }
  }

  void logout() {
    _apiService.logout();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(authApiServiceProvider);
  return AuthNotifier(apiService);
});
