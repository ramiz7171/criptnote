import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/user_settings.dart';

class SettingsService {
  static final _client = SupabaseService.client;

  static Future<UserSettings?> fetchSettings(String userId) async {
    final response = await _client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      // Create default settings
      final created = await _client.from('user_settings').insert({
        'user_id': userId,
        'ai_tone': 'professional',
        'summary_length': 'medium',
        'notifications': {
          'email_summaries': false,
          'meeting_reminders': true,
          'transcript_ready': true,
        },
        'default_view': 'grid',
        'preferences': {},
      }).select().single();
      return UserSettings.fromJson(created);
    }

    return UserSettings.fromJson(response);
  }

  static Future<void> updateSettings(String userId, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('user_settings').update(updates).eq('user_id', userId);
  }

  static RealtimeChannel subscribeToSettings(String userId, Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('settings-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_settings',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }
}
