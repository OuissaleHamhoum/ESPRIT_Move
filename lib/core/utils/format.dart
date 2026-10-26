/// Petites fonctions de formatage partagees par tous les modules.
/// En base de donnees, les dates sont stockees en texte :
///   - date  : "2026-10-18"       (yyyy-MM-dd)
///   - heure : "17:30"            (HH:mm)
class Fmt {
  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ];
  static const _days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

  static String two(int n) => n.toString().padLeft(2, '0');

  /// DateTime -> "2026-10-18" (format stocke en base)
  static String dbDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  /// "2026-10-18" -> "dim. 18 oct."
  static String shortDate(String dbDate) {
    final d = DateTime.parse(dbDate);
    return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  /// "2026-10-18" -> "18 oct."
  static String dayMonth(String dbDate) {
    final d = DateTime.parse(dbDate);
    return '${d.day} ${_months[d.month - 1]}';
  }

  /// Rythme en min/km (duree / distance). Retourne "--" si distance = 0.
  static String pace(double km, int minutes) =>
      km <= 0 ? '--' : (minutes / km).toStringAsFixed(1);

  /// 75 -> "1 h 15"   |   45 -> "45 min"
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${two(minutes % 60)}';
  }

  /// 3725 secondes -> "01:02:05"  (chronometre du direct)
  static String clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// Allure : 318 s/km -> "5:18". "--" si inconnue.
  static String paceSec(num? secPerKm) {
    if (secPerKm == null || secPerKm <= 0 || secPerKm >= 3600) return '--';
    final s = secPerKm.round();
    return '${s ~/ 60}:${two(s % 60)}';
  }

  /// Vitesse m/s -> allure "5:18" (min/km). "--" a l'arret.
  static String paceFromSpeed(double mps) => mps < 0.4 ? '--' : paceSec(1000 / mps);

  /// m/s -> "12.4" (km/h). "--" si inconnue.
  static String kmh(double? mps) => mps == null ? '--' : (mps * 3.6).toStringAsFixed(1);

  /// DateTime -> "oct."
  static String month(DateTime d) => _months[d.month - 1];

  /// DateTime -> "17:30"
  static String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
}
