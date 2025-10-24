// lib/models/vtt_map.dart (원래 vtt_scene.dart)

import 'package:flutter/foundation.dart';

/// 백엔드의 GridType enum (common/enums/grid-type.enum.ts)
enum GridType {
  SQUARE,
  HEX_H, // Hexagonal (Horizontal)
  HEX_V, // Hexagonal (Vertical)
}

/// GridType enum <-> String 변환
GridType gridTypeFromString(String? type) {
  switch (type) {
    case 'SQUARE':
      return GridType.SQUARE;
    case 'HEX_H':
      return GridType.HEX_H;
    case 'HEX_V':
      return GridType.HEX_V;
    default:
      debugPrint('Warning: Unknown GridType "$type", defaulting to SQUARE.');
      return GridType.SQUARE;
  }
}

String _gridTypeToString(GridType type) {
  return type.toString().split('.').last; // 'GridType.SQUARE' -> 'SQUARE'
}

/// 백엔드의 VttMap 엔티티/DTO에 대응하는 모델
class VttMap {
  final String id; // UUID (String)
  final String roomId; // VttMap이 속한 방 ID
  final String name;
  final String? imageUrl; // 맵 배경 이미지 URL
  final GridType gridType;
  final int gridSize;
  final bool showGrid;
  final DateTime updatedAt;

  VttMap({
    required this.id,
    required this.roomId,
    required this.name,
    this.imageUrl,
    this.gridType = GridType.SQUARE,
    this.gridSize = 50,
    this.showGrid = true,
    required this.updatedAt,
  });

  /// 백엔드 REST API 또는 WebSocket('joinedMap' 이벤트의 'map' 객체)의
  /// JSON 응답을 VttMap 객체로 변환합니다.
  factory VttMap.fromJson(Map<String, dynamic> j) {
    // roomId는 vttmap.entity.ts 에는 있지만
    // vtt.gateway.ts의 'joinedMap' 이벤트 응답에는 map 객체 밖에 mapId와 함께 별도로 제공될 수 있습니다.
    // REST API (GET /vttmaps) 응답에는 roomId가 포함되어야 합니다.
    // 여기서는 JSON에 roomId가 있다고 가정합니다. (vttmap.entity.ts 기준)
    final roomId = j['roomId']?.toString();
    final id = j['id']?.toString();

    if (id == null) {
      throw FormatException("Invalid or missing 'id' in VttMap JSON: $j");
    }
    if (roomId == null) {
       debugPrint("Warning: 'roomId' is missing in VttMap JSON: $j");
       // roomId가 필수인 경우 아래 주석을 해제하세요.
       // throw FormatException("Invalid or missing 'roomId' in VttMap JSON: $j");
    }

    DateTime parsedUpdatedAt;
    try {
      parsedUpdatedAt = DateTime.parse(j['updatedAt'] as String);
    } catch (e) {
      debugPrint('Error parsing updatedAt: ${j['updatedAt']} - $e');
      parsedUpdatedAt = DateTime.now(); // Fallback
    }

    return VttMap(
      id: id,
      // roomId가 JSON에 없다면, VttMap을 생성하는 외부(예: VttProvider)에서 주입해야 할 수 있습니다.
      roomId: roomId ?? '', // 임시로 빈 문자열 처리
      name: j['name'] as String? ?? 'Unnamed Map',
      imageUrl: j['imageUrl'] as String?,
      gridType: gridTypeFromString(j['gridType'] as String?),
      // gridSize 파싱 (int 또는 double로 올 수 있음)
      gridSize: (j['gridSize'] as num?)?.toInt() ?? 50,
      showGrid: j['showGrid'] as bool? ?? true,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// VttMap 객체를 JSON으로 변환합니다. (주로 생성/수정 요청 시 사용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'name': name,
      'imageUrl': imageUrl,
      'gridType': _gridTypeToString(gridType),
      'gridSize': gridSize,
      'showGrid': showGrid,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 객체 복사를 위한 copyWith 메서드
  VttMap copyWith({
    String? id,
    String? roomId,
    String? name,
    String? imageUrl,
    GridType? gridType,
    int? gridSize,
    bool? showGrid,
    DateTime? updatedAt,
  }) {
    return VttMap(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      gridType: gridType ?? this.gridType,
      gridSize: gridSize ?? this.gridSize,
      showGrid: showGrid ?? this.showGrid,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}