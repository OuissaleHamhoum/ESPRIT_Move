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
        'SELECT a.type, a.title, a.distance_km, a.duration_min, u.name FROM activities a '
        'JOIN users u ON u.id = a.user_id ORDER BY a.id DESC LIMIT 5');
    const icons = {
      'Course': '🏃', 'Vélo': '🚴', 'Marche': '🚶',
      'Muscu': '🏋️', 'Football': '⚽', 'Natation': '🏊',
    };
    final feed = feedRows
        .map((r) => FeedItem(icons[r['type']] ?? '🏅',
            '${r['name']} · ${r['title']} (${(r['distance_km'] as num).toStringAsFixed(1)} km, ${r['duration_min']} min)'))
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
    // Reservations des 7 prochains jours / creneaux offerts par les terrains ouverts
    final until = Fmt.dbDate(DateTime.now().add(const Duration(days: 6)));
    final bookings = await count(
        "SELECT COUNT(*) AS v FROM bookings WHERE status = 'confirmed' AND date >= ? AND date <= ?",
        [Fmt.dbDate(DateTime.now()), until]);
    var slotsPerWeek = 0;
    for (final f in await db.query('facilities',
        columns: ['open_hour', 'close_hour', 'slot_minutes'], where: 'active = 1')) {
      final minutes = ((f['close_hour'] as int) - (f['open_hour'] as int)) * 60;
      slotsPerWeek += (minutes ~/ (f['slot_minutes'] as int)) * 7;
    }

    double ratio(num a, num b) => b <= 0 ? 0 : (a / b).clamp(0.0, 1.0).toDouble();
    return [
      ['Comptes ($users / objectif 100)', ratio(users, 100), users],
      ['Activités sur 7 jours ($acts / objectif 50)', ratio(acts, 50), acts],
      ['Participation aux événements ($joins / $seats places)', ratio(joins, seats), joins],
      ['Occupation des terrains, 7 prochains jours ($bookings / $slotsPerWeek créneaux)',
        ratio(bookings, slotsPerWeek), bookings],
    ];
  }

  /// Chiffres de l'accueil administrateur (lecture des autres modules).
  static Future<AdminSummary> adminSummary() async {
    final db = await AppDatabase.db;
    Future<int> count(String sql, [List<Object?>? args]) async =>
        (await db.rawQuery(sql, args)).first['v'] as int;
    final now = DateTime.now();
    final nowKey = '${Fmt.dbDate(now)} ${Fmt.two(now.hour)}:${Fmt.two(now.minute)}';

    final todayRows = await db.rawQuery(
        'SELECT b.slot, b.duration_min, f.name AS facility, f.icon, u.name AS user '
        'FROM bookings b JOIN facilities f ON f.id = b.facility_id '
        'JOIN users u ON u.id = b.user_id '
        "WHERE b.status = 'confirmed' AND b.date = ? ORDER BY b.slot",
        [Fmt.dbDate(now)]);

    return AdminSummary(
      students: await count("SELECT COUNT(*) AS v FROM users WHERE role = 'student'"),
      pendingCards: await count(
          "SELECT COUNT(*) AS v FROM users WHERE role = 'student' AND card_verified = 0"),
      activeFacilities: await count('SELECT COUNT(*) AS v FROM facilities WHERE active = 1'),
      upcomingBookings: await count(
          "SELECT COUNT(*) AS v FROM bookings WHERE status = 'confirmed' "
          "AND (date || ' ' || slot) > ?",
          [nowKey]),
      today: [
        for (final r in todayRows)
          FeedItem(
              r['icon'] as String,
              '${r['slot']} · ${r['facility']} · ${r['user']}'),
      ],
    );
  }
}
