import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/token.dart'; // Token 모델 임포트
import '../../services/vtt_socket_service.dart';
import '../../models/vtt_map.dart'; // VttScene 대신 VttMap 임포트

class VttCanvas extends StatefulWidget {
  const VttCanvas({super.key});

  @override
  State<VttCanvas> createState() => _VttCanvasState();
}

class _VttCanvasState extends State<VttCanvas> {
  final TransformationController _transformationController =
      TransformationController();

  // TODO: 실제 맵 크기를 결정하는 로직 필요 (예: 배경 이미지 로드 후 크기 계산)
  // 임시로 큰 고정 크기 사용
  final double _canvasWidth = 3000.0;
  final double _canvasHeight = 3000.0;


  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // VttSocketService의 변경 사항 감시
    final vtt = context.watch<VttSocketService>();
    final VttMap? vttMap = vtt.vttMap; // scene -> vttMap
    // markers -> tokens, Map<String, Token>에서 값 목록 가져오기
    final tokens = vtt.tokens.values.toList();

    // VttMap 로딩 중 표시
    if (vttMap == null) {
      // 소켓 연결 상태나 오류 메시지도 함께 표시하면 더 좋음
      if (vtt.isConnected && vtt.isRoomJoined) {
         return const Center(child: Text('맵을 선택하거나 로딩 중...'));
      } else if (!vtt.isConnected) {
         return const Center(child: Text('소켓 연결 중...'));
      } else {
         return const Center(child: Text('VTT 서비스에 연결되지 않음'));
      }
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.1,
      maxScale: 4.0,
      constrained: false, // 캔버스 크기 이상으로 패닝 허용
      boundaryMargin: const EdgeInsets.all(100.0), // 패닝 여백

      child: SizedBox(
        // VttMap에 width/height가 없으므로 임시 고정 크기 사용
        width: _canvasWidth,
        height: _canvasHeight,
        child: Stack(
          clipBehavior: Clip.none, // 토큰이 캔버스 가장자리에 걸쳐도 보이도록 함
          children: [
            // --- 배경 이미지 ---
            Positioned.fill(
              child: vttMap.imageUrl == null || vttMap.imageUrl!.isEmpty
                  ? Container(color: Colors.grey[300]) // 기본 배경색
                  : CachedNetworkImage(
                      imageUrl: vttMap.imageUrl!,
                      // TODO: 배경 이미지 크기에 맞춰 Stack 크기를 조절하는 로직 추가 가능
                      fit: BoxFit.cover, // 일단 커버로 채움
                      placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.red[100],
                        child: Center(
                            child: Icon(Icons.error_outline,
                                color: Colors.red[700])),
                      ),
                    ),
            ),

            // --- 토큰 (Markers -> Tokens) ---
            ...tokens.map(
              (token) => _TokenItem( // _MarkerItem -> _TokenItem
                // Key는 String 타입 ID 사용
                key: ValueKey(token.id),
                token: token,
                // TODO: 맵 크기가 동적이므로, 토큰 이동 제약 로직은 _TokenItem 내부나 여기서 더 정교하게 구현 필요
                canvasWidth: _canvasWidth,
                canvasHeight: _canvasHeight,
                onPositionChanged: (dx, dy) {
                  // 이동 로직은 단순화 (제약 조건 제거 - 필요시 추가)
                  final newX = token.x + dx;
                  final newY = token.y + dy;

                  // 실제 위치가 변경되었을 때만 소켓 이벤트 전송
                  if (newX != token.x || newY != token.y) {
                    // String ID 사용
                    vtt.moveToken(token.id, newX, newY);
                  }
                },
              ),
            ),

            // --- Grid Layer (주석 처리) ---
            // TODO: 백엔드 VttMap의 gridType, gridSize, showGrid 값에 맞춰 GridPainter 구현 필요
            // Positioned.fill(
            //   child: CustomPaint(
            //     painter: GridPainter(
            //        gridSize: vttMap.gridSize.toDouble(), // gridSize 사용
            //        showGrid: vttMap.showGrid, // showGrid 사용
            //        gridType: vttMap.gridType, // gridType (SQUARE, HEX_H, HEX_V) 에 따른 분기 필요
            //      ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

// --- _TokenItem Widget (_MarkerItem 대체) ---
class _TokenItem extends StatelessWidget {
  final Token token; // Marker -> Token
  final double canvasWidth; // 이름 변경: sceneWidth -> canvasWidth
  final double canvasHeight; // 이름 변경: sceneHeight -> canvasHeight
  final void Function(double dx, double dy) onPositionChanged;

  // TODO: 토큰 크기를 결정하는 로직 필요 (모델에 추가하거나, 이미지 기반 등)
  // 임시 고정 크기
  final double tokenWidth = 50.0;
  final double tokenHeight = 50.0;


  const _TokenItem({
    super.key,
    required this.token,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 토큰 위치 (모델의 x, y 사용)
    // TODO: 필요시 여기서 캔버스 경계 제약 로직 추가
    final posX = token.x;
    final posY = token.y;

    // 토큰 숨김 처리
    if (!token.isVisible) {
      return const SizedBox.shrink(); // 보이지 않으면 빈 위젯 반환
    }

    return Positioned(
      left: posX,
      top: posY,
      width: tokenWidth, // 임시 고정 크기
      height: tokenHeight, // 임시 고정 크기
      child: GestureDetector(
        onPanUpdate: (details) =>
            onPositionChanged(details.delta.dx, details.delta.dy),

        child: Tooltip(
          message: token.name, // name 필드 사용
          preferBelow: false,
          child: Opacity(
            opacity: 0.9,
            child: Container(
              decoration: BoxDecoration(
                 borderRadius: BorderRadius.circular(4),
                 border: Border.all(color: Colors.black.withOpacity(0.5), width: 1),
                color: token.imageUrl == null || token.imageUrl!.isEmpty
                    ? Colors.blueGrey[100] // 기본 색상
                    : Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  )
                ],
                image: (token.imageUrl != null && token.imageUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(token.imageUrl!),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                           debugPrint("Error loading token image: $exception");
                         },
                      )
                    : null,
              ),
              child: (token.imageUrl == null || token.imageUrl!.isEmpty)
                  ? Center(
                      child: Text(
                        token.name, // name 필드 사용
                        textAlign: TextAlign.center,
                        style: TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: tokenWidth / 5, // 크기에 비례한 폰트 크기
                           color: Colors.black87,
                         ),
                         overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}


// --- Optional Grid Painter (주석 처리) ---
/*
class GridPainter extends CustomPainter {
  final double gridSize;
  final bool showGrid; // 그리드 표시 여부
  final GridType gridType; // 그리드 타입 (vtt_map.dart 에서 임포트)
  final Color gridColor;
  final double strokeWidth;

  GridPainter({
    required this.gridSize,
    required this.showGrid,
    required this.gridType,
    this.gridColor = Colors.black26,
    this.strokeWidth = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGrid || gridSize <= 0) return; // showGrid가 false면 그리지 않음

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // TODO: gridType에 따라 Square, Hex_H, Hex_V 그리기 로직 구현
    if (gridType == GridType.SQUARE) {
      // Draw vertical lines
      for (double x = 0; x <= size.width; x += gridSize) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      // Draw horizontal lines
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else {
      // TODO: Hexagonal grid drawing logic
      debugPrint("Hexagonal grid painting not implemented yet.");
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
           oldDelegate.showGrid != showGrid ||
           oldDelegate.gridType != gridType ||
           oldDelegate.gridColor != gridColor;
  }
}
*/