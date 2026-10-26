import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../data/share_service.dart';

/// Inviter un ami qui n'a pas encore l'app : envoyer l'application (APK)
/// ou un simple message, via la feuille de partage Android.
class InviteSheet {
  static Future<void> show(BuildContext context) async {
    final withApp = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.android, color: AppColors.green),
            title: const Text('Envoyer l’application'),
            subtitle: const Text('Votre ami l’installe directement (WhatsApp, Quick Share…)'),
            onTap: () => Navigator.pop(ctx, true),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('Envoyer un message'),
            subtitle: Text(ShareService.inviteUrl.isEmpty
                ? 'Invitation par texte'
                : 'Avec le lien de téléchargement'),
            onTap: () => Navigator.pop(ctx, false),
          ),
        ]),
      ),
    );
    if (withApp == null) return;
    try {
      await ShareService.invite(Session.name, withApp: withApp);
    } catch (_) {
      if (context.mounted) AppSnack.show(context, 'Partage impossible.');
    }
  }
}
