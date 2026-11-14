/// Authentication domain entities and DTOs

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final String userId;
  final String email;
  final String clientSalt;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.userId,
    required this.email,
    required this.clientSalt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      userId: json['user_id'] as String,
      email: json['email'] as String,
      clientSalt: json['client_salt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'user_id': userId,
        'email': email,
        'client_salt': clientSalt,
      };
}

class UserProfile {
  final String id;
  final String email;
  final String clientSalt;
  final String planTier;

  UserProfile({
    required this.id,
    required this.email,
    required this.clientSalt,
    required this.planTier,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      clientSalt: json['client_salt'] as String,
      planTier: json['plan_tier'] as String? ?? 'FREE',
    );
  }
}

