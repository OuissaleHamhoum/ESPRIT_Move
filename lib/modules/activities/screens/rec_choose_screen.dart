import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/activity_dao.dart';
import '../models/activity.dart';
import 'rec_live_screen.dart';

/// REC-01 : choix du sport + gros bouton GO.
class RecChooseScreen extends StatefulWidget {
  const RecChooseScreen({super.key});

  @override
  State<RecChooseScreen> createState() => _RecChooseScreenState();
}

class _RecChooseScreenState extends State<RecChooseScreen> {
  String _type = 'Course';
  bool _beacon = false;

  @override
  void initState() {
    super.initState();
    _loadBeacon();
  }

  Future<void> _loadBeacon() async {
    final uid = Session.userId;
    if (uid == null) return;
    final b = await ActivityDao.isBeaconActive(uid);
    if (mounted) setState(() => _beacon = b);
  }

  Future<void> _go() async {
    final ok = await GuestGate.check(context,
        message: 'Créez un compte pour enregistrer vos sorties.');
    if (!ok) return;
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => RecLiveScreen(type: _type)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle sortie'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
      body: Container(
        width: double.infinity, // pleine largeur : GO bien centre
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ChipSelector(
                options: ActivityTypes.all,
                selected: {_type},
                onTap: (t) => setState(() => _type = t),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _go,
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                    color: AppColors.red, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Text('GO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _beacon
                  ? '📍 Beacon activé : vos contacts vous voient'
                  : '📍 Beacon désactivé (touchez Profil pour l’activer)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
