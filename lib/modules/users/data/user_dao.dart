import '../../../core/database/app_database.dart';
import '../../../core/utils/security.dart';
import '../models/app_user.dart';

/// Acces SQLite : comptes, profil, contacts Beacon.
class UserDao {
  // ---------- CREATE : inscription ----------
  static Future<bool> emailExists(String email) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        columns: ['id'], where: 'email = ?', whereArgs: [email.toLowerCase()]);
    return rows.isNotEmpty;
  }

  /// Cree le compte. Retourne l'id du nouvel utilisateur.
  static Future<int> signUp({
    required String name,
    required String email,
    required String password,
    required String cardNumber,
    required String filiere,
    required bool cardVerified,
    required String city,
    required String campus,
    required Set<String> interests,
  }) async {
    final db = await AppDatabase.db;
    return db.insert('users', {
      'name': name,
      'email': email.toLowerCase(),
      'password_hash': Security.hash(password), // jamais en clair !
      'card_number': cardNumber,
      'filiere': filiere,
      'card_verified': cardVerified ? 1 : 0,
      'city': city,
      'campus': campus,
      'interests': interests.join(','),
      'role': 'student',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Rejoint des groupes (choisis a l'etape 5 de l'inscription).
  static Future<void> joinGroups(int userId, Iterable<int> groupIds) async {
    final db = await AppDatabase.db;
    for (final g in groupIds) {
      await db.insert('group_members', {'group_id': g, 'user_id': userId});
    }
  }

  /// Groupes proposes a l'etape 5 : (id, nom, pictogramme, nb membres).
  static Future<List<Map<String, Object?>>> suggestedGroups() async {
    final db = await AppDatabase.db;
    return db.query('campus_groups', orderBy: 'id');
  }

  // ---------- READ ----------
  /// Connexion : retourne l'utilisateur si e-mail + mot de passe corrects, sinon null.
  static Future<AppUser?> login(String email, String password) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        where: 'email = ? AND password_hash = ?',
        whereArgs: [email.toLowerCase(), Security.hash(password)]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  static Future<AppUser?> getById(int id) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  /// km total, nombre d'activites, nombre d'evenements (tuiles du profil).
  static Future<ProfileStats> stats(int userId) async {
    final db = await AppDatabase.db;
    final a = (await db.rawQuery(
            'SELECT COALESCE(SUM(distance_km),0) AS km, COUNT(*) AS n '
            'FROM activities WHERE user_id = ?',
            [userId]))
        .first;
    final e = (await db.rawQuery(
            'SELECT COUNT(*) AS n FROM event_participants WHERE user_id = ?',
            [userId]))
        .first;
    return ProfileStats(
        (a['km'] as num).toDouble(), a['n'] as int, e['n'] as int);
  }

  // ---------- UPDATE : ville, interets, contacts Beacon ----------
  /// Met a jour la ville, les interets ET remplace les contacts Beacon
  /// (3 maximum) en une seule transaction.
  static Future<void> updateProfile({
    required int userId,
    required String city,
    required Set<String> interests,
    required List<String> beaconPhones,
  }) async {
    final db = await AppDatabase.db;
    await db.transaction((txn) async {
      await txn.update('users', {'city': city, 'interests': interests.join(',')},
          where: 'id = ?', whereArgs: [userId]);
      await txn.delete('beacon_contacts', where: 'user_id = ?', whereArgs: [userId]);
      // take(3) = regle metier : 3 contacts Beacon maximum
      for (final phone in beaconPhones.take(3)) {
        await txn.insert('beacon_contacts', {'user_id': userId, 'phone': phone});
      }
      // Plus de contact -> le partage Beacon est coupe
      if (beaconPhones.isEmpty) {
        await txn.update('users', {'beacon_active': 0},
            where: 'id = ?', whereArgs: [userId]);
      }
    });
  }

  static Future<List<BeaconContact>> beaconContacts(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('beacon_contacts',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'id');
    return rows.map((r) => BeaconContact(r['id'] as int, r['phone'] as String)).toList();
  }

  /// Active / coupe le partage Beacon. Impossible sans contact (retourne false).
  static Future<bool> setBeaconActive(int userId, bool active) async {
    if (active && (await beaconContacts(userId)).isEmpty) return false;
    final db = await AppDatabase.db;
    await db.update('users', {'beacon_active': active ? 1 : 0},
        where: 'id = ?', whereArgs: [userId]);
    return true;
  }

  /// Mode demo : bascule etudiant <-> administrateur.
  static Future<void> setRole(int userId, String role) async {
    final db = await AppDatabase.db;
    await db.update('users', {'role': role}, where: 'id = ?', whereArgs: [userId]);
  }

  // ---------- DELETE ----------
  /// Supprime le compte. Grace a "ON DELETE CASCADE", ses activites,
  /// reservations, messages, contacts... sont supprimes automatiquement.
  static Future<void> delete(int userId) async {
    final db = await AppDatabase.db;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }
}
