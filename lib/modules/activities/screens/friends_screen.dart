import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/friend_dao.dart';
import '../models/activity.dart';
import '../widgets/activity_tile.dart';
import '../widgets/invite_sheet.dart';
import 'activity_detail_screen.dart';

/// Amis : fil des sorties partagees + gestion des amis (recherche,
/// demandes recues / envoyees, invitations).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Activity> _feed = [];
  List<FriendUser> _related = [];
  List<FriendUser>? _results; // null = pas de recherche en cours
  bool _loading = true;

  int get _me => Session.userId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final feed = await FriendDao.feed(_me);
    final related = await FriendDao.related(_me);
    if (!mounted) return;
    setState(() {
      _feed = feed;
      _related = related;
      _loading = false;
    });
    if (_results != null) _runSearch();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _search.text;
    if (q.trim().isEmpty) return;
    final r = await FriendDao.search(_me, q);
    if (mounted && _search.text == q) setState(() => _results = r);
  }

  Future<void> _act(Future<void> Function() action, String message) async {
    try {
      await action();
      if (mounted) AppSnack.show(context, message);
    } catch (_) {
      if (mounted) AppSnack.show(context, 'Action impossible, réessayez.', error: true);
    }
    await _load();
  }

  Future<void> _removeFriend(FriendUser u) async {
    final ok = await ConfirmSheet.show(context,
        title: 'Retirer ${u.name} ?', message: 'Vous ne verrez plus vos sorties respectives.');
    if (ok) await _act(() => FriendDao.remove(_me, u.id), 'Ami retiré');
  }

  @override
  Widget build(BuildContext context) {
    final received = _related.where((u) => u.status == FriendStatus.received).length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Amis'),
          bottom: TabBar(
            indicatorColor: AppColors.red,
            labelColor: AppColors.red,
            tabs: [
              const Tab(text: 'Fil d’activité'),
              Tab(text: received == 0 ? 'Mes amis' : 'Mes amis ($received)'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_feedTab(), _friendsTab()]),
      ),
    );
  }

  // ---------- Fil ----------
  Widget _feedTab() {
    if (_feed.isEmpty) {
      return EmptyState(
        emoji: '👥',
        message: _related.any((u) => u.status == FriendStatus.friends)
            ? 'Vos amis n’ont encore partagé aucune sortie.'
            : 'Ajoutez des amis pour voir leurs sorties ici.',
        buttonLabel: 'Inviter des amis',
        onPressed: () => InviteSheet.show(context),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        for (final a in _feed)
          ActivityTile(
            activity: a,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: a.id!))),
          ),
      ]),
    );
  }

  // ---------- Amis ----------
  Widget _friendsTab() {
    final small = Theme.of(context).textTheme.titleSmall;
    List<FriendUser> by(FriendStatus s) => _related.where((u) => u.status == s).toList();
    final received = by(FriendStatus.received), friends = by(FriendStatus.friends), sent = by(FriendStatus.sent);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Rechercher un étudiant (nom ou email)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      _onSearch('');
                    }),
          ),
        ),
        const SizedBox(height: 12),
        if (_results != null) ...[
          if (_results!.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun étudiant trouvé.', textAlign: TextAlign.center)),
          for (final u in _results!) _userTile(u),
        ] else ...[
          if (received.isNotEmpty) ...[
            Text('Demandes reçues', style: small),
            for (final u in received) _userTile(u),
            const SizedBox(height: 8),
          ],
          Text('Mes amis (${friends.length})', style: small),
          if (friends.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Recherchez un étudiant ci-dessus pour l’ajouter.')),
          for (final u in friends) _userTile(u),
          if (sent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Demandes envoyées', style: small),
            for (final u in sent) _userTile(u),
          ],
        ],
        const SizedBox(height: 16),
        AppButton(
            label: 'Inviter un ami qui n’a pas l’app',
            icon: Icons.person_add_alt,
            outlined: true,
            onPressed: () => InviteSheet.show(context)),
      ]),
    );
  }

  Widget _userTile(FriendUser u) {
    final name = Session.name;
    final Widget trailing = switch (u.status) {
      FriendStatus.none => FilledButton.tonal(
          onPressed: () => _act(() => FriendDao.request(_me, name, u.id), 'Demande envoyée'),
          child: const Text('Ajouter')),
      FriendStatus.sent => TextButton(
          onPressed: () => _act(() => FriendDao.remove(_me, u.id), 'Demande annulée'),
          child: const Text('Annuler')),
      FriendStatus.received => Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: 'Refuser',
              onPressed: () => _act(() => FriendDao.remove(_me, u.id), 'Demande refusée'),
              icon: const Icon(Icons.close)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => _act(() => FriendDao.accept(_me, name, u.id), 'Vous êtes amis 🤝'),
              child: const Text('Accepter')),
        ]),
      FriendStatus.friends => IconButton(
          tooltip: 'Retirer',
          onPressed: () => _removeFriend(u),
          icon: const Icon(Icons.person_remove_outlined)),
    };
    return Card(
      child: ListTile(
        leading: Avatar(name: u.name),
        title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(u.status == FriendStatus.friends ? 'Ami' : u.email,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
      ),
    );
  }
}
