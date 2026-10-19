import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/group_dao.dart';
import '../models/campus_event.dart';

/// GRP-01 : groupes du campus, avec Rejoindre / Quitter.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<CampusGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await GroupDao.getAll(Session.userId);
    if (mounted) setState(() => _groups = g);
  }

  Future<void> _toggle(CampusGroup g) async {
    if (!await GuestGate.check(context, message: 'Créez un compte pour rejoindre un groupe.')) {
      return;
    }
    g.joined
        ? await GroupDao.leave(g.id, Session.userId!)
        : await GroupDao.join(g.id, Session.userId!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groupes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final g in _groups)
            Card(
              child: ListTile(
                leading: Text(g.icon, style: const TextStyle(fontSize: 28)),
                title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${g.members} membres'),
                trailing: g.joined
                    ? OutlinedButton(onPressed: () => _toggle(g), child: const Text('Quitter'))
                    : ElevatedButton(onPressed: () => _toggle(g), child: const Text('Rejoindre')),
              ),
            ),
        ],
      ),
    );
  }
}
