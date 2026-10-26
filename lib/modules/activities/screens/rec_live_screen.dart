import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../core/services/location_service.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../models/activity.dart';
import '../tracking/draft_store.dart';
import '../tracking/track_recorder.dart';
import '../widgets/activity_map.dart';
import 'rec_summary_screen.dart';

/// Les 3 etats de l'enregistrement.
enum RecPhase { countdown, running, paused }

/// REC-02 (compte a rebours 3-2-1) + REC-03 (en direct) + REC-04 (en pause).
/// Un seul ecran, 3 etats : plus simple que 3 pages qui se passent des donnees.
///
/// Les points GPS reels (package geolocator) sont confies a [TrackRecorder],
/// qui filtre les points imprecis et calcule distance, temps et allures.
/// Sur Android, un service de premier plan (notification) garde le GPS actif
/// ecran verrouille. La sortie est sauvegardee regulierement ([DraftStore]) :
/// si l'app est tuee, elle est proposee a la reprise ([restore]).
class RecLiveScreen extends StatefulWidget {
  final String type;
  final TrackRecorder? restore;
  const RecLiveScreen({super.key, required this.type, this.restore});

  @override
  State<RecLiveScreen> createState() => _RecLiveScreenState();
}

class _RecLiveScreenState extends State<RecLiveScreen> with WidgetsBindingObserver {
  static const _signalLostAfter = Duration(seconds: 15);
  static const _saveEvery = Duration(seconds: 15);

