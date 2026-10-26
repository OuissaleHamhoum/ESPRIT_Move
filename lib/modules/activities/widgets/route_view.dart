import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Dessine le trace GPS d'une sortie (points [lat, lng]) avec CustomPaint.
/// Pas de fond de carte : juste la forme du parcours, depart vert, arrivee rouge.
/// Utilise hors connexion et sur la carte de partage ([color] du trace).
class RouteView extends StatelessWidget {
  final List<List<double>> route;
  final Color color;
  const RouteView({super.key, required this.route, this.color = AppColors.red});

  @override
  Widget build(BuildContext context) {
    if (route.length < 2) {
      return Center(
          child: Text('🗺️  Aucun tracé GPS pour cette sortie',
              style: Theme.of(context).textTheme.bodySmall));
    }
    return CustomPaint(painter: _RoutePainter(route, color), size: Size.infinite);
  }
}

class _RoutePainter extends CustomPainter {
  final List<List<double>> route;
  final Color color;
  _RoutePainter(this.route, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Projection simple : longitude corrigee par cos(latitude), suffisant
    // pour un parcours de quelques kilometres.
    final k = math.cos(route.first[0] * math.pi / 180);
    final pts = [for (final p in route) Offset(p[1] * k, -p[0])];

    var minX = pts.first.dx, maxX = minX, minY = pts.first.dy, maxY = minY;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    const pad = 16.0;
    final w = math.max(maxX - minX, 1e-9), h = math.max(maxY - minY, 1e-9);
    final scale = math.min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h);
    // centre le trace dans la zone
    final dx = (size.width - w * scale) / 2, dy = (size.height - h * scale) / 2;
    Offset map(Offset p) => Offset(dx + (p.dx - minX) * scale, dy + (p.dy - minY) * scale);

    final path = Path()..moveTo(map(pts.first).dx, map(pts.first).dy);
    for (final p in pts.skip(1)) {
      final m = map(p);
      path.lineTo(m.dx, m.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(map(pts.first), 5, Paint()..color = AppColors.green);
    canvas.drawCircle(map(pts.last), 5, Paint()..color = AppColors.red);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.route != route || old.color != color;
}
