import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../models/activity.dart';

/// Detail chiffre d'une sortie (recap REC-05 et detail ACT-02) +
/// fractionnes par kilometre. Une valeur non mesurable s'affiche
/// "indisponible" : rien n'est estime ni invente.
class ActivityMetrics extends StatelessWidget {
  final Activity activity;
  const ActivityMetrics({super.key, required this.activity});

  static const _na = 'indisponible';

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final rows = <(String, String)>[
      ('Sport', '${ActivityTypes.iconOf(a.type)} ${a.type}'),
      ('Date', Fmt.shortDate(a.date)),
      ('Départ', a.startTime == null ? _na : Fmt.hm(a.startTime!)),
      ('Arrivée', a.endTime == null ? _na : Fmt.hm(a.endTime!)),
      ('Durée totale', a.elapsedS == null ? _na : Fmt.clock(a.elapsedS!)),
      ('Temps en mouvement', a.movingS == null ? Fmt.duration(a.durationMin) : Fmt.clock(a.movingS!)),
      ('Distance', '${a.distanceKm.toStringAsFixed(2)} km'),
      ('Allure moyenne', a.avgPaceSecPerKm == null ? _na : '${Fmt.paceSec(a.avgPaceSecPerKm)} /km'),
      ('Vitesse moyenne', a.avgSpeedKmh == null ? _na : '${a.avgSpeedKmh!.toStringAsFixed(1)} km/h'),
      ('Vitesse max', a.maxSpeed == null ? _na : '${Fmt.kmh(a.maxSpeed)} km/h'),
      ('Dénivelé positif', a.elevationGain == null ? _na : '${a.elevationGain!.round()} m'),
    ];
    final small = Theme.of(context).textTheme.bodySmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(label, style: small)),
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: value == _na ? AppColors.grey : null)),
                ]),
              ),
            if (a.splits.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Fractionnés', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              _SplitBars(activity: a),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une barre par km : plus elle est longue, plus le km a ete rapide.
class _SplitBars extends StatelessWidget {
  final Activity activity;
  const _SplitBars({required this.activity});

  @override
  Widget build(BuildContext context) {
    final splits = activity.splits;
    final best = splits.map((s) => s.paceSecPerKm).where((p) => p > 0).fold<int>(1 << 30, (m, p) => p < m ? p : m);
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(children: [
      for (final s in splits)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(
                width: 48,
                child: Text(s.distanceM >= 999 ? 'km ${s.index}' : (s.distanceM / 1000).toStringAsFixed(2),
                    style: small)),
            SizedBox(width: 48, child: Text(Fmt.paceSec(s.paceSecPerKm), style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 10,
                    width: s.paceSecPerKm <= 0 ? 0 : c.maxWidth * best / s.paceSecPerKm,
                    decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: s.paceSecPerKm == best ? 1 : 0.55),
                        borderRadius: BorderRadius.circular(5)),
                  ),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}
