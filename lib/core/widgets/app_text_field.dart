import 'package:flutter/material.dart';

/// Champ de formulaire avec son libelle au-dessus (comme les maquettes).
/// A mettre dans un Form(key: _formKey) : le message d'erreur du validator
/// s'affiche en rouge sous le champ.
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? hint;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.hint,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            validator: validator,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          ),
        ],
      ),
    );
  }

  /// Validator pret a l'emploi : champ obligatoire.
  static String? notEmpty(String? v, [String msg = 'Champ obligatoire']) =>
      (v == null || v.trim().isEmpty) ? msg : null;
}
