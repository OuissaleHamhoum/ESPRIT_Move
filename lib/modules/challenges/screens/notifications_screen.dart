import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../data/home_dao.dart';

/// NOTIF-01 : notifications calculees (serie en danger, invitation,
/// badge debloque, offre partenaire).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    HomeDao.notifications(Session.userId).then((l) {
      if (mounted) setState(() => _items = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔔 Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [for (final n in _items) Card(child: ListTile(title: Text(n)))],
      ),
    );
  }
}
