import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/user_dao.dart';

/// Connexion (ecran ajoute : le PDF decrit l'inscription mais pas le login).
/// Compte de test : mariem@esprit.tn / 123456
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = await UserDao.login(_email.text.trim(), _password.text);
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'E-mail ou mot de passe incorrect';
      });
      return;
    }
    await Session.login(id: user.id!, name: user.name, role: user.role);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            AppTextField(
              label: 'E-mail ESPRIT',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => AppTextField.notEmpty(v, 'E-mail obligatoire'),
            ),
            AppTextField(
              label: 'Mot de passe',
              controller: _password,
              obscure: true,
              validator: (v) => AppTextField.notEmpty(v, 'Mot de passe obligatoire'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.red)),
              ),
            AppButton(label: 'Se connecter', loading: _loading, onPressed: _signIn),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.signUp),
              child: const Text('Pas de compte ? Créer un compte'),
            ),
            TextButton(
              onPressed: () async {
                await Session.logout(); // visiteur sans compte
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (r) => false);
              },
              child: const Text('Explorer sans compte'),
            ),
          ],
        ),
      ),
    );
  }
}
