import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/core/crypto/crypto_helper.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/features/auth/data/auth_api_service.dart';
import 'package:pingo_mobile/features/home/data/sync_api_service.dart';
import 'package:pingo_mobile/features/home/domain/sync_models.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Live Backend Integration Tests (Docker Container on 127.0.0.1:8000)', () {
    late ApiClient apiClient;
    late AuthApiService authService;
    late SyncApiService syncService;

    setUp(() {
      ApiConfig.baseUrl = 'http://127.0.0.1:8000';
      apiClient = ApiClient();
      authService = AuthApiService(client: apiClient);
      syncService = SyncApiService(client: apiClient);
    });

    tearDown(() {
      apiClient.close();
    });

    test('E2E: Full User Lifecycle & Zero-Knowledge Sync against Live Server', () async {
      // 1. Health check
      final isHealthy = await authService.checkHealth();
      expect(isHealthy, isTrue, reason: 'Live backend container should be healthy on 127.0.0.1:8000');

      // 2. User registration
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'flutter_e2e_$uniqueId@pingo.app';
      const testPassword = 'Password123!@#';
      final testSalt = CryptoHelper.generateClientSalt(16);

      final registerRes = await authService.register(
        email: testEmail,
        password: testPassword,
        clientSalt: testSalt,
      );

      expect(registerRes.accessToken, isNotEmpty);
      expect(registerRes.email, testEmail);
      expect(registerRes.clientSalt, testSalt);

      // 3. User login
      final loginRes = await authService.login(
        email: testEmail,
        password: testPassword,
      );

      expect(loginRes.accessToken, isNotEmpty);
      expect(loginRes.email, testEmail);

      // 4. Authenticated profile check
      final profile = await authService.getMe();
      expect(profile.email, testEmail);
      expect(profile.clientSalt, testSalt);
      expect(profile.planTier, 'FREE');

      // 5. Zero-Knowledge E2EE Sync Push
      final reminderId = const Uuid().v4();
      final vaultId = const Uuid().v4();

      final reminderDto = EncryptedReminderDto(
        id: reminderId,
        ciphertext: CryptoHelper.toBase64('My Secret Doctor Reminder'),
        iv: CryptoHelper.toBase64('0123456789ab'),
        authTag: CryptoHelper.toBase64('abcdefghijklmnop'),
        keyVersion: 1,
        algorithm: 'AES-256-GCM',
        dueAt: DateTime.parse('2026-11-09T10:00:00Z'),
        isCompleted: false,
        version: 1,
      );

      final vaultDto = EncryptedVaultDto(
        id: vaultId,
        itemType: 'passport',
        ciphertext: CryptoHelper.toBase64('Encrypted Passport Data'),
        iv: CryptoHelper.toBase64('0123456789ab'),
        authTag: CryptoHelper.toBase64('abcdefghijklmnop'),
        keyVersion: 1,
        algorithm: 'AES-256-GCM',
        version: 1,
      );

      final pushRes = await syncService.pushSync(
        reminders: [reminderDto],
        vaultItems: [vaultDto],
      );

      expect(pushRes.success, isTrue);
      expect(pushRes.appliedCount, 2);

      // 6. Zero-Knowledge E2EE Sync Pull
      final pullRes = await syncService.pullSync();
      expect(pullRes.reminders, hasLength(1));
      expect(pullRes.reminders.first.id, reminderId);
      expect(
        CryptoHelper.fromBase64(pullRes.reminders.first.ciphertext),
        'My Secret Doctor Reminder',
      );

      expect(pullRes.vaultItems, hasLength(1));
      expect(pullRes.vaultItems.first.id, vaultId);
      expect(
        CryptoHelper.fromBase64(pullRes.vaultItems.first.ciphertext),
        'Encrypted Passport Data',
      );
    });
  });
}

