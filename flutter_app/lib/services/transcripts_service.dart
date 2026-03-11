import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/transcript.dart';

class TranscriptsService {
  static final _client = SupabaseService.client;

  static Future<List<Transcript>> fetchTranscripts(String userId) async {
    final response = await _client
        .from('transcripts')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (response as List).map((e) => Transcript.fromJson(e)).toList();
  }

  static Future<Transcript?> createTranscript({
    required String userId,
    required String title,
    String transcriptText = '',
    List<SpeakerSegment>? speakerSegments,
    String summary = '',
    String actionItems = '',
    String audioUrl = '',
    String status = 'processing',
    int durationSeconds = 0,
    List<String>? tags,
    String? meetingId,
  }) async {
    final response = await _client.from('transcripts').insert({
      'user_id': userId,
      'title': title,
      'transcript_text': transcriptText,
      'speaker_segments': (speakerSegments ?? []).map((s) => s.toJson()).toList(),
      'summary': summary,
      'action_items': actionItems,
      'audio_url': audioUrl,
      'status': status,
      'duration_seconds': durationSeconds,
      'tags': tags ?? [],
      'meeting_id': meetingId,
    }).select().single();
    return Transcript.fromJson(response);
  }

  static Future<void> updateTranscript(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('transcripts').update(updates).eq('id', id);
  }

  static Future<void> deleteTranscript(String id) async {
    await _client.from('transcripts').delete().eq('id', id);
  }

  static RealtimeChannel subscribeToTranscripts(String userId, Function(String, Map<String, dynamic>) onEvent) {
    return _client
        .channel('transcripts-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transcripts',
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
