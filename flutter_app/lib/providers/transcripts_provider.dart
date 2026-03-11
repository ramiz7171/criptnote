import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transcript.dart';
import '../services/transcripts_service.dart';
import 'auth_provider.dart';

class TranscriptsNotifier extends StateNotifier<List<Transcript>> {
  TranscriptsNotifier(this._userId) : super([]) {
    _load();
  }

  final String _userId;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    final transcripts = await TranscriptsService.fetchTranscripts(_userId);
    state = transcripts;
    _subscribe();
  }

  void _subscribe() {
    _channel = TranscriptsService.subscribeToTranscripts(_userId, (event, record) {
      if (record.isEmpty) return;
      final t = Transcript.fromJson(record);
      if (event == 'insert') {
        if (!state.any((x) => x.id == t.id)) state = [...state, t];
      } else if (event == 'update') {
        state = state.map((x) => x.id == t.id ? t : x).toList();
      } else if (event == 'delete') {
        state = state.where((x) => x.id != t.id).toList();
      }
    });
  }

  Future<Transcript?> createTranscript({
    required String title,
    String transcriptText = '',
    String summary = '',
    String actionItems = '',
    String audioUrl = '',
    String status = 'processing',
    int durationSeconds = 0,
    List<String>? tags,
    String? meetingId,
  }) async {
    final t = await TranscriptsService.createTranscript(
      userId: _userId,
      title: title,
      transcriptText: transcriptText,
      summary: summary,
      actionItems: actionItems,
      audioUrl: audioUrl,
      status: status,
      durationSeconds: durationSeconds,
      tags: tags,
      meetingId: meetingId,
    );
    if (t != null) state = [t, ...state];
    return t;
  }

  Future<void> updateTranscript(String id, Map<String, dynamic> updates) async {
    await TranscriptsService.updateTranscript(id, updates);
    state = state.map((t) {
      if (t.id != id) return t;
      return Transcript.fromJson({...t.toJson(), ...updates});
    }).toList();
  }

  Future<void> deleteTranscript(String id) async {
    state = state.where((t) => t.id != id).toList();
    await TranscriptsService.deleteTranscript(id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final transcriptsProvider = StateNotifierProvider.autoDispose<TranscriptsNotifier, List<Transcript>>((ref) {
  final auth = ref.watch(authProvider);
  return TranscriptsNotifier(auth.user?.id ?? '');
});
