import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import '../models/activity.dart';

/// Acces SQLite pour les activites : C-R-U-D.
/// "DAO" = Data Access Object : le SEUL fichier qui ecrit du SQL pour ce module.
/// Les ecrans appellent ces fonctions, jamais sqflite directement.
class ActivityDao {
  // ---------- CREATE ----------
  /// Enregistre une activite. Retourne l'id genere.
  static Future<int> insert(Activity a) async {
    final db = await AppDatabase.db;
    return db.insert('activities', a.toMap());
  }

  // ---------- READ ----------
  /// Historique d'un utilisateur, du plus recent au plus ancien.
  static Future<List<Activity>> getByUser(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('activities',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date DESC, id DESC');
    return rows.map(Activity.fromMap).toList();
  }

  /// Detail d'une activite (null si elle n'existe plus).
  static Future<Activity?> getById(int id) async {
    final db = await AppDatabase.db;
    final rows = await db.query('activities', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Activity.fromMap(rows.first);
  }

  /// km / nombre de sorties / minutes sur les 7 derniers jours.
  static Future<ActivityStats> last7Days(int userId) async {
    final db = await AppDatabase.db;
    final since = Fmt.dbDate(DateTime.now().subtract(const Duration(days: 6)));
    final r = (await db.rawQuery(
      'SELECT COALESCE(SUM(distance_km),0) AS km, COUNT(*) AS n, '
      'COALESCE(SUM(duration_min),0) AS min '
      'FROM activities WHERE user_id = ? AND date >= ?',
      [userId, since],
    ))
        .first;
    return ActivityStats(
        (r['km'] as num).toDouble(), r['n'] as int, (r['min'] as num).toInt());
  }

  // ---------- UPDATE ----------
  /// Modifie une activite (titre, type, notes).
  static Future<int> update(Activity a) async {
    final db = await AppDatabase.db;
    return db.update('activities', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  // ---------- DELETE ----------
  static Future<int> delete(int id) async {
    final db = await AppDatabase.db;
    return db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Lecture d'une donnee du module 2 (affichage seulement) ----------
  /// Le partage Beacon est-il actif ? (affiche sur REC-01 et REC-03)
  static Future<bool> isBeaconActive(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        columns: ['beacon_active'], where: 'id = ?', whereArgs: [userId]);
    return rows.isNotEmpty && rows.first['beacon_active'] == 1;
  }
}
