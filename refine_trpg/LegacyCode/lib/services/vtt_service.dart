import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/vtt_scene.dart';
import '../models/marker.dart';

class VttApi {
  final String base; // 예: http://localhost:4000
  final Map<String, String> _headers;
  VttApi(this.base, {Map<String, String>? headers})
    : _headers = {'Content-Type': 'application/json', ...?headers};

  // --- Scenes ---
  Future<List<VttScene>> getScenesByRoom(int roomId) async {
    final r = await http.get(Uri.parse('$base/api/vtt/scenes/room/$roomId'));
    final a = (jsonDecode(r.body) as List);
    return a.map((e) => VttScene.fromJson(e)).toList();
  }

  Future<VttScene> getScene(int id) async {
    final r = await http.get(Uri.parse('$base/api/vtt/scenes/$id'));
    return VttScene.fromJson(jsonDecode(r.body));
  }

  Future<void> activateScene(int sceneId, int roomId) async {
    await http.patch(
      Uri.parse('$base/api/vtt/scenes/$sceneId/activate/$roomId'),
    );
  }

  // --- Markers ---
  Future<List<Marker>> getMarkersByScene(int sceneId) async {
    final r = await http.get(
      Uri.parse('$base/api/vtt/markers/by-scene/$sceneId'),
    );
    final a = (jsonDecode(r.body) as List);
    return a.map((e) => Marker.fromJson(e)).toList();
  }

  Future<Marker> createMarker(Marker m) async {
    final r = await http.post(
      Uri.parse('$base/api/vtt/markers'),
      headers: _headers,
      body: jsonEncode(m.toJson()),
    );
    return Marker.fromJson(jsonDecode(r.body));
  }

  Future<Marker> updateMarkerPosition(
    int id, {
    required double x,
    required double y,
    double? rotation,
  }) async {
    final r = await http.patch(
      Uri.parse('$base/api/vtt/markers/$id/position'),
      headers: _headers,
      body: jsonEncode({
        'x': x,
        'y': y,
        if (rotation != null) 'rotation': rotation,
      }),
    );
    return Marker.fromJson(jsonDecode(r.body));
  }

  Future<Marker> updateMarker(int id, Map<String, dynamic> dto) async {
    final r = await http.patch(
      Uri.parse('$base/api/vtt/markers/$id'),
      headers: _headers,
      body: jsonEncode(dto),
    );
    return Marker.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteMarker(int id) async {
    await http.delete(Uri.parse('$base/api/vtt/markers/$id'));
  }

  // --- Upload (선택) ---
  Future<Map<String, dynamic>> uploadImage(
    File f, {
    int? userId,
    String? role,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/vtt/uploads/image'),
    );
    req.fields.addAll({
      if (userId != null) 'userId': '$userId',
      if (role != null) 'role': role,
    });
    req.files.add(await http.MultipartFile.fromPath('file', f.path));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
