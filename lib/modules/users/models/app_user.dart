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
  final bool cardVerified;
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
    this.cardVerified = false,
    this.interests = const {},
    this.role = 'student',
    this.points = 0,
    this.beaconActive = false,
  });

  bool get isAdmin => role == 'admin';

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
      cardVerified: m['card_verified'] == 1,
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
