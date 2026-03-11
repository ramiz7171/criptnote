import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../core/constants.dart';
import '../../services/gemini_service.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String noteId;
  const NoteEditorScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late quill.QuillController _quillController;
  final _titleController = TextEditingController();
  final _scrollController = ScrollController();
  final _codeController = TextEditingController();
  Note? _note;
  bool _initialized = false;
  bool _saving = false;
  bool _aiLoading = false;
  String _selectedColor = '#ffffff';
  DateTime? _expiresAt;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNote());
  }

  void _loadNote() {
    final notesState = ref.read(notesProvider);
    final note = notesState.notes.where((n) => n.id == widget.noteId).firstOrNull;
    if (note == null) return;

    setState(() => _note = note);
    _titleController.text = note.title;
    _selectedColor = note.color;
    _expiresAt = note.expiresAt != null ? DateTime.tryParse(note.expiresAt!) : null;
    _scheduledAt = note.scheduledAt != null ? DateTime.tryParse(note.scheduledAt!) : null;

    // Load content
    String content = note.content;

    // Decrypt if needed
    final enc = ref.read(encryptionProvider);
    if (enc.isEncryptionEnabled && enc.isUnlocked) {
      try {
        content = ref.read(encryptionProvider.notifier).decryptString(content);
      } catch (_) {}
    }

    if (note.noteType.isCode) {
      _codeController.text = content;
    } else {
      try {
        if (content.isNotEmpty && content.trimLeft().startsWith('[')) {
          final json = jsonDecode(content) as List;
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(json),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else if (content.isNotEmpty) {
          final doc = quill.Document();
          doc.insert(0, content);
          _quillController = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } catch (_) {
        final doc = quill.Document();
        doc.insert(0, content);
        _quillController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    }

    setState(() => _initialized = true);
  }

  Future<void> _save() async {
    if (_note == null) return;
    setState(() => _saving = true);

    String content;
    if (_note!.noteType.isCode) {
      content = _codeController.text;
    } else {
      content = jsonEncode(_quillController.document.toDelta().toJson());
    }

    // Encrypt if needed
    final enc = ref.read(encryptionProvider);
    if (enc.isEncryptionEnabled && enc.isUnlocked) {
      content = ref.read(encryptionProvider.notifier).encryptString(content);
    }

    await ref.read(notesProvider.notifier).updateNote(_note!.id, {
      'title': _titleController.text.trim(),
      'content': content,
      'color': _selectedColor,
      'expires_at': _expiresAt?.toIso8601String(),
      'scheduled_at': _scheduledAt?.toIso8601String(),
    });

    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (_note == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Move this note to trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notesProvider.notifier).deleteNote(_note!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickColor() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Note Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.noteColors.map((hex) {
            Color color;
            try {
              color = Color(int.parse(hex.replaceAll('#', '0xFF')));
            } catch (_) {
              color = Colors.white;
            }
            return GestureDetector(
              onTap: () => Navigator.pop(context, hex),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedColor == hex ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
                    width: _selectedColor == hex ? 2.5 : 1,
                  ),
                ),
                child: _selectedColor == hex ? const Icon(Icons.check, size: 18) : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
    if (selected != null) setState(() => _selectedColor = selected);
  }

  Future<void> _aiSummarize() async {
    final text = _note!.noteType.isCode ? _codeController.text : _quillController.document.toPlainText();
    if (text.trim().isEmpty) return;
    setState(() => _aiLoading = true);
    final result = await GeminiService.summarize(text);
    setState(() => _aiLoading = false);
    if (result != null && mounted) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('AI Summary'),
        content: SingleChildScrollView(child: Text(result)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    }
  }

  Future<void> _aiFixGrammar() async {
    final text = _quillController.document.toPlainText();
    if (text.trim().isEmpty) return;
    setState(() => _aiLoading = true);
    final result = await GeminiService.checkGrammar(text);
    setState(() => _aiLoading = false);
    if (result != null && mounted) {
      // Replace content with corrected text
      final doc = quill.Document();
      doc.insert(0, result);
      setState(() {
        _quillController = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grammar fixed by AI')));
    }
  }

  Future<void> _aiFixCode() async {
    final code = _codeController.text;
    if (code.trim().isEmpty) return;
    final language = {
      NoteType.java: 'java', NoteType.javascript: 'javascript',
      NoteType.python: 'python', NoteType.sql: 'sql',
    }[_note!.noteType] ?? 'code';
    setState(() => _aiLoading = true);
    final result = await GeminiService.fixCode(code, language);
    setState(() => _aiLoading = false);
    if (result != null && mounted) {
      // Strip markdown code fences if present
      String clean = result;
      final fence = RegExp(r'```\w*\n?([\s\S]*?)```');
      final match = fence.firstMatch(clean);
      if (match != null) clean = match.group(1) ?? clean;
      setState(() => _codeController.text = clean.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code reviewed by AI')));
    }
  }

  Future<void> _pickExpiration() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() => _expiresAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_initialized) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    final note = _note!;
    final isCode = note.noteType.isCode;

    Color? bgColor;
    if (_selectedColor != '#ffffff' && _selectedColor.isNotEmpty) {
      try { bgColor = Color(int.parse(_selectedColor.replaceAll('#', '0xFF'))); } catch (_) {}
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Title',
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_expiresAt != null)
            TextButton.icon(
              icon: const Icon(Icons.timer, size: 14),
              label: Text('${_expiresAt!.month}/${_expiresAt!.day}', style: const TextStyle(fontSize: 12)),
              onPressed: () => setState(() => _expiresAt = null),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          if (_aiLoading)
            const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple)))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.auto_awesome, color: Colors.purple),
              tooltip: 'AI',
              itemBuilder: (_) => [
                if (!isCode) ...[
                  const PopupMenuItem(value: 'summarize', child: ListTile(leading: Icon(Icons.summarize), title: Text('Summarize'), dense: true)),
                  const PopupMenuItem(value: 'grammar', child: ListTile(leading: Icon(Icons.spellcheck), title: Text('Fix Grammar'), dense: true)),
                ] else
                  const PopupMenuItem(value: 'fixcode', child: ListTile(leading: Icon(Icons.bug_report), title: Text('Fix Code'), dense: true)),
              ],
              onSelected: (v) {
                if (v == 'summarize') _aiSummarize();
                if (v == 'grammar') _aiFixGrammar();
                if (v == 'fixcode') _aiFixCode();
              },
            ),
          IconButton(icon: const Icon(Icons.color_lens_outlined), onPressed: _pickColor),
          IconButton(icon: const Icon(Icons.timer_outlined), onPressed: _pickExpiration),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _delete),
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.save_outlined), onPressed: _save),
        ],
      ),
      body: Column(
        children: [
          // Toolbar for rich text only
          if (!isCode)
            quill.QuillSimpleToolbar(
              controller: _quillController,
              config: quill.QuillSimpleToolbarConfig(
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showListBullets: true,
                showListNumbers: true,
                showListCheck: true,
                showCodeBlock: true,
                showLink: true,
                showHeaderStyle: true,
                showAlignmentButtons: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showFontSize: true,
                showUndo: true,
                showRedo: true,
                showClearFormat: true,
              ),
            ),

          // Editor content
          Expanded(
            child: isCode ? _buildCodeEditor(isDark) : _buildRichEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildRichEditor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: quill.QuillEditor(
        controller: _quillController,
        focusNode: FocusNode(),
        scrollController: _scrollController,
        config: const quill.QuillEditorConfig(
          placeholder: 'Start writing...',
          padding: EdgeInsets.zero,
          autoFocus: false,
        ),
      ),
    );
  }

  Widget _buildCodeEditor(bool isDark) {
    final language = {
      NoteType.java: 'java',
      NoteType.javascript: 'javascript',
      NoteType.python: 'python',
      NoteType.sql: 'sql',
    }[_note!.noteType] ?? 'plaintext';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
          child: Row(
            children: [
              const Icon(Icons.code, size: 16),
              const SizedBox(width: 8),
              Text(_note!.noteType.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
            child: TextField(
              controller: _codeController,
              scrollController: _scrollController,
              expands: true,
              maxLines: null,
              minLines: null,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Write your $language code here...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                fillColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}
