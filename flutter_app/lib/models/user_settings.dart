class NotificationSettings {
  final bool emailSummaries;
  final bool meetingReminders;
  final bool transcriptReady;

  const NotificationSettings({
    this.emailSummaries = false,
    this.meetingReminders = true,
    this.transcriptReady = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        emailSummaries: json['email_summaries'] as bool? ?? false,
        meetingReminders: json['meeting_reminders'] as bool? ?? true,
        transcriptReady: json['transcript_ready'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'email_summaries': emailSummaries,
        'meeting_reminders': meetingReminders,
        'transcript_ready': transcriptReady,
      };

  NotificationSettings copyWith({
    bool? emailSummaries,
    bool? meetingReminders,
    bool? transcriptReady,
  }) =>
      NotificationSettings(
        emailSummaries: emailSummaries ?? this.emailSummaries,
        meetingReminders: meetingReminders ?? this.meetingReminders,
        transcriptReady: transcriptReady ?? this.transcriptReady,
      );
}

class UserSettings {
  final String id;
  final String userId;
  final String aiTone; // professional | casual | concise | detailed
  final String summaryLength; // short | medium | long
  final NotificationSettings notifications;
  final String defaultView; // grid | list | infinite
  final Map<String, dynamic> preferences;
  final String createdAt;
  final String updatedAt;

  const UserSettings({
    required this.id,
    required this.userId,
    required this.aiTone,
    required this.summaryLength,
    required this.notifications,
    required this.defaultView,
    required this.preferences,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    NotificationSettings parseNotifications(dynamic v) {
      if (v == null) return const NotificationSettings();
      if (v is Map<String, dynamic>) return NotificationSettings.fromJson(v);
      return const NotificationSettings();
    }

    Map<String, dynamic> parsePreferences(dynamic v) {
      if (v == null) return {};
      if (v is Map<String, dynamic>) return v;
      return {};
    }

    return UserSettings(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      aiTone: json['ai_tone'] as String? ?? 'professional',
      summaryLength: json['summary_length'] as String? ?? 'medium',
      notifications: parseNotifications(json['notifications']),
      defaultView: json['default_view'] as String? ?? 'grid',
      preferences: parsePreferences(json['preferences']),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'ai_tone': aiTone,
        'summary_length': summaryLength,
        'notifications': notifications.toJson(),
        'default_view': defaultView,
        'preferences': preferences,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  UserSettings copyWith({
    String? aiTone,
    String? summaryLength,
    NotificationSettings? notifications,
    String? defaultView,
    Map<String, dynamic>? preferences,
  }) =>
      UserSettings(
        id: id,
        userId: userId,
        aiTone: aiTone ?? this.aiTone,
        summaryLength: summaryLength ?? this.summaryLength,
        notifications: notifications ?? this.notifications,
        defaultView: defaultView ?? this.defaultView,
        preferences: preferences ?? this.preferences,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  int get idleTimeoutMinutes => (preferences['idle_timeout_minutes'] as num?)?.toInt() ?? 0;
  bool get encryptionEnabled => preferences['encryption_enabled'] as bool? ?? false;
  String? get encryptionSalt => preferences['encryption_salt'] as String?;
}
