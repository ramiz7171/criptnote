import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meeting.dart';
import '../services/meetings_service.dart';
import 'auth_provider.dart';

class MeetingsNotifier extends StateNotifier<List<Meeting>> {
  MeetingsNotifier(this._userId) : super([]) {
    _load();
  }

  final String _userId;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    final meetings = await MeetingsService.fetchMeetings(_userId);
    state = meetings;
    _subscribe();
  }

  void _subscribe() {
    _channel = MeetingsService.subscribeToMeetings(_userId, (event, record) {
      if (record.isEmpty) return;
      final meeting = Meeting.fromJson(record);
      if (event == 'insert') {
        if (!state.any((m) => m.id == meeting.id)) state = [...state, meeting];
      } else if (event == 'update') {
        state = state.map((m) => m.id == meeting.id ? meeting : m).toList();
      } else if (event == 'delete') {
        state = state.where((m) => m.id != meeting.id).toList();
      }
    });
  }

  Future<Meeting?> createMeeting({
    required String title,
    String? meetingDate,
    List<String>? participants,
    List<String>? tags,
    List<AgendaItem>? agenda,
  }) async {
    final meeting = await MeetingsService.createMeeting(
      userId: _userId, title: title, meetingDate: meetingDate,
      participants: participants, tags: tags, agenda: agenda,
    );
    if (meeting != null) state = [...state, meeting];
    return meeting;
  }

  Future<void> updateMeeting(String id, Map<String, dynamic> updates) async {
    await MeetingsService.updateMeeting(id, updates);
    state = state.map((m) {
      if (m.id != id) return m;
      return Meeting.fromJson({...m.toJson(), ...updates});
    }).toList();
  }

  Future<void> deleteMeeting(String id) async {
    state = state.where((m) => m.id != id).toList();
    await MeetingsService.deleteMeeting(id);
  }

  List<Meeting> get upcoming => state
      .where((m) => m.status == MeetingStatus.scheduled || m.status == MeetingStatus.inProgress)
      .toList();

  List<Meeting> get completed => state
      .where((m) => m.status == MeetingStatus.completed || m.status == MeetingStatus.cancelled)
      .toList();

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final meetingsProvider = StateNotifierProvider.autoDispose<MeetingsNotifier, List<Meeting>>((ref) {
  final auth = ref.watch(authProvider);
  return MeetingsNotifier(auth.user?.id ?? '');
});
