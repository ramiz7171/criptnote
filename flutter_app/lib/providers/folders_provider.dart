import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/folder.dart';
import '../services/folders_service.dart';
import 'auth_provider.dart';

class FoldersNotifier extends StateNotifier<List<Folder>> {
  FoldersNotifier(this._userId) : super([]) {
    _load();
  }

  final String _userId;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    final folders = await FoldersService.fetchFolders(_userId);
    state = folders;
    _subscribe();
  }

  void _subscribe() {
    _channel = FoldersService.subscribeToFolders(_userId, (event, record) {
      if (record.isEmpty) return;
      final folder = Folder.fromJson(record);
      if (event == 'insert') {
        if (!state.any((f) => f.id == folder.id)) {
          state = [...state, folder];
        }
      } else if (event == 'update') {
        state = state.map((f) => f.id == folder.id ? folder : f).toList();
      } else if (event == 'delete') {
        state = state.where((f) => f.id != folder.id).toList();
      }
    });
  }

  Future<Folder?> createFolder(String name) async {
    final folder = await FoldersService.createFolder(_userId, name);
    if (folder != null) {
      state = [...state, folder];
    }
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    state = state.map((f) => f.id == id ? f.copyWith(name: name) : f).toList();
    await FoldersService.renameFolder(id, name);
  }

  Future<void> updateFolderColor(String id, String? color) async {
    state = state.map((f) => f.id == id ? f.copyWith(color: color) : f).toList();
    await FoldersService.updateFolderColor(id, color);
  }

  Future<void> deleteFolder(String id) async {
    state = state.where((f) => f.id != id).toList();
    await FoldersService.deleteFolder(id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final foldersProvider = StateNotifierProvider.autoDispose<FoldersNotifier, List<Folder>>((ref) {
  final auth = ref.watch(authProvider);
  return FoldersNotifier(auth.user?.id ?? '');
});
