// lib/models/vtt_scene.dart

/// VTT 맵(씬)을 나타내는 모델
/// [수정됨] 백엔드 VttMap 엔티티/DTO에 맞게 ID 타입을 int -> String으로 변경
class VttScene {
  final String id; // [수정됨] int -> String (UUID)
  final String roomId; // [수정됨] int -> String (UUID)
  final String name;
  final int width;
  final int height;
  final bool isActive;
  
  // [제거됨] final int? backgroundImageId;
  // [수정됨] 백엔드의 'imageUrl' 필드에 해당
  final String? backgroundUrl; 

  /// 맵 설정 (그리드 유형, 크기, 색상 등)
  /// [수정됨] 백엔드의 gridType, gridSize 등을 이 Map으로 통합 관리
  final Map<String, dynamic> properties;

  VttScene({
    required this.id,
    required this.roomId,
    required this.name,
    required this.width,
    required this.height,
    required this.isActive,
    this.backgroundUrl,
    this.properties = const {},
  });

  /// 백엔드 JSON (VttMapDto, VttMapResponseDto 등)을 VttScene 객체로 변환
  factory VttScene.fromJson(Map<String, dynamic> j) {
    
    // [수정됨] 백엔드의 VttMapDto/VttMapEntity의 설정값들을 props로 병합
    final props = (j['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    if (j['gridType'] != null) props['gridType'] = j['gridType'];
    if (j['gridSize'] != null) props['gridSize'] = j['gridSize'];
    if (j['gridColor'] != null) props['gridColor'] = j['gridColor'];
    if (j['gridOpacity'] != null) props['gridOpacity'] = j['gridOpacity'];

    return VttScene(
      // [수정됨] id/roomId를 String으로 파싱
      id: j['id'] as String? ?? '',
      roomId: j['roomId'] as String? ?? '',
      
      name: j['name'] as String? ?? 'Scene',
      width: (j['width'] as num?)?.toInt() ?? 1000,
      height: (j['height'] as num?)?.toInt() ?? 800,
      isActive: j['isActive'] as bool? ?? false,

      // [수정됨] 백엔드는 'imageUrl' 필드를 사용
      backgroundUrl: j['imageUrl'] as String?,
      
      properties: props, // [수정됨] 병합된 설정
    );
  }

  /// 객체를 JSON으로 변환 (주로 UpdateVttMapDto 형식으로 사용)
  /// [API] PATCH /vttmaps/:mapId
  Map<String, dynamic> toUpdateJson() {
    // 백엔드 UpdateVttMapDto는 name, gridType, gridSize, gridColor, gridOpacity, imageUrl을 받음
    return {
      'name': name,
      'imageUrl': backgroundUrl,
      // properties 맵의 값들을 DTO에 맞게 최상위 레벨로 추출
      'gridType': properties['gridType'],
      'gridSize': properties['gridSize'],
      'gridColor': properties['gridColor'],
      'gridOpacity': properties['gridOpacity'],
    };
  }

  /// 새 맵 생성(CreateVttMapDto)을 위한 JSON
  /// [API] POST /rooms/:roomId/vttmaps
  Map<String, dynamic> toCreateJson() {
    // 백엔드 CreateVttMapDto는 name, width, height, gridType, gridSize, gridColor, gridOpacity를 받음
    return {
      'name': name,
      'width': width,
      'height': height,
      'imageUrl': backgroundUrl, // imageUrl도 생성 시 포함 가능
      // properties 맵의 값들을 DTO에 맞게 최상위 레벨로 추출
      'gridType': properties['gridType'] ?? 'SQUARE', // 기본값 제공
      'gridSize': properties['gridSize'] ?? 50,
      'gridColor': properties['gridColor'] ?? '#000000',
      'gridOpacity': properties['gridOpacity'] ?? 0.5,
    };
    // roomId는 VttService의 API 경로로 전달됨
  }
}