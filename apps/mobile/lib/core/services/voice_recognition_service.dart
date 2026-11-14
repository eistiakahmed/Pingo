import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service managing hardware microphone audio capture and Speech-to-Text conversion.
class VoiceRecognitionService {
  VoiceRecognitionService._();
  static final VoiceRecognitionService instance = VoiceRecognitionService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  List<stt.LocaleName> _supportedLocales = [];

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;
  List<stt.LocaleName> get supportedLocales => _supportedLocales;

  /// Initializes speech recognition engine and requests microphone permissions.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) => debugPrint('[VoiceRecognition] Status: $status'),
        onError: (error) => debugPrint('[VoiceRecognition] Error: $error'),
      );

      if (_isInitialized) {
        _supportedLocales = await _speech.locales();
        debugPrint('[VoiceRecognition] Found ${_supportedLocales.length} speech locales');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('[VoiceRecognition] Exception during init: $e');
      return false;
    }
  }

  /// Finds the best available matching locale for a given language code ('bn' or 'en').
  String? findBestLocale(String langCode) {
    if (_supportedLocales.isEmpty) return null;

    final target = langCode.toLowerCase().trim();
    if (target == 'bn' || target == 'bangla') {
      // 1. Exact match for Bangladesh
      for (final loc in _supportedLocales) {
        final id = loc.localeId.toLowerCase();
        if (id == 'bn_bd' || id == 'bn-bd') return loc.localeId;
      }
      // 2. Any Bengali locale (bn_IN, etc.)
      for (final loc in _supportedLocales) {
        if (loc.localeId.toLowerCase().startsWith('bn')) return loc.localeId;
      }
    } else if (target == 'en' || target == 'english') {
      for (final loc in _supportedLocales) {
        final id = loc.localeId.toLowerCase();
        if (id == 'en_us' || id == 'en-us') return loc.localeId;
      }
      for (final loc in _supportedLocales) {
        if (loc.localeId.toLowerCase().startsWith('en')) return loc.localeId;
      }
    }

    return null;
  }

  /// Starts listening for spoken words and returns transcribed words in real-time.
  /// Uses continuous dictation mode with extended pause thresholds for long voice notes.
  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    Function(double soundLevel)? onSoundLevelChange,
    Function(String status)? onStatusChange,
    String? localeId,
  }) async {
    final ready = await initialize();
    if (!ready) {
      debugPrint('[VoiceRecognition] Cannot start listening: Engine not ready');
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        localeId: localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        onSoundLevelChange: onSoundLevelChange,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('[VoiceRecognition] Error starting listen: $e');
    }
  }

  /// Stops speech listening and finalizes recognized text.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Cancels speech recognition.
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  /// Returns system locales supported by the device's speech engine.
  Future<List<stt.LocaleName>> getSupportedLocales() async {
    final ready = await initialize();
    if (!ready) return [];
    return _speech.locales();
  }
}

