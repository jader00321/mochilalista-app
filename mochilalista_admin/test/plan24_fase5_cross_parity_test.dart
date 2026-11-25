import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

import '../lib/commercial_config_sync_service.dart';
import '../lib/config_service.dart';
import '../lib/license_signer.dart';

const String _expectedOfficialPublicSha256 =
    '1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106';

String _resolveAdminRoot() {
  if (File('web/js/qrcode.min.js').existsSync()) {
    return Directory.current.path;
  }
  if (File('mochilalista_admin/web/js/qrcode.min.js').existsSync()) {
    return '${Directory.current.path}/mochilalista_admin';
  }
  throw StateError('No se pudo ubicar mochilalista_admin.');
}

List<int> _extractMobileEmbeddedPublicKey(String dartValidatorPath) {
  final src = File(dartValidatorPath).readAsStringSync();
  final blockMatch = RegExp(
    r'_defaultOfficialPublicKeyBytes\s*=\s*\[([^\]]+)\]',
    multiLine: true,
  ).firstMatch(src);
  if (blockMatch == null) {
    throw StateError('No se encontró _defaultOfficialPublicKeyBytes');
  }
  final hexMatches = RegExp(r'0x([0-9a-fA-F]{2})')
      .allMatches(blockMatch.group(1)!)
      .map((m) => int.parse(m.group(1)!, radix: 16))
      .toList();
  if (hexMatches.length != 32) {
    throw StateError(
        'Se esperaban 32 bytes públicos embebidos, se encontraron ${hexMatches.length}');
  }
  return hexMatches;
}

