import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Partage via la feuille de partage native d'Android (Instagram, WhatsApp,
/// Facebook...). Rien n'est jamais publie automatiquement : c'est
/// l'utilisateur qui choisit l'application et valide.
class ShareService {
  /// Lien d'invitation (page de telechargement de l'app), fourni au build :
  ///   flutter build apk --dart-define=INVITE_URL=https://...
  /// Vide = message d'invitation sans lien.
  static const inviteUrl = String.fromEnvironment('INVITE_URL');

  /// Transforme la carte affichee (RepaintBoundary) en image PNG et la partage.
  static Future<void> shareCard(RenderRepaintBoundary boundary, String text) async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('capture impossible');
    // dossier temporaire prive : le fichier n'est lisible que par l'app choisie
    final file = File(p.join((await getTemporaryDirectory()).path, 'esprit_move_activite.png'));
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: text,
    ));
  }

  static const _app = MethodChannel('esprit_move/app');

  static String inviteText(String fromName) =>
      '${fromName.isEmpty ? 'Je t’invite' : '$fromName t’invite'} à enregistrer tes sorties '
      'sportives avec moi sur ESPRIT Move, l’app sport du campus ESPRIT ! 🏃🚴'
      '${inviteUrl.isEmpty ? '' : '\n$inviteUrl'}';

  /// Invitation : message (+ lien si configure). Avec [withApp], l'application
  /// elle-meme (APK installe) est jointe : l'ami l'installe directement depuis
  /// WhatsApp, Bluetooth, Quick Share... sans serveur ni store.
  static Future<void> invite(String fromName, {required bool withApp}) async {
    final files = <XFile>[];
    if (withApp) {
      final src = await _app.invokeMethod<String>('apkPath');
      if (src == null) throw StateError('APK introuvable');
      final apk = File(p.join((await getTemporaryDirectory()).path, 'ESPRIT_Move.apk'));
      await File(src).copy(apk.path);
      files.add(XFile(apk.path, mimeType: 'application/vnd.android.package-archive'));
    }
    await SharePlus.instance.share(ShareParams(
      subject: 'Rejoins-moi sur ESPRIT Move',
      text: inviteText(fromName),
      files: files.isEmpty ? null : files,
    ));
  }
}
