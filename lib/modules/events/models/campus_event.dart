/// Un evenement sportif (table "events" + son lieu + ses participants).
class CampusEvent {
  final int id;
  final String title;
  final String sport;
  final int placeId;
  final String placeName;
  final double mapX; // position de l'epingle sur le plan (0.0 a 1.0)
  final double mapY;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final int capacity;
  final String description;
  final int organizerId;
  final String status; // 'active' ou 'cancelled'
  final int participants; // nombre d'inscrits
  final bool joined; // l'utilisateur connecte est-il inscrit ?

  const CampusEvent({
    required this.id,
    required this.title,
    required this.sport,
    required this.placeId,
    required this.placeName,
    required this.mapX,
    required this.mapY,
    required this.date,
    required this.time,
    required this.capacity,
    required this.description,
    required this.organizerId,
    required this.status,
    required this.participants,
    required this.joined,
  });

  bool get isCancelled => status == 'cancelled';
  bool get isFull => participants >= capacity; // regle : "Complet"

  /// Date + heure de debut de l'evenement.
  DateTime get startsAt => DateTime.parse('${date}T$time');

  /// Deja commence / termine : on ne peut plus s'inscrire.
  bool get isPast => startsAt.isBefore(DateTime.now());

  factory CampusEvent.fromMap(Map<String, dynamic> m) => CampusEvent(
        id: m['id'] as int,
        title: m['title'] as String,
        sport: m['sport'] as String,
        placeId: m['place_id'] as int,
        placeName: m['place_name'] as String,
        mapX: (m['px'] as num).toDouble(),
        mapY: (m['py'] as num).toDouble(),
        date: m['date'] as String,
        time: m['time'] as String,
        capacity: m['capacity'] as int,
        description: (m['description'] as String?) ?? '',
        organizerId: m['organizer_id'] as int,
        status: (m['status'] as String?) ?? 'active',
        participants: m['n'] as int,
        joined: (m['joined'] as int) > 0,
      );
}

/// Lieu du campus (table "places", commune avec le module 4).
class CampusPlace {
  final int id;
  final String name;
  const CampusPlace(this.id, this.name);
}

/// Groupe du campus (table "campus_groups").
class CampusGroup {
  final int id;
  final String name;
  final String icon;
  final int members; // membres de base + inscrits dans l'application
  final bool joined;
  const CampusGroup(this.id, this.name, this.icon, this.members, this.joined);
}

/// Resultat d'une tentative d'inscription a un evenement.
enum JoinResult { ok, full, cancelled, alreadyJoined, past }

class EventSports {
  static const Map<String, String> emoji = {
    'Course': '🏃',
    'Football': '⚽',
    'Basket': '🏀',
    'Yoga': '🧘',
    'Natation': '🏊',
    'Vélo': '🚴',
    'Tennis': '🎾',
    'Muscu': '🏋️',
  };
  static List<String> get all => emoji.keys.toList();
  static String iconOf(String sport) => emoji[sport] ?? '🏅';
}
