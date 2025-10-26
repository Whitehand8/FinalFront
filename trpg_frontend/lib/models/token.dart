// lib/models/Token.dart (원래 Token.dart)

import 'package:flutter/foundation.dart'; // For debugPrint

/// 백엔드의 Token 엔티티/DTO에 대응하는 모델
class Token {
  final String id; // Token ID (UUID)
  final String mapId; // VttMap ID (UUID)

  // 연결된 시트 또는 NPC (둘 중 하나만 값을 가짐)
  // [수정됨] 백엔드(Token.entity.ts)의 'characterSheetId: number?'와 일치
  final int? characterSheetId;
  final int? npcId; // Npc ID (number)

  String name;
  double x, y; // Position (mutable)
  String? imageUrl; // Token image
  bool isVisible; // 토큰 표시 여부
  final bool canMove; // 현재 사용자가 이 토큰을 움직일 수 있는지 여부

  Token({
    required this.id,
    required this.mapId,
    this.characterSheetId, // [수정됨]
    this.npcId,
    required this.name,
    required this.x,
    required this.y,
    this.imageUrl,
    this.isVisible = true,
    this.canMove = false, // 기본값은 false, 'joinedMap'에서 실제 값으로 덮어씀
  });

  /// 백엔드 REST API 또는 WebSocket('joinedMap' 이벤트의 'Tokens' 배열)의
  /// JSON 응답을 Token 객체로 변환합니다.
  factory Token.fromJson(Map<String, dynamic> j) {
    // Helper to safely parse double
    double _parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper to safely parse int, returns null if parsing fails or input is null
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      return null;
    }

    // Safely parse required fields
    final id = j['id']?.toString();
    final mapId = j['mapId']?.toString();
    final name = j['name'] as String? ?? 'Token'; // Default name
    final x = _parseDouble(j['x']);
    final y = _parseDouble(j['y']);

    // Validate required fields
    if (id == null) {
      throw FormatException("Invalid or missing 'id' in Token JSON: $j");
    }
    if (mapId == null) {
      debugPrint("Problematic Token JSON for mapId: $j");
      throw FormatException("Invalid or missing 'mapId' in Token JSON: $j");
    }

    return Token(
      id: id,
      mapId: mapId,
      // [수정됨] 'characterSheetId' 키에서 int? 타입으로 파싱
      characterSheetId: _parseInt(j['characterSheetId']),
      npcId: _parseInt(j['npcId']), // Nullable int
      name: name,
      x: x,
      y: y,
      imageUrl: j['imageUrl'] as String?,
      isVisible: j['isVisible'] as bool? ?? true, // Default to true
      // canMove는 백엔드 DTO에 따라 다름. 여기서는 'joinedMap' 응답에 포함된 것을 가정
      canMove: j['canMove'] as bool? ?? false,
    );
  }

  /// Token 객체를 JSON으로 변환합니다. (주로 생성 요청 시 사용)
  /// 참고: 백엔드의 CreateTokenDto는 다른 구조를 가질 수 있습니다.
  Map<String, dynamic> toJson() => {
        'id': id,
        'mapId': mapId,
        'characterSheetId': characterSheetId, // [수정됨]
        'npcId': npcId,
        'name': name,
        'x': x,
        'y': y,
        'imageUrl': imageUrl,
        'isVisible': isVisible,
        'canMove': canMove,
      };

  /// 객체 복사를 위한 copyWith 메서드
  Token copyWith({
    String? id,
    String? mapId,
    int? characterSheetId, // [수정됨]
    int? npcId,
    String? name,
    double? x,
    double? y,
    String? imageUrl,
    bool? isVisible,
    bool? canMove,
  }) {
    return Token(
      id: id ?? this.id,
      mapId: mapId ?? this.mapId,
      // [수정됨]
      characterSheetId: characterSheetId ?? this.characterSheetId,
      npcId: npcId ?? this.npcId,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      imageUrl: imageUrl ?? this.imageUrl,
      isVisible: isVisible ?? this.isVisible,
      canMove: canMove ?? this.canMove,
    );
  }
}