import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/activity_dao.dart';
import '../models/activity.dart';
import '../widgets/activity_tile.dart';
import 'activity_detail_screen.dart';
import 'activity_stats_screen.dart';
import 'friends_screen.dart';

/// ACT-01 (liste) + ACT-05 (etat vide) : onglet "Activites".
/// Filtres par sport et par periode, acces aux statistiques et aux amis.
class ActivitiesListScreen extends StatefulWidget {
  const ActivitiesListScreen({super.key});

  @override
  State<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends State<ActivitiesListScreen> {
  static const _all = 'Tous';

  List<Activity> _activities = [];
  bool _loading = true;
  String _sport = _all;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// READ : charge l'historique depuis SQLite (une seule requete, allegee).
  Future<void> _load() async {
    final uid = Session.userId;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final list = await ActivityDao.getByUser(uid);
    if (!mounted) return;
    setState(() {
      _activities = list;
      _loading = false;
    });
  }

  List<Activity> get _filtered {
    final from = _range == null ? null : Fmt.dbDate(_range!.start);
    final to = _range == null ? null : Fmt.dbDate(_range!.end);
    return [
      for (final a in _activities)
        if ((_sport == _all || a.type == _sport) &&
            (from == null || a.date.compareTo(from) >= 0) &&
            (to == null || a.date.compareTo(to) <= 0))
          a,
    ];
  }

  Future<void> _openDetail(Activity a) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: a.id!)));
    _load(); // au retour, on recharge (l'activite a peut-etre change)
  }

  void _startRecording() => Navigator.pushNamed(context, AppRoutes.recChoose);

  Future<void> _openFriends() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

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
      return Column(children: [
        Expanded(
          child: EmptyState(
            emoji: '🏃',
            message: 'Aucune activité. Lancez votre première sortie !',
            buttonLabel: 'Enregistrer',
            onPressed: _startRecording,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AppButton(
              label: 'Amis', icon: Icons.people_alt_outlined, outlined: true, onPressed: _openFriends),
        ),
      ]);
    }

    final week = ActivityStats.of(_activities,
        from: Fmt.dbDate(DateTime.now().subtract(const Duration(days: 6))));
    final sports = {for (final a in _activities) a.type};
    final shown = _filtered;

    // ACT-01 : liste
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: StatTile(value: week.km.toStringAsFixed(1), label: 'km / 7 jours')),
            Expanded(child: StatTile(value: '${week.count}', label: 'sorties')),
            Expanded(child: StatTile(value: '${week.minutes}', label: 'minutes')),
          ]),
          const SizedBox(height: 8),
          AppButton(
              label: 'Enregistrer une activité',
              icon: Icons.fiber_manual_record,
              onPressed: _startRecording),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: AppButton(
                label: 'Statistiques',
                icon: Icons.bar_chart,
                outlined: true,
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ActivityStatsScreen(activities: _activities))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                  label: 'Amis',
                  icon: Icons.people_alt_outlined,
                  outlined: true,
                  onPressed: _openFriends),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Historique', style: Theme.of(context).textTheme.titleMedium)),
            if (_range != null)
              IconButton(
                  tooltip: 'Toutes les dates',
                  onPressed: () => setState(() => _range = null),
                  icon: const Icon(Icons.close, size: 18)),
            TextButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(_range == null
                  ? 'Dates'
                  : '${Fmt.dayMonth(Fmt.dbDate(_range!.start))} → ${Fmt.dayMonth(Fmt.dbDate(_range!.end))}'),
            ),
          ]),
          if (sports.length > 1)
            ChipSelector(
              options: [_all, ...ActivityTypes.all.where(sports.contains)],
              selected: {_sport},
              onTap: (s) => setState(() => _sport = s),
            ),
          const SizedBox(height: 4),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune activité pour ces filtres.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey)),
            ),
          for (final a in shown) ActivityTile(activity: a, onTap: () => _openDetail(a)),
        ],
      ),
    );
  }
}
