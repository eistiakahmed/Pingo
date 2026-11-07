import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/features/home/data/sync_api_service.dart';
import 'package:pingo_mobile/features/home/domain/sync_models.dart';

void main() {
  group('SyncApiService Tests', () {
    test('pushSync() sends encrypted reminders and vault items and returns applied_count', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/sync/push');
        final body = jsonDecode(request.body);
        expect(body['reminders'], hasLength(1));
        expect(body['vault_items'], hasLength(1));
        expect(body['reminders'][0]['ciphertext'], 'Y2lwaGVydGV4dDE=');

        return http.Response(
          jsonEncode({
            'success': true,
            'applied_count': 2,
            'server_timestamp': '2026-11-07T02:00:00Z',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final syncService = SyncApiService(client: apiClient);

      final reminder = EncryptedReminderDto(
        id: '11111111-2222-3333-4444-555555555555',
        ciphertext: 'Y2lwaGVydGV4dDE=',
        iv: 'MDEyMzQ1Njc4OWFi',
        authTag: 'YWJjZGVmZ2hpamtsbW5vcA==',
        keyVersion: 1,
        algorithm: 'AES-256-GCM',
        dueAt: DateTime.parse('2026-11-08T10:00:00Z'),
        isCompleted: false,
        version: 1,
      );

      final vault = EncryptedVaultDto(
        id: '22222222-3333-4444-5555-666666666666',
        itemType: 'passport',
        ciphertext: 'dmF1bHRfZGF0YQ==',
        iv: 'MDEyMzQ1Njc4OWFi',
        authTag: 'YWJjZGVmZ2hpamtsbW5vcA==',
        keyVersion: 1,
        algorithm: 'AES-256-GCM',
        version: 1,
      );

      final response = await syncService.pushSync(
        reminders: [reminder],
        vaultItems: [vault],
      );

      expect(response.success, true);
      expect(response.appliedCount, 2);
    });

    test('pullSync() returns encrypted delta lists', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/sync/pull');
        expect(request.url.queryParameters['since'], isNotNull);

        return http.Response(
          jsonEncode({
            'reminders': [
              {
                'id': '11111111-2222-3333-4444-555555555555',
                'ciphertext': 'Y2lwaGVydGV4dDE=',
                'iv': 'MDEyMzQ1Njc4OWFi',
                'auth_tag': 'YWJjZGVmZ2hpamtsbW5vcA==',
                'key_version': 1,
                'algorithm': 'AES-256-GCM',
                'due_at': '2026-11-08T10:00:00Z',
                'is_completed': true,
                'version': 2,
              }
            ],
            'vault_items': [],
            'server_timestamp': '2026-11-07T02:00:00Z',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final syncService = SyncApiService(client: apiClient);

      final response = await syncService.pullSync(
        since: DateTime.parse('2026-11-07T00:00:00Z'),
      );

      expect(response.reminders, hasLength(1));
      expect(response.reminders.first.version, 2);
      expect(response.reminders.first.isCompleted, true);
      expect(response.vaultItems, isEmpty);
    });
  });
}

