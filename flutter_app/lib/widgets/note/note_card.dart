import 'package:flutter/material.dart';
import '../../models/note.dart';
import 'package:intl/intl.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final bool isListView;
  final VoidCallback onTap;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPermanentDelete;
  final bool showTrashActions;

  const NoteCard({
    super.key,
    required this.note,
    this.isListView = false,
    required this.onTap,
    this.onPin,
    this.onArchive,
    this.onDelete,
    this.onRestore,
    this.onPermanentDelete,
    this.showTrashActions = false,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.transparent;
    }
  }

  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _parseColor(note.color);
    final hasCustomColor = note.color != '#ffffff' && note.color.isNotEmpty;
    final textColor = hasCustomColor && _isLightColor(bgColor) ? Colors.black87 : null;
    final cardColor = hasCustomColor ? bgColor : null;
    final content = _getPreviewContent();
    final formattedDate = DateFormat('MMM d').format(DateTime.parse(note.updatedAt));

    if (isListView) {
      return Card(
        color: cardColor,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (note.pinned) ...[
                            Icon(Icons.push_pin, size: 12, color: textColor ?? Colors.grey),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              note.title.isEmpty ? 'Untitled' : note.title,
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(content, style: TextStyle(fontSize: 12, color: textColor ?? Colors.grey, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formattedDate, style: TextStyle(fontSize: 11, color: textColor ?? Colors.grey)),
                    const SizedBox(height: 4),
                    _buildMenu(textColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.pinned) Icon(Icons.push_pin, size: 12, color: textColor ?? Colors.grey),
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildMenu(textColor),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: Text(content, style: TextStyle(fontSize: 12, color: textColor ?? Colors.grey, height: 1.4), overflow: TextOverflow.fade),
                ),
              ] else const Spacer(),
              Row(
                children: [
                  _buildTypeBadge(textColor),
                  const Spacer(),
                  Text(formattedDate, style: TextStyle(fontSize: 11, color: textColor ?? Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPreviewContent() {
    // Strip HTML tags for preview
    return note.content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .substring(0, note.content.length > 200 ? 200 : note.content.length);
  }

  Widget _buildTypeBadge(Color? textColor) {
    if (note.noteType == NoteType.basic) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(note.noteType.label, style: TextStyle(fontSize: 10, color: textColor ?? Colors.blue)),
    );
  }

  Widget _buildMenu(Color? textColor) {
    if (showTrashActions) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.restore, size: 18),
            onPressed: onRestore,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.green,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_forever, size: 18),
            onPressed: onPermanentDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.red,
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 16, color: textColor ?? Colors.grey),
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'pin', child: ListTile(leading: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18), title: Text(note.pinned ? 'Unpin' : 'Pin'), dense: true)),
        PopupMenuItem(value: 'archive', child: ListTile(leading: const Icon(Icons.archive_outlined, size: 18), title: const Text('Archive'), dense: true)),
        PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete_outline, size: 18, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)), dense: true)),
      ],
      onSelected: (val) {
        if (val == 'pin') onPin?.call();
        if (val == 'archive') onArchive?.call();
        if (val == 'delete') onDelete?.call();
      },
    );
  }
}
