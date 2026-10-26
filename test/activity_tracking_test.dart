import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:esprit_move/core/database/schema.dart';
import 'package:esprit_move/core/utils/format.dart';
import 'package:esprit_move/modules/activities/models/activity.dart';
import 'package:esprit_move/modules/activities/models/progress.dart';
import 'package:esprit_move/modules/activities/tracking/track_recorder.dart';

// Trajectoires synthetiques UNIQUEMENT pour verifier les calculs.
const _lat0 = 36.8988, _lng0 = 10.1897; // campus ESPRIT
const _mPerDegLat = 6371008.8 * math.pi / 180;
final _t0 = DateTime(2026, 10, 26, 8);

GpsFix _fix(double northM, int sec, {double acc = 5, double? alt, double? altAcc}) => GpsFix(
      lat: _lat0 + northM / _mPerDegLat,
      lng: _lng0,
      accuracy: acc,
      time: _t0.add(Duration(seconds: sec)),
      alt: alt,
      altAccuracy: altAcc,
    );

/// Court vers le nord a [speed] m/s, un point par seconde.
void _run(TrackRecorder r, {required int from, required int to, double speed = 3, double startM = 0}) {
  for (var s = from; s <= to; s++) {
    r.addFix(_fix(startM + (s - from) * speed, s));
  }
}

