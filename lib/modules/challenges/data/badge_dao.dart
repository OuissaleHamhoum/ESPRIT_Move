import '../../../core/database/app_database.dart';
import '../models/challenge_models.dart';

/// Acces SQLite pour les badges / certificats et les recompenses.
/// L'attribution automatique des badges est dans core/services/reward_engine.dart.
class BadgeDao {
  /// Tous les badges ; earned = obtenu par userId.
  static Future<List<BadgeItem>> getAll(int? userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('badges', orderBy: 'id');
    final owned = <int>{};
    if (userId != null) {
      final u = await db.query('user_badges', where: 'user_id = ?', whereArgs: [userId]);
      owned.addAll(u.map((r) => r['badge_id'] as int));
    }
    return rows
        .map((r) => BadgeItem(r['id'] as int, r['name'] as String, r['icon'] as String,
            r['rule'] as String, (r['threshold'] as num).toDouble(),
            owned.contains(r['id'])))
        .toList();
  }

  // CREATE (admin)
  static Future<void> insert(String name, String icon, String rule, double threshold) async {
    final db = await AppDatabase.db;
    await db.insert('badges',
        {'name': name, 'icon': icon, 'rule': rule, 'threshold': threshold});
  }

  // DELETE (admin) : supprime aussi les certificats obtenus (CASCADE)
  static Future<void> delete(int id) async {
    final db = await AppDatabase.db;
    await db.delete('badges', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Recompenses ----------
  static Future<List<Reward>> rewards() async {
    final db = await AppDatabase.db;
    final rows = await db.query('rewards', orderBy: 'cost');
    return rows
        .map((r) => Reward(r['id'] as int, r['name'] as String, r['icon'] as String,
            r['cost'] as int))
        .toList();
  }
}
