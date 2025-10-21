class User {
  final String username; 
  final String password;
  final String confirmPassword;
  final String email;

  User({
    required this.username,
    required this.password,
    required this.confirmPassword,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'name': username, // ← 백엔드 User.name 필드에 매핑
        'password': password,
        'confirmPassword': confirmPassword,
        'email': email
      };
}

