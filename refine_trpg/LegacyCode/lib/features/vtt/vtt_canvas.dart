import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/vtt_scene.dart';
import '../../models/marker.dart';
import '../../services/vtt_service.dart';
import '../../services/vtt_socket.dart';

class VttCanvas extends StatefulWidget {
  final int roomId;
  final String baseUrl; // http://localhost:4000
  final VttScene? initialScene; // 있으면 바로 표시
  const VttCanvas({
    super.key,
    required this.roomId,
    required this.baseUrl,
    this.initialScene,
  });

  @override
  State<VttCanvas> createState() => _VttCanvasState();
}

class _VttCanvasState extends State<VttCanvas> {
  late final VttApi _api;
  late final VttSocket _socket;

  List<VttScene> _scenes = [];
  VttScene? _scene;
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _api = VttApi(widget.baseUrl);
    _socket = VttSocket(widget.baseUrl)..connect(
      onMarkerCreated: (m) {
        if (_scene?.id == m.sceneId) setState(() => _markers.add(m));
      },
      onMarkerMoved: (m) {
        if (_scene?.id == m.sceneId) {
          final i = _markers.indexWhere((e) => e.id == m.id);
          if (i >= 0) setState(() => _markers[i] = m);
        }
      },
      onMarkerDeleted: (id) {
        _markers.removeWhere((e) => e.id == id);
        setState(() {});
      },
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.initialScene != null) {
      _scene = widget.initialScene!;
      _markers
        ..clear()
        ..addAll(await _api.getMarkersByScene(_scene!.id));
      setState(() {});
    } else {
      _scenes = await _api.getScenesByRoom(widget.roomId);
      if (_scenes.isEmpty) {
        _scene = null;
      } else {
        _scene = _scenes.firstWhere(
          (s) => s.isActive,
          orElse: () => _scenes.first,
        );
      }
      if (_scene != null) {
        _markers
          ..clear()
          ..addAll(await _api.getMarkersByScene(_scene!.id));
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  Future<void> _onDragEnd(Marker m) async {
    // 서버 반영 (낙관적 UI 이후 확정값 수신시 소켓으로 재동기)
    await _api.updateMarkerPosition(m.id, x: m.x, y: m.y, rotation: m.rotation);
  }

  @override
  Widget build(BuildContext context) {
    if (_scene == null) {
      return const Center(child: Text('씬이 없습니다.'));
    }
    return LayoutBuilder(
      builder: (context, bc) {
        return Stack(
          children: [
            // 배경
            Positioned.fill(
              child:
                  _scene!.backgroundUrl == null
                      ? Container(color: Colors.black12)
                      : CachedNetworkImage(
                        imageUrl: '${widget.baseUrl}${_scene!.backgroundUrl!}',
                        fit: BoxFit.cover,
                      ),
            ),
            // 마커들
            ..._markers.map(
              (m) => _MarkerItem(
                marker: m,
                onChanged: (dx, dy) {
                  setState(() {
                    m.x = max(0, min(m.x + dx, bc.maxWidth - m.width));
                    m.y = max(0, min(m.y + dy, bc.maxHeight - m.height));
                  });
                },
                onDrop: () => _onDragEnd(m),
                baseUrl: widget.baseUrl,
              ),
            ),
            // 우측 상단: 씬 선택/새로고침
            Positioned(
              right: 12,
              top: 12,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      _scenes = await _api.getScenesByRoom(widget.roomId);
                      if (_scenes.isNotEmpty) {
                        final chosen = await showMenu<VttScene>(
                          context: context,
                          position: const RelativeRect.fromLTRB(100, 80, 0, 0),
                          items:
                              _scenes
                                  .map(
                                    (s) => PopupMenuItem(
                                      value: s,
                                      child: Text(
                                        '${s.name}${s.isActive ? ' (활성)' : ''}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                        );
                        if (chosen != null) {
                          _scene = chosen;
                          _markers
                            ..clear()
                            ..addAll(await _api.getMarkersByScene(_scene!.id));
                          setState(() {});
                        }
                      }
                    },
                    child: const Text('씬 선택'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _bootstrap,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarkerItem extends StatefulWidget {
  final Marker marker;
  final void Function(double dx, double dy) onChanged;
  final VoidCallback onDrop;
  final String baseUrl;
  const _MarkerItem({
    required this.marker,
    required this.onChanged,
    required this.onDrop,
    required this.baseUrl,
  });

  @override
  State<_MarkerItem> createState() => _MarkerItemState();
}

class _MarkerItemState extends State<_MarkerItem> {
  @override
  Widget build(BuildContext context) {
    final m = widget.marker;
    return Positioned(
      left: m.x,
      top: m.y,
      width: m.width.toDouble(),
      height: m.height.toDouble(),
      child: GestureDetector(
        onPanUpdate: (d) => widget.onChanged(d.delta.dx, d.delta.dy),
        onPanEnd: (_) => widget.onDrop(),
        child: Opacity(
          opacity: 0.95,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black26),
              color: Colors.white,
              image:
                  (m.imageUrl != null)
                      ? DecorationImage(
                        image: NetworkImage('${widget.baseUrl}${m.imageUrl!}'),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                (m.imageUrl == null)
                    ? Center(
                      child: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
