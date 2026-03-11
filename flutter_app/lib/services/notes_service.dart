import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/note.dart';

class NotesService {
  static final _client = SupabaseService.client;

  static Future<List<Note>> fetchNotes(String userId) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('position', ascending: true);
    return (response as List).map((e) => Note.fromJson(e)).toList();
  }

  static Future<Note?> createNote({
    required String userId,
    required String title,
    String content = '',
    NoteType noteType = NoteType.basic,
    String? expiresAt,
    String? scheduledAt,
    String? folderId,
  }) async {
    final response = await _client.from('notes').insert({
      'user_id': userId,
      'title': title,
      'content': content,
      'note_type': noteType.value,
      'expires_at': expiresAt,
      'scheduled_at': scheduledAt,
      'folder_id': folderId,
      'color': '#ffffff',
      'pinned': false,
      'archived': false,
      'position': DateTime.now().millisecondsSinceEpoch,
    }).select().single();
    return Note.fromJson(response);
  }

  static Future<void> updateNote(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('notes').update(updates).eq('id', id);
  }

  static Future<void> softDeleteNote(String id) async {
    await _client.from('notes').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> permanentDeleteNote(String id) async {
    await _client.from('notes').delete().eq('id', id);
  }

  static Future<void> permanentDeleteAll(String userId) async {
    await _client
        .from('notes')
        .delete()
        .eq('user_id', userId)
        .not('deleted_at', 'is', null);
  }

  static Future<void> restoreNote(String id) async {
    await _client.from('notes').update({
      'deleted_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> archiveNote(String id) async {
    await _client.from('notes').update({
      'archived': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> unarchiveNote(String id) async {
    await _client.from('notes').update({
      'archived': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> pinNote(String id, bool pinned) async {
    await _client.from('notes').update({
      'pinned': pinned,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> updateColor(String id, String color) async {
    await _client.from('notes').update({
      'color': color,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> moveToFolder(String noteId, String? folderId) async {
    await _client.from('notes').update({
      'folder_id': folderId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', noteId);
  }

  static Future<void> bulkMoveToFolder(List<String> noteIds, String? folderId) async {
    await _client.from('notes').update({
      'folder_id': folderId,
      'updated_at': DateTime.now().toIso8601String(),
    }).inFilter('id', noteIds);
  }

  static Future<void> bulkDelete(List<String> noteIds) async {
    await _client.from('notes').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).inFilter('id', noteIds);
  }

  static Future<void> bulkArchive(List<String> noteIds) async {
    await _client.from('notes').update({
      'archived': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).inFilter('id', noteIds);
  }

  static Future<void> updatePositions(List<Map<String, dynamic>> updates) async {
    for (final update in updates) {
      await _client.from('notes').update({'position': update['position']}).eq('id', update['id']);
    }
  }

  static Future<void> cleanupExpired() async {
    await _client.rpc('cleanup_expired_notes');
  }

  static RealtimeChannel subscribeToNotes(String userId, Function(String, Map<String, dynamic>) onEvent) {
    return _client
        .channel('notes-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            final eventType = payload.eventType.name; // insert | update | delete
            final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
            onEvent(eventType, record);
          },
        )
        .subscribe();
  }
}
