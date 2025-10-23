import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/marker.dart';
import '../../services/vtt_socket_service.dart';
import '../../models/vtt_scene.dart'; // Import VttScene

class VttCanvas extends StatefulWidget {
  const VttCanvas({super.key});

  @override
  State<VttCanvas> createState() => _VttCanvasState();
}

class _VttCanvasState extends State<VttCanvas> {
  // Controller to manage transformations (zoom/pan) programmatically if needed.
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes in VttSocketService
    final vtt = context.watch<VttSocketService>();
    final VttScene? scene = vtt.scene; // Make scene nullable
    // Use markers directly from the provider
    final markers = vtt.markers.values.toList();

    if (scene == null) {
      return const Center(child: Text('씬을 불러오는 중...'));
    }

    // --- Get scene dimensions ---
    // Use scene dimensions for the canvas size, provide defaults if necessary
    final double sceneWidth = scene.width.toDouble();
    final double sceneHeight = scene.height.toDouble();

    // Ensure dimensions are valid (> 0)
    if (sceneWidth <= 0 || sceneHeight <= 0) {
       return const Center(child: Text('씬 크기 정보가 유효하지 않습니다.'));
    }


    // Use InteractiveViewer for zoom/pan capabilities
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.1, // Minimum zoom level
      maxScale: 4.0, // Maximum zoom level
      constrained: false, // Allow panning beyond the bounds of the child
      // boundaryMargin: EdgeInsets.all(double.infinity), // Allow infinite panning (optional)
       boundaryMargin: const EdgeInsets.all(100.0), // Add some padding around the scene

      // Builder is useful if you need the viewport size, but Stack works directly too
      child: SizedBox(
        width: sceneWidth,
        height: sceneHeight,
        child: Stack(
          clipBehavior: Clip.none, // Allow markers partially outside the bounds
          children: [
            // --- Background ---
            Positioned.fill(
              child: scene.backgroundUrl == null || scene.backgroundUrl!.isEmpty
                  ? Container(color: Colors.grey[300]) // Use a lighter grey
                  : CachedNetworkImage(
                      imageUrl: scene.backgroundUrl!,
                      fit: BoxFit.cover, // Cover the entire scene area
                      placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)), // Smaller indicator
                      errorWidget: (context, url, error) => Container(
                        color: Colors.red[100], // Indicate error with color
                        child: Center(
                            child: Icon(Icons.error_outline,
                                color: Colors.red[700])),
                      ),
                    ),
            ),

            // --- Markers ---
            // Render markers based on the list from the provider
            ...markers.map(
              (m) => _MarkerItem(
                key: ValueKey(m.id), // Add key for better performance
                marker: m,
                sceneWidth: sceneWidth, // Pass scene dimensions
                sceneHeight: sceneHeight,
                onPositionChanged: (dx, dy) {
                  // Calculate new position based on drag delta
                  // Apply boundary constraints relative to the scene dimensions
                  final newX = max(
                          0.0, min(m.x + dx, sceneWidth - m.width))
                      .toDouble(); // Ensure marker stays within scene width
                  final newY = max(
                          0.0, min(m.y + dy, sceneHeight - m.height))
                      .toDouble(); // Ensure marker stays within scene height

                  // Check if position actually changed to avoid unnecessary updates
                  if (newX != m.x || newY != m.y) {
                    // Update position via the VttSocketService
                     vtt.moveMarker(m.id, newX, newY);
                  }
                },
                // Optional: Add onTap or onLongPress later for marker interactions
              ),
            ),
             // --- Grid Layer (Optional Example) ---
            // Positioned.fill(
            //   child: CustomPaint(
            //     painter: GridPainter(gridSize: 50.0), // Example grid size
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}


// --- _MarkerItem Widget ---
class _MarkerItem extends StatelessWidget {
  final Marker marker;
  final double sceneWidth;
  final double sceneHeight;
  final void Function(double dx, double dy) onPositionChanged;
  // Add other callbacks as needed (onTap, onLongPress, etc.)

  const _MarkerItem({
    super.key, // Use super parameter syntax
    required this.marker,
    required this.sceneWidth,
    required this.sceneHeight,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
     // Ensure marker dimensions are valid
    final markerWidth = max(10.0, marker.width.toDouble()); // Minimum size
    final markerHeight = max(10.0, marker.height.toDouble());

    // Clamp initial position just in case it's outside bounds
    final clampedX = max(0.0, min(marker.x, sceneWidth - markerWidth));
    final clampedY = max(0.0, min(marker.y, sceneHeight - markerHeight));


    return Positioned(
      left: clampedX,
      top: clampedY,
      width: markerWidth,
      height: markerHeight,
      child: GestureDetector(
        // Use onPanUpdate for continuous dragging
        onPanUpdate: (details) =>
            onPositionChanged(details.delta.dx, details.delta.dy),
        // Add onPanStart and onPanEnd if needed for drag start/end logic

        child: Tooltip( // Add Tooltip to show marker name on hover/long-press
          message: marker.name,
          preferBelow: false,
          child: Opacity(
            opacity: 0.9, // Slightly more transparent
            child: Container( // Use Container for more decoration options
              decoration: BoxDecoration(
                // borderRadius: BorderRadius.circular(markerWidth / 2), // Make it circular if desired
                 borderRadius: BorderRadius.circular(4), // Slightly rounded corners
                 border: Border.all(color: Colors.black.withOpacity(0.5), width: 1), // Softer border
                color: marker.imageUrl == null || marker.imageUrl!.isEmpty
                    ? Colors.blueGrey[100] // Default color if no image
                    : Colors.transparent, // Transparent if image is present
                boxShadow: [ // Add a subtle shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  )
                ],
                image: (marker.imageUrl != null && marker.imageUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(marker.imageUrl!),
                        fit: BoxFit.cover, // Or BoxFit.contain depending on preference
                        onError: (exception, stackTrace) {
                           // Optional: Handle image loading errors visually
                           print("Error loading marker image: $exception");
                         },
                      )
                    : null,
              ),
              // Display name inside if there's no image
              child: (marker.imageUrl == null || marker.imageUrl!.isEmpty)
                  ? Center(
                      child: Text(
                        marker.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: markerWidth / 5, // Adjust font size based on marker size
                           color: Colors.black87,
                         ),
                         overflow: TextOverflow.ellipsis, // Prevent overflow
                      ),
                    )
                  : const SizedBox.shrink(), // Empty box if image exists
            ),
          ),
        ),
      ),
    );
  }
}


// --- Optional Grid Painter ---
class GridPainter extends CustomPainter {
  final double gridSize;
  final Color gridColor;
  final double strokeWidth;

  GridPainter({
    required this.gridSize,
    this.gridColor = Colors.black26, // Lighter grid color
    this.strokeWidth = 0.5, // Thinner lines
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gridSize <= 0) return;

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    // Only repaint if grid size or color changes
    return oldDelegate.gridSize != gridSize || oldDelegate.gridColor != gridColor;
  }
}
