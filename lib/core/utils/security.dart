import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Hachage des mots de passe : on ne stocke JAMAIS le mot de passe en clair.
class Security {
  /// "123456" -> "8d969eef6ecad3c29a3a629280e686cf..." (sha256)
  static String hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();
}
