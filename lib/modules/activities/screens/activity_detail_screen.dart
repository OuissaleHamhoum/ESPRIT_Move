import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../data/activity_dao.dart';
import '../models/activity.dart';
import 'activity_edit_screen.dart';

/// ACT-02 : detail d'une activite. Boutons Modifier (ACT-03) et Supprimer (ACT-04).
class ActivityDetailScreen extends StatefulWidget {
  final int activityId;
  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  Activity? _activity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ActivityDao.getById(widget.activityId);
    if (!mounted) return;
    setState(() => _activity = a);
  }

  Future<void> _edit() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ActivityEditScreen(activity: _activity!)));
    _load(); // affiche les nouvelles valeurs
  }

  /// DELETE avec confirmation (ACT-04).
  Future<void> _delete() async {
    final ok = await ConfirmSheet.show(context,
        title: 'Supprimer cette activité ?',
        message: 'Cette action est définitive.');
    if (!ok) return;
    await ActivityDao.delete(_activity!.id!);
    if (!mounted) return;
    AppSnack.show(context, 'Activité supprimée');
    Navigator.pop(context); // retour a la liste (ACT-01)
  }

  @override
  Widget build(BuildContext context) {
    final a = _activity;
    return Scaffold(
      appBar: AppBar(title: const Text('Détail')),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Bandeau rouge : sport, titre, date
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                        colors: [AppColors.red, AppColors.darkBg]),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ActivityTypes.iconOf(a.type),
                          style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(a.title,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('${Fmt.shortDate(a.date)} · ${a.type}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _stat(a.distanceKm.toStringAsFixed(2), 'km'),
                  _stat('${a.durationMin}', 'minutes'),
                  _stat(Fmt.pace(a.distanceKm, a.durationMin), 'min/km'),
                ]),
                // Trace du parcours : voir GUIDE.md pour le brancher au GPS
                Card(
                  child: SizedBox(
                    height: 110,
                    child: Center(
                        child: Text('🗺️  Tracé du parcours (GPS à venir)',
                            style: Theme.of(context).textTheme.bodySmall)),
                  ),
                ),
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
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: AppButton(label: 'Modifier', onPressed: _edit)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: AppButton(
                          label: 'Supprimer', outlined: true, onPressed: _delete)),
                ]),
              ],
            ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}
