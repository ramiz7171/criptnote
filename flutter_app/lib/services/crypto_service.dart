import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// AES-GCM-256 encryption matching the web app's Web Crypto API implementation.
/// Format: 'enc:' + base64(IV[12 bytes] + ciphertext + authTag[16 bytes])
class CryptoService {
  static const String _prefix = 'enc:';
  static const int _ivLength = 12;
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 16;
  static const int _pbkdf2Iterations = 100000;

  // Generate random salt (16 bytes) as base64
  static String generateSalt() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(List.generate(_saltLength, (_) => random.nextInt(256)));
    return base64Encode(bytes);
  }

  // Derive AES key from passphrase + salt using PBKDF2-SHA256
  static Uint8List deriveKey(String passphrase, String saltBase64) {
    final salt = base64Decode(saltBase64);
    final passphraseBytes = utf8.encode(passphrase);

    final params = Pbkdf2Parameters(Uint8List.fromList(salt), _pbkdf2Iterations, _keyLength);
    final keyDerivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))..init(params);

    return keyDerivator.process(Uint8List.fromList(passphraseBytes));
  }

  // Encrypt string, returns 'enc:' + base64(iv + ciphertext)
  static String encryptString(String plaintext, Uint8List key) {
    final random = Random.secure();
    final iv = Uint8List.fromList(List.generate(_ivLength, (_) => random.nextInt(256)));
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

    final ciphertext = cipher.process(plaintextBytes);

    // Combine IV + ciphertext (GCM appends auth tag automatically)
    final combined = Uint8List(iv.length + ciphertext.length);
    combined.setAll(0, iv);
    combined.setAll(iv.length, ciphertext);

    return _prefix + base64Encode(combined);
  }

  // Decrypt string, input must start with 'enc:'
  static String decryptString(String encrypted, Uint8List key) {
    if (!encrypted.startsWith(_prefix)) return encrypted;

    final combined = base64Decode(encrypted.substring(_prefix.length));
    final iv = combined.sublist(0, _ivLength);
    final ciphertext = combined.sublist(_ivLength);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, Uint8List.fromList(iv), Uint8List(0)));

    final plaintext = cipher.process(Uint8List.fromList(ciphertext));
    return utf8.decode(plaintext);
  }

  // Encrypt binary data (for files)
  static Uint8List encryptBytes(Uint8List data, Uint8List key) {
    final random = Random.secure();
    final iv = Uint8List.fromList(List.generate(_ivLength, (_) => random.nextInt(256)));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

    final ciphertext = cipher.process(data);

    final combined = Uint8List(iv.length + ciphertext.length);
    combined.setAll(0, iv);
    combined.setAll(iv.length, ciphertext);

    return combined;
  }

  // Decrypt binary data
  static Uint8List decryptBytes(Uint8List combined, Uint8List key) {
    final iv = combined.sublist(0, _ivLength);
    final ciphertext = combined.sublist(_ivLength);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, Uint8List.fromList(iv), Uint8List(0)));

    return cipher.process(Uint8List.fromList(ciphertext));
  }

  // SHA-256 hash a string (for PIN storage)
  static String sha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if a string is encrypted
  static bool isEncrypted(String value) => value.startsWith(_prefix);
}