void main() {
  group(
      'PLAN MAESTRO 24 - FASE 5: Paridad Criptográfica Pública Admin <-> Móvil y Vector Canónico MLC1',
      () {
    late Directory tempDir;
    late String adminRoot;

    setUp(() {
      adminRoot = _resolveAdminRoot();
      tempDir = Directory.systemTemp.createTempSync('ml_p24_fase5_parity_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        '1. Paridad exacta SHA-256 de la clave pública de 32 bytes Admin <-> App Móvil (sin exponer secretos)',
        () async {
      final mobileValidatorPath =
          '$adminRoot/../app_movil/lib/core/services/license/ed25519_license_validator.dart';
      expect(File(mobileValidatorPath).existsSync(), isTrue);

      final mobilePubBytes = _extractMobileEmbeddedPublicKey(mobileValidatorPath);
      final mobilePubSha256 =
          sha256.convert(mobilePubBytes).toString().toLowerCase();
      expect(mobilePubSha256, equals(_expectedOfficialPublicSha256));

      final masterKeyFile = File('$adminRoot/private_keys/ed25519_master.key');
      if (masterKeyFile.existsSync()) {
        final realSigner = LicenseSigner();
        await realSigner.loadMasterKey(keyPath: masterKeyFile.path);
        // Solo extraer y comparar la clave pública de 32 bytes (jamás imprimir semilla)
        final adminPubBytes = realSigner.publicKeyBytes;
        expect(adminPubBytes.length, equals(32));
        expect(adminPubBytes, equals(mobilePubBytes));
        final adminPubSha256 =
            sha256.convert(adminPubBytes).toString().toLowerCase();
        expect(adminPubSha256, equals(_expectedOfficialPublicSha256));
      }
    });

    test(
        '2. Vector canónico Admin completo (BCP+BBVA, 8 productos, um=12): firma Ed25519 MLC1- y round-trip QR jsQR 576x576',
        () async {
      final dataDir = Directory('${tempDir.path}/data')
        ..createSync(recursive: true);
      final backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);

      final configService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await configService.init();

      final cfg =
          jsonDecode(jsonEncode(configService.config)) as Map<String, dynamic>;
      cfg['legal_identity']['support_phone'] = '+51 999 777 666';
      cfg['legal_identity']['commercial_name'] = 'MochilaLista';
      cfg['payment_methods']['yape_plin_holder'] =
          'Julio Angello Vasquez Navarro';
      cfg['payment_methods']['yape_plin_phone'] = '999777666';
      cfg['payment_methods']['bcp_account_holder'] = 'Julio Angello Vasquez';
      cfg['payment_methods']['bcp_account_number'] = '191-55566677-0-99';
      cfg['payment_methods']['bcp_cci'] = '002-191-005556667709-99';
      cfg['payment_methods']['bbva_account_holder'] = 'Julio Angello Vasquez';
      cfg['payment_methods']['bbva_account_number'] = '0011-0123-0200456789';
      cfg['payment_methods']['bbva_cci'] = '011-123-000200456789-34';
      cfg['catalog']['MENSUAL']['price'] = 39.00;
      cfg['catalog']['MENSUAL']['ai_credits'] = 60;
      cfg['catalog']['PERPETUO_LIBERADO']['updates_window_months'] = 0;
      cfg['catalog']['PASE_ACTUALIZACION_ANUAL']['updates_window_months'] = 0;
      await configService.saveConfig(cfg);

      // Semilla sintética determinista compartida con la prueba cruzada móvil
      final testSeed = List<int>.generate(32, (i) => (i * 7 + 13) & 0xFF);
      final signer = LicenseSigner();
      await signer.initWithSeed(testSeed);

      final syncService = CommercialConfigSyncService();
      final issued = await syncService.generateSignedToken(
        configService.config,
        revision: 5,
        signer: signer,
        nowUtc: DateTime.utc(2026, 11, 25, 18, 30, 0),
      );

      final token = issued['token'] as String;
      expect(token.startsWith('MLC1-'), isTrue);
      final parts = token.substring('MLC1-'.length).split('.');
      expect(parts.length, equals(2));

      // Verificación directa Ed25519 con separación de dominio utf8('MLC1-$payloadB64')
      final domainBytes = utf8.encode('MLC1-${parts[0]}');
      final sigBytes = LicenseSigner.decodeBase64UrlSafe(parts[1]);
      final edValid = await Ed25519().verify(
        domainBytes,
        signature: Signature(
          sigBytes,
          publicKey: SimplePublicKey(
            signer.publicKeyBytes,
            type: KeyPairType.ed25519,
          ),
        ),
      );
      expect(edValid, isTrue);

      final verified =
          await syncService.verifySignedToken(token, signer: signer);
      expect(verified['valid'], isTrue);
      expect(verified['revision'], equals(5));
      final p = verified['payload']['p'] as Map<String, dynamic>;
      expect(p.length, equals(8));
      expect(p['perpetua']['um'], equals(12));
      expect(p['pase_anual_updates']['um'], equals(12));
      expect(p['mensual']['pr'], equals(39.0));
      expect(p['mensual']['ai'], equals(60));
      expect(verified['payload']['bcp']['acc'], equals('191-55566677-0-99'));
      expect(
        verified['payload']['bbva']['acc'],
        equals('0011-0123-0200456789'),
      );

      // Verificación QR V1-V40 + quiet zone 32px -> round-trip jsqr.min.js idéntico al token
      final nodeRunner = File('${tempDir.path}/qr_cross_check.js');
      nodeRunner.writeAsStringSync(r'''
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const adminRoot = process.argv[2];
const token = fs.readFileSync(process.argv[3], 'utf8');
const qrCodeSrc = fs.readFileSync(path.join(adminRoot, 'web/js/qrcode.min.js'), 'utf8');
const jsQrSrc = fs.readFileSync(path.join(adminRoot, 'web/js/jsqr.min.js'), 'utf8');
const adminAppSrc = fs.readFileSync(path.join(adminRoot, 'web/js/admin_app.js'), 'utf8');

function extractFn(src, name) {
  const s = src.indexOf(`function ${name}(`);
  let i = src.indexOf('{', s), d = 0, sq = false, dq = false, tq = false, lc = false, bc = false;
  for (; i < src.length; i++) {
    const ch = src[i], pv = src[i - 1], nx = src[i + 1];
    if (lc) { if (ch === '\n') lc = false; continue; }
    if (bc) { if (pv === '*' && ch === '/') bc = false; continue; }
    if (sq) { if (ch === "'" && pv !== '\\') sq = false; continue; }
    if (dq) { if (ch === '"' && pv !== '\\') dq = false; continue; }
    if (tq) { if (ch === '`' && pv !== '\\') tq = false; continue; }
    if (ch === '/' && nx === '/') { lc = true; continue; }
    if (ch === '/' && nx === '*') { bc = true; continue; }
    if (ch === "'") { sq = true; continue; }
    if (ch === '"') { dq = true; continue; }
    if (ch === '`') { tq = true; continue; }
    if (ch === '{') d++; else if (ch === '}') { d--; if (d === 0) return src.slice(s, i + 1); }
  }
  throw new Error('Unclosed ' + name);
}

function parseColor(c) {
  const s = String(c || '').toLowerCase();
  return (s === '#ffffff' || s === 'white') ? [255, 255, 255, 255] : [15, 23, 42, 255];
}
function makeCanvas() {
  return {
    tagName: 'CANVAS', width: 0, height: 0, style: {}, _rgba: new Uint8ClampedArray(0),
    getContext() {
      const self = this;
      if (self._rgba.length !== self.width * self.height * 4) {
        self._rgba = new Uint8ClampedArray(self.width * self.height * 4);
      }
      return {
        fillStyle: '#000000',
        fillRect(x, y, w, h) {
          if (self._rgba.length !== self.width * self.height * 4) {
            self._rgba = new Uint8ClampedArray(self.width * self.height * 4);
          }
          const [r, g, b, a] = parseColor(this.fillStyle);
          const x0 = Math.max(0, Math.round(x)), y0 = Math.max(0, Math.round(y));
          const x1 = Math.min(self.width, Math.round(x + w)), y1 = Math.min(self.height, Math.round(y + h));
          for (let py = y0; py < y1; py++) {
            for (let px = x0; px < x1; px++) {
              const idx = (py * self.width + px) * 4;
              self._rgba[idx] = r; self._rgba[idx + 1] = g; self._rgba[idx + 2] = b; self._rgba[idx + 3] = a;
            }
          }
        },
        drawImage(src, dx, dy, dw, dh) {
          if (self._rgba.length !== self.width * self.height * 4) {
            self._rgba = new Uint8ClampedArray(self.width * self.height * 4);
          }
          for (let py = 0; py < dh; py++) {
            const sy = Math.floor((py * src.height) / dh);
            for (let px = 0; px < dw; px++) {
              const sx = Math.floor((px * src.width) / dw);
              const si = (sy * src.width + sx) * 4, di = ((dy + py) * self.width + (dx + px)) * 4;
              self._rgba[di] = src._rgba[si]; self._rgba[di+1] = src._rgba[si+1];
              self._rgba[di+2] = src._rgba[si+2]; self._rgba[di+3] = src._rgba[si+3];
            }
          }
        }
      };
    }
  };
}
const container = { children: [], _inner: '', set innerHTML(v) { this._inner = v; this.children = []; }, appendChild(c) { this.children.push(c); return c; } };
const sb = {
  document: { createElement: (t) => t === 'canvas' ? makeCanvas() : { className: '', style: {} } },
  console: { log: () => {}, error: () => {} },
  TextEncoder, Uint8Array, Uint8ClampedArray, Math, Error, Array, Number, String, parseInt
};
sb.window = sb; sb.self = sb; sb.global = sb;
vm.createContext(sb);
vm.runInContext(qrCodeSrc, sb);
vm.runInContext(jsQrSrc, sb);
vm.runInContext(extractFn(adminAppSrc, 'getUtf8ByteLength'), sb);
vm.runInContext(extractFn(adminAppSrc, 'renderSafeQrCode'), sb);

const qrInst = sb.renderSafeQrCode(container, token, 512, '#0f172a', '#ffffff');
const srcCanvas = container.children[0];
const outCanvas = makeCanvas();
outCanvas.width = 576; outCanvas.height = 576;
const ctx = outCanvas.getContext('2d');
ctx.fillStyle = '#ffffff';
ctx.fillRect(0, 0, 576, 576);
ctx.drawImage(srcCanvas, 32, 32, 512, 512);
const decoded = sb.jsQR(outCanvas._rgba, 576, 576, { inversionAttempts: 'attemptBoth' });
if (!decoded || decoded.data !== token) process.exit(2);
process.stdout.write(JSON.stringify({ version: qrInst._lastVersion, level: qrInst._lastCorrectLevel, decodedMatch: true }));
''');
      final tokFile = File('${tempDir.path}/token.txt')
        ..writeAsStringSync(token);
      final proc = await Process.run('node', [
        nodeRunner.path,
        adminRoot,
        tokFile.path,
      ]);
      expect(proc.exitCode, equals(0), reason: 'stderr: ${proc.stderr}');
      final qrJson = jsonDecode(proc.stdout as String) as Map<String, dynamic>;
      expect(qrJson['decodedMatch'], isTrue);
      expect(qrJson['level'], equals(1)); // CorrectLevel.L
      expect(qrJson['version'], lessThanOrEqualTo(40));
    });
  });
}
