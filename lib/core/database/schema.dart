/// ============================================================
///  SCHEMA SQLite DE TOUTE L'APPLICATION (toutes les tables)
/// ============================================================
/// REGLE D'EQUIPE : chaque membre ne modifie QUE la section de son module.
/// Si vous ajoutez une colonne : augmentez `dbVersion` dans app_database.dart,
/// prevenez le chef d'equipe, puis desinstallez l'app du telephone
/// (ou appelez AppDatabase.reset()) pour recreer la base.
class Schema {
  static const List<String> tables = [
    // ---------------- MODULE 2 : Utilisateurs, profil, chat ----------------
    '''
    CREATE TABLE users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      city TEXT DEFAULT '',
      campus TEXT DEFAULT '',
      card_number TEXT DEFAULT '',
      filiere TEXT DEFAULT '',
      card_verified INTEGER DEFAULT 0,      -- 1 = carte etudiante verifiee
      interests TEXT DEFAULT '',            -- "Running,Football,Yoga"
      role TEXT DEFAULT 'student',          -- 'student' ou 'admin'
      points INTEGER DEFAULT 0,
      beacon_active INTEGER DEFAULT 0,      -- 1 = partage de position actif
      created_at TEXT NOT NULL
    )''',
    // 3 contacts maximum par utilisateur (regle verifiee dans UserDao)
    '''
    CREATE TABLE beacon_contacts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      phone TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE rooms(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon TEXT DEFAULT '💬'
    )''',
    '''
    CREATE TABLE messages(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      text TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY(room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''',

    // ---------------- COMMUN modules 3 et 4 : lieux du campus ----------------
    // x et y = position de l'epingle sur le plan (valeurs entre 0.0 et 1.0)
    '''
    CREATE TABLE places(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      x REAL DEFAULT 0.5,
      y REAL DEFAULT 0.5
    )''',

    // ---------------- MODULE 1 : Activites ----------------
    '''
    CREATE TABLE activities(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      type TEXT NOT NULL,                   -- Course, Vélo, Marche, Muscu, Football, Natation
      title TEXT NOT NULL,
      distance_km REAL DEFAULT 0,
      duration_min INTEGER DEFAULT 0,
      notes TEXT DEFAULT '',
      date TEXT NOT NULL,                   -- yyyy-MM-dd
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''',

    // ---------------- MODULE 3 : Evenements et groupes ----------------
    '''
    CREATE TABLE events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      sport TEXT NOT NULL,
      place_id INTEGER NOT NULL,
      date TEXT NOT NULL,                   -- yyyy-MM-dd
      time TEXT NOT NULL,                   -- HH:mm
      capacity INTEGER NOT NULL,
      description TEXT DEFAULT '',
      organizer_id INTEGER NOT NULL,
      status TEXT DEFAULT 'active',         -- 'active' ou 'cancelled'
      FOREIGN KEY(place_id) REFERENCES places(id),
      FOREIGN KEY(organizer_id) REFERENCES users(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE event_participants(
      event_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      PRIMARY KEY(event_id, user_id),
      FOREIGN KEY(event_id) REFERENCES events(id) ON DELETE CASCADE,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE campus_groups(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon TEXT DEFAULT '🏃',
      base_members INTEGER DEFAULT 0        -- membres "deja inscrits" (demo)
    )''',
    '''
    CREATE TABLE group_members(
      group_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      PRIMARY KEY(group_id, user_id),
      FOREIGN KEY(group_id) REFERENCES campus_groups(id) ON DELETE CASCADE,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''',

    // ---------------- MODULE 4 : Reservation des installations ----------------
    '''
    CREATE TABLE facilities(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      place_id INTEGER NOT NULL,
      icon TEXT DEFAULT '🏟️',
      FOREIGN KEY(place_id) REFERENCES places(id)
    )''',
    '''
    CREATE TABLE bookings(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      facility_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      date TEXT NOT NULL,                   -- yyyy-MM-dd
      slot TEXT NOT NULL,                   -- "08:00" (creneaux de 2 h)
      status TEXT DEFAULT 'confirmed',
      FOREIGN KEY(facility_id) REFERENCES facilities(id),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''',

    // ---------------- MODULE 5 : Defis, badges, recompenses ----------------
    '''
    CREATE TABLE challenges(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      measure TEXT NOT NULL,                -- 'km', 'seances' ou 'minutes'
      goal REAL NOT NULL,
      duration_days INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE challenge_participants(
      challenge_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      PRIMARY KEY(challenge_id, user_id),
      FOREIGN KEY(challenge_id) REFERENCES challenges(id) ON DELETE CASCADE,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE badges(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon TEXT DEFAULT '🏅',
      rule TEXT NOT NULL,                   -- 'distance', 'activities' ou 'events'
      threshold REAL NOT NULL
    )''',
    '''
    CREATE TABLE user_badges(
      user_id INTEGER NOT NULL,
      badge_id INTEGER NOT NULL,
      earned_at TEXT NOT NULL,
      PRIMARY KEY(user_id, badge_id),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY(badge_id) REFERENCES badges(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE rewards(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon TEXT DEFAULT '🎁',
      cost INTEGER NOT NULL
    )''',
  ];
}
