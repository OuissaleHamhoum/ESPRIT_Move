/// Un utilisateur (table SQLite "users").
/// Le mot de passe n'est PAS dans cet objet : seul son hash est en base.
class AppUser {
  final int? id;
  final String name;
  final String email;
  final String city;
  final String campus;
  final String cardNumber;
  final String filiere;
  final int cardStatus; // 1 validee, 0 en attente, -1 refusee (par l'admin)
  final Set<String> interests; // en base : "Running,Football,Yoga"
  final String role; // 'student' ou 'admin'
  final int points;
  final bool beaconActive;

  const AppUser({
    this.id,
    required this.name,
    required this.email,
    this.city = '',
    this.campus = '',
    this.cardNumber = '',
    this.filiere = '',
    this.cardStatus = 0,
    this.interests = const {},
    this.role = 'student',
    this.points = 0,
    this.beaconActive = false,
  });

  bool get isAdmin => role == 'admin';
  bool get cardVerified => cardStatus == 1;

  String get cardStatusLabel => cardStatus == 1
      ? 'Carte validée'
      : cardStatus == -1
          ? 'Carte refusée'
          : 'Carte en attente de validation';

  /// Prenom = premier mot du nom ("Mariem Ben Ali" -> "Mariem")
  String get firstName => name.trim().split(' ').first;

  factory AppUser.fromMap(Map<String, dynamic> m) {
    final raw = (m['interests'] as String?) ?? '';
    return AppUser(
      id: m['id'] as int,
      name: m['name'] as String,
      email: m['email'] as String,
      city: (m['city'] as String?) ?? '',
      campus: (m['campus'] as String?) ?? '',
      cardNumber: (m['card_number'] as String?) ?? '',
      filiere: (m['filiere'] as String?) ?? '',
      cardStatus: (m['card_verified'] as int?) ?? 0,
      interests: raw.isEmpty ? <String>{} : raw.split(',').toSet(),
      role: (m['role'] as String?) ?? 'student',
      points: (m['points'] as int?) ?? 0,
      beaconActive: m['beacon_active'] == 1,
    );
  }
}

/// Contact Beacon : un numero de telephone (3 maximum par utilisateur).
class BeaconContact {
  final int id;
  final String phone;
  const BeaconContact(this.id, this.phone);
}

/// Statistiques affichees sur le profil.
class ProfileStats {
  final double km;
  final int activities;
  final int events;
  const ProfileStats(this.km, this.activities, this.events);
}
