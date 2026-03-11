import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../services/crypto_service.dart';
import '../services/auth_service.dart';
import 'auth_provider.dart';

class SecurityState {
  final bool isLocked;
  final bool isPinEnabled;
  final bool isBiometricAvailable;
  final int idleTimeoutMinutes;

  const SecurityState({
    this.isLocked = false,
    this.isPinEnabled = false,
    this.isBiometricAvailable = false,
    this.idleTimeoutMinutes = 0,
  });

  SecurityState copyWith({
    bool? isLocked,
    bool? isPinEnabled,
    bool? isBiometricAvailable,
    int? idleTimeoutMinutes,
  }) =>
      SecurityState(
        isLocked: isLocked ?? this.isLocked,
        isPinEnabled: isPinEnabled ?? this.isPinEnabled,
        isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
        idleTimeoutMinutes: idleTimeoutMinutes ?? this.idleTimeoutMinutes,
      );
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  SecurityNotifier(this._ref) : super(const SecurityState()) {
    _init();
  }

  final Ref _ref;
  final _localAuth = LocalAuthentication();

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPinHash = prefs.getString(AppConstants.pinStorageKey) != null;
    final canBiometric = await _localAuth.canCheckBiometrics;
    state = state.copyWith(
      isPinEnabled: hasPinHash,
      isBiometricAvailable: canBiometric,
    );
  }

  void lock() {
    state = state.copyWith(isLocked: true);
  }

  Future<bool> unlockWithPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(AppConstants.pinStorageKey);
    if (storedHash == null) return false;

    final inputHash = CryptoService.sha256Hash(pin);
    if (inputHash == storedHash) {
      state = state.copyWith(isLocked: false);
      return true;
    }
    return false;
  }

  Future<bool> unlockWithPassword(String password) async {
    final auth = _ref.read(authProvider);
    if (auth.user == null) return false;
    final email = auth.user!.email ?? '';
    final valid = await AuthService.verifyPassword(email, password);
    if (valid) {
      state = state.copyWith(isLocked: false);
    }
    return valid;
  }

  Future<bool> unlockWithBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock CriptNote',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (authenticated) {
        state = state.copyWith(isLocked: false);
      }
      return authenticated;
    } catch (_) {
      return false;
    }
  }

  Future<void> setupPin(String pin) async {
    final hash = CryptoService.sha256Hash(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.pinStorageKey, hash);
    state = state.copyWith(isPinEnabled: true, isLocked: false);
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.pinStorageKey);
    state = state.copyWith(isPinEnabled: false);
  }

  void setIdleTimeout(int minutes) {
    state = state.copyWith(idleTimeoutMinutes: minutes);
  }
}

final securityProvider = StateNotifierProvider<SecurityNotifier, SecurityState>(
  (ref) => SecurityNotifier(ref),
);
