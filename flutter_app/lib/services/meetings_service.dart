import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/meeting.dart';

class MeetingsService {
  static final _client = SupabaseService.client;

  static Future<List<Meeting>> fetchMeetings(String userId) async {
    final response = await _client
        .from('meetings')
        .select()
        .eq('user_id', userId)
        .order('meeting_date', ascending: false);
    return (response as List).map((e) => Meeting.fromJson(e)).toList();
  }

  static Future<Meeting?> createMeeting({
    required String userId,
    required String title,
    String? meetingDate,
    List<String>? participants,
    List<String>? tags,
    List<AgendaItem>? agenda,
    String status = 'scheduled',
  }) async {
    final response = await _client.from('meetings').insert({
      'user_id': userId,
      'title': title,
      'meeting_date': meetingDate ?? DateTime.now().toIso8601String(),
      'duration_minutes': 60,
      'participants': participants ?? [],
      'tags': tags ?? [],
      'agenda': (agenda ?? []).map((a) => a.toJson()).toList(),
      'status': status,
      'ai_notes': '',
      'follow_up': '',
      'audio_url': '',
    }).select().single();
    return Meeting.fromJson(response);
  }

  static Future<void> updateMeeting(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('meetings').update(updates).eq('id', id);
  }

  static Future<void> deleteMeeting(String id) async {
    await _client.from('meetings').delete().eq('id', id);
  }

  static RealtimeChannel subscribeToMeetings(String userId, Function(String, Map<String, dynamic>) onEvent) {
    return _client
        .channel('meetings-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meetings',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            final eventType = payload.eventType.name;
            final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
            onEvent(eventType, record);
          },
        )
        .subscribe();
  }
}
