import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../services/notification_service.dart';
import '../session/session.dart';
import '../theme/app_colors.dart';

/// En-tete commun : logo "ESPRIT Move" (ou un titre) + 3 icones
/// (chat, notifications, Beacon) + ligne rouge, comme sur les maquettes.
///
///   appBar: const AppTopBar()                       -> logo
///   appBar: const AppTopBar(title: 'Mes activités') -> titre
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showActions;
  const AppTopBar({super.key, this.title, this.showActions = true});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null
          ? Text(title!)
          : const Text.rich(TextSpan(children: [
              TextSpan(text: 'ESPRIT '),
              TextSpan(text: 'Move', style: TextStyle(color: AppColors.red)),
            ])),
      // Raccourcis etudiant (chat, notifications, Beacon) : pas pour l'admin
      actions: showActions && !Session.isAdmin
          ? [
              _icon(context, Icons.chat_bubble_outline, AppRoutes.chatRooms),
              _NotificationsButton(),
              _icon(context, Icons.location_on_outlined, AppRoutes.beacon),
            ]
          : null,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: SizedBox(
            height: 2, width: double.infinity, child: ColoredBox(color: AppColors.red)),
      ),
    );
  }

  Widget _icon(BuildContext context, IconData icon, String route) => IconButton(
        icon: Icon(icon),
        onPressed: () => Navigator.pushNamed(context, route),
      );
}

/// Cloche + pastille rouge s'il y a des notifications non lues
/// (ex. reservation annulee par l'administration).
class _NotificationsButton extends StatefulWidget {
  @override
  State<_NotificationsButton> createState() => _NotificationsButtonState();
}

class _NotificationsButtonState extends State<_NotificationsButton> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Session.userId;
    if (uid == null) return;
    final n = await NotificationService.unreadCount(uid);
    if (mounted) setState(() => _unread = n);
  }

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Badge(
          isLabelVisible: _unread > 0,
          label: Text('$_unread'),
          child: const Icon(Icons.notifications_none),
        ),
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.notifications);
          _load(); // tout est lu en sortant
        },
      );
}
