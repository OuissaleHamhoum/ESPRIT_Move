import 'package:flutter/material.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/badge_dao.dart';
import '../models/challenge_models.dart';

/// BDG-03 : creer un badge (administrateur).
class BadgeFormScreen extends StatefulWidget {
  const BadgeFormScreen({super.key});

  @override
  State<BadgeFormScreen> createState() => _BadgeFormScreenState();
}

class _BadgeFormScreenState extends State<BadgeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _icon = TextEditingController(text: '🏅');
  final _threshold = TextEditingController();
  String _rule = 'distance';

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    await BadgeDao.insert(_name.text.trim(), _icon.text.trim(), _rule,
        double.parse(_threshold.text.trim()));
    if (!mounted) return;
    AppSnack.show(context, 'Badge créé');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau badge')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
                label: 'Nom',
                controller: _name,
                hint: 'Ex. Marathonien',
                validator: (v) => AppTextField.notEmpty(v, 'Le nom est obligatoire')),
            AppTextField(
                label: 'Emoji',
                controller: _icon,
                validator: (v) => AppTextField.notEmpty(v, 'Choisissez un emoji')),
            Text('Condition', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _rule,
              items: BadgeRules.labels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _rule = v!),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Seuil',
              controller: _threshold,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n <= 0) ? 'Seuil invalide' : null;
              },
            ),
            AppButton(label: 'Créer', onPressed: _create),
          ],
        ),
      ),
    );
  }
}
