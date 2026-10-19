import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Pastilles selectionnables (sports, interets...).
/// Choix multiple : le parent ajoute/retire dans son Set.
/// Choix unique : le parent remplace son Set par {option}.
class ChipSelector extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  const ChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options.map((o) {
        final isOn = selected.contains(o);
        return ChoiceChip(
          label: Text(o),
          selected: isOn,
          selectedColor: AppColors.red,
          showCheckmark: false,
          labelStyle: TextStyle(color: isOn ? Colors.white : null),
          onSelected: (_) => onTap(o),
        );
      }).toList(),
    );
  }
}
