class VttScene {
  final int id; // Scene ID remains int as used in services
  final String roomId; // Changed roomId to String
  final String name;
  final int width;
  final int height;
  final bool isActive;
  final int? backgroundImageId;
  final String? backgroundUrl;
  final Map<String, dynamic> properties;

  VttScene({
    required this.id,
    required this.roomId, // Changed to String
    required this.name,
    required this.width,
    required this.height,
    required this.isActive,
    this.backgroundImageId,
    this.backgroundUrl,
    this.properties = const {},
  });

  factory VttScene.fromJson(Map<String, dynamic> j) {
    // Helper to safely parse int, returns null if parsing fails or input is null
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Safely parse background URL from nested object or direct key
    String? _parseBackgroundUrl(dynamic bgData, dynamic directUrl) {
       if (bgData is Map && bgData['url'] is String) {
         return bgData['url'] as String;
       } else if (directUrl is String) {
         return directUrl;
       }
       return null;
    }


    // Safely parse required fields with fallbacks
    final id = _parseInt(j['id']);
    final roomId = j['roomId']?.toString(); // Safely convert roomId to String
    final name = j['name'] as String? ?? 'Scene';
    final width = _parseInt(j['width']) ?? 1000; // Default width
    final height = _parseInt(j['height']) ?? 800; // Default height
    final isActive = j['isActive'] as bool? ?? false;
    final backgroundImageId = _parseInt(j['backgroundImageId']);
    final backgroundUrl = _parseBackgroundUrl(j['background'], j['backgroundUrl']);
    final properties = (j['properties'] as Map?)?.cast<String, dynamic>() ?? const {};

    // Check if essential fields are valid after parsing
    if (id == null) {
      throw FormatException("Invalid or missing 'id' in VttScene JSON: $j");
    }
     if (roomId == null) {
      throw FormatException("Invalid or missing 'roomId' in VttScene JSON: $j");
    }


    return VttScene(
      id: id,
      roomId: roomId,
      name: name,
      width: width,
      height: height,
      isActive: isActive,
      backgroundImageId: backgroundImageId,
      backgroundUrl: backgroundUrl,
      properties: properties,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId, // Ensure roomId is output as String
      'name': name,
      'width': width,
      'height': height,
      'isActive': isActive,
      'backgroundImageId': backgroundImageId,
      'backgroundUrl': backgroundUrl,
      'properties': properties,
    };
  }

  // Optional: Add copyWith method for easier updates
  VttScene copyWith({
    int? id,
    String? roomId,
    String? name,
    int? width,
    int? height,
    bool? isActive,
    int? backgroundImageId,
    String? backgroundUrl,
    Map<String, dynamic>? properties,
  }) {
    return VttScene(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      width: width ?? this.width,
      height: height ?? this.height,
      isActive: isActive ?? this.isActive,
      backgroundImageId: backgroundImageId ?? this.backgroundImageId,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      properties: properties ?? this.properties,
    );
  }
}
