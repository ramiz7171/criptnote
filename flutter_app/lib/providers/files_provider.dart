import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_file.dart';
import '../services/files_service.dart';
import 'auth_provider.dart';

class FilesState {
  final List<FileFolder> fileFolders;
  final List<UserFile> userFiles;
  final bool loading;
  final Map<String, double> uploadProgress;

  const FilesState({
    this.fileFolders = const [],
    this.userFiles = const [],
    this.loading = true,
    this.uploadProgress = const {},
  });

  FilesState copyWith({
    List<FileFolder>? fileFolders,
    List<UserFile>? userFiles,
    bool? loading,
    Map<String, double>? uploadProgress,
  }) =>
      FilesState(
        fileFolders: fileFolders ?? this.fileFolders,
        userFiles: userFiles ?? this.userFiles,
        loading: loading ?? this.loading,
        uploadProgress: uploadProgress ?? this.uploadProgress,
      );

  List<FileFolder> getFoldersInFolder(String? parentId) =>
      fileFolders.where((f) => f.parentFolderId == parentId).toList();

  List<UserFile> getFilesInFolder(String? folderId) =>
      userFiles.where((f) => f.folderId == folderId).toList();

  List<Map<String, dynamic>> getBreadcrumbs(String? folderId) {
    if (folderId == null) return [];
    final crumbs = <Map<String, dynamic>>[];
    String? current = folderId;
    while (current != null) {
      final folder = fileFolders.where((f) => f.id == current).firstOrNull;
      if (folder == null) break;
      crumbs.insert(0, {'id': folder.id, 'name': folder.name});
      current = folder.parentFolderId;
    }
    return crumbs;
  }
}

class FilesNotifier extends StateNotifier<FilesState> {
  FilesNotifier(this._userId) : super(const FilesState()) {
    _load();
  }

  final String _userId;
  RealtimeChannel? _fileChannel;
  RealtimeChannel? _folderChannel;

  Future<void> _load() async {
    final folders = await FilesService.fetchFileFolders(_userId);
    final files = await FilesService.fetchUserFiles(_userId);
    state = state.copyWith(fileFolders: folders, userFiles: files, loading: false);
    _subscribe();
  }

  void _subscribe() {
    _fileChannel = FilesService.subscribeToFiles(_userId, (event, record) {
      if (record.isEmpty) return;
      final file = UserFile.fromJson(record);
      if (event == 'insert') {
        if (!state.userFiles.any((f) => f.id == file.id)) {
          state = state.copyWith(userFiles: [...state.userFiles, file]);
        }
      } else if (event == 'update') {
        state = state.copyWith(userFiles: state.userFiles.map((f) => f.id == file.id ? file : f).toList());
      } else if (event == 'delete') {
        state = state.copyWith(userFiles: state.userFiles.where((f) => f.id != file.id).toList());
      }
    });
  }

  Future<FileFolder?> createFileFolder({required String name, String? parentFolderId, String color = 'blue'}) async {
    final folder = await FilesService.createFileFolder(userId: _userId, name: name, parentFolderId: parentFolderId, color: color);
    if (folder != null) state = state.copyWith(fileFolders: [...state.fileFolders, folder]);
    return folder;
  }

  Future<void> renameFileFolder(String id, String name) async {
    state = state.copyWith(fileFolders: state.fileFolders.map((f) => f.id == id ? FileFolder(
      id: f.id, userId: f.userId, name: name, parentFolderId: f.parentFolderId,
      color: f.color, position: f.position, createdAt: f.createdAt, updatedAt: f.updatedAt,
    ) : f).toList());
    await FilesService.renameFileFolder(id, name);
  }

  Future<void> deleteFileFolder(String id) async {
    state = state.copyWith(fileFolders: state.fileFolders.where((f) => f.id != id).toList());
    await FilesService.deleteFileFolder(id);
  }

  Future<UserFile?> uploadFile(File file, String fileName, String fileType, String? folderId) async {
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
    state = state.copyWith(uploadProgress: {...state.uploadProgress, uploadId: 0.0});
    try {
      final userFile = await FilesService.uploadFile(
        userId: _userId, file: file, fileName: fileName, fileType: fileType, folderId: folderId,
        onProgress: (progress) {
          state = state.copyWith(uploadProgress: {...state.uploadProgress, uploadId: progress});
        },
      );
      if (userFile != null) {
        state = state.copyWith(userFiles: [...state.userFiles, userFile]);
      }
      final progress = Map<String, double>.from(state.uploadProgress);
      progress.remove(uploadId);
      state = state.copyWith(uploadProgress: progress);
      return userFile;
    } catch (e) {
      final progress = Map<String, double>.from(state.uploadProgress);
      progress.remove(uploadId);
      state = state.copyWith(uploadProgress: progress);
      rethrow;
    }
  }

  Future<void> renameFile(String id, String fileName) async {
    state = state.copyWith(userFiles: state.userFiles.map((f) => f.id == id
        ? UserFile(id: f.id, userId: f.userId, folderId: f.folderId, fileName: fileName,
            fileType: f.fileType, fileSize: f.fileSize, storagePath: f.storagePath,
            shareId: f.shareId, shareExpiresAt: f.shareExpiresAt, sharePasswordHash: f.sharePasswordHash,
            position: f.position, createdAt: f.createdAt, updatedAt: f.updatedAt)
        : f).toList());
    await FilesService.renameFile(id, fileName);
  }

  Future<void> deleteFile(UserFile file) async {
    state = state.copyWith(userFiles: state.userFiles.where((f) => f.id != file.id).toList());
    await FilesService.deleteFile(file);
  }

  Future<void> moveFile(String id, String? folderId) async {
    await FilesService.moveFile(id, folderId);
    final files = await FilesService.fetchUserFiles(_userId);
    state = state.copyWith(userFiles: files);
  }

  Future<String?> generateShareLink({required String fileId, required String expiresIn, String? password}) async {
    final shareId = await FilesService.generateShareLink(fileId: fileId, expiresIn: expiresIn, password: password);
    final files = await FilesService.fetchUserFiles(_userId);
    state = state.copyWith(userFiles: files);
    return shareId;
  }

  Future<void> revokeShareLink(String fileId) async {
    await FilesService.revokeShareLink(fileId);
    final files = await FilesService.fetchUserFiles(_userId);
    state = state.copyWith(userFiles: files);
  }

  String getFileUrl(String storagePath) => FilesService.getFileUrl(storagePath);

  @override
  void dispose() {
    _fileChannel?.unsubscribe();
    _folderChannel?.unsubscribe();
    super.dispose();
  }
}

final filesProvider = StateNotifierProvider.autoDispose<FilesNotifier, FilesState>((ref) {
  final auth = ref.watch(authProvider);
  return FilesNotifier(auth.user?.id ?? '');
});
