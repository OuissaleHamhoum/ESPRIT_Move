import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Pastille ronde rouge avec l'initiale du nom.
class Avatar extends StatelessWidget {
  final String name;
  final double radius;
  const Avatar({super.key, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.red,
      child: Text(initial,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius)),
    );
  }
}
