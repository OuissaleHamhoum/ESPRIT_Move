import 'package:flutter_test/flutter_test.dart';
import 'package:esprit_move/core/utils/format.dart';
import 'package:esprit_move/core/utils/security.dart';

// Tests simples (sans base de donnees) : flutter test
void main() {
  test('Fmt.pace = duree / distance', () {
    expect(Fmt.pace(10, 50), '5.0');
    expect(Fmt.pace(0, 50), '--');
  });

  test('Fmt.dbDate donne yyyy-MM-dd', () {
    expect(Fmt.dbDate(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('Security.hash est stable et different du mot de passe', () {
    expect(Security.hash('123456'), Security.hash('123456'));
    expect(Security.hash('123456'), isNot('123456'));
  });
}
