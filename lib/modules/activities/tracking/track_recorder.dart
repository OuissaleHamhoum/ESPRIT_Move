import 'dart:math' as math;

/// Un point GPS brut recu du telephone (sans dependance a geolocator :
/// la classe reste testable avec `flutter test`).
class GpsFix {
  final double lat;
  final double lng;
  final double accuracy; // precision horizontale (m)
  final double? alt; // altitude (m), null si inconnue
  final double? altAccuracy; // precision verticale (m), null si inconnue
  final DateTime time;

  const GpsFix({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.time,
    this.alt,
    this.altAccuracy,
  });

  GpsFix withTime(DateTime t) =>
      GpsFix(lat: lat, lng: lng, accuracy: accuracy, time: t, alt: alt, altAccuracy: altAccuracy);

  List<Object?> toJson() =>
      [lat, lng, accuracy, alt, altAccuracy, time.millisecondsSinceEpoch];

  factory GpsFix.fromJson(List<dynamic> j) => GpsFix(
        lat: (j[0] as num).toDouble(),
        lng: (j[1] as num).toDouble(),
        accuracy: (j[2] as num).toDouble(),
        alt: (j[3] as num?)?.toDouble(),
        altAccuracy: (j[4] as num?)?.toDouble(),
        time: DateTime.fromMillisecondsSinceEpoch(j[5] as int),
      );
}

/// Temps (en mouvement) mis pour parcourir un kilometre.
/// Le dernier fractionne peut etre partiel (distanceM < 1000).
class KmSplit {
  final int index; // 1, 2, 3...
  final double distanceM;
  final int movingS;
  const KmSplit(this.index, this.distanceM, this.movingS);

  /// Allure du fractionne en secondes par km.
  int get paceSecPerKm => distanceM <= 0 ? 0 : (movingS * 1000 / distanceM).round();

  List<num> toJson() => [index, double.parse(distanceM.toStringAsFixed(1)), movingS];
  factory KmSplit.fromJson(List<dynamic> j) =>
      KmSplit(j[0] as int, (j[1] as num).toDouble(), j[2] as int);
}

/// Moteur d'enregistrement d'une sortie : recoit les points GPS reels et
/// calcule distance, temps en mouvement, vitesses, fractionnes, denivele.
///
/// Filtres appliques a chaque point :
///   1. precision horizontale > [maxAccuracyM]           -> ignore
///   2. deplacement plus petit que le bruit GPS           -> ignore (immobile)
///   3. vitesse impossible pour le sport (saut GPS)      -> ignore
///   4. segment trop lent (< [minMovingSpeed])            -> pas de distance,
///      pas de temps en mouvement
/// Pendant une pause aucun point n'est compte, et le premier point apres la
/// reprise ne fait que repositionner le depart du segment suivant.
///
/// Tout l'etat est rejouable a partir de [events] : c'est ce qui est
/// sauvegarde pour reprendre une sortie si l'application est tuee.
class TrackRecorder {
  static const double maxAccuracyM = 25;
  static const double minMovingSpeed = 0.4; // m/s (~1.4 km/h)
  static const double minStepM = 3;
  static const int maxSpikesInARow = 5; // ensuite on repart de ce point
  static const double maxAltAccuracyM = 15;
  static const double elevThresholdM = 3; // hysteresis anti-bruit
  static const Duration speedWindow = Duration(seconds: 15);

  /// Vitesse maximale plausible (m/s) : au-dela, le point est un saut GPS.
  static double maxSpeedFor(String type) => switch (type) {
        'Vélo' => 25, // 90 km/h en descente
        'Natation' => 4,
        _ => 12, // a pied : 43 km/h
      };

  final String type;
  final DateTime startedAt;
  DateTime? finishedAt;
  bool paused = false;

  final List<List<Object?>> _events = [];

  double distanceM = 0;
  double movingS = 0;
  final List<List<double>> route = []; // [lat, lng] pour la carte
  final List<KmSplit> splits = [];

  /// Derniere position connue (meme pendant la pause) : marqueur "vous".
  GpsFix? lastPosition;
  DateTime? lastFixAt;

  GpsFix? _anchor; // dernier point retenu du segment courant
  DateTime? _stillUntil; // immobile jusqu'a cet instant
  int _spikes = 0;
  double _splitStartMoving = 0;
  // fenetre glissante pour la vitesse : [fin du segment, distance, duree]
  final List<(DateTime, double, double)> _recent = [];
  double _maxSpeed = 0;

