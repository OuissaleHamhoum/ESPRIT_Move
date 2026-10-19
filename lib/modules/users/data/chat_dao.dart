import '../../../core/database/app_database.dart';
import '../models/chat_models.dart';

/// Acces SQLite pour la messagerie par salons.
class ChatDao {
  /// Liste des salons avec le dernier message de chacun.
  static Future<List<ChatRoom>> rooms() async {
    final db = await AppDatabase.db;
    final rooms = await db.query('rooms', orderBy: 'id');
    final result = <ChatRoom>[];
    for (final r in rooms) {
      final last = await db.query('messages',
          columns: ['text'],
          where: 'room_id = ?',
          whereArgs: [r['id']],
          orderBy: 'id DESC',
          limit: 1);
      result.add(ChatRoom(r['id'] as int, r['name'] as String, r['icon'] as String,
          last.isEmpty ? '' : last.first['text'] as String));
    }
    return result;
  }

  /// Messages d'un salon, du plus ancien au plus recent.
  static Future<List<ChatMessage>> messages(int roomId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
      'SELECT m.id, m.user_id, m.text, u.name AS author '
      'FROM messages m JOIN users u ON u.id = m.user_id '
      'WHERE m.room_id = ? ORDER BY m.id',
      [roomId],
    );
    return rows
        .map((r) => ChatMessage(r['id'] as int, r['user_id'] as int,
            r['author'] as String, r['text'] as String))
        .toList();
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

  /// PROTOTYPE : simule la reponse d'un autre etudiant (comme dans le PDF :
  /// "Envoyer -> reponse apres 1 s"). Sans serveur, il n'y a pas de vrai
  /// temps reel : voir GUIDE.md pour une evolution avec Firebase / WebSocket.
  static Future<void> simulateReply(int roomId, int myUserId) async {
    final db = await AppDatabase.db;
    final others = await db.query('users',
        columns: ['id'], where: 'id != ?', whereArgs: [myUserId], limit: 1);
    if (others.isEmpty) return;
    await send(roomId, others.first['id'] as int, 'Super, à tout à l’heure ! 👍');
  }
}
