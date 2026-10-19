import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../session/session.dart';
import 'app_button.dart';

/// Visiteur sans compte : les actions d'ECRITURE renvoient vers l'inscription
/// (ecrans EV-06 et BK-06 du PDF).
///
///   onPressed: () async {
///     if (!await GuestGate.check(context, message: 'Créez un compte pour rejoindre.')) return;
///     ... action reservee aux utilisateurs connectes ...
///   }
class GuestGate {
  static Future<bool> check(BuildContext context,
      {String message = 'Créez un compte pour continuer.'}) async {
    if (!Session.isGuest) return true;
    final nav = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Crée un compte', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 20),
            AppButton(
                label: 'Créer mon compte',
                onPressed: () {
                  Navigator.pop(ctx);
                  nav.pushNamed(AppRoutes.signUp);
                }),
            const SizedBox(height: 10),
            AppButton(
                label: 'Annuler', outlined: true, onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
    return false;
  }
}
