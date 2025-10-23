import 'package:flutter/foundation.dart'; // For debugPrint

class Marker {
  final int id; // Marker ID (Primary Key)
  final String name;
  double x, y; // Position (mutable)
  double rotation; // Rotation (mutable)
  int width, height; // Size (mutable)
  int zIndex; // Stacking order (mutable)
  final int sceneId; // Foreign key referencing VttScene.id
  final int? imageId; // Optional foreign key for a specific image asset
  final String? imageUrl; // Optional URL for the marker image
  Map<String, dynamic> stats; // Mutable stats map
  Map<String, dynamic> properties; // Mutable properties map

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
    // Use const {} for default empty maps
    this.stats = const {},
    this.properties = const {},
  });

  factory Marker.fromJson(Map<String, dynamic> j) {
    // Helper to safely parse int, returns null if parsing fails or input is null
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      // Try double conversion for robustness (e.g., 100.0 from JSON)
      if (value is double) return value.toInt();
      return null;
    }

     // Helper to safely parse double
    double? _parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }


    // Safely parse background URL from nested object or direct key
    String? _parseImageUrl(dynamic imgData, dynamic directUrl) {
       if (imgData is Map && imgData['url'] is String) {
         return imgData['url'] as String;
       } else if (directUrl is String) {
         return directUrl;
       }
       return null;
    }

    // Safely parse required and optional fields
    final id = _parseInt(j['id']);
    final name = j['name'] as String? ?? 'Marker'; // Default name
    final x = _parseDouble(j['x']) ?? 0.0; // Default position
    final y = _parseDouble(j['y']) ?? 0.0; // Default position
    final rotation = _parseDouble(j['rotation']) ?? 0.0; // Default rotation
    final width = _parseInt(j['width']) ?? 50; // Default size
    final height = _parseInt(j['height']) ?? 50; // Default size
    final zIndex = _parseInt(j['zIndex']) ?? 0; // Default zIndex
    // Try parsing sceneId from direct key or nested scene object
    final sceneId = _parseInt(j['sceneId'] ?? j['scene']?['id']);
    final imageId = _parseInt(j['imageId']);
    final imageUrl = _parseImageUrl(j['image'], j['imageUrl']); // Check both nested 'image' and direct 'imageUrl'
    // Safely cast maps, defaulting to empty const map
    final stats = (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final properties = (j['properties'] as Map?)?.cast<String, dynamic>() ?? const {};


    // Validate required fields after parsing
    if (id == null) {
      throw FormatException("Invalid or missing 'id' in Marker JSON: $j");
    }
    if (sceneId == null) {
      // Log the problematic JSON for easier debugging
      debugPrint("Problematic Marker JSON for sceneId: $j");
      throw FormatException("Invalid or missing 'sceneId' in Marker JSON: $j");
    }


    return Marker(
      id: id,
      name: name,
      x: x,
      y: y,
      rotation: rotation,
      width: width,
      height: height,
      zIndex: zIndex,
      sceneId: sceneId,
      imageId: imageId,
      imageUrl: imageUrl,
      stats: Map<String, dynamic>.from(stats), // Create mutable copies
      properties: Map<String, dynamic>.from(properties), // Create mutable copies
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
        'imageId': imageId, // Will be null if not set
        'imageUrl': imageUrl, // Will be null if not set
        'stats': stats,
        'properties': properties,
      };

   // copyWith method for creating modified copies
   Marker copyWith({
    int? id,
    String? name,
    double? x,
    double? y,
    double? rotation,
    int? width,
    int? height,
    int? zIndex,
    int? sceneId,
    int? imageId,
    String? imageUrl,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? properties,
  }) {
    return Marker(
      id: id ?? this.id,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      width: width ?? this.width,
      height: height ?? this.height,
      zIndex: zIndex ?? this.zIndex,
      sceneId: sceneId ?? this.sceneId,
      imageId: imageId ?? this.imageId,
      imageUrl: imageUrl ?? this.imageUrl,
      // Ensure the maps are copied if new ones aren't provided
      stats: stats ?? Map<String, dynamic>.from(this.stats),
      properties: properties ?? Map<String, dynamic>.from(this.properties),
    );
  }

}
