import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/badge_dao.dart';
import '../data/challenge_dao.dart';
import '../models/challenge_models.dart';
import 'certificate_screen.dart';
import 'challenge_form_screen.dart';
import 'leaderboard_screen.dart';

/// CH-01 (defis) + BDG-01 (grille de badges).
/// Les utilisateurs : Participer / Quitter / Classement.
/// Les admins en plus : + Defi, modifier, supprimer, + Badge.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<Challenge> _challenges = [];
  List<BadgeItem> _badges = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ChallengeDao.getAll(Session.userId);
    final b = await BadgeDao.getAll(Session.userId);
    if (!mounted) return;
    setState(() {
      _challenges = c;
      _badges = b;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<void> _toggleJoin(Challenge c) async {
    if (!await GuestGate.check(context, message: 'Créez un compte pour participer.')) return;
    c.joined
        ? await ChallengeDao.leave(c.id, Session.userId!)
        : await ChallengeDao.join(c.id, Session.userId!);
    _load();
  }

  Future<void> _delete(Challenge c) async {
    final ok = await ConfirmSheet.show(context,
        title: 'Supprimer ce défi ?', message: c.title);
    if (!ok) return;
    await ChallengeDao.delete(c.id);
    if (!mounted) return;
    AppSnack.show(context, 'Défi supprimé');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final admin = Session.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Défis'),
        actions: [
          if (admin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                  onPressed: () => _push(const ChallengeFormScreen()),
                  child: const Text('+ Défi')),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_challenges.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Aucun défi pour le moment.', style: Theme.of(context).textTheme.bodySmall)),
            ),
          for (final c in _challenges) _challengeCard(c, admin),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Badges et certificats', style: Theme.of(context).textTheme.titleMedium)),
            if (admin)
              ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.badgeForm).then((_) => _load()),
                  child: const Text('+ Badge')),
          ]),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [for (final b in _badges) _badgeTile(b)],
          ),
        ],
      ),
    );
  }

  Widget _challengeCard(Challenge c, bool admin) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(c.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Text('${c.durationDays} j', style: const TextStyle(color: AppColors.red)),
          ]),
          Text('Objectif : ${c.goal.round()} ${c.measureLabel}', style: Theme.of(context).textTheme.bodySmall),
          if (c.joined) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
                value: c.ratio, color: AppColors.red, minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 4),
            Text('${c.progress.toStringAsFixed(1)} / ${c.goal.round()} ${c.measureLabel}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            // L'administrateur gere les defis mais n'y participe pas
            if (!admin)
              c.joined
                  ? OutlinedButton(onPressed: () => _toggleJoin(c), child: const Text('Quitter'))
                  : ElevatedButton(onPressed: () => _toggleJoin(c), child: const Text('Participer')),
            OutlinedButton(
                onPressed: () => _push(LeaderboardScreen(challenge: c)),
                child: const Text('Classement')),
            if (admin) ...[
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _push(ChallengeFormScreen(challenge: c))),
              IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.red), onPressed: () => _delete(c)),
            ],
          ]),
        ]),
      ),
    );
  }

  /// Badge obtenu = couleur ; badge verrouille = gris.
  Widget _badgeTile(BadgeItem b) {
    return InkWell(
      onTap: () => _push(CertificateScreen(badge: b)),
      child: Card(
        child: Opacity(
          opacity: b.earned ? 1 : 0.4,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(b.icon, style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 4),
            Text(b.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(b.earned ? 'Obtenu' : 'Verrouillé', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}
