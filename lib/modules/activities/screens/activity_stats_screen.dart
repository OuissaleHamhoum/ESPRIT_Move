import 'package:flutter/material.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/stat_tile.dart';
import '../models/activity.dart';
import '../models/progress.dart';
import '../widgets/bar_chart.dart';

/// Statistiques et progression : totaux, km par semaine et par mois, records.
/// Recoit l'historique deja charge par la liste (aucune requete en plus).
class ActivityStatsScreen extends StatelessWidget {
  final List<Activity> activities;
  const ActivityStatsScreen({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = ActivityStats.of(activities);
    final weeks = Progress.weekly(activities, now: now);
    final months = Progress.monthly(activities, now: now);
    final rec = Progress.records(activities);
    final title = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Depuis le début', style: title),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: StatTile(value: total.km.toStringAsFixed(1), label: 'km')),
            Expanded(child: StatTile(value: '${total.count}', label: 'sorties')),
            Expanded(child: StatTile(value: Fmt.duration(total.minutes), label: 'en mouvement')),
          ]),
          const SizedBox(height: 12),
          _chartCard(context, 'Km par semaine', weeks.last,
              BarChart(
                values: [for (final w in weeks) w.km],
                labels: [for (final w in weeks) '${w.start.day}/${w.start.month}'],
              ),
              'cette semaine'),
          _chartCard(context, 'Km par mois', months.last,
              BarChart(
                values: [for (final m in months) m.km],
                labels: [for (final m in months) Fmt.month(m.start)],
              ),
              'ce mois-ci'),
          const SizedBox(height: 4),
          Text('Records personnels', style: title),
          Card(
            child: Column(children: [
              _record('📏', 'Plus longue distance', rec.longest,
                  (a) => '${a.distanceKm.toStringAsFixed(2)} km'),
              _record('⏱️', 'Plus longue durée', rec.longestTime, (a) => Fmt.duration(a.durationMin)),
              _record('⚡', 'Meilleure allure (≥ 1 km)', rec.bestPace,
                  (a) => '${Fmt.paceSec(a.avgPaceSecPerKm)} /km'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(BuildContext context, String title, Bucket current, Widget chart, String period) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text('${current.km.toStringAsFixed(1)} km · ${current.count} sorties · '
                '${Fmt.duration(current.minutes)} $period',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            chart,
          ]),
        ),
      );

  Widget _record(String icon, String label, Activity? a, String Function(Activity) value) => ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(label),
        subtitle: Text(a == null ? 'Pas encore de sortie' : '${a.title} · ${Fmt.shortDate(a.date)}'),
        trailing: Text(a == null ? '--' : value(a), style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}
