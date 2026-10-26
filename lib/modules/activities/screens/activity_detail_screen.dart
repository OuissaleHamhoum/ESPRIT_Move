import 'package:flutter/material.dart';
import '../../../core/services/reward_engine.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/activity_dao.dart';
import '../data/friend_dao.dart';
import '../models/activity.dart';
import '../widgets/activity_map.dart';
import '../widgets/activity_metrics.dart';
import '../widgets/photo_strip.dart';
import 'activity_edit_screen.dart';
import 'share_activity_screen.dart';

/// ACT-02 : detail d'une activite (carte, statistiques, fractionnes, photos).
/// Proprietaire : Partager, visibilite amis, Modifier (ACT-03), Supprimer (ACT-04).
/// Ami : lecture seule (uniquement si la sortie a ete partagee avec lui).
class ActivityDetailScreen extends StatefulWidget {
  final int activityId;
  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  Activity? _activity;
  bool _missing = false; // supprimee, ou pas partagee avec moi

  bool get _mine => _activity?.userId == Session.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Session.userId;
    final a = uid == null ? null : await FriendDao.visible(widget.activityId, uid);
    if (!mounted) return;
    setState(() {
      _activity = a;
      _missing = a == null;
    });
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActivityEditScreen(activity: _activity!)),
    );
    _load(); // affiche les nouvelles valeurs
  }

  /// Photos ou visibilite modifiees : UPDATE immediat.
  Future<void> _save(Activity updated) async {
    setState(() => _activity = updated);
    await ActivityDao.update(updated);
  }

  /// DELETE avec confirmation (ACT-04).
  Future<void> _delete() async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Supprimer cette activité ?',
      message: 'Cette action est définitive.',
    );
    if (!ok) return;
    final a = _activity!;
    await ActivityDao.delete(a);
    // on retire les points gagnes avec cette sortie (10 / km)
    await RewardEngine.addPoints(a.userId, -(a.distanceKm * RewardEngine.pointsPerKm).round());
    if (!mounted) return;
    AppSnack.show(context, 'Activité supprimée');
    Navigator.pop(context); // retour a la liste (ACT-01)
  }

  @override
  Widget build(BuildContext context) {
    final a = _activity;
    return Scaffold(
      appBar: AppBar(title: const Text('Détail')),
      body: _missing
          ? const EmptyState(emoji: '🔒', message: 'Cette activité n’est pas disponible.')
          : a == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Bandeau rouge : sport, titre, date
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [AppColors.red, AppColors.darkBg]),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ActivityTypes.iconOf(a.type), style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${Fmt.shortDate(a.date)} · ${a.type}'
                        '${_mine || a.authorName == null ? '' : ' · ${a.authorName}'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat(a.distanceKm.toStringAsFixed(2), 'km'),
                    _stat('${a.durationMin}', 'minutes'),
                    _stat(Fmt.paceSec(a.avgPaceSecPerKm), 'min/km'),
                  ],
                ),
                // Trace du parcours enregistre par le GPS
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: a.route.length < 2 ? 110 : 240,
                    child: ActivityMap(route: a.route),
                  ),
                ),
                ActivityMetrics(activity: a),
                if (_mine || a.photos.isNotEmpty)
                  PhotoStrip(
                      photos: a.photos,
                      onChanged: _mine ? (p) => _save(a.copyWith(photos: p)) : null),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(a.notes.isEmpty ? 'Aucune note.' : a.notes),
                      ],
                    ),
                  ),
                ),
                // Actions reservees au proprietaire de la sortie
                if (_mine) ...[
                  Card(
                    child: SwitchListTile(
                      activeThumbColor: AppColors.red,
                      secondary: const Icon(Icons.people_alt_outlined),
                      title: const Text('Visible par mes amis'),
                      subtitle: Text(a.shared ? 'Dans le fil de vos amis' : 'Privée : vous seul la voyez'),
                      value: a.shared,
                      onChanged: (v) => _save(a.copyWith(shared: v)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Partager l’activité',
                    icon: Icons.ios_share,
                    outlined: true,
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ShareActivityScreen(activity: a))),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(label: 'Modifier', onPressed: _edit),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(label: 'Supprimer', outlined: true, onPressed: _delete),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}
