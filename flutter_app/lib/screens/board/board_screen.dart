import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../providers/notes_provider.dart';
import '../../models/note.dart';

enum _DrawTool { pen, marker, highlighter, eraser }

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final _DrawTool tool;

  const _Stroke({required this.points, required this.color, required this.width, required this.tool});

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'color': color.toARGB32(),
    'width': width,
    'tool': tool.index,
  };

  factory _Stroke.fromJson(Map<String, dynamic> json) => _Stroke(
    points: (json['points'] as List).map((p) => Offset(p['x'] as double, p['y'] as double)).toList(),
    color: Color(json['color'] as int),
    width: (json['width'] as num).toDouble(),
    tool: _DrawTool.values[json['tool'] as int],
  );
}

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  final List<_Stroke> _strokes = [];
  final List<_Stroke> _redoStack = [];
  _Stroke? _currentStroke;

  _DrawTool _tool = _DrawTool.pen;
  Color _color = Colors.black;
  double _width = 3.0;
  Note? _boardNote;

  final List<Color> _palette = [
    Colors.black, Colors.white, Colors.red, Colors.orange, Colors.yellow,
    Colors.green, Colors.blue, Colors.purple, Colors.pink, Colors.brown,
    Colors.grey, Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBoardNote());
  }

  void _loadBoardNote() {
    final notesState = ref.read(notesProvider);
    final board = notesState.boardNotes.isNotEmpty ? notesState.boardNotes.first : null;
    if (board != null) {
      setState(() => _boardNote = board);
      _loadStrokes(board.content);
    }
  }

  void _loadStrokes(String content) {
    if (content.isEmpty) return;
    try {
      final List<dynamic> data = jsonDecode(content);
      setState(() {
        _strokes.clear();
        _strokes.addAll(data.map((s) => _Stroke.fromJson(s as Map<String, dynamic>)));
      });
    } catch (_) {}
  }

  Future<void> _saveBoard() async {
    final content = jsonEncode(_strokes.map((s) => s.toJson()).toList());
    if (_boardNote == null) {
      final note = await ref.read(notesProvider.notifier).createNote(
        title: 'Board',
        content: content,
        noteType: NoteType.board,
      );
      setState(() => _boardNote = note);
    } else {
      await ref.read(notesProvider.notifier).updateNote(_boardNote!.id, {'content': content});
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Board saved')));
  }

  void _clearBoard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Board'),
        content: const Text('This will clear all drawings. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) setState(() { _strokes.clear(); _redoStack.clear(); });
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() { _redoStack.add(_strokes.removeLast()); });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() { _strokes.add(_redoStack.removeLast()); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _strokes.isEmpty ? null : _undo),
          IconButton(icon: const Icon(Icons.redo), onPressed: _redoStack.isEmpty ? null : _redo),
          IconButton(icon: const Icon(Icons.delete_sweep_outlined), onPressed: _clearBoard),
          IconButton(icon: const Icon(Icons.save_outlined), onPressed: _saveBoard),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                // Tools
                _ToolButton(icon: Icons.edit, selected: _tool == _DrawTool.pen, onTap: () => setState(() => _tool = _DrawTool.pen)),
                _ToolButton(icon: Icons.brush, selected: _tool == _DrawTool.marker, onTap: () => setState(() => _tool = _DrawTool.marker)),
                _ToolButton(icon: Icons.highlight, selected: _tool == _DrawTool.highlighter, onTap: () => setState(() => _tool = _DrawTool.highlighter)),
                _ToolButton(icon: Icons.auto_fix_high, selected: _tool == _DrawTool.eraser, onTap: () => setState(() => _tool = _DrawTool.eraser)),
                const VerticalDivider(),

                // Brush sizes
                ...[(3.0, 'S'), (6.0, 'M'), (12.0, 'L'), (20.0, 'XL')].map((pair) =>
                  _SizeButton(label: pair.$2, selected: _width == pair.$1, onTap: () => setState(() => _width = pair.$1))),
                const VerticalDivider(),

                // Colors
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _palette.map((c) => GestureDetector(
                      onTap: () => setState(() { _color = c; _tool = _DrawTool.pen; }),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? Colors.blue : Colors.grey.withOpacity(0.3),
                            width: _color == c ? 2 : 1,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Canvas
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: GestureDetector(
                onPanStart: (d) {
                  final color = _tool == _DrawTool.eraser ? (isDark ? const Color(0xFF1E293B) : Colors.white) : _color;
                  final opacity = _tool == _DrawTool.highlighter ? 0.4 : 1.0;
                  setState(() {
                    _currentStroke = _Stroke(
                      points: [d.localPosition],
                      color: color.withOpacity(opacity),
                      width: _tool == _DrawTool.eraser ? _width * 4 : _width,
                      tool: _tool,
                    );
                    _redoStack.clear();
                  });
                },
                onPanUpdate: (d) {
                  if (_currentStroke == null) return;
                  setState(() {
                    _currentStroke = _Stroke(
                      points: [..._currentStroke!.points, d.localPosition],
                      color: _currentStroke!.color,
                      width: _currentStroke!.width,
                      tool: _currentStroke!.tool,
                    );
                  });
                },
                onPanEnd: (_) {
                  if (_currentStroke != null) {
                    setState(() {
                      _strokes.add(_currentStroke!);
                      _currentStroke = null;
                    });
                  }
                },
                child: CustomPaint(
                  painter: _BoardPainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? currentStroke;

  const _BoardPainter({required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, if (currentStroke != null) currentStroke!]) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onTap,
      color: selected ? const Color(0xFF3B82F6) : null,
      style: selected ? IconButton.styleFrom(backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1)) : null,
    );
  }
}

class _SizeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SizeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 10, color: selected ? Colors.white : null, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
