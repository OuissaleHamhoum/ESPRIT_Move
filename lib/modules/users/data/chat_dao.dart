import '../../../core/database/app_database.dart';
import '../models/chat_models.dart';

/// Acces SQLite pour la messagerie par salons.
class ChatDao {
  /// Liste des salons avec le dernier message de chacun.
  static Future<List<ChatRoom>> rooms() async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
      'SELECT r.id, r.name, r.icon, '
      '(SELECT text FROM messages m WHERE m.room_id = r.id ORDER BY m.id DESC LIMIT 1) AS last '
      'FROM rooms r ORDER BY r.id',
    );
    return rows
        .map((r) => ChatRoom(r['id'] as int, r['name'] as String, r['icon'] as String,
            (r['last'] as String?) ?? ''))
        .toList();
  }

  /// Messages d'un salon, du plus ancien au plus recent.
  static Future<List<ChatMessage>> messages(int roomId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
      'SELECT m.id, m.user_id, m.text, m.created_at, u.name AS author '
      'FROM messages m JOIN users u ON u.id = m.user_id '
      'WHERE m.room_id = ? ORDER BY m.id',
      [roomId],
    );
    return rows
        .map((r) => ChatMessage(
              r['id'] as int,
              r['user_id'] as int,
              r['author'] as String,
              r['text'] as String,
              DateTime.tryParse(r['created_at'] as String) ?? DateTime.now(),
            ))
        .toList();
  }

  /// Id du dernier message d'un salon (0 si vide) : sert a detecter
  /// les nouveaux messages sans tout recharger.
  static Future<int> lastId(int roomId) async {
    final db = await AppDatabase.db;
    final r = await db.rawQuery(
        'SELECT COALESCE(MAX(id), 0) AS v FROM messages WHERE room_id = ?', [roomId]);
    return r.first['v'] as int;
  }

  /// Envoie un message.
  static Future<void> send(int roomId, int userId, String text) async {
    final db = await AppDatabase.db;
    await db.insert('messages', {
      'room_id': roomId,
      'user_id': userId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
