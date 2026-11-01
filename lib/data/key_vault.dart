import 'dart:convert';
import 'dart:typed_data';

/// Encrypts and decrypts sensitive API keys stored on disk so raw provider
/// tokens (sk-..., gsk_...) never sit as plain text in SharedPreferences.
class KeyVault {
  static const _prefix = 'enc:v1:';

  static const _salt = [
    0x48, 0x69, 0x6E, 0x64, 0x53, 0x69, 0x67, 0x68,
    0x74, 0x2E, 0x53, 0x65, 0x63, 0x75, 0x72, 0x65,
    0x56, 0x61, 0x75, 0x6C, 0x74, 0x2E, 0x32, 0x30,
    0x32, 0x36, 0x2E, 0x4B, 0x65, 0x79, 0x41, 0x69,
  ];

  static String encrypt(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final bytes = utf8.encode(text);
    final masked = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      masked[i] = bytes[i] ^ _salt[i % _salt.length];
    }
    return '$_prefix${base64Url.encode(masked)}';
  }

  static String decrypt(String stored) {
    final trimmed = stored.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith(_prefix)) {
      // Legacy unencrypted plaintext: return directly and migrate on next save.
      return trimmed;
    }
    try {
      final payload = trimmed.substring(_prefix.length);
      final masked = base64Url.decode(payload);
      final bytes = Uint8List(masked.length);
      for (var i = 0; i < masked.length; i++) {
        bytes[i] = masked[i] ^ _salt[i % _salt.length];
      }
      return utf8.decode(bytes);
    } catch (_) {
      return '';
    }
  }
}
