import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/notification_service.dart';
import '../models/activity.dart';

/// Lien entre l'utilisateur connecte et un autre compte.
enum FriendStatus { none, sent, received, friends }

class FriendUser {
  final int id;
  final String name;
  final String email;
  final FriendStatus status;
  const FriendUser(this.id, this.name, this.email, this.status);
}

/// Amis et fil d'activite (table "friendships").
/// Tous les comptes de l'application partagent la meme base SQLite :
/// deux etudiants qui se connectent sur l'app se voient entre eux.
class FriendDao {
  /// Ids des amis confirmes de [me] (sous-requete SQL, 2 parametres : me, me).
  static const _friendIds =
      "SELECT friend_id FROM friendships WHERE user_id = ? AND status = 'accepted' "
      "UNION SELECT user_id FROM friendships WHERE friend_id = ? AND status = 'accepted'";

  static const _feedColumns =
      'a.id, a.user_id, a.type, a.title, a.notes, a.date, a.distance_km, a.duration_min, '
      'a.start_time, a.end_time, a.elapsed_s, a.moving_s, a.max_speed, a.elev_gain, a.shared';

  /// Statut de chaque compte lie a [me].
  static Future<Map<int, FriendStatus>> _links(DatabaseExecutor db, int me) async {
    final rows = await db.query('friendships',
        where: 'user_id = ? OR friend_id = ?', whereArgs: [me, me]);
    return {
      for (final r in rows)
        (r['user_id'] == me ? r['friend_id'] : r['user_id']) as int: r['status'] == 'accepted'
            ? FriendStatus.friends
            : (r['user_id'] == me ? FriendStatus.sent : FriendStatus.received),
    };
  }

  static List<FriendUser> _users(List<Map<String, Object?>> rows, Map<int, FriendStatus> links) => [
        for (final r in rows)
          FriendUser(r['id'] as int, r['name'] as String, r['email'] as String,
              links[r['id']] ?? FriendStatus.none),
      ];

  /// Comptes etudiants dont le nom ou l'email contient [query].
  static Future<List<FriendUser>> search(int me, String query) async {
    final db = await AppDatabase.db;
    final q = '%${query.trim()}%';
    final rows = await db.query('users',
        columns: ['id', 'name', 'email'],
        where: "id <> ? AND role <> 'admin' AND (name LIKE ? OR email LIKE ?)",
        whereArgs: [me, q, q],
        orderBy: 'name COLLATE NOCASE',
        limit: 30);
    return _users(rows, await _links(db, me));
  }

  /// Amis, demandes recues et envoyees (un seul aller-retour en base).
  static Future<List<FriendUser>> related(int me) async {
    final db = await AppDatabase.db;
    final links = await _links(db, me);
    if (links.isEmpty) return const [];
    final rows = await db.query('users',
        columns: ['id', 'name', 'email'],
        where: 'id IN (${List.filled(links.length, '?').join(',')})',
        whereArgs: links.keys.toList(),
        orderBy: 'name COLLATE NOCASE');
    return _users(rows, links);
  }

  /// Envoie une demande. Si l'autre m'avait deja invite : on devient amis.
  static Future<void> request(int me, String myName, int other) async {
    final db = await AppDatabase.db;
    await db.transaction((txn) async {
      final reverse = await txn.query('friendships',
          where: 'user_id = ? AND friend_id = ?', whereArgs: [other, me]);
      if (reverse.isNotEmpty) {
        await _accept(txn, me, myName, other);
        return;
      }
      final n = await txn.insert(
          'friendships',
          {'user_id': me, 'friend_id': other, 'status': 'pending', 'created_at': _now()},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (n > 0) {
        await NotificationService.notify(other, '👋 $myName vous a envoyé une demande d’ami.', txn: txn);
      }
    });
  }

  /// Accepte la demande recue de [from].
  static Future<void> accept(int me, String myName, int from) async {
    final db = await AppDatabase.db;
    await db.transaction((txn) => _accept(txn, me, myName, from));
  }

  static Future<void> _accept(Transaction txn, int me, String myName, int from) async {
    final n = await txn.update('friendships', {'status': 'accepted'},
        where: "user_id = ? AND friend_id = ? AND status = 'pending'", whereArgs: [from, me]);
    if (n > 0) {
      await NotificationService.notify(from, '🤝 $myName a accepté votre demande d’ami.', txn: txn);
    }
  }

  /// Refuser, annuler une demande ou retirer un ami.
  static Future<void> remove(int me, int other) async {
    final db = await AppDatabase.db;
    await db.delete('friendships',
        where: '(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)',
        whereArgs: [me, other, other, me]);
  }

  /// Fil : sorties partagees par mes amis, les plus recentes d'abord.
  static Future<List<Activity>> feed(int me, {int limit = 100}) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        'SELECT $_feedColumns, u.name AS author FROM activities a '
        'JOIN users u ON u.id = a.user_id '
        'WHERE a.shared = 1 AND a.user_id IN ($_friendIds) '
        'ORDER BY a.date DESC, a.id DESC LIMIT ?',
        [me, me, limit]);
    return rows.map(Activity.fromMap).toList();
  }

  /// Une sortie, seulement si [me] a le droit de la voir :
  /// la sienne, ou celle d'un ami qui l'a partagee. Sinon null.
  static Future<Activity?> visible(int activityId, int me) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        'SELECT a.*, u.name AS author FROM activities a JOIN users u ON u.id = a.user_id '
        'WHERE a.id = ? AND (a.user_id = ? OR (a.shared = 1 AND a.user_id IN ($_friendIds)))',
        [activityId, me, me, me]);
    return rows.isEmpty ? null : Activity.fromMap(rows.first);
  }

  static String _now() => DateTime.now().toIso8601String();
}
