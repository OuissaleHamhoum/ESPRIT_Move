import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Notification courte en bas de l'ecran (toast).
///   AppSnack.show(context, 'Activité enregistrée');
///   AppSnack.show(context, 'Créneau déjà pris', error: true);
class AppSnack {
  static void show(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
      ));
  }
}
