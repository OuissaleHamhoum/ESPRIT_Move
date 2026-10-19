import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import '../models/challenge_models.dart';

/// Acces SQLite pour les defis : C-R-U-D (admin), rejoindre, classement.
class ChallengeDao {
  /// Valeur d'un utilisateur pour un defi : on compte ses activites des
  /// N derniers jours (N = duree du defi). Regle du PDF.
  static Future<double> _valueFor(
      Database db, String measure, int durationDays, int userId) async {
    final since =
        Fmt.dbDate(DateTime.now().subtract(Duration(days: durationDays - 1)));
    final select = measure == 'km'
        ? 'COALESCE(SUM(distance_km),0)'
        : measure == 'minutes'
            ? 'COALESCE(SUM(duration_min),0)'
            : 'COUNT(*)'; // 'seances'
    final r = await db.rawQuery(
        'SELECT $select AS v FROM activities WHERE user_id = ? AND date >= ?',
        [userId, since]);
    return (r.first['v'] as num).toDouble();
  }

  // ---------- READ ----------
  static Future<List<Challenge>> getAll(int? userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('challenges', orderBy: 'id');
    final list = <Challenge>[];
    for (final r in rows) {
      var joined = false;
      var progress = 0.0;
      if (userId != null) {
        final j = await db.query('challenge_participants',
            where: 'challenge_id = ? AND user_id = ?', whereArgs: [r['id'], userId]);
        joined = j.isNotEmpty;
        progress = await _valueFor(
            db, r['measure'] as String, r['duration_days'] as int, userId);
      }
      list.add(Challenge(
        id: r['id'] as int,
        title: r['title'] as String,
        measure: r['measure'] as String,
        goal: (r['goal'] as num).toDouble(),
        durationDays: r['duration_days'] as int,
        joined: joined,
        progress: progress,
      ));
    }
    return list;
  }

  /// Classement : seuls les participants apparaissent, du meilleur au moins bon.
  static Future<List<LeaderEntry>> leaderboard(Challenge c) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        'SELECT u.id, u.name FROM challenge_participants cp '
        'JOIN users u ON u.id = cp.user_id WHERE cp.challenge_id = ?',
        [c.id]);
    final list = <LeaderEntry>[];
    for (final r in rows) {
      final v = await _valueFor(db, c.measure, c.durationDays, r['id'] as int);
      list.add(LeaderEntry(r['id'] as int, r['name'] as String, v));
    }
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // ---------- CREATE (admin) ----------
  static Future<void> insert(String title, String measure, double goal, int days) async {
    final db = await AppDatabase.db;
    await db.insert('challenges',
        {'title': title, 'measure': measure, 'goal': goal, 'duration_days': days});
  }

  // ---------- UPDATE (admin) ----------
  static Future<void> update(
      int id, String title, String measure, double goal, int days) async {
    final db = await AppDatabase.db;
    await db.update('challenges',
        {'title': title, 'measure': measure, 'goal': goal, 'duration_days': days},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------- DELETE (admin) ----------
  static Future<void> delete(int id) async {
    final db = await AppDatabase.db;
    await db.delete('challenges', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- JOIN / LEAVE ----------
  static Future<void> join(int challengeId, int userId) async {
    final db = await AppDatabase.db;
    await db.insert('challenge_participants',
        {'challenge_id': challengeId, 'user_id': userId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> leave(int challengeId, int userId) async {
    final db = await AppDatabase.db;
    await db.delete('challenge_participants',
        where: 'challenge_id = ? AND user_id = ?', whereArgs: [challengeId, userId]);
  }
}
