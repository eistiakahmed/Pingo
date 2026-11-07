import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/core/network/api_exceptions.dart';

void main() {
  group('ApiClient Tests', () {
    test('get() sends request with Content-Type and returns decoded JSON', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        return http.Response(
          jsonEncode({'status': 'healthy', 'service': 'pingo-backend'}),
          200,
        );
      });

      final client = ApiClient(client: mockClient);
      final result = await client.get('http://test/health');

      expect(result['status'], 'healthy');
      expect(result['service'], 'pingo-backend');
    });

    test('post() sends request body and attaches Authorization Bearer token', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer mock-jwt-token');
        final body = jsonDecode(request.body);
        expect(body['email'], 'test@pingo.app');
        return http.Response(
          jsonEncode({'success': true, 'applied_count': 1}),
          200,
        );
      });

      final client = ApiClient(client: mockClient);
      client.setAuthToken('mock-jwt-token');

      final result = await client.post(
        'http://test/api/v1/sync/push',
        body: {'email': 'test@pingo.app'},
      );

      expect(result['success'], true);
      expect(result['applied_count'], 1);
    });

    test('Throws ApiException with RFC 7807 problem details on 401 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'https://api.pingo.app/errors/invalid-credentials',
            'title': 'Authentication Failed',
            'status': 401,
            'detail': 'Incorrect email or password.',
            'instance': '/api/v1/auth/login',
          }),
          401,
        );
      });

      final client = ApiClient(client: mockClient);

      expect(
        () async => await client.post(
          'http://test/api/v1/auth/login',
          body: {'email': 'wrong@pingo.app', 'password': 'wrong'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.title, 'title', 'Authentication Failed')
              .having((e) => e.detail, 'detail', 'Incorrect email or password.'),
        ),
      );
    });

    test('Throws ApiException.network when connection fails', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection refused');
      });

      final client = ApiClient(client: mockClient);

      expect(
        () async => await client.get('http://test/unreachable'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.title, 'title', 'Network Error'),
        ),
      );
    });
  });
}
