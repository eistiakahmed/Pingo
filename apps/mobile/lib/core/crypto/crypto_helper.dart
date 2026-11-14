import 'dart:convert';
import 'dart:math';

/// Cryptographic and Zero-Knowledge client utilities
class CryptoHelper {
  CryptoHelper._();

  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically strong random salt string
  static String generateClientSalt([int byteLength = 16]) {
    final values = List<int>.generate(byteLength, (_) => _secureRandom.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Encodes string or bytes to standard Base64
  static String toBase64(String input) {
    return base64Encode(utf8.encode(input));
  }

  /// Decodes standard Base64 to string
  static String fromBase64(String base64Str) {
    return utf8.decode(base64Decode(base64Str));
  }
}

