import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/features/home/domain/sync_models.dart';

/// Zero-Knowledge Sync API Service
class SyncApiService {
  final ApiClient _client;

  SyncApiService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Pushes encrypted delta payload to server
  Future<SyncPushResponse> pushSync({
    List<EncryptedReminderDto> reminders = const [],
    List<EncryptedVaultDto> vaultItems = const [],
  }) async {
    final payload = {
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'vault_items': vaultItems.map((v) => v.toJson()).toList(),
    };

    final response = await _client.post(ApiConfig.syncPush, body: payload);
    return SyncPushResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Pulls encrypted delta payload updated since the given timestamp
  Future<SyncPullResponse> pullSync({DateTime? since}) async {
    String url = ApiConfig.syncPull;
    if (since != null) {
      url += '?since=${Uri.encodeQueryComponent(since.toUtc().toIso8601String())}';
    }

    final response = await _client.get(url);
    return SyncPullResponse.fromJson(response as Map<String, dynamic>);
  }
}

