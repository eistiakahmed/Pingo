/// Zero-Knowledge Sync Models and Data Transfer Objects

class EncryptedReminderDto {
  final String id;
  final String ciphertext;
  final String iv;
  final String authTag;
  final int keyVersion;
  final String algorithm;
  final DateTime? dueAt;
  final bool isCompleted;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  EncryptedReminderDto({
    required this.id,
    required this.ciphertext,
    required this.iv,
    required this.authTag,
    this.keyVersion = 1,
    this.algorithm = 'AES-256-GCM',
    this.dueAt,
    this.isCompleted = false,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory EncryptedReminderDto.fromJson(Map<String, dynamic> json) {
    return EncryptedReminderDto(
      id: json['id'] as String,
      ciphertext: json['ciphertext'] as String,
      iv: json['iv'] as String,
      authTag: json['auth_tag'] as String,
      keyVersion: json['key_version'] as int? ?? 1,
      algorithm: json['algorithm'] as String? ?? 'AES-256-GCM',
      dueAt: json['due_at'] != null ? DateTime.parse(json['due_at'] as String) : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      version: json['version'] as int? ?? 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ciphertext': ciphertext,
        'iv': iv,
        'auth_tag': authTag,
        'key_version': keyVersion,
        'algorithm': algorithm,
        'due_at': dueAt?.toIso8601String(),
        'is_completed': isCompleted,
        'version': version,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

class EncryptedVaultDto {
  final String id;
  final String itemType;
  final String ciphertext;
  final String iv;
  final String authTag;
  final int keyVersion;
  final String algorithm;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  EncryptedVaultDto({
    required this.id,
    required this.itemType,
    required this.ciphertext,
    required this.iv,
    required this.authTag,
    this.keyVersion = 1,
    this.algorithm = 'AES-256-GCM',
    this.version = 1,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory EncryptedVaultDto.fromJson(Map<String, dynamic> json) {
    return EncryptedVaultDto(
      id: json['id'] as String,
      itemType: json['item_type'] as String,
      ciphertext: json['ciphertext'] as String,
      iv: json['iv'] as String,
      authTag: json['auth_tag'] as String,
      keyVersion: json['key_version'] as int? ?? 1,
      algorithm: json['algorithm'] as String? ?? 'AES-256-GCM',
      version: json['version'] as int? ?? 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_type': itemType,
        'ciphertext': ciphertext,
        'iv': iv,
        'auth_tag': authTag,
        'key_version': keyVersion,
        'algorithm': algorithm,
        'version': version,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

class SyncPushResponse {
  final bool success;
  final int appliedCount;
  final DateTime serverTimestamp;

  SyncPushResponse({
    required this.success,
    required this.appliedCount,
    required this.serverTimestamp,
  });

  factory SyncPushResponse.fromJson(Map<String, dynamic> json) {
    return SyncPushResponse(
      success: json['success'] as bool? ?? false,
      appliedCount: json['applied_count'] as int? ?? 0,
      serverTimestamp: DateTime.parse(json['server_timestamp'] as String),
    );
  }
}

class SyncPullResponse {
  final List<EncryptedReminderDto> reminders;
  final List<EncryptedVaultDto> vaultItems;
  final DateTime serverTimestamp;

  SyncPullResponse({
    required this.reminders,
    required this.vaultItems,
    required this.serverTimestamp,
  });

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) {
    return SyncPullResponse(
      reminders: (json['reminders'] as List<dynamic>? ?? [])
          .map((r) => EncryptedReminderDto.fromJson(r as Map<String, dynamic>))
          .toList(),
      vaultItems: (json['vault_items'] as List<dynamic>? ?? [])
          .map((v) => EncryptedVaultDto.fromJson(v as Map<String, dynamic>))
          .toList(),
      serverTimestamp: DateTime.parse(json['server_timestamp'] as String),
    );
  }
}

