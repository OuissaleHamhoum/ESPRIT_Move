import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// Notifications enregistrees en base (table "notifications").
/// Utilisees quand l'ADMINISTRATION agit sur le compte d'un etudiant :
/// reservation annulee, terrain ferme, carte etudiante validee / refusee...
class NotificationService {
  /// Ajoute une notification. [txn] : a passer si l'appel est fait
  /// a l'interieur d'une transaction.
  static Future<void> notify(int userId, String text, {DatabaseExecutor? txn}) async {
    final db = txn ?? await AppDatabase.db;
    await db.insert('notifications', {
      'user_id': userId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Notifications d'un utilisateur, de la plus recente a la plus ancienne.
  static Future<List<StoredNotification>> forUser(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('notifications',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'id DESC', limit: 50);
    return rows
        .map((r) => StoredNotification(
              r['text'] as String,
              DateTime.parse(r['created_at'] as String),
              r['is_read'] == 1,
            ))
        .toList();
  }

  static Future<int> unreadCount(int userId) async {
    final db = await AppDatabase.db;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS v FROM notifications WHERE user_id = ? AND is_read = 0',
        [userId]);
    return r.first['v'] as int;
  }

  static Future<void> markAllRead(int userId) async {
    final db = await AppDatabase.db;
    await db.update('notifications', {'is_read': 1},
        where: 'user_id = ? AND is_read = 0', whereArgs: [userId]);
  }
}

class StoredNotification {
  final String text;
  final DateTime createdAt;
  final bool read;
  const StoredNotification(this.text, this.createdAt, this.read);
}
