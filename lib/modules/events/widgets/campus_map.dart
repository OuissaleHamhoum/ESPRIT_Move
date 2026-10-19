import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/campus_event.dart';

/// EV-02 : plan SCHEMATIQUE du campus avec une epingle par evenement.
/// Pas de Google Maps : les lieux ont une position (x, y entre 0 et 1) dans
/// la table "places". Plus simple, fonctionne hors connexion.
class CampusMap extends StatelessWidget {
  final List<CampusEvent> events;
  final ValueChanged<CampusEvent> onPinTap;
  const CampusMap({super.key, required this.events, required this.onPinTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          // Si 2 evenements ont le meme lieu, on decale legerement les epingles.
          final seenPlaces = <int, int>{};
          final pins = <Widget>[];
          for (final e in events.where((e) => !e.isCancelled)) {
            final k = seenPlaces.update(e.placeId, (v) => v + 1, ifAbsent: () => 0);
            final left = (e.mapX + k * 0.05) * w - 16;
            final top = e.mapY * h - 32;
            pins.add(Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: () => onPinTap(e),
                child: Column(children: [
                  const Icon(Icons.location_on, color: AppColors.red, size: 32),
                  Text(e.placeName,
                      style: const TextStyle(fontSize: 10, color: AppColors.grey)),
                ]),
              ),
            ));
          }
          return Stack(children: [
            // Quelques "batiments" decoratifs
            for (final r in const [
              Rect.fromLTWH(0.05, 0.08, 0.2, 0.15),
              Rect.fromLTWH(0.45, 0.05, 0.25, 0.12),
              Rect.fromLTWH(0.75, 0.50, 0.18, 0.2),
            ])
              Positioned(
                left: r.left * w,
                top: r.top * h,
                width: r.width * w,
                height: r.height * h,
                child: Container(
                    decoration: BoxDecoration(
                        color: AppColors.grey.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6))),
              ),
            const Positioned(
                left: 8,
                bottom: 6,
                child: Text('Campus · plan schématique',
                    style: TextStyle(fontSize: 10, color: AppColors.grey))),
            ...pins,
          ]);
        }),
      ),
    );
  }
}
