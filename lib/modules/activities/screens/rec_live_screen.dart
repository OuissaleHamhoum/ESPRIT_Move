import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../models/activity.dart';
import 'rec_summary_screen.dart';

/// Les 3 etats de l'enregistrement.
enum RecPhase { countdown, running, paused }

/// REC-02 (compte a rebours 3-2-1) + REC-03 (en direct) + REC-04 (en pause).
/// Un seul ecran, 3 etats : plus simple que 3 pages qui se passent des donnees.
///
/// PROTOTYPE : la distance est SIMULEE a partir d'une vitesse moyenne par sport.
/// Pour le vrai GPS : package geolocator (voir GUIDE.md, section Evolutions).
class RecLiveScreen extends StatefulWidget {
  final String type;
  const RecLiveScreen({super.key, required this.type});

  @override
  State<RecLiveScreen> createState() => _RecLiveScreenState();
}

class _RecLiveScreenState extends State<RecLiveScreen> {
  RecPhase _phase = RecPhase.countdown;
  int _count = 3; // 3 -> 2 -> 1
  int _seconds = 0; // temps ecoule
  double _km = 0; // distance simulee
  bool _fast = false; // mode demo : 1 s reelle = 30 s d'activite
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel(); // IMPORTANT : arreter le chrono en quittant l'ecran
    super.dispose();
  }

  // ---------- REC-02 : 3, 2, 1 puis on demarre ----------
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count > 1) {
        setState(() => _count--);
      } else {
        t.cancel();
        _startRunning();
      }
    });
  }

  // ---------- REC-03 : chronometre en direct ----------
  void _startRunning() {
    setState(() => _phase = RecPhase.running);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final step = _fast ? 30 : 1; // secondes d'activite par tick
      final speed = ActivityTypes.demoSpeedKmh[widget.type] ?? 0;
      setState(() {
        _seconds += step;
        _km += speed / 3600 * step;
      });
    });
  }

  // ---------- REC-04 : pause / reprise ----------
  void _pause() {
    _timer?.cancel();
    setState(() => _phase = RecPhase.paused);
  }

  void _finish() {
    _timer?.cancel();
    final minutes = (_seconds / 60).round();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RecSummaryScreen(
          type: widget.type,
          km: double.parse(_km.toStringAsFixed(2)),
          minutes: minutes < 1 ? 1 : minutes,
        ),
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

  Widget _buildLive() {
    final minutes = _seconds / 60;
    final paused = _phase == RecPhase.paused;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('${ActivityTypes.iconOf(widget.type)} ${widget.type}'
              '${paused ? '  ·  EN PAUSE' : ''}'),
          const Spacer(),
          // Gros chiffre : distance (72 px, extra-gras)
          Text(_km.toStringAsFixed(2),
              style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: paused ? AppColors.grey : null)),
          Text('kilomètres', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          Row(children: [
            _tile(Fmt.clock(_seconds), 'durée'),
            _tile(Fmt.pace(_km, minutes.ceil()), 'min/km'),
            _tile('${(minutes * 8).round()}', 'kcal'),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Accélérer (démo ×30)'),
            value: _fast,
            activeThumbColor: AppColors.red,
            onChanged: (v) => setState(() => _fast = v),
          ),
          const Spacer(),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: paused ? _startRunning : _pause,
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}
