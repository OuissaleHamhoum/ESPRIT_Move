import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/format.dart';
import '../models/facility.dart';

/// Acces SQLite pour les terrains et les reservations.
///
/// Regles metier :
///   - seuls les terrains ouverts (active = 1) sont reservables ;
///   - un creneau deja commence ne se reserve / modifie / annule plus ;
///   - un etudiant ne peut pas avoir deux reservations qui se chevauchent ;
///   - 3 reservations a venir maximum par etudiant ;
///   - une annulation garde la ligne (statut 'cancelled') pour l'historique ;
///   - quand l'admin annule, l'etudiant recoit une notification.
class BookingDao {
  static const maxUpcomingPerUser = 3;

  static const _facilitySql = '''
    SELECT f.*, p.name AS place_name,
      (SELECT COUNT(*) FROM bookings b WHERE b.facility_id = f.id
         AND b.status = 'confirmed' AND (b.date || ' ' || b.slot) > ?) AS upcoming
    FROM facilities f JOIN places p ON p.id = f.place_id
  ''';

  static const _bookingSql = '''
    SELECT b.*, f.name AS facility_name, f.sport, u.name AS user_name, u.email AS user_email
    FROM bookings b
    JOIN facilities f ON f.id = b.facility_id
    JOIN users u ON u.id = b.user_id
  ''';

  /// "2026-10-20 14:05" : sert a comparer avec (date || ' ' || slot).
  static String _now() {
    final n = DateTime.now();
    return '${Fmt.dbDate(n)} ${Fmt.two(n.hour)}:${Fmt.two(n.minute)}';
  }

  // =================== TERRAINS (lecture) ===================

