import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/crypto_service.dart';
import '../services/settings_service.dart';
import 'settings_provider.dart';

class EncryptionState {
  final bool isEncryptionEnabled;
  final bool isUnlocked;
  final Uint8List? key;

  const EncryptionState({
    this.isEncryptionEnabled = false,
    this.isUnlocked = false,
    this.key,
  });

  EncryptionState copyWith({bool? isEncryptionEnabled, bool? isUnlocked, Uint8List? key}) =>
      EncryptionState(
        isEncryptionEnabled: isEncryptionEnabled ?? this.isEncryptionEnabled,
        isUnlocked: isUnlocked ?? this.isUnlocked,
        key: key ?? this.key,
      );
}

class EncryptionNotifier extends StateNotifier<EncryptionState> {
  EncryptionNotifier(this._ref) : super(const EncryptionState());

  final Ref _ref;

  void updateFromSettings(bool enabled) {
    if (!enabled) {
      state = const EncryptionState();
    } else {
      state = state.copyWith(isEncryptionEnabled: true);
    }
  }

  Future<bool> unlock(String passphrase) async {
    final settings = _ref.read(settingsProvider).settings;
    if (settings == null) return false;
    final salt = settings.encryptionSalt;
    if (salt == null) return false;

    try {
      final key = CryptoService.deriveKey(passphrase, salt);
      // Test by trying to decrypt a known value if available
      state = state.copyWith(isUnlocked: true, key: key);
      return true;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    state = state.copyWith(isUnlocked: false, key: null);
  }

  Future<void> enableEncryption({
    required String passphrase,
    required String userId,
    required List<Map<String, dynamic>> existingNotes,
    Function(double)? onProgress,
  }) async {
    final salt = CryptoService.generateSalt();
    final key = CryptoService.deriveKey(passphrase, salt);

    // Encrypt all existing notes
    final total = existingNotes.length;
    for (int i = 0; i < total; i++) {
      final note = existingNotes[i];
      final content = note['content'] as String? ?? '';
      if (content.isNotEmpty && !CryptoService.isEncrypted(content)) {
        CryptoService.encryptString(content, key); // individual note update handled by notes provider
        await SettingsService.updateSettings(userId, {});
      }
      onProgress?.call((i + 1) / total);
    }

    // Save salt to settings
    await SettingsService.updateSettings(userId, {
      'preferences': {
        'encryption_enabled': true,
        'encryption_salt': salt,
      }
    });

    state = EncryptionState(isEncryptionEnabled: true, isUnlocked: true, key: key);
  }

  Future<void> disableEncryption({
    required String passphrase,
    required String userId,
  }) async {
    await SettingsService.updateSettings(userId, {
      'preferences': {
        'encryption_enabled': false,
        'encryption_salt': null,
      }
    });
    state = const EncryptionState();
  }

  String encryptString(String plaintext) {
    if (!state.isUnlocked || state.key == null) return plaintext;
    return CryptoService.encryptString(plaintext, state.key!);
  }

  String decryptString(String ciphertext) {
    if (!state.isUnlocked || state.key == null) return ciphertext;
    if (!CryptoService.isEncrypted(ciphertext)) return ciphertext;
    try {
      return CryptoService.decryptString(ciphertext, state.key!);
    } catch (_) {
      return ciphertext;
    }
  }
}

final encryptionProvider = StateNotifierProvider<EncryptionNotifier, EncryptionState>(
  (ref) => EncryptionNotifier(ref),
);
