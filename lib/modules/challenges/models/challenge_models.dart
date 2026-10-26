/// Defi hebdomadaire (table "challenges") + ma progression.
class Challenge {
  final int id;
  final String title;
  final String measure; // 'km', 'seances' ou 'minutes'
  final double goal;
  final int durationDays;
  final bool joined; // ai-je rejoint ce defi ?
  final double progress; // ma valeur actuelle (km, seances ou minutes)

  const Challenge({
    required this.id,
    required this.title,
    required this.measure,
    required this.goal,
    required this.durationDays,
    required this.joined,
    required this.progress,
  });

  /// Entre 0.0 et 1.0 pour la barre de progression.
  double get ratio => goal <= 0 ? 0 : (progress / goal).clamp(0.0, 1.0);

  String get measureLabel => Measures.unit(measure);
}

/// Une ligne du classement.
class LeaderEntry {
  final int userId;
  final String name;
  final double value;
  const LeaderEntry(this.userId, this.name, this.value);
}

/// Badge (table "badges") ; earned = obtenu par l'utilisateur connecte.
class BadgeItem {
  final int id;
  final String name;
  final String icon;
  final String rule; // 'distance', 'activities' ou 'events'
  final double threshold;
  final bool earned;
  const BadgeItem(this.id, this.name, this.icon, this.rule, this.threshold, this.earned);

  String get condition => BadgeRules.describe(rule, threshold);
}

/// Recompense echangeable contre des points (table "rewards").
class Reward {
  final int id;
  final String name;
  final String icon;
  final int cost;
  const Reward(this.id, this.name, this.icon, this.cost);
}

class Measures {
  static const labels = {'km': 'Distance (km)', 'seances': 'Séances', 'minutes': 'Durée (minutes)'};
  static String unit(String m) => m == 'seances' ? 'séances' : m;
}

class BadgeRules {
  static const labels = {
    'distance': 'Distance (une activité)',
    'activities': 'Nombre d’activités',
    'events': 'Événements rejoints',
  };

  static String describe(String rule, double t) {
    final n = t == t.roundToDouble() ? t.round().toString() : t.toString();
    switch (rule) {
      case 'distance':
        return 'Une activité d’au moins $n km';
      case 'activities':
        return 'Au moins $n activités';
      default:
        return 'Au moins $n événements rejoints';
    }
  }
}

/// Donnees de l'ecran d'accueil (assemblees depuis les autres modules).
class HomeData {
  final String userName;
  final int points;
  final double weekKm;
  final int streak;
  final String? nextEventTitle; // null = aucun evenement a venir
  final String? nextEventInfo;
  final int activeStudents;
  final double campusKm;
  final int eventsCount;
  final List<FeedItem> feed; // fil de la communaute
  const HomeData({
    required this.userName,
    required this.points,
    required this.weekKm,
    required this.streak,
    required this.nextEventTitle,
    required this.nextEventInfo,
    required this.activeStudents,
    required this.campusKm,
    required this.eventsCount,
    required this.feed,
  });

  static const weeklyGoalKm = 40.0; // objectif hebdomadaire du prototype
}

/// Une ligne du fil : pictogramme du sport + phrase.
class FeedItem {
  final String icon;
  final String text;
  const FeedItem(this.icon, this.text);
}

/// Chiffres de l'accueil administrateur.
class AdminSummary {
  final int students;
  final int pendingCards;
  final int activeFacilities;
  final int upcomingBookings;
  final List<FeedItem> today; // reservations du jour
  const AdminSummary({
    required this.students,
    required this.pendingCards,
    required this.activeFacilities,
    required this.upcomingBookings,
    required this.today,
  });
}
