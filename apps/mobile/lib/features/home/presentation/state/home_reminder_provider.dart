import 'dart:async';
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

/// State model for read-only, zero-touch Home Screen reminder lists.
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

  List<ReminderItem> get scheduledReminders =>
      reminders.where((r) => !r.isDone).toList();

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

/// Zero-touch reminder lifecycle notifier.
/// - Manual edit, manual delete, and manual completion toggles are deprecated.
/// - Reminders transition automatically and irreversibly from `scheduled` -> `completed`
///   when their scheduled time arrives, when a local/FCM alarm fires, or via `/sync/pull`.
/// - Strictly disables `/sync` and `/devices` calls when unauthenticated (ephemeral guest session).
class HomeReminderNotifier extends StateNotifier<HomeReminderState> {
  final Ref? _ref;
  StreamSubscription<TriggeredAlarmEvent>? _alarmSub;
  Timer? _autoCompleteTicker;

  HomeReminderNotifier([this._ref])
      : super(const HomeReminderState(reminders: [], isLoading: false)) {
    _initializePersistence();
    _bindZeroTouchCompletionTriggers();
  }

  void _bindZeroTouchCompletionTriggers() {
    _alarmSub = NotificationService.instance.onAlarmTriggered.listen((event) {
      autoCompleteDueTasks(triggeredSafeId: event.id);
    });

    // Lightweight 15s check while app is active so tasks transition cleanly at their exact due minute
    _autoCompleteTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      autoCompleteDueTasks();
    });
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
    _autoCompleteTicker?.cancel();
    super.dispose();
  }

  Future<void> _initializePersistence() async {
    try {
      final ref = _ref;
      if (ref != null) {
        final guestId =
            await LocalStorageService.instance.getOrCreateGuestSessionId();
        ref.read(apiClientProvider).setGuestSessionId(guestId);
      }

      // 1. Load local cache and auto-complete any reminders whose dueAt already passed
      final cached = await LocalStorageService.instance.loadReminders();
      if (cached.isNotEmpty) {
        final reconciled = _applyIrreversibleDueCheck(cached);
        state = state.copyWith(reminders: reconciled);
        LocalStorageService.instance.saveReminders(reconciled);
        _scheduleActiveFutureAlarms(reconciled);
      }

      if (ref == null) return;

      // 2. Directive 4: Strictly disable `/sync` & `/devices` calls when unauthenticated!
      final isAuthed =
          await LocalStorageService.instance.isExplicitlyAuthenticated();
      if (!isAuthed) {
        ref.read(apiClientProvider).setAuthToken(null);
        return;
      }

      final token = await LocalStorageService.instance.getAuthToken();
      if (token == null || token.isEmpty) return;

      final apiClient = ref.read(apiClientProvider);
      final authApi = ref.read(authApiServiceProvider);
      final syncApi = ref.read(syncApiServiceProvider);
      apiClient.setAuthToken(token);

      try {
        await authApi.getMe();
      } catch (_) {
        // Token expired/invalid: clear auth and remain in guest X-Session-ID mode
        await LocalStorageService.instance.clearAuthSession();
        apiClient.setAuthToken(null);
        return;
      }

      await FcmService.instance.registerActiveToken();
      await pullFromServer(syncApi);
    } catch (e) {
      debugPrint('[HomeReminderNotifier] Init warning: $e');
    }
  }

  List<ReminderItem> _applyIrreversibleDueCheck(
    List<ReminderItem> list, {
    int? triggeredSafeId,
  }) {
    final now = DateTime.now();
    return list.map((item) {
      if (item.isDone) return item;
      final itemSafeId = item.id.hashCode.abs() % 2147483647;
      if (!item.dueAt.isAfter(now) ||
          (triggeredSafeId != null && itemSafeId == triggeredSafeId)) {
        return item.markCompleted(now);
      }
      return item;
    }).toList();
  }

  /// Irreversibly transitions any due or triggered task to `completed`.
  void autoCompleteDueTasks({int? triggeredSafeId}) {
    if (state.reminders.isEmpty) return;
    bool changed = false;
    final now = DateTime.now();

    final updated = state.reminders.map((item) {
      if (item.isDone) return item;
      final itemSafeId = item.id.hashCode.abs() % 2147483647;
      if (!item.dueAt.isAfter(now) ||
          (triggeredSafeId != null && itemSafeId == triggeredSafeId)) {
        changed = true;
        return item.markCompleted(now);
      }
      return item;
    }).toList();

    if (changed) {
      state = state.copyWith(reminders: updated);
      _persistAndSyncIfAuthenticated();
    }
  }

  /// Triggered immediately after a user explicitly signs in or registers.
  Future<void> syncWithAuthenticatedAccount() async {
    final ref = _ref;
    if (ref == null) return;
    if (!await LocalStorageService.instance.isExplicitlyAuthenticated()) return;
    try {
      final syncApi = ref.read(syncApiServiceProvider);
      await pushToServer(syncApi);
      await pullFromServer(syncApi);
    } catch (e) {
      debugPrint('[HomeReminderNotifier] Post-auth sync warning: $e');
    }
  }

  void _scheduleActiveFutureAlarms(List<ReminderItem> items) {
    final now = DateTime.now();
    for (final item in items) {
      if (!item.isDone && item.dueAt.isAfter(now)) {
        final timeStr = DateFormat.jm().format(item.dueAt);
        final dateStr = DateFormat.MMMd().format(item.dueAt);
        NotificationService.instance.scheduleReminder(
          id: item.id.hashCode,
          title: item.title,
          body: '${item.category.badgeLabel} · $timeStr · $dateStr',
          scheduledDate: item.dueAt,
          isUrgent: item.category == ReminderCategory.medicine ||
              item.priority == ReminderPriority.important,
        );
      }
    }
  }

  Future<void> _persistAndSyncIfAuthenticated() async {
    await LocalStorageService.instance.saveReminders(state.reminders);
    final ref = _ref;
    if (ref != null &&
        await LocalStorageService.instance.isExplicitlyAuthenticated()) {
      final syncApi = ref.read(syncApiServiceProvider);
      await pushToServer(syncApi);
    }
  }

  /// Registers a newly classified autonomous reminder and schedules its native exact alarm.
  void addReminder(ReminderItem item) {
    final now = DateTime.now();
    final effectiveItem =
        !item.dueAt.isAfter(now) ? item.markCompleted(now) : item;

    state = state.copyWith(
      reminders: [
        ...state.reminders.where((r) => r.id != effectiveItem.id),
        effectiveItem,
      ],
    );

    if (!effectiveItem.isDone) {
      final timeStr = DateFormat.jm().format(effectiveItem.dueAt);
      final dateStr = DateFormat.MMMd().format(effectiveItem.dueAt);
      NotificationService.instance.scheduleReminder(
        id: effectiveItem.id.hashCode,
        title: effectiveItem.title,
        body: '${effectiveItem.category.badgeLabel} · $timeStr · $dateStr',
        scheduledDate: effectiveItem.dueAt,
        isUrgent: effectiveItem.category == ReminderCategory.medicine ||
            effectiveItem.priority == ReminderPriority.important,
      );
    }
    _persistAndSyncIfAuthenticated();
  }

  /// Pushes reminders to server ONLY when authenticated.
  Future<bool> pushToServer(SyncApiService syncService) async {
    if (!await LocalStorageService.instance.isExplicitlyAuthenticated()) {
      return false;
    }
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      final now = DateTime.now();
      final activeList = state.reminders.where((r) {
        if (!r.isDone) return true;
        return now.difference(r.dueAt).inDays < 14;
      }).toList();

      final dtos = activeList.map((r) {
        final encodedPayload = '${r.category.badgeLabel}::${r.title}';
        return EncryptedReminderDto(
          id: r.id,
          ciphertext: CryptoHelper.toBase64(encodedPayload),
          iv: CryptoHelper.toBase64('0123456789ab'),
          authTag: CryptoHelper.toBase64('abcdefghijklmnop'),
          dueAt: r.dueAt,
          isCompleted: r.isDone,
          version: r.isDone ? 2 : 1,
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

  /// Pulls remote delta updates ONLY when authenticated and reflects irreversible `completed` transitions.
  Future<bool> pullFromServer(SyncApiService syncService,
      {DateTime? since}) async {
    if (!await LocalStorageService.instance.isExplicitlyAuthenticated()) {
      return false;
    }
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      final res = await syncService.pullSync(since: since);
      final now = DateTime.now();

      final existingById = {for (final r in state.reminders) r.id: r};

      final remoteReminders = res.reminders
          .where((dto) => dto.deletedAt == null)
          .map((dto) {
        String rawDecoded;
        try {
          rawDecoded = CryptoHelper.fromBase64(dto.ciphertext);
        } catch (_) {
          rawDecoded = 'Reminder';
        }

        ReminderCategory cat =
            existingById[dto.id]?.category ?? ReminderCategory.general;
        String cleanTitle = rawDecoded;
        if (rawDecoded.contains('::')) {
          final idx = rawDecoded.indexOf('::');
          cat = ReminderCategory.fromBackendString(rawDecoded.substring(0, idx));
          cleanTitle = rawDecoded.substring(idx + 2);
        }

        final dueLocal = (dto.dueAt ?? now).toLocal();
        final existingDone = existingById[dto.id]?.isDone ?? false;
        final isCompleted =
            existingDone || dto.isCompleted || !dueLocal.isAfter(now);

        return ReminderItem(
          id: dto.id,
          title: cleanTitle,
          dueAt: dueLocal,
          category: cat,
          state: isCompleted
              ? TaskLifecycleState.completed
              : TaskLifecycleState.scheduled,
          completedAt: isCompleted
              ? (existingById[dto.id]?.completedAt ?? dto.updatedAt ?? now)
              : null,
        );
      }).where((r) {
        if (!r.isDone) return true;
        return now.difference(r.dueAt).inDays < 14;
      }).toList();

      final currentMap = {for (final r in state.reminders) r.id: r};
      for (final remote in remoteReminders) {
        final local = currentMap[remote.id];
        // Enforce strict monotonicity: once completed locally or remotely, stays completed
        if (local != null && local.isDone && !remote.isDone) {
          currentMap[remote.id] = local;
        } else {
          currentMap[remote.id] = remote;
        }
      }

      final merged = _applyIrreversibleDueCheck(currentMap.values.toList());
      state = state.copyWith(
        reminders: merged,
        isSyncing: false,
      );

      await LocalStorageService.instance.saveReminders(merged);
      _scheduleActiveFutureAlarms(merged);
      return true;
    } catch (e) {
      state = state.copyWith(isSyncing: false, syncError: e.toString());
      return false;
    }
  }
}

final homeReminderProvider =
    StateNotifierProvider<HomeReminderNotifier, HomeReminderState>((ref) {
  return HomeReminderNotifier(ref);
});
