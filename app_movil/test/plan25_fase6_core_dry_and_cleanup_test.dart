import 'dart:io';

import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/whatsapp_uri_builder.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Directory _resolveAppMovilRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}${Platform.pathSeparator}pubspec.yaml').existsSync() &&
      Directory('${cwd.path}${Platform.pathSeparator}lib').existsSync()) {
    return cwd;
  }
  final nested = Directory('${cwd.path}${Platform.pathSeparator}app_movil');
  if (nested.existsSync() &&
      File('${nested.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
    return nested;
  }
  throw StateError('No se pudo localizar la raíz app_movil desde ${cwd.path}');
}

void main() {
  group('Plan 25 Fase 6 — WhatsAppUriBuilder (D-MOV-04)', () {
    test('normaliza teléfonos de Perú sin duplicar prefijo 51', () {
      expect(WhatsAppUriBuilder.normalizePeruWhatsAppPhone('987654321'), '51987654321');
      expect(WhatsAppUriBuilder.normalizePeruWhatsAppPhone('+51 987 654 321'), '51987654321');
      expect(WhatsAppUriBuilder.normalizePeruWhatsAppPhone('51987654321'), '51987654321');
      expect(WhatsAppUriBuilder.normalizePeruWhatsAppPhone('5151987654321'), '51987654321');
    });

    test('respeta teléfonos internacionales con + e invalida vacíos/ceros', () {
      expect(WhatsAppUriBuilder.normalizePeruWhatsAppPhone('+1 415 555 0101'), '14155550101');
      expect(WhatsAppUriBuilder.normalizePeruWhatsAppPhone(''), '');
      expect(WhatsAppUriBuilder.normalizePeruWhatsAppPhone('000000000'), '');
      expect(WhatsAppUriBuilder.normalizePeruWhatsAppPhone('12345'), '');
    });

    test('construye URI oficial https://wa.me con mensaje codificado y fallback', () {
      final uri = WhatsAppUriBuilder.buildSendUri(
        phone: '+51 922 836 879',
        message: 'Hola Perú!\nTotal: S/ 10.50',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/51922836879');
      expect(uri.queryParameters['text'], 'Hola Perú!\nTotal: S/ 10.50');

      final fallbackUri = WhatsAppUriBuilder.buildSendUri(
        phone: '',
        fallbackPhone: '987654321',
      );
      expect(fallbackUri.toString(), 'https://wa.me/51987654321');

      final openUri = WhatsAppUriBuilder.buildSendUri(phone: '   ');
      expect(openUri.toString(), 'https://wa.me/');
    });
  });

  group('Plan 25 Fase 6 — AppCurrency y AppDateFormatter (D-MOV-01 / D-MOV-02)', () {
    test('AppCurrency.format maneja cero, nulos, NaN, negativos y separador opcional', () {
      expect(AppCurrency.format(0), 'S/ 0.00');
      expect(AppCurrency.format(null), 'S/ 0.00');
      expect(AppCurrency.format(double.nan), 'S/ 0.00');
      expect(AppCurrency.format(double.infinity), 'S/ 0.00');
      expect(AppCurrency.format(1258.57), 'S/ 1,258.57');
      expect(AppCurrency.format(1258.57, includeThousandsSeparator: false), 'S/ 1258.57');
      expect(AppCurrency.format(1258.57, decimals: 0), 'S/ 1,259');
      expect(AppCurrency.format(-42.5, includeThousandsSeparator: false), '-S/ 42.50');
      expect(AppCurrency.format(-1250.5, decimals: 1), '-S/ 1,250.5');
    });

    test('AppDateFormatter cachea instancias DateFormat y formatea en español', () {
      expect(identical(AppDateFormatter.ddMMyyyy, AppDateFormatter.ddMMyyyy), isTrue);
      expect(identical(AppDateFormatter.ddMMyyyyHHmm, AppDateFormatter.ddMMyyyyHHmm), isTrue);

      final sample = DateTime(2026, 11, 25, 14, 30, 5);
      expect(AppDateFormatter.formatDate(sample), '25/11/2026');
      expect(AppDateFormatter.formatDateTime(sample), '25/11/2026 14:30');
      expect(AppDateFormatter.formatIsoDate(sample), '2026-11-25');
      expect(AppDateFormatter.formatTime24(sample), '14:30');
      expect(AppDateFormatter.formatFileTimestamp(sample), '20261125_143005');
      expect(AppDateFormatter.parseFileTimestamp('20261125_143005'), DateTime(2026, 11, 25, 14, 30, 5));

      expect(AppDateFormatter.formatDateSpanish(sample), '25 nov. 2026');
      expect(
        AppDateFormatter.formatDateSpanish(sample, includeTime: true),
        '25 nov. 2026 • 14:30',
      );
      final withWeekday = AppDateFormatter.formatDateSpanish(sample, includeWeekday: true);
      expect(withWeekday.startsWith('Mié'), isTrue);
      expect(withWeekday.contains('25/11/2026'), isTrue);
    });
  });

  group('Plan 25 Fase 6 — ClipboardHelper y AppFeedbackHelper (D-MOV-03 / D-MOV-05)', () {
    testWidgets('ClipboardHelper copia vía SystemChannels.platform y muestra SnackBar', (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          copiedText = args?['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ClipboardHelper.copyWithFeedback(
                        context,
                        'HWID-TEST-2026',
                        feedbackMessage: 'ID copiado unificado',
                        haptic: false,
                        useScaffoldSnackBar: true,
                      );
                    },
                    child: const Text('Copiar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AppFeedbackHelper.showSnackBar(
                        context,
                        'Aviso directo',
                      );
                    },
                    child: const Text('Aviso'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copiar'));
      await tester.pump();
      expect(copiedText, 'HWID-TEST-2026');
      expect(find.text('ID copiado unificado'), findsOneWidget);

      await tester.tap(find.text('Aviso'));
      await tester.pump();
      expect(find.text('Aviso directo'), findsOneWidget);
    });
  });

  group('Plan 25 Fase 6 — UniversalImage optimización de decodificación (D-MOV-06)', () {
    test('computeSafeCacheDimension protege contra NaN, Infinity, cero y clamp 4096', () {
      expect(UniversalImage.computeSafeCacheDimension(null, 2.0), isNull);
      expect(UniversalImage.computeSafeCacheDimension(double.infinity, 2.0), isNull);
      expect(UniversalImage.computeSafeCacheDimension(double.nan, 2.0), isNull);
      expect(UniversalImage.computeSafeCacheDimension(0, 2.0), isNull);
      expect(UniversalImage.computeSafeCacheDimension(-24, 2.0), isNull);
      expect(UniversalImage.computeSafeCacheDimension(0.2, 1.0), 1);
      expect(UniversalImage.computeSafeCacheDimension(64, 2.5), 160);
      expect(UniversalImage.computeSafeCacheDimension(5000, 2.0), 4096);
    });

    testWidgets('UniversalImage con path nulo y archivo inexistente no lanza en build', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalImage(
              path: null,
              width: 64,
              height: 64,
              productName: 'Café Especial',
              categoryName: 'Bebidas',
            ),
          ),
        ),
      );
      expect(find.text('CE'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalImage(
              path: '__inexistente__/archivo_no_existe_plan25.png',
              width: 64,
              height: 64,
              productName: 'Arroz Extra',
              categoryName: 'Abarrotes',
            ),
          ),
        ),
      );

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<ResizeImage>());

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Plan 25 Fase 6 — Higiene, limpieza de huérfanos y AndroidManifest (D-MOV-07)', () {
    test('los 5 archivos huérfanos están eliminados, AndroidManifest está limpio y sin Clipboard.setData directo', () {
      final root = _resolveAppMovilRoot();
      final sep = Platform.pathSeparator;

      final removedFiles = [
        'lib${sep}features${sep}profile${sep}screens${sep}business_backup_screen.dart',
        'lib${sep}core${sep}widgets${sep}safe_dropdown.dart',
        'lib${sep}core${sep}widgets${sep}super_switch.dart',
        'lib${sep}features${sep}profile${sep}widgets${sep}team${sep}team_members_tab.dart',
        'lib${sep}features${sep}profile${sep}widgets${sep}team${sep}access_codes_tab.dart',
      ];
      for (final rel in removedFiles) {
        expect(
          File('${root.path}$sep$rel').existsSync(),
          isFalse,
          reason: 'El huérfano $rel debía estar eliminado',
        );
      }
      expect(
        Directory('${root.path}${sep}lib${sep}features${sep}profile${sep}widgets${sep}team')
            .existsSync(),
        isFalse,
      );

      final manifestFile = File(
        '${root.path}${sep}android${sep}app${sep}src${sep}main${sep}AndroidManifest.xml',
      );
      expect(manifestFile.existsSync(), isTrue);
      final manifest = manifestFile.readAsStringSync();
      expect(manifest.contains('com.google.android.geo.API_KEY'), isFalse);
      expect(manifest.contains('android.permission.CAMERA'), isTrue);
      expect(manifest.contains('android.permission.INTERNET'), isTrue);

      final libDir = Directory('${root.path}${sep}lib');
      final offendingClipboardFiles = <String>[];
      for (final entity in libDir.listSync(recursive: true).whereType<File>()) {
        if (!entity.path.endsWith('.dart')) continue;
        final norm = entity.path.replaceAll('\\', '/');
        if (norm.endsWith('/lib/core/utils/clipboard_helper.dart')) continue;
        final text = entity.readAsStringSync();
        if (text.contains('Clipboard.setData')) {
          offendingClipboardFiles.add(norm);
        }
      }
      expect(offendingClipboardFiles, isEmpty);
    });
  });
}
