enum NoteType { basic, checkbox, java, javascript, python, sql, board }

extension NoteTypeExtension on NoteType {
  String get value {
    switch (this) {
      case NoteType.basic: return 'basic';
      case NoteType.checkbox: return 'checkbox';
      case NoteType.java: return 'java';
      case NoteType.javascript: return 'javascript';
      case NoteType.python: return 'python';
      case NoteType.sql: return 'sql';
      case NoteType.board: return 'board';
    }
  }

  static NoteType fromString(String s) {
    switch (s) {
      case 'checkbox': return NoteType.checkbox;
      case 'java': return NoteType.java;
      case 'javascript': return NoteType.javascript;
      case 'python': return NoteType.python;
      case 'sql': return NoteType.sql;
      case 'board': return NoteType.board;
      default: return NoteType.basic;
    }
  }

  bool get isCode => [NoteType.java, NoteType.javascript, NoteType.python, NoteType.sql].contains(this);
  String get label {
    switch (this) {
      case NoteType.basic: return 'Note';
      case NoteType.checkbox: return 'Checklist';
      case NoteType.java: return 'Java';
      case NoteType.javascript: return 'JavaScript';
      case NoteType.python: return 'Python';
      case NoteType.sql: return 'SQL';
      case NoteType.board: return 'Board';
    }
  }
}

class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final NoteType noteType;
  final bool archived;
  final bool pinned;
  final String? deletedAt;
  final String? folderId;
  final String color;
  final int position;
  final String? expiresAt;
  final String? scheduledAt;
  final String createdAt;
  final String updatedAt;

  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.noteType,
    required this.archived,
    required this.pinned,
    this.deletedAt,
    this.folderId,
    required this.color,
    required this.position,
    this.expiresAt,
    this.scheduledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      noteType: NoteTypeExtension.fromString(json['note_type'] as String? ?? 'basic'),
      archived: json['archived'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      deletedAt: json['deleted_at'] as String?,
      folderId: json['folder_id'] as String?,
      color: json['color'] as String? ?? '#ffffff',
      position: json['position'] as int? ?? 0,
      expiresAt: json['expires_at'] as String?,
      scheduledAt: json['scheduled_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'content': content,
    'note_type': noteType.value,
    'archived': archived,
    'pinned': pinned,
    'deleted_at': deletedAt,
    'folder_id': folderId,
    'color': color,
    'position': position,
    'expires_at': expiresAt,
    'scheduled_at': scheduledAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    NoteType? noteType,
    bool? archived,
    bool? pinned,
    String? deletedAt,
    Object? folderId = _sentinel,
    String? color,
    int? position,
    String? expiresAt,
    String? scheduledAt,
    String? createdAt,
    String? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      noteType: noteType ?? this.noteType,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      deletedAt: deletedAt ?? this.deletedAt,
      folderId: folderId == _sentinel ? this.folderId : folderId as String?,
      color: color ?? this.color,
      position: position ?? this.position,
      expiresAt: expiresAt ?? this.expiresAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isDeleted => deletedAt != null;
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.parse(expiresAt!).isBefore(DateTime.now());
  }
  bool get isScheduled {
    if (scheduledAt == null) return false;
    return DateTime.parse(scheduledAt!).isAfter(DateTime.now());
  }
  bool get isActive => !archived && deletedAt == null && !isExpired && !isScheduled;
}

const _sentinel = Object();
