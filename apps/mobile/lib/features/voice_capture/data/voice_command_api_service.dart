import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/core/storage/local_storage_service.dart';

/// Uncommitted attachment preview returned by `POST /api/attachments/stage`.
class StagedAttachmentPreviewItem {
  final String stagingId;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String? localPath;

  const StagedAttachmentPreviewItem({
    required this.stagingId,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.localPath,
  });

  bool get isImage =>
      mimeType.toLowerCase().startsWith('image/') ||
      filename.toLowerCase().endsWith('.png') ||
      filename.toLowerCase().endsWith('.jpg') ||
      filename.toLowerCase().endsWith('.jpeg') ||
      filename.toLowerCase().endsWith('.webp');

  factory StagedAttachmentPreviewItem.fromJson(
    Map<String, dynamic> json, {
    String? localPath,
  }) {
    return StagedAttachmentPreviewItem(
      stagingId: (json['staging_id'] as String? ?? '').trim(),
      filename: (json['filename'] as String? ?? 'attachment').trim(),
      mimeType:
          (json['mime_type'] as String? ?? 'application/octet-stream').trim(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      localPath: localPath,
    );
  }
}

/// Represents a single executed autonomous tool returned in `actions`.
class VoiceExecutedAction {
  final String tool;
  final Map<String, dynamic> arguments;
  final String? recordId;
  final String category;
  final String? lifecycleState;

  const VoiceExecutedAction({
    required this.tool,
    required this.arguments,
    this.recordId,
    this.category = 'GENERAL',
    this.lifecycleState,
  });

  factory VoiceExecutedAction.fromJson(Map<String, dynamic> json) {
    final rawArgs = json['arguments'];
    final parsedArgs = rawArgs is Map<String, dynamic>
        ? rawArgs
        : (rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : const <String, dynamic>{});
    final catFromTop = json['category']?.toString();
    final catFromArgs = parsedArgs['category']?.toString();
    return VoiceExecutedAction(
      tool: (json['tool'] as String? ?? '').trim(),
      arguments: parsedArgs,
      recordId: json['record_id']?.toString(),
      category: (catFromTop ?? catFromArgs ?? 'GENERAL').trim().toUpperCase(),
      lifecycleState: json['lifecycle_state']?.toString(),
    );
  }
}

/// Typed response model from `POST /api/voice-command` and `POST /api/assistant/message`.
class VoiceCommandResult {
  final String status;
  final String userSaid;
  final String aiReply;
  final String audioUrl;
  final List<VoiceExecutedAction> actions;
  final List<Map<String, dynamic>> bundledAttachments;

  const VoiceCommandResult({
    this.status = 'completed_turn',
    required this.userSaid,
    required this.aiReply,
    required this.audioUrl,
    required this.actions,
    this.bundledAttachments = const [],
  });

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

    final rawBundled = json['bundled_attachments'];
    final parsedBundled = <Map<String, dynamic>>[];
    if (rawBundled is List) {
      for (final item in rawBundled) {
        if (item is Map) {
          parsedBundled.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return VoiceCommandResult(
      status: (json['status'] as String? ?? 'completed_turn').trim(),
      userSaid: (json['user_said'] as String? ?? '').trim(),
      aiReply: (json['ai_reply'] as String? ?? '').trim(),
      audioUrl: (json['audio_url'] as String? ?? '').trim(),
      actions: parsedActions,
      bundledAttachments: parsedBundled,
    );
  }
}

/// Multimodal API client for Staging (`POST /api/attachments/stage`),
/// Voice Bundling (`POST /api/voice-command`), and Text Bundling (`POST /api/assistant/message`).
class VoiceCommandApiService {
  VoiceCommandApiService._();
  static final VoiceCommandApiService instance = VoiceCommandApiService._();

  /// Resolves strict tenant headers (`Authorization: Bearer <JWT>` when authenticated,
  /// otherwise `X-Session-ID: <guest-uuid>`).
  Future<Map<String, String>> _buildTenantHeaders() async {
    final authToken = await LocalStorageService.instance.getAuthToken();
    if (authToken != null && authToken.isNotEmpty) {
      return {'Authorization': 'Bearer $authToken'};
    }
    final guestSessionId =
        await LocalStorageService.instance.getOrCreateGuestSessionId();
    return {'X-Session-ID': guestSessionId};
  }

  /// Directive 3: Decoupled Attachment Staging (`POST /api/attachments/stage`).
  /// Uploads an image or file into uncommitted preview state without auto-sending.
  Future<StagedAttachmentPreviewItem> stageAttachment({
    required String filePath,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final uri = Uri.parse(ApiConfig.attachmentsStage);
    final headers = await _buildTenantHeaders();

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('attachment', filePath));

    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = 'Attachment staging failed (${response.statusCode})';
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
    final stagedList = decoded['staged'] as List<dynamic>? ?? const [];
    if (stagedList.isEmpty) {
      throw HttpException('No staged preview returned by server', uri: uri);
    }

    final latest = Map<String, dynamic>.from(stagedList.last as Map);
    return StagedAttachmentPreviewItem.fromJson(latest, localPath: filePath);
  }

  /// Bundled Voice Transmission (`POST /api/voice-command`).
  Future<VoiceCommandResult> uploadVoiceCommand({
    required String filePath,
    List<String>? stagingIds,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.parse(ApiConfig.voiceCommand);
    final headers = await _buildTenantHeaders();

    final request = http.MultipartRequest('POST', uri)..headers.addAll(headers);

    if (!headers.containsKey('Authorization')) {
      request.fields['user_id'] = headers['X-Session-ID']!;
    }
    if (stagingIds != null && stagingIds.isNotEmpty) {
      request.fields['staging_ids'] = jsonEncode(stagingIds);
    }

    request.files.add(
      await http.MultipartFile.fromPath('audio', filePath),
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

  /// Bundled Text + Staged Attachments Transmission (`POST /api/assistant/message`).
  Future<VoiceCommandResult> sendBundledTextMessage({
    required String message,
    required List<String> stagingIds,
    bool synthesizeTts = false,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final uri = Uri.parse(ApiConfig.assistantMessage);
    final tenantHeaders = await _buildTenantHeaders();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      ...tenantHeaders,
    };

    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'message': message,
            'staging_ids': stagingIds,
            'synthesize_tts': synthesizeTts,
          }),
          encoding: utf8,
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = 'Message failed (${response.statusCode})';
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
  }
}
