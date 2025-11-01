// lib/features/vtt/vtt_canvas.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:trpg_frontend/models/token.dart';
import 'package:trpg_frontend/services/vtt_socket_service.dart';
import 'package:trpg_frontend/services/vtt_service.dart'; // [수정됨] REST API 서비스 import

class VttCanvas extends StatelessWidget {
  const VttCanvas({super.key});

  // [수정됨] Token 모델에는 width, height가 없으므로 기본 크기 정의
  static const double defaultTokenSize = 50.0;

  @override
  Widget build(BuildContext context) {
    // Provider로부터 Socket 서비스와 REST API 서비스 인스턴스 가져오기
    final vttSocket = Provider.of<VttSocketService>(context);
    final vttApi = VttService.instance; // REST API 서비스
    final scene = vttSocket.scene;
    final tokens = vttSocket.tokens.values.toList(); // Map의 값들만 List로 변환

    if (scene == null) {
      return const Center(child: Text('씬 정보를 기다리는 중...'));
    }
    if (!vttSocket.isConnected) {
       return const Center(child: Text('VTT 서버에 연결 중...'));
    }

    return LayoutBuilder(
      builder: (context, constraints) { // BoxConstraints 사용
        return Stack(
          children: [
            // 배경 이미지
            Positioned.fill(
              child: scene.backgroundUrl == null || scene.backgroundUrl!.isEmpty
                  ? Container(color: Colors.grey[300]) // 기본 배경색
                  : CachedNetworkImage(
                      imageUrl: scene.backgroundUrl!,
                      fit: BoxFit.cover, // 이미지 채우기 방식
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                          const Center(child: Icon(Icons.error, color: Colors.red)),
                    ),
            ),

            // 토큰 목록 렌더링
            ...tokens.map(
              (token) => _TokenItem( // [수정됨] 위젯 이름 변경
                key: ValueKey(token.id), // [수정됨] String ID를 Key로 사용
                token: token,
                defaultSize: defaultTokenSize, // [수정됨] 기본 크기 전달
                onPositionChanged: (dx, dy) async { // [수정됨] 비동기 처리
                  // 화면 경계 내에서 새로운 위치 계산
                  final newX = max(
                          0.0,
                          min(token.x + dx,
                              constraints.maxWidth - defaultTokenSize)) // [수정됨] width 대신 defaultSize
                      .toDouble();
                  final newY = max(
                          0.0,
                          min(token.y + dy,
                              constraints.maxHeight - defaultTokenSize)) // [수정됨] height 대신 defaultSize
                      .toDouble();

                  // 변경된 위치만 서버에 업데이트 요청 (REST API 사용)
                  try {
                    // [수정됨] VttService의 updateToken 호출
                    await vttApi.updateToken(token.id, { 
                      'x': newX,
                      'y': newY,
                    });
                    // 성공 시 UI는 VttSocketService의 'token.updated' 이벤트를 통해 갱신됨
                  } catch (e) {
                    // TODO: 사용자에게 오류 메시지 표시 (예: ScaffoldMessenger)
                    debugPrint('토큰 이동 실패: $e');
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 개별 토큰을 표시하는 위젯
class _TokenItem extends StatelessWidget { // [수정됨] 이름 변경
  final Token token;
  final double defaultSize; // [수정됨] 크기 파라미터 추가
  final void Function(double dx, double dy) onPositionChanged;

  const _TokenItem({
    super.key, // [수정됨] Key 전달
    required this.token,
    required this.defaultSize, // [수정됨]
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: token.x,
      top: token.y,
      // [수정됨] width, height 대신 defaultSize 사용
      width: defaultSize, 
      height: defaultSize,
      child: GestureDetector(
        // [수정됨] onPanUpdate가 아닌 onPositionChanged 콜백 사용
        onPanUpdate: (details) => 
            onPositionChanged(details.delta.dx, details.delta.dy),
        child: Tooltip( // 토큰 이름 표시 (선택 사항)
          message: token.name,
          child: Opacity(
            // [수정됨] isVisible 속성 반영
            opacity: token.isVisible ? 0.95 : 0.4, 
            child: Container( // [수정됨] DecoratedBox -> Container (더 유연함)
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(defaultSize / 2), // 원형 토큰
                border: Border.all(color: Colors.black45, width: 1.5),
                color: Colors.blueGrey[100], // 기본 색상
                image: (token.imageUrl != null && token.imageUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(token.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [ // 입체감 효과 (선택 사항)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              // 이미지가 없을 때 이름의 첫 글자 표시 (선택 사항)
              child: (token.imageUrl == null || token.imageUrl!.isEmpty) 
                  ? Center(
                      child: Text(
                        token.name.isNotEmpty ? token.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: defaultSize * 0.6,
                          color: Colors.black87,
                        ),
                      ),
                    )
                  : null, // 이미지가 있으면 텍스트 표시 안 함
            ),
          ),
        ),
      ),
    );
  }
}