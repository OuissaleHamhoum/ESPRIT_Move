import 'package:flutter/material.dart';
import '../../../core/services/reward_engine.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/badge_dao.dart';
import '../models/challenge_models.dart';

/// REW-01 : solde de points + recompenses a echanger.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  List<Reward> _rewards = [];
  int _points = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BadgeDao.rewards();
    final p = Session.userId == null ? 0 : await RewardEngine.balance(Session.userId!);
    if (!mounted) return;
    setState(() {
      _rewards = r;
      _points = p;
    });
  }

  Future<void> _redeem(Reward r) async {
    if (!await GuestGate.check(context, message: 'Créez un compte pour gagner des points.')) return;
    final ok = await RewardEngine.spend(Session.userId!, r.cost);
    if (!mounted) return;
    AppSnack.show(context, ok ? '${r.name} échangé(e) ! 🎉' : 'Points insuffisants', error: !ok);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⭐ Points et récompenses')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Text('$_points points',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.gold)),
          ),
          Center(
            child: Text('10 pts par km · 50 pts par événement · 100 pts par badge',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 16),
          for (final r in _rewards)
            Card(
              child: ListTile(
                leading: Text(r.icon, style: const TextStyle(fontSize: 28)),
                title: Text(r.name),
                subtitle: Text('${r.cost} pts'),
                trailing: ElevatedButton(
                  onPressed: _points >= r.cost ? () => _redeem(r) : null,
                  child: const Text('Échanger'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