void main() {
  group('TrackRecorder', () {
    test('distance, temps en mouvement et fractionnes sur une ligne droite', () {
      final r = TrackRecorder(type: 'Course', startedAt: _t0);
      _run(r, from: 0, to: 400); // 1200 m en 400 s
      r.finish(_t0.add(const Duration(seconds: 400)));
      expect(r.distanceM, closeTo(1200, 12));
      expect(r.movingS, closeTo(400, 2));
      expect(r.splits.length, 2);
      expect(r.splits.first.distanceM, 1000);
      expect(r.splits.first.movingS, closeTo(333, 2));
      expect(r.splits.last.distanceM, closeTo(200, 12));
      expect(r.avgSpeed, closeTo(3, 0.05));
      expect(r.maxSpeed, closeTo(3, 0.1));
      expect(r.elapsedS(DateTime.now()), 400);
    });

    test('la pause ne compte ni distance ni temps en mouvement', () {
      final r = TrackRecorder(type: 'Course', startedAt: _t0);
      _run(r, from: 0, to: 100); // 300 m
      r.pause(_t0.add(const Duration(seconds: 100)));
      _run(r, from: 101, to: 200, startM: 300); // ignore
      r.resume(_t0.add(const Duration(seconds: 200)));
      _run(r, from: 201, to: 300, startM: 600); // 300 m
      r.finish(_t0.add(const Duration(seconds: 300)));
      expect(r.distanceM, closeTo(600, 6));
      expect(r.movingS, closeTo(200, 3));
      expect(r.elapsedS(DateTime.now()), 300); // duree totale : pauses comprises
    });

    test('points imprecis et sauts GPS ignores', () {
      final r = TrackRecorder(type: 'Marche', startedAt: _t0);
      _run(r, from: 0, to: 100, speed: 1.4);
      r.addFix(_fix(140 + 800, 101)); // saut de 800 m en 1 s
      r.addFix(_fix(5000, 102, acc: 80)); // precision 80 m
      _run(r, from: 103, to: 200, speed: 1.4, startM: 140 + 1.4 * 3);
      expect(r.distanceM, closeTo(1.4 * 200, 5));
    });

    test('immobile avec bruit GPS : 0 m et 0 s en mouvement', () {
      final r = TrackRecorder(type: 'Course', startedAt: _t0);
      final rnd = math.Random(1);
      for (var s = 0; s < 300; s++) {
        r.addFix(_fix(rnd.nextDouble() * 4 - 2, s, acc: 8));
      }
      expect(r.distanceM, 0);
      expect(r.movingS, 0);
      expect(r.currentSpeed(_t0.add(const Duration(seconds: 300))), 0);
      expect(r.avgSpeed, isNull);
    });

    test('perte de signal : la distance du trou est conservee si plausible', () {
      final r = TrackRecorder(type: 'Course', startedAt: _t0);
      _run(r, from: 0, to: 60); // 180 m
      _run(r, from: 120, to: 180, startM: 360); // 60 s sans signal (tunnel)
      expect(r.distanceM, closeTo(540, 6));
      expect(r.movingS, closeTo(180, 3));
    });

    test('denivele : fiable seulement avec une altitude precise', () {
      final up = TrackRecorder(type: 'Randonnée', startedAt: _t0);
      final none = TrackRecorder(type: 'Randonnée', startedAt: _t0);
      for (var s = 0; s <= 300; s++) {
        up.addFix(_fix(s * 1.2, s, alt: 100 + s * 0.1, altAcc: 3)); // +30 m
        none.addFix(_fix(s * 1.2, s));
      }
      expect(up.elevationGain, closeTo(30, 4));
      expect(none.elevationGain, isNull);
    });


    test('barometre : denivele precis, prioritaire sur le GPS, pause exclue', () {
      double hPa(double h) => 1013.25 * math.pow(1 - h / 44330, 5.255);
      final r = TrackRecorder(type: 'Randonnée', startedAt: _t0);
      for (var s = 0; s <= 200; s++) {
        r.addFix(_fix(s * 1.2, s)); // GPS sans altitude
        r.addPressure(hPa(s * 0.1), _t0.add(Duration(seconds: s))); // +20 m
      }
      r.pause(_t0.add(const Duration(seconds: 200)));
      for (var s = 201; s <= 260; s++) {
        r.addPressure(hPa(20 + (s - 200) * 1.0), _t0.add(Duration(seconds: s))); // ignore
      }
      expect(r.usesBarometer, isTrue);
      expect(r.elevationGain, closeTo(20, 2));
      final copy = TrackRecorder.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(copy.elevationGain, r.elevationGain);
    });
    test('sauvegarde / reprise : meme etat apres rejeu', () {
      final r = TrackRecorder(type: 'Vélo', startedAt: _t0);
      _run(r, from: 0, to: 50, speed: 8);
      r.pause(_t0.add(const Duration(seconds: 50)));
      final copy = TrackRecorder.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(copy.distanceM, r.distanceM);
      expect(copy.movingS, r.movingS);
      expect(copy.route, r.route);
      expect(copy.paused, isTrue);
    });
  });

  test('Activity : aller-retour SQLite avec les nouvelles colonnes', () {
    final r = TrackRecorder(type: 'Course', startedAt: _t0);
    _run(r, from: 0, to: 400);
    r.finish(_t0.add(const Duration(seconds: 410)));
    final a = Activity.fromRecorder(r, userId: 1).copyWith(title: 'Test', photos: ['/p/1.jpg']);
    final back = Activity.fromMap({...a.toMap(), 'id': 7});
    expect(back.distanceKm, a.distanceKm);
    expect(back.movingS, a.movingS);
    expect(back.elapsedS, 410);
    expect(back.splits.length, 2);
    expect(back.photos, ['/p/1.jpg']);
    expect(back.avgPaceSecPerKm, closeTo(333, 3));
    // ancienne ligne (v3) sans les colonnes v4
    final old = Activity.fromMap({
      'id': 1, 'user_id': 1, 'type': 'Course', 'title': 'x', 'date': '2026-10-01',
      'distance_km': 5.0, 'duration_min': 25, 'route': '',
    });
    expect(old.movingS, isNull);
    expect(old.avgPaceSecPerKm, 300);
    expect(old.splits, isEmpty);
  });

  test('migration v4 : chaque nouvelle colonne existe aussi dans CREATE TABLE', () {
    final create = Schema.tables.firstWhere((t) => t.contains('CREATE TABLE activities'));
    for (final sql in Schema.migrations[4]!.where((q) => q.startsWith('ALTER'))) {
      final col = RegExp(r'ADD COLUMN (\w+)').firstMatch(sql)!.group(1)!;
      expect(create, contains(col));
    }
  });

  test('Progress : totaux par semaine (lundi) et par mois', () {
    Activity a(String date, double km) =>
        Activity(userId: 1, type: 'Course', title: '', date: date, distanceKm: km, durationMin: 30);
    final list = [a('2026-10-26', 5), a('2026-10-20', 3), a('2026-10-19', 2), a('2026-09-30', 10)];
    final now = DateTime(2026, 10, 26);
    final weeks = Progress.weekly(list, now: now, weeks: 2);
    expect(weeks.map((w) => w.km), [5, 5]); // semaine du 19 : 3 + 2
    final months = Progress.monthly(list, now: now, months: 2);
    expect(months.map((m) => m.km), [10, 10]);
    expect(Progress.records(list).longest!.distanceKm, 10);
  });

  test('Fmt : allure et vitesse', () {
    expect(Fmt.paceSec(318), '5:18');
    expect(Fmt.paceSec(null), '--');
    expect(Fmt.paceFromSpeed(0), '--');
    expect(Fmt.paceFromSpeed(1000 / 300), '5:00');
    expect(Fmt.kmh(10), '36.0');
  });
}
