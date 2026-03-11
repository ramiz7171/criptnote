import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/transcripts_provider.dart';
import '../../models/transcript.dart';
import '../../services/gemini_service.dart';

class TranscriptsScreen extends ConsumerStatefulWidget {
  const TranscriptsScreen({super.key});

  @override
  ConsumerState<TranscriptsScreen> createState() => _TranscriptsScreenState();
}

class _TranscriptsScreenState extends ConsumerState<TranscriptsScreen> {
  String _search = '';

  Future<void> _record() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required')));
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecordSheet(notifier: ref.read(transcriptsProvider.notifier)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transcripts = ref.watch(transcriptsProvider);
    final notifier = ref.read(transcriptsProvider.notifier);

    final filtered = _search.isEmpty
        ? transcripts
        : transcripts.where((t) => t.title.toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Transcripts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _record,
        icon: const Icon(Icons.mic),
        label: const Text('Record'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search transcripts...',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_none, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No transcripts yet', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      return _TranscriptCard(
                        transcript: t,
                        onTap: () => _openTranscript(t),
                        onDelete: () => notifier.deleteTranscript(t.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openTranscript(Transcript transcript) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TranscriptDetailSheet(
        transcript: transcript,
        notifier: ref.read(transcriptsProvider.notifier),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  final Transcript transcript;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TranscriptCard({required this.transcript, required this.onTap, required this.onDelete});

  Color get _statusColor {
    switch (transcript.status) {
      case TranscriptStatus.processing: return Colors.orange;
      case TranscriptStatus.completed: return Colors.green;
      case TranscriptStatus.failed: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy').format(DateTime.parse(transcript.createdAt));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.mic, color: _statusColor, size: 20),
        ),
        title: Text(transcript.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(date, style: const TextStyle(fontSize: 12)),
          if (transcript.durationSeconds > 0)
            Text(transcript.durationFormatted, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(transcript.status.value, style: TextStyle(fontSize: 11, color: _statusColor)),
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
            onSelected: (_) => onDelete(),
          ),
        ]),
        isThreeLine: true,
      ),
    );
  }
}

class _TranscriptDetailSheet extends StatelessWidget {
  final Transcript transcript;
  final TranscriptsNotifier notifier;
  const _TranscriptDetailSheet({required this.transcript, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: controller,
          children: [
            Text(transcript.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(transcript.createdAt)),
              style: const TextStyle(color: Colors.grey),
            ),
            if (transcript.durationSeconds > 0)
              Text(transcript.durationFormatted, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),

            if (transcript.summary.isNotEmpty) ...[
              const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Text(transcript.summary),
              ),
              const SizedBox(height: 16),
            ],

            if (transcript.actionItems.isNotEmpty) ...[
              const Text('Action Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(transcript.actionItems),
              const SizedBox(height: 16),
            ],

            if (transcript.speakerSegments.isNotEmpty) ...[
              const Text('Transcript', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...transcript.speakerSegments.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.speaker, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue, fontSize: 13)),
                  Text(s.text),
                ]),
              )),
            ] else if (transcript.transcriptText.isNotEmpty) ...[
              const Text('Transcript', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(transcript.transcriptText),
            ],

            if (transcript.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 6, children: transcript.tags.map((t) => Chip(label: Text(t, style: const TextStyle(fontSize: 12)))).toList()),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordSheet extends StatefulWidget {
  final TranscriptsNotifier notifier;
  const _RecordSheet({required this.notifier});

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  int _seconds = 0;
  String? _recordingPath;
  String? _error;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordingPath!);
    setState(() { _isRecording = true; _seconds = 0; _error = null; });
    _tick();
  }

  void _tick() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isRecording) setState(() => _seconds++);
    }
  }

  Future<void> _stopAndTranscribe() async {
    await _recorder.stop();
    setState(() { _isRecording = false; _isProcessing = true; });

    if (_recordingPath == null) {
      setState(() { _isProcessing = false; _error = 'No recording found'; });
      return;
    }

    final title = 'Recording ${DateFormat('MMM d, HH:mm').format(DateTime.now())}';
    final audioFile = File(_recordingPath!);

    try {
      final audioBytes = await audioFile.readAsBytes();

      // Create transcript record with 'processing' status
      final transcript = await widget.notifier.createTranscript(
        title: title,
        status: 'processing',
        durationSeconds: _seconds,
      );

      if (transcript != null) {
        // Transcribe via Gemini AI
        final result = await GeminiService.transcribeAudio(audioBytes, 'audio/m4a');

        if (result != null) {
          await widget.notifier.updateTranscript(transcript.id, {
            'status': 'completed',
            'transcript_text': result['transcript'] ?? '',
            'summary': result['summary'] ?? '',
            'action_items': result['actionItems'] ?? '',
          });
        } else {
          await widget.notifier.updateTranscript(transcript.id, {'status': 'failed'});
          setState(() => _error = 'Transcription failed — check your AI connection');
        }
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      // Cleanup temp file
      try { await audioFile.delete(); } catch (_) {}
      setState(() => _isProcessing = false);
    }

    if (mounted && _error == null) Navigator.pop(context);
  }

  String get _timerText {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        top: 32,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Voice Recording', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Text(
            _timerText,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 32),

          if (_isProcessing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Transcribing with AI...', style: TextStyle(color: Colors.grey)),
          ] else if (!_isRecording)
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.mic),
              label: const Text('Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _stopAndTranscribe,
              icon: const Icon(Icons.stop),
              label: const Text('Stop & Transcribe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
            ),

          const SizedBox(height: 16),
          if (_isRecording)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('Recording...', style: TextStyle(color: Colors.red)),
            ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ],
      ),
    );
  }
}
