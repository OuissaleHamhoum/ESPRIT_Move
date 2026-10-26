import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../models/campus_event.dart';

/// Une ligne de la liste des evenements (EV-01 et sous la carte EV-02).
class EventTile extends StatelessWidget {
  final CampusEvent event;
  final VoidCallback onTap;
  const EventTile({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Text(EventSports.iconOf(event.sport), style: const TextStyle(fontSize: 28)),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${Fmt.shortDate(event.date)} · ${event.time} · ${event.placeName}\n'
          '${event.participants}/${event.capacity} inscrits',
        ),
        isThreeLine: true,
        trailing: event.isCancelled
            ? const _Tag('Annulé', AppColors.grey)
            : event.isPast
            ? const _Tag('Terminé', AppColors.grey)
            : event.joined
            ? const _Tag('Inscrit', AppColors.green)
            : event.isFull
            ? const _Tag('Complet', AppColors.gold)
            : null,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 12)),
  );
}
