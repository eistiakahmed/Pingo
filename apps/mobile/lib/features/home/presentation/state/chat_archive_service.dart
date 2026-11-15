import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/chat_message.dart';

/// Service responsible for managing local chat history persistence,
/// sliding active window retention, and background archiving to preserve 60/120 FPS UI performance.
class ChatArchiveService {
  static const String _activeMessagesKey = 'pingo_active_chat_messages_v1';
  static const String _archivedMessagesKey = 'pingo_archived_chat_messages_v1';
  static const int maxActiveWindow = 40;

  static final ChatArchiveService instance = ChatArchiveService._internal();
  ChatArchiveService._internal();

  /// Loads the active in-memory messages from local persistent storage.
  Future<List<ChatMessage>> loadActiveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_activeMessagesKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> decoded = json.decode(jsonString);
      return decoded.map((item) => ChatMessage.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Saves the active messages, automatically archiving any overflow beyond [maxActiveWindow].
  Future<void> saveActiveMessages(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (messages.length > maxActiveWindow) {
        final overflowCount = messages.length - maxActiveWindow;
        final toArchive = messages.sublist(0, overflowCount);
        final toRetain = messages.sublist(overflowCount);

        // Archive older messages to long-term storage
        await _appendToArchive(toArchive);

        final jsonString = json.encode(toRetain.map((m) => m.toMap()).toList());
        await prefs.setString(_activeMessagesKey, jsonString);
      } else {
        final jsonString = json.encode(messages.map((m) => m.toMap()).toList());
        await prefs.setString(_activeMessagesKey, jsonString);
      }
    } catch (_) {}
  }

  /// Archives the entire active session to long-term storage and resets the active window.
  Future<void> archiveCurrentSession(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _appendToArchive(messages);
      await prefs.remove(_activeMessagesKey);
    } catch (_) {}
  }

  /// Appends a batch of messages to the historical archive.
  Future<void> _appendToArchive(List<ChatMessage> newArchives) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingString = prefs.getString(_archivedMessagesKey);
      List<dynamic> list = [];
      if (existingString != null && existingString.isNotEmpty) {
        list = json.decode(existingString) as List<dynamic>;
      }

      list.addAll(newArchives.map((m) => m.toMap()));

      // Cap total historical archives at 500 to prevent unbounded disk growth
      if (list.length > 500) {
        list = list.sublist(list.length - 500);
      }

      await prefs.setString(_archivedMessagesKey, json.encode(list));
    } catch (_) {}
  }

  /// Loads archived history on-demand for lazy pagination.
  Future<List<ChatMessage>> loadArchivedMessages({int limit = 40}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_archivedMessagesKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> decoded = json.decode(jsonString);
      final all = decoded.map((item) => ChatMessage.fromMap(item as Map<String, dynamic>)).toList();

      if (all.length > limit) {
        return all.sublist(all.length - limit);
      }
      return all;
    } catch (_) {
      return [];
    }
  }

  /// Clears active and archived messages.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeMessagesKey);
    await prefs.remove(_archivedMessagesKey);
  }
}
