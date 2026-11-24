import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/core/network/api_exceptions.dart';
import 'package:pingo_mobile/core/network/providers.dart';
import 'package:pingo_mobile/core/services/fcm_service.dart';
import 'package:pingo_mobile/core/storage/local_storage_service.dart';
import 'package:pingo_mobile/features/auth/data/auth_api_service.dart';
import 'package:pingo_mobile/features/auth/domain/auth_models.dart';
import 'package:pingo_mobile/features/home/presentation/state/home_reminder_provider.dart';

/// Authentication UI state
class AuthState {
  final bool isInitializing;
  final bool isLoading;
  final bool isAuthenticated;
  final bool isGuest;
  final String? userEmail;
  final String? userName;
  final AuthResponse? session;
  final UserProfile? profile;
  final String? errorMessage;

  const AuthState({
    this.isInitializing = true,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.isGuest = false,
    this.userEmail,
    this.userName,
    this.session,
    this.profile,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isInitializing,
    bool? isLoading,
    bool? isAuthenticated,
    bool? isGuest,
    String? userEmail,
    String? userName,
    AuthResponse? session,
    UserProfile? profile,
    String? errorMessage,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isGuest: isGuest ?? this.isGuest,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      session: session ?? this.session,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _apiService;
  final ApiClient _apiClient;
  final Ref _ref;

  AuthNotifier(this._apiService, this._apiClient, this._ref)
      : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final guestId =
          await LocalStorageService.instance.getOrCreateGuestSessionId();
      _apiClient.setGuestSessionId(guestId);

      final isAuthed =
          await LocalStorageService.instance.isExplicitlyAuthenticated();
      if (isAuthed) {
        final token = await LocalStorageService.instance.getAuthToken();
        final email = await LocalStorageService.instance.getUserEmail();
        final name = await LocalStorageService.instance.getUserName();
        _apiClient.setAuthToken(token);
        state = state.copyWith(
          isInitializing: false,
          isAuthenticated: true,
          isGuest: false,
          userEmail: email,
          userName: name,
        );
        return;
      }
    } catch (_) {}

    _apiClient.setAuthToken(null);
    state = state.copyWith(
      isInitializing: false,
      isAuthenticated: false,
      isGuest: false,
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    String? name,
    String? clientSalt,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _apiService.register(
        email: email,
        password: password,
        clientSalt: clientSalt,
      );
      _apiClient.setAuthToken(session.accessToken);
      await LocalStorageService.instance.saveAuthToken(session.accessToken);
      await LocalStorageService.instance.saveUserAccount(
        email: session.email,
        name: name,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isGuest: false,
        userEmail: session.email,
        userName: name,
        session: session,
      );

      // Bind FCM token & sync reminders for the newly registered account
      FcmService.instance.registerActiveToken();
      _ref.read(homeReminderProvider.notifier).syncWithAuthenticatedAccount();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.detail);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not reach the server. Check your internet connection.',
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
      _apiClient.setAuthToken(session.accessToken);
      await LocalStorageService.instance.saveAuthToken(session.accessToken);
      await LocalStorageService.instance.saveUserAccount(email: session.email);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isGuest: false,
        userEmail: session.email,
        session: session,
      );

      // Bind FCM token & sync reminders for the authenticated account
      FcmService.instance.registerActiveToken();
      _ref.read(homeReminderProvider.notifier).syncWithAuthenticatedAccount();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.detail);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sign-in failed. Check your email and password.',
      );
      return false;
    }
  }

  Future<void> continueAsGuest() async {
    _apiClient.setAuthToken(null);
    final guestId =
        await LocalStorageService.instance.getOrCreateGuestSessionId();
    _apiClient.setGuestSessionId(guestId);
    state = state.copyWith(
      isInitializing: false,
      isLoading: false,
      isAuthenticated: false,
      isGuest: true,
      errorMessage: null,
    );
  }

  Future<void> logout() async {
    _apiService.logout();
    _apiClient.setAuthToken(null);
    await LocalStorageService.instance.clearAuthSession();
    final guestId =
        await LocalStorageService.instance.getOrCreateGuestSessionId();
    _apiClient.setGuestSessionId(guestId);
    state = const AuthState(
      isInitializing: false,
      isAuthenticated: false,
      isGuest: false,
    );
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(authApiServiceProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiService, apiClient, ref);
});
