import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/folder.dart';

class FoldersService {
  static final _client = SupabaseService.client;

  static Future<List<Folder>> fetchFolders(String userId) async {
    final response = await _client
        .from('folders')
        .select()
        .eq('user_id', userId)
        .order('name', ascending: true);
    return (response as List).map((e) => Folder.fromJson(e)).toList();
  }

  static Future<Folder?> createFolder(String userId, String name) async {
    final response = await _client.from('folders').insert({
      'user_id': userId,
      'name': name,
    }).select().single();
    return Folder.fromJson(response);
  }

  static Future<void> renameFolder(String id, String name) async {
    await _client.from('folders').update({
      'name': name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> updateFolderColor(String id, String? color) async {
    await _client.from('folders').update({
      'color': color,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> deleteFolder(String id) async {
    // First delete all notes in the folder
    await _client.from('notes').delete().eq('folder_id', id);
    // Then delete the folder
    await _client.from('folders').delete().eq('id', id);
  }

  static RealtimeChannel subscribeToFolders(String userId, Function(String, Map<String, dynamic>) onEvent) {
    return _client
        .channel('folders-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'folders',
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