  /// Terrains proposes aux etudiants : ouverts uniquement.
  static Future<List<Facility>> activeFacilities() async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        '$_facilitySql WHERE f.active = 1 ORDER BY f.sport, f.name', [_now()]);
    return rows.map(Facility.fromMap).toList();
  }

  /// Tous les terrains (ecran admin), ouverts d'abord.
  static Future<List<Facility>> allFacilities() async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        '$_facilitySql ORDER BY f.active DESC, f.sport, f.name', [_now()]);
    return rows.map(Facility.fromMap).toList();
  }

  static Future<Facility?> facility(int id) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery('$_facilitySql WHERE f.id = ?', [_now(), id]);
    return rows.isEmpty ? null : Facility.fromMap(rows.first);
  }

  /// Noms des lieux deja connus (suggestions du formulaire admin).
  static Future<List<String>> placeNames() async {
    final db = await AppDatabase.db;
    final rows = await db.query('places', columns: ['name'], orderBy: 'name');
    return rows.map((r) => r['name'] as String).toList();
  }

  // =================== RESERVATIONS (etudiant) ===================

  /// Statut de la carte etudiante : 1 validee, 0 en attente, -1 refusee.
  static Future<int> cardStatus(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        columns: ['card_verified'], where: 'id = ?', whereArgs: [userId]);
    return rows.isEmpty ? 0 : (rows.first['card_verified'] as int? ?? 0);
  }

  /// Creneaux du terrain indisponibles ce jour-la (chevauchent une
  /// reservation confirmee). [excludeBookingId] : ma reservation en cours
  /// de modification.
  static Future<Set<String>> takenSlots(Facility f, String date,
      {int? excludeBookingId}) async {
    final db = await AppDatabase.db;
    final rows = await db.query('bookings',
        columns: ['slot', 'duration_min'],
        where: "facility_id = ? AND date = ? AND status = 'confirmed' AND id != ?",
        whereArgs: [f.id, date, excludeBookingId ?? -1]);
    final taken = <String>{};
    for (final s in f.slots) {
      final start = Slots.at(date, s);
      for (final r in rows) {
        if (Slots.overlap(start, f.slotMinutes, Slots.at(date, r['slot'] as String),
            r['duration_min'] as int)) {
          taken.add(s);
          break;
        }
      }
    }
    return taken;
  }

  /// Verifie toutes les regles avant de reserver / deplacer un creneau.
  static Future<BookingResult> _check(DatabaseExecutor db, Facility f, int userId,
      String date, String slot, {int? excludeBookingId}) async {
    final fresh = await db.query('facilities',
        columns: ['active'], where: 'id = ?', whereArgs: [f.id]);
    if (fresh.isEmpty || fresh.first['active'] != 1) return BookingResult.closed;

    final start = Slots.at(date, slot);
    if (!start.isAfter(DateTime.now())) return BookingResult.past;

    // Creneau deja pris sur ce terrain ?
    final onFacility = await db.query('bookings',
        columns: ['slot', 'duration_min'],
        where: "facility_id = ? AND date = ? AND status = 'confirmed' AND id != ?",
        whereArgs: [f.id, date, excludeBookingId ?? -1]);
    for (final r in onFacility) {
      if (Slots.overlap(start, f.slotMinutes, Slots.at(date, r['slot'] as String),
          r['duration_min'] as int)) {
        return BookingResult.slotTaken;
      }
    }

    // L'etudiant a-t-il deja un creneau qui chevauche (autre terrain) ?
    final mine = await db.query('bookings',
        columns: ['slot', 'duration_min'],
        where: "user_id = ? AND date = ? AND status = 'confirmed' AND id != ?",
        whereArgs: [userId, date, excludeBookingId ?? -1]);
    for (final r in mine) {
      if (Slots.overlap(start, f.slotMinutes, Slots.at(date, r['slot'] as String),
          r['duration_min'] as int)) {
        return BookingResult.userConflict;
      }
    }

    // Limite de reservations a venir (une modification ne compte pas)
    if (excludeBookingId == null) {
      final n = (await db.rawQuery(
              "SELECT COUNT(*) AS v FROM bookings WHERE user_id = ? AND status = 'confirmed' "
              "AND (date || ' ' || slot) > ?",
              [userId, _now()]))
          .first['v'] as int;
      if (n >= maxUpcomingPerUser) return BookingResult.tooMany;
    }
    return BookingResult.ok;
  }

  /// CREATE : reserve un creneau (dans une transaction : deux reservations
  /// simultanees du meme creneau sont impossibles).
  static Future<BookingResult> book(
      Facility f, int userId, String date, String slot) async {
    final db = await AppDatabase.db;
    return db.transaction((txn) async {
      final result = await _check(txn, f, userId, date, slot);
      if (result != BookingResult.ok) return result;
      await txn.insert('bookings', {
        'facility_id': f.id,
        'user_id': userId,
        'date': date,
        'slot': slot,
        'duration_min': f.slotMinutes,
        'status': 'confirmed',
        'created_at': DateTime.now().toIso8601String(),
      });
      return BookingResult.ok;
    });
  }

  /// UPDATE : deplace ma reservation vers un autre jour / creneau.
  static Future<BookingResult> move(
      Booking b, Facility f, String date, String slot) async {
    if (b.hasStarted || b.isCancelled) return BookingResult.past;
    final db = await AppDatabase.db;
    return db.transaction((txn) async {
      final result =
          await _check(txn, f, b.userId, date, slot, excludeBookingId: b.id);
      if (result != BookingResult.ok) return result;
      await txn.update('bookings',
          {'date': date, 'slot': slot, 'duration_min': f.slotMinutes},
          where: 'id = ?', whereArgs: [b.id]);
      return BookingResult.ok;
    });
  }

  /// Annulation par l'etudiant. Retourne false si le creneau a commence.
  static Future<bool> cancelByUser(Booking b) async {
    if (b.hasStarted || b.isCancelled) return false;
    final db = await AppDatabase.db;
    await db.update('bookings', {'status': 'cancelled', 'cancelled_by': 'user'},
        where: 'id = ?', whereArgs: [b.id]);
    return true;
  }

  /// Mes reservations a venir (de la plus proche a la plus lointaine).
  static Future<List<Booking>> myUpcoming(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        "$_bookingSql WHERE b.user_id = ? AND b.status = 'confirmed' "
        "AND (b.date || ' ' || b.slot) > ? ORDER BY b.date, b.slot",
        [userId, _now()]);
    return rows.map(Booking.fromMap).toList();
  }

  /// Mon historique : passees + annulees (les plus recentes d'abord).
  static Future<List<Booking>> myHistory(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        "$_bookingSql WHERE b.user_id = ? AND (b.status = 'cancelled' "
        "OR (b.date || ' ' || b.slot) <= ?) ORDER BY b.date DESC, b.slot DESC LIMIT 30",
        [userId, _now()]);
    return rows.map(Booking.fromMap).toList();
  }

  // =================== ADMIN : terrains ===================

  /// Retrouve un lieu par son nom (sans tenir compte de la casse) ou le cree.
  static Future<int> _placeId(DatabaseExecutor db, String name) async {
    final rows = await db.query('places',
        columns: ['id'], where: 'LOWER(name) = LOWER(?)', whereArgs: [name]);
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return db.insert('places', {'name': name});
  }

  /// Reservations a venir qui ne rentrent plus dans les nouveaux horaires.
  static Future<List<Booking>> _outsideSchedule(
      DatabaseExecutor db, int facilityId, int openHour, int closeHour) async {
    final rows = await db.rawQuery(
        "$_bookingSql WHERE b.facility_id = ? AND b.status = 'confirmed' "
        "AND (b.date || ' ' || b.slot) > ?",
        [facilityId, _now()]);
    return rows.map(Booking.fromMap).where((b) {
      final open = DateTime(b.start.year, b.start.month, b.start.day, openHour);
      final close = DateTime(b.start.year, b.start.month, b.start.day, closeHour);
      return b.start.isBefore(open) || b.end.isAfter(close);
    }).toList();
  }

  /// Nombre de reservations qui seraient annulees par ces nouveaux horaires
  /// (affiche a l'admin avant d'enregistrer).
  static Future<int> countOutsideSchedule(
      int facilityId, int openHour, int closeHour) async {
    final db = await AppDatabase.db;
    return (await _outsideSchedule(db, facilityId, openHour, closeHour)).length;
  }

  /// CREATE / UPDATE d'un terrain. En modification, les reservations a venir
  /// hors des nouveaux horaires sont annulees (etudiants prevenus).
  static Future<void> saveFacility({
    int? id,
    required String name,
    required String sport,
    required String placeName,
    required String description,
    required int openHour,
    required int closeHour,
    required int slotMinutes,
  }) async {
    final db = await AppDatabase.db;
    await db.transaction((txn) async {
      final values = {
        'name': name,
        'sport': sport,
        'icon': FacilitySports.iconOf(sport),
        'place_id': await _placeId(txn, placeName),
        'description': description,
        'open_hour': openHour,
        'close_hour': closeHour,
        'slot_minutes': slotMinutes,
      };
      if (id == null) {
        await txn.insert('facilities', values);
        return;
      }
      await txn.update('facilities', values, where: 'id = ?', whereArgs: [id]);
      for (final b in await _outsideSchedule(txn, id, openHour, closeHour)) {
        await _cancel(txn, b, 'Horaires du terrain modifiés');
      }
    });
  }

  /// Ouvre / ferme un terrain. Fermer annule les reservations a venir
  /// (etudiants prevenus). Retourne le nombre de reservations annulees.
  static Future<int> setActive(Facility f, bool active, {String reason = ''}) async {
    final db = await AppDatabase.db;
    return db.transaction((txn) async {
      await txn.update('facilities', {'active': active ? 1 : 0},
          where: 'id = ?', whereArgs: [f.id]);
      if (active) return 0;
      final rows = await txn.rawQuery(
          "$_bookingSql WHERE b.facility_id = ? AND b.status = 'confirmed' "
          "AND (b.date || ' ' || b.slot) > ?",
          [f.id, _now()]);
      for (final r in rows) {
        await _cancel(txn, Booking.fromMap(r), reason.isEmpty ? 'Terrain fermé' : reason);
      }
      return rows.length;
    });
  }

  /// DELETE d'un terrain : seulement s'il n'a JAMAIS ete reserve
  /// (sinon on le ferme, pour garder l'historique). Retourne false si refuse.
  static Future<bool> deleteFacility(int id) async {
    final db = await AppDatabase.db;
    final n = (await db.rawQuery(
            'SELECT COUNT(*) AS v FROM bookings WHERE facility_id = ?', [id]))
        .first['v'] as int;
    if (n > 0) return false;
    await db.delete('facilities', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  // =================== ADMIN : reservations ===================

  /// Reservations vues par l'admin, filtrees.
  static Future<List<Booking>> adminBookings(AdminBookingFilter filter,
      {int? facilityId}) async {
    final db = await AppDatabase.db;
    final now = _now();
    final today = Fmt.dbDate(DateTime.now());
    final where = <String>[];
    final args = <Object?>[];
    switch (filter) {
      case AdminBookingFilter.upcoming:
        where.add("b.status = 'confirmed' AND (b.date || ' ' || b.slot) > ?");
        args.add(now);
        break;
      case AdminBookingFilter.today:
        where.add('b.date = ?');
        args.add(today);
        break;
      case AdminBookingFilter.past:
        where.add("b.status = 'confirmed' AND (b.date || ' ' || b.slot) <= ?");
        args.add(now);
        break;
      case AdminBookingFilter.cancelled:
        where.add("b.status = 'cancelled'");
        break;
    }
    if (facilityId != null) {
      where.add('b.facility_id = ?');
      args.add(facilityId);
    }
    final desc = filter == AdminBookingFilter.past ||
        filter == AdminBookingFilter.cancelled;
    final rows = await db.rawQuery(
        '$_bookingSql WHERE ${where.join(' AND ')} '
        'ORDER BY b.date ${desc ? 'DESC' : 'ASC'}, b.slot ${desc ? 'DESC' : 'ASC'} LIMIT 200',
        args);
    return rows.map(Booking.fromMap).toList();
  }

  /// Annulation par l'administration (avec motif) + notification.
  static Future<void> cancelByAdmin(Booking b, String reason) async {
    final db = await AppDatabase.db;
    await db.transaction((txn) => _cancel(txn, b, reason));
  }

  static Future<void> _cancel(DatabaseExecutor txn, Booking b, String reason) async {
    await txn.update('bookings',
        {'status': 'cancelled', 'cancelled_by': 'admin', 'cancel_reason': reason},
        where: 'id = ?', whereArgs: [b.id]);
    await NotificationService.notify(
        b.userId,
        '❌ Réservation annulée : ${b.facilityName}, ${Fmt.shortDate(b.date)} '
        '${b.timeRange}${reason.isEmpty ? '' : ' — $reason'}',
        txn: txn);
  }

  /// Chiffres de l'accueil admin.
  static Future<BookingStats> stats() async {
    final db = await AppDatabase.db;
    Future<int> count(String sql, [List<Object?>? args]) async =>
        (await db.rawQuery(sql, args)).first['v'] as int;
    final today = Fmt.dbDate(DateTime.now());
    return BookingStats(
      today: await count(
          "SELECT COUNT(*) AS v FROM bookings WHERE status = 'confirmed' AND date = ?",
          [today]),
      upcoming: await count(
          "SELECT COUNT(*) AS v FROM bookings WHERE status = 'confirmed' "
          "AND (date || ' ' || slot) > ?",
          [_now()]),
      activeFacilities:
          await count('SELECT COUNT(*) AS v FROM facilities WHERE active = 1'),
      closedFacilities:
          await count('SELECT COUNT(*) AS v FROM facilities WHERE active = 0'),
    );
  }
}

enum AdminBookingFilter { upcoming, today, past, cancelled }

class BookingStats {
  final int today;
  final int upcoming;
  final int activeFacilities;
  final int closedFacilities;
  const BookingStats({
    required this.today,
    required this.upcoming,
    required this.activeFacilities,
    required this.closedFacilities,
  });
}
