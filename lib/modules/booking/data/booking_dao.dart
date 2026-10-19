import '../../../core/database/app_database.dart';
import '../models/facility.dart';

/// Acces SQLite pour les installations et les reservations.
class BookingDao {
  // ---------- READ ----------
  static Future<List<Facility>> facilities() async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        'SELECT f.id, f.name, f.icon, p.name AS place FROM facilities f '
        'JOIN places p ON p.id = f.place_id ORDER BY f.id');
    return rows
        .map((r) => Facility(r['id'] as int, r['name'] as String,
            r['place'] as String, r['icon'] as String))
        .toList();
  }

  /// Mes reservations (de la plus proche a la plus lointaine).
  static Future<List<Booking>> myBookings(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.rawQuery(
        'SELECT b.id, b.facility_id, b.date, b.slot, f.name, f.icon '
        'FROM bookings b JOIN facilities f ON f.id = b.facility_id '
        "WHERE b.user_id = ? AND b.status = 'confirmed' ORDER BY b.date, b.slot",
        [userId]);
    return rows
        .map((r) => Booking(r['id'] as int, r['facility_id'] as int,
            r['name'] as String, r['icon'] as String,
            r['date'] as String, r['slot'] as String))
        .toList();
  }

  /// Creneaux deja pris pour une installation et un jour.
  /// excludeBookingId : on ignore ma propre reservation quand je la modifie.
  static Future<Set<String>> takenSlots(int facilityId, String date,
      {int? excludeBookingId}) async {
    final db = await AppDatabase.db;
    final rows = await db.query('bookings',
        columns: ['slot'],
        where: "facility_id = ? AND date = ? AND status = 'confirmed' AND id != ?",
        whereArgs: [facilityId, date, excludeBookingId ?? -1]);
    return rows.map((r) => r['slot'] as String).toSet();
  }

  /// Regle : la reservation exige une carte etudiante verifiee.
  static Future<bool> hasVerifiedCard(int userId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        columns: ['card_verified'], where: 'id = ?', whereArgs: [userId]);
    return rows.isNotEmpty && rows.first['card_verified'] == 1;
  }

  // ---------- CREATE ----------
  /// Reserve un creneau. Retourne false si deja pris.
  static Future<bool> insert(int facilityId, int userId, String date, String slot) async {
    if ((await takenSlots(facilityId, date)).contains(slot)) return false;
    final db = await AppDatabase.db;
    await db.insert('bookings', {
      'facility_id': facilityId,
      'user_id': userId,
      'date': date,
      'slot': slot,
      'status': 'confirmed',
    });
    return true;
  }

  // ---------- UPDATE ----------
  /// Change le jour / creneau. L'ancien creneau est libere automatiquement
  /// (on modifie la meme ligne). Retourne false si le nouveau est deja pris.
  static Future<bool> update(Booking b, String date, String slot) async {
    final taken = await takenSlots(b.facilityId, date, excludeBookingId: b.id);
    if (taken.contains(slot)) return false;
    final db = await AppDatabase.db;
    await db.update('bookings', {'date': date, 'slot': slot},
        where: 'id = ?', whereArgs: [b.id]);
    return true;
  }

  // ---------- DELETE ----------
  static Future<void> delete(int bookingId) async {
    final db = await AppDatabase.db;
    await db.delete('bookings', where: 'id = ?', whereArgs: [bookingId]);
  }
}
