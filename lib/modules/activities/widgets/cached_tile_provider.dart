import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Tuiles OpenStreetMap gardees sur le telephone : une zone deja affichee
/// (pendant la sortie, dans le recap...) reste visible HORS CONNEXION.
/// Les tuiles de plus de 30 jours sont rafraichies quand le reseau est la
/// (regle d'usage OSM), et le cache est limite a [maxTiles] fichiers.
class CachedTileProvider extends TileProvider {
  static const maxTiles = 4000; // ~80 Mo
  static const maxAge = Duration(days: 30);

  static Future<Directory>? _dir;
  static Future<Directory> get dir => _dir ??= _open();

  static Future<Directory> _open() async {
    final d = Directory(p.join((await getApplicationCacheDirectory()).path, 'osm_tiles'));
    if (!await d.exists()) await d.create(recursive: true);
    unawaited(_prune(d));
    return d;
  }

  /// Supprime les tuiles les plus anciennes au-dela de [maxTiles].
  static Future<void> _prune(Directory d) async {
    try {
      final files = await d.list().where((e) => e is File).cast<File>().toList();
      if (files.length <= maxTiles) return;
      final dated = [for (final f in files) (f, (await f.stat()).modified)]
        ..sort((a, b) => a.$2.compareTo(b.$2));
      for (final (f, _) in dated.take(files.length - maxTiles)) {
        await f.delete();
      }
    } catch (_) {}
  }

  static final _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _CachedTile(getTileUrl(coordinates, options), Map.of(headers));
}

class _CachedTile extends ImageProvider<_CachedTile> {
  final String url;
  final Map<String, String> headers;
  const _CachedTile(this.url, this.headers);

  @override
  Future<_CachedTile> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_CachedTile key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final dir = await CachedTileProvider.dir;
    final file = File(p.join(dir.path, '${url.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.png'));
    Uint8List? bytes;
    if (await file.exists()) {
      bytes = await file.readAsBytes();
      final age = DateTime.now().difference((await file.stat()).modified);
      if (age > CachedTileProvider.maxAge) {
        bytes = await _download(file) ?? bytes; // hors ligne : on garde l'ancienne
      }
    } else {
      bytes = await _download(file);
    }
    if (bytes == null) throw StateError('tuile indisponible hors connexion');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  Future<Uint8List?> _download(File file) async {
    try {
      final req = await CachedTileProvider._http.getUrl(Uri.parse(url));
      headers.forEach(req.headers.set);
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(res);
      await file.writeAsBytes(bytes, flush: false);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) => other is _CachedTile && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