  RecPhase _phase = RecPhase.countdown;
  int _count = 3; // 3 -> 2 -> 1
  TrackRecorder? _rec; // cree a la fin du decompte
  GpsFix? _preview; // position affichee pendant le decompte
  String? _gpsError; // message si le GPS est indisponible
  Timer? _timer;
  Timer? _retry;
  StreamSubscription<Position>? _gps;
  StreamSubscription<BarometerEvent>? _baro;
  DateTime _lastBaro = DateTime(0);
  DateTime _lastSave = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final r = widget.restore;
    if (r != null) {
      r.pause(r.lastFixAt ?? DateTime.now()); // reprise : l'utilisateur relance lui-meme
      _rec = r;
      _phase = RecPhase.paused;
      _startTicker();
    } else {
      _startCountdown();
    }
    _initGps();
    _initBarometer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel(); // IMPORTANT : arreter le chrono en quittant l'ecran
    _retry?.cancel();
    _gps?.cancel(); // ... et le GPS (arrete aussi le service de premier plan)
    _baro?.cancel();
    super.dispose();
  }

  /// Barometre du telephone (s'il existe) pour un denivele precis.
  /// Pas de capteur : erreur ignoree, le denivele vient alors du GPS.
  void _initBarometer() {
    _baro = barometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen(
      (e) {
        final now = DateTime.now();
        if (now.difference(_lastBaro) < const Duration(seconds: 1)) return; // 1 mesure / s
        _lastBaro = now;
        _rec?.addPressure(e.pressure, now);
      },
      onError: (_) => _baro = null,
      cancelOnError: true,
    );
  }

  /// App mise en arriere-plan : on sauvegarde tout de suite.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _saveDraft();
  }

  // ---------- GPS ----------
  Future<void> _initGps() async {
    final error = await LocationService.ensurePermission();
    if (!mounted) return;
    if (error != null) {
      setState(() => _gpsError = error);
      _scheduleRetry();
      return;
    }
    await LocationService.ensureNotificationPermission();
    if (!mounted) return;
    _gps = LocationService.track(background: true).listen(
      _onPosition,
      onError: (_) {
        if (mounted) setState(() => _gpsError = 'Signal GPS perdu, nouvelle tentative…');
        _scheduleRetry();
      },
      onDone: _scheduleRetry,
      cancelOnError: true,
    );
  }

  /// GPS coupe ou permission refusee : on reessaie toutes les 5 s,
  /// la sortie continue sans perdre ce qui est deja enregistre.
  void _scheduleRetry() {
    _gps?.cancel();
    _gps = null;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 5), () {
      if (mounted) _initGps();
    });
  }

  void _onPosition(Position p) {
    if (p.isMocked) return; // positions simulees refusees : uniquement le vrai GPS
    final fix = GpsFix(
      lat: p.latitude,
      lng: p.longitude,
      accuracy: p.accuracy,
      time: p.timestamp,
      alt: p.hasAltitude ? p.altitude : null,
      altAccuracy: p.hasAltitudeAccuracy ? p.altitudeAccuracy : null,
    );
    _gpsError = null;
    final r = _rec;
    if (r == null) {
      setState(() => _preview = fix);
    } else {
      r.addFix(fix); // l'affichage est rafraichi par le chrono (1 fois / s)
    }
  }

  // ---------- REC-02 : 3, 2, 1 puis on demarre ----------
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count > 1) {
        setState(() => _count--);
      } else {
        t.cancel();
        final now = DateTime.now();
        _rec = TrackRecorder(type: widget.type, startedAt: now);
        // point de depart = derniere position reelle si elle date de moins de 5 s
        final p = _preview;
        if (p != null && now.difference(p.time) < const Duration(seconds: 5)) {
          _rec!.addFix(p.withTime(now));
        }
        setState(() => _phase = RecPhase.running);
        _startTicker();
      }
    });
  }

  // ---------- REC-03 : chronometre en direct ----------
  /// Le temps vient de l'horloge du telephone (pas d'un compteur) : il reste
  /// exact meme si Android ralentit l'app en arriere-plan.
  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().difference(_lastSave) >= _saveEvery) _saveDraft();
      setState(() {});
    });
  }

  Future<void> _saveDraft() async {
    final r = _rec;
    if (r == null || r.finishedAt != null) return;
    _lastSave = DateTime.now();
    try {
      await DraftStore.save(r);
    } catch (_) {} // stockage plein : l'enregistrement en memoire continue
  }

  // ---------- REC-04 : pause / reprise ----------
  void _pause() {
    setState(() {
      _rec!.pause(DateTime.now());
      _phase = RecPhase.paused;
    });
    _saveDraft();
  }

  void _resume() {
    setState(() {
      _rec!.resume(DateTime.now());
      _phase = RecPhase.running;
    });
  }

  void _finish() {
    final r = _rec!..finish(DateTime.now());
    _timer?.cancel();
    _retry?.cancel();
    _gps?.cancel();
    _gps = null;
    _baro?.cancel();
    _baro = null;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RecSummaryScreen(activity: Activity.fromRecorder(r, userId: Session.userId!)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope : empeche de quitter par erreur avec le bouton retour
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: _phase == RecPhase.countdown ? _buildCountdown() : _buildLive(),
        ),
      ),
    );
  }

  Widget _buildCountdown() => Center(
        child: Text('$_count',
            style: const TextStyle(
                fontSize: 140, fontWeight: FontWeight.w900, color: AppColors.red)),
      );

  String _status(TrackRecorder r, DateTime now) {
    if (_gpsError != null) return _gpsError!;
    final last = r.lastFixAt;
    if (last == null) return '📡 Recherche du signal GPS…';
    if (now.difference(last) > _signalLostAfter) return '📡 Signal GPS perdu, recherche…';
    return '📡 GPS actif';
  }

  Widget _buildLive() {
    final r = _rec!;
    final now = DateTime.now();
    final paused = _phase == RecPhase.paused;
    final status = _status(r, now);
    final pos = r.lastPosition ?? _preview;
    final avgPace = r.km < 0.05 ? null : r.movingS / r.km;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('${ActivityTypes.iconOf(widget.type)} ${widget.type}'
              '${paused ? '  ·  EN PAUSE' : ''}'),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
                fontSize: 12, color: status == '📡 GPS actif' ? AppColors.grey : AppColors.red),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: ActivityMap(
                route: r.route,
                current: pos == null ? null : LatLng(pos.lat, pos.lng),
                live: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Gros chiffre : distance (72 px, extra-gras)
          Text(r.km.toStringAsFixed(2),
              style: TextStyle(
                  fontSize: 72,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: paused ? AppColors.grey : null)),
          Text('kilomètres', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(children: [
            _tile(Fmt.clock(r.elapsedS(now)), 'durée'),
            _tile(Fmt.paceFromSpeed(r.currentSpeed(now)), 'allure /km'),
            _tile(Fmt.kmh(r.currentSpeed(now)), 'km/h'),
          ]),
          Row(children: [
            _tile(Fmt.clock(r.movingS.round()), 'en mouvement'),
            _tile(Fmt.paceSec(avgPace), 'allure moy.'),
            _tile('${(r.movingS / 60 * 8).round()}', 'kcal'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: paused ? _resume : _pause,
                child: Text(paused ? '▶ Reprendre' : '❚❚ Pause'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: _finish,
                child: const Text('■ Terminer'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _tile(String value, String label) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: [
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}
