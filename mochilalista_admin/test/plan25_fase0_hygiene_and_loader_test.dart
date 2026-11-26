import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 25 - FASE 0: WebBundleLoader, .gitattributes e Higiene PowerShell', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ml_p25_fase0_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. WebBundleLoader resuelve rutas reales y mantiene paridad exacta HTML/CSS/JS + node --check', () {
      final htmlFile = WebBundleLoader.resolveWebAssetFile('index.html');
      final cssFile = WebBundleLoader.resolveWebAssetFile('css/styles.css');
      final jsFile = WebBundleLoader.resolveWebAssetFile('js/admin_app.js');

      expect(htmlFile.existsSync(), isTrue);
      expect(cssFile.existsSync(), isTrue);
      expect(jsFile.existsSync(), isTrue);

      expect(WebBundleLoader.loadHtml(), equals(htmlFile.readAsStringSync()));
      expect(WebBundleLoader.cssFilePaths(), isNotEmpty);
      expect(WebBundleLoader.loadCss(), equals(cssFile.readAsStringSync()));
      expect(WebBundleLoader.jsFilePaths(), isNotEmpty);
      expect(WebBundleLoader.loadJs(), equals(jsFile.readAsStringSync()));

      final bundleOut = WebBundleLoader.writeConcatenatedJsTo(
        tempDir,
        filename: 'fase0_bundle_check.js',
      );
      expect(bundleOut.existsSync(), isTrue);
      expect(bundleOut.readAsStringSync(), equals(WebBundleLoader.loadJs()));

      for (final jsPath in [...WebBundleLoader.jsFilePaths(), bundleOut.path]) {
        final res = Process.runSync('node', ['--check', jsPath]);
        expect(
          res.exitCode,
          equals(0),
          reason: 'node --check falló en $jsPath: ${res.stderr}',
        );
      }

      for (final vendorRel in ['js/qrcode.min.js', 'js/jsqr.min.js']) {
        final vendorFile = WebBundleLoader.resolveWebAssetFile(vendorRel);
        expect(vendorFile.existsSync(), isTrue, reason: '$vendorRel debe existir');
        final res = Process.runSync('node', ['--check', vendorFile.path]);
        expect(
          res.exitCode,
          equals(0),
          reason: 'node --check falló en $vendorRel: ${res.stderr}',
        );
      }
    });

    test('2. Higiene B: .gitattributes en raíz (UTF-8 sin BOM) y reglas EOL/binarias válidas', () {
      final gitattributes = WebBundleLoader.resolveRepoFile('.gitattributes');
      expect(gitattributes.existsSync(), isTrue);

      final bytes = gitattributes.readAsBytesSync();
      expect(
        bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF,
        isFalse,
        reason: '.gitattributes debe guardarse en UTF-8 sin BOM',
      );

      final content = utf8.decode(bytes);
      expect(content, contains('* text=auto'));
      expect(content, contains('*.bat text eol=crlf'));
      expect(content, contains('*.ps1 text eol=crlf'));
      expect(content, contains('*.dart text eol=lf'));
      expect(content, contains('*.js text eol=lf'));
      expect(content, contains('*.apk binary'));
    });

    test('3. Higiene A: scripts/compilar_release_dual.ps1 preserva BOM único EF BB BF, CRLF, AST=0 y verbos aprobados', () {
      final ps1File = WebBundleLoader.resolveRepoFile('scripts/compilar_release_dual.ps1');
      expect(ps1File.existsSync(), isTrue);

      final bytes = ps1File.readAsBytesSync();
      expect(bytes.length, greaterThan(6));
      expect(
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF,
        isTrue,
        reason: 'compilar_release_dual.ps1 debe conservar BOM UTF-8 EF BB BF al inicio',
      );
      expect(
        bytes[3] == 0xEF && bytes[4] == 0xBB && bytes[5] == 0xBF,
        isFalse,
        reason: 'compilar_release_dual.ps1 no debe tener doble BOM UTF-8',
      );

      // Cero LF sueltos sin CR previo
      var bareLfCount = 0;
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] == 0x0A && (i == 0 || bytes[i - 1] != 0x0D)) {
          bareLfCount++;
        }
      }
      expect(bareLfCount, equals(0), reason: 'El .ps1 debe mantener formato estricto CRLF');

      final content = utf8.decode(bytes.sublist(3));
      // Las 6 funciones con verbo no aprobado ya no deben declararse ni invocarse
      for (final legacyFn in [
        'T',
        'Fail-WithGuidance',
        'Parse-PubspecVersion',
        'Verify-KeystoreConfigSafe',
        'Parse-ApkSignerSummary',
        'Certify-ApkForensic',
      ]) {
        expect(
          RegExp('function\\s+$legacyFn\\b').hasMatch(content),
          isFalse,
          reason: 'Función con verbo no aprobado sigue declarada: $legacyFn',
        );
      }

      for (final approvedFn in [
        'ConvertTo-Utf8DisplayText',
        'Stop-WithGuidance',
        'ConvertFrom-PubspecVersion',
        'Test-KeystoreConfigSafe',
        'ConvertFrom-ApkSignerSummary',
        'Test-ApkForensic',
      ]) {
        expect(
          RegExp('function\\s+$approvedFn\\b').hasMatch(content),
          isTrue,
          reason: 'Falta función renombrada con verbo aprobado: $approvedFn',
        );
      }

      if (Platform.isWindows) {
        final escapedPath = ps1File.path.replaceAll("'", "''");
        final psRes = Process.runSync('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '''
\$bytes = [System.IO.File]::ReadAllBytes('$escapedPath')
\$noBom = [System.Text.Encoding]::UTF8.GetString(\$bytes, 3, \$bytes.Length - 3)
\$err = \$null; \$tok = \$null
\$ast = [System.Management.Automation.Language.Parser]::ParseInput(\$noBom, [ref]\$tok, [ref]\$err)
\$approved = (Get-Verb).Verb
\$fns = \$ast.FindAll({ param(\$n) \$n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, \$true)
\$bad = @(\$fns | Where-Object {
  \$verb = if (\$_.Name -like '*-*') { \$_.Name.Split('-')[0] } else { \$_.Name }
  \$approved -notcontains \$verb
})
Write-Output ("NO_BOM_PARSE_ERRORS=" + \$err.Count + "|UNAPPROVED_VERBS_COUNT=" + \$bad.Count)
if (\$err.Count -ne 0 -or \$bad.Count -ne 0) { exit 1 }
''',
        ]);
        expect(
          psRes.exitCode,
          equals(0),
          reason: 'Parser/Verb check PowerShell falló:\nSTDOUT:${psRes.stdout}\nSTDERR:${psRes.stderr}',
        );
        expect(psRes.stdout.toString(), contains('NO_BOM_PARSE_ERRORS=0|UNAPPROVED_VERBS_COUNT=0'));
      }
    });
  });
}
