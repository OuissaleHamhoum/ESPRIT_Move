import 'package:flutter/material.dart';
import '../../../core/services/reward_engine.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/event_dao.dart';
import '../models/campus_event.dart';
import 'event_form_screen.dart';

/// EV-03 : detail d'un evenement + Rejoindre / Quitter / Modifier /
/// Annuler / Supprimer (EV-05 = confirmation de suppression).
class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  CampusEvent? _event;
  List<String> _names = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await EventDao.getById(widget.eventId, Session.userId);
    final names = await EventDao.participantNames(widget.eventId);
    if (!mounted) return;
    setState(() {
      _event = e;
      _names = names;
    });
  }

  /// Seul l'organisateur ou un admin peut modifier / annuler / supprimer.
  bool get _canManage =>
      _event != null &&
      !Session.isGuest &&
      (Session.userId == _event!.organizerId || Session.isAdmin);

  Future<void> _join() async {
    if (!await GuestGate.check(context, message: 'Créez un compte pour rejoindre.')) return;
    final uid = Session.userId!;
    final result = await EventDao.join(widget.eventId, uid);
    if (!mounted) return;
    switch (result) {
      case JoinResult.ok:
        final badges = await RewardEngine.onEventJoined(uid); // +50 pts
        if (!mounted) return;
        AppSnack.show(
            context,
            badges.isEmpty
                ? 'Inscription confirmée +50 pts'
                : 'Badge débloqué : ${badges.join(', ')} 🎉');
        break;
      case JoinResult.full:
        AppSnack.show(context, 'Événement complet', error: true);
        break;
      case JoinResult.cancelled:
        AppSnack.show(context, 'Événement annulé', error: true);
        break;
      case JoinResult.past:
        AppSnack.show(context, 'Événement terminé', error: true);
        break;
      case JoinResult.alreadyJoined:
        break;
    }
    _load();
  }

  Future<void> _leave() async {
    await EventDao.leave(widget.eventId, Session.userId!);
    await RewardEngine.onEventLeft(Session.userId!); // -50 pts
    if (!mounted) return;
    AppSnack.show(context, 'Vous avez quitté l’événement');
    _load();
  }

  Future<void> _edit() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EventFormScreen(event: _event)));
    _load();
  }

  Future<void> _toggleCancel() async {
    await EventDao.setCancelled(widget.eventId, !_event!.isCancelled);
    _load();
  }

  /// EV-05 : suppression definitive avec confirmation.
  Future<void> _delete() async {
    final ok = await ConfirmSheet.show(context,
        title: 'Supprimer cet événement ?',
        message: 'Les inscriptions seront supprimées. Action définitive.');
    if (!ok) return;
    await EventDao.delete(widget.eventId);
    if (!mounted) return;
    Navigator.pop(context); // retour a la liste
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    return Scaffold(
      appBar: AppBar(title: const Text('Événement')),
      body: e == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [AppColors.red, AppColors.darkBg]),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(EventSports.iconOf(e.sport), style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(e.title,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('${Fmt.shortDate(e.date)} · ${e.time}',
                          style: const TextStyle(color: Colors.white70)),
                      Text('📍 ${e.placeName}', style: const TextStyle(color: Colors.white70)),
                      if (e.isCancelled)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('ANNULÉ',
                              style: TextStyle(
                                  color: AppColors.gold, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.description.isEmpty ? 'Pas de description.' : e.description),
                        const SizedBox(height: 14),
                        // Barre de remplissage
                        LinearProgressIndicator(
                          value: e.capacity == 0 ? 0 : e.participants / e.capacity,
                          color: AppColors.red,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Text('${e.participants}/${e.capacity} inscrits',
                            style: Theme.of(context).textTheme.bodySmall),
                        if (_names.isNotEmpty)
                          Text('Participants : ${_names.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Bouton principal : Rejoindre / Quitter / Complet / Annule
                if (e.isCancelled)
                  const AppButton(label: 'Événement annulé', onPressed: null)
                else if (e.isPast)
                  AppButton(
                      label: e.joined ? 'Événement terminé · vous y étiez' : 'Événement terminé',
                      onPressed: null)
                else if (e.joined)
                  AppButton(label: 'Quitter l’événement', outlined: true, onPressed: _leave)
                else if (e.isFull)
                  const AppButton(label: 'Complet', onPressed: null)
                else
                  AppButton(label: 'Rejoindre', onPressed: _join),
                if (_canManage) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: AppButton(label: 'Modifier', outlined: true, onPressed: _edit)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: AppButton(
                            label: e.isCancelled ? 'Réactiver' : 'Annuler',
                            outlined: true,
                            onPressed: _toggleCancel)),
                    IconButton(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline, color: AppColors.red)),
                  ]),
                ],
              ],
            ),
    );
  }
}
