import 'package:flutter/material.dart';
import 'app_button.dart';

/// Confirmation avant toute suppression (regle transverse du PDF).
///
///   final ok = await ConfirmSheet.show(context,
///       title: 'Supprimer cette activité ?',
///       message: 'Cette action est définitive.');
///   if (ok) { ... supprimer ... }
class ConfirmSheet {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Supprimer',
    String cancelLabel = 'Annuler',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 20),
            AppButton(label: confirmLabel, onPressed: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 10),
            AppButton(
                label: cancelLabel,
                outlined: true,
                onPressed: () => Navigator.pop(ctx, false)),
          ],
        ),
      ),
    );
    return result ?? false; // fermer la feuille = annuler
  }
}
