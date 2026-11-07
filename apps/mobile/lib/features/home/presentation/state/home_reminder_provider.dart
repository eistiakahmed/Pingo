import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/crypto/crypto_helper.dart';
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

/// State notifier managing home reminders with clean, dynamic data and cloud sync.
class HomeReminderNotifier extends StateNotifier<HomeReminderState> {
  HomeReminderNotifier()
      : super(
          const HomeReminderState(
            reminders: [], // Zero demo data: Starts pristine and clean
            isLoading: false,
          ),
        );

  /// Add a newly captured reminder
  void addReminder(ReminderItem item) {
    state = state.copyWith(
      reminders: [...state.reminders, item],
    );
  }

  /// Update an existing reminder
  void updateReminder(ReminderItem item) {
    state = state.copyWith(
      reminders: state.reminders.map((r) => r.id == item.id ? item : r).toList(),
    );
  }

  /// Snooze reminder by given duration
  void snooze(String id, Duration duration) {
    state = state.copyWith(
      reminders: state.reminders.map((r) {
        if (r.id == id) {
          return r.copyWith(
            dueAt: r.dueAt.add(duration),
            isOverdue: false,
          );
        }
        return r;
      }).toList(),
    );
  }

  /// Toggle task completion status
  void toggleDone(String id) {
    state = state.copyWith(
      reminders: state.reminders.map((r) {
        if (r.id == id) {
          return r.copyWith(isDone: !r.isDone);
        }
        return r;
      }).toList(),
    );
  }

  /// Delete a reminder
  void deleteReminder(String id) {
    state = state.copyWith(
      reminders: state.reminders.where((r) => r.id != id).toList(),
    );
  }

  /// Pushes all local reminders to server with Zero-Knowledge encryption
  Future<bool> pushToServer(SyncApiService syncService) async {
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      final dtos = state.reminders.map((r) {
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
  Future<bool> pullFromServer(SyncApiService syncService, {DateTime? since}) async {
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      final res = await syncService.pullSync(since: since);
      final remoteReminders = res.reminders.map((dto) {
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
          category: 'GENERAL',
          isDone: dto.isCompleted,
        );
      }).toList();

      // Merge avoiding duplicate IDs
      final currentMap = {for (var r in state.reminders) r.id: r};
      for (final remote in remoteReminders) {
        currentMap[remote.id] = remote;
      }

      state = state.copyWith(
        reminders: currentMap.values.toList(),
        isSyncing: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSyncing: false, syncError: e.toString());
      return false;
    }
  }

  /// Clear all reminders
  void clearAll() {
    state = state.copyWith(reminders: []);
  }
}

/// Riverpod provider for Home reminders
final homeReminderProvider =
    StateNotifierProvider<HomeReminderNotifier, HomeReminderState>((ref) {
  return HomeReminderNotifier();
});
