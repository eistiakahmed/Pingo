import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// Service managing offline persistent storage, guest session tokens, and 14-day retention.
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  static const String _keyReminders = 'pingo_cached_reminders_v1';
  static const String _keyAuthToken = 'pingo_auth_jwt_token';
  static const String _keyUserEmail = 'pingo_auth_user_email';
  static const String _keyUserName = 'pingo_auth_user_name';
  static const String _keyDeviceId = 'pingo_unique_device_id';
  static const String _keyGuestSessionId = 'pingo_ephemeral_session_id';

  /// Saves reminders to local disk storage, pruning completed items older than 14 days.
  Future<void> saveReminders(List<ReminderItem> reminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final retained = reminders.where((r) {
        if (!r.isDone) return true;
        final age = now.difference(r.dueAt).inDays;
        return age < 14;
      }).toList();

      final jsonList = retained.map((r) => r.toJson()).toList();
      await prefs.setString(_keyReminders, jsonEncode(jsonList));
      debugPrint(
        '[LocalStorage] Saved ${retained.length} reminders locally.',
      );
    } catch (e) {
      debugPrint('[LocalStorage] Error saving reminders: $e');
    }
  }

  /// Loads reminders from local disk storage.
  Future<List<ReminderItem>> loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyReminders);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List<dynamic>;
      final now = DateTime.now();

      return decoded
          .map((item) => ReminderItem.fromJson(item as Map<String, dynamic>))
          .where((r) {
            if (!r.isDone) return true;
            return now.difference(r.dueAt).inDays < 14;
          })
          .toList();
    } catch (e) {
      debugPrint('[LocalStorage] Error loading reminders: $e');
      return [];
    }
  }

  /// Returns true ONLY when an explicit user account (non-internal) has an active JWT.
  Future<bool> isExplicitlyAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyAuthToken);
      final email = prefs.getString(_keyUserEmail);
      if (token == null || token.trim().isEmpty) return false;
      if (email == null || email.trim().isEmpty) return false;
      if (email.endsWith('@pingo.internal')) {
        // Purge legacy shadow device credentials so unauthenticated sessions stay strictly ephemeral
        await prefs.remove(_keyAuthToken);
        await prefs.remove(_keyUserEmail);
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Gets the stored JWT authentication token ONLY if explicitly authenticated.
  Future<String?> getAuthToken() async {
    try {
      if (!await isExplicitlyAuthenticated()) return null;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAuthToken);
    } catch (e) {
      debugPrint('[LocalStorage] Error loading auth token: $e');
      return null;
    }
  }

  /// Saves the active JWT authentication token.
  Future<void> saveAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
    } catch (e) {
      debugPrint('[LocalStorage] Error saving auth token: $e');
    }
  }

  /// Saves the signed-in user's email and optional display name.
  Future<void> saveUserAccount({required String email, String? name}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserEmail, email);
      if (name != null && name.trim().isNotEmpty) {
        await prefs.setString(_keyUserName, name.trim());
      }
    } catch (e) {
      debugPrint('[LocalStorage] Error saving user account: $e');
    }
  }

  Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserEmail);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserName);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAuthSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserName);
    } catch (e) {
      debugPrint('[LocalStorage] Error clearing auth session: $e');
    }
  }

  /// Generates and persists a local UUID session token for unauthenticated `X-Session-ID` requests.
  Future<String> getOrCreateGuestSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sid = prefs.getString(_keyGuestSessionId);
      if (sid == null || sid.trim().isEmpty) {
        sid = const Uuid().v4();
        await prefs.setString(_keyGuestSessionId, sid);
      }
      return sid;
    } catch (_) {
      return const Uuid().v4();
    }
  }

  Future<String> getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_keyDeviceId);
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString(_keyDeviceId, deviceId);
      }
      return deviceId;
    } catch (_) {
      return const Uuid().v4();
    }
  }
}
