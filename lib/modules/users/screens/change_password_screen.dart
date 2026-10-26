import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/user_dao.dart';

/// PRO-05 : changer son mot de passe (etudiant ou administrateur).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_old, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await UserDao.changePassword(Session.userId!, _old.text, _new.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      AppSnack.show(context, 'Mot de passe actuel incorrect', error: true);
      return;
    }
    AppSnack.show(context, 'Mot de passe modifié');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              label: 'Mot de passe actuel',
              controller: _old,
              obscure: true,
              validator: (v) => AppTextField.notEmpty(v, 'Obligatoire'),
            ),
            AppTextField(
              label: 'Nouveau mot de passe (6 caractères min.)',
              controller: _new,
              obscure: true,
              validator: (v) {
                if (v == null || v.length < 6) return 'Au moins 6 caractères';
                if (v == _old.text) return 'Choisissez un mot de passe différent';
                return null;
              },
            ),
            AppTextField(
              label: 'Confirmer le nouveau mot de passe',
              controller: _confirm,
              obscure: true,
              validator: (v) => v != _new.text ? 'Les mots de passe diffèrent' : null,
            ),
            AppButton(label: 'Enregistrer', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
