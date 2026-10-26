import 'package:flutter/material.dart';
import '../../../core/utils/format.dart';
import '../models/activity.dart';
import '../screens/rec_live_screen.dart';
import 'draft_store.dart';

/// Propose de reprendre une sortie interrompue (app tuee par Android,
/// telephone redemarre...). Retourne true si une sortie a ete reprise.
class DraftRecovery {
  static bool _asked = false; // une seule fois par lancement de l'app

  static Future<bool> check(BuildContext context) async {
    if (_asked) return false;
    _asked = true;
    final r = await DraftStore.load();
    if (r == null || !context.mounted) return false;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sortie interrompue'),
        content: Text('${ActivityTypes.iconOf(r.type)} ${r.type} commencée à '
            '${Fmt.hm(r.startedAt)} · ${r.km.toStringAsFixed(2)} km enregistrés.\n'
            'Voulez-vous la reprendre ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Supprimer')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reprendre')),
        ],
      ),
    );
    if (resume != true) {
      await DraftStore.clear();
      return false;
    }
    if (!context.mounted) return false;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => RecLiveScreen(type: r.type, restore: r)));
    return true;
  }
}
