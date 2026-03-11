class UserFile {
  final String id;
  final String userId;
  final String? folderId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String storagePath;
  final String? shareId;
  final String? shareExpiresAt;
  final String? sharePasswordHash;
  final int position;
  final String createdAt;
  final String updatedAt;

  const UserFile({
    required this.id,
    required this.userId,
    this.folderId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.storagePath,
    this.shareId,
    this.shareExpiresAt,
    this.sharePasswordHash,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserFile.fromJson(Map<String, dynamic> json) => UserFile(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        folderId: json['folder_id'] as String?,
        fileName: json['file_name'] as String,
        fileType: json['file_type'] as String? ?? '',
        fileSize: json['file_size'] as int? ?? 0,
        storagePath: json['storage_path'] as String,
        shareId: json['share_id'] as String?,
        shareExpiresAt: json['share_expires_at'] as String?,
        sharePasswordHash: json['share_password_hash'] as String?,
        position: json['position'] as int? ?? 0,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'folder_id': folderId,
        'file_name': fileName,
        'file_type': fileType,
        'file_size': fileSize,
        'storage_path': storagePath,
        'share_id': shareId,
        'share_expires_at': shareExpiresAt,
        'share_password_hash': sharePasswordHash,
        'position': position,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  bool get isShared => shareId != null;
  bool get hasSharePassword => sharePasswordHash != null;
}

class FileFolder {
  final String id;
  final String userId;
  final String name;
  final String? parentFolderId;
  final String color;
  final int position;
  final String createdAt;
  final String updatedAt;

  const FileFolder({
    required this.id,
    required this.userId,
    required this.name,
    this.parentFolderId,
    required this.color,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FileFolder.fromJson(Map<String, dynamic> json) => FileFolder(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        parentFolderId: json['parent_folder_id'] as String?,
        color: json['color'] as String? ?? 'blue',
        position: json['position'] as int? ?? 0,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'parent_folder_id': parentFolderId,
        'color': color,
        'position': position,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
