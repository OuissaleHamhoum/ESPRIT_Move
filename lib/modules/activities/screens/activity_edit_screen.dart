import 'package:flutter/material.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/activity_dao.dart';
import '../models/activity.dart';

/// ACT-03 : modifier le titre, le type et les notes d'une activite (UPDATE).
class ActivityEditScreen extends StatefulWidget {
  final Activity activity;
  const ActivityEditScreen({super.key, required this.activity});

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late String _type;

  @override
  void initState() {
    super.initState();
    // On pre-remplit le formulaire avec les valeurs actuelles
    _title = TextEditingController(text: widget.activity.title);
    _notes = TextEditingController(text: widget.activity.notes);
    _type = widget.activity.type;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.activity.copyWith(
      title: _title.text.trim(),
      type: _type,
      notes: _notes.text.trim(),
    );
    await ActivityDao.update(updated);
    if (!mounted) return;
    AppSnack.show(context, 'Activité modifiée');
    Navigator.pop(context); // retour au detail (ACT-02)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier l’activité')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
                label: 'Titre',
                controller: _title,
                validator: (v) => AppTextField.notEmpty(v, 'Le titre est obligatoire')),
            Text('Type', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: ActivityTypes.all
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text('${ActivityTypes.iconOf(t)} $t')))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 14),
            AppTextField(label: 'Notes', controller: _notes, maxLines: 4),
            AppButton(label: 'Enregistrer', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
