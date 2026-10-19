import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import '../models/challenge_models.dart';

/// Donnees de l'accueil, des notifications et du tableau de bord admin.
/// L'accueil ASSEMBLE des donnees des autres modules (lecture seule).
class HomeDao {
  /// Serie = jours consecutifs avec au moins une activite.
  /// On part d'aujourd'hui (ou d'hier si rien aujourd'hui).
  static Future<int> streak(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        'SELECT DISTINCT date FROM activities WHERE user_id = ?', [userId]);
    final days = rows.map((r) => r['date'] as String).toSet();
    var day = DateTime.now();
    if (!days.contains(Fmt.dbDate(day))) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(Fmt.dbDate(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// La serie est "en danger" : une serie existe mais rien n'a ete fait aujourd'hui.
  static Future<bool> streakAtRisk(int userId) async {
    final db = await AppDatabase.db;
    final today = await db.query('activities',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, Fmt.dbDate(DateTime.now())]);
    return today.isEmpty && await streak(userId) > 0;
  }

  static Future<HomeData> load(int? userId) async {
    final db = await AppDatabase.db;
    final today = Fmt.dbDate(DateTime.now());

    var name = '';
    var points = 0;
    var weekKm = 0.0;
    var streakDays = 0;
    String? evTitle;
    String? evInfo;

    if (userId != null) {
      final u = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (u.isNotEmpty) {
        name = (u.first['name'] as String).split(' ').first;
        points = (u.first['points'] as int?) ?? 0;
      }
      final since = Fmt.dbDate(DateTime.now().subtract(const Duration(days: 6)));
      final k = await db.rawQuery(
          'SELECT COALESCE(SUM(distance_km),0) AS v FROM activities '
          'WHERE user_id = ? AND date >= ?',
          [userId, since]);
      weekKm = (k.first['v'] as num).toDouble();
      streakDays = await streak(userId);

      // Prochain evenement ou je suis inscrit (module 3)
      final e = await db.rawQuery(
          'SELECT e.title, e.date, e.time, p.name AS place FROM events e '
          'JOIN event_participants ep ON ep.event_id = e.id '
          'JOIN places p ON p.id = e.place_id '
          "WHERE ep.user_id = ? AND e.status = 'active' AND e.date >= ? "
          'ORDER BY e.date, e.time LIMIT 1',
          [userId, today]);
      if (e.isNotEmpty) {
        evTitle = e.first['title'] as String;
        evInfo = '${Fmt.shortDate(e.first['date'] as String)} · ${e.first['time']} · ${e.first['place']}';
      }
    }

    // Impact campus
    final students = (await db.rawQuery("SELECT COUNT(*) AS v FROM users WHERE role = 'student'"))
        .first['v'] as int;
    final km = (await db.rawQuery('SELECT COALESCE(SUM(distance_km),0) AS v FROM activities'))
        .first['v'] as num;
    final events = (await db.rawQuery("SELECT COUNT(*) AS v FROM events WHERE status = 'active'"))
        .first['v'] as int;

    // Fil de la communaute : 5 dernieres activites de tous les etudiants
    final feedRows = await db.rawQuery(
        'SELECT a.title, a.distance_km, a.duration_min, u.name FROM activities a '
        'JOIN users u ON u.id = a.user_id ORDER BY a.id DESC LIMIT 5');
    final feed = feedRows
        .map((r) =>
            '${r['name']} · ${r['title']} (${(r['distance_km'] as num).toStringAsFixed(1)} km, ${r['duration_min']} min)')
        .toList();

    return HomeData(
      userName: name,
      points: points,
      weekKm: weekKm,
      streak: streakDays,
      nextEventTitle: evTitle,
      nextEventInfo: evInfo,
      activeStudents: students,
      campusKm: km.toDouble(),
      eventsCount: events,
      feed: feed,
    );
  }

  /// Notifications calculees a partir des donnees (pas de table dediee).
  static Future<List<String>> notifications(int? userId) async {
    final list = <String>[];
    if (userId != null) {
      final db = await AppDatabase.db;
      if (await streakAtRisk(userId)) {
        list.add('🔥 Série en danger : bougez aujourd’hui pour la garder !');
      }
      final ev = await db.rawQuery(
          'SELECT e.title FROM events e '
          "WHERE e.status = 'active' AND e.date >= ? AND e.id NOT IN "
          '(SELECT event_id FROM event_participants WHERE user_id = ?) '
          'ORDER BY e.date LIMIT 1',
          [Fmt.dbDate(DateTime.now()), userId]);
      if (ev.isNotEmpty) list.add('👥 Invitation : ${ev.first['title']}');
      final b = await db.rawQuery(
          'SELECT b.name FROM user_badges ub JOIN badges b ON b.id = ub.badge_id '
          'WHERE ub.user_id = ? ORDER BY ub.earned_at DESC LIMIT 2',
          [userId]);
      for (final r in b) {
        list.add('🏅 Badge débloqué : ${r['name']}');
      }
    }
    list.add('🎟️ Offre partenaire : -20 % chez GymPro Tunis');
    return list;
  }

  /// Tableau de bord admin : (libelle, pourcentage 0..1, valeur brute).
  static Future<List<List<Object>>> dashboard() async {
    final db = await AppDatabase.db;
    Future<int> count(String sql, [List<Object?>? args]) async =>
        (await db.rawQuery(sql, args)).first['v'] as int;

    final since = Fmt.dbDate(DateTime.now().subtract(const Duration(days: 6)));
    final users = await count('SELECT COUNT(*) AS v FROM users');
    final acts = await count('SELECT COUNT(*) AS v FROM activities WHERE date >= ?', [since]);
    final joins = await count('SELECT COUNT(*) AS v FROM event_participants');
    final seats = await count('SELECT COALESCE(SUM(capacity),0) AS v FROM events');
    final bookings = await count("SELECT COUNT(*) AS v FROM bookings WHERE status = 'confirmed'");
    final facilities = await count('SELECT COUNT(*) AS v FROM facilities');

    double ratio(num a, num b) => b <= 0 ? 0 : (a / b).clamp(0.0, 1.0).toDouble();
    return [
      ['Inscriptions ($users / objectif 100)', ratio(users, 100), users],
      ['Activités sur 7 jours ($acts / objectif 50)', ratio(acts, 50), acts],
      ['Participation aux événements ($joins / $seats places)', ratio(joins, seats), joins],
      ['Réservations ($bookings / ${facilities * 6 * 7} créneaux)', ratio(bookings, facilities * 6 * 7), bookings],
    ];
  }
}