  // denivele
  int _fixesKept = 0;
  int _altFixes = 0;
  int _baroCount = 0;
  final _gpsClimb = _Climb(threshold: elevThresholdM, alpha: 0.3);
  final _baroClimb = _Climb(threshold: 1, alpha: 0.2);

  TrackRecorder({required this.type, required this.startedAt});

  // ---------------------------------------------------------------- events
  void pause(DateTime t) {
    if (paused || finishedAt != null) return;
    paused = true;
    _anchor = null; // le trajet fait pendant la pause ne compte pas
    _recent.clear();
    _gpsClimb.restart(); // ... ni le denivele
    _baroClimb.restart();
    _events.add(['p', t.millisecondsSinceEpoch]);
  }

  void resume(DateTime t) {
    if (!paused || finishedAt != null) return;
    paused = false;
    _events.add(['r', t.millisecondsSinceEpoch]);
  }

  void finish(DateTime t) {
    if (finishedAt != null) return;
    finishedAt = t;
    final rest = distanceM - splits.length * 1000;
    if (rest >= 50) {
      splits.add(KmSplit(splits.length + 1, rest, (movingS - _splitStartMoving).round()));
    }
  }

  /// Ajoute un point GPS. Retourne true si le point a ete retenu dans le trace.
  bool addFix(GpsFix f) {
    if (f.accuracy <= 50) lastPosition = f;
    lastFixAt = f.time;
    if (paused || finishedAt != null || f.accuracy > maxAccuracyM) return false;
    _events.add(['f', ...f.toJson()]);
    return _apply(f);
  }

  bool _apply(GpsFix f) {
    final a = _anchor;
    if (a == null) {
      _keep(f);
      return true;
    }
    final d = distanceBetween(a.lat, a.lng, f.lat, f.lng);
    final from = (_stillUntil != null && _stillUntil!.isAfter(a.time)) ? _stillUntil! : a.time;
    final dt = f.time.difference(from).inMilliseconds / 1000;
    if (dt <= 0) return false;
    final v = d / dt;

    // 2. bruit : le telephone "bouge" sur place
    if (d < math.max(minStepM, (a.accuracy + f.accuracy) / 4)) {
      final sinceAnchor = f.time.difference(a.time).inMilliseconds / 1000;
      if (d / sinceAnchor < minMovingSpeed) {
        _stillUntil = f.time;
      }
      return false;
    }

    // 3. saut GPS : vitesse impossible
    if (v > maxSpeedFor(type)) {
      if (++_spikes < maxSpikesInARow) return false;
      _keep(f); // le signal s'est vraiment deplace (sortie de tunnel...) : nouveau segment
      return true;
    }

    // 4. segment trop lent : on avance le depart sans compter
    if (v >= minMovingSpeed) {
      _addSegment(d, dt, f.time);
    }
    _keep(f);
    return true;
  }

  void _keep(GpsFix f) {
    _anchor = f;
    _stillUntil = null;
    _spikes = 0;
    _fixesKept++;
    route.add([_round6(f.lat), _round6(f.lng)]);
    _trackAltitude(f);
  }

  void _addSegment(double d, double dt, DateTime end) {
    // fractionnes : on interpole l'instant ou chaque km est franchi
    final before = distanceM, movingBefore = movingS;
    distanceM += d;
    movingS += dt;
    while (distanceM >= (splits.length + 1) * 1000) {
      final target = (splits.length + 1) * 1000.0;
      final at = movingBefore + dt * (target - before) / d;
      splits.add(KmSplit(splits.length + 1, 1000, (at - _splitStartMoving).round()));
      _splitStartMoving = at;
    }

    _recent.add((end, d, dt));
    _recent.removeWhere((s) => end.difference(s.$1) > speedWindow);
    // vitesse max sur au moins 5 s pour lisser les pics
    var sd = 0.0, st = 0.0;
    for (final s in _recent.reversed) {
      sd += s.$2;
      st += s.$3;
      if (st >= 5) {
        _maxSpeed = math.max(_maxSpeed, sd / st);
        break;
      }
    }
  }

