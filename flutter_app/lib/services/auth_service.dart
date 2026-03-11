import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/profile.dart';

class AuthService {
  static final _client = SupabaseService.client;
  static final _auth = SupabaseService.auth;

  // Sign up with email, password and username
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    if (response.user != null) {
      // Create profile
      await _client.from('profiles').upsert({
        'id': response.user!.id,
        'username': username,
        'display_name': username,
        'avatar_url': '',
        'is_admin': false,
      });
      // Create default settings
      await _client.from('user_settings').upsert({
        'user_id': response.user!.id,
        'ai_tone': 'professional',
        'summary_length': 'medium',
        'notifications': {
          'email_summaries': false,
          'meeting_reminders': true,
          'transcript_ready': true,
        },
        'default_view': 'grid',
        'preferences': {},
      });
    }
    return response;
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithPassword(email: email, password: password);
  }

  // Magic link
  static Future<void> signInWithMagicLink(String email) async {
    await _auth.signInWithOtp(email: email);
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Verify MFA
  static Future<AuthMFAChallengeResponse> createMfaChallenge(String factorId) async {
    return _auth.mfa.challenge(factorId: factorId);
  }

  static Future<AuthMFAVerifyResponse> verifyMfa({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    return _auth.mfa.verify(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
  }

  // Get MFA factors
  static Future<AuthMFAListFactorsResponse> getMfaFactors() async {
    return _auth.mfa.listFactors();
  }

  // Enroll MFA (TOTP)
  static Future<AuthMFAEnrollResponse> enrollMfa({String? issuer}) async {
    return _auth.mfa.enroll(issuer: issuer ?? 'CriptNote');
  }

  // Unenroll MFA
  static Future<void> unenrollMfa(String factorId) async {
    await _auth.mfa.unenroll(factorId);
  }

  // Update password
  static Future<UserResponse> updatePassword(String newPassword) async {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  // Get profile
  static Future<Profile?> getProfile(String userId) async {
    final response = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (response == null) return null;
    return Profile.fromJson(response);
  }

  // Update profile
  static Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  // Verify current password (by re-authenticating)
  static Future<bool> verifyPassword(String email, String password) async {
    try {
      final res = await _auth.signInWithPassword(email: email, password: password);
      return res.user != null;
    } catch (_) {
      return false;
    }
  }

  // Get recovery codes count
  static Future<int> getRecoveryCodesCount(String userId) async {
    final response = await _client.rpc('count_recovery_codes', params: {'p_user_id': userId});
    return response as int? ?? 0;
  }

  // Generate recovery codes
  static Future<List<String>> generateRecoveryCodes(String userId) async {
    final response = await _client.rpc('generate_recovery_codes', params: {'p_user_id': userId});
    if (response is List) return response.map((e) => e.toString()).toList();
    return [];
  }

  // Verify recovery code
  static Future<bool> verifyRecoveryCode(String userId, String code) async {
    final response = await _client.rpc('verify_recovery_code', params: {
      'p_user_id': userId,
      'p_code': code,
    });
    return response as bool? ?? false;
  }
}
