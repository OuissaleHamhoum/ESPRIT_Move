import 'package:sqflite/sqflite.dart';
import '../utils/format.dart';
import '../utils/security.dart';

/// Donnees de demonstration inserees a la creation de la base.
/// Elles permettent a chaque membre de tester son module SEUL,
/// sans attendre le travail des autres.
///
/// COMPTES DE TEST :
///   Etudiant : mariem@esprit.tn  / 123456   (id = 1)
///   Admin    : admin@esprit.tn   / admin123 (id = 2)
class SeedData {
  static Future<void> run(Database db) async {
    final now = DateTime.now();
    String inDays(int n) => Fmt.dbDate(now.add(Duration(days: n)));

    // ---- Utilisateurs ----
    await db.insert('users', {
      'name': 'Mariem Ben Ali',
      'email': 'mariem@esprit.tn',
      'password_hash': Security.hash('123456'),
      'city': 'Tunis',
      'campus': 'Campus Ghazela',
      'card_number': 'ESP-482913',
      'filiere': 'Informatique',
      'card_verified': 1,
      'interests': 'Running,Football,Yoga',
      'role': 'student',
      'points': 1235,
      'created_at': now.toIso8601String(),
    });
    await db.insert('users', {
      'name': 'Administrateur',
      'email': 'admin@esprit.tn',
      'password_hash': Security.hash('admin123'),
      'city': 'Tunis',
      'campus': 'Campus Charguia',
      'card_number': 'ESP-000001',
      'filiere': 'Administration',
      'card_verified': 1,
      'interests': 'Muscu',
      'role': 'admin',
      'points': 0,
      'created_at': now.toIso8601String(),
    });
    // Quelques autres etudiants (pour le classement et le chat)
    for (final n in ['Sara Ben Salah', 'Yassine Trabelsi', 'Amine Gharbi']) {
      await db.insert('users', {
        'name': n,
        'email': '${n.split(' ').first.toLowerCase()}@esprit.tn',
        'password_hash': Security.hash('123456'),
        'city': 'Tunis',
        'card_verified': 1,
        'role': 'student',
        'created_at': now.toIso8601String(),
      });
    }

    // ---- Lieux du campus (communs events + booking) ----
    final places = <String, List<double>>{
      'Stade ESPRIT': [0.30, 0.35],
      'Terrain basket': [0.70, 0.30],
      'Gymnase': [0.55, 0.65],
      'Piste athlétisme': [0.20, 0.75],
      'Parvis Bibliothèque': [0.80, 0.70],
    };
    final placeId = <String, int>{};
    for (final e in places.entries) {
      placeId[e.key] = await db
          .insert('places', {'name': e.key, 'x': e.value[0], 'y': e.value[1]});
    }

    // ---- Installations (module 4) ----
    final facilities = [
      ['Terrain de football', 'Stade ESPRIT', '⚽'],
      ['Court de basket', 'Terrain basket', '🏀'],
      ['Salle de musculation', 'Gymnase', '🏋️'],
      ['Piste d’athlétisme', 'Piste athlétisme', '🏃'],
    ];
    for (final f in facilities) {
      await db.insert('facilities',
          {'name': f[0], 'place_id': placeId[f[1]], 'icon': f[2]});
    }

    // ---- Groupes (module 3) ----
    final groups = [
      ['Running Club', '🏃', 128],
      ['Basket ESPRIT', '🏀', 84],
      ['Yoga & Bien-être', '🧘', 61],
      ['Foot Campus', '⚽', 152],
      ['Cyclistes', '🚴', 47],
    ];
    for (final g in groups) {
      await db.insert('campus_groups',
          {'name': g[0], 'icon': g[1], 'base_members': g[2]});
    }
    await db.insert('group_members', {'group_id': 1, 'user_id': 1});

    // ---- Evenements (module 3) ----
    final events = [
      ['Run Club du jeudi', 'Course', 'Stade ESPRIT', inDays(2), '17:30', 30,
          '5 km tranquille, tous niveaux.'],
      ['Tournoi 3x3 Basket', 'Basket', 'Terrain basket', inDays(4), '15:00', 24,
          'Tournoi par équipes de 3.'],
      ['Yoga sur le parvis', 'Yoga', 'Parvis Bibliothèque', inDays(5), '12:30',
          15, 'Séance de yoga en plein air.'],
    ];
    for (final e in events) {
      await db.insert('events', {
        'title': e[0], 'sport': e[1], 'place_id': placeId[e[2]],
        'date': e[3], 'time': e[4], 'capacity': e[5], 'description': e[6],
        'organizer_id': 2, 'status': 'active',
      });
    }
    await db.insert('event_participants', {'event_id': 1, 'user_id': 1});

    // ---- Salons de chat (module 2) ----
    await db.insert('rooms', {'name': 'Général campus', 'icon': '💬'});
    await db.insert('rooms', {'name': 'Running Club', 'icon': '🏃'});
    await db.insert('rooms', {'name': 'Basket', 'icon': '🏀'});
    await db.insert('messages', {
      'room_id': 2, 'user_id': 3, 'text': 'RDV 17h30 au stade !',
      'created_at': now.toIso8601String(),
    });

    // ---- Activites (module 1) ----
    final acts = [
      ['Course', '10K du campus', 10.1, 58, 0],
      ['Course', 'Footing du matin', 6.0, 31, 2],
      ['Vélo', 'Sortie vélo Ariana', 18.4, 56, 4],
    ];
    for (final a in acts) {
      await db.insert('activities', {
        'user_id': 1, 'type': a[0], 'title': a[1], 'distance_km': a[2],
        'duration_min': a[3], 'notes': '', 'date': inDays(-(a[4] as int)),
      });
    }
    // Activites des autres etudiants (pour le classement)
    await db.insert('activities', {
      'user_id': 3, 'type': 'Course', 'title': 'Sortie 10K',
      'distance_km': 42.0, 'duration_min': 240, 'date': inDays(-1),
    });
    await db.insert('activities', {
      'user_id': 4, 'type': 'Course', 'title': 'Footing',
      'distance_km': 35.0, 'duration_min': 200, 'date': inDays(-2),
    });
    await db.insert('activities', {
      'user_id': 5, 'type': 'Vélo', 'title': 'Vélo',
      'distance_km': 20.0, 'duration_min': 70, 'date': inDays(-2),
    });

    // ---- Defis, badges, recompenses (module 5) ----
    await db.insert('challenges', {
      'title': '100 km en octobre', 'measure': 'km', 'goal': 100,
      'duration_days': 30,
    });
    await db.insert('challenges', {
      'title': '5 séances cette semaine', 'measure': 'seances', 'goal': 5,
      'duration_days': 7,
    });
    for (final uid in [1, 3, 4, 5]) {
      await db.insert('challenge_participants',
          {'challenge_id': 1, 'user_id': uid});
    }
    await db.insert('badges',
        {'name': 'Premier 10K', 'icon': '🥇', 'rule': 'distance', 'threshold': 10});
    await db.insert('badges',
        {'name': 'Régulier', 'icon': '🔥', 'rule': 'activities', 'threshold': 3});
    await db.insert('badges', {
      'name': 'Esprit d’équipe', 'icon': '🤝', 'rule': 'events', 'threshold': 20,
    });
    await db.insert('rewards', {'name': 'Café offert (cafétéria)', 'icon': '☕', 'cost': 200});
    await db.insert('rewards', {'name': 'Gourde ESPRIT Move', 'icon': '💧', 'cost': 500});
    await db.insert('rewards', {'name': 'T-shirt officiel', 'icon': '👕', 'cost': 800});
    await db.insert('rewards', {'name': '1 mois de salle', 'icon': '🏋️', 'cost': 1500});
  }
}
