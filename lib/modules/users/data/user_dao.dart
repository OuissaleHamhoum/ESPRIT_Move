import '../../../core/database/app_database.dart';
import '../../../core/services/notification_service.dart';
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
      'card_verified': 0, // en attente de validation par l'admin
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
    return db.rawQuery(
        'SELECT g.id, g.name, g.icon, '
        '(SELECT COUNT(*) FROM group_members gm WHERE gm.group_id = g.id) AS members '
        'FROM campus_groups g ORDER BY g.id');
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
  /// Met a jour le nom, le campus, la ville, les interets ET remplace les contacts Beacon
  /// (3 maximum) en une seule transaction.
  static Future<void> updateProfile({
    required int userId,
    required String name,
    required String campus,
    required String city,
    required Set<String> interests,
    required List<String> beaconPhones,
    String? cardNumber, // null = inchange (ex. compte admin)
  }) async {
    final db = await AppDatabase.db;
    await db.transaction((txn) async {
      final current = await txn.query('users',
          columns: ['card_number'], where: 'id = ?', whereArgs: [userId]);
      final cardChanged = cardNumber != null &&
          current.isNotEmpty &&
          current.first['card_number'] != cardNumber;
      await txn.update('users', {
        'name': name,
        'campus': campus,
        'city': city,
        'interests': interests.join(','),
        // Nouveau numero de carte -> nouvelle validation par l'admin
        if (cardChanged) 'card_number': cardNumber,
        if (cardChanged) 'card_verified': 0,
      },
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

  /// Numero de carte deja utilise par un autre compte ?
  static Future<bool> cardNumberTaken(String cardNumber, {int? exceptUserId}) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        columns: ['id'],
        where: 'LOWER(card_number) = LOWER(?) AND id != ?',
        whereArgs: [cardNumber, exceptUserId ?? -1]);
    return rows.isNotEmpty;
  }

  /// Change le mot de passe. Retourne false si l'ancien est incorrect.
  static Future<bool> changePassword(int userId, String oldPassword, String newPassword) async {
    final db = await AppDatabase.db;
    final n = await db.update('users', {'password_hash': Security.hash(newPassword)},
        where: 'id = ? AND password_hash = ?',
        whereArgs: [userId, Security.hash(oldPassword)]);
    return n == 1;
  }

  // ---------- ADMIN : gestion des comptes ----------
  /// Comptes vus par l'admin. [filter] : 'pending' (cartes a valider),
  /// 'students' ou 'admins'. [search] : nom, e-mail ou numero de carte.
  static Future<List<AppUser>> adminList(String filter, {String search = ''}) async {
    final db = await AppDatabase.db;
    final where = <String>[];
    final args = <Object?>[];
    switch (filter) {
      case 'pending':
        where.add("role = 'student' AND card_verified = 0");
        break;
      case 'admins':
        where.add("role = 'admin'");
        break;
      default:
        where.add("role = 'student'");
    }
    if (search.trim().isNotEmpty) {
      where.add('(LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(card_number) LIKE ?)');
      final s = '%${search.trim().toLowerCase()}%';
      args.addAll([s, s, s]);
    }
    final rows = await db.query('users',
        where: where.join(' AND '), whereArgs: args, orderBy: 'created_at DESC');
    return rows.map(AppUser.fromMap).toList();
  }

  static Future<int> pendingCardsCount() async {
    final db = await AppDatabase.db;
    final r = await db.rawQuery(
        "SELECT COUNT(*) AS v FROM users WHERE role = 'student' AND card_verified = 0");
    return r.first['v'] as int;
  }

  /// Valide (1) ou refuse (-1) la carte etudiante + notification.
  static Future<void> setCardStatus(int userId, int status) async {
    final db = await AppDatabase.db;
    await db.update('users', {'card_verified': status},
        where: 'id = ?', whereArgs: [userId]);
    await NotificationService.notify(
        userId,
        status == 1
            ? '✅ Carte étudiante validée : vous pouvez réserver les terrains.'
            : '⚠️ Carte étudiante refusée : vérifiez le numéro dans Profil > Modifier.');
  }

  /// Nomme administrateur / remet etudiant.
  static Future<void> setRole(int userId, String role) async {
    final db = await AppDatabase.db;
    await db.update('users', {'role': role, if (role == 'admin') 'card_verified': 1},
        where: 'id = ?', whereArgs: [userId]);
  }

  static Future<int> adminCount() async {
    final db = await AppDatabase.db;
    final r = await db.rawQuery("SELECT COUNT(*) AS v FROM users WHERE role = 'admin'");
    return r.first['v'] as int;
  }

  // ---------- DELETE ----------
  /// Supprime le compte. Grace a "ON DELETE CASCADE", ses activites,
  /// reservations, messages, contacts... sont supprimes automatiquement.
  static Future<void> delete(int userId) async {
    final db = await AppDatabase.db;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }
}
