import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;
import 'schema.dart';
import 'seed_data.dart';

/// Ouvre (une seule fois) la base SQLite locale du telephone.
///
/// Le fichier "esprit_move.db" est cree automatiquement dans le stockage prive
/// de l'application : pas de serveur, pas d'internet, pas de configuration.
///
/// Utilisation dans n'importe quel DAO :
///   final db = await AppDatabase.db;
///   final rows = await db.query('activities');
class AppDatabase {
  /// Incrementer ce numero quand le schema change (voir schema.dart).
  static const int dbVersion = 1;
  static const String _fileName = 'esprit_move.db';

  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  /// Sur Android / iOS : sqflite fonctionne directement.
  /// Sur Windows / Linux / macOS (test sur PC) : on active le moteur FFI.
  /// Le navigateur (Chrome, Edge) n'est PAS supporte.
  static bool _factoryReady = false;
  static void _initFactory() {
    if (_factoryReady) return;
    _factoryReady = true;
    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
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
        await SeedData.run(db); // donnees de demonstration
      },
      // En developpement : on repart d'une base neuve si la version change.
      onUpgrade: (db, oldV, newV) async {
        await _dropAll(db);
        for (final sql in Schema.tables) {
          await db.execute(sql);
        }
        await SeedData.run(db);
      },
    );
  }

  static Future<void> _dropAll(Database db) async {
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'");
    await db.execute('PRAGMA foreign_keys = OFF');
    for (final t in tables) {
      await db.execute('DROP TABLE IF EXISTS ${t['name']}');
    }
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Outil de dev : efface tout et recree la base avec les donnees de demo.
  static Future<void> reset() async {
    final path = join(await getDatabasesPath(), _fileName);
    await _db?.close();
    _db = null;
    await deleteDatabase(path);
    await db; // recree
  }
}
