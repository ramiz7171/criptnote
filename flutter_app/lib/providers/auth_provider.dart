import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../models/profile.dart';

class AuthState {
  final User? user;
  final Profile? profile;
  final Session? session;
  final bool loading;
  final bool mfaRequired;
  final String? mfaFactorId;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.session,
    this.loading = true,
    this.mfaRequired = false,
    this.mfaFactorId,
    this.error,
  });

  AuthState copyWith({
    User? user,
    Profile? profile,
    Session? session,
    bool? loading,
    bool? mfaRequired,
    String? mfaFactorId,
    String? error,
  }) =>
      AuthState(
        user: user ?? this.user,
        profile: profile ?? this.profile,
        session: session ?? this.session,
        loading: loading ?? this.loading,
        mfaRequired: mfaRequired ?? this.mfaRequired,
        mfaFactorId: mfaFactorId ?? this.mfaFactorId,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() {
    final user = SupabaseService.currentUser;
    final session = SupabaseService.currentSession;

    if (user != null) {
      state = state.copyWith(user: user, session: session, loading: false);
      _loadProfile(user.id);
    } else {
      state = state.copyWith(loading: false);
    }

    // Listen to auth changes
    SupabaseService.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final newSession = data.session;

      if (event == AuthChangeEvent.signedIn && newSession != null) {
        state = state.copyWith(
          user: newSession.user,
          session: newSession,
          mfaRequired: false,
          mfaFactorId: null,
          loading: false,
        );
        _loadProfile(newSession.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AuthState(loading: false);
      } else if (event == AuthChangeEvent.tokenRefreshed && newSession != null) {
        state = state.copyWith(session: newSession);
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    final profile = await AuthService.getProfile(userId);
    state = state.copyWith(profile: profile);
  }

  Future<String?> signUp({required String email, required String password, required String username}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await AuthService.signUp(email: email, password: password, username: username);
      if (response.user == null) {
        state = state.copyWith(loading: false, error: 'Sign up failed');
        return 'Sign up failed';
      }
      state = state.copyWith(loading: false);
      return null;
    } catch (e) {
      final msg = e.toString();
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await AuthService.signIn(email: email, password: password);
      if (response.user == null) {
        state = state.copyWith(loading: false, error: 'Invalid credentials');
        return 'Invalid credentials';
      }

      // Check MFA
      final factors = await AuthService.getMfaFactors();
      final totpFactor = factors.totp.isNotEmpty ? factors.totp.first : null;

      if (totpFactor != null) {
        final aal = SupabaseService.auth.mfa.getAuthenticatorAssuranceLevel();
        if (aal.currentLevel == AuthenticatorAssuranceLevels.aal1 &&
            aal.nextLevel == AuthenticatorAssuranceLevels.aal2) {
          state = state.copyWith(
            loading: false,
            mfaRequired: true,
            mfaFactorId: totpFactor.id,
          );
          return null; // MFA needed
        }
      }

      state = state.copyWith(loading: false);
      return null;
    } catch (e) {
      final msg = e.toString();
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  Future<String?> signInWithMagicLink(String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await AuthService.signInWithMagicLink(email);
      state = state.copyWith(loading: false);
      return null;
    } catch (e) {
      final msg = e.toString();
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  Future<String?> verifyMfa(String code) async {
    if (state.mfaFactorId == null) return 'No MFA factor';
    state = state.copyWith(loading: true, error: null);
    try {
      final challenge = await AuthService.createMfaChallenge(state.mfaFactorId!);
      await AuthService.verifyMfa(
        factorId: state.mfaFactorId!,
        challengeId: challenge.id,
        code: code,
      );
      state = state.copyWith(loading: false, mfaRequired: false, mfaFactorId: null);
      return null;
    } catch (e) {
      final msg = e.toString();
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    state = const AuthState(loading: false);
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (state.user == null) return;
    await AuthService.updateProfile(state.user!.id, updates);
    await _loadProfile(state.user!.id);
  }

  void clearError() => state = state.copyWith(error: null);
  void clearMfa() => state = state.copyWith(mfaRequired: false, mfaFactorId: null);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
