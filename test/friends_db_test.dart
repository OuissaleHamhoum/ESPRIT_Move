import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:esprit_move/core/database/app_database.dart';
import 'package:esprit_move/modules/activities/data/activity_dao.dart';
import 'package:esprit_move/modules/activities/data/friend_dao.dart';
import 'package:esprit_move/modules/activities/models/activity.dart';

// Vraie base SQLite (moteur FFI du PC) : migration v3 -> v5 et amis.
void main() {
  late String path;

  setUpAll(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows; // AppDatabase -> FFI
    sqfliteFfiInit();
    path = p.join(await databaseFactoryFfi.getDatabasesPath(), 'esprit_move.db');
    await databaseFactoryFfi.deleteDatabase(path);
  });

  tearDownAll(() => debugDefaultTargetPlatformOverride = null);

  Future<int> user(Database db, String name) => db.insert('users', {
        'name': name,
        'email': '${name.toLowerCase()}@esprit.tn',
        'password_hash': 'x',
        'created_at': DateTime.now().toIso8601String(),
      });

  test('migration v3 -> v5 : les sorties existantes sont conservees', () async {
    // Base "ancienne version" : schema v3 de la table activities
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
                'email TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, role TEXT DEFAULT \'student\', '
                'points INTEGER DEFAULT 0, beacon_active INTEGER DEFAULT 0, created_at TEXT NOT NULL)');
            await db.execute('CREATE TABLE notifications(id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'user_id INTEGER NOT NULL, text TEXT NOT NULL, created_at TEXT NOT NULL, is_read INTEGER DEFAULT 0)');
            await db.execute('CREATE TABLE activities(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, '
                'type TEXT NOT NULL, title TEXT NOT NULL, distance_km REAL DEFAULT 0, duration_min INTEGER DEFAULT 0, '
                "notes TEXT DEFAULT '', date TEXT NOT NULL, route TEXT DEFAULT '', "
                'FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)');
          },
        ));
    final uid = await user(old, 'Ancien');
    await old.insert('activities', {
      'user_id': uid, 'type': 'Course', 'title': 'Sortie v3', 'date': '2026-09-01',
      'distance_km': 4.2, 'duration_min': 21, 'route': '[[36.8,10.1],[36.81,10.1]]',
    });
    await old.close();

    final list = await ActivityDao.getByUser(uid); // ouvre la base en v5 -> migrations
    expect(list.single.title, 'Sortie v3');
    expect(list.single.distanceKm, 4.2);
    expect(list.single.shared, isTrue); // valeur par defaut de la nouvelle colonne
    final db = await AppDatabase.db;
    expect(await db.getVersion(), AppDatabase.dbVersion);
    expect((await FriendDao.visible(list.single.id!, uid))!.route.length, 2);
  });

  test('amis : demande, acceptation, fil et droits de lecture', () async {
    final db = await AppDatabase.db;
    final a = await user(db, 'Amine'), b = await user(db, 'Brahim'), c = await user(db, 'Chaima');

    // A cherche B et lui envoie une demande
    expect((await FriendDao.search(a, 'brah')).single.status, FriendStatus.none);
    await FriendDao.request(a, 'Amine', b);
    expect((await FriendDao.related(a)).single.status, FriendStatus.sent);
    expect((await FriendDao.related(b)).single.status, FriendStatus.received);

    // A publie une sortie partagee et une privee
    Future<int> post(String title, bool shared) => ActivityDao.insert(Activity(
        userId: a, type: 'Vélo', title: title, date: '2026-10-25', distanceKm: 10,
        durationMin: 30, shared: shared));
    final pub = await post('Publique', true), priv = await post('Privée', false);

    // Pas encore amis : rien n'est visible
    expect(await FriendDao.feed(b), isEmpty);
    expect(await FriendDao.visible(pub, b), isNull);

    await FriendDao.accept(b, 'Brahim', a);
    expect((await FriendDao.related(a)).single.status, FriendStatus.friends);

    final feed = await FriendDao.feed(b);
    expect(feed.map((x) => x.title), ['Publique']); // la privee n'apparait pas
    expect(feed.single.authorName, 'Amine');
    expect((await FriendDao.visible(pub, b))!.title, 'Publique');
    expect(await FriendDao.visible(priv, b), isNull);
    expect(await FriendDao.visible(pub, c), isNull); // pas ami
    expect((await FriendDao.visible(priv, a))!.title, 'Privée'); // le proprietaire voit tout

    // Notifications : demande pour B, acceptation pour A
    final notes = await db.query('notifications', where: 'user_id IN (?, ?)', whereArgs: [a, b]);
    expect(notes.length, 2);

    // Demande croisee : C invite A, A invite C -> amis directement
    await FriendDao.request(c, 'Chaima', a);
    await FriendDao.request(a, 'Amine', c);
    expect((await FriendDao.related(c)).single.status, FriendStatus.friends);

    // Retirer un ami : le fil se vide
    await FriendDao.remove(b, a);
    expect(await FriendDao.feed(b), isEmpty);
    expect(await FriendDao.search(a, 'admin'), isEmpty); // l'admin n'est pas proposé
  });
}
