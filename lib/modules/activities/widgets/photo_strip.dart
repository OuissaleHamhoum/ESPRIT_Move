import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../data/photo_store.dart';

/// Photos d'une sortie : prendre une photo, choisir dans la galerie,
/// agrandir, retirer. [onChanged] recoit la nouvelle liste de chemins ;
/// null = lecture seule (sortie d'un ami).
class PhotoStrip extends StatelessWidget {
  final List<String> photos;
  final ValueChanged<List<String>>? onChanged;
  const PhotoStrip({super.key, required this.photos, required this.onChanged});

  bool get _editable => onChanged != null;

  Future<void> _add(BuildContext context, {required bool camera}) async {
    try {
      final path = await PhotoStore.pick(camera: camera);
      if (path != null) onChanged!([...photos, path]);
    } catch (_) {
      if (context.mounted) {
        AppSnack.show(
          context,
          camera ? 'Appareil photo indisponible.' : 'Galerie indisponible.',
        );
      }
    }
  }

  void _open(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            if (_editable)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onChanged!([...photos]..remove(path));
                  PhotoStore.deleteAll([path]);
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                label: const Text('Retirer la photo'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_editable)
                    _button(
                      Icons.photo_camera_outlined,
                      'Photo',
                      () => _add(context, camera: true),
                    ),
                  if (_editable)
                    _button(
                      Icons.photo_library_outlined,
                      'Galerie',
                      () => _add(context, camera: false),
                    ),
                  for (final path in photos)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _open(context, path),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(path),
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            cacheWidth: 252, // decode en petit : liste fluide
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 84,
                              height: 84,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: SizedBox(
      width: 84,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
