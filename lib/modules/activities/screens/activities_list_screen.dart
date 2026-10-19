import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/activity_dao.dart';
import '../models/activity.dart';
import '../widgets/activity_tile.dart';
import 'activity_detail_screen.dart';

/// ACT-01 (liste) + ACT-05 (etat vide) : onglet "Activites".
class ActivitiesListScreen extends StatefulWidget {
  const ActivitiesListScreen({super.key});

  @override
  State<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends State<ActivitiesListScreen> {
  List<Activity> _activities = [];
  ActivityStats _stats = const ActivityStats(0, 0, 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// READ : charge l'historique depuis SQLite.
  Future<void> _load() async {
    final uid = Session.userId;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final list = await ActivityDao.getByUser(uid);
    final stats = await ActivityDao.last7Days(uid);
    if (!mounted) return;
    setState(() {
      _activities = list;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _openDetail(Activity a) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: a.id!)));
    _load(); // au retour, on recharge (l'activite a peut-etre change)
  }

  void _startRecording() => Navigator.pushNamed(context, AppRoutes.recChoose);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Mes activités'),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Visiteur sans compte : pas d'historique
    if (Session.isGuest) {
      return EmptyState(
        emoji: '🔒',
        message: 'Créez un compte pour enregistrer vos sorties.',
        buttonLabel: 'Créer mon compte',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.signUp),
      );
    }

    // ACT-05 : etat vide
    if (_activities.isEmpty) {
      return EmptyState(
        emoji: '🏃',
        message: 'Aucune activité. Lancez votre première sortie !',
        buttonLabel: 'Enregistrer',
        onPressed: _startRecording,
      );
    }

    // ACT-01 : liste
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: StatTile(value: _stats.km.toStringAsFixed(1), label: 'km / 7 jours')),
            Expanded(child: StatTile(value: '${_stats.count}', label: 'sorties')),
            Expanded(child: StatTile(value: '${_stats.minutes}', label: 'minutes')),
          ]),
          const SizedBox(height: 8),
          AppButton(
              label: 'Enregistrer une activité',
              icon: Icons.fiber_manual_record,
              onPressed: _startRecording),
          const SizedBox(height: 16),
          Text('Historique', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final a in _activities)
            ActivityTile(activity: a, onTap: () => _openDetail(a)),
        ],
      ),
    );
  }
}
