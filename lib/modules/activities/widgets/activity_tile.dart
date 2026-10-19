import 'package:flutter/material.dart';
import '../../../core/utils/format.dart';
import '../models/activity.dart';

/// Une ligne de l'historique : pictogramme, titre, date, distance, duree.
class ActivityTile extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;
  const ActivityTile({super.key, required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Text(ActivityTypes.iconOf(activity.type),
            style: const TextStyle(fontSize: 28)),
        title: Text(activity.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(Fmt.shortDate(activity.date)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${activity.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${activity.durationMin} min',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
