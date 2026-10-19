import 'package:flutter/material.dart';
import '../app_routes.dart';
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
      actions: showActions
          ? [
              _icon(context, Icons.chat_bubble_outline, AppRoutes.chatRooms),
              _icon(context, Icons.notifications_none, AppRoutes.notifications),
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
