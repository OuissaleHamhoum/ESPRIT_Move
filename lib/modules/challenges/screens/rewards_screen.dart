import 'package:flutter/material.dart';
import '../../../core/services/reward_engine.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/badge_dao.dart';
import '../models/challenge_models.dart';

/// REW-01 : solde de points + recompenses a echanger (etudiant).
/// L'administrateur voit le meme catalogue et peut ajouter / retirer
/// des recompenses (pas d'echange pour lui).
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  List<Reward> _rewards = [];
  int _points = 0;
  bool _loading = true;

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
      _loading = false;
    });
  }

  Future<void> _redeem(Reward r) async {
    if (!await GuestGate.check(context, message: 'Créez un compte pour gagner des points.')) return;
    if (!mounted) return;
    final confirm = await ConfirmSheet.show(context,
        title: 'Échanger ${r.cost} points ?',
        message: r.name,
        confirmLabel: 'Échanger');
    if (!confirm) return;
    final ok = await RewardEngine.spend(Session.userId!, r.cost);
    if (!mounted) return;
    AppSnack.show(context, ok ? '${r.name} échangé(e) ! 🎉' : 'Points insuffisants', error: !ok);
    _load();
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final icon = TextEditingController(text: '🎁');
    final cost = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle récompense'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(hintText: 'Nom (ex. Gourde ESPRIT)'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: icon,
              decoration: const InputDecoration(hintText: 'Emoji'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Coût en points'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1) ? 'Nombre de points invalide' : null;
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await BadgeDao.insertReward(name.text.trim(),
          icon.text.trim().isEmpty ? '🎁' : icon.text.trim(), int.parse(cost.text.trim()));
      _load();
    }
    name.dispose();
    icon.dispose();
    cost.dispose();
  }

  Future<void> _delete(Reward r) async {
    final ok = await ConfirmSheet.show(context,
        title: 'Retirer cette récompense ?', message: r.name, confirmLabel: 'Retirer');
    if (!ok) return;
    await BadgeDao.deleteReward(r.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final admin = Session.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: Text(admin ? '🎁 Récompenses' : '⭐ Points et récompenses'),
        actions: [
          if (admin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(onPressed: _add, child: const Text('+ Récompense')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!admin) ...[
                  Center(
                    child: Text('$_points points',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.gold)),
                  ),
                  Center(
                    child: Text('10 pts par km · 50 pts par événement · 100 pts par badge',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_rewards.isEmpty)
                  SizedBox(
                    height: 240,
                    child: EmptyState(
                      emoji: '🎁',
                      message: admin
                          ? 'Aucune récompense. Ajoutez-en pour motiver les étudiants.'
                          : 'Aucune récompense disponible pour le moment.',
                    ),
                  ),
                for (final r in _rewards)
                  Card(
                    child: ListTile(
                      leading: Text(r.icon, style: const TextStyle(fontSize: 28)),
                      title: Text(r.name),
                      subtitle: Text('${r.cost} pts'),
                      trailing: admin
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.red),
                              onPressed: () => _delete(r))
                          : ElevatedButton(
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
