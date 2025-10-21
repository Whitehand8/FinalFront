class VttScene {
  final int id;
  final int roomId;
  final String name;
  final int width;
  final int height;
  final bool isActive;
  final int? backgroundImageId;
  final String? backgroundUrl;
  final Map<String, dynamic> properties;

  VttScene({
    required this.id,
    required this.roomId,
    required this.name,
    required this.width,
    required this.height,
    required this.isActive,
    this.backgroundImageId,
    this.backgroundUrl,
    this.properties = const {},
  });

  factory VttScene.fromJson(Map<String, dynamic> j) {
    final bg = j['background'];
    return VttScene(
      id: j['id'],
      roomId: j['roomId'],
      name: j['name'] ?? 'Scene',
      width: j['width'] ?? 1000,
      height: j['height'] ?? 800,
      isActive: j['isActive'] ?? false,
      backgroundImageId: j['backgroundImageId'],
      backgroundUrl:
          (bg is Map && bg['url'] is String)
              ? bg['url'] as String
              : (j['backgroundUrl'] as String?), // 혹시 직접 주는 경우
      properties:
          (j['properties'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
