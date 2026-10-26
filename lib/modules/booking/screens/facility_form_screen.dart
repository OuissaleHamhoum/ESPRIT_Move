import 'package:flutter/material.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../data/booking_dao.dart';
import '../models/facility.dart';

/// ADMIN : creer ou modifier un terrain (padel, football, basket...).
///   FacilityFormScreen()             -> nouveau terrain
///   FacilityFormScreen(facility: f)  -> modification
class FacilityFormScreen extends StatefulWidget {
  final Facility? facility;
  const FacilityFormScreen({super.key, this.facility});

  @override
  State<FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<FacilityFormScreen> {
  static const _durations = [60, 90, 120];
  static final _hours = List.generate(24, (h) => h); // 0..23 (+ 24 a la fermeture)

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _description = TextEditingController();
  String _sport = FacilitySports.all.first;
  int _open = 8;
  int _close = 22;
  int _slotMinutes = 60;
  List<String> _knownPlaces = [];
  TextEditingController? _placeField; // champ interne de l'Autocomplete
  bool _saving = false;

  bool get _isEdit => widget.facility != null;

  @override
  void initState() {
    super.initState();
    final f = widget.facility;
    if (f != null) {
      _name.text = f.name;
      _place.text = f.placeName;
      _description.text = f.description;
      _sport = f.sport;
      _open = f.openHour;
      _close = f.closeHour;
      _slotMinutes = f.slotMinutes;
    }
    BookingDao.placeNames().then((p) {
      if (mounted) setState(() => _knownPlaces = p);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _place, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _slotCount => Slots.generate(_open, _close, _slotMinutes).length;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_slotCount == 0) {
      AppSnack.show(context, 'Les horaires ne permettent aucun créneau', error: true);
      return;
    }

    // Modification des horaires : prevenir si des reservations sont touchees
    if (_isEdit) {
      final n = await BookingDao.countOutsideSchedule(widget.facility!.id, _open, _close);
      if (!mounted) return;
      if (n > 0) {
        final ok = await ConfirmSheet.show(context,
            title: 'Modifier les horaires ?',
            message: '$n réservation(s) à venir sont hors des nouveaux horaires. '
                'Elles seront annulées et les étudiants prévenus.',
            confirmLabel: 'Enregistrer quand même');
        if (!ok) return;
      }
    }

    setState(() => _saving = true);
    await BookingDao.saveFacility(
      id: widget.facility?.id,
      name: _name.text.trim(),
      sport: _sport,
      placeName: _place.text.trim(),
      description: _description.text.trim(),
      openHour: _open,
      closeHour: _close,
      slotMinutes: _slotMinutes,
    );
    if (!mounted) return;
    AppSnack.show(context, _isEdit ? 'Terrain modifié' : 'Terrain ajouté');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier le terrain' : 'Nouveau terrain')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label('Sport'),
            DropdownButtonFormField<String>(
              initialValue: _sport,
              items: [
                for (final s in FacilitySports.all)
                  DropdownMenuItem(value: s, child: Text('${FacilitySports.iconOf(s)}  $s')),
              ],
              onChanged: (v) => setState(() => _sport = v!),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Nom du terrain',
              controller: _name,
              hint: 'Padel 1, Terrain synthétique...',
              validator: (v) => AppTextField.notEmpty(v, 'Le nom est obligatoire'),
            ),
            _label('Emplacement sur le campus'),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _place.text),
              optionsBuilder: (v) => _knownPlaces.where(
                  (p) => p.toLowerCase().contains(v.text.trim().toLowerCase())),
              onSelected: (p) => _place.text = p,
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                // On garde _place synchronise avec le champ affiche (1 seule fois)
                if (_placeField != controller) {
                  _placeField = controller;
                  controller.addListener(() => _place.text = controller.text);
                }
                return TextFormField(
                  controller: controller,
                  focusNode: focus,
                  decoration: const InputDecoration(hintText: 'Bloc G, Stade ESPRIT...'),
                  validator: (v) => AppTextField.notEmpty(v, 'L’emplacement est obligatoire'),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _hourField('Ouverture', _open, (v) => setState(() => _open = v))),
              const SizedBox(width: 12),
              Expanded(
                child: _hourField('Fermeture', _close, (v) => setState(() => _close = v),
                    validator: (v) => (v ?? 0) <= _open ? 'Après l’ouverture' : null,
                    withMidnight: true),
              ),
            ]),
            const SizedBox(height: 14),
            _label('Durée d’un créneau'),
            DropdownButtonFormField<int>(
              initialValue: _slotMinutes,
              items: [
                for (final d in _durations)
                  DropdownMenuItem(value: d, child: Text(Facility.slotLabel(d))),
              ],
              onChanged: (v) => setState(() => _slotMinutes = v!),
            ),
            const SizedBox(height: 6),
            Text('$_slotCount créneau(x) par jour',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            AppTextField(
                label: 'Description (facultatif)',
                controller: _description,
                maxLines: 3,
                hint: 'Éclairage, vestiaires, matériel fourni...'),
            AppButton(
              label: _isEdit ? 'Enregistrer' : 'Ajouter le terrain',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );

  Widget _hourField(String label, int value, ValueChanged<int> onChanged,
      {FormFieldValidator<int>? validator, bool withMidnight = false}) {
    final hours = [..._hours, if (withMidnight) 24];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      DropdownButtonFormField<int>(
        initialValue: value,
        validator: validator,
        items: [
          for (final h in hours)
            DropdownMenuItem(value: h, child: Text('${Fmt.two(h % 24)}:00')),
        ],
        onChanged: (v) => onChanged(v!),
      ),
    ]);
  }
}
