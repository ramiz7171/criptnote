class AppConstants {
  static const String supabaseUrl = 'https://kgylvsenyoqjwonmoibs.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtneWx2c2VueW9xandvbm1vaWJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MTYwOTAsImV4cCI6MjA4NzM5MjA5MH0.wYtOxtn911MPyLCIoAGJJo6lGzsPjSWHQZiqzJSYO6A';
  static const String geminiApiKey = 'AIzaSyBTRMAhiAScMBFfbkz0qxzZLXmDyHRJqMA';

  // Storage
  static const String userFilesBucket = 'user-files';
  static const int maxFileSizeBytes = 15 * 1024 * 1024; // 15 MB

  // PIN
  static const String pinStorageKey = 'criptnote_pin_hash';
  static const String themeStorageKey = 'criptnote_theme';
  static const String encryptionSaltKey = 'criptnote_enc_salt';

  // AI daily limits
  static const int aiSummarizeLimit = 5;
  static const int aiGrammarLimit = 5;
  static const int aiTranscriptLimit = 3;
  static const int aiMeetingLimit = 2;

  // Note soft-delete retention days
  static const int trashRetentionDays = 30;

  // Idle timeout options (minutes)
  static const List<int> idleTimeoutOptions = [0, 1, 5, 10, 30, 60];

  // Note colors
  static const List<String> noteColors = [
    '#ffffff',
    '#fef08a',
    '#bbf7d0',
    '#bfdbfe',
    '#fecaca',
    '#e9d5ff',
    '#fed7aa',
    '#d1fae5',
    '#fce7f3',
    '#ccfbf1',
  ];

  // File folder colors
  static const Map<String, int> folderColors = {
    'blue': 0xFF3B82F6,
    'green': 0xFF22C55E,
    'yellow': 0xFFF59E0B,
    'red': 0xFFEF4444,
    'purple': 0xFFA855F7,
    'gray': 0xFF6B7280,
  };
}
