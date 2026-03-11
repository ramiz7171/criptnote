enum MeetingStatus { scheduled, inProgress, completed, cancelled }

extension MeetingStatusExt on MeetingStatus {
  String get value {
    switch (this) {
      case MeetingStatus.scheduled: return 'scheduled';
      case MeetingStatus.inProgress: return 'in_progress';
      case MeetingStatus.completed: return 'completed';
      case MeetingStatus.cancelled: return 'cancelled';
    }
  }

  static MeetingStatus fromString(String s) {
    switch (s) {
      case 'in_progress': return MeetingStatus.inProgress;
      case 'completed': return MeetingStatus.completed;
      case 'cancelled': return MeetingStatus.cancelled;
      default: return MeetingStatus.scheduled;
    }
  }

  String get label {
    switch (this) {
      case MeetingStatus.scheduled: return 'Scheduled';
      case MeetingStatus.inProgress: return 'In Progress';
      case MeetingStatus.completed: return 'Completed';
      case MeetingStatus.cancelled: return 'Cancelled';
    }
  }
}

class AgendaItem {
  final String text;
  final bool completed;

  const AgendaItem({required this.text, required this.completed});

  factory AgendaItem.fromJson(Map<String, dynamic> json) => AgendaItem(
        text: json['text'] as String,
        completed: json['completed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'text': text, 'completed': completed};

  AgendaItem copyWith({String? text, bool? completed}) =>
      AgendaItem(text: text ?? this.text, completed: completed ?? this.completed);
}

class Meeting {
  final String id;
  final String userId;
  final String title;
  final String meetingDate;
  final int durationMinutes;
  final List<String> participants;
  final List<String> tags;
  final List<AgendaItem> agenda;
  final MeetingStatus status;
  final String aiNotes;
  final String followUp;
  final String audioUrl;
  final String? transcriptId;
  final String createdAt;
  final String updatedAt;

  const Meeting({
    required this.id,
    required this.userId,
    required this.title,
    required this.meetingDate,
    required this.durationMinutes,
    required this.participants,
    required this.tags,
    required this.agenda,
    required this.status,
    required this.aiNotes,
    required this.followUp,
    required this.audioUrl,
    this.transcriptId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    List<AgendaItem> parseAgenda(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => AgendaItem.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    }

    return Meeting(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      meetingDate: json['meeting_date'] as String? ?? DateTime.now().toIso8601String(),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      participants: parseStringList(json['participants']),
      tags: parseStringList(json['tags']),
      agenda: parseAgenda(json['agenda']),
      status: MeetingStatusExt.fromString(json['status'] as String? ?? 'scheduled'),
      aiNotes: json['ai_notes'] as String? ?? '',
      followUp: json['follow_up'] as String? ?? '',
      audioUrl: json['audio_url'] as String? ?? '',
      transcriptId: json['transcript_id'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'meeting_date': meetingDate,
        'duration_minutes': durationMinutes,
        'participants': participants,
        'tags': tags,
        'agenda': agenda.map((a) => a.toJson()).toList(),
        'status': status.value,
        'ai_notes': aiNotes,
        'follow_up': followUp,
        'audio_url': audioUrl,
        'transcript_id': transcriptId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Meeting copyWith({
    String? title,
    String? meetingDate,
    int? durationMinutes,
    List<String>? participants,
    List<String>? tags,
    List<AgendaItem>? agenda,
    MeetingStatus? status,
    String? aiNotes,
    String? followUp,
    String? audioUrl,
    String? transcriptId,
  }) =>
      Meeting(
        id: id,
        userId: userId,
        title: title ?? this.title,
        meetingDate: meetingDate ?? this.meetingDate,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        participants: participants ?? this.participants,
        tags: tags ?? this.tags,
        agenda: agenda ?? this.agenda,
        status: status ?? this.status,
        aiNotes: aiNotes ?? this.aiNotes,
        followUp: followUp ?? this.followUp,
        audioUrl: audioUrl ?? this.audioUrl,
        transcriptId: transcriptId ?? this.transcriptId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