  void _trackAltitude(GpsFix f) {
    final alt = f.alt, acc = f.altAccuracy;
    if (alt == null || acc == null || acc <= 0 || acc > maxAltAccuracyM) return;
    _altFixes++;
    _gpsClimb.add(alt);
  }

  /// Capteur barometrique du telephone (hPa) : altitude relative bien plus
  /// precise que le GPS. S'il existe, il remplace l'altitude GPS.
  void addPressure(double hPa, DateTime t) {
    if (paused || finishedAt != null || hPa < 300 || hPa > 1100) return;
    hPa = double.parse(hPa.toStringAsFixed(3)); // meme valeur en direct et au rejeu
    _events.add(['b', hPa, t.millisecondsSinceEpoch]);
    _baroCount++;
    _baroClimb.add(44330 * (1 - math.pow(hPa / 1013.25, 0.1903).toDouble())); // formule barometrique
  }

  // --------------------------------------------------------------- metrics
  double get km => distanceM / 1000;

  int elapsedS(DateTime now) => (finishedAt ?? now).difference(startedAt).inSeconds;

  /// Vitesse actuelle (m/s) sur les 15 dernieres secondes, 0 si a l'arret.
  double currentSpeed(DateTime now) {
    if (paused) return 0;
    var d = 0.0, t = 0.0;
    for (final s in _recent) {
      if (now.difference(s.$1) <= speedWindow) {
        d += s.$2;
        t += s.$3;
      }
    }
    return t < 3 ? 0 : d / t;
  }

  /// Vitesse moyenne en mouvement (m/s), null si pas assez de donnees.
  double? get avgSpeed => (movingS < 30 || distanceM < 50) ? null : distanceM / movingS;

  /// Vitesse max lissee (m/s), null si la sortie est trop courte pour etre fiable.
  double? get maxSpeed => (movingS < 60 || _maxSpeed <= 0) ? null : _maxSpeed;

  /// Denivele positif (m) : barometre si present, sinon GPS si son altitude
  /// etait fiable, sinon null.
  double? get elevationGain {
    if (_baroCount >= 10) return _baroClimb.gain;
    return (_fixesKept >= 10 && _altFixes >= _fixesKept * 0.8) ? _gpsClimb.gain : null;
  }

  /// Source du denivele, pour l'affichage.
  bool get usesBarometer => _baroCount >= 10;

  // ---------------------------------------------------------- persistence
  Map<String, Object?> toJson() => {
        'type': type,
        'start': startedAt.millisecondsSinceEpoch,
        'events': _events,
      };

  /// Reconstruit l'etat en rejouant les evenements enregistres.
  factory TrackRecorder.fromJson(Map<String, dynamic> j) {
    final r = TrackRecorder(
        type: j['type'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(j['start'] as int));
    for (final e in (j['events'] as List).cast<List<dynamic>>()) {
      switch (e[0]) {
        case 'p':
          r.pause(DateTime.fromMillisecondsSinceEpoch(e[1] as int));
        case 'r':
          r.resume(DateTime.fromMillisecondsSinceEpoch(e[1] as int));
        case 'f':
          r.addFix(GpsFix.fromJson(e.sublist(1)));
        case 'b':
          r.addPressure((e[1] as num).toDouble(), DateTime.fromMillisecondsSinceEpoch(e[2] as int));
      }
    }
    return r;
  }

  // ----------------------------------------------------------------- utils
  static double _round6(double v) => (v * 1e6).roundToDouble() / 1e6;

  /// Distance (m) entre deux coordonnees : formule de haversine.
  static double distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371008.8;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }
}

/// Cumul du denivele positif : altitude lissee (moyenne exponentielle) +
/// hysteresis de [threshold] metres pour ne pas compter le bruit du capteur.
class _Climb {
  final double threshold;
  final double alpha;
  _Climb({required this.threshold, required this.alpha});

  double gain = 0;
  double? _smooth;
  double? _ref;

  void add(double alt) {
    final s = _smooth = _smooth == null ? alt : _smooth! * (1 - alpha) + alt * alpha;
    final ref = _ref ??= s;
    if (s - ref >= threshold) {
      gain += s - ref;
      _ref = s;
    } else if (ref - s >= threshold) {
      _ref = s;
    }
  }

  /// Apres une pause : on repart de la nouvelle altitude.
  void restart() {
    _smooth = null;
    _ref = null;
  }
}
