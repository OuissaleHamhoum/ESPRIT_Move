import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Acces au GPS (package geolocator) : permission + suivi de position.
/// Fonctionne sur Android, iOS, macOS, Windows et le navigateur.
class LocationService {
  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Demande la permission si besoin. Retourne null si tout est OK,
  /// sinon un message d'erreur a afficher a l'utilisateur.
  static Future<String?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Activez la localisation (GPS) de l’appareil.';
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied) {
      return 'Permission de localisation refusée.';
    }
    if (p == LocationPermission.deniedForever) {
      return 'Localisation bloquée : autorisez-la dans les réglages.';
    }
    return null;
  }

  /// Android 13+ : la notification du suivi en arriere-plan doit etre autorisee
  /// pour etre visible. Un refus n'empeche pas l'enregistrement.
  static Future<void> ensureNotificationPermission() async {
    if (_isAndroid) await ph.Permission.notification.request();
  }

  /// Flux de positions (1 point par seconde environ, sans filtre de distance :
  /// le tri est fait par TrackRecorder).
  ///
  /// Sur Android, [background] lance un service de premier plan avec une
  /// notification : le suivi continue ecran verrouille ou app en arriere-plan.
  static Stream<Position> track({bool background = false}) {
    final LocationSettings settings = _isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 1),
            useMSLAltitude: true,
            foregroundNotificationConfig: background
                ? const ForegroundNotificationConfig(
                    notificationTitle: 'ESPRIT Move enregistre votre sortie',
                    notificationText: 'Suivi GPS en cours. Touchez pour revenir.',
                    notificationChannelName: 'Enregistrement des sorties',
                    enableWakeLock: true,
                    setOngoing: true,
                  )
                : null,
          )
        : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
