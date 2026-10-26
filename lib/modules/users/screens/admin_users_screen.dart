import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/user_dao.dart';
import '../models/app_user.dart';

/// ADMIN (onglet "Comptes") : cartes etudiantes a valider, liste des
/// etudiants et des administrateurs.
/// Actions : valider / refuser une carte, nommer ou retirer un admin,
/// supprimer un compte.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  String _filter = 'pending';
  List<AppUser> _users = [];
  int _pending = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final u = await UserDao.adminList(_filter, search: _search.text);
    final p = await UserDao.pendingCardsCount();
    if (!mounted) return;
    setState(() {
      _users = u;
      _pending = p;
      _loading = false;
    });
  }

  Future<void> _setCard(AppUser u, int status) async {
    await UserDao.setCardStatus(u.id!, status);
    if (!mounted) return;
    AppSnack.show(context, status == 1 ? 'Carte de ${u.firstName} validée' : 'Carte refusée');
    _load();
  }

  Future<void> _setRole(AppUser u, String role) async {
    if (role == 'student' && await UserDao.adminCount() <= 1) {
      if (!mounted) return;
      AppSnack.show(context, 'Il faut au moins un administrateur', error: true);
      return;
    }
    if (!mounted) return;
    final ok = await ConfirmSheet.show(context,
        title: role == 'admin' ? 'Nommer ${u.name} administrateur ?' : 'Retirer les droits admin ?',
        message: role == 'admin'
            ? 'Il/elle pourra gérer les terrains, réservations et comptes.'
            : '${u.name} redeviendra étudiant(e).',
        confirmLabel: 'Confirmer');
    if (!ok) return;
    await UserDao.setRole(u.id!, role);
    _load();
  }

  Future<void> _delete(AppUser u) async {
    final ok = await ConfirmSheet.show(context,
        title: 'Supprimer le compte de ${u.name} ?',
        message: 'Ses activités, réservations et messages seront supprimés. Action définitive.',
        confirmLabel: 'Supprimer définitivement');
    if (!ok) return;
    await UserDao.delete(u.id!);
    if (!mounted) return;
    AppSnack.show(context, 'Compte supprimé');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comptes'), automaticallyImplyLeading: false),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: 'pending', label: FittedBox(child: Text('À valider ($_pending)'))),
              const ButtonSegment(value: 'students', label: FittedBox(child: Text('Étudiants'))),
              const ButtonSegment(value: 'admins', label: FittedBox(child: Text('Admins'))),
            ],
            selected: {_filter},
            onSelectionChanged: (s) {
              setState(() => _filter = s.first);
              _load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _search,
            onChanged: (_) => _load(),
            decoration: const InputDecoration(
                hintText: 'Rechercher (nom, e-mail, n° de carte)',
                prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? EmptyState(
                      emoji: _filter == 'pending' ? '✅' : '👤',
                      message: _filter == 'pending'
                          ? 'Aucune carte en attente de validation.'
                          : 'Aucun compte.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [for (final u in _users) _card(u)],
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _card(AppUser u) {
    final me = u.id == Session.userId;
    final statusColor = u.cardStatus == 1
        ? AppColors.green
        : u.cardStatus == -1
            ? AppColors.red
            : AppColors.gold;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(name: u.name, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me ? '${u.name} (vous)' : u.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(u.email, style: Theme.of(context).textTheme.bodySmall),
                if (!u.isAdmin) ...[
                  Text(
                      [
                        if (u.cardNumber.isNotEmpty) 'Carte ${u.cardNumber}',
                        u.filiere,
                        u.campus,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(u.cardStatusLabel, style: TextStyle(fontSize: 12, color: statusColor)),
                ],
              ]),
            ),
            if (!me)
              PopupMenuButton<String>(
                onSelected: (a) {
                  switch (a) {
                    case 'admin':
                      _setRole(u, 'admin');
                      break;
                    case 'student':
                      _setRole(u, 'student');
                      break;
                    case 'reject':
                      _setCard(u, -1);
                      break;
                    case 'delete':
                      _delete(u);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (!u.isAdmin && u.cardStatus != -1)
                    const PopupMenuItem(value: 'reject', child: Text('Refuser la carte')),
                  if (u.isAdmin)
                    const PopupMenuItem(value: 'student', child: Text('Retirer les droits admin'))
                  else
                    const PopupMenuItem(value: 'admin', child: Text('Nommer administrateur')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer le compte', style: TextStyle(color: AppColors.red))),
                ],
              ),
          ]),
          // Validation rapide de la carte etudiante
          if (!u.isAdmin && u.cardStatus != 1)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _setCard(u, 1),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Valider la carte'),
                  ),
                ),
                if (u.cardStatus == 0) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => _setCard(u, -1), child: const Text('Refuser')),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}
