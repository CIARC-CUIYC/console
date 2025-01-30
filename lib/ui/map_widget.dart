import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:zoom_widget/zoom_widget.dart';

enum DraggedPoint { topLeft, topRight, bottomLeft, bottomRight }

class MapWidget extends StatelessWidget {
  static const int mapHeight = 10800;
  static const int mapWidth = 21600;
  static const double scaleFactorDisplaySpace = 1 / 25;
  static const double mapHeightDisplaySpace = mapHeight * scaleFactorDisplaySpace;
  static const double mapWidthDisplaySpace = mapWidth * scaleFactorDisplaySpace;
  static const double sateliteSize = 25;

  final Rect? highlightArea;
  final Offset? satellite;
  final Offset? satelliteVelocity;
  final ui.Image? mapImage;

  const MapWidget({super.key, this.mapImage, this.highlightArea, this.satellite, this.satelliteVelocity});

  @override
  Widget build(BuildContext context) {
    return Zoom(
      initTotalZoomOut: true,
      child: Center(
        child: Container(
          height: mapHeightDisplaySpace,
          width: mapWidthDisplaySpace,
          color: Colors.white,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (mapImage != null) RawImage(image: mapImage!, fit: BoxFit.fill),
              ResizableHighlight(),
              if (satellite != null && satelliteVelocity != null)
                CustomPaint(
                  painter: SatelliteTrajectoryPainter(satellite: satellite!, satelliteVelocity: satelliteVelocity!),
                ),
              if (highlightArea != null) CustomPaint(painter: HighlightPainter(highlightArea: highlightArea!)),
              if (satellite != null)
                Positioned(
                  left: satellite!.dx * scaleFactorDisplaySpace - sateliteSize / 2,
                  top: satellite!.dy * scaleFactorDisplaySpace - sateliteSize / 2,
                  width: sateliteSize,
                  height: sateliteSize,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(sateliteSize / 2),
                    ),
                    child: Icon(Icons.satellite_alt, size: sateliteSize - 7, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HighlightPainter extends CustomPainter {
  final Rect highlightArea;

  HighlightPainter({super.repaint, required this.highlightArea});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    void paintLine(Offset p1, Offset p2) {
      if (p1.dx > MapWidget.mapWidth && p2.dx < MapWidget.mapWidth) {
        final overflow = p1.dx - MapWidget.mapWidth;
        paintLine(Offset(overflow, p1.dy), Offset(0, p1.dy));
        paintLine(Offset(MapWidget.mapWidth.toDouble(), p1.dy), p2);
        return;
      }

      if (p1.dy > MapWidget.mapHeight && p2.dy < MapWidget.mapHeight) {
        final overflow = p1.dy - MapWidget.mapHeight;
        paintLine(Offset(p1.dx, overflow), Offset(p1.dx, 0));
        paintLine(Offset(p1.dx, MapWidget.mapHeight.toDouble()), p2);
        return;
      }

      if (p1.dy > MapWidget.mapHeight) {
        p1 = Offset(p1.dx, p1.dy - MapWidget.mapHeight);
      }

      if (p1.dx > MapWidget.mapWidth) {
        p1 = Offset(p1.dx - MapWidget.mapWidth, p1.dy);
      }

      if (p2.dy > MapWidget.mapHeight) {
        p2 = Offset(p2.dx, p2.dy - MapWidget.mapHeight);
      }

      if (p2.dx > MapWidget.mapWidth) {
        p2 = Offset(p2.dx - MapWidget.mapWidth, p2.dy);
      }

      canvas.drawLine(
        p1.scale(MapWidget.scaleFactorDisplaySpace, MapWidget.scaleFactorDisplaySpace),
        p2.scale(MapWidget.scaleFactorDisplaySpace, MapWidget.scaleFactorDisplaySpace),
        paint,
      );
    }

    paintLine(highlightArea.bottomRight, highlightArea.bottomLeft);
    paintLine(highlightArea.topRight, highlightArea.topLeft);
    paintLine(highlightArea.bottomLeft, highlightArea.topLeft);
    paintLine(highlightArea.bottomRight, highlightArea.topRight);
  }

  @override
  bool shouldRepaint(HighlightPainter oldDelegate) => oldDelegate.highlightArea != highlightArea;
}

class SatelliteTrajectoryPainter extends CustomPainter {
  final Offset satellite;
  final Offset satelliteVelocity;
  static const int markerCount = 50;
  static const double markerSize = 4;
  static const double spacing = 60;

  SatelliteTrajectoryPainter({super.repaint, required this.satellite, required this.satelliteVelocity});

  @override
  void paint(Canvas canvas, Size size) {
    Offset currentPosition = satellite;
    for (int i = 0; i < markerCount; i++) {
      currentPosition += (satelliteVelocity * spacing);
      currentPosition = Offset(currentPosition.dx % MapWidget.mapWidth, currentPosition.dy % MapWidget.mapHeight);

      final scaledPosition = currentPosition.scale(
        MapWidget.scaleFactorDisplaySpace,
        MapWidget.scaleFactorDisplaySpace,
      );
      final int alpha;
      if (i < markerCount * 0.75) {
        alpha = 255;
      } else {
        alpha = 0xFF - ((i - (markerCount * 0.75)) * (0xFF / (markerCount * 0.25))).round();
      }
      canvas.drawCircle(scaledPosition, markerSize / 2, Paint()..color = Colors.blueAccent.withAlpha(alpha));
    }
  }

  @override
  bool shouldRepaint(SatelliteTrajectoryPainter oldDelegate) =>
      oldDelegate.satellite != satellite || oldDelegate.satelliteVelocity != satelliteVelocity;
}

class ResizableHighlight extends StatefulWidget {
  const ResizableHighlight({super.key});

  @override
  State<StatefulWidget> createState() => ResizableHighlightState();
}

class ResizableHighlightState extends State<ResizableHighlight> {
  DraggedPoint? _draggedPoint;
  Rect highlightArea = Rect.fromCenter(
    center: Offset(MapWidget.mapWidth / 2, MapWidget.mapHeight / 2),
    width: MapWidget.mapWidth / 4,
    height: MapWidget.mapHeight / 4,
  );
  static const double dragRegistrationRadiusSquared = 150 * 150;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (details) {
        final position = details.localPosition.scale(
          1 / MapWidget.scaleFactorDisplaySpace,
          1 / MapWidget.scaleFactorDisplaySpace,
        );
        if ((highlightArea.topLeft - position).distanceSquared <= dragRegistrationRadiusSquared) {
          setState(() {
            _draggedPoint = DraggedPoint.topRight;
          });
        } else if ((highlightArea.topRight - position).distanceSquared <= dragRegistrationRadiusSquared) {
          setState(() {
            _draggedPoint = DraggedPoint.topRight;
          });
        } else if ((highlightArea.bottomLeft - position).distanceSquared <= dragRegistrationRadiusSquared) {
          setState(() {
            _draggedPoint = DraggedPoint.bottomLeft;
          });
        } else if ((highlightArea.bottomRight - position).distanceSquared <= dragRegistrationRadiusSquared) {
          setState(() {
            _draggedPoint = DraggedPoint.bottomRight;
          });
        } else {
          return;
        }
        // Hack the fight
        WidgetsBinding.instance.gestureArena.add(details.pointer, NoopGestureArenaMember()).resolve(GestureDisposition.accepted);
      },

      onPointerMove: (details) {
        if (_draggedPoint == null) return;
        final position = details.localPosition.scale(
          1 / MapWidget.scaleFactorDisplaySpace,
          1 / MapWidget.scaleFactorDisplaySpace,
        );
        final positionClamped = Offset(
          position.dx.clamp(0, MapWidget.mapWidth).toDouble(),
          position.dy.clamp(0, MapWidget.mapHeight).toDouble(),
        );

        switch (_draggedPoint) {
          case DraggedPoint.topLeft:
            setState(() {
              highlightArea = Rect.fromPoints(positionClamped,  highlightArea.bottomRight);
            });
            break;
          case DraggedPoint.topRight:
            setState(() {
              highlightArea = Rect.fromPoints(positionClamped, highlightArea.bottomLeft);
            });
            break;
          case DraggedPoint.bottomLeft:
            setState(() {
              highlightArea = Rect.fromPoints(positionClamped, highlightArea.topRight);
            });
            break;
          case DraggedPoint.bottomRight:
            setState(() {
              highlightArea = Rect.fromPoints(positionClamped, highlightArea.topLeft);
            });
          case null:
        }
      },
      onPointerUp: (details) {
        _draggedPoint = null;
      },
      child: CustomPaint(painter: HighlightPainter(highlightArea: highlightArea)),
    );
  }
}


class NoopGestureArenaMember extends GestureArenaMember {
  @override
  void acceptGesture(int pointer) {
    // TODO: implement acceptGesture
  }

  @override
  void rejectGesture(int pointer) {
    // TODO: implement rejectGesture
  }

}