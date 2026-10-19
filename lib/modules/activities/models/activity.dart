/// Une activite sportive (table SQLite "activities").
class Activity {
  final int? id; // null tant que l'activite n'est pas enregistree en base
  final int userId;
  final String type; // Course, Vélo, Marche, Muscu, Football, Natation
  final String title;
  final String notes;
  final String date; // "yyyy-MM-dd"
  final double distanceKm;
  final int durationMin;

  const Activity({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.notes = '',
    required this.date,
    this.distanceKm = 0,
    this.durationMin = 0,
  });

  /// Estimation du prototype : 8 kcal par minute (PDF, module 1).
  int get calories => durationMin * 8;

  /// Copie avec quelques champs modifies (utilise pour la modification ACT-03).
  Activity copyWith({String? type, String? title, String? notes}) => Activity(
        id: id,
        userId: userId,
        type: type ?? this.type,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        date: date,
        distanceKm: distanceKm,
        durationMin: durationMin,
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
      };

  /// Ligne SQLite -> objet
  factory Activity.fromMap(Map<String, dynamic> m) => Activity(
        id: m['id'] as int,
        userId: m['user_id'] as int,
        type: m['type'] as String,
        title: m['title'] as String,
        notes: (m['notes'] as String?) ?? '',
        date: m['date'] as String,
        distanceKm: (m['distance_km'] as num).toDouble(),
        durationMin: m['duration_min'] as int,
      );
}

/// Les 6 sports du PDF avec leur pictogramme.
class ActivityTypes {
  static const Map<String, String> emoji = {
    'Course': '🏃',
    'Vélo': '🚴',
    'Marche': '🚶',
    'Muscu': '🏋️',
    'Football': '⚽',
    'Natation': '🏊',
  };

  static List<String> get all => emoji.keys.toList();
  static String iconOf(String type) => emoji[type] ?? '🏅';

  /// Vitesse moyenne (km/h) utilisee pour SIMULER la distance en direct.
  /// A remplacer par le GPS (package geolocator) - voir GUIDE.md.
  static const Map<String, double> demoSpeedKmh = {
    'Course': 10,
    'Vélo': 20,
    'Marche': 5,
    'Muscu': 0,
    'Football': 4,
    'Natation': 2,
  };
}

/// Statistiques des 7 derniers jours (tuiles de ACT-01).
class ActivityStats {
  final double km;
  final int count;
  final int minutes;
  const ActivityStats(this.km, this.count, this.minutes);
}
