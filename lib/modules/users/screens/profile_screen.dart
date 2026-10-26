import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/user_dao.dart';
import '../models/app_user.dart';

/// PRO-01 : profil (onglet "Profil") + PRO-04 (suppression du compte).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;
  ProfileStats _stats = const ProfileStats(0, 0, 0);
  List<BeaconContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// READ : charge le profil depuis SQLite.
  Future<void> _load() async {
    final uid = Session.userId;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final user = await UserDao.getById(uid);
    final stats = await UserDao.stats(uid);
    final contacts = await UserDao.beaconContacts(uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _stats = stats;
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _openAndReload(String route) async {
    await Navigator.pushNamed(context, route);
    _load();
  }

  /// DELETE avec confirmation (PRO-04) -> retour a l'inscription.
  Future<void> _deleteAccount() async {
    final ok = await ConfirmSheet.show(context,
        title: 'Supprimer le compte ?',
        message: 'Vos données seront effacées. Action irréversible.',
        confirmLabel: 'Supprimer définitivement');
    if (!ok) return;
    await UserDao.delete(Session.userId!);
    await Session.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.signUp, (r) => false);
  }

  Future<void> _logout() async {
    await Session.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.signIn, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Profil'),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (Session.isGuest || _user == null) {
      return EmptyState(
        emoji: '👤',
        message: 'Connectez-vous pour voir votre profil.',
        buttonLabel: 'Se connecter',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.signIn),
      );
    }

    final u = _user!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // En-tete : avatar, nom, e-mail, filiere, campus, ville
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Avatar(name: u.name, radius: 26),
            title: Row(children: [
              Flexible(
                child: Text(u.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (u.cardVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 18, color: AppColors.green),
              ],
            ]),
            subtitle: Text([
              u.email,
              [u.filiere, u.campus].where((s) => s.isNotEmpty).join(' · '),
              [u.city, '${u.points} pts', if (u.isAdmin) 'Administrateur']
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
            ].where((s) => s.isNotEmpty).join('\n')),
            isThreeLine: true,
          ),
        ),
        // Carte etudiante : validee / en attente / refusee (par l'admin)
        if (!u.isAdmin)
          Card(
            child: ListTile(
              leading: Icon(
                u.cardStatus == 1
                    ? Icons.verified
                    : u.cardStatus == -1
                        ? Icons.error_outline
                        : Icons.hourglass_top,
                color: u.cardStatus == 1
                    ? AppColors.green
                    : u.cardStatus == -1
                        ? AppColors.red
                        : AppColors.gold,
              ),
              title: Text(u.cardStatusLabel),
              subtitle: Text(u.cardStatus == -1
                  ? 'N° ${u.cardNumber} · corrigez-le dans « Modifier le profil »'
                  : 'N° ${u.cardNumber}'),
            ),
          ),
        Row(children: [
          Expanded(child: StatTile(value: _stats.km.toStringAsFixed(1), label: 'km total')),
          Expanded(child: StatTile(value: '${_stats.activities}', label: 'activités')),
          Expanded(child: StatTile(value: '${_stats.events}', label: 'événements')),
        ]),
        // Centres d'interet
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Centres d’intérêt', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                u.interests.isEmpty
                    ? Text('Aucun', style: Theme.of(context).textTheme.bodySmall)
                    : Wrap(
                        spacing: 6,
                        children: [for (final i in u.interests) Chip(label: Text(i))],
                      ),
              ],
            ),
          ),
        ),
        // Contacts Beacon (n/3)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('Contacts Beacon (${_contacts.length}/3)',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (u.beaconActive)
                    const Text('Actif', style: TextStyle(color: AppColors.green)),
                ]),
                const SizedBox(height: 8),
                if (_contacts.isEmpty)
                  Text('Aucun contact', style: Theme.of(context).textTheme.bodySmall),
                for (final c in _contacts) Text('📞 ${c.phone}'),
                TextButton(
                  onPressed: () => _openAndReload(AppRoutes.beacon),
                  child: const Text('Ouvrir Beacon'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: AppButton(
                  label: 'Modifier le profil',
                  onPressed: () => _openAndReload(AppRoutes.editProfile))),
          const SizedBox(width: 10),
          Expanded(
              child: AppButton(
                  label: 'Chat',
                  outlined: true,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.chatRooms))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: AppButton(
                  label: 'Thème clair / sombre',
                  outlined: true,
                  onPressed: ThemeController.toggle)),
          const SizedBox(width: 10),
          Expanded(
              child: AppButton(label: 'Se déconnecter', outlined: true, onPressed: _logout)),
        ]),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.changePassword),
          child: const Text('Changer le mot de passe'),
        ),
        TextButton(
          onPressed: _deleteAccount,
          child: const Text('Supprimer mon compte',
              style: TextStyle(color: AppColors.red)),
        ),
        const SizedBox(height: 60), // place pour le bouton rouge central
      ],
    );
  }
}
