import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/booking_dao.dart';
import '../models/facility.dart';
import '../widgets/reason_dialog.dart';

/// ADMIN (onglet "Reservations") : toutes les reservations, filtrees par
/// periode et par terrain. L'admin peut annuler (avec motif) : l'etudiant
/// recoit une notification.
///   AdminBookingsScreen()               -> onglet (tous les terrains)
///   AdminBookingsScreen(facility: f)    -> planning d'un terrain
class AdminBookingsScreen extends StatefulWidget {
  final Facility? facility;
  const AdminBookingsScreen({super.key, this.facility});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  static const _labels = {
    AdminBookingFilter.upcoming: 'À venir',
    AdminBookingFilter.today: 'Aujourd’hui',
    AdminBookingFilter.past: 'Passées',
    AdminBookingFilter.cancelled: 'Annulées',
  };

  AdminBookingFilter _filter = AdminBookingFilter.upcoming;
  int? _facilityId;
  List<Facility> _facilities = [];
  List<Booking> _bookings = [];
  bool _loading = true;

  bool get _isTab => widget.facility == null;

  @override
  void initState() {
    super.initState();
    _facilityId = widget.facility?.id;
    if (_isTab) {
      BookingDao.allFacilities().then((f) {
        if (mounted) setState(() => _facilities = f);
      });
    }
    _load();
  }

  Future<void> _load() async {
    final b = await BookingDao.adminBookings(_filter, facilityId: _facilityId);
    if (!mounted) return;
    setState(() {
      _bookings = b;
      _loading = false;
    });
  }

  Future<void> _cancel(Booking b) async {
    final reason = await ReasonDialog.show(context,
        title: 'Annuler cette réservation ?',
        message: '${b.userName} · ${b.facilityName}\n'
            '${Fmt.shortDate(b.date)} · ${b.timeRange}',
        confirmLabel: 'Annuler la réservation');
    if (reason == null) return;
    await BookingDao.cancelByAdmin(b, reason);
    if (!mounted) return;
    AppSnack.show(context, 'Réservation annulée · ${b.userName} a été prévenu(e)');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTab ? 'Réservations' : '${widget.facility!.icon} ${widget.facility!.name}'),
        automaticallyImplyLeading: !_isTab,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<AdminBookingFilter>(
            showSelectedIcon: false,
            segments: [
              for (final e in _labels.entries)
                ButtonSegment(
                    value: e.key,
                    label: FittedBox(child: Text(e.value))),
            ],
            selected: {_filter},
            onSelectionChanged: (s) {
              setState(() => _filter = s.first);
              _load();
            },
          ),
        ),
        if (_isTab && _facilities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<int?>(
              initialValue: _facilityId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous les terrains')),
                for (final f in _facilities)
                  DropdownMenuItem(value: f.id, child: Text('${f.icon}  ${f.name}')),
              ],
              onChanged: (v) {
                setState(() => _facilityId = v);
                _load();
              },
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _bookings.isEmpty
                  ? const EmptyState(emoji: '📅', message: 'Aucune réservation.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [for (final b in _bookings) _tile(b)],
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _tile(Booking b) {
    final canCancel = !b.isCancelled && !b.hasStarted;
    return Card(
      child: ListTile(
        leading: Text(b.icon, style: const TextStyle(fontSize: 26)),
        title: Text('${Fmt.shortDate(b.date)} · ${b.timeRange}'),
        subtitle: Text([
          if (_facilityId == null) b.facilityName,
          '${b.userName} · ${b.userEmail}',
          if (b.isCancelled) b.adminStatusLabel,
        ].join('\n')),
        isThreeLine: _facilityId == null || b.isCancelled,
        trailing: canCancel
            ? IconButton(
                tooltip: 'Annuler',
                icon: const Icon(Icons.cancel_outlined, color: AppColors.red),
                onPressed: () => _cancel(b),
              )
            : null,
      ),
    );
  }
}
