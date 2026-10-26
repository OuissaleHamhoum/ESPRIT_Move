import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/services/reward_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/activity_dao.dart';
import '../data/photo_store.dart';
import '../models/activity.dart';
import '../tracking/draft_store.dart';
import '../widgets/activity_map.dart';
import '../widgets/activity_metrics.dart';
import '../widgets/photo_strip.dart';
import 'share_activity_screen.dart';

/// REC-05 : recapitulatif de la sortie. "Enregistrer" = CREATE en base.
class RecSummaryScreen extends StatefulWidget {
  final Activity activity; // calculee par TrackRecorder, pas encore en base
  const RecSummaryScreen({super.key, required this.activity});

  @override
  State<RecSummaryScreen> createState() => _RecSummaryScreenState();
}

class _RecSummaryScreenState extends State<RecSummaryScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  List<String> _photos = [];
  bool _shared = true; // visible dans le fil des amis
  bool _saving = false;

  Activity get _a => widget.activity;
  int get _points => (_a.distanceKm * RewardEngine.pointsPerKm).round();

  /// Regle metier : titre par defaut "Sport du jour"
  Activity get _current => _a.copyWith(
        title: _title.text.trim().isEmpty ? 'Sport du jour' : _title.text.trim(),
        notes: _notes.text.trim(),
        photos: _photos,
        shared: _shared,
      );

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 1. CREATE : on ajoute l'activite dans SQLite
      await ActivityDao.insert(_current);
      await DraftStore.clear();

      // 2. Points (10/km) + verification des badges (module 5)
      final badges = await RewardEngine.onActivityCreated(_a.userId, _a.distanceKm);

      if (!mounted) return;
      AppSnack.show(
          context,
          badges.isEmpty
              ? 'Sortie enregistrée +$_points pts'
              : 'Badge débloqué : ${badges.join(', ')} 🎉');

      // 3. Retour a l'onglet "Activites" (index 1)
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (r) => false,
          arguments: 1);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.show(context, 'Enregistrement impossible, réessayez.');
    }
  }

  Future<void> _discard() async {
    final ok = await ConfirmSheet.show(context,
        title: 'Ignorer cette sortie ?', message: 'Le parcours et les photos seront perdus.');
    if (!ok) return;
    await DraftStore.clear();
    await PhotoStore.deleteAll(_photos);
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  void _share() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ShareActivityScreen(activity: _current)));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // quitter = choisir Enregistrer ou Ignorer
      child: Scaffold(
        appBar: AppBar(title: const Text('Récapitulatif'), automaticallyImplyLeading: false),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: Text('🎉', style: TextStyle(fontSize: 48))),
            const Center(
                child: Text('Bravo !',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: StatTile(value: _a.distanceKm.toStringAsFixed(2), label: 'km')),
              Expanded(child: StatTile(value: '${_a.durationMin}', label: 'min')),
              Expanded(child: StatTile(value: '+$_points', label: 'points')),
            ]),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                  height: _a.route.length < 2 ? 110 : 240, child: ActivityMap(route: _a.route)),
            ),
            ActivityMetrics(activity: _a),
            PhotoStrip(photos: _photos, onChanged: (p) => setState(() => _photos = p)),
            const SizedBox(height: 12),
            AppTextField(label: 'Titre', controller: _title, hint: 'Sport du jour'),
            AppTextField(label: 'Notes', controller: _notes, maxLines: 3),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.red,
              title: const Text('Partager avec mes amis'),
              subtitle: const Text('La sortie apparaît dans leur fil d’activité'),
              value: _shared,
              onChanged: (v) => setState(() => _shared = v),
            ),
            AppButton(label: 'Enregistrer la sortie', loading: _saving, onPressed: _save),
            const SizedBox(height: 10),
            AppButton(
                label: 'Partager l’activité', icon: Icons.ios_share, outlined: true, onPressed: _share),
            const SizedBox(height: 10),
            AppButton(label: 'Ignorer', outlined: true, onPressed: _discard),
          ],
        ),
      ),
    );
  }
}
