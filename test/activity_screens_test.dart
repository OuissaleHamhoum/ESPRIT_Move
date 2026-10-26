import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esprit_move/core/widgets/stat_tile.dart';
import 'package:esprit_move/modules/activities/models/activity.dart';
import 'package:esprit_move/modules/activities/screens/activity_stats_screen.dart';
import 'package:esprit_move/modules/activities/screens/share_activity_screen.dart';
import 'package:esprit_move/modules/activities/tracking/track_recorder.dart';
import 'package:esprit_move/modules/activities/widgets/activity_map.dart';
import 'package:esprit_move/modules/activities/widgets/activity_metrics.dart';

// Tests d'affichage des ecrans du module 1 (sans GPS ni base de donnees).
Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

const _old = Activity(
    userId: 1, type: 'Course', title: 'Ancienne', date: '2026-10-01', distanceKm: 5, durationMin: 25);

final _full = Activity(
  id: 3,
  userId: 1,
  type: 'Vélo',
  title: 'Tour du lac',
  date: '2026-10-25',
  distanceKm: 2.4,
  durationMin: 8,
  route: const [[36.80, 10.18], [36.81, 10.19], [36.82, 10.18]],
  startTime: DateTime(2026, 10, 25, 7, 30),
  endTime: DateTime(2026, 10, 25, 7, 40),
  elapsedS: 600,
  movingS: 480,
  maxSpeed: 9,
  elevationGain: 12,
  splits: const [KmSplit(1, 1000, 200), KmSplit(2, 1000, 190), KmSplit(3, 400, 90)],
);

void main() {
  testWidgets('Metriques : "indisponible" quand la donnee n’a pas ete mesuree', (t) async {
    await t.pumpWidget(_app(const SingleChildScrollView(child: ActivityMetrics(activity: _old))));
    expect(find.text('5:00 /km'), findsOneWidget); // calculable : 25 min / 5 km
    expect(find.text('indisponible'), findsNWidgets(5)); // depart, arrivee, duree, vmax, denivele
    expect(find.text('Fractionnés'), findsNothing);
  });

  testWidgets('Metriques : horaires, vitesses, denivele et fractionnes', (t) async {
    await t.pumpWidget(_app(SingleChildScrollView(child: ActivityMetrics(activity: _full))));
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('07:40'), findsOneWidget);
    expect(find.text('32.4 km/h'), findsOneWidget); // 9 m/s
    expect(find.text('12 m'), findsOneWidget);
    expect(find.text('Fractionnés'), findsOneWidget);
    expect(find.text('km 2'), findsOneWidget);
    expect(find.text('0.40'), findsOneWidget); // dernier fractionne partiel
    expect(find.text('indisponible'), findsNothing);
  });

  testWidgets('Carte : message clair sans trace GPS', (t) async {
    await t.pumpWidget(_app(const ActivityMap(route: [])));
    expect(find.textContaining('Aucun tracé GPS'), findsOneWidget);
  });

  testWidgets('Partage : apercu modifiable avant la feuille de partage', (t) async {
    await t.binding.setSurfaceSize(const Size(400, 1000)); // taille d'un telephone
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(home: ShareActivityScreen(activity: _full)));
    expect(find.text('Tour du lac'), findsOneWidget);
    expect(find.text('2.40'), findsOneWidget);
    expect(find.text('3:20'), findsOneWidget); // allure 480 s / 2.4 km
    final sw = find.byType(SwitchListTile);
    expect(t.widget<SwitchListTile>(sw).value, isTrue);
    await t.tap(sw);
    await t.pump();
    expect(t.widget<SwitchListTile>(sw).value, isFalse);
    expect(find.text('Bravo ! 💪'), findsOneWidget); // sans trace ni photo
  });

  testWidgets('Statistiques : totaux et records', (t) async {
    await t.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(home: ActivityStatsScreen(activities: [_old, _full])));
    final total = find.ancestor(of: find.text('sorties'), matching: find.byType(StatTile));
    expect(find.descendant(of: total, matching: find.text('7.4')), findsNothing);
    expect(find.descendant(of: find.byType(StatTile).first, matching: find.text('7.4')),
        findsOneWidget); // 5 + 2.4 km depuis le debut
    expect(find.descendant(of: total, matching: find.text('2')), findsOneWidget);
    expect(find.text('Records personnels'), findsOneWidget);
    expect(find.text('5.00 km'), findsOneWidget);
  });
}
