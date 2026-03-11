import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';
import '../models/user_file.dart';
import '../core/constants.dart';

class FilesService {
  static final _client = SupabaseService.client;
  static const _uuid = Uuid();

  // File Folders
  static Future<List<FileFolder>> fetchFileFolders(String userId) async {
    final response = await _client
        .from('file_folders')
        .select()
        .eq('user_id', userId)
        .order('position', ascending: true);
    return (response as List).map((e) => FileFolder.fromJson(e)).toList();
  }

  static Future<FileFolder?> createFileFolder({
    required String userId,
    required String name,
    String? parentFolderId,
    String color = 'blue',
  }) async {
    final response = await _client.from('file_folders').insert({
      'user_id': userId,
      'name': name,
      'parent_folder_id': parentFolderId,
      'color': color,
      'position': DateTime.now().millisecondsSinceEpoch,
    }).select().single();
    return FileFolder.fromJson(response);
  }

  static Future<void> renameFileFolder(String id, String name) async {
    await _client.from('file_folders').update({
      'name': name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> updateFileFolderColor(String id, String color) async {
    await _client.from('file_folders').update({
      'color': color,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> moveFileFolder(String id, String? parentFolderId) async {
    await _client.from('file_folders').update({
      'parent_folder_id': parentFolderId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> deleteFileFolder(String id) async {
    // Get all files in this folder and delete from storage
    final files = await _client.from('user_files').select().eq('folder_id', id);
    for (final file in files as List) {
      await _client.storage.from(AppConstants.userFilesBucket).remove([file['storage_path'] as String]);
    }
    await _client.from('user_files').delete().eq('folder_id', id);
    await _client.from('file_folders').delete().eq('id', id);
  }

  // User Files
  static Future<List<UserFile>> fetchUserFiles(String userId) async {
    final response = await _client
        .from('user_files')
        .select()
        .eq('user_id', userId)
        .order('position', ascending: true);
    return (response as List).map((e) => UserFile.fromJson(e)).toList();
  }

  static Future<UserFile?> uploadFile({
    required String userId,
    required File file,
    required String fileName,
    required String fileType,
    String? folderId,
    Function(double)? onProgress,
  }) async {
    final fileSize = await file.length();
    final isAdmin = false; // Check from profile if needed

    if (!isAdmin && fileSize > AppConstants.maxFileSizeBytes) {
      throw Exception('File size exceeds 15MB limit');
    }

    final uniqueId = _uuid.v4().substring(0, 8);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$userId/$timestamp-$uniqueId/$fileName';

    final bytes = await file.readAsBytes();
    await _client.storage.from(AppConstants.userFilesBucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: fileType, upsert: false),
    );

    final response = await _client.from('user_files').insert({
      'user_id': userId,
      'folder_id': folderId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'storage_path': storagePath,
      'position': DateTime.now().millisecondsSinceEpoch,
    }).select().single();

    return UserFile.fromJson(response);
  }

  static Future<void> renameFile(String id, String fileName) async {
    await _client.from('user_files').update({
      'file_name': fileName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> moveFile(String id, String? folderId) async {
    await _client.from('user_files').update({
      'folder_id': folderId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> bulkMoveFiles(List<String> ids, String? folderId) async {
    await _client.from('user_files').update({
      'folder_id': folderId,
      'updated_at': DateTime.now().toIso8601String(),
    }).inFilter('id', ids);
  }

  static Future<void> deleteFile(UserFile file) async {
    await _client.storage.from(AppConstants.userFilesBucket).remove([file.storagePath]);
    await _client.from('user_files').delete().eq('id', file.id);
  }

  static Future<void> bulkDeleteFiles(List<UserFile> files) async {
    final paths = files.map((f) => f.storagePath).toList();
    await _client.storage.from(AppConstants.userFilesBucket).remove(paths);
    await _client.from('user_files').delete().inFilter('id', files.map((f) => f.id).toList());
  }

  static String getFileUrl(String storagePath) {
    return _client.storage.from(AppConstants.userFilesBucket).getPublicUrl(storagePath);
  }

  // Sharing
  static Future<String?> generateShareLink({
    required String fileId,
    required String expiresIn, // '24h' | '7d' | '30d' | 'never'
    String? password,
  }) async {
    final shareId = _uuid.v4().replaceAll('-', '').substring(0, 16);
    DateTime? expiresAt;

    switch (expiresIn) {
      case '24h': expiresAt = DateTime.now().add(const Duration(hours: 24)); break;
      case '7d': expiresAt = DateTime.now().add(const Duration(days: 7)); break;
      case '30d': expiresAt = DateTime.now().add(const Duration(days: 30)); break;
    }

    await _client.from('user_files').update({
      'share_id': shareId,
      'share_expires_at': expiresAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', fileId);

    if (password != null) {
      await _client.rpc('set_share_password', params: {
        'p_file_id': fileId,
        'p_password': password,
      });
    }

    return shareId;
  }

  static Future<void> revokeShareLink(String fileId) async {
    await _client.from('user_files').update({
      'share_id': null,
      'share_expires_at': null,
      'share_password_hash': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', fileId);
  }

  static Future<Map<String, dynamic>?> getSharedFile(String shareId) async {
    final result = await _client.rpc('get_shared_file', params: {'p_share_id': shareId});
    if (result == null) return null;
    return result as Map<String, dynamic>;
  }

  static Future<bool> verifySharePassword(String shareId, String password) async {
    final result = await _client.rpc('verify_share_password', params: {
      'p_share_id': shareId,
      'p_password': password,
    });
    return result as bool? ?? false;
  }

  static RealtimeChannel subscribeToFiles(String userId, Function(String, Map<String, dynamic>) onEvent) {
    return _client
        .channel('files-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_files',
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
