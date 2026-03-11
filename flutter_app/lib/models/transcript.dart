enum TranscriptStatus { processing, completed, failed }

extension TranscriptStatusExt on TranscriptStatus {
  String get value {
    switch (this) {
      case TranscriptStatus.processing: return 'processing';
      case TranscriptStatus.completed: return 'completed';
      case TranscriptStatus.failed: return 'failed';
    }
  }

  static TranscriptStatus fromString(String s) {
    switch (s) {
      case 'completed': return TranscriptStatus.completed;
      case 'failed': return TranscriptStatus.failed;
      default: return TranscriptStatus.processing;
    }
  }
}

class SpeakerSegment {
  final String speaker;
  final String text;

  const SpeakerSegment({required this.speaker, required this.text});

  factory SpeakerSegment.fromJson(Map<String, dynamic> json) =>
      SpeakerSegment(speaker: json['speaker'] as String, text: json['text'] as String);

  Map<String, dynamic> toJson() => {'speaker': speaker, 'text': text};
}

class Transcript {
  final String id;
  final String userId;
  final String title;
  final String transcriptText;
  final List<SpeakerSegment> speakerSegments;
  final String summary;
  final String actionItems;
  final String audioUrl;
  final TranscriptStatus status;
  final int durationSeconds;
  final List<String> tags;
  final String? meetingId;
  final String createdAt;
  final String updatedAt;

  const Transcript({
    required this.id,
    required this.userId,
    required this.title,
    required this.transcriptText,
    required this.speakerSegments,
    required this.summary,
    required this.actionItems,
    required this.audioUrl,
    required this.status,
    required this.durationSeconds,
    required this.tags,
    this.meetingId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transcript.fromJson(Map<String, dynamic> json) {
    List<SpeakerSegment> parseSegments(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => SpeakerSegment.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    }

    List<String> parseStringList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return Transcript(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      transcriptText: json['transcript_text'] as String? ?? '',
      speakerSegments: parseSegments(json['speaker_segments']),
      summary: json['summary'] as String? ?? '',
      actionItems: json['action_items'] as String? ?? '',
      audioUrl: json['audio_url'] as String? ?? '',
      status: TranscriptStatusExt.fromString(json['status'] as String? ?? 'processing'),
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      tags: parseStringList(json['tags']),
      meetingId: json['meeting_id'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'transcript_text': transcriptText,
        'speaker_segments': speakerSegments.map((s) => s.toJson()).toList(),
        'summary': summary,
        'action_items': actionItems,
        'audio_url': audioUrl,
        'status': status.value,
        'duration_seconds': durationSeconds,
        'tags': tags,
        'meeting_id': meetingId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m}m ${s}s';
  }
}
