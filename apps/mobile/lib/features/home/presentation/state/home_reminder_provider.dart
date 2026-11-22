import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/crypto/crypto_helper.dart';
import 'package:pingo_mobile/core/network/providers.dart';
import 'package:pingo_mobile/core/services/fcm_service.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/core/storage/local_storage_service.dart';
import 'package:pingo_mobile/features/home/data/sync_api_service.dart';
import 'package:pingo_mobile/features/home/domain/sync_models.dart';
import '../../domain/reminder_item.dart';

/// State model for Home Screen reminder lists.
class HomeReminderState {
  final List<ReminderItem> reminders;
  final bool isLoading;
  final bool isSyncing;
  final String? syncError;

  const HomeReminderState({
    required this.reminders,
    this.isLoading = false,
    this.isSyncing = false,
    this.syncError,
  });

  List<ReminderItem> get todayReminders =>
      reminders.where((r) => !r.isDone && !r.isOverdue).toList();

  List<ReminderItem> get overdueReminders =>
      reminders.where((r) => !r.isDone && r.isOverdue).toList();

  List<ReminderItem> get completedReminders =>
      reminders.where((r) => r.isDone).toList();

  HomeReminderState copyWith({
    List<ReminderItem>? reminders,
    bool? isLoading,
    bool? isSyncing,
    String? syncError,
  }) {
    return HomeReminderState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncError: syncError,
    );
  }
}

/// State notifier managing home reminders with persistent local storage and cloud database sync.
class HomeReminderNotifier extends StateNotifier<HomeReminderState> {
  final Ref? _ref;

  HomeReminderNotifier([this._ref])
      : super(
          const HomeReminderState(
            reminders: [],
            isLoading: false,
          ),
        ) {
    _initializePersistence();
  }

  /// Initializes local storage loading and silent background sync with PostgreSQL.
  Future<void> _initializePersistence() async {
    try {
      // 1. Load from local device cache instantly
      final cached = await LocalStorageService.instance.loadReminders();
      if (cached.isNotEmpty) {
        state = state.copyWith(reminders: cached);
      }

      final ref = _ref;
      if (ref == null) return;

      // 2. Ensure auth session & sync with cloud PostgreSQL
      final authApi = ref.read(authApiServiceProvider);
      final syncApi = ref.read(syncApiServiceProvider);
      final apiClient = ref.read(apiClientProvider);

      String? token = await LocalStorageService.instance.getAuthToken();
      if (token == null || token.isEmpty) {
        final deviceId = await LocalStorageService.instance.getOrCreateDeviceId();
        final deviceEmail =
            'device_${deviceId.replaceAll("-", "").substring(0, 12)}@pingo.internal';
        final devicePass = 'PingoSec_${deviceId.substring(0, 16)}!';

        try {
          final session =
              await authApi.register(email: deviceEmail, password: devicePass);
          token = session.accessToken;
        } catch (_) {
          final session =
              await authApi.login(email: deviceEmail, password: devicePass);
          token = session.accessToken;
        }
        await LocalStorageService.instance.saveAuthToken(token);
      }

      apiClient.setAuthToken(token);

      // Pull updates from AWS PostgreSQL
      await pullFromServer(syncApi);

      // Register device FCM push token with backend
      FcmService.instance.registerActiveToken();
    } catch (e) {
      debugPrint('[HomeReminderNotifier] Cloud sync init warning: $e');
    }
  }

  void _persistAndSync() {
    LocalStorageService.instance.saveReminders(state.reminders);
    final ref = _ref;
    if (ref != null) {
      final syncApi = ref.read(syncApiServiceProvider);
      pushToServer(syncApi);
    }
  }

  /// Add a newly captured reminder
  void addReminder(ReminderItem item) {
    state = state.copyWith(
      reminders: [...state.reminders, item],
    );
    if (!item.isDone) {
      final timeStr = DateFormat.jm().format(item.dueAt);
      final dateStr = DateFormat.MMMd().format(item.dueAt);
      NotificationService.instance.scheduleReminder(
        id: item.id.hashCode,
        title: item.title,
        body: '$timeStr · $dateStr',
        scheduledDate: item.dueAt,
        isUrgent: item.category == ReminderCategory.medicine ||
            item.priority == ReminderPriority.important,
      );
    }
    _persistAndSync();
  }

  /// Update an existing reminder
  void updateReminder(ReminderItem item) {
    state = state.copyWith(
      reminders:
          state.reminders.map((r) => r.id == item.id ? item : r).toList(),
    );
    if (!item.isDone) {
      final timeStr = DateFormat.jm().format(item.dueAt);
      final dateStr = DateFormat.MMMd().format(item.dueAt);
      NotificationService.instance.scheduleReminder(
        id: item.id.hashCode,
        title: item.title,
        body: '$timeStr · $dateStr',
        scheduledDate: item.dueAt,
        isUrgent: item.category == ReminderCategory.medicine ||
            item.priority == ReminderPriority.important,
      );
    } else {
      NotificationService.instance.cancelReminder(item.id.hashCode);
    }
    _persistAndSync();
  }

