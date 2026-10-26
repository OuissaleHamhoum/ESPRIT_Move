import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Histogramme simple (une serie) : une barre par periode, valeur au toucher,
/// seule la derniere periode (en cours) est etiquetee.
class BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String unit;
  const BarChart({super.key, required this.values, required this.labels, this.unit = 'km'});

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    final small = Theme.of(context).textTheme.bodySmall;
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Tooltip(
                message: '${labels[i]} : ${values[i].toStringAsFixed(1)} $unit',
                triggerMode: TooltipTriggerMode.tap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3), // espace entre barres
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (i == values.length - 1)
                      Text(values[i].toStringAsFixed(1),
                          style: small?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Container(
                      height: max <= 0 ? 0 : 100 * values[i] / max,
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: i == values.length - 1 ? 1 : 0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: AppColors.grey.withValues(alpha: 0.4)),
                    const SizedBox(height: 4),
                    Text(labels[i], style: small, maxLines: 1, overflow: TextOverflow.clip),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
