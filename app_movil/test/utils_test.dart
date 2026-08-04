import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/providers/catalog_provider.dart';

void main() {
  group('Utils Tests', () {
    test('normalizeText should remove accents and lowercase', () {
      final String input1 = 'CAFÉ';
      final String input2 = 'Árbol Mágico';
      final String input3 = 'niño';

      expect(normalizeText(input1), 'cafe');
      expect(normalizeText(input2), 'arbol magico');
      expect(normalizeText(input3), 'nino');
    });

    test('normalizeText should trim whitespace', () {
      final String input = '  Hola Mundo  ';
      expect(normalizeText(input), 'hola mundo');
    });

    test('normalizeText should handle empty strings', () {
      expect(normalizeText(''), '');
      expect(normalizeText('   '), '');
    });
  });
}
