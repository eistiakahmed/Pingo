import 'package:pingo_mobile/core/crypto/crypto_helper.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/features/auth/domain/auth_models.dart';

/// Authentication API Gateway Service
class AuthApiService {
  final ApiClient _client;

  AuthApiService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Registers a new user and generates a cryptographic client salt
  Future<AuthResponse> register({
    required String email,
    required String password,
    String? clientSalt,
  }) async {
    final salt = clientSalt ?? CryptoHelper.generateClientSalt(16);
    final response = await _client.post(
      ApiConfig.authRegister,
      body: {
        'email': email,
        'password': password,
        'client_salt': salt,
      },
    );

    final authRes = AuthResponse.fromJson(response as Map<String, dynamic>);
    _client.setAuthToken(authRes.accessToken);
    return authRes;
  }

  /// Logs in an existing user and returns JWT token
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      ApiConfig.authLogin,
      body: {
        'email': email,
        'password': password,
      },
    );

    final authRes = AuthResponse.fromJson(response as Map<String, dynamic>);
    _client.setAuthToken(authRes.accessToken);
    return authRes;
  }

  /// Fetches authenticated user profile
  Future<UserProfile> getMe() async {
    final response = await _client.get(ApiConfig.authMe);
    return UserProfile.fromJson(response as Map<String, dynamic>);
  }

  /// Checks API gateway health
  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(ApiConfig.health);
      return response['status'] == 'healthy';
    } catch (_) {
      return false;
    }
  }

  /// Clears stored authentication session
  void logout() {
    _client.setAuthToken(null);
  }
}

