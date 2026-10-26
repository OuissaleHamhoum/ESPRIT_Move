import '../../../core/database/app_database.dart';
import '../models/campus_event.dart';

/// Acces SQLite pour les groupes du campus.
class GroupDao {
  /// Tous les groupes avec leur nombre reel de membres.
  static Future<List<CampusGroup>> getAll(int? userId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery('''
      SELECT g.id, g.name, g.icon,
        (SELECT COUNT(*) FROM group_members gm WHERE gm.group_id = g.id) AS members,
        (SELECT COUNT(*) FROM group_members gm WHERE gm.group_id = g.id AND gm.user_id = ?) AS joined
      FROM campus_groups g ORDER BY g.id
    ''', [userId ?? -1]);
    return rows
        .map((r) => CampusGroup(r['id'] as int, r['name'] as String,
            r['icon'] as String, r['members'] as int, (r['joined'] as int) > 0))
        .toList();
  }

  static Future<void> join(int groupId, int userId) async {
    final db = await AppDatabase.db;
    await db.insert('group_members', {'group_id': groupId, 'user_id': userId});
  }

  static Future<void> leave(int groupId, int userId) async {
    final db = await AppDatabase.db;
    await db.delete('group_members',
        where: 'group_id = ? AND user_id = ?', whereArgs: [groupId, userId]);
  }
}
