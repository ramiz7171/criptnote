import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../../providers/files_provider.dart';
import '../../models/user_file.dart';
import '../../core/constants.dart';

enum _ViewMode { grid, list }

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  _ViewMode _viewMode = _ViewMode.grid;
  String? _currentFolderId;
  final List<String?> _navHistory = [null];
  String _search = '';

  void _navigateToFolder(String? folderId) {
    setState(() {
      _currentFolderId = folderId;
      _navHistory.add(folderId);
    });
  }

  void _navigateBack() {
    if (_navHistory.length > 1) {
      _navHistory.removeLast();
      setState(() => _currentFolderId = _navHistory.last);
    }
  }

  Future<void> _uploadFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    for (final platformFile in result.files) {
      if (platformFile.path == null) continue;
      final file = File(platformFile.path!);
      try {
        await ref.read(filesProvider.notifier).uploadFile(
          file,
          platformFile.name,
          platformFile.extension != null ? 'application/${platformFile.extension}' : 'application/octet-stream',
          _currentFolderId,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload ${platformFile.name}: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CreateFolderDialog(),
    );
    if (name != null) {
      await ref.read(filesProvider.notifier).createFileFolder(name: name, parentFolderId: _currentFolderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(filesProvider);
    final breadcrumbs = state.getBreadcrumbs(_currentFolderId);
    final folders = state.getFoldersInFolder(_currentFolderId);
    final files = state.getFilesInFolder(_currentFolderId);

    // Apply search
    final filteredFolders = _search.isEmpty ? folders : folders.where((f) => f.name.toLowerCase().contains(_search.toLowerCase())).toList();
    final filteredFiles = _search.isEmpty ? files : files.where((f) => f.fileName.toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        leading: _currentFolderId != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _navigateBack)
            : null,
        actions: [
          IconButton(icon: Icon(_viewMode == _ViewMode.grid ? Icons.list : Icons.grid_view), onPressed: () => setState(() => _viewMode = _viewMode == _ViewMode.grid ? _ViewMode.list : _ViewMode.grid)),
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: _createFolder),
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _uploadFiles),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search files...', prefixIcon: Icon(Icons.search, size: 20), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // Breadcrumb
          if (breadcrumbs.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _BreadcrumbChip(label: 'Files', onTap: () { setState(() { _currentFolderId = null; _navHistory.clear(); _navHistory.add(null); }); }),
                  ...breadcrumbs.map((b) => _BreadcrumbChip(label: b['name'] as String, onTap: () { setState(() { _currentFolderId = b['id'] as String; }); })),
                ],
              ),
            ),

          // Upload progress
          if (state.uploadProgress.isNotEmpty)
            ...state.uploadProgress.values.map((p) => LinearProgressIndicator(value: p)),

          // Content
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : filteredFolders.isEmpty && filteredFiles.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('Empty folder', style: TextStyle(color: Colors.grey)),
                      ]))
                    : _viewMode == _ViewMode.grid
                        ? _buildGrid(filteredFolders, filteredFiles)
                        : _buildList(filteredFolders, filteredFiles),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<dynamic> folders, List<UserFile> files) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.9),
      itemCount: folders.length + files.length,
      itemBuilder: (context, i) {
        if (i < folders.length) {
          final folder = folders[i] as FileFolder;
          return _FolderGridItem(folder: folder, onTap: () => _navigateToFolder(folder.id), onDelete: () => ref.read(filesProvider.notifier).deleteFileFolder(folder.id));
        }
        final file = files[i - folders.length];
        return _FileGridItem(file: file, getUrl: ref.read(filesProvider.notifier).getFileUrl, onShare: () => _showShareDialog(file), onDelete: () => ref.read(filesProvider.notifier).deleteFile(file));
      },
    );
  }

  Widget _buildList(List<dynamic> folders, List<UserFile> files) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...folders.map((folder) => _FolderListItem(folder: folder as FileFolder, onTap: () => _navigateToFolder(folder.id), onDelete: () => ref.read(filesProvider.notifier).deleteFileFolder(folder.id))),
        ...files.map((file) => _FileListItem(file: file, getUrl: ref.read(filesProvider.notifier).getFileUrl, onShare: () => _showShareDialog(file), onDelete: () => ref.read(filesProvider.notifier).deleteFile(file))),
      ],
    );
  }

  void _showShareDialog(UserFile file) {
    showDialog(context: context, builder: (_) => _ShareDialog(file: file, notifier: ref.read(filesProvider.notifier)));
  }
}

