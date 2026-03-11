import 'dart:io';
import 'supabase_service.dart';
import '../models/audit_log.dart';

class AuditService {
  static final _client = SupabaseService.client;

  static Future<List<AuditLog>> fetchAuditLogs(String userId, {int limit = 4, int offset = 0}) async {
    final response = await _client
        .from('audit_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List).map((e) => AuditLog.fromJson(e)).toList();
  }

  static Future<void> log({
    required String userId,
    required String action,
    String? resourceType,
    String? resourceId,
    Map<String, dynamic>? details,
  }) async {
    final deviceInfo = _getDeviceInfo();
    await _client.from('audit_logs').insert({
      'user_id': userId,
      'action': action,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'details': details ?? {},
      'device_info': deviceInfo,
    });
  }

  static String _getDeviceInfo() {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      return 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  // Session management
  static Future<List<SessionRecord>> fetchSessions(String userId) async {
    final response = await _client
        .from('sessions')
        .select()
        .eq('user_id', userId)
        .order('last_active_at', ascending: false);
    return (response as List).map((e) => SessionRecord.fromJson(e)).toList();
  }

  static Future<void> deleteSession(String sessionId) async {
    await _client.from('sessions').delete().eq('id', sessionId);
  }

  static Future<void> deleteAllSessions(String userId) async {
    await _client.from('sessions').delete().eq('user_id', userId);
  }
}
