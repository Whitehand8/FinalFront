class Participant {
  final String userId;
  final String nickname;
  final String role;

  Participant({
    required this.userId,
    required this.nickname,
    required this.role,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      // 👇 이 부분을 수정했습니다: 'user_id'가 없으면 'id'를 사용하도록 변경
      userId: (json['user_id'] ?? json['id'])?.toString() ?? '',
      nickname: json['nickname'] ?? 'Unknown',
      role: json['role'] ?? 'PLAYER',
    );
  }
}