class _ShareDialog extends StatefulWidget {
  final UserFile file;
  final FilesNotifier notifier;
  const _ShareDialog({required this.file, required this.notifier});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  String _expiresIn = '7d';
  final _passwordController = TextEditingController();
  bool _usePassword = false;
  String? _shareUrl;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    final shareId = await widget.notifier.generateShareLink(
      fileId: widget.file.id,
      expiresIn: _expiresIn,
      password: _usePassword ? _passwordController.text : null,
    );
    if (shareId != null) {
      setState(() => _shareUrl = 'https://criptnote.com/share/$shareId');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share File'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _expiresIn,
              decoration: const InputDecoration(labelText: 'Expires in'),
              items: const [
                DropdownMenuItem(value: '24h', child: Text('24 hours')),
                DropdownMenuItem(value: '7d', child: Text('7 days')),
                DropdownMenuItem(value: '30d', child: Text('30 days')),
                DropdownMenuItem(value: 'never', child: Text('Never')),
              ],
              onChanged: (v) => setState(() => _expiresIn = v ?? '7d'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Password protect'),
              value: _usePassword,
              onChanged: (v) => setState(() => _usePassword = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_usePassword) TextField(
              controller: _passwordController,
              decoration: const InputDecoration(hintText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
              obscureText: true,
            ),
            if (_shareUrl != null) ...[
              const SizedBox(height: 16),
              QrImageView(data: _shareUrl!, size: 150),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(child: Text(_shareUrl!, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                    IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () { Clipboard.setData(ClipboardData(text: _shareUrl!)); }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        if (_shareUrl == null)
          ElevatedButton(onPressed: _loading ? null : _generate, child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Generate Link')),
        if (widget.file.shareId != null)
          TextButton(onPressed: () { widget.notifier.revokeShareLink(widget.file.id); Navigator.pop(context); }, child: const Text('Revoke', style: TextStyle(color: Colors.red))),
      ],
    );
  }
}

class _FolderGridItem extends StatelessWidget {
  final FileFolder folder;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _FolderGridItem({required this.folder, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorMap = AppConstants.folderColors;
    final color = Color(colorMap[folder.color] ?? 0xFF3B82F6);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder, size: 48, color: color),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(folder.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 14),
              itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
              onSelected: (v) { if (v == 'delete') onDelete(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _FileGridItem extends StatelessWidget {
  final UserFile file;
  final String Function(String) getUrl;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  const _FileGridItem({required this.file, required this.getUrl, required this.onShare, required this.onDelete});

  IconData get _fileIcon {
    final ext = file.fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext)) return Icons.image_outlined;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_outlined;
    if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.video_file_outlined;
    if (['mp3', 'wav', 'm4a'].contains(ext)) return Icons.audio_file_outlined;
    if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_fileIcon, size: 40, color: Colors.blue),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(file.fileName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
          Text(file.fileSizeFormatted, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 14),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share, size: 18), title: Text('Share'), dense: true)),
              PopupMenuItem(value: 'open', child: ListTile(leading: const Icon(Icons.open_in_new, size: 18), title: const Text('Open'), dense: true)),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)), dense: true)),
            ],
            onSelected: (v) async {
              if (v == 'share') onShare();
              if (v == 'open') launchUrl(Uri.parse(getUrl(file.storagePath)));
              if (v == 'delete') onDelete();
            },
          ),
        ],
      ),
    );
  }
}

class _FolderListItem extends StatelessWidget {
  final FileFolder folder;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _FolderListItem({required this.folder, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = Color(AppConstants.folderColors[folder.color] ?? 0xFF3B82F6);
    return ListTile(leading: Icon(Icons.folder, color: color), title: Text(folder.name), onTap: onTap, trailing: PopupMenuButton<String>(itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('Delete'))], onSelected: (_) => onDelete()));
  }
}

class _FileListItem extends StatelessWidget {
  final UserFile file;
  final String Function(String) getUrl;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  const _FileListItem({required this.file, required this.getUrl, required this.onShare, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.insert_drive_file_outlined),
      title: Text(file.fileName),
      subtitle: Text(file.fileSizeFormatted),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (file.isShared) const Icon(Icons.share, size: 16, color: Colors.green),
        PopupMenuButton<String>(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'share', child: Text('Share')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (v) {
            if (v == 'share') onShare();
            if (v == 'delete') onDelete();
          },
        ),
      ]),
    );
  }
}

class _CreateFolderDialog extends StatelessWidget {
  _CreateFolderDialog();
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Folder'),
      content: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Folder name'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Create')),
      ],
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _BreadcrumbChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      TextButton(onPressed: onTap, style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 4)), child: Text(label, style: const TextStyle(fontSize: 13))),
    ]);
  }
}
