import '../../../core/database/app_database.dart';
import '../models/activity.dart';
import 'photo_store.dart';

/// Acces SQLite pour les activites : C-R-U-D.
/// "DAO" = Data Access Object : le SEUL fichier qui ecrit du SQL pour ce module.
/// Les ecrans appellent ces fonctions, jamais sqflite directement.
class ActivityDao {
  /// Colonnes de l'historique : sans le trace, les fractionnes ni les photos
  /// (JSON volumineux inutiles pour la liste et les statistiques).
  static const _listColumns = [
    'id', 'user_id', 'type', 'title', 'notes', 'date', 'distance_km',
    'duration_min', 'start_time', 'end_time', 'elapsed_s', 'moving_s',
    'max_speed', 'elev_gain', 'shared',
  ];

  // ---------- CREATE ----------
  /// Enregistre une activite. Retourne l'id genere.
  static Future<int> insert(Activity a) async {
    final db = await AppDatabase.db;
    return db.insert('activities', a.toMap());
  }

  // ---------- READ ----------
  /// Historique d'un utilisateur, du plus recent au plus ancien (version allegee).
  static Future<List<Activity>> getByUser(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('activities',
        columns: _listColumns,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date DESC, id DESC');
    return rows.map(Activity.fromMap).toList();
  }

  // Detail d'une activite : FriendDao.visible (verifie qui a le droit de la voir).

  // ---------- UPDATE ----------
  /// Modifie une activite (titre, type, notes, photos).
  static Future<int> update(Activity a) async {
    final db = await AppDatabase.db;
    return db.update('activities', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  // ---------- DELETE ----------
  /// Supprime l'activite et ses photos du stockage prive.
  static Future<int> delete(Activity a) async {
    final db = await AppDatabase.db;
    final n = await db.delete('activities', where: 'id = ?', whereArgs: [a.id]);
    await PhotoStore.deleteAll(a.photos);
    return n;
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
