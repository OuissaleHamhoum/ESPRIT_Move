import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import 'cached_tile_provider.dart';

/// Carte OpenStreetMap (gratuite, sans cle d'API) avec le trace GPS reel :
/// depart vert, trace rouge, arrivee en damier, position actuelle en bleu.
///
/// - [live] : la camera suit [current] (ecran d'enregistrement).
/// - sinon : la camera cadre tout le parcours (recap, detail).
/// Hors connexion, les tuiles ne chargent pas mais le trace reste dessine.
class ActivityMap extends StatefulWidget {
  final List<List<double>> route;
  final LatLng? current;
  final bool live;
  const ActivityMap({super.key, required this.route, this.current, this.live = false});

  @override
  State<ActivityMap> createState() => _ActivityMapState();
}

class _ActivityMapState extends State<ActivityMap> {
  static final _tiles = CachedTileProvider(); // partage par toutes les cartes
  final _controller = MapController();
  bool _follow = true; // desactive des que l'utilisateur deplace la carte
  bool _ready = false;
  late List<LatLng> _points = _toLatLng(widget.route);

  static List<LatLng> _toLatLng(List<List<double>> r) => [for (final p in r) LatLng(p[0], p[1])];

  @override
  void didUpdateWidget(ActivityMap old) {
    super.didUpdateWidget(old);
    // Le trace ne fait que s'allonger : on convertit seulement les nouveaux points.
    if (widget.route.length != _points.length) {
      _points = widget.route.length > _points.length
          ? [..._points, ..._toLatLng(widget.route.sublist(_points.length))]
          : _toLatLng(widget.route);
    }
    final c = widget.current;
    if (widget.live && _follow && _ready && c != null && c != old.current) {
      _controller.move(c, _controller.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.current ?? (_points.isEmpty ? null : _points.last);
    if (center == null) {
      return Center(
          child: Text(widget.live ? '📡 Recherche du signal GPS…' : '🗺️  Aucun tracé GPS pour cette sortie',
              style: Theme.of(context).textTheme.bodySmall));
    }
    final fit = !widget.live && _points.length >= 2;
    return Stack(children: [
      FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 16,
          initialCameraFit: fit
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(_points), padding: const EdgeInsets.all(32))
              : null,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onMapReady: () => _ready = true,
          onPositionChanged: (_, hasGesture) {
            if (hasGesture && _follow && widget.live) setState(() => _follow = false);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'tn.esprit.esprit_move',
            tileProvider: _tiles,
            // mode sombre : tuiles assombries, le trace rouge reste lisible
            tileBuilder: Theme.of(context).brightness == Brightness.dark ? darkModeTileBuilder : null,
          ),
          if (_points.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points: _points,
                strokeWidth: 5,
                color: AppColors.red,
                borderStrokeWidth: 1.5,
                borderColor: Colors.white,
              ),
            ]),
          MarkerLayer(markers: [
            if (_points.isNotEmpty) _dot(_points.first, AppColors.green),
            if (!widget.live && _points.length >= 2) _finish(_points.last),
            if (widget.current != null) _dot(widget.current!, const Color(0xFF1E88E5), size: 18),
          ]),
          const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
        ],
      ),
      if (widget.live && !_follow && widget.current != null)
        Positioned(
          right: 8,
          bottom: 36,
          child: FloatingActionButton.small(
            heroTag: null,
            backgroundColor: Colors.white,
            onPressed: () {
              setState(() => _follow = true);
              _controller.move(widget.current!, _controller.camera.zoom);
            },
            child: const Icon(Icons.my_location, color: AppColors.red),
          ),
        ),
    ]);
  }

  Marker _dot(LatLng p, Color c, {double size = 14}) => Marker(
        point: p,
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black38)],
          ),
        ),
      );

  Marker _finish(LatLng p) => Marker(
        point: p,
        width: 22,
        height: 22,
        child: const DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(Icons.sports_score, size: 18, color: Colors.black),
        ),
      );
}
