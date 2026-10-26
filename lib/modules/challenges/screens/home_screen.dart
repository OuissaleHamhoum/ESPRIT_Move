import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/home_dao.dart';
import '../models/challenge_models.dart';

/// HOME-01 : accueil. Assemble les donnees des 4 autres modules.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await HomeDao.load(Session.userId);
    if (mounted) setState(() => _data = d);
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    _load(); // les points ont peut-etre change
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: const AppTopBar(),
      body: d == null
          ? const Center(child: CircularProgressIndicator()) // chargement
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(d),
                  const SizedBox(height: 12),
                  _weeklyCard(d),
                  const SizedBox(height: 8),
                  _shortcuts(),
                  const SizedBox(height: 12),
                  Text('Prochain événement', style: Theme.of(context).textTheme.titleMedium),
                  Card(
                    child: ListTile(
                      leading: const Text('📅', style: TextStyle(fontSize: 26)),
                      title: Text(d.nextEventTitle ?? 'Aucun événement prévu'),
                      subtitle: Text(d.nextEventInfo ?? 'Rejoignez-en un dans l’onglet Événements'),
                      onTap: () => Navigator.pushNamedAndRemoveUntil(
                          context, AppRoutes.main, (r) => false,
                          arguments: 2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Impact campus', style: Theme.of(context).textTheme.titleMedium),
                  Row(children: [
                    Expanded(child: StatTile(value: '${d.activeStudents}', label: 'étudiants actifs')),
                    Expanded(child: StatTile(value: d.campusKm.toStringAsFixed(0), label: 'km ce mois')),
                    Expanded(child: StatTile(value: '${d.eventsCount}', label: 'événements')),
                  ]),
                  const SizedBox(height: 8),
                  Text('Fil de la communauté', style: Theme.of(context).textTheme.titleMedium),
                  for (final line in d.feed)
                    Card(child: ListTile(leading: Text(line.icon, style: const TextStyle(fontSize: 22)), title: Text(line.text))),
                  if (d.feed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Aucune activité pour le moment. Lancez la première ! 🏃',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }

  Widget _header(HomeData d) => Row(children: [
        Expanded(
          child: Text(Session.isGuest ? 'Salut 👋' : 'Salut ${d.userName} 👋',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        if (!Session.isGuest)
          InkWell(
            onTap: () => _open(AppRoutes.rewards),
            child: Chip(
              avatar: const Icon(Icons.star, color: AppColors.gold, size: 18),
              label: Text('${d.points} pts',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
          ),
      ]);

  /// Anneau d'objectif hebdomadaire + serie de jours
  Widget _weeklyCard(HomeData d) {
    final ratio = (d.weekKm / HomeData.weeklyGoalKm).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                    value: ratio, strokeWidth: 8, color: AppColors.red,
                    backgroundColor: AppColors.grey.withValues(alpha: 0.3)),
              ),
              Text('${(ratio * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d.weekKm.toStringAsFixed(1)} / ${HomeData.weeklyGoalKm.round()} km',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('objectif de la semaine', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text('🔥 ${d.streak} jour${d.streak > 1 ? 's' : ''} de série'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _shortcuts() {
    Widget item(String emoji, String label, String route) => Expanded(
          child: InkWell(
            onTap: () => _open(route),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      item('🏟️', 'Réserver', AppRoutes.booking),
      item('🏆', 'Défis', AppRoutes.challenges),
      item('👥', 'Groupes', AppRoutes.groups),
      item('⭐', 'Points', AppRoutes.rewards),
    ]);
  }
}
