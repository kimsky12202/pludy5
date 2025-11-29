class User {
  final int id;
  final String username;
  final String email;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AuthToken {
  final String token;
  final int userId;
  final String username;
  final String email;

  const AuthToken({
    required this.token,
    required this.userId,
    required this.username,
    required this.email,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      token: json['token'] as String,
      userId: json['user_id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
    );
  }
}
