import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/features/auth/data/auth_api_service.dart';

void main() {
  group('AuthApiService Tests', () {
    test('register() returns AuthResponse and sets client auth token', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/register');
        final body = jsonDecode(request.body);
        expect(body['email'], 'newuser@pingo.app');
        expect(body['password'], 'SecurePass123!');
        expect(body['client_salt'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'access_token': 'jwt-registered-token-123',
            'token_type': 'bearer',
            'user_id': '11111111-2222-3333-4444-555555555555',
            'email': 'newuser@pingo.app',
            'client_salt': body['client_salt'],
          }),
          201,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final authService = AuthApiService(client: apiClient);

      final response = await authService.register(
        email: 'newuser@pingo.app',
        password: 'SecurePass123!',
      );

      expect(response.accessToken, 'jwt-registered-token-123');
      expect(response.email, 'newuser@pingo.app');
      expect(apiClient.authToken, 'jwt-registered-token-123');
    });

    test('login() returns AuthResponse and sets client auth token', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        final body = jsonDecode(request.body);
        expect(body['email'], 'existing@pingo.app');

        return http.Response(
          jsonEncode({
            'access_token': 'jwt-login-token-456',
            'token_type': 'bearer',
            'user_id': '22222222-3333-4444-5555-666666666666',
            'email': 'existing@pingo.app',
            'client_salt': 'existing_salt_123',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final authService = AuthApiService(client: apiClient);

      final response = await authService.login(
        email: 'existing@pingo.app',
        password: 'Password123!',
      );

      expect(response.accessToken, 'jwt-login-token-456');
      expect(response.email, 'existing@pingo.app');
      expect(apiClient.authToken, 'jwt-login-token-456');
    });

    test('getMe() returns UserProfile when authenticated', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/me');
        expect(request.headers['Authorization'], 'Bearer jwt-login-token-456');

        return http.Response(
          jsonEncode({
            'id': '22222222-3333-4444-5555-666666666666',
            'email': 'existing@pingo.app',
            'client_salt': 'existing_salt_123',
            'plan_tier': 'PRO',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      apiClient.setAuthToken('jwt-login-token-456');
      final authService = AuthApiService(client: apiClient);

      final profile = await authService.getMe();
      expect(profile.id, '22222222-3333-4444-5555-666666666666');
      expect(profile.email, 'existing@pingo.app');
      expect(profile.planTier, 'PRO');
    });

    test('checkHealth() returns true when backend status is healthy', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'healthy', 'service': 'pingo-backend'}),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final authService = AuthApiService(client: apiClient);

      final isHealthy = await authService.checkHealth();
      expect(isHealthy, true);
    });
  });
}
