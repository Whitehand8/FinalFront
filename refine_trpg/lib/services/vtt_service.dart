import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/vtt_scene.dart';
import '../models/marker.dart';

/// VTT REST 서비스
/// - Scenes: 조회/활성화 + [gridSize, showGrid] 설정 지원
/// - Markers: 목록/생성/위치 업데이트(옵션: 그리드 스냅) / 삭제
/// - Upload: 이미지 업로드(멀티파트)
class VttService {
  final String base; // 예: http://localhost:4000
  final Map<String, String> _headers;
  VttService(this.base, {Map<String, String>? headers})
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

  /// [NEW] 씬 메타데이터 갱신 (gridSize, showGrid 등)
  Future<VttScene> updateScene(int id, Map<String, dynamic> dto) async {
    final r = await http.patch(
      Uri.parse('$base/api/vtt/scenes/$id'),
      headers: _headers,
      body: jsonEncode(dto),
    );
    return VttScene.fromJson(jsonDecode(r.body));
  }

  /// [NEW] 그리드 간격 설정
  Future<VttScene> setGridSize(int sceneId, double gridSize) {
    return updateScene(sceneId, {'gridSize': gridSize});
  }

  /// [NEW] 그리드 표시 토글
  Future<VttScene> setShowGrid(int sceneId, bool show) {
    return updateScene(sceneId, {'showGrid': show});
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

  /// 마커 위치 업데이트
  /// - [snapToGrid]=true 이고 [gridSize]>0 일 때, x/y를 가장 가까운 그리드에 스냅합니다.
  Future<Marker> updateMarkerPosition(
    int id, {
    required double x,
    required double y,
    double? rotation,
    bool snapToGrid = false,
    double? gridSize,
  }) async {
    double nx = x;
    double ny = y;

    if (snapToGrid) {
      final gs = (gridSize ?? 0);
      if (gs > 0) {
        nx = (nx / gs).roundToDouble() * gs;
        ny = (ny / gs).roundToDouble() * gs;
      }
    }

    final r = await http.patch(
      Uri.parse('$base/api/vtt/markers/$id/position'),
      headers: _headers,
      body: jsonEncode({
        'x': nx,
        'y': ny,
        if (rotation != null) 'rotation': rotation,
      }),
    );
    return Marker.fromJson(jsonDecode(r.body));
  }

  /// [NEW] 씬의 gridSize를 조회해 스냅 적용 후 위치 업데이트
  Future<Marker> updateMarkerPositionWithSceneSnap(
    int id, {
    required double x,
    required double y,
    required int sceneId,
    double? rotation,
  }) async {
    final scene = await getScene(sceneId);
    // VttScene 모델에 gridSize가 있다고 가정. 없을 경우 0 처리.
    final dynamic raw = (scene as dynamic).gridSize;
    final double gs = (raw is num) ? raw.toDouble() : 0.0;
    return updateMarkerPosition(
      id,
      x: x,
      y: y,
      rotation: rotation,
      snapToGrid: gs > 0,
      gridSize: gs,
    );
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
