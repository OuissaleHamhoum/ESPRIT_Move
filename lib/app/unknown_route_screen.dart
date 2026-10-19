import 'package:flutter/material.dart';
import '../core/widgets/empty_state.dart';

/// Affiche quand on navigue vers une route d'un module pas encore integre.
/// Permet a chacun de tester SON module seul sans plantage.
class UnknownRouteScreen extends StatelessWidget {
  final String? routeName;
  const UnknownRouteScreen({super.key, this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Écran non intégré')),
      body: EmptyState(
        emoji: '🚧',
        message: 'La route "$routeName" appartient à un autre module.\n'
            'Elle sera disponible après l\'intégration.',
        buttonLabel: 'Retour',
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}
