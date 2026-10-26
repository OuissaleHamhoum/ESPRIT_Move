import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../data/booking_dao.dart';
import '../models/facility.dart';

/// BK-02 (reserver) et BK-04 (changer) : choix du jour (7 jours) + creneau.
///   SlotPickerScreen(facility: f)                -> nouvelle reservation
///   SlotPickerScreen(facility: f, booking: b)    -> deplacer une reservation
/// Les creneaux viennent des horaires du terrain (definis par l'admin).
/// Un creneau pris ou deja commence est barre et non cliquable.
class SlotPickerScreen extends StatefulWidget {
  final Facility facility;
  final Booking? booking;
  const SlotPickerScreen({super.key, required this.facility, this.booking});

  @override
  State<SlotPickerScreen> createState() => _SlotPickerScreenState();
}

class _SlotPickerScreenState extends State<SlotPickerScreen> {
  late final List<DateTime> _days;
  int _dayIndex = 0;
  String? _slot;
  Set<String> _taken = {};
  bool _saving = false;

  bool get _isChange => widget.booking != null;
  Facility get _f => widget.facility;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _days = List.generate(7, (i) => DateTime(today.year, today.month, today.day + i));

    // En mode "changer" : on part de la reservation actuelle
    final b = widget.booking;
    if (b != null) {
      final idx = _days.indexWhere((d) => Fmt.dbDate(d) == b.date);
      if (idx >= 0) _dayIndex = idx;
      if (_f.slots.contains(b.slot)) _slot = b.slot;
    }
    _loadTaken();
  }

  String get _date => Fmt.dbDate(_days[_dayIndex]);

  Future<void> _loadTaken() async {
    final t = await BookingDao.takenSlots(_f, _date, excludeBookingId: widget.booking?.id);
    if (!mounted) return;
    setState(() {
      _taken = t;
      if (_slot != null && (t.contains(_slot) || _isPast(_slot!))) _slot = null;
    });
  }

  /// Un creneau deja commence n'est plus reservable.
  bool _isPast(String slot) => !Slots.at(_date, slot).isAfter(DateTime.now());

  Future<void> _confirm() async {
    if (_slot == null || _taken.contains(_slot) || _isPast(_slot!)) {
      setState(() => _slot = null);
      AppSnack.show(context, 'Choisissez un créneau disponible', error: true);
      return;
    }
    setState(() => _saving = true);
    final result = _isChange
        ? await BookingDao.move(widget.booking!, _f, _date, _slot!)
        : await BookingDao.book(_f, Session.userId!, _date, _slot!);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result == BookingResult.ok) {
      AppSnack.show(context, _isChange ? 'Réservation modifiée ✅' : 'Réservation confirmée ✅');
      Navigator.pop(context); // retour a BK-01
      return;
    }
    AppSnack.show(context, _message(result), error: true);
    _loadTaken();
  }

  String _message(BookingResult r) {
    switch (r) {
      case BookingResult.slotTaken:
        return 'Ce créneau vient d’être pris';
      case BookingResult.userConflict:
        return 'Vous avez déjà une réservation sur ce créneau horaire';
      case BookingResult.tooMany:
        return 'Maximum ${BookingDao.maxUpcomingPerUser} réservations à venir';
      case BookingResult.closed:
        return 'Ce terrain est fermé par l’administration';
      case BookingResult.past:
        return 'Ce créneau a déjà commencé';
      case BookingResult.ok:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _f.slots;
    return Scaffold(
      appBar: AppBar(title: Text('${_f.icon} ${_f.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${_f.placeName} · ${_f.scheduleLabel}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text('Jour', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(Fmt.shortDate(Fmt.dbDate(_days[i]))),
                selected: i == _dayIndex,
                selectedColor: AppColors.red,
                showCheckmark: false,
                labelStyle: TextStyle(color: i == _dayIndex ? Colors.white : null),
                onSelected: (_) {
                  setState(() => _dayIndex = i);
                  _loadTaken();
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Créneau (${Facility.slotLabel(_f.slotMinutes)})',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (slots.every((s) => _taken.contains(s) || _isPast(s)))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Plus aucun créneau libre ce jour-là.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final s in slots) _slotButton(s)],
          ),
          const SizedBox(height: 28),
          AppButton(
            label: _isChange ? 'Confirmer le changement' : 'Confirmer la réservation',
            loading: _saving,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }

  Widget _slotButton(String s) {
    final disabled = _taken.contains(s) || _isPast(s);
    final selected = _slot == s;
    final end = Slots.format(Slots.at(_date, s).add(Duration(minutes: _f.slotMinutes)));
    return InkWell(
      onTap: disabled ? null : () => setState(() => _slot = s),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 120,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.red : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$s - $end',
          style: TextStyle(
            color: selected ? Colors.white : (disabled ? AppColors.grey : null),
            decoration: disabled ? TextDecoration.lineThrough : null, // pris = barre
          ),
        ),
      ),
    );
  }
}
