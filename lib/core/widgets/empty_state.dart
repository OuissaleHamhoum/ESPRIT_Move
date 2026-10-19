import 'package:flutter/material.dart';
import 'app_button.dart';

/// Etat vide : pictogramme + phrase + bouton d'action (PDF section 11).
class EmptyState extends StatelessWidget {
  final String emoji;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const EmptyState({
    super.key,
    required this.message,
    this.emoji = '📭',
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            if (buttonLabel != null) ...[
              const SizedBox(height: 16),
              AppButton(label: buttonLabel!, onPressed: onPressed),
            ],
          ],
        ),
      ),
    );
  }
}
