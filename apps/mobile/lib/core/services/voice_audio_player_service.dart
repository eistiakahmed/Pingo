import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Singleton audio playback controller wrapping `just_audio` for WhatsApp-style
/// voice message bubbles and immediate AI reply auto-play.
class VoiceAudioPlayerService extends ChangeNotifier {
  VoiceAudioPlayerService._() {
    _bindStreams();
  }

  static final VoiceAudioPlayerService instance = VoiceAudioPlayerService._();

  final AudioPlayer _player = AudioPlayer();

  String? _activeMessageId;
  String? _activeUrl;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? get activeMessageId => _activeMessageId;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;

  bool isPlayingMessage(String messageId) =>
      _activeMessageId == messageId && _isPlaying;

  bool isActiveMessage(String messageId) => _activeMessageId == messageId;

  void _bindStreams() {
    _player.playerStateStream.listen((state) {
      final completed = state.processingState == ProcessingState.completed;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      if (completed) {
        _isPlaying = false;
        _position = Duration.zero;
        _player.pause();
        _player.seek(Duration.zero);
      } else {
        _isPlaying = state.playing;
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  /// Auto-plays or toggles playback for a voice bubble.
  Future<void> toggleOrPlay({
    required String messageId,
    required String audioUrl,
  }) async {
    if (audioUrl.trim().isEmpty) return;

    try {
      if (_activeMessageId == messageId && _activeUrl == audioUrl) {
        if (_isPlaying) {
          await _player.pause();
        } else {
          if (_duration > Duration.zero && _position >= _duration) {
            await _player.seek(Duration.zero);
          }
          await _player.play();
        }
        return;
      }

      await playUrl(messageId: messageId, audioUrl: audioUrl);
    } catch (e) {
      debugPrint('[VoiceAudioPlayerService] Playback error: $e');
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Loads `$baseUrl$audioUrl` into `just_audio` and starts playback immediately.
  Future<void> playUrl({
    required String messageId,
    required String audioUrl,
  }) async {
    if (audioUrl.trim().isEmpty) return;
    try {
      _activeMessageId = messageId;
      _activeUrl = audioUrl;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isLoading = true;
      notifyListeners();

      await _player.stop();
      final loadedDuration = await _player.setUrl(audioUrl);
      if (loadedDuration != null) {
        _duration = loadedDuration;
      }
      _isLoading = false;
      notifyListeners();

      await _player.play();
    } catch (e) {
      debugPrint('[VoiceAudioPlayerService] Auto-play error ($audioUrl): $e');
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> seekForMessage(String messageId, Duration target) async {
    if (_activeMessageId != messageId) return;
    try {
      await _player.seek(target);
    } catch (e) {
      debugPrint('[VoiceAudioPlayerService] Seek error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _isLoading = false;
      _position = Duration.zero;
      notifyListeners();
    } catch (_) {}
  }
}
