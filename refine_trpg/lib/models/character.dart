class Character {
  final String id;
  final String ownerId;
  final String roomId;
  final String systemId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> derived;

  Character({
    required this.id,
    required this.ownerId,
    required this.roomId,
    required this.systemId,
    required this.data,
    required this.derived,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['_id'],
      ownerId: json['ownerId'],
      roomId: json['roomId'],
      systemId: json['systemId'],
      data: json['data'] as Map<String, dynamic>,
      derived: json['derived'] as Map<String, dynamic>,
    );
  }
}
