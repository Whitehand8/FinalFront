// lib/models/user.dart
class User {
  final String name, nickname, email, role;
  User(
      {required this.name,
      required this.nickname,
      required this.email,
      required this.role});
  factory User.fromJson(Map<String, dynamic> json) => User(
        name: json['name'],
        nickname: json['nickname'],
        email: json['email'],
        role: json['role'],
      );
}
