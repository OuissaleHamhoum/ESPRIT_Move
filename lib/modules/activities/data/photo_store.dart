import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Photos des sorties : copiees dans le dossier PRIVE de l'application
/// (invisible des autres apps, supprime avec l'app). En base on ne garde
/// que le chemin du fichier.
class PhotoStore {
  static final _picker = ImagePicker();

  static Future<Directory> _dir() async {
    final d = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'activity_photos'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Ouvre l'appareil photo ou la galerie. Retourne le chemin prive, ou null
  /// si l'utilisateur a annule.
  static Future<String?> pick({required bool camera}) async {
    final x = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2048, // suffisant pour l'ecran et le partage, fichiers legers
      imageQuality: 85,
    );
    if (x == null) return null;
    final ext = p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path);
    final dest = p.join((await _dir()).path, '${DateTime.now().microsecondsSinceEpoch}$ext');
    await File(x.path).copy(dest);
    return dest;
  }

  static Future<void> deleteAll(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
