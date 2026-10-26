import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/booking_dao.dart';
import '../models/facility.dart';
import 'slot_picker_screen.dart';

/// BK-01 (etudiant) : terrains ouverts + "Mes reservations" (changer /
/// annuler) + historique (passees et annulees).
class FacilitiesScreen extends StatefulWidget {
  const FacilitiesScreen({super.key});

  @override
  State<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends State<FacilitiesScreen> {
  static const _all = 'Tous';

  List<Facility> _facilities = [];
  List<Booking> _upcoming = [];
  List<Booking> _history = [];
  String _sport = _all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await BookingDao.activeFacilities();
    final uid = Session.userId;
    final up = uid == null ? <Booking>[] : await BookingDao.myUpcoming(uid);
    final hist = uid == null ? <Booking>[] : await BookingDao.myHistory(uid);
    if (!mounted) return;
    setState(() {
      _facilities = f;
      _upcoming = up;
      _history = hist;
      if (_sport != _all && !f.any((x) => x.sport == _sport)) _sport = _all;
      _loading = false;
    });
  }

  /// Reserver : visiteur -> compte, carte non validee -> message explicite.
  Future<void> _reserve(Facility f) async {
    if (!await GuestGate.check(context, message: 'Créez un compte pour réserver.')) return;
    final status = await BookingDao.cardStatus(Session.userId!);
    if (!mounted) return;
    if (status != 1) {
      AppSnack.show(
          context,
          status == -1
              ? 'Carte étudiante refusée : corrigez le numéro dans Profil > Modifier'
              : 'Votre carte étudiante est en attente de validation par l’administration',
          error: true);
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => SlotPickerScreen(facility: f)));
    _load();
  }

  Future<void> _change(Booking b) async {
    final f = await BookingDao.facility(b.facilityId);
    if (!mounted) return;
    if (f == null || !f.active) {
      AppSnack.show(context, 'Ce terrain est fermé : la réservation ne peut pas être déplacée',
          error: true);
      return;
    }
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => SlotPickerScreen(facility: f, booking: b)));
    _load();
  }

  /// BK-05 : annuler une reservation (confirmation obligatoire).
  Future<void> _cancel(Booking b) async {
    final ok = await ConfirmSheet.show(context,
        title: 'Annuler ce créneau ?',
        message: '${b.facilityName} · ${Fmt.shortDate(b.date)} · ${b.timeRange}',
        confirmLabel: 'Oui, annuler',
        cancelLabel: 'Non');
    if (!ok) return;
    final done = await BookingDao.cancelByUser(b);
    if (!mounted) return;
    AppSnack.show(context,
        done ? 'Réservation annulée' : 'Ce créneau a déjà commencé : annulation impossible',
        error: !done);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final sports = {for (final f in _facilities) f.sport}.toList()..sort();
    final shown = _sport == _all
        ? _facilities
        : _facilities.where((f) => f.sport == _sport).toList();

    return Scaffold(
      appBar: const AppTopBar(title: 'Réserver un terrain'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!Session.isGuest) ..._myBookings(),
                  Text('Terrains', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_facilities.isEmpty)
                    const SizedBox(
                      height: 220,
                      child: EmptyState(
                          emoji: '🏟️',
                          message: 'Aucun terrain disponible pour le moment.'),
                    )
                  else ...[
                    if (sports.length > 1)
                      ChipSelector(
                        options: [_all, ...sports],
                        selected: {_sport},
                        onTap: (s) => setState(() => _sport = s),
                      ),
                    const SizedBox(height: 8),
                    for (final f in shown) _facilityCard(f),
                  ],
                  if (_history.isNotEmpty) _historySection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _facilityCard(Facility f) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Text(f.icon, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${f.sport} · ${f.placeName}',
                    style: Theme.of(context).textTheme.bodySmall),
                Text(f.scheduleLabel, style: Theme.of(context).textTheme.bodySmall),
                if (f.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(f.description, style: const TextStyle(fontSize: 13)),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () => _reserve(f), child: const Text('Réserver')),
          ]),
        ),
      );

  List<Widget> _myBookings() => [
        Text('Mes réservations à venir (${_upcoming.length}/${BookingDao.maxUpcomingPerUser})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (_upcoming.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('Aucune réservation à venir.',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final b in _upcoming)
          Card(
            child: ListTile(
              leading: Text(b.icon, style: const TextStyle(fontSize: 26)),
              title: Text(b.facilityName),
              subtitle: Text('${Fmt.shortDate(b.date)} · ${b.timeRange}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(onPressed: () => _change(b), child: const Text('Changer')),
                IconButton(
                    tooltip: 'Annuler',
                    icon: const Icon(Icons.close),
                    onPressed: () => _cancel(b)),
              ]),
            ),
          ),
        const SizedBox(height: 16),
      ];

  Widget _historySection() => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Card(
          child: ExpansionTile(
            shape: const Border(),
            title: Text('Historique (${_history.length})'),
            children: [
              for (final b in _history)
                ListTile(
                  dense: true,
                  leading: Text(b.icon, style: const TextStyle(fontSize: 22)),
                  title: Text('${b.facilityName} · ${Fmt.shortDate(b.date)} · ${b.timeRange}'),
                  subtitle: Text(b.statusLabel,
                      style: TextStyle(
                          color: b.isCancelled ? AppColors.red : AppColors.grey)),
                ),
            ],
          ),
        ),
      );
}
