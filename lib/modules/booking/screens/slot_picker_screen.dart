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
///   SlotPickerScreen(facility: f, booking: b)    -> changer une reservation
/// Un creneau deja pris est barre et non cliquable.
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

  bool get _isChange => widget.booking != null;

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
      _slot = b.slot;
    }
    _loadTaken();
  }

  String get _date => Fmt.dbDate(_days[_dayIndex]);

  Future<void> _loadTaken() async {
    final t = await BookingDao.takenSlots(widget.facility.id, _date,
        excludeBookingId: widget.booking?.id);
    if (!mounted) return;
    setState(() {
      _taken = t;
      if (_slot != null && t.contains(_slot)) _slot = null; // plus disponible
    });
  }

  /// Un creneau deja passe aujourd'hui n'est plus reservable.
  bool _isPast(String slot) {
    if (_dayIndex != 0) return false;
    final hour = int.parse(slot.substring(0, 2));
    return hour <= DateTime.now().hour;
  }

  Future<void> _confirm() async {
    if (_slot == null) {
      AppSnack.show(context, 'Choisissez un créneau', error: true);
      return;
    }
    final bool ok = _isChange
        ? await BookingDao.update(widget.booking!, _date, _slot!)
        : await BookingDao.insert(widget.facility.id, Session.userId!, _date, _slot!);
    if (!mounted) return;
    if (!ok) {
      AppSnack.show(context, 'Ce créneau vient d’être pris', error: true);
      _loadTaken();
      return;
    }
    // BK-03 : confirmation
    AppSnack.show(context, _isChange ? 'Réservation modifiée ✅' : 'Réservation confirmée ✅');
    Navigator.pop(context); // retour a BK-01
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.facility.icon} ${widget.facility.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          Text('Créneau (2 h)', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in Slots.all) _slotButton(s),
            ],
          ),
          const SizedBox(height: 28),
          AppButton(
            label: _isChange ? 'Confirmer le changement' : 'Confirmer la réservation',
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }

  Widget _slotButton(String s) {
    final disabled = _taken.contains(s) || _isPast(s);
    final selected = _slot == s;
    return InkWell(
      onTap: disabled ? null : () => setState(() => _slot = s),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 100,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.red : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          s,
          style: TextStyle(
            color: selected ? Colors.white : (disabled ? AppColors.grey : null),
            // creneau pris = barre
            decoration: disabled ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
