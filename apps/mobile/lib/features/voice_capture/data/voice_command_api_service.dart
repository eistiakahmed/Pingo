import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pingo_mobile/core/network/api_config.dart';

/// Represents a single executed tool returned in `actions` from `/api/voice-command`.
class VoiceExecutedAction {
  final String tool;
  final Map<String, dynamic> arguments;
  final String? recordId;

  const VoiceExecutedAction({
    required this.tool,
    required this.arguments,
    this.recordId,
  });

  factory VoiceExecutedAction.fromJson(Map<String, dynamic> json) {
    final rawArgs = json['arguments'];
    return VoiceExecutedAction(
      tool: (json['tool'] as String? ?? '').trim(),
      arguments: rawArgs is Map<String, dynamic>
          ? rawArgs
          : (rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : const {}),
      recordId: json['record_id']?.toString(),
    );
  }
}

/// Typed response model from `POST /api/voice-command`.
class VoiceCommandResult {
  final String userSaid;
  final String aiReply;
  final String audioUrl;
  final List<VoiceExecutedAction> actions;

  const VoiceCommandResult({
    required this.userSaid,
    required this.aiReply,
    required this.audioUrl,
    required this.actions,
  });

  /// Full playable HTTP URL (`$baseUrl$audioUrl`).
  String get fullAudioUrl => ApiConfig.resolveMediaUrl(audioUrl);

  factory VoiceCommandResult.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    final parsedActions = <VoiceExecutedAction>[];
    if (rawActions is List) {
      for (final item in rawActions) {
        if (item is Map<String, dynamic>) {
          parsedActions.add(VoiceExecutedAction.fromJson(item));
        } else if (item is Map) {
          parsedActions.add(
            VoiceExecutedAction.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return VoiceCommandResult(
      userSaid: (json['user_said'] as String? ?? '').trim(),
      aiReply: (json['ai_reply'] as String? ?? '').trim(),
      audioUrl: (json['audio_url'] as String? ?? '').trim(),
      actions: parsedActions,
    );
  }
}

/// Multipart client for `POST /api/voice-command`.
class VoiceCommandApiService {
  VoiceCommandApiService._();
  static final VoiceCommandApiService instance = VoiceCommandApiService._();

  Future<VoiceCommandResult> uploadVoiceCommand({
    required String filePath,
    required String userId,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.parse(ApiConfig.voiceCommand);
    final request = http.MultipartRequest('POST', uri)
      ..fields['user_id'] = userId
      ..files.add(
        await http.MultipartFile.fromPath(
          'audio', // strictly matches FastAPI `audio: UploadFile = File(...)`
          filePath,
        ),
      );

    try {
      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String detail = 'Voice command failed (${response.statusCode})';
        try {
          final errMap = jsonDecode(response.body);
          if (errMap is Map && errMap['detail'] != null) {
            detail = errMap['detail'].toString();
          }
        } catch (_) {}
        throw HttpException(detail, uri: uri);
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return VoiceCommandResult.fromJson(decoded);
    } finally {
      // Clean up temporary recorded .m4a file from device cache
      try {
        final f = File(filePath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (e) {
        debugPrint('[VoiceCommandApiService] Temp audio delete warning: $e');
      }
    }
  }
}
