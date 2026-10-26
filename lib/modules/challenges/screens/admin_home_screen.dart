import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/home_dao.dart';
import '../models/challenge_models.dart';

/// ADMIN (onglet "Accueil") : chiffres cles, reservations du jour,
/// raccourcis de gestion et compte administrateur.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  AdminSummary? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await HomeDao.adminSummary();
    if (mounted) setState(() => _data = d);
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    _load();
  }

  /// Ouvre un autre onglet de l'espace admin (1 terrains, 2 reservations, 3 comptes).
  void _tab(int index) =>
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (r) => false,
          arguments: index);

  Future<void> _logout() async {
    await Session.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.signIn, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text.rich(TextSpan(children: [
          TextSpan(text: 'ESPRIT '),
          TextSpan(text: 'Move', style: TextStyle(color: AppColors.red)),
          TextSpan(text: '  ·  Admin', style: TextStyle(fontSize: 14, color: AppColors.grey)),
        ])),
      ),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Bonjour ${Session.name.split(' ').first} 👋',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _stat('${d.students}', 'étudiants', () => _tab(3))),
                    Expanded(
                        child: _stat('${d.pendingCards}', 'cartes à valider', () => _tab(3),
                            highlight: d.pendingCards > 0)),
                  ]),
                  Row(children: [
                    Expanded(child: _stat('${d.activeFacilities}', 'terrains ouverts', () => _tab(1))),
                    Expanded(
                        child: _stat('${d.upcomingBookings}', 'réservations à venir', () => _tab(2))),
                  ]),
                  const SizedBox(height: 12),
                  Text('Réservations du jour', style: Theme.of(context).textTheme.titleMedium),
                  if (d.today.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('Aucune réservation aujourd’hui.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  for (final b in d.today)
                    Card(
                      child: ListTile(
                        dense: true,
                        leading: Text(b.icon, style: const TextStyle(fontSize: 22)),
                        title: Text(b.text),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text('Gestion', style: Theme.of(context).textTheme.titleMedium),
                  _link(Icons.emoji_events_outlined, 'Défis et badges', AppRoutes.challenges),
                  _link(Icons.card_giftcard, 'Récompenses', AppRoutes.rewards),
                  _link(Icons.event_outlined, 'Événements', AppRoutes.adminEvents),
                  _link(Icons.insights_outlined, 'Engagement campus', AppRoutes.dashboard),
                  const SizedBox(height: 12),
                  Text('Mon compte', style: Theme.of(context).textTheme.titleMedium),
                  _link(Icons.lock_outline, 'Changer le mot de passe', AppRoutes.changePassword),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.brightness_6_outlined),
                      title: const Text('Thème clair / sombre'),
                      onTap: ThemeController.toggle,
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.red),
                      title: const Text('Se déconnecter',
                          style: TextStyle(color: AppColors.red)),
                      onTap: _logout,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _stat(String value, String label, VoidCallback onTap, {bool highlight = false}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: highlight
            ? Card(
                color: AppColors.gold.withValues(alpha: 0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gold)),
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              )
            : StatTile(value: value, label: label),
      );

  Widget _link(IconData icon, String label, String route) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(route),
        ),
      );
}
