import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/services/reward_engine.dart';
import '../../../core/session/session.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/activity_dao.dart';
import '../models/activity.dart';

/// REC-05 : recapitulatif de la sortie. "Enregistrer" = CREATE en base.
class RecSummaryScreen extends StatefulWidget {
  final String type;
  final double km;
  final int minutes;
  const RecSummaryScreen(
      {super.key, required this.type, required this.km, required this.minutes});

  @override
  State<RecSummaryScreen> createState() => _RecSummaryScreenState();
}

class _RecSummaryScreenState extends State<RecSummaryScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  int get _points => (widget.km * RewardEngine.pointsPerKm).round();

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    // Regle metier : titre par defaut "Sport du jour"
    final title = _title.text.trim().isEmpty ? 'Sport du jour' : _title.text.trim();

    // 1. CREATE : on ajoute l'activite dans SQLite
    await ActivityDao.insert(Activity(
      userId: Session.userId!,
      type: widget.type,
      title: title,
      notes: _notes.text.trim(),
      date: Fmt.dbDate(DateTime.now()),
      distanceKm: widget.km,
      durationMin: widget.minutes,
    ));

    // 2. Points (10/km) + verification des badges (module 5)
    final badges = await RewardEngine.onActivityCreated(Session.userId!, widget.km);

    if (!mounted) return;
    AppSnack.show(
        context,
        badges.isEmpty
            ? 'Sortie enregistrée +$_points pts'
            : 'Badge débloqué : ${badges.join(', ')} 🎉');

    // 3. Retour a l'onglet "Activites" (index 1)
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (r) => false,
        arguments: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Expanded(child: StatTile(value: widget.km.toStringAsFixed(2), label: 'km')),
            Expanded(child: StatTile(value: '${widget.minutes}', label: 'min')),
            Expanded(child: StatTile(value: '+$_points', label: 'points')),
          ]),
          const SizedBox(height: 12),
          AppTextField(label: 'Titre', controller: _title, hint: 'Sport du jour'),
          AppTextField(label: 'Notes', controller: _notes, maxLines: 3),
          AppButton(label: 'Enregistrer la sortie', loading: _saving, onPressed: _save),
          const SizedBox(height: 10),
          AppButton(
              label: 'Ignorer',
              outlined: true,
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst)),
        ],
      ),
    );
  }
}
