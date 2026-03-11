class Folder {
  final String id;
  final String userId;
  final String name;
  final String? color;
  final String createdAt;
  final String updatedAt;

  const Folder({
    required this.id,
    required this.userId,
    required this.name,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        color: json['color'] as String?,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'color': color,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Folder copyWith({String? name, String? color}) => Folder(
        id: id,
        userId: userId,
        name: name ?? this.name,
        color: color ?? this.color,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
