import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/config/api_constants.dart';

void main() {
  group('ApiConstants & Cascade Suite', () {
    test('Verifica que el modelo primario sea gemini-3.8-flash y los respaldos sean oficiales', () {
      expect(ApiConstants.geminiPrimaryModel, equals('gemini-3.8-flash'));
      expect(ApiConstants.geminiFallbackModelFast, equals('gemini-3.1-flash-lite'));
      expect(ApiConstants.geminiFallbackModelStable, equals('gemini-3.6-flash'));

      expect(ApiConstants.cascadeModels.length, equals(3));
      expect(ApiConstants.cascadeModels[0], equals('gemini-3.8-flash'));
      expect(ApiConstants.cascadeModels[1], equals('gemini-3.1-flash-lite'));
      expect(ApiConstants.cascadeModels[2], equals('gemini-3.6-flash'));
    });

    test('Verifica que el tiempo de espera (timeout) sea generoso (>= 90 segundos)', () {
      expect(ApiConstants.aiTimeoutSeconds, greaterThanOrEqualTo(90));
    });
  });

  group('JSON Sanitizer Edge Cases', () {
    String sanitizeResponse(String rawText) {
      String clean = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final firstBrace = clean.indexOf('{');
      final lastBrace = clean.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        clean = clean.substring(firstBrace, lastBrace + 1);
      }
      return clean;
    }

    test('Limpia correctamente markdown json con texto previo y posterior', () {
      const raw = '''
Aquí tienes la información extraída de la factura:
```json
{
  "proveedor_detectado": "DISTRIBUIDORA NAVARRETE S.A.",
  "items": [
    {
      "descripcion_detectada": "CUADERNO STANDFORD 100 HJS",
      "cantidad_ump_comprada": 12.0
    }
  ]
}
```
Espero que esta información te sea de utilidad.
''';

      final clean = sanitizeResponse(raw);
      expect(clean.startsWith('{'), isTrue);
      expect(clean.endsWith('}'), isTrue);

      final decoded = json.decode(clean) as Map<String, dynamic>;
      expect(decoded['proveedor_detectado'], equals("DISTRIBUIDORA NAVARRETE S.A."));
      expect((decoded['items'] as List).length, equals(1));
    });

    test('Sanitiza JSON crudo sin bloques markdown', () {
      const raw = '{"metadata": {"institution_name": "Colegio San Agustín"}, "items": []}';
      final clean = sanitizeResponse(raw);
      final decoded = json.decode(clean) as Map<String, dynamic>;
      expect(decoded['metadata']['institution_name'], equals("Colegio San Agustín"));
    });

    test('Limpia comas sobrantes (trailing commas) que los LLMs suelen generar antes de } o ]', () {
      const rawWithTrailingCommas = '''
      {
        "items": [
          {"id": 1, "nombre": "Borrador",},
          {"id": 2, "nombre": "Tajador",},
        ],
        "total": 15.5,
      }
      ''';
      String sanitizeWithTrailing(String raw) {
        String clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
        final firstBrace = clean.indexOf('{');
        final lastBrace = clean.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
          clean = clean.substring(firstBrace, lastBrace + 1);
        }
        clean = clean.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m.group(1)!);
        return clean;
      }

      final clean = sanitizeWithTrailing(rawWithTrailingCommas);
      final decoded = json.decode(clean) as Map<String, dynamic>;
      expect(decoded['items'].length, equals(2));
      expect(decoded['total'], equals(15.5));
    });
  });

  group('ScanningDialog Step Mapping Logic', () {
    int calculateStep(String text) {
      final lower = text.toLowerCase();
      if (lower.contains('optimizando') ||
          lower.contains('nitidez') ||
          lower.contains('resolución') ||
          lower.contains('preparando')) {
        return 0;
      }
      if (lower.contains('conectando') ||
          lower.contains('agente') ||
          lower.contains('gemini') ||
          lower.contains('inteligencia') ||
          lower.contains('reintentando') ||
          lower.contains('conmutando') ||
          lower.contains('servidor') ||
          lower.contains('límite')) {
        return 1;
      }
      if (lower.contains('leyendo') ||
          lower.contains('analizando') ||
          lower.contains('deduciendo') ||
          lower.contains('empaques') ||
          lower.contains('lotes') ||
          lower.contains('fracciones') ||
          lower.contains('cálculos')) {
        return 2;
      }
      if (lower.contains('estructurando') ||
          lower.contains('extrayendo') ||
          lower.contains('catálogo') ||
          lower.contains('casi listo') ||
          lower.contains('finalizando')) {
        return 3;
      }
      return 1;
    }

    test('Asigna pasos correctamente según el ciclo narrativo', () {
      expect(calculateStep("Optimizando nitidez y resolución del comprobante..."), equals(0));
      expect(calculateStep("Conectando con Agente IA (Gemini 3.8 Flash)..."), equals(1));
      expect(calculateStep("Servidor ocupado. Conmutando a agente en alta velocidad..."), equals(1));
      expect(calculateStep("Límite temporal alcanzado. Conmutando al agente de respaldo..."), equals(1));
      expect(calculateStep("Leyendo detalle de productos, códigos y precios..."), equals(2));
      expect(calculateStep("Deduciendo empaques, fracciones y cálculos contables..."), equals(2));
      expect(calculateStep("Estructurando catálogo con máxima precisión..."), equals(3));
      expect(calculateStep("Extrayendo datos, casi listo..."), equals(3));
    });
  });
}
