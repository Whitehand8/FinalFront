import 'dart:convert';
import 'dart:io'; // dart:io의 File 객체 사용
import 'dart:async'; // For TimeoutException
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
// 수정된 모델 파일을 임포트
import 'package:refine_trpg/models/vtt_map.dart';
import 'package:refine_trpg/models/token.dart';
import 'auth_service.dart'; // Import AuthService for token handling

// Custom exception for VTT service errors
class VttServiceException implements Exception {
  final String message;
  final int? statusCode;

  VttServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'VttServiceException: $message (code: $statusCode)';
}

/// 백엔드의 Presigned URL 응답 DTO에 대응하는 헬퍼 클래스
class PresignedUrlResponse {
  final String presignedUrl;
  final String publicUrl;

  PresignedUrlResponse({required this.presignedUrl, required this.publicUrl});

  factory PresignedUrlResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResponse(
      presignedUrl: json['presignedUrl'],
      publicUrl: json['publicUrl'],
    );
  }
}

class VttService {
  // 백엔드 REST API 포트
  static const String _baseUrl = 'http://localhost:11122';

  // --- 헬퍼 함수 (기존과 동일) ---

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
        debugPrint(
            "VTT Service: Auth token is null, proceeding without Authorization header.");
        // throw VttServiceException("Authentication required, but token is missing.");
      }
    }
    return headers;
  }

  // Helper to handle HTTP responses and errors
  static dynamic _handleResponse(http.Response response) {
    final int statusCode = response.statusCode;
    debugPrint("VTT Service Response: $statusCode");
    // debugPrint("Body: ${response.body}");

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return null; // For 204 No Content
      }
      try {
        // 백엔드는 UTF-8로 응답하므로 디코딩
        return jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        debugPrint("VTT Service: Error decoding JSON response body: $e");
        throw VttServiceException("서버 응답 처리 중 오류 발생 (JSON Decode Error)",
            statusCode: statusCode);
      }
    } else {
      // Handle error responses
      String errorMessage = "알 수 없는 오류 발생";
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          errorMessage = decoded['message'] ?? decoded['error'] ?? errorMessage;
        } else if (decoded is String) {
          errorMessage = decoded;
        }
      } catch (e) {
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
      debugPrint("VTT Service: Unexpected error during request: $e");
      throw VttServiceException("요청 처리 중 예상치 못한 오류 발생: ${e.toString()}");
    }
  }

  // --- VttMap API (Scene API 대체) ---

  /// 특정 방의 모든 맵 목록 조회 (GET /vttmaps?roomId=...)
  static Future<List<VttMap>> getMapsByRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/vttmaps').replace(queryParameters: {'roomId': roomId});
    debugPrint("VTT Service: GET $uri");
    final headers = await _getHeaders();
    final response = await _makeRequest(() => http.get(uri, headers: headers));
    final List<dynamic> jsonList = _handleResponse(response);
    try {
      // 백엔드 vttmap.controller.ts의 getVttMapsByRoom은 VttMapDto[]를 반환
      return jsonList
          .map((e) => VttMap.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint(
          "VTT Service Error (getMapsByRoom): Error parsing map list: $e");
      throw VttServiceException("맵 목록 데이터를 파싱하는 중 오류 발생");
    }
  }

  /// 맵 단건 조회 (GET /vttmaps/:mapId)
  static Future<VttMap> getMap(String mapId) async {
    final uri = Uri.parse('$_baseUrl/vttmaps/$mapId');
    debugPrint("VTT Service: GET $uri");
    final headers = await _getHeaders();
    final response = await _makeRequest(() => http.get(uri, headers: headers));
    // 백엔드는 VttMapResponseDto (message + vttMap)를 반환
    final dynamic jsonResponse = _handleResponse(response)['vttMap'];
    try {
      if (jsonResponse is Map<String, dynamic>) {
        return VttMap.fromJson(jsonResponse);
      } else {
        throw VttServiceException("잘못된 맵 데이터 형식 수신");
      }
    } catch (e) {
      debugPrint("VTT Service Error (getMap): Error parsing map: $e");
      throw VttServiceException("맵 데이터를 파싱하는 중 오류 발생");
    }
  }

  /// 맵 생성 (POST /vttmaps/rooms/:roomId/vttmaps)
  /// createDto는 백엔드의 CreateVttMapDto와 일치해야 함
  /// { "name": String, "gridType": String, "gridSize": int, "showGrid": bool, "imageUrl": String? }
  static Future<VttMap> createMap(String roomId, Map<String, dynamic> createDto) async {
    final uri = Uri.parse('$_baseUrl/vttmaps/rooms/$roomId/vttmaps');
    final body = jsonEncode(createDto);
    debugPrint("VTT Service: POST $uri with body $body");
    final headers = await _getHeaders();
    final response = await _makeRequest(() => http.post(uri, headers: headers, body: body));
    // 백엔드는 VttMapResponseDto (message + vttMap)를 반환
    final dynamic jsonResponse = _handleResponse(response)['vttMap'];
     try {
       if (jsonResponse is Map<String, dynamic>){
         return VttMap.fromJson(jsonResponse);
       } else {
          throw VttServiceException("잘못된 맵 데이터 형식 수신");
       }
     } catch (e) {
        debugPrint("VTT Service Error (createMap): Error parsing map: $e");
        throw VttServiceException("맵 생성 응답 데이터를 파싱하는 중 오류 발생");
     }
  }
  
  /// 맵 수정 (PATCH /vttmaps/:mapId)
  /// updateDto는 백엔드의 UpdateVttMapDto와 일치해야 함 (부분 업데이트 가능)
  static Future<VttMap> updateMap(String mapId, Map<String, dynamic> updateDto) async {
    final uri = Uri.parse('$_baseUrl/vttmaps/$mapId');
    final body = jsonEncode(updateDto);
    debugPrint("VTT Service: PATCH $uri with body $body");
    final headers = await _getHeaders();
    final response = await _makeRequest(() => http.patch(uri, headers: headers, body: body));
    // 백엔드는 VttMapResponseDto (message + vttMap)를 반환
    final dynamic jsonResponse = _handleResponse(response)['vttMap'];
     try {
       if (jsonResponse is Map<String, dynamic>){
         return VttMap.fromJson(jsonResponse);
       } else {
          throw VttServiceException("잘못된 맵 데이터 형식 수신");
       }
     } catch (e) {
        debugPrint("VTT Service Error (updateMap): Error parsing map: $e");
        throw VttServiceException("맵 수정 응답 데이터를 파싱하는 중 오류 발생");
     }
  }

  /// 맵 삭제 (DELETE /vttmaps/:mapId)
  static Future<void> deleteMap(String mapId) async {
    final uri = Uri.parse('$_baseUrl/vttmaps/$mapId');
    debugPrint("VTT Service: DELETE $uri");
    final headers = await _getHeaders();
    final response = await _makeRequest(() => http.delete(uri, headers: headers));
    _handleResponse(response); // 200 OK (DeleteVttMapResponseDto) 또는 204 No Content
  }


  // --- Token API (Marker API 대체) ---

  /// 특정 맵의 모든 토큰 조회 (GET /tokens/maps/:mapId)
  static Future<List<Token>> getTokensByMap(String mapId) async {
    final uri = Uri.parse('$_baseUrl/tokens/maps/$mapId');
    debugPrint("VTT Service: GET $uri");
    final headers = await _getHeaders();
    final response = await _makeRequest(() => http.get(uri, headers: headers));
    final List<dynamic> jsonList = _handleResponse(response);
    try {
      // 백엔드는 TokenResponseDto[]를 반환
      return jsonList
          .map((e) => Token.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint(
          "VTT Service Error (getTokensByMap): Error parsing token list: $e");
      throw VttServiceException("토큰 목록 데이터를 파싱하는 중 오류 발생");
    }
  }

  /// 토큰 생성 (POST /tokens/maps/:mapId)
  /// createDto는 백엔드의 CreateTokenDto와 일치해야 함
  /// { "name": String, "x": double, "y": double, "sheetId": String?, "npcId": int?, "imageUrl": String?, "isVisible": bool? }
  static Future<Token> createToken(String mapId, Map<String, dynamic> createDto) async {
    final uri = Uri.parse('$_baseUrl/tokens/maps/$mapId');
    final body = jsonEncode(createDto);
    debugPrint("VTT Service: POST $uri with body $body");
    final headers = await _getHeaders();
    final response =
        await _makeRequest(() => http.post(uri, headers: headers, body: body));
    // 백엔드는 TokenResponseDto를 반환
    final dynamic jsonResponse = _handleResponse(response);
    try {
      if (jsonResponse is Map<String, dynamic>) {
        return Token.fromJson(jsonResponse);
      } else {
        throw VttServiceException("잘못된 토큰 데이터 형식 수신");
      }
    } catch (e) {
      debugPrint("VTT Service Error (createToken): Error parsing token: $e");
      throw VttServiceException("토큰 생성 응답 데이터를 파싱하는 중 오류 발생");
    }
  }

  /// 토큰 수정 (PATCH /tokens/:id)
  /// updateDto는 백엔드의 UpdateTokenDto와 일치해야 함 (부분 업데이트)
  static Future<Token> updateToken(String tokenId, Map<String, dynamic> updateDto) async {
    final uri = Uri.parse('$_baseUrl/tokens/$tokenId');
    final body = jsonEncode(updateDto);
    debugPrint("VTT Service: PATCH $uri with body $body");
    final headers = await _getHeaders();
    final response =
        await _makeRequest(() => http.patch(uri, headers: headers, body: body));
    // 백엔드는 TokenResponseDto를 반환
    final dynamic jsonResponse = _handleResponse(response);
    try {
      if (jsonResponse is Map<String, dynamic>) {
        return Token.fromJson(jsonResponse);
      } else {
        throw VttServiceException("잘못된 토큰 데이터 형식 수신");
      }
    } catch (e) {
      debugPrint("VTT Service Error (updateToken): Error parsing token: $e");
      throw VttServiceException("토큰 업데이트 응답 데이터를 파싱하는 중 오류 발생");
    }
  }

  /// 토큰 삭제 (DELETE /tokens/:id)
  static Future<void> deleteToken(String tokenId) async {
    final uri = Uri.parse('$_baseUrl/tokens/$tokenId');
    debugPrint("VTT Service: DELETE $uri");
    final headers = await _getHeaders();
    final response = await _makeRequest(() => http.delete(uri, headers: headers));
    _handleResponse(response); // 204 No Content
  }

  // --- Upload API (Presigned URL 방식) ---

  /// 맵 이미지 업로드용 Presigned URL 받기
  /// (POST /vttmaps/rooms/:roomId/vttmaps/presigned-url)
  static Future<PresignedUrlResponse> getPresignedUrlForMapImage(
      String roomId, String fileName, String contentType) async {
    final uri =
        Uri.parse('$_baseUrl/vttmaps/rooms/$roomId/vttmaps/presigned-url');
    final body = jsonEncode({
      'fileName': fileName,
      'contentType': contentType,
    });
    debugPrint("VTT Service: POST $uri");
    final headers = await _getHeaders();
    final response =
        await _makeRequest(() => http.post(uri, headers: headers, body: body));
    final dynamic jsonResponse = _handleResponse(response);
    try {
      return PresignedUrlResponse.fromJson(jsonResponse);
    } catch (e) {
      debugPrint("VTT Service Error (getPresignedUrl): $e");
      throw VttServiceException("Presigned URL 응답 파싱 오류");
    }
  }

  /// Presigned URL로 실제 파일 업로드 (S3에 PUT)
  /// (이 요청은 인증 헤더가 필요 없습니다)
  static Future<void> uploadFileToPresignedUrl(
      String presignedUrl, File file, String contentType) async {
    final uri = Uri.parse(presignedUrl);
    debugPrint("VTT Service: PUT $uri (Uploading file to S3)");
    try {
      final response = await http
          .put(
            uri,
            headers: {'Content-Type': contentType},
            body: await file.readAsBytes(), // 파일 내용을 byte로 읽어 전송
          )
          .timeout(const Duration(seconds: 60)); // 업로드를 위해 타임아웃 60초

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
            "VTT Service Error (uploadFile): S3 upload failed with status ${response.statusCode}");
        debugPrint("Body: ${response.body}");
        throw VttServiceException("이미지 업로드 실패 (S3)",
            statusCode: response.statusCode);
      }
      debugPrint("VTT Service: File uploaded successfully to S3.");
    } on TimeoutException {
      debugPrint("VTT Service: File upload timed out.");
      throw VttServiceException("이미지 업로드 시간 초과");
    } on SocketException {
      debugPrint("VTT Service: SocketException during file upload.");
      throw VttServiceException("네트워크 연결 오류로 이미지 업로드 실패");
    } catch (e) {
      debugPrint("VTT Service: Unexpected error during file upload: $e");
      if (e is VttServiceException) rethrow;
      throw VttServiceException("이미지 업로드 중 예상치 못한 오류 발생");
    }
  }
}