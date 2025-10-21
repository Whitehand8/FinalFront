class Marker {
  final int id;
  final String name;
  double x, y;
  double rotation;
  int width, height;
  int zIndex;
  final int sceneId;
  final int? imageId;
  final String? imageUrl;
  Map<String, dynamic> stats;
  Map<String, dynamic> properties;

  Marker({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.rotation,
    required this.width,
    required this.height,
    required this.zIndex,
    required this.sceneId,
    this.imageId,
    this.imageUrl,
    this.stats = const {},
    this.properties = const {},
  });

  factory Marker.fromJson(Map<String, dynamic> j) {
    final img = j['image'];
    return Marker(
      id: j['id'],
      name: j['name'] ?? 'Marker',
      x: (j['x'] ?? 0).toDouble(),
      y: (j['y'] ?? 0).toDouble(),
      rotation: (j['rotation'] ?? 0).toDouble(),
      width: j['width'] ?? 100,
      height: j['height'] ?? 100,
      zIndex: j['zIndex'] ?? 0,
      sceneId: j['sceneId'] ?? (j['scene']?['id']),
      imageId: j['imageId'],
      imageUrl: (img is Map && img['url'] is String)
          ? img['url'] as String
          : j['imageUrl'],
      stats: (j['stats'] as Map?)?.cast<String, dynamic>() ?? {},
      properties: (j['properties'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'rotation': rotation,
        'width': width,
        'height': height,
        'zIndex': zIndex,
        'sceneId': sceneId,
        'imageId': imageId,
        'stats': stats,
        'properties': properties,
      };
}
