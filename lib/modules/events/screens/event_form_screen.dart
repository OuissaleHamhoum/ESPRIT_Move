import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/event_dao.dart';
import '../models/campus_event.dart';

/// EV-04 : creer OU modifier un evenement.
///   EventFormScreen()              -> creation (CREATE)
///   EventFormScreen(event: unEvt)  -> modification (UPDATE), champs pre-remplis
class EventFormScreen extends StatefulWidget {
  final CampusEvent? event;
  const EventFormScreen({super.key, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _capacity = TextEditingController(text: '20');
  final _description = TextEditingController();
  String _sport = EventSports.all.first;
  int? _placeId;
  List<CampusPlace> _places = [];

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _title.text = e.title;
      _date.text = e.date;
      _time.text = e.time;
      _capacity.text = '${e.capacity}';
      _description.text = e.description;
      _sport = e.sport;
      _placeId = e.placeId;
    }
    EventDao.places().then((p) {
      if (!mounted) return;
      setState(() {
        _places = p;
        _placeId ??= p.isEmpty ? null : p.first.id;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _date, _time, _capacity, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) _date.text = Fmt.dbDate(d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 17, minute: 30));
    if (t != null) _time.text = '${Fmt.two(t.hour)}:${Fmt.two(t.minute)}';
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final capacity = int.parse(_capacity.text.trim());

    if (_isEdit) {
      await EventDao.update(widget.event!.id,
          title: _title.text.trim(), sport: _sport, placeId: _placeId!,
          date: _date.text, time: _time.text, capacity: capacity,
          description: _description.text.trim());
    } else {
      await EventDao.insert(
          title: _title.text.trim(), sport: _sport, placeId: _placeId!,
          date: _date.text, time: _time.text, capacity: capacity,
          description: _description.text.trim(), organizerId: Session.userId!);
    }
    if (!mounted) return;
    AppSnack.show(context, _isEdit ? 'Événement modifié' : 'Événement publié');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier l’événement' : 'Créer un événement')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
                label: 'Titre',
                controller: _title,
                validator: (v) => AppTextField.notEmpty(v, 'Le titre est obligatoire')),
            Text('Sport', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _sport,
              items: EventSports.all
                  .map((s) => DropdownMenuItem(value: s, child: Text('${EventSports.iconOf(s)} $s')))
                  .toList(),
              onChanged: (v) => setState(() => _sport = v!),
            ),
            const SizedBox(height: 14),
            Text('Lieu', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _placeId,
              items: _places.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
              onChanged: (v) => setState(() => _placeId = v),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: AppTextField(
                    label: 'Date',
                    controller: _date,
                    readOnly: true,
                    onTap: _pickDate,
                    validator: (v) => AppTextField.notEmpty(v, 'Choisissez une date')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                    label: 'Heure',
                    controller: _time,
                    readOnly: true,
                    onTap: _pickTime,
                    validator: (v) => AppTextField.notEmpty(v, 'Choisissez une heure')),
              ),
            ]),
            AppTextField(
              label: 'Places',
              controller: _capacity,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1) ? 'Nombre de places invalide' : null;
              },
            ),
            AppTextField(label: 'Description', controller: _description, maxLines: 3),
            AppButton(label: 'Publier', onPressed: _publish),
          ],
        ),
      ),
    );
  }
}
