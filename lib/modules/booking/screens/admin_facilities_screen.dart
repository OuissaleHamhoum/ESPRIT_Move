import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/booking_dao.dart';
import '../models/facility.dart';
import '../widgets/reason_dialog.dart';
import 'admin_bookings_screen.dart';
import 'facility_form_screen.dart';

/// ADMIN (onglet "Terrains") : liste de tous les terrains + ajout,
/// modification, fermeture / reouverture, suppression, planning.
class AdminFacilitiesScreen extends StatefulWidget {
  const AdminFacilitiesScreen({super.key});

  @override
  State<AdminFacilitiesScreen> createState() => _AdminFacilitiesScreenState();
}

class _AdminFacilitiesScreenState extends State<AdminFacilitiesScreen> {
  List<Facility> _facilities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await BookingDao.allFacilities();
    if (!mounted) return;
    setState(() {
      _facilities = f;
      _loading = false;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  /// Fermer : les reservations a venir sont annulees (etudiants prevenus).
  Future<void> _toggleActive(Facility f) async {
    if (f.active) {
      final reason = await ReasonDialog.show(context,
          title: 'Fermer « ${f.name} » ?',
          message: f.upcomingBookings == 0
              ? 'Le terrain ne sera plus réservable.'
              : 'Le terrain ne sera plus réservable et ses ${f.upcomingBookings} '
                  'réservation(s) à venir seront annulées.',
          confirmLabel: 'Fermer',
          hint: 'Motif (ex. travaux)');
      if (reason == null) return;
      final n = await BookingDao.setActive(f, false, reason: reason);
      if (!mounted) return;
      AppSnack.show(context,
          n == 0 ? 'Terrain fermé' : 'Terrain fermé · $n réservation(s) annulée(s)');
    } else {
      await BookingDao.setActive(f, true);
      if (!mounted) return;
      AppSnack.show(context, 'Terrain rouvert');
    }
    _load();
  }

  Future<void> _delete(Facility f) async {
    final ok = await ConfirmSheet.show(context,
        title: 'Supprimer « ${f.name} » ?', message: 'Action définitive.');
    if (!ok) return;
    final done = await BookingDao.deleteFacility(f.id);
    if (!mounted) return;
    AppSnack.show(
        context,
        done
            ? 'Terrain supprimé'
            : 'Ce terrain a des réservations : fermez-le plutôt (l’historique est conservé)',
        error: !done);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terrains'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _push(const FacilityFormScreen()),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Terrain'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _facilities.isEmpty
              ? EmptyState(
                  emoji: '🏟️',
                  message: 'Aucun terrain. Ajoutez le premier (padel, football...).',
                  buttonLabel: 'Ajouter un terrain',
                  onPressed: () => _push(const FacilityFormScreen()),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [for (final f in _facilities) _card(f)],
                  ),
                ),
    );
  }

  Widget _card(Facility f) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _push(AdminBookingsScreen(facility: f)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(children: [
              Opacity(
                  opacity: f.active ? 1 : 0.4,
                  child: Text(f.icon, style: const TextStyle(fontSize: 30))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(f.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    _tag(f.active ? 'Ouvert' : 'Fermé',
                        f.active ? AppColors.green : AppColors.grey),
                  ]),
                  Text('${f.sport} · ${f.placeName}',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(f.scheduleLabel, style: Theme.of(context).textTheme.bodySmall),
                  Text('${f.upcomingBookings} réservation(s) à venir',
                      style: const TextStyle(fontSize: 12, color: AppColors.red)),
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (a) {
                  switch (a) {
                    case 'edit':
                      _push(FacilityFormScreen(facility: f));
                      break;
                    case 'bookings':
                      _push(AdminBookingsScreen(facility: f));
                      break;
                    case 'toggle':
                      _toggleActive(f);
                      break;
                    case 'delete':
                      _delete(f);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  const PopupMenuItem(value: 'bookings', child: Text('Voir les réservations')),
                  PopupMenuItem(
                      value: 'toggle', child: Text(f.active ? 'Fermer le terrain' : 'Rouvrir')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer', style: TextStyle(color: AppColors.red))),
                ],
              ),
            ]),
          ),
        ),
      );

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11)),
      );
}
