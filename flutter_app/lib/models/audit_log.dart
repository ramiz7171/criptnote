class AuditLog {
  final String id;
  final String userId;
  final String action;
  final String? resourceType;
  final String? resourceId;
  final Map<String, dynamic> details;
  final String deviceInfo;
  final String createdAt;

  const AuditLog({
    required this.id,
    required this.userId,
    required this.action,
    this.resourceType,
    this.resourceId,
    required this.details,
    required this.deviceInfo,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        action: json['action'] as String,
        resourceType: json['resource_type'] as String?,
        resourceId: json['resource_id'] as String?,
        details: (json['details'] as Map<String, dynamic>?) ?? {},
        deviceInfo: json['device_info'] as String? ?? '',
        createdAt: json['created_at'] as String,
      );
}

class SessionRecord {
  final String id;
  final String userId;
  final String sessionToken;
  final String deviceInfo;
  final String ipAddress;
  final String lastActiveAt;
  final String createdAt;
  final bool isCurrent;

  const SessionRecord({
    required this.id,
    required this.userId,
    required this.sessionToken,
    required this.deviceInfo,
    required this.ipAddress,
    required this.lastActiveAt,
    required this.createdAt,
    required this.isCurrent,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        sessionToken: json['session_token'] as String,
        deviceInfo: json['device_info'] as String? ?? '',
        ipAddress: json['ip_address'] as String? ?? '',
        lastActiveAt: json['last_active_at'] as String,
        createdAt: json['created_at'] as String,
        isCurrent: json['is_current'] as bool? ?? false,
      );
}
