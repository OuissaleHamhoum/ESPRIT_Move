import 'dart:convert';
import '../tracking/track_recorder.dart';

/// Une activite sportive (table SQLite "activities").
/// Les champs ajoutes en v4 (horaires, temps en mouvement, vitesses,
/// fractionnes, denivele, photos) sont null / vides pour les anciennes sorties.
class Activity {
  final int? id; // null tant que l'activite n'est pas enregistree en base
  final int userId;
  final String type; // voir ActivityTypes
  final String title;
  final String notes;
  final String date; // "yyyy-MM-dd"
  final double distanceKm;
  final int durationMin; // temps en mouvement, en minutes

  /// Trace GPS : liste de points [latitude, longitude] (vide si pas de GPS).
  final List<List<double>> route;

  final DateTime? startTime;
  final DateTime? endTime;
  final int? elapsedS; // depart -> arrivee, pauses comprises
  final int? movingS; // temps reellement en mouvement
  final double? maxSpeed; // m/s, null si pas fiable
  final double? elevationGain; // m, null si altitude pas fiable
  final List<KmSplit> splits;
  final List<String> photos; // chemins dans le stockage prive
  final bool shared; // visible par les amis
  final String? authorName; // rempli pour le fil des amis (jointure), jamais enregistre

  const Activity({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.notes = '',
    required this.date,
    this.distanceKm = 0,
    this.durationMin = 0,
    this.route = const [],
    this.startTime,
    this.endTime,
    this.elapsedS,
    this.movingS,
    this.maxSpeed,
    this.elevationGain,
    this.splits = const [],
    this.photos = const [],
    this.shared = true,
    this.authorName,
  });

  /// Construit l'activite a partir d'un enregistrement GPS termine.
  factory Activity.fromRecorder(TrackRecorder r, {required int userId}) {
    final end = r.finishedAt ?? DateTime.now();
    final km = double.parse(r.km.toStringAsFixed(2));
    return Activity(
      userId: userId,
      type: r.type,
      title: '',
      date: '${r.startedAt.year}-${_two(r.startedAt.month)}-${_two(r.startedAt.day)}',
      distanceKm: km,
      durationMin: (r.movingS / 60).round(),
      route: List.of(r.route),
      startTime: r.startedAt,
      endTime: end,
      elapsedS: r.elapsedS(end),
      movingS: r.movingS.round(),
      maxSpeed: r.maxSpeed,
      elevationGain: r.elevationGain,
      splits: List.of(r.splits),
    );
  }

  /// Estimation du prototype : 8 kcal par minute (PDF, module 1).
  int get calories => durationMin * 8;

  /// Secondes utilisees pour l'allure : temps en mouvement si connu.
  int get _paceSeconds => movingS ?? durationMin * 60;

  /// Allure moyenne en s/km, null si la distance ou le temps est trop faible.
  int? get avgPaceSecPerKm =>
      (distanceKm < 0.05 || _paceSeconds < 30) ? null : (_paceSeconds / distanceKm).round();

  /// Vitesse moyenne en km/h, null si pas fiable.
  double? get avgSpeedKmh =>
      (distanceKm < 0.05 || _paceSeconds < 30) ? null : distanceKm / (_paceSeconds / 3600);

  Activity copyWith(
          {String? type, String? title, String? notes, List<String>? photos, bool? shared}) =>
      Activity(
        id: id,
        userId: userId,
        type: type ?? this.type,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        date: date,
        distanceKm: distanceKm,
        durationMin: durationMin,
        route: route,
        startTime: startTime,
        endTime: endTime,
        elapsedS: elapsedS,
        movingS: movingS,
        maxSpeed: maxSpeed,
        elevationGain: elevationGain,
        splits: splits,
        photos: photos ?? this.photos,
        shared: shared ?? this.shared,
        authorName: authorName,
      );

  /// Objet -> ligne SQLite
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'notes': notes,
        'date': date,
        'distance_km': distanceKm,
        'duration_min': durationMin,
        'route': jsonEncode(route),
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'elapsed_s': elapsedS,
        'moving_s': movingS,
        'max_speed': maxSpeed,
        'elev_gain': elevationGain,
        'splits': jsonEncode([for (final s in splits) s.toJson()]),
        'photos': jsonEncode(photos),
        'shared': shared ? 1 : 0,
      };

  /// Ligne SQLite -> objet. Les colonnes absentes (requete allegee de la
  /// liste, anciennes lignes) donnent des valeurs vides.
  factory Activity.fromMap(Map<String, dynamic> m) => Activity(
        id: m['id'] as int,
        userId: m['user_id'] as int,
        type: m['type'] as String,
        title: m['title'] as String,
        notes: (m['notes'] as String?) ?? '',
        date: m['date'] as String,
        distanceKm: (m['distance_km'] as num).toDouble(),
        durationMin: m['duration_min'] as int,
        route: _decodeList(m['route'], (p) => (p as List).map((v) => (v as num).toDouble()).toList()),
        startTime: DateTime.tryParse((m['start_time'] as String?) ?? ''),
        endTime: DateTime.tryParse((m['end_time'] as String?) ?? ''),
        elapsedS: m['elapsed_s'] as int?,
        movingS: m['moving_s'] as int?,
        maxSpeed: (m['max_speed'] as num?)?.toDouble(),
        elevationGain: (m['elev_gain'] as num?)?.toDouble(),
        splits: _decodeList(m['splits'], (s) => KmSplit.fromJson(s as List)),
        photos: _decodeList(m['photos'], (s) => s as String),
        shared: ((m['shared'] as int?) ?? 1) == 1,
        authorName: m['author'] as String?,
      );

  static List<T> _decodeList<T>(Object? json, T Function(dynamic) item) {
    if (json is! String || json.isEmpty) return const [];
    return (jsonDecode(json) as List).map(item).toList();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// Les sports avec leur pictogramme. Les 4 sports suivis au GPS sont en tete.
class ActivityTypes {
  static const Map<String, String> emoji = {
    'Course': '🏃',
    'Marche': '🚶',
    'Vélo': '🚴',
    'Randonnée': '🥾',
    'Muscu': '🏋️',
    'Football': '⚽',
    'Natation': '🏊',
  };

  static List<String> get all => emoji.keys.toList();
  static String iconOf(String type) => emoji[type] ?? '🏅';
}

/// Totaux d'une periode (tuiles de ACT-01, statistiques).
class ActivityStats {
  final double km;
  final int count;
  final int minutes;
  const ActivityStats(this.km, this.count, this.minutes);

  /// Somme des activites dont la date est dans [from, to] (format yyyy-MM-dd).
  factory ActivityStats.of(Iterable<Activity> list, {String? from, String? to}) {
    var km = 0.0, n = 0, min = 0;
    for (final a in list) {
      if (from != null && a.date.compareTo(from) < 0) continue;
      if (to != null && a.date.compareTo(to) > 0) continue;
      km += a.distanceKm;
      n++;
      min += a.durationMin;
    }
    return ActivityStats(km, n, min);
  }
}
