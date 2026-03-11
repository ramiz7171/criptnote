import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';
import '../services/notes_service.dart';
import 'auth_provider.dart';

class NotesState {
  final List<Note> notes;
  final bool loading;

  const NotesState({this.notes = const [], this.loading = true});

  NotesState copyWith({List<Note>? notes, bool? loading}) =>
      NotesState(notes: notes ?? this.notes, loading: loading ?? this.loading);

  // Active notes (not archived, not deleted, not expired, not scheduled future)
  List<Note> get activeNotes => notes.where((n) => n.isActive).toList();

  // Basic + checkbox notes (unfiled)
  List<Note> get basicNotes {
    final unfiled = activeNotes.where((n) => n.folderId == null && (n.noteType == NoteType.basic || n.noteType == NoteType.checkbox)).toList();
    return _sortNotes(unfiled);
  }

  // Code notes grouped by type
  Map<NoteType, List<Note>> get codeNotes {
    final codeTypes = [NoteType.java, NoteType.javascript, NoteType.python, NoteType.sql];
    final result = <NoteType, List<Note>>{};
    for (final type in codeTypes) {
      result[type] = _sortNotes(activeNotes.where((n) => n.noteType == type && n.folderId == null).toList());
    }
    return result;
  }

  // Board notes
  List<Note> get boardNotes => _sortNotes(activeNotes.where((n) => n.noteType == NoteType.board).toList());

  // Archived notes
  List<Note> get archivedNotes => notes.where((n) => n.archived && n.deletedAt == null).toList();

  // Deleted notes (trash - within 30 days)
  List<Note> get deletedNotes {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return notes.where((n) {
      if (n.deletedAt == null) return false;
      final deletedTime = DateTime.parse(n.deletedAt!);
      return deletedTime.isAfter(cutoff);
    }).toList();
  }

  // Notes grouped by folder
  Map<String, List<Note>> get folderNotes {
    final result = <String, List<Note>>{};
    for (final note in activeNotes) {
      if (note.folderId != null) {
        result.putIfAbsent(note.folderId!, () => []).add(note);
      }
    }
    return result;
  }

  List<Note> _sortNotes(List<Note> list) {
    final sorted = List<Note>.from(list);
    sorted.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      final aPos = a.position;
      final bPos = b.position;
      if (aPos != bPos) return aPos.compareTo(bPos);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }
}

class NotesNotifier extends StateNotifier<NotesState> {
  NotesNotifier(this._userId) : super(const NotesState()) {
    _load();
  }

  final String _userId;
  RealtimeChannel? _channel;
  final Set<String> _pendingUpdates = {};

  Future<void> _load() async {
    final notes = await NotesService.fetchNotes(_userId);
    // Cleanup expired
    _cleanupExpired(notes);
    state = state.copyWith(notes: notes, loading: false);
    _subscribe();
  }

  void _cleanupExpired(List<Note> notes) {
    final expired = notes.where((n) => n.isExpired && n.deletedAt == null).toList();
    for (final note in expired) {
      NotesService.softDeleteNote(note.id);
    }
  }

  void _subscribe() {
    _channel = NotesService.subscribeToNotes(_userId, (event, record) {
      if (record.isEmpty) return;
      final id = record['id'] as String?;
      if (id != null && _pendingUpdates.contains(id)) return; // Skip pessimistic lock

      final note = Note.fromJson(record);

      if (event == 'insert') {
        if (!state.notes.any((n) => n.id == note.id)) {
          state = state.copyWith(notes: [...state.notes, note]);
        }
      } else if (event == 'update') {
        state = state.copyWith(
          notes: state.notes.map((n) => n.id == note.id ? note : n).toList(),
        );
      } else if (event == 'delete') {
        state = state.copyWith(notes: state.notes.where((n) => n.id != note.id).toList());
      }
    });
  }

  void _lockPending(String id) {
    _pendingUpdates.add(id);
    Future.delayed(const Duration(milliseconds: 1500), () => _pendingUpdates.remove(id));
  }

