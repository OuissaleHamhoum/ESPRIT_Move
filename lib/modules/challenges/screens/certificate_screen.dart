import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../data/badge_dao.dart';
import '../models/challenge_models.dart';

/// BDG-02 : certificat d'un badge. Badge verrouille : gris, sans "Partager".
/// "Partager" copie le texte du certificat (voir GUIDE.md pour share_plus).
class CertificateScreen extends StatelessWidget {
  final BadgeItem badge;
  const CertificateScreen({super.key, required this.badge});

  Future<void> _share(BuildContext context) async {
    final text = '🏅 ${badge.name} - Certificat ESPRIT Move décerné à ${Session.name}. '
        '${badge.condition}.';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) AppSnack.show(context, 'Certificat copié, prêt à partager !');
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await ConfirmSheet.show(context,
        title: 'Supprimer ce badge ?', message: badge.name);
    if (!ok) return;
    await BadgeDao.delete(badge.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Certificat')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Opacity(
            opacity: badge.earned ? 1 : 0.4,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red, width: 4), // cadre rouge
              ),
              child: Column(children: [
                Text('Certificat ESPRIT Move', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Text(badge.icon, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(badge.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(badge.earned ? 'décerné à ${Session.name}' : 'Badge verrouillé'),
                const SizedBox(height: 6),
                Text(badge.condition, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          if (badge.earned) AppButton(label: 'Partager', onPressed: () => _share(context)),
          if (Session.isAdmin) ...[
            const SizedBox(height: 10),
            AppButton(
                label: 'Supprimer le badge',
                outlined: true,
                onPressed: () => _delete(context)),
          ],
        ],
      ),
    );
  }
}
