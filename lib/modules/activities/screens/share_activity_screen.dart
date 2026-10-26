import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snack.dart';
import '../data/share_service.dart';
import '../models/activity.dart';
import '../widgets/route_view.dart';

/// Apercu de la carte de partage : l'utilisateur choisit d'inclure ou non le
/// trace et une photo, voit le resultat, puis ouvre la feuille de partage.
class ShareActivityScreen extends StatefulWidget {
  final Activity activity;
  const ShareActivityScreen({super.key, required this.activity});

  @override
  State<ShareActivityScreen> createState() => _ShareActivityScreenState();
}

class _ShareActivityScreenState extends State<ShareActivityScreen> {
  final _cardKey = GlobalKey();
  late bool _withRoute = widget.activity.route.length >= 2;
  String? _photo; // null = sans photo (choix par defaut)
  bool _sharing = false;

  Activity get _a => widget.activity;

  String get _text {
    final pace = _a.avgPaceSecPerKm;
    return '${ActivityTypes.iconOf(_a.type)} ${_a.type} · ${_a.distanceKm.toStringAsFixed(2)} km'
        ' en ${Fmt.clock(_a.movingS ?? _a.durationMin * 60)}'
        '${pace == null ? '' : ' (${Fmt.paceSec(pace)} /km)'} · ESPRIT Move';
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await ShareService.shareCard(boundary, _text);
    } catch (_) {
      if (mounted) AppSnack.show(context, 'Partage impossible.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partager')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Aperçu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RepaintBoundary(key: _cardKey, child: _card()),
          const SizedBox(height: 12),
          if (_a.route.length >= 2)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.red,
              title: const Text('Inclure le tracé'),
              value: _withRoute,
              onChanged: (v) => setState(() => _withRoute = v),
            ),
          if (_a.photos.isNotEmpty) ...[
            Text('Photo', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            SizedBox(
              height: 64,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _photoChoice(null),
                for (final ph in _a.photos) _photoChoice(ph),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          AppButton(
              label: 'Partager', icon: Icons.ios_share, loading: _sharing, onPressed: _share),
          const SizedBox(height: 8),
          Text('Vous choisirez l’application (Instagram, WhatsApp, Facebook…) '
              'et validerez la publication.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _photoChoice(String? path) {
    final on = _photo == path;
    return GestureDetector(
      onTap: () => setState(() => _photo = path),
      child: Container(
        width: 64,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppColors.red : Colors.transparent, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: path == null
            ? const Center(child: Text('Aucune', style: TextStyle(fontSize: 11)))
            : Image.file(File(path), fit: BoxFit.cover, cacheWidth: 192),
      ),
    );
  }

  /// La carte exportee en image (format portrait, lisible en story).
  Widget _card() {
    final a = _a;
    const white70 = TextStyle(color: Colors.white70, fontSize: 12);
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.red, AppColors.darkBg]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${ActivityTypes.iconOf(a.type)} ${a.type}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            const Text.rich(TextSpan(children: [
              TextSpan(text: 'ESPRIT ', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Move', style: TextStyle(color: Colors.white70)),
            ]), style: TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Row(children: [
              if (_photo != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_photo!), fit: BoxFit.cover, height: double.infinity),
                  ),
                ),
              if (_photo != null && _withRoute) const SizedBox(width: 10),
              if (_withRoute)
                Expanded(child: RouteView(route: a.route, color: Colors.white)),
              if (_photo == null && !_withRoute)
                const Expanded(
                    child: Center(
                        child: Text('Bravo ! 💪',
                            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)))),
            ]),
          ),
          const SizedBox(height: 12),
          Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(Fmt.shortDate(a.date), style: white70),
          const SizedBox(height: 10),
          Row(children: [
            _big(a.distanceKm.toStringAsFixed(2), 'km'),
            _big(Fmt.clock(a.movingS ?? a.durationMin * 60), 'durée'),
            _big(Fmt.paceSec(a.avgPaceSecPerKm), 'allure /km'),
          ]),
        ]),
      ),
    );
  }

  Widget _big(String v, String label) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}
