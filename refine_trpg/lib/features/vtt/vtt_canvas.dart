import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/marker.dart';
import '../../services/vtt_socket_service.dart';

/// VTT 캔버스 (줌/패닝 + 그리드 + 마커 드래그)
/// - 소켓 기반 상태(VttSocketService)는 유지
/// - 이동 델타는 현재 줌 배율을 고려해 서버로 전송 (dx/scale, dy/scale)
/// - 배경/그리드/마커 모두 InteractiveViewer 안에서 스케일/패닝
class VttCanvas extends StatefulWidget {
  const VttCanvas({super.key});

  @override
  State<VttCanvas> createState() => _VttCanvasState();
}

class _VttCanvasState extends State<VttCanvas> {
  final TransformationController _t = TransformationController();
  int? _selectedMarkerId;

  double get _scale {
    final m = _t.value;
    // 대각 성분에서 스케일 근사
    return (m.row0[0].abs() + m.row1[1].abs()) / 2.0;
  }

  void _resetView() {
    _t.value = Matrix4.identity();
    setState(() {});
  }

  static const double _minScale = 0.5;
  static const double _maxScale = 3.5;

  void _zoomBy(double delta) {
    final current = _scale <= 0.001 ? 1.0 : _scale;
    final target = (current + delta).clamp(_minScale, _maxScale);
    final ratio = target / current;
    setState(() {
      final m = Matrix4.copy(_t.value);
      m.scale(ratio, ratio, 1);
      _t.value = m;
    });
  }

  void _zoomIn() => _zoomBy(0.25);
  void _zoomOut() => _zoomBy(-0.25);

  @override
  Widget build(BuildContext context) {
    final vtt = Provider.of<VttSocketService>(context);
    final scene = vtt.scene;
    final markers = vtt.markers.values.toList();

    if (scene == null) {
      return const Center(child: Text('씬을 불러오는 중...'));
    }

    return LayoutBuilder(
      builder: (context, bc) {
        final canvasSize = Size(bc.maxWidth, bc.maxHeight);

        return Stack(
          children: [
            // 메인 인터랙션 뷰 (줌/패닝)
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _t,
                minScale: 0.5,
                maxScale: 3.5,
                boundaryMargin: const EdgeInsets.all(2000),
                constrained: false, // 캔버스에 여백을 둬서 패닝 여유 확보
                child: Stack(
                  children: [
                    // 배경
                    SizedBox(
                      width: canvasSize.width,
                      height: canvasSize.height,
                      child: scene.backgroundUrl == null
                          ? Container(color: Colors.black12)
                          : CachedNetworkImage(
                              imageUrl: scene.backgroundUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) =>
                                  const Center(child: Icon(Icons.error)),
                            ),
                    ),

                    // 그리드 (옵션)
                    if (vtt.showGrid)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: CustomPaint(
                            painter: _GridPainter(
                              spacing: (vtt.gridSize > 0) ? vtt.gridSize : 50.0,
                              color: Colors.white.withOpacity(0.08),
                              thickEvery: 5,
                              thickColor: Colors.white.withOpacity(0.14),
                            ),
                          ),
                        ),
                      ),

                    // 마커들
                    ...markers.map(
                      (m) => _MarkerItem(
                        marker: m,
                        selected: _selectedMarkerId == m.id,
                        onTap: () => setState(() => _selectedMarkerId = m.id),
                        onChanged: (dx, dy) {
                          // 현재 배율을 고려해 논리 좌표로 변환
                          final s = _scale <= 0.001 ? 1.0 : _scale;
                          final ndx = dx / s;
                          final ndy = dy / s;

                          final newX = math.max(
                            0.0,
                            math.min(m.x + ndx, bc.maxWidth - m.width),
                          ).toDouble();

                          final newY = math.max(
                            0.0,
                            math.min(m.y + ndy, bc.maxHeight - m.height),
                          ).toDouble();

                          // 위치 변경은 소켓 서비스에 위임 (현 설계 유지)
                          vtt.moveMarker(m.id, newX, newY);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 우상단 툴버튼 (그리드 토글 / 뷰 리셋)
            Positioned(
              top: 12,
              right: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '축소',
                      icon: const Icon(Icons.zoom_out, color: Colors.white),
                      onPressed: _zoomOut,
                    ),
                    IconButton(
                      tooltip: '확대',
                      icon: const Icon(Icons.zoom_in, color: Colors.white),
                      onPressed: _zoomIn,
                    ),
                    IconButton(
                      tooltip: vtt.showGrid ? '그리드 끄기' : '그리드 켜기',
                      icon: Icon(
                        vtt.showGrid ? Icons.grid_off : Icons.grid_on,
                        color: Colors.white,
                      ),
                      onPressed: () => vtt.setShowGrid(!vtt.showGrid),
                    ),
                    IconButton(
                      tooltip: '뷰 리셋',
                      icon: const Icon(Icons.center_focus_strong, color: Colors.white),
                      onPressed: _resetView,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarkerItem extends StatelessWidget {
  final Marker marker;
  final bool selected;
  final VoidCallback onTap;
  final void Function(double dx, double dy) onChanged;

  const _MarkerItem({
    super.key,
    required this.marker,
    required this.selected,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: marker.x,
      top: marker.y,
      width: marker.width.toDouble(),
      height: marker.height.toDouble(),
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (d) => onChanged(d.delta.dx, d.delta.dy),
        child: Opacity(
          opacity: 0.97,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? Colors.blueAccent : Colors.black26,
                width: selected ? 2.0 : 1.0,
              ),
              color: Colors.white,
              image: (marker.imageUrl != null)
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(marker.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: (marker.imageUrl == null)
                ? Center(
                    child: Text(
                      marker.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// 단순 그리드 페인터 (spacing 픽셀 간격, n번째마다 진하게)
class _GridPainter extends CustomPainter {
  final double spacing;
  final int thickEvery;
  final Color color;
  final Color thickColor;

  _GridPainter({
    required this.spacing,
    required this.color,
    required this.thickEvery,
    required this.thickColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pThin = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    final pThick = Paint()
      ..color = thickColor
      ..strokeWidth = 1.0;

    // 수직선
    for (int i = 0; i * spacing <= size.width; i++) {
      final x = i * spacing;
      final isThick = (i % thickEvery == 0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), isThick ? pThick : pThin);
    }
    // 수평선
    for (int j = 0; j * spacing <= size.height; j++) {
      final y = j * spacing;
      final isThick = (j % thickEvery == 0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), isThick ? pThick : pThin);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) {
    return old.spacing != spacing ||
        old.color != color ||
        old.thickColor != thickColor ||
        old.thickEvery != thickEvery;
  }
}
