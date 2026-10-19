import '../database/app_database.dart';

/// Points et badges : regles metier PARTAGEES (PDF, module 5).
///
///   10 points par km | 50 par evenement | 100 par badge | 100 a l'inscription
///
/// Les modules appellent ces fonctions apres leurs actions :
///   - Module 1 (Activites)  -> RewardEngine.onActivityCreated(...)
///   - Module 3 (Evenements) -> RewardEngine.onEventJoined(...) / onEventLeft(...)
///   - Module 2 (Users)      -> RewardEngine.addPoints(id, signupPoints)
///   - Module 5 (Recompenses)-> RewardEngine.spend(...)
class RewardEngine {
  static const pointsPerKm = 10;
  static const pointsPerEvent = 50;
  static const pointsPerBadge = 100;
  static const signupPoints = 100;

  static Future<void> addPoints(int userId, int pts) async {
    final db = await AppDatabase.db;
    // MAX(0, ...) : le solde ne devient jamais negatif
    await db.rawUpdate(
        'UPDATE users SET points = MAX(0, points + ?) WHERE id = ?',
        [pts, userId]);
  }

  static Future<int> balance(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        columns: ['points'], where: 'id = ?', whereArgs: [userId]);
    return rows.isEmpty ? 0 : (rows.first['points'] as int? ?? 0);
  }

  /// Depense des points. Retourne false si le solde est insuffisant.
  static Future<bool> spend(int userId, int cost) async {
    if (await balance(userId) < cost) return false;
    await addPoints(userId, -cost);
    return true;
  }

  /// Apres l'enregistrement d'une activite. Retourne les badges gagnes.
  static Future<List<String>> onActivityCreated(int userId, double km) async {
    await addPoints(userId, (km * pointsPerKm).round());
    return checkBadges(userId);
  }

  static Future<List<String>> onEventJoined(int userId) async {
    await addPoints(userId, pointsPerEvent);
    return checkBadges(userId);
  }

  static Future<void> onEventLeft(int userId) =>
      addPoints(userId, -pointsPerEvent);

  /// Verifie les regles de chaque badge et attribue ceux qui sont atteints.
  ///   distance   : une activite d'au moins `threshold` km
  ///   activities : au moins `threshold` activites
  ///   events     : au moins `threshold` evenements rejoints
  static Future<List<String>> checkBadges(int userId) async {
    final db = await AppDatabase.db;

    final maxKm = (await db.rawQuery(
            'SELECT COALESCE(MAX(distance_km),0) AS v FROM activities WHERE user_id = ?',
            [userId]))
        .first['v'] as num;
    final nbActivities = (await db.rawQuery(
            'SELECT COUNT(*) AS v FROM activities WHERE user_id = ?', [userId]))
        .first['v'] as int;
    final nbEvents = (await db.rawQuery(
            'SELECT COUNT(*) AS v FROM event_participants WHERE user_id = ?',
            [userId]))
        .first['v'] as int;

    final owned = (await db
            .query('user_badges', where: 'user_id = ?', whereArgs: [userId]))
        .map((r) => r['badge_id'] as int)
        .toSet();

    final newOnes = <String>[];
    for (final b in await db.query('badges')) {
      final id = b['id'] as int;
      if (owned.contains(id)) continue;

      final double value;
      switch (b['rule']) {
        case 'distance':
          value = maxKm.toDouble();
          break;
        case 'activities':
          value = nbActivities.toDouble();
          break;
        default: // 'events'
          value = nbEvents.toDouble();
      }

      if (value >= (b['threshold'] as num).toDouble()) {
        await db.insert('user_badges', {
          'user_id': userId,
          'badge_id': id,
          'earned_at': DateTime.now().toIso8601String(),
        });
        await addPoints(userId, pointsPerBadge);
        newOnes.add(b['name'] as String);
      }
    }
    return newOnes;
  }
}
