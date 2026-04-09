import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/route_point.dart';

class RouteLineView extends StatelessWidget {
  const RouteLineView({super.key, required this.points});

  final List<RoutePoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RouteLinePainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  const _RouteLinePainter(this.points);

  final List<RoutePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bg = Paint()..color = const Color(0xFFEFF7F5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bg,
    );

    if (points.length < 2) {
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final RoutePoint p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLon = min(minLon, p.longitude);
      maxLon = max(maxLon, p.longitude);
    }

    final double latRange = max(maxLat - minLat, 0.00001);
    final double lonRange = max(maxLon - minLon, 0.00001);
    const double pad = 14;

    Offset mapPoint(RoutePoint p) {
      final double x =
          pad + ((p.longitude - minLon) / lonRange) * (size.width - pad * 2);
      final double y =
          pad + ((maxLat - p.latitude) / latRange) * (size.height - pad * 2);
      return Offset(x, y);
    }

    final Path path = Path()
      ..moveTo(mapPoint(points.first).dx, mapPoint(points.first).dy);
    for (int i = 1; i < points.length; i++) {
      final Offset o = mapPoint(points[i]);
      path.lineTo(o.dx, o.dy);
    }

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF146356)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, track);

    final Paint markerStart = Paint()..color = const Color(0xFF0E8A2F);
    final Paint markerEnd = Paint()..color = const Color(0xFFD2232A);
    canvas.drawCircle(mapPoint(points.first), 4, markerStart);
    canvas.drawCircle(mapPoint(points.last), 4, markerEnd);
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
