import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'track_recorder.dart';

/// Sortie en cours sauvegardee dans le stockage prive de l'application.
/// Si Android tue l'application pendant l'enregistrement, la sortie est
/// proposee a la reprise au lancement suivant (rien n'est perdu).
class DraftStore {
  static Future<File> _file() async =>
      File(p.join((await getApplicationSupportDirectory()).path, 'rec_draft.json'));

  /// Ecriture atomique : fichier temporaire puis renommage.
  static Future<void> save(TrackRecorder r) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(r.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  static Future<TrackRecorder?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      return TrackRecorder.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      await clear(); // fichier corrompu : on l'oublie
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
