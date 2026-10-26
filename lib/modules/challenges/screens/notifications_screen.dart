import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/home_dao.dart';

/// NOTIF-01 : notifications.
///   - envoyees par l'administration (reservation annulee, carte validee...)
///   - calculees depuis les donnees (serie en danger, invitation, badge).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<StoredNotification> _stored = [];
  List<String> _computed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Session.userId;
    final stored = uid == null ? <StoredNotification>[] : await NotificationService.forUser(uid);
    final computed = await HomeDao.notifications(uid);
    if (uid != null) await NotificationService.markAllRead(uid);
    if (!mounted) return;
    setState(() {
      _stored = stored;
      _computed = computed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔔 Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stored.isEmpty && _computed.isEmpty
              ? const EmptyState(emoji: '🔔', message: 'Aucune notification.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final n in _computed) Card(child: ListTile(title: Text(n))),
                    for (final n in _stored)
                      Card(
                        child: ListTile(
                          title: Text(n.text,
                              style: TextStyle(
                                  fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Text(
                              '${Fmt.shortDate(Fmt.dbDate(n.createdAt))} · '
                              '${Fmt.two(n.createdAt.hour)}:${Fmt.two(n.createdAt.minute)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.grey)),
                        ),
                      ),
                  ],
                ),
    );
  }
}