  Future<Note?> createNote({
    required String title,
    String content = '',
    NoteType noteType = NoteType.basic,
    String? expiresAt,
    String? scheduledAt,
    String? folderId,
  }) async {
    final note = await NotesService.createNote(
      userId: _userId,
      title: title,
      content: content,
      noteType: noteType,
      expiresAt: expiresAt,
      scheduledAt: scheduledAt,
      folderId: folderId,
    );
    if (note != null) {
      state = state.copyWith(notes: [...state.notes, note]);
    }
    return note;
  }

  Future<void> updateNote(String id, Map<String, dynamic> updates) async {
    _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) {
        if (n.id != id) return n;
        return Note.fromJson({...n.toJson(), ...updates});
      }).toList(),
    );
    await NotesService.updateNote(id, updates);
  }

  Future<void> deleteNote(String id) async {
    _lockPending(id);
    final deletedAt = DateTime.now().toIso8601String();
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == id ? n.copyWith(deletedAt: deletedAt) : n).toList(),
    );
    await NotesService.softDeleteNote(id);
  }

  Future<void> permanentDeleteNote(String id) async {
    state = state.copyWith(notes: state.notes.where((n) => n.id != id).toList());
    await NotesService.permanentDeleteNote(id);
  }

  Future<void> permanentDeleteAll() async {
    state = state.copyWith(notes: state.notes.where((n) => n.deletedAt == null).toList());
    await NotesService.permanentDeleteAll(_userId);
  }

  Future<void> restoreNote(String id) async {
    _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == id ? n.copyWith(deletedAt: null) : n).toList(),
    );
    await NotesService.restoreNote(id);
  }

  Future<void> archiveNote(String id) async {
    _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == id ? n.copyWith(archived: true) : n).toList(),
    );
    await NotesService.archiveNote(id);
  }

  Future<void> unarchiveNote(String id) async {
    _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == id ? n.copyWith(archived: false) : n).toList(),
    );
    await NotesService.unarchiveNote(id);
  }

  Future<void> pinNote(String id) async {
    final note = state.notes.firstWhere((n) => n.id == id);
    final newPinned = !note.pinned;
    _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == id ? n.copyWith(pinned: newPinned) : n).toList(),
    );
    await NotesService.pinNote(id, newPinned);
  }

  Future<void> updateColor(String id, String color) async {
    _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == id ? n.copyWith(color: color) : n).toList(),
    );
    await NotesService.updateColor(id, color);
  }

  Future<void> moveToFolder(String noteId, String? folderId) async {
    _lockPending(noteId);
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == noteId ? n.copyWith(folderId: folderId) : n).toList(),
    );
    await NotesService.moveToFolder(noteId, folderId);
  }

  Future<void> bulkMoveToFolder(List<String> noteIds, String? folderId) async {
    for (final id in noteIds) _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) => noteIds.contains(n.id) ? n.copyWith(folderId: folderId) : n).toList(),
    );
    await NotesService.bulkMoveToFolder(noteIds, folderId);
  }

  Future<void> bulkDelete(List<String> noteIds) async {
    final deletedAt = DateTime.now().toIso8601String();
    for (final id in noteIds) _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) => noteIds.contains(n.id) ? n.copyWith(deletedAt: deletedAt) : n).toList(),
    );
    await NotesService.bulkDelete(noteIds);
  }

  Future<void> bulkArchive(List<String> noteIds) async {
    for (final id in noteIds) _lockPending(id);
    state = state.copyWith(
      notes: state.notes.map((n) => noteIds.contains(n.id) ? n.copyWith(archived: true) : n).toList(),
    );
    await NotesService.bulkArchive(noteIds);
  }

  Future<void> refresh() async {
    final notes = await NotesService.fetchNotes(_userId);
    state = state.copyWith(notes: notes, loading: false);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final notesProvider = StateNotifierProvider.autoDispose<NotesNotifier, NotesState>((ref) {
  final auth = ref.watch(authProvider);
  return NotesNotifier(auth.user?.id ?? '');
});
