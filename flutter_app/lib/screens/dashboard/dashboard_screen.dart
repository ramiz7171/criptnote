import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/notes_provider.dart';
import '../../providers/folders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/security_provider.dart';
import '../../models/note.dart';
import '../../models/folder.dart';
import '../../core/theme.dart';
import '../../widgets/note/note_card.dart';
import '../../widgets/note/new_note_dialog.dart';
import '../../widgets/note/folder_dialog.dart';

enum _ViewMode { grid, list }
enum _Section { notes, archived, trash, folder }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _ViewMode _viewMode = _ViewMode.grid;
  _Section _section = _Section.notes;
  String? _selectedFolderId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  NoteType _filterType = NoteType.basic;
  bool _showCodeNotes = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Note> _getVisibleNotes() {
    final notesState = ref.read(notesProvider);
    List<Note> notes;

    switch (_section) {
      case _Section.archived:
        notes = notesState.archivedNotes;
        break;
      case _Section.trash:
        notes = notesState.deletedNotes;
        break;
      case _Section.folder:
        notes = notesState.folderNotes[_selectedFolderId] ?? [];
        break;
      case _Section.notes:
        if (_showCodeNotes) {
          notes = notesState.codeNotes[_filterType] ?? [];
        } else {
          notes = notesState.basicNotes;
        }
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      notes = notes.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q)
      ).toList();
    }

    return notes;
  }

  void _openNote(Note note) {
    context.push('/note/${note.id}');
  }

  Future<void> _createNote() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => NewNoteDialog(folderId: _section == _Section.folder ? _selectedFolderId : null),
    );
    if (result != null) {
      final note = await ref.read(notesProvider.notifier).createNote(
        title: result['title'] as String,
        noteType: result['type'] as NoteType? ?? NoteType.basic,
        folderId: result['folderId'] as String?,
      );
      if (note != null) _openNote(note);
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const FolderDialog(),
    );
    if (name != null) {
      await ref.read(foldersProvider.notifier).createFolder(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);
    final folders = ref.watch(foldersProvider);
    final auth = ref.watch(authProvider);
    final theme = ref.watch(themeProvider);
    final isDark = theme == ThemeMode.dark;
    final notes = _getVisibleNotes();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: Icon(_viewMode == _ViewMode.grid ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() =>
              _viewMode = _viewMode == _ViewMode.grid ? _ViewMode.list : _ViewMode.grid),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () => ref.read(securityProvider.notifier).lock(),
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue,
              radius: 16,
              child: Text(
                (auth.profile?.displayName.isNotEmpty == true
                    ? auth.profile!.displayName[0]
                    : auth.user?.email?[0] ?? 'U').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            onSelected: (val) {
              if (val == 'settings') context.go('/settings');
              if (val == 'signout') ref.read(authProvider.notifier).signOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings), title: Text('Settings'))),
              const PopupMenuItem(value: 'signout', child: ListTile(leading: Icon(Icons.logout), title: Text('Sign Out'))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(folders, isDark),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Trash actions
          if (_section == _Section.trash && notesState.deletedNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Trash', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.read(notesProvider.notifier).permanentDeleteAll(),
                    child: const Text('Empty Trash', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Notes content
          Expanded(
            child: notesState.loading
                ? const Center(child: CircularProgressIndicator())
                : notes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note_add_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty ? 'No notes found' : 'No notes yet',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : _viewMode == _ViewMode.grid
                        ? _buildGridView(notes)
                        : _buildListView(notes),
          ),
        ],
      ),
      floatingActionButton: _section != _Section.trash
          ? FloatingActionButton(
              onPressed: _createNote,
              backgroundColor: AppTheme.primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildGridView(List<Note> notes) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NoteCard(
          note: note,
          onTap: () => _openNote(note),
          onPin: () => ref.read(notesProvider.notifier).pinNote(note.id),
          onArchive: () => ref.read(notesProvider.notifier).archiveNote(note.id),
          onDelete: () => ref.read(notesProvider.notifier).deleteNote(note.id),
          onRestore: _section == _Section.trash
              ? () => ref.read(notesProvider.notifier).restoreNote(note.id)
              : null,
          onPermanentDelete: _section == _Section.trash
              ? () => ref.read(notesProvider.notifier).permanentDeleteNote(note.id)
              : null,
          showTrashActions: _section == _Section.trash,
        );
      },
    );
  }

  Widget _buildListView(List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NoteCard(
            note: note,
            isListView: true,
            onTap: () => _openNote(note),
            onPin: () => ref.read(notesProvider.notifier).pinNote(note.id),
            onArchive: () => ref.read(notesProvider.notifier).archiveNote(note.id),
            onDelete: () => ref.read(notesProvider.notifier).deleteNote(note.id),
            onRestore: _section == _Section.trash
                ? () => ref.read(notesProvider.notifier).restoreNote(note.id)
                : null,
            onPermanentDelete: _section == _Section.trash
                ? () => ref.read(notesProvider.notifier).permanentDeleteNote(note.id)
                : null,
            showTrashActions: _section == _Section.trash,
          ),
        );
      },
    );
  }

  String _getTitle() {
    switch (_section) {
      case _Section.archived: return 'Archived';
      case _Section.trash: return 'Trash';
      case _Section.folder:
        final folder = ref.read(foldersProvider).where((f) => f.id == _selectedFolderId).firstOrNull;
        return folder?.name ?? 'Folder';
      case _Section.notes:
        if (_showCodeNotes) return _filterType.label;
        return 'Notes';
    }
  }

  Widget _buildDrawer(List<Folder> folders, bool isDark) {
    final notesState = ref.watch(notesProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('CriptNote', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  // Notes sections
                  _DrawerItem(
                    icon: Icons.note_outlined,
                    label: 'Notes',
                    count: notesState.basicNotes.length,
                    selected: _section == _Section.notes && !_showCodeNotes,
                    onTap: () { setState(() { _section = _Section.notes; _showCodeNotes = false; }); Navigator.pop(context); },
                  ),
                  // Code note types
                  const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('CODE', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1))),
                  ...[NoteType.java, NoteType.javascript, NoteType.python, NoteType.sql].map((type) {
                    final count = notesState.codeNotes[type]?.length ?? 0;
                    return _DrawerItem(
                      icon: Icons.code,
                      label: type.label,
                      count: count,
                      selected: _section == _Section.notes && _showCodeNotes && _filterType == type,
                      onTap: () { setState(() { _section = _Section.notes; _showCodeNotes = true; _filterType = type; }); Navigator.pop(context); },
                    );
                  }),

                  // Folders section
                  if (folders.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          const Text('FOLDERS', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: _createFolder,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    ...folders.map((folder) => _FolderDrawerItem(
                      folder: folder,
                      count: notesState.folderNotes[folder.id]?.length ?? 0,
                      selected: _section == _Section.folder && _selectedFolderId == folder.id,
                      onTap: () {
                        setState(() { _section = _Section.folder; _selectedFolderId = folder.id; });
                        Navigator.pop(context);
                      },
                      onDelete: () => ref.read(foldersProvider.notifier).deleteFolder(folder.id),
                      onRename: (name) => ref.read(foldersProvider.notifier).renameFolder(folder.id, name),
                    )),
                  ],

                  const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('MORE', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1))),
                  _DrawerItem(
                    icon: Icons.archive_outlined,
                    label: 'Archived',
                    count: notesState.archivedNotes.length,
                    selected: _section == _Section.archived,
                    onTap: () { setState(() => _section = _Section.archived); Navigator.pop(context); },
                  ),
                  _DrawerItem(
                    icon: Icons.delete_outline,
                    label: 'Trash',
                    count: notesState.deletedNotes.length,
                    selected: _section == _Section.trash,
                    onTap: () { setState(() => _section = _Section.trash); Navigator.pop(context); },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.add_circle_outline,
              label: 'New Folder',
              onTap: () { Navigator.pop(context); _createFolder(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({required this.icon, required this.label, this.count, this.selected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: selected ? const Color(0xFF3B82F6) : null),
      title: Text(label, style: TextStyle(fontSize: 14, color: selected ? const Color(0xFF3B82F6) : null)),
      trailing: count != null && count! > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF3B82F6) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.grey)),
            )
          : null,
      selected: selected,
      selectedTileColor: const Color(0xFF3B82F6).withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      onTap: onTap,
    );
  }
}

class _FolderDrawerItem extends StatelessWidget {
  final Folder folder;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(String) onRename;

  const _FolderDrawerItem({
    required this.folder, required this.count, required this.selected,
    required this.onTap, required this.onDelete, required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    Color folderColor = const Color(0xFF3B82F6);
    if (folder.color != null) {
      try {
        folderColor = Color(int.parse(folder.color!.replaceAll('#', '0xFF')));
      } catch (_) {}
    }

    return ListTile(
      leading: Icon(Icons.folder, size: 20, color: folderColor),
      title: Text(folder.name, style: TextStyle(fontSize: 14, color: selected ? const Color(0xFF3B82F6) : null)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) Text('$count', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 16),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
            onSelected: (val) async {
              if (val == 'delete') onDelete();
              if (val == 'rename') {
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => FolderDialog(initialName: folder.name),
                );
                if (name != null) onRename(name);
              }
            },
          ),
        ],
      ),
      selected: selected,
      selectedTileColor: const Color(0xFF3B82F6).withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      onTap: onTap,
    );
  }
}