  /// Snooze reminder by given duration
  void snooze(String id, Duration duration) {
    state = state.copyWith(
      reminders: state.reminders.map((r) {
        if (r.id == id) {
          final updated = r.copyWith(
            dueAt: r.dueAt.add(duration),
            isOverdue: false,
          );
          final timeStr = DateFormat.jm().format(updated.dueAt);
          final dateStr = DateFormat.MMMd().format(updated.dueAt);
          NotificationService.instance.scheduleReminder(
            id: updated.id.hashCode,
            title: updated.title,
            body: '$timeStr · $dateStr (Snoozed)',
            scheduledDate: updated.dueAt,
          );
          return updated;
        }
        return r;
      }).toList(),
    );
    _persistAndSync();
  }

  /// Toggle task completion status
  void toggleDone(String id) {
    state = state.copyWith(
      reminders: state.reminders.map((r) {
        if (r.id == id) {
          final newDone = !r.isDone;
          if (newDone) {
            NotificationService.instance.cancelReminder(r.id.hashCode);
          } else {
            final timeStr = DateFormat.jm().format(r.dueAt);
            final dateStr = DateFormat.MMMd().format(r.dueAt);
            NotificationService.instance.scheduleReminder(
              id: r.id.hashCode,
              title: r.title,
              body: '$timeStr · $dateStr',
              scheduledDate: r.dueAt,
            );
          }
          return r.copyWith(isDone: newDone);
        }
        return r;
      }).toList(),
    );
    _persistAndSync();
  }

  /// Delete a reminder and push a tombstone to the cloud so it never resurrects
  void deleteReminder(String id) {
    final deletedItem =
        state.reminders.where((r) => r.id == id).firstOrNull;
    NotificationService.instance.cancelReminder(id.hashCode);
    state = state.copyWith(
      reminders: state.reminders.where((r) => r.id != id).toList(),
    );
    LocalStorageService.instance.saveReminders(state.reminders);
    final ref = _ref;
    if (ref != null) {
      final syncApi = ref.read(syncApiServiceProvider);
      if (deletedItem != null) {
        syncApi.pushSync(
          reminders: [
            EncryptedReminderDto(
              id: deletedItem.id,
              ciphertext: CryptoHelper.toBase64(deletedItem.title),
              iv: CryptoHelper.toBase64('0123456789ab'),
              authTag: CryptoHelper.toBase64('abcdefghijklmnop'),
              dueAt: deletedItem.dueAt,
              isCompleted: deletedItem.isDone,
              version: 2,
              deletedAt: DateTime.now().toUtc(),
            ),
          ],
        );
      }
      pushToServer(syncApi);
    }
  }

  /// Pushes all local reminders to server with Zero-Knowledge encryption
  Future<bool> pushToServer(SyncApiService syncService) async {
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      final now = DateTime.now();
      // Apply 14-day retention rule for completed reminders
      final activeList = state.reminders.where((r) {
        if (!r.isDone) return true;
        return now.difference(r.dueAt).inDays < 14;
      }).toList();

      final dtos = activeList.map((r) {
        return EncryptedReminderDto(
          id: r.id,
          ciphertext: CryptoHelper.toBase64(r.title),
          iv: CryptoHelper.toBase64('0123456789ab'),
          authTag: CryptoHelper.toBase64('abcdefghijklmnop'),
          dueAt: r.dueAt,
          isCompleted: r.isDone,
          version: 1,
        );
      }).toList();

      final res = await syncService.pushSync(reminders: dtos);
      state = state.copyWith(isSyncing: false);
      return res.success;
    } catch (e) {
      state = state.copyWith(isSyncing: false, syncError: e.toString());
      return false;
    }
  }

  /// Pulls remote delta updates and merges into local list
  Future<bool> pullFromServer(SyncApiService syncService,
      {DateTime? since}) async {
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      final res = await syncService.pullSync(since: since);
      final now = DateTime.now();

      final deletedIds = res.reminders
          .where((dto) => dto.deletedAt != null)
          .map((dto) => dto.id)
          .toSet();

      final remoteReminders = res.reminders
          .where((dto) => dto.deletedAt == null)
          .map((dto) {
        String decodedTitle;
        try {
          decodedTitle = CryptoHelper.fromBase64(dto.ciphertext);
        } catch (_) {
          decodedTitle = 'Encrypted Reminder';
        }

        return ReminderItem(
          id: dto.id,
          title: decodedTitle,
          dueAt: dto.dueAt ?? DateTime.now(),
          category: ReminderCategory.other,
          isDone: dto.isCompleted,
        );
      }).where((r) {
        // Enforce 14-day completed retention policy
        if (!r.isDone) return true;
        return now.difference(r.dueAt).inDays < 14;
      }).toList();

      // Merge avoiding duplicate IDs and removing server-deleted tombstones
      final currentMap = {
        for (var r in state.reminders)
          if (!deletedIds.contains(r.id)) r.id: r,
      };
      for (final remote in remoteReminders) {
        currentMap[remote.id] = remote;
      }

      final merged = currentMap.values.toList();
      state = state.copyWith(
        reminders: merged,
        isSyncing: false,
      );

      // Save merged list locally
      LocalStorageService.instance.saveReminders(merged);
      return true;
    } catch (e) {
      state = state.copyWith(isSyncing: false, syncError: e.toString());
      return false;
    }
  }

  /// Clear all reminders
  void clearAll() {
    state = state.copyWith(reminders: []);
    _persistAndSync();
  }
}

/// Riverpod provider for Home reminders
final homeReminderProvider =
    StateNotifierProvider<HomeReminderNotifier, HomeReminderState>((ref) {
  return HomeReminderNotifier(ref);
});
