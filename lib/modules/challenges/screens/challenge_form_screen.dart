import 'package:flutter/material.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/challenge_dao.dart';
import '../models/challenge_models.dart';

/// CH-03 : creer OU modifier un defi (administrateur).
///   ChallengeFormScreen()                -> creation
///   ChallengeFormScreen(challenge: c)    -> modification
class ChallengeFormScreen extends StatefulWidget {
  final Challenge? challenge;
  const ChallengeFormScreen({super.key, this.challenge});

  @override
  State<ChallengeFormScreen> createState() => _ChallengeFormScreenState();
}

class _ChallengeFormScreenState extends State<ChallengeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _goal = TextEditingController();
  final _days = TextEditingController(text: '7');
  String _measure = 'km';

  bool get _isEdit => widget.challenge != null;

  @override
  void initState() {
    super.initState();
    final c = widget.challenge;
    if (c != null) {
      _title.text = c.title;
      _goal.text = c.goal.round().toString();
      _days.text = '${c.durationDays}';
      _measure = c.measure;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    _days.dispose();
    super.dispose();
  }

  String? _positive(String? v) {
    final n = int.tryParse(v ?? '');
    return (n == null || n < 1) ? 'Nombre invalide' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final goal = double.parse(_goal.text.trim());
    final days = int.parse(_days.text.trim());
    if (_isEdit) {
      await ChallengeDao.update(widget.challenge!.id, _title.text.trim(), _measure, goal, days);
    } else {
      await ChallengeDao.insert(_title.text.trim(), _measure, goal, days);
    }
    if (!mounted) return;
    AppSnack.show(context, 'Défi enregistré');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier le défi' : 'Nouveau défi')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
                label: 'Titre',
                controller: _title,
                validator: (v) => AppTextField.notEmpty(v, 'Le titre est obligatoire')),
            Text('Mesure', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _measure,
              items: Measures.labels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _measure = v!),
            ),
            const SizedBox(height: 14),
            AppTextField(
                label: 'Objectif',
                controller: _goal,
                keyboardType: TextInputType.number,
                validator: _positive),
            AppTextField(
                label: 'Durée (jours)',
                controller: _days,
                keyboardType: TextInputType.number,
                validator: _positive),
            AppButton(label: 'Enregistrer', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
