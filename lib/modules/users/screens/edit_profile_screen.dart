import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/chip_selector.dart';
import '../data/user_dao.dart';

/// PRO-02 : modifier le nom, le campus, la ville, les centres d'interet et les contacts Beacon.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _options = [
    'Running', 'Football', 'Basket', 'Yoga', 'Muscu', 'Vélo', 'Natation', 'Tennis'
  ];
  static const _campuses = ['Campus Ghazela', 'Campus Charguia'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _cardNumber = TextEditingController();
  String _initialCard = '';
  int _cardStatus = 0;
  String _campus = _campuses.first;
  final _newPhone = TextEditingController();
  final Set<String> _interests = {};
  final List<String> _phones = []; // 3 maximum
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _cardNumber.dispose();
    _newPhone.dispose();
    super.dispose();
  }

  /// On pre-remplit le formulaire avec les valeurs actuelles.
  Future<void> _loadCurrentValues() async {
    final uid = Session.userId!;
    final user = await UserDao.getById(uid);
    final contacts = await UserDao.beaconContacts(uid);
    if (!mounted || user == null) return;
    setState(() {
      _name.text = user.name;
      if (_campuses.contains(user.campus)) _campus = user.campus;
      _city.text = user.city;
      _cardNumber.text = _initialCard = user.cardNumber;
      _cardStatus = user.cardStatus;
      _interests.addAll(user.interests);
      _phones.addAll(contacts.map((c) => c.phone));
      _ready = true;
    });
  }

  void _addPhone() {
    final p = _newPhone.text.trim();
    if (p.length < 8) {
      AppSnack.show(context, 'Numéro invalide (8 chiffres min.)', error: true);
      return;
    }
    if (_phones.contains(p)) {
      AppSnack.show(context, 'Ce numéro est déjà dans la liste', error: true);
      return;
    }
    if (_phones.length >= 3) {
      AppSnack.show(context, 'Maximum 3 contacts Beacon', error: true);
      return;
    }
    setState(() {
      _phones.add(p);
      _newPhone.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final card = _cardNumber.text.trim();
    final cardChanged = !Session.isAdmin && card != _initialCard;
    if (cardChanged && await UserDao.cardNumberTaken(card, exceptUserId: Session.userId)) {
      if (!mounted) return;
      AppSnack.show(context, 'Ce numéro de carte est déjà utilisé', error: true);
      return;
    }
    await UserDao.updateProfile(
      userId: Session.userId!,
      name: _name.text.trim(),
      campus: _campus,
      city: _city.text.trim(),
      interests: _interests,
      beaconPhones: _phones,
      cardNumber: Session.isAdmin ? null : card,
    );
    Session.name = _name.text.trim();
    if (!mounted) return;
    AppSnack.show(
        context,
        cardChanged
            ? 'Profil mis à jour · nouvelle carte envoyée pour validation'
            : 'Profil mis à jour');
    Navigator.pop(context); // retour au profil (PRO-01)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppTextField(
                      label: 'Nom complet',
                      controller: _name,
                      validator: (v) => AppTextField.notEmpty(v, 'Le nom est obligatoire')),
                  Text('Campus', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _campus,
                    items: _campuses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _campus = v!),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                      label: 'Ville',
                      controller: _city,
                      validator: (v) => AppTextField.notEmpty(v, 'La ville est obligatoire')),
                  if (!Session.isAdmin)
                    AppTextField(
                      label: _cardStatus == 1
                          ? 'N° de carte étudiante (validée — la modifier relance la validation)'
                          : 'N° de carte étudiante',
                      controller: _cardNumber,
                      validator: (v) => AppTextField.notEmpty(v, 'Numéro obligatoire'),
                    ),
                  Text('Centres d’intérêt', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  ChipSelector(
                    options: _options,
                    selected: _interests,
                    onTap: (o) => setState(() {
                      if (!_interests.add(o)) _interests.remove(o);
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text('Contacts Beacon (max. 3)',
                      style: Theme.of(context).textTheme.bodySmall),
                  for (var i = 0; i < _phones.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone),
                      title: Text(_phones[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _phones.removeAt(i)),
                      ),
                    ),
                  if (_phones.length < 3)
                    Row(children: [
                      Expanded(
                        child: AppTextField(
                            label: 'Ajouter un contact',
                            controller: _newPhone,
                            keyboardType: TextInputType.phone,
                            hint: '+216 20 123 456'),
                      ),
                      IconButton(icon: const Icon(Icons.add_circle), onPressed: _addPhone),
                    ]),
                  const SizedBox(height: 8),
                  AppButton(label: 'Enregistrer', onPressed: _save),
                ],
              ),
            ),
    );
  }
}
