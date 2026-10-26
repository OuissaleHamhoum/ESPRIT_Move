import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/reward_engine.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/chip_selector.dart';
import '../data/user_dao.dart';

/// SU-01 a SU-06 : inscription en 5 etapes dans UN seul ecran.
/// Les donnees saisies restent dans cet ecran jusqu'a l'etape finale,
/// puis UserDao.signUp() cree le compte en une seule fois.
///
///   0 = Compte | 1 = Carte etudiante | 2 = Localisation
///   3 = Interets | 4 = Groupes | 5 = Succes (SU-06)
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const _interestOptions = [
    'Running',
    'Football',
    'Basket',
    'Yoga',
    'Muscu',
    'Vélo',
    'Natation',
    'Tennis',
  ];
  static const _campuses = ['Campus Ghazela', 'Campus Charguia'];
  static const _filieres = [
    'Informatique',
    'Génie civil',
    'Télécommunications',
    'Business',
    'Mécanique',
  ];

  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _saving = false;

  // Donnees saisies (une par champ)
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _cardNumber = TextEditingController();
  final _city = TextEditingController(text: 'Tunis');
  String _filiere = _filieres.first;
  String _campus = _campuses.first;
  bool _locationAllowed = false;
  final Set<String> _interests = {};
  final Set<int> _groupIds = {};
  List<Map<String, Object?>> _groups = [];

  @override
  void initState() {
    super.initState();
    UserDao.suggestedGroups().then((g) {
      if (mounted) setState(() => _groups = g);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _cardNumber, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- Navigation entre les etapes ----------
  /// SU-03 : demande la permission de localisation au systeme.
  Future<void> _askLocation() async {
    final error = await LocationService.ensurePermission();
    if (!mounted) return;
    if (error != null) {
      AppSnack.show(context, error, error: true);
      return;
    }
    setState(() => _locationAllowed = true);
  }

  Future<void> _next() async {
    if (_saving) return; // evite un double appui (etape sautee / compte en double)
    if (!_formKey.currentState!.validate()) return; // erreurs en rouge
    if (_step == 0) {
      setState(() => _saving = true);
      final exists = await UserDao.emailExists(_email.text.trim());
      if (!mounted) return;
      setState(() => _saving = false);
      if (exists) {
        AppSnack.show(context, 'Cet e-mail est déjà utilisé', error: true);
        return;
      }
    }
    if (_step == 1) {
      setState(() => _saving = true);
      final taken = await UserDao.cardNumberTaken(_cardNumber.text.trim());
      if (!mounted) return;
      setState(() => _saving = false);
      if (taken) {
        AppSnack.show(context, 'Ce numéro de carte est déjà utilisé', error: true);
        return;
      }
    }
    if (_step == 4) {
      await _createAccount();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  // ---------- CREATE : on enregistre le compte ----------
  Future<void> _createAccount() async {
    setState(() => _saving = true);
    final int id;
    try {
      id = await UserDao.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        cardNumber: _cardNumber.text.trim(),
        filiere: _filiere,
        city: _city.text.trim(),
        campus: _campus,
        interests: _interests,
      );
    } catch (_) {
      // ex. UNIQUE constraint : e-mail pris entre-temps
      if (!mounted) return;
      setState(() {
        _saving = false;
        _step = 0;
      });
      AppSnack.show(context, 'Impossible de créer le compte (e-mail déjà utilisé ?)', error: true);
      return;
    }
    await UserDao.joinGroups(id, _groupIds);
    await RewardEngine.addPoints(id, RewardEngine.signupPoints); // +100 pts
    await Session.login(id: id, name: _name.text.trim(), role: 'student');

    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = 5; // SU-06 : succes
    });
    // Apres 1,2 s -> accueil
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 5) return _buildSuccess();

    return Scaffold(
      appBar: AppBar(
        title: Text('Étape ${_step + 1}/5 · ${_titles[_step]}'),
        actions: [TextButton(onPressed: _back, child: const Text('Retour'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / 5,
              color: AppColors.red,
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 20),
            ..._stepContent(),
            const SizedBox(height: 8),
            AppButton(
              label: _step == 4 ? 'Terminer et entrer' : 'Continuer',
              loading: _saving,
              onPressed: _next,
            ),
            if (_step == 0) ...[
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.signIn),
                child: const Text('J’ai déjà un compte'),
              ),
              TextButton(
                onPressed: () async {
                  await Session.logout();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (r) => false);
                },
                child: const Text('Explorer sans compte'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _titles = ['Compte', 'Carte étudiante', 'Localisation', 'Intérêts', 'Groupes'];

  List<Widget> _stepContent() {
    switch (_step) {
      case 0: // SU-01 Compte
        return [
          Text('Crée ton compte', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Nom complet',
            controller: _name,
            validator: (v) => AppTextField.notEmpty(v, 'Le nom est obligatoire'),
          ),
          AppTextField(
            label: 'E-mail ESPRIT',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'L’e-mail est obligatoire';
              if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v.trim())) {
                return 'E-mail invalide';
              }
              return null;
            },
          ),
          AppTextField(
            label: 'Mot de passe (6 caractères min.)',
            controller: _password,
            obscure: true,
            validator: (v) => (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
          ),
        ];
      case 1: // SU-02 Carte etudiante
        return [
          const Card(
            child: ListTile(
              leading: Icon(Icons.badge_outlined, color: AppColors.grey),
              title: Text('Carte étudiante ESPRIT'),
              subtitle: Text('Votre numéro sera vérifié par l’administration. '
                  'La réservation des terrains est possible après validation.'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Numéro de carte étudiante',
            controller: _cardNumber,
            hint: 'Tel qu’il figure sur votre carte',
            validator: (v) => AppTextField.notEmpty(v, 'Numéro obligatoire'),
          ),
          Text('Filière', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _filiere,
            items: _filieres.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _filiere = v!),
          ),
          const SizedBox(height: 14),
        ];
      case 2: // SU-03 Localisation
        return [
          Text('Localisation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Pour te proposer les événements proches et activer Beacon.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Ville',
            controller: _city,
            validator: (v) => AppTextField.notEmpty(v, 'La ville est obligatoire'),
          ),
          Text('Campus', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _campus,
            items: _campuses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _campus = v!),
          ),
          const SizedBox(height: 14),
          // Vraie demande de permission GPS. Aucune position n'est stockee ici
          // (regle du PDF : pas de donnee de position sans consentement).
          AppButton(
            label: _locationAllowed ? '✔ Localisation autorisée' : 'Autoriser la localisation',
            outlined: true,
            onPressed: _askLocation,
          ),
          const SizedBox(height: 14),
        ];
      case 3: // SU-04 Interets
        return [
          Text('Tes centres d’intérêt', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Choisis-en autant que tu veux.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ChipSelector(
            options: _interestOptions,
            selected: _interests,
            onTap: (o) => setState(() {
              if (!_interests.add(o)) _interests.remove(o); // ajoute, sinon retire
            }),
          ),
          const SizedBox(height: 20),
        ];
      default: // 4 : SU-05 Groupes
        return [
          Text('Rejoins des groupes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Tu pourras en changer à tout moment.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final g in _groups)
            Card(
              child: CheckboxListTile(
                activeColor: AppColors.red,
                value: _groupIds.contains(g['id'] as int),
                onChanged: (on) => setState(() {
                  on == true ? _groupIds.add(g['id'] as int) : _groupIds.remove(g['id'] as int);
                }),
                title: Text('${g['icon']}  ${g['name']}'),
                subtitle: Text('${g['members']} membre(s)'),
              ),
            ),
        ];
    }
  }

  // SU-06 : succes
  Widget _buildSuccess() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              'Bienvenue ${_name.text.trim().split(' ').first} !',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text('+100 pts', style: TextStyle(color: AppColors.gold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
