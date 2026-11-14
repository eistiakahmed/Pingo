import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/features/action_stream/data/ai_api_service.dart';
import 'package:pingo_mobile/features/auth/data/auth_api_service.dart';
import 'package:pingo_mobile/features/home/data/sync_api_service.dart';

/// Global ApiClient singleton
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(() => client.close());
  return client;
});

/// Auth API Service Provider
final authApiServiceProvider = Provider<AuthApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthApiService(client: client);
});

/// Sync API Service Provider
final syncApiServiceProvider = Provider<SyncApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return SyncApiService(client: client);
});

/// AI API Service Provider
final aiApiServiceProvider = Provider<AiApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AiApiService(client: client);
});

