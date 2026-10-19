# ESPRIT Move : guide final (lancer le projet + téléphone + SQLite)

Application Flutter, base de données **SQLite locale** sur le téléphone (pas de serveur, pas d'internet).
Ce guide a été testé : le projet compile et s'installe sur un Samsung (Android 16).

---

## 1. Installation (une seule fois par PC)

1. **Flutter SDK** récent (version **3.44 ou plus**), par exemple dans `C:\src\flutter`. Ajouter `C:\src\flutter\bin` au PATH.
2. **Android Studio** (il installe le SDK Android). Au premier lancement, accepter les licences.
3. **Mode développeur Windows** : `start ms-settings:developers` puis l'activer.
4. Dans PowerShell :
   ```powershell
   flutter --version          # doit être >= 3.44
   flutter doctor             # tout doit être coché pour Android
   flutter doctor --android-licenses   # répondre y partout
   ```
5. **Internet obligatoire au premier lancement** : Gradle télécharge le NDK, CMake et le SDK Android (plusieurs Go, 15 à 25 minutes). Les lancements suivants prennent 1 à 2 minutes.

## 2. Ouvrir le projet

1. Dézipper `esprit_move.zip` dans un chemin **court, sans espaces ni parenthèses**, par exemple `C:\dev\esprit_move`.
2. Ouvrir PowerShell **dans le dossier qui contient `pubspec.yaml`** :
   ```powershell
   cd C:\dev\esprit_move
   ```
3. Télécharger les packages et vérifier le code :
   ```powershell
   flutter pub get
   flutter analyze        # doit afficher : No issues found!
   ```

## 3. Préparer le téléphone Android

1. *Paramètres → Informations sur le téléphone → Informations logiciel* : toucher **7 fois** « Numéro de build ».
2. *Paramètres → Options pour les développeurs* : activer **Débogage USB**.
3. Brancher avec un **câble de données** (pas un câble de charge seule).
4. Sur le téléphone, mode USB = **Transfert de fichiers**.
5. Accepter la fenêtre « Autoriser le débogage USB ? » (cocher « Toujours autoriser »).
6. Vérifier sur le PC :
   ```powershell
   flutter devices        # le téléphone doit apparaître (type : mobile)
   ```

## 4. Lancer l'application

```powershell
# Application complète
flutter run

# Si plusieurs appareils : choisir le téléphone avec son identifiant
flutter run -d <identifiant>

# Un seul module (travail en solo)
flutter run -t lib/dev/main_activities.dart
flutter run -t lib/dev/main_users.dart
flutter run -t lib/dev/main_events.dart
flutter run -t lib/dev/main_booking.dart
flutter run -t lib/dev/main_challenges.dart
```

Pendant l'exécution : `r` = hot reload, `R` = hot restart, `q` = quitter.
Test sans téléphone : `flutter run -d windows`. **Ne pas lancer sur Chrome/Edge** (SQLite ne marche pas sur le web).

**Comptes de test**

| Rôle | E-mail | Mot de passe |
|---|---|---|
| Étudiante | `mariem@esprit.tn` | `123456` |
| Administrateur | `admin@esprit.tn` | `admin123` |

## 5. Connexion à la base SQLite du téléphone

Rien à configurer. Au démarrage, `main.dart` appelle `AppDatabase.db` :

1. le fichier `esprit_move.db` est créé dans le stockage privé de l'application ;
2. les 17 tables sont créées (`lib/core/database/schema.dart`) ;
3. les données de démonstration sont insérées (`seed_data.dart`) ;
4. chaque DAO utilise `final db = await AppDatabase.db;` puis `query / insert / update / delete`.

Chaque téléphone a sa propre base.

### Voir le contenu de la base

**Méthode A : Android Studio (la plus simple)**
App lancée → *View → Tool Windows → App Inspection → Database Inspector* → choisir `esprit_move.db`. On voit les tables et on peut lancer du SQL.

**Méthode B : copier le fichier sur le PC**
```powershell
adb exec-out run-as tn.esprit.esprit_move cat databases/esprit_move.db > esprit_move.db
```
Ouvrir ensuite avec *DB Browser for SQLite*. (Fonctionne en mode debug.)

### Requêtes de vérification
```sql
SELECT id, name, email, role, points FROM users;
SELECT * FROM activities;
SELECT * FROM bookings;
SELECT name FROM sqlite_master WHERE type='table';   -- 17 tables
```
**Test de bout en bout :** dans l'app, enregistrer une sortie (bouton rouge → GO → Terminer → Enregistrer), puis relancer `SELECT * FROM activities` : la nouvelle ligne apparaît.

### Repartir d'une base neuve
Désinstaller l'app du téléphone, ou appeler une fois `await AppDatabase.reset();`.
Si le schéma change : modifier `schema.dart` et passer `dbVersion` de 1 à 2 dans `app_database.dart`.

## 6. Parcours à tester (référence : `ESPRIT_Move_Board_avec_Test.html`, bouton « ▶ Tester »)

- [ ] 1. Splash → 3 bienvenues → inscription en 5 étapes → accueil (+100 pts)
- [ ] 2. Bouton rouge → choix du sport → GO → 3-2-1 → pause/reprise → terminer → enregistrer → liste → détail
- [ ] 3. Événements : liste ↔ carte → détail → rejoindre → quitter (« Complet »)
- [ ] 4. Réserver un créneau → changer (l'ancien est libéré) → annuler
- [ ] 5. Défi : participer → classement → badge → certificat
- [ ] 6. Beacon : 3 contacts → activer (refusé sans contact)
- [ ] 7. Admin (`admin@esprit.tn`) : + Défi, + Badge, tableau de bord
- [ ] Modes clair et sombre (bouton dans le profil)

## 7. Problèmes rencontrés et solutions

| Message | Cause | Solution |
|---|---|---|
| `Waiting for another flutter command to release the startup lock` | Une autre commande Flutter tourne (Android Studio, VS Code, ancien `flutter run`) | `Ctrl+C`, fermer les IDE, `taskkill /F /IM dart.exe`, puis `Remove-Item C:\src\flutter\bin\cache\lockfile -Force` |
| `Timeout waiting to lock cache directory ... in use by another process` | Un Gradle resté ouvert | Dans le dossier `android` : `.\gradlew --stop`, puis `taskkill /F /IM java.exe`, puis relancer |
| `[CXX1101] NDK ... did not have a source.properties file` | NDK téléchargé de façon incomplète | `Remove-Item "$env:LOCALAPPDATA\Android\sdk\ndk\28.2.13676358" -Recurse -Force`, puis `flutter run` (il se re-télécharge) |
| Cadre « AGP 9+ / newDsl » | Message générique de Flutter quand le plugin Gradle échoue | Ignorer : le projet est déjà configuré (`android.newDsl=false`). Corriger l'erreur Gradle réelle affichée au-dessus |
| `flutter devices` ne voit pas le téléphone | Débogage USB, câble ou autorisation | Changer de câble, réactiver le débogage USB, accepter la fenêtre sur le téléphone, `adb kill-server` puis `adb start-server` |
| `no such table` / colonne inconnue | Schéma changé | Désinstaller l'app ou `AppDatabase.reset()` |
| Build très long | Premier téléchargement Gradle/NDK | Normal, attendre |
| Erreur de mémoire Gradle | `-Xmx8G` trop grand pour le PC | Dans `android/gradle.properties`, remplacer `-Xmx8G` par `-Xmx4G` |
| Bandeau jaune/noir « overflowed by N pixels » | Texte trop long dans un bouton | Corrigé dans `app_button.dart` ; en cas d'autre cas, entourer le texte d'un `Flexible` |
| Page blanche | Lancé sur Chrome/Edge | Lancer sur Android ou Windows |

## 8. Règles d'équipe (rappel)

1. Chaque membre travaille uniquement dans `lib/modules/<son_module>/`.
2. Fichiers partagés (`core/`, `app/`, `schema.dart`, `app_routes.dart`) : modifier seulement après accord du groupe.
3. Une branche Git par membre, *pull request* vers `main`.
4. Ne jamais importer un écran d'un autre module : utiliser `Navigator.pushNamed(context, AppRoutes.xxx)`.
5. Ne pas mettre dans Git : `build/`, `.dart_tool/`, `.idea/`, `android/local.properties`.
