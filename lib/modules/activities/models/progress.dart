import 'activity.dart';

/// Totaux d'une periode (une semaine ou un mois) pour les graphiques.
class Bucket {
  final DateTime start;
  final double km;
  final int minutes;
  final int count;
  const Bucket(this.start, this.km, this.minutes, this.count);
}

/// Records personnels (null si aucune sortie ne s'y prete).
class Records {
  final Activity? longest;
  final Activity? longestTime;
  final Activity? bestPace; // sorties d'au moins 1 km
  const Records(this.longest, this.longestTime, this.bestPace);
}

/// Calculs de progression a partir de l'historique (fonctions pures, testees).
class Progress {
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Lundi de la semaine de [d].
  static DateTime weekStart(DateTime d) => _day(d).subtract(Duration(days: d.weekday - 1));

  /// [weeks] dernieres semaines (lundi -> dimanche), la plus ancienne en premier.
  static List<Bucket> weekly(Iterable<Activity> list, {required DateTime now, int weeks = 8}) {
    final first = weekStart(now).subtract(Duration(days: 7 * (weeks - 1)));
    final starts = [for (var i = 0; i < weeks; i++) first.add(Duration(days: 7 * i))];
    return _bucket(list, starts, (d) => weekStart(d));
  }

  /// [months] derniers mois calendaires, le plus ancien en premier.
  static List<Bucket> monthly(Iterable<Activity> list, {required DateTime now, int months = 6}) {
    final starts = [for (var i = months - 1; i >= 0; i--) DateTime(now.year, now.month - i)];
    return _bucket(list, starts, (d) => DateTime(d.year, d.month));
  }

  static List<Bucket> _bucket(
      Iterable<Activity> list, List<DateTime> starts, DateTime Function(DateTime) keyOf) {
    final km = <DateTime, double>{}, min = <DateTime, int>{}, n = <DateTime, int>{};
    for (final a in list) {
      final k = keyOf(DateTime.parse(a.date));
      km[k] = (km[k] ?? 0) + a.distanceKm;
      min[k] = (min[k] ?? 0) + a.durationMin;
      n[k] = (n[k] ?? 0) + 1;
    }
    return [for (final s in starts) Bucket(s, km[s] ?? 0, min[s] ?? 0, n[s] ?? 0)];
  }

  static Records records(Iterable<Activity> list) {
    Activity? longest, longestTime, bestPace;
    for (final a in list) {
      if (a.distanceKm > 0 && (longest == null || a.distanceKm > longest.distanceKm)) longest = a;
      if (a.durationMin > 0 && (longestTime == null || a.durationMin > longestTime.durationMin)) {
        longestTime = a;
      }
      final p = a.avgPaceSecPerKm;
      if (a.distanceKm >= 1 && p != null && (bestPace == null || p < bestPace.avgPaceSecPerKm!)) {
        bestPace = a;
      }
    }
    return Records(longest, longestTime, bestPace);
  }
}
