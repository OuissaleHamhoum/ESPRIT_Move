import '../../../core/database/app_database.dart';
import '../models/campus_event.dart';

/// Acces SQLite pour les evenements : C-R-U-D + rejoindre / quitter.
class EventDao {
  // Requete commune : evenement + lieu + nb d'inscrits + "suis-je inscrit ?"
  static const _selectSql = '''
    SELECT e.*, p.name AS place_name, p.x AS px, p.y AS py,
      (SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = e.id) AS n,
      (SELECT COUNT(*) FROM event_participants ep
         WHERE ep.event_id = e.id AND ep.user_id = ?) AS joined
    FROM events e JOIN places p ON p.id = e.place_id
  ''';

  // ---------- READ ----------
  /// Tous les evenements, du plus proche au plus lointain.
  /// userId = null pour un visiteur (joined sera toujours false).
  static Future<List<CampusEvent>> getAll(int? userId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        '$_selectSql ORDER BY e.date, e.time', [userId ?? -1]);
    return rows.map(CampusEvent.fromMap).toList();
  }

  static Future<CampusEvent?> getById(int id, int? userId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery('$_selectSql WHERE e.id = ?', [userId ?? -1, id]);
    return rows.isEmpty ? null : CampusEvent.fromMap(rows.first);
  }

  /// Noms des inscrits (affiches dans le detail).
  static Future<List<String>> participantNames(int eventId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        'SELECT u.name FROM event_participants ep '
        'JOIN users u ON u.id = ep.user_id WHERE ep.event_id = ?',
        [eventId]);
    return rows.map((r) => r['name'] as String).toList();
  }

  /// Lieux du campus (liste deroulante du formulaire).
  static Future<List<CampusPlace>> places() async {
    final db = await AppDatabase.db;
    final rows = await db.query('places', orderBy: 'name');
    return rows.map((r) => CampusPlace(r['id'] as int, r['name'] as String)).toList();
  }

  // ---------- CREATE ----------
  static Future<int> insert({
    required String title,
    required String sport,
    required int placeId,
    required String date,
    required String time,
    required int capacity,
    required String description,
    required int organizerId,
  }) async {
    final db = await AppDatabase.db;
    return db.insert('events', {
      'title': title,
      'sport': sport,
      'place_id': placeId,
      'date': date,
      'time': time,
      'capacity': capacity,
      'description': description,
      'organizer_id': organizerId,
      'status': 'active',
    });
  }

  // ---------- UPDATE ----------
  static Future<void> update(
    int id, {
    required String title,
    required String sport,
    required int placeId,
    required String date,
    required String time,
    required int capacity,
    required String description,
  }) async {
    final db = await AppDatabase.db;
    await db.update(
        'events',
        {
          'title': title,
          'sport': sport,
          'place_id': placeId,
          'date': date,
          'time': time,
          'capacity': capacity,
          'description': description,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  /// "Annuler" garde l'evenement visible avec le tag "Annule" (reversible).
  static Future<void> setCancelled(int id, bool cancelled) async {
    final db = await AppDatabase.db;
    await db.update('events', {'status': cancelled ? 'cancelled' : 'active'},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------- DELETE ----------
  /// "Supprimer" retire l'evenement (et ses inscriptions : ON DELETE CASCADE).
  static Future<void> delete(int id) async {
    final db = await AppDatabase.db;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- JOIN / LEAVE ----------
  /// Inscription. Regle : impossible si l'evenement est complet ou annule.
  static Future<JoinResult> join(int eventId, int userId) async {
    final db = await AppDatabase.db;
    final e = await getById(eventId, userId);
    if (e == null || e.isCancelled) return JoinResult.cancelled;
    if (e.joined) return JoinResult.alreadyJoined;
    if (e.isPast) return JoinResult.past;
    if (e.isFull) return JoinResult.full;
    await db.insert('event_participants', {'event_id': eventId, 'user_id': userId});
    return JoinResult.ok;
  }

  static Future<void> leave(int eventId, int userId) async {
    final db = await AppDatabase.db;
    await db.delete('event_participants',
        where: 'event_id = ? AND user_id = ?', whereArgs: [eventId, userId]);
  }
}
