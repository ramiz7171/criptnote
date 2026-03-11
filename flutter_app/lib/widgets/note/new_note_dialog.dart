import 'package:flutter/material.dart';
import '../../models/note.dart';

class NewNoteDialog extends StatefulWidget {
  final String? folderId;
  const NewNoteDialog({super.key, this.folderId});

  @override
  State<NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<NewNoteDialog> {
  final _titleController = TextEditingController();
  NoteType _selectedType = NoteType.basic;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Note title', labelText: 'Title'),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<NoteType>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: NoteType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
            onChanged: (v) => setState(() => _selectedType = v ?? NoteType.basic),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, {
      'title': title,
      'type': _selectedType,
      'folderId': widget.folderId,
    });
  }
}
