import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/event_dao.dart';
import '../models/campus_event.dart';
import '../widgets/event_tile.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

/// EV-01 : onglet "Evenements" (liste). Aussi ouvert par l'admin
/// (route AppRoutes.adminEvents) pour moderer les evenements.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<CampusEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// READ : evenements depuis SQLite.
  Future<void> _load() async {
    final list = await EventDao.getAll(Session.userId);
    if (!mounted) return;
    setState(() {
      _events = list;
      _loading = false;
    });
  }

  Future<void> _openDetail(CampusEvent e) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)));
    _load();
  }

  Future<void> _create() async {
    final ok = await GuestGate.check(context,
        message: 'Créez un compte pour organiser un événement.');
    if (!ok) return;
    if (!mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const EventFormScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Événements'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(
                    child: Text('${_events.length} événement(s)',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ElevatedButton(onPressed: _create, child: const Text('+ Créer')),
                ]),
                const SizedBox(height: 12),
                if (_events.isEmpty)
                  SizedBox(
                    height: 300,
                    child: EmptyState(
                      emoji: '📅',
                      message: 'Aucun événement pour le moment.',
                      buttonLabel: 'Créer un événement',
                      onPressed: _create,
                    ),
                  )
                else ...[
                  for (final e in _events) EventTile(event: e, onTap: () => _openDetail(e)),
                ],
                const SizedBox(height: 60),
              ],
            ),
    );
  }
}
