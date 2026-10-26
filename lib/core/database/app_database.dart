import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;
import 'schema.dart';
import 'seed_data.dart';

/// Ouvre (une seule fois) la base SQLite locale du telephone ou web.
///
/// Le fichier "esprit_move.db" est cree automatiquement dans le stockage prive
/// de l'application : pas de serveur, pas d'internet, pas de configuration.
///
/// Utilisation dans n'importe quel DAO :
///   final db = await AppDatabase.db;
///   final rows = await db.query('activities');
class AppDatabase {
  /// Incrementer ce numero quand le schema change (voir schema.dart).
  static const int dbVersion = 5; // v4 : suivi GPS detaille, v5 : amis (migrations sans perte)
  static const String _fileName = 'esprit_move.db';

  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  /// Sur Android / iOS : sqflite fonctionne directement.
  /// Sur Windows / Linux / macOS : on active le moteur FFI.
  /// Sur le navigateur (Chrome, Edge) : sqflite_common_ffi_web.
  static bool _factoryReady = false;
  static void _initFactory() {
    if (_factoryReady) return;
    _factoryReady = true;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android / iOS : sqflite natif, rien a faire.
  }

  static Future<Database> _open() async {
    _initFactory();
    final path = join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: dbVersion,
      // Active les cles etrangeres (ON DELETE CASCADE) : supprimer un compte
      // supprime aussi ses activites, reservations, etc.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (final sql in Schema.tables) {
          await db.execute(sql);
        }
        await SeedData.run(db); // donnees de depart (compte admin...)
      },
      onUpgrade: (db, oldV, newV) async {
        // v1, v2 contenaient des donnees de demo : on repart d'une base neuve.
        if (oldV < 3) {
          await _dropAll(db);
          for (final sql in Schema.tables) {
            await db.execute(sql);
          }
          await SeedData.run(db);
          return;
        }
        // v3 et plus : migrations incrementales, les donnees sont conservees.
        for (var v = oldV + 1; v <= newV; v++) {
          for (final sql in Schema.migrations[v] ?? const <String>[]) {
            await db.execute(sql);
          }
        }
      },
    );
  }

  /// Supprime toutes les tables. onUpgrade s'execute dans une transaction,
  /// ou "PRAGMA foreign_keys = OFF" est sans effet : on supprime donc
  /// d'abord les tables qui referencent les autres (enfants avant parents).
  static Future<void> _dropAll(Database db) async {
    final rows = await db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'");
    final remaining = {for (final r in rows) r['name'] as String: (r['sql'] as String? ?? '')};
    while (remaining.isNotEmpty) {
      // Tables qu'aucune autre table restante ne reference
      final free = remaining.keys
          .where((t) => !remaining.entries
              .any((e) => e.key != t && e.value.contains('REFERENCES $t(')))
          .toList();
      for (final t in free.isEmpty ? remaining.keys.toList() : free) {
        await db.execute('DROP TABLE IF EXISTS $t');
        remaining.remove(t);
      }
    }
  }

  /// Outil de dev : efface tout et recree la base (donnees de depart).
  static Future<void> reset() async {
    final path = join(await getDatabasesPath(), _fileName);
    await _db?.close();
    _db = null;
    await deleteDatabase(path);
    await db; // recree
  }
}
