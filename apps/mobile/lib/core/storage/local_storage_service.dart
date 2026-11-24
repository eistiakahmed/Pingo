import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// Service managing offline persistent storage and automatic data retention.
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  static const String _keyReminders = 'pingo_cached_reminders_v1';
  static const String _keyAuthToken = 'pingo_auth_jwt_token';
  static const String _keyUserEmail = 'pingo_auth_user_email';
  static const String _keyUserName = 'pingo_auth_user_name';
  static const String _keyDeviceId = 'pingo_unique_device_id';

  /// Saves active reminders to local disk storage, automatically pruning
  /// items completed more than 14 days ago according to the retention policy.
  Future<void> saveReminders(List<ReminderItem> reminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Data retention: remove items completed more than 14 days ago
      final retained = reminders.where((r) {
        if (!r.isDone) return true;
        final age = now.difference(r.dueAt).inDays;
        return age < 14;
      }).toList();

      final jsonList = retained.map((r) => r.toJson()).toList();
      await prefs.setString(_keyReminders, jsonEncode(jsonList));
      debugPrint('[LocalStorage] Saved ${retained.length} reminders locally (auto-pruned ${reminders.length - retained.length} items >14d old).');
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

      final list = decoded
          .map((item) => ReminderItem.fromJson(item as Map<String, dynamic>))
          .where((r) {
            // Apply 14-day completed retention rule
            if (!r.isDone) return true;
            return now.difference(r.dueAt).inDays < 14;
          })
          .toList();

      return list;
    } catch (e) {
      debugPrint('[LocalStorage] Error loading reminders: $e');
      return [];
    }
  }

  /// Gets the stored JWT authentication token, if any.
  Future<String?> getAuthToken() async {
    try {
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

  /// Gets the signed-in user's email, if an explicit account is logged in.
  Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserEmail);
    } catch (e) {
      return null;
    }
  }

  /// Gets the signed-in user's display name, if saved.
  Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserName);
    } catch (e) {
      return null;
    }
  }

  /// Clears the explicit user session (token, email, and name).
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

  /// Retrieves or generates a persistent anonymous device ID.
  Future<String> getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_keyDeviceId);
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString(_keyDeviceId, deviceId);
      }
      return deviceId;
    } catch (e) {
      return const Uuid().v4();
    }
  }
}

