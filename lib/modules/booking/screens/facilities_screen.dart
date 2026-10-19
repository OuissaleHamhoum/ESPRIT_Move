import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/booking_dao.dart';
import '../models/facility.dart';
import 'slot_picker_screen.dart';

/// BK-01 : installations a reserver + "Mes reservations" (Changer / annuler).
class FacilitiesScreen extends StatefulWidget {
  const FacilitiesScreen({super.key});

  @override
  State<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends State<FacilitiesScreen> {
  List<Facility> _facilities = [];
  List<Booking> _bookings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await BookingDao.facilities();
    final uid = Session.userId;
    final b = uid == null ? <Booking>[] : await BookingDao.myBookings(uid);
    if (!mounted) return;
    setState(() {
      _facilities = f;
      _bookings = b;
    });
  }

  /// Reserver : visiteur -> BK-06, carte non verifiee -> message.
  Future<void> _reserve(Facility f) async {
    if (!await GuestGate.check(context, message: 'Créez un compte pour réserver.')) return;
    if (!await BookingDao.hasVerifiedCard(Session.userId!)) {
      if (mounted) {
        AppSnack.show(context, 'Une carte étudiante vérifiée est nécessaire', error: true);
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => SlotPickerScreen(facility: f)));
    _load();
  }

  Future<void> _change(Booking b) async {
    final f = _facilities.firstWhere((x) => x.id == b.facilityId);
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => SlotPickerScreen(facility: f, booking: b)));
    _load();
  }

  /// BK-05 : annuler une reservation (confirmation obligatoire).
  Future<void> _cancel(Booking b) async {
    final ok = await ConfirmSheet.show(context,
        title: 'Annuler ce créneau ?',
        message: '${b.facilityName} · ${Fmt.shortDate(b.date)} · ${b.slot}',
        confirmLabel: 'Oui, annuler',
        cancelLabel: 'Non');
    if (!ok) return;
    await BookingDao.delete(b.id);
    if (!mounted) return;
    AppSnack.show(context, 'Réservation annulée');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Installations'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final f in _facilities)
            Card(
              child: ListTile(
                leading: Text(f.icon, style: const TextStyle(fontSize: 28)),
                title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(f.placeName),
                trailing: ElevatedButton(
                    onPressed: () => _reserve(f), child: const Text('Réserver')),
              ),
            ),
          const SizedBox(height: 16),
          Text('Mes réservations', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (_bookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucune réservation.', style: Theme.of(context).textTheme.bodySmall),
            ),
          for (final b in _bookings)
            Card(
              child: ListTile(
                leading: Text(b.icon, style: const TextStyle(fontSize: 26)),
                title: Text(b.facilityName),
                subtitle: Text('${Fmt.shortDate(b.date)} · ${b.slot}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  OutlinedButton(onPressed: () => _change(b), child: const Text('Changer')),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => _cancel(b)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
