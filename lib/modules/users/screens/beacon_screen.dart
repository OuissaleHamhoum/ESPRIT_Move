import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/user_dao.dart';
import '../models/app_user.dart';

/// PRO-03 : Beacon = partage de position avec 3 contacts maximum.
/// Regle : l'activation est IMPOSSIBLE sans contact.
/// Aucune position n'est stockee (prototype : on memorise seulement actif/inactif).
class BeaconScreen extends StatefulWidget {
  const BeaconScreen({super.key});

  @override
  State<BeaconScreen> createState() => _BeaconScreenState();
}

class _BeaconScreenState extends State<BeaconScreen> {
  List<BeaconContact> _contacts = [];
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Session.userId;
    if (uid == null) return;
    final user = await UserDao.getById(uid);
    final contacts = await UserDao.beaconContacts(uid);
    if (!mounted) return;
    setState(() {
      _active = user?.beaconActive ?? false;
      _contacts = contacts;
    });
  }

  Future<void> _toggle() async {
    if (!await GuestGate.check(context, message: 'Créez un compte pour utiliser Beacon.')) {
      return;
    }
    final ok = await UserDao.setBeaconActive(Session.userId!, !_active);
    if (!mounted) return;
    if (!ok) {
      AppSnack.show(context, 'Ajoutez au moins un contact (Profil > Modifier)', error: true);
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📍 Beacon')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Partagez votre position en direct avec 3 contacts maximum.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (_contacts.isEmpty)
            const Card(
                child: ListTile(title: Text('Aucun contact'),
                    subtitle: Text('Ajoutez-en dans Profil > Modifier le profil')))
          else
            for (final c in _contacts)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(c.phone),
                  subtitle: Text(_active ? 'voit votre position' : 'en pause',
                      style: TextStyle(color: _active ? AppColors.red : null)),
                ),
              ),
          const SizedBox(height: 16),
          AppButton(
            label: _active ? 'Arrêter le partage' : 'Activer le partage',
            outlined: _active,
            onPressed: _toggle,
          ),
        ],
      ),
    );
  }
}
