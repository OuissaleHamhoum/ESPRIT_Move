import '../../../core/utils/format.dart';

/// Sports proposes pour un terrain, avec leur pictogramme.
class FacilitySports {
  static const Map<String, String> icons = {
    'Padel': '🎾',
    'Football': '⚽',
    'Basket': '🏀',
    'Tennis': '🎾',
    'Volley': '🏐',
    'Handball': '🤾',
    'Musculation': '🏋️',
    'Athlétisme': '🏃',
    'Natation': '🏊',
    'Autre': '🏟️',
  };

  static List<String> get all => icons.keys.toList();
  static String iconOf(String sport) => icons[sport] ?? '🏟️';
}

/// Terrain / installation reservable (table "facilities").
/// Cree, modifie, ferme ou supprime par l'administration uniquement.
class Facility {
  final int id;
  final String name;
  final String sport;
  final int placeId;
  final String placeName; // lieu du campus (table "places")
  final String description;
  final int openHour;
  final int closeHour;
  final int slotMinutes;
  final bool active;
  final int upcomingBookings; // reservations a venir (affiche cote admin)

  const Facility({
    required this.id,
    required this.name,
    required this.sport,
    required this.placeId,
    required this.placeName,
    this.description = '',
    this.openHour = 8,
    this.closeHour = 22,
    this.slotMinutes = 60,
    this.active = true,
    this.upcomingBookings = 0,
  });

  String get icon => FacilitySports.iconOf(sport);

  /// "08:00 - 22:00 · créneaux de 1 h 30"
  String get scheduleLabel =>
      '${Fmt.two(openHour)}:00 - ${Fmt.two(closeHour)}:00 · '
      'créneaux de ${slotLabel(slotMinutes)}';

  /// 60 -> "1 h", 90 -> "1 h 30"
  static String slotLabel(int minutes) =>
      minutes % 60 == 0 ? '${minutes ~/ 60} h' : Fmt.duration(minutes);

  /// Heures de debut des creneaux : de l'ouverture a la fermeture.
  List<String> get slots => Slots.generate(openHour, closeHour, slotMinutes);

  factory Facility.fromMap(Map<String, dynamic> m) => Facility(
        id: m['id'] as int,
        name: m['name'] as String,
        sport: m['sport'] as String,
        placeId: m['place_id'] as int,
        placeName: m['place_name'] as String,
        description: (m['description'] as String?) ?? '',
        openHour: m['open_hour'] as int,
        closeHour: m['close_hour'] as int,
        slotMinutes: m['slot_minutes'] as int,
        active: m['active'] == 1,
        upcomingBookings: (m['upcoming'] as int?) ?? 0,
      );
}

/// Une reservation (table "bookings") avec le terrain et l'etudiant.
class Booking {
  final int id;
  final int facilityId;
  final String facilityName;
  final String sport;
  final int userId;
  final String userName;
  final String userEmail;
  final String date; // yyyy-MM-dd
  final String slot; // heure de debut "HH:mm"
  final int durationMin;
  final String status; // 'confirmed' ou 'cancelled'
  final String? cancelledBy; // 'user' ou 'admin'
  final String cancelReason;

  const Booking({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.sport,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.date,
    required this.slot,
    required this.durationMin,
    required this.status,
    this.cancelledBy,
    this.cancelReason = '',
  });

  String get icon => FacilitySports.iconOf(sport);
  bool get isCancelled => status == 'cancelled';

  /// Debut du creneau (date + heure).
  DateTime get start => Slots.at(date, slot);
  DateTime get end => start.add(Duration(minutes: durationMin));

  /// Le creneau a deja commence (ou est termine) : plus modifiable.
  bool get hasStarted => !start.isAfter(DateTime.now());

  /// "14:00 - 15:30"
  String get timeRange => '$slot - ${Slots.format(end)}';

  /// Libelle de statut pour l'historique.
  String get statusLabel {
    if (isCancelled) {
      final who = cancelledBy == 'admin' ? 'par l’administration' : 'par vous';
      return 'Annulée $who${cancelReason.isEmpty ? '' : ' : $cancelReason'}';
    }
    return hasStarted ? 'Passée' : 'Confirmée';
  }

  /// Meme chose vu par l'administration.
  String get adminStatusLabel {
    if (!isCancelled) return statusLabel;
    final who = cancelledBy == 'admin' ? 'par l’administration' : 'par l’étudiant';
    return 'Annulée $who${cancelReason.isEmpty ? '' : ' : $cancelReason'}';
  }

  factory Booking.fromMap(Map<String, dynamic> m) => Booking(
        id: m['id'] as int,
        facilityId: m['facility_id'] as int,
        facilityName: m['facility_name'] as String,
        sport: m['sport'] as String,
        userId: m['user_id'] as int,
        userName: m['user_name'] as String,
        userEmail: m['user_email'] as String,
        date: m['date'] as String,
        slot: m['slot'] as String,
        durationMin: m['duration_min'] as int,
        status: m['status'] as String,
        cancelledBy: m['cancelled_by'] as String?,
        cancelReason: (m['cancel_reason'] as String?) ?? '',
      );
}

/// Calcul des creneaux a partir des horaires d'un terrain.
class Slots {
  /// Ex. generate(8, 12, 90) -> ["08:00", "09:30"] (le dernier doit finir
  /// avant la fermeture).
  static List<String> generate(int openHour, int closeHour, int minutes) {
    final list = <String>[];
    for (var m = openHour * 60; m + minutes <= closeHour * 60; m += minutes) {
      list.add('${Fmt.two(m ~/ 60)}:${Fmt.two(m % 60)}');
    }
    return list;
  }

  /// "2026-10-20" + "14:30" -> DateTime
  static DateTime at(String date, String slot) {
    final d = DateTime.parse(date);
    return DateTime(d.year, d.month, d.day,
        int.parse(slot.substring(0, 2)), int.parse(slot.substring(3, 5)));
  }

  static String format(DateTime t) => '${Fmt.two(t.hour)}:${Fmt.two(t.minute)}';

  /// Deux intervalles [a, a+da[ et [b, b+db[ se chevauchent-ils ?
  static bool overlap(DateTime a, int da, DateTime b, int db) =>
      a.isBefore(b.add(Duration(minutes: db))) && b.isBefore(a.add(Duration(minutes: da)));
}

/// Raison pour laquelle une reservation est refusee.
enum BookingResult { ok, slotTaken, userConflict, tooMany, closed, past }
