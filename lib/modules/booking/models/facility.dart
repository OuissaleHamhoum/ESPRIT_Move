/// Installation reservable (table "facilities") : terrain, court, salle...
class Facility {
  final int id;
  final String name;
  final String placeName; // lieu du campus (table "places")
  final String icon;
  const Facility(this.id, this.name, this.placeName, this.icon);
}

/// Une reservation (table "bookings") avec le nom de l'installation.
class Booking {
  final int id;
  final int facilityId;
  final String facilityName;
  final String icon;
  final String date; // yyyy-MM-dd
  final String slot; // "14:00" (creneau de 2 h)
  const Booking(this.id, this.facilityId, this.facilityName, this.icon, this.date, this.slot);
}

/// Creneaux de 2 h proposes chaque jour (PDF module 4).
class Slots {
  static const all = ['08:00', '10:00', '12:00', '14:00', '16:00', '18:00'];
}
