class Profile {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isAdmin;
  final String createdAt;

  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isAdmin,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        isAdmin: json['is_admin'] as bool? ?? false,
        createdAt: json['created_at'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_admin': isAdmin,
        'created_at': createdAt,
      };

  Profile copyWith({String? displayName, String? avatarUrl}) => Profile(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isAdmin: isAdmin,
        createdAt: createdAt,
      );
}
