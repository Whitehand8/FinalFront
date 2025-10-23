import 'dart:convert';
import 'dart:io'; // Note: dart:io File won't work directly on web
import 'dart:async'; // For TimeoutException
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import '../models/vtt_scene.dart';
import '../models/marker.dart';
import 'auth_service.dart'; // Import AuthService for token handling

// Custom exception for VTT service errors
class VttServiceException implements Exception {
  final String message;
  final int? statusCode;

  VttServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'VttServiceException: $message (code: $statusCode)';
}

class VttService {
  // Use the same base URL as other services for consistency
  static const String _baseUrl = 'http://localhost:1122'; // Updated base URL

  // Helper to get headers, including Authorization token
  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = await AuthService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
         debugPrint("VTT Service: Auth token is null, proceeding without Authorization header.");
         // Depending on API requirements, you might want to throw an error here
         // throw VttServiceException("Authentication required, but token is missing.");
      }
    }
    return headers;
  }

  // Helper to handle HTTP responses and errors
  static dynamic _handleResponse(http.Response response) {
    final int statusCode = response.statusCode;
    debugPrint("VTT Service Response: $statusCode");
    // debugPrint("Body: ${response.body}"); // Uncomment for detailed body logging

    if (statusCode >= 200 && statusCode < 300) {
      // Handle successful responses (200 OK, 201 Created, 204 No Content)
       if (response.body.isEmpty) {
         return null; // For 204 No Content or empty responses
       }
       try {
          return jsonDecode(response.body);
       } catch (e) {
          debugPrint("VTT Service: Error decoding JSON response body: $e");
          throw VttServiceException("서버 응답 처리 중 오류 발생 (JSON Decode Error)", statusCode: statusCode);
       }
    } else {
      // Handle error responses
      String errorMessage = "알 수 없는 오류 발생";
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          errorMessage = decoded['message'] ?? decoded['error'] ?? errorMessage;
        } else if (decoded is String) {
           errorMessage = decoded;
        }
      } catch (e) {
         // If decoding fails, use the raw body or a default message
         errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
         debugPrint("VTT Service: Error decoding error response body: $e");
      }
       debugPrint("VTT Service Error: $statusCode - $errorMessage");
      throw VttServiceException(errorMessage, statusCode: statusCode);
    }
  }

  // Helper for making requests with timeout and error catching
  static Future<http.Response> _makeRequest(
      Future<http.Response> Function() requestFunc) async {
    try {
      // Added timeout for network requests
      return await requestFunc().timeout(const Duration(seconds: 15));
    } on TimeoutException {
       debugPrint("VTT Service: Request timed out.");
      throw VttServiceException("서버 응답 시간이 초과되었습니다.");
    } on SocketException {
       debugPrint("VTT Service: SocketException (Network error).");
      throw VttServiceException("네트워크 연결을 확인해주세요.");
    } on http.ClientException catch (e) {
       debugPrint("VTT Service: ClientException: $e");
       throw VttServiceException("네트워크 요청 중 오류 발생: $e");
    } catch (e) {
       // Catch other potential errors during the request process
       debugPrint("VTT Service: Unexpected error during request: $e");
       throw VttServiceException("요청 처리 중 예상치 못한 오류 발생: ${e.toString()}");
    }
  }


  // --- Scenes API ---
  // Note: Assuming API paths are correct as per the original file. Adjust if needed.
  // Note: Changed ID types from int to String for consistency with RoomService/AuthService if needed. Adjust based on backend.
  // Assuming IDs remain integers based on original code for now.

  static Future<List<VttScene>> getScenesByRoom(int roomId) async { // Make static
    final uri = Uri.parse('$_baseUrl/api/vtt/scenes/room/$roomId'); // Original path kept
    debugPrint("VTT Service: GET $uri");
    final headers = await _getHeaders(); // Get headers beforehand
    final response = await _makeRequest(() => http.get(uri, headers: headers)); // Pass headers to the call
    final List<dynamic> jsonList = _handleResponse(response);
    try {
       return jsonList.map((e) => VttScene.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
       debugPrint("VTT Service Error (getScenesByRoom): Error parsing scene list: $e");
       throw VttServiceException("씬 목록 데이터를 파싱하는 중 오류 발생");
    }
  }

  static Future<VttScene> getScene(int id) async { // Make static
    final uri = Uri.parse('$_baseUrl/api/vtt/scenes/$id'); // Original path kept
    debugPrint("VTT Service: GET $uri");
    final headers = await _getHeaders(); // Get headers beforehand
    final response = await _makeRequest(() => http.get(uri, headers: headers)); // Pass headers
     final dynamic jsonResponse = _handleResponse(response);
    try {
        if (jsonResponse is Map<String, dynamic>){
          return VttScene.fromJson(jsonResponse);
        } else {
           throw VttServiceException("잘못된 씬 데이터 형식 수신");
        }
    } catch (e) {
        debugPrint("VTT Service Error (getScene): Error parsing scene: $e");
        throw VttServiceException("씬 데이터를 파싱하는 중 오류 발생");
    }
  }

  static Future<void> activateScene(int sceneId, int roomId) async { // Make static
    // Note: This endpoint seems unusual (PATCH with IDs in URL path). Verify with backend.
    final uri = Uri.parse('$_baseUrl/api/vtt/scenes/$sceneId/activate/$roomId'); // Original path kept
    debugPrint("VTT Service: PATCH $uri");
    final headers = await _getHeaders(); // Get headers beforehand
    final response = await _makeRequest(() => http.patch(uri, headers: headers)); // Pass headers
    _handleResponse(response); // Throws exception on error, returns null/void on success (e.g., 204)
  }

  // --- Markers API ---

  static Future<List<Marker>> getMarkersByScene(int sceneId) async { // Make static
    final uri = Uri.parse('$_baseUrl/api/vtt/markers/by-scene/$sceneId'); // Original path kept
    debugPrint("VTT Service: GET $uri");
    final headers = await _getHeaders(); // Get headers beforehand
    final response = await _makeRequest(() => http.get(uri, headers: headers)); // Pass headers
    final List<dynamic> jsonList = _handleResponse(response);
     try {
        return jsonList.map((e) => Marker.fromJson(e as Map<String, dynamic>)).toList();
     } catch (e) {
        debugPrint("VTT Service Error (getMarkersByScene): Error parsing marker list: $e");
        throw VttServiceException("마커 목록 데이터를 파싱하는 중 오류 발생");
     }
  }

  static Future<Marker> createMarker(Marker marker) async { // Make static
    final uri = Uri.parse('$_baseUrl/api/vtt/markers'); // Original path kept
    final body = jsonEncode(marker.toJson());
    debugPrint("VTT Service: POST $uri with body $body");
    final headers = await _getHeaders(); // Get headers beforehand
    final response = await _makeRequest(() => http.post(uri, headers: headers, body: body)); // Pass headers
    final dynamic jsonResponse = _handleResponse(response);
     try {
       if (jsonResponse is Map<String, dynamic>){
         return Marker.fromJson(jsonResponse);
       } else {
          throw VttServiceException("잘못된 마커 데이터 형식 수신");
       }
     } catch (e) {
        debugPrint("VTT Service Error (createMarker): Error parsing marker: $e");
        throw VttServiceException("마커 생성 응답 데이터를 파싱하는 중 오류 발생");
     }
  }

  static Future<Marker> updateMarkerPosition({ // Make static
    required int id,
    required double x,
    required double y,
    double? rotation,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/vtt/markers/$id/position'); // Original path kept
    final Map<String, dynamic> bodyMap = {'x': x, 'y': y};
    if (rotation != null) {
      bodyMap['rotation'] = rotation;
    }
    final body = jsonEncode(bodyMap);
    debugPrint("VTT Service: PATCH $uri with body $body");
    final headers = await _getHeaders(); // Get headers beforehand
    final response = await _makeRequest(() => http.patch(uri, headers: headers, body: body)); // Pass headers
     final dynamic jsonResponse = _handleResponse(response);
    try {
      if (jsonResponse is Map<String, dynamic>){
        return Marker.fromJson(jsonResponse);
      } else {
         throw VttServiceException("잘못된 마커 데이터 형식 수신");
      }
    } catch (e) {
        debugPrint("VTT Service Error (updateMarkerPosition): Error parsing marker: $e");
        throw VttServiceException("마커 위치 업데이트 응답 데이터를 파싱하는 중 오류 발생");
    }
  }

  static Future<Marker> updateMarker(int id, Map<String, dynamic> dto) async { // Make static
    final uri = Uri.parse('$_baseUrl/api/vtt/markers/$id'); // Original path kept
    final body = jsonEncode(dto);
    debugPrint("VTT Service: PATCH $uri with body $body");
    final headers = await _getHeaders(); // Get headers beforehand
    final response = await _makeRequest(() => http.patch(uri, headers: headers, body: body)); // Pass headers
     final dynamic jsonResponse = _handleResponse(response);
     try {
       if (jsonResponse is Map<String, dynamic>){
         return Marker.fromJson(jsonResponse);
       } else {
          throw VttServiceException("잘못된 마커 데이터 형식 수신");
       }
     } catch (e) {
        debugPrint("VTT Service Error (updateMarker): Error parsing marker: $e");
        throw VttServiceException("마커 업데이트 응답 데이터를 파싱하는 중 오류 발생");
     }
  }

  static Future<void> deleteMarker(int id) async { // Make static
    final uri = Uri.parse('$_baseUrl/api/vtt/markers/$id'); // Original path kept
     debugPrint("VTT Service: DELETE $uri");
     final headers = await _getHeaders(); // Get headers beforehand
    final response = await _makeRequest(() => http.delete(uri, headers: headers)); // Pass headers
    _handleResponse(response); // Throws exception on error, returns null/void on success (e.g., 204)
  }

  // --- Upload ---
  // IMPORTANT: This uses dart:io's File and http.MultipartRequest which
  //            is NOT directly compatible with Flutter Web.
  //            For web, you'd typically use html.FileUploadInputElement
  //            and send the file bytes using http.post or similar.
  //            Consider using a cross-platform file picker package.
  static Future<Map<String, dynamic>> uploadImage( // Make static
    File imageFile, { // Changed parameter name for clarity
    String? userId, // Assuming user ID is String based on other services
    String? role,
  }) async {
     // Check if running on web and throw an error or handle differently
    if (kIsWeb) {
      throw UnsupportedError("dart:io File upload is not supported on web.");
      // Or implement web-specific upload logic here
    }

    final uri = Uri.parse('$_baseUrl/api/vtt/uploads/image'); // Original path kept
    debugPrint("VTT Service: POST $uri (Multipart Upload)");

    try {
      final request = http.MultipartRequest('POST', uri);
      final headers = await _getHeaders(); // Get headers, including auth token
      // Note: MultipartRequest headers might need Content-Type removed or handled differently
      // Depending on the http package version and backend expectations.
      // Let's keep Authorization for now.
      headers.remove('Content-Type'); // Typically removed for multipart
      request.headers.addAll(headers);


      // Add fields
      if (userId != null) request.fields['userId'] = userId;
      if (role != null) request.fields['role'] = role;

      // Add file
      request.files.add(await http.MultipartFile.fromPath(
         'file', // Field name expected by the backend
         imageFile.path,
         // You might need to specify filename and contentType depending on backend
         // filename: basename(imageFile.path),
         // contentType: MediaType('image', 'jpeg'), // Or detect mime type
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60)); // Longer timeout for uploads
      final response = await http.Response.fromStream(streamedResponse);

       // Use the same response handler, adjust Content-Type if necessary for _handleResponse
       // For multipart, the response might still be JSON
       final dynamic jsonResponse = _handleResponse(response);
       if (jsonResponse is Map<String, dynamic>){
          return jsonResponse;
       } else {
           throw VttServiceException("이미지 업로드 응답 형식이 잘못되었습니다.");
       }
    } on TimeoutException {
       debugPrint("VTT Service: Image upload timed out.");
      throw VttServiceException("이미지 업로드 시간 초과");
    } on SocketException {
      debugPrint("VTT Service: SocketException during image upload.");
      throw VttServiceException("네트워크 연결 오류로 이미지 업로드 실패");
    } on http.ClientException catch (e) {
       debugPrint("VTT Service: ClientException during image upload: $e");
       throw VttServiceException("이미지 업로드 중 네트워크 요청 오류 발생: $e");
    } catch (e) {
       debugPrint("VTT Service: Unexpected error during image upload: $e");
      // Rethrow VttServiceException, wrap others
      if (e is VttServiceException) rethrow;
      throw VttServiceException("이미지 업로드 중 예상치 못한 오류 발생: ${e.toString()}");
    }
  }
}
