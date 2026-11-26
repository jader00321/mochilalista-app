import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/commercial_config_sync_service.dart';
import '../lib/config_service.dart';
import '../lib/license_signer.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 24 - FASE 1: Motor QR ISO/IEC 18004 V1-V40 y Saneamiento Updates 12 meses', () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ml_p24_fase1_');
      dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Round-trip Node.js con jsqr.min.js sobre V1-V40 (220B..2900B), token MLC1 real y quiet zone 32px', () async {
      final configService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await configService.init();

      final signer = LicenseSigner();
      await signer.initWithSeed(List<int>.generate(32, (i) => (i * 19 + 7) % 256));
      final syncService = CommercialConfigSyncService();

      // Token MLC1 real estándar (~1,990 B)
      final stdIssued = await syncService.generateSignedToken(
        configService.config,
        revision: 1,
        signer: signer,
        nowUtc: DateTime.utc(2026, 11, 25, 17, 0, 0),
      );
      final stdToken = stdIssued['token'] as String;

      // Token MLC1 real extendido con BCP + BBVA completos (~2,200+ B)
      final extConfig = jsonDecode(jsonEncode(configService.config)) as Map<String, dynamic>;
      final pm = Map<String, dynamic>.from(extConfig['payment_methods'] as Map);
      pm['bcp_account_holder'] = 'Julio Angello Vasquez Navarro';
      pm['bcp_account_number'] = '191-98765432-0-12';
      pm['bcp_cci'] = '00219119876543201255';
      pm['bbva_account_holder'] = 'Julio Angello Vasquez Navarro';
      pm['bbva_account_number'] = '0011-0123-0200456789';
      pm['bbva_cci'] = '01112300020045678934';
      extConfig['payment_methods'] = pm;
      final extIssued = await syncService.generateSignedToken(
        extConfig,
        revision: 2,
        signer: signer,
        nowUtc: DateTime.utc(2026, 11, 25, 17, 5, 0),
      );
      final extToken = extIssued['token'] as String;

      final runnerFile = File('${tempDir.path}/qr_roundtrip_runner.js');
      runnerFile.writeAsStringSync(r'''
const fs = require('fs');
const vm = require('vm');

const qrCodePath = process.argv[2];
const jsQrPath = process.argv[3];
const adminBundlePath = process.argv[4];
const payloadsJson = fs.readFileSync(process.argv[5], 'utf8');
const inputData = JSON.parse(payloadsJson);

const qrCodeSrc = fs.readFileSync(qrCodePath, 'utf8');
const jsQrSrc = fs.readFileSync(jsQrPath, 'utf8');
const adminAppSrc = fs.readFileSync(adminBundlePath, 'utf8');

function extractFunction(src, fnName) {
  const marker = `function ${fnName}(`;
  const start = src.indexOf(marker);
  if (start === -1) throw new Error(`No encontrado ${fnName}`);
  let i = src.indexOf('{', start);
  let depth = 0;
  let inSingle = false, inDouble = false, inTemplate = false, inLineComment = false, inBlockComment = false;
  for (; i < src.length; i++) {
    const ch = src[i], prev = src[i - 1], next = src[i + 1];
    if (inLineComment) { if (ch === '\n') inLineComment = false; continue; }
    if (inBlockComment) { if (prev === '*' && ch === '/') inBlockComment = false; continue; }
    if (inSingle) { if (ch === "'" && prev !== '\\') inSingle = false; continue; }
    if (inDouble) { if (ch === '"' && prev !== '\\') inDouble = false; continue; }
    if (inTemplate) { if (ch === '`' && prev !== '\\') inTemplate = false; continue; }
    if (ch === '/' && next === '/') { inLineComment = true; continue; }
    if (ch === '/' && next === '*') { inBlockComment = true; continue; }
    if (ch === "'") { inSingle = true; continue; }
    if (ch === '"') { inDouble = true; continue; }
    if (ch === '`') { inTemplate = true; continue; }
    if (ch === '{') depth++;
    else if (ch === '}') { depth--; if (depth === 0) return src.slice(start, i + 1); }
  }
  throw new Error(`No cerrado ${fnName}`);
}

function parseColor(colorStr) {
  const s = String(colorStr || '').trim().toLowerCase();
  if (s === 'white' || s === '#fff' || s === '#ffffff') return [255, 255, 255, 255];
  if (s === 'black' || s === '#000' || s === '#000000') return [0, 0, 0, 255];
  if (s.startsWith('#') && s.length === 7) {
    return [parseInt(s.slice(1, 3), 16), parseInt(s.slice(3, 5), 16), parseInt(s.slice(5, 7), 16), 255];
  }
  return [15, 23, 42, 255];
}

function makeMockCanvas() {
  return {
    tagName: 'CANVAS',
    width: 0,
    height: 0,
    style: {},
    _rgba: new Uint8ClampedArray(0),
    _initBuffer() {
      this._rgba = new Uint8ClampedArray(Math.max(0, Math.floor(this.width)) * Math.max(0, Math.floor(this.height)) * 4);
    },
    getContext(kind) {
      if (kind !== '2d') return null;
      const self = this;
      if (self._rgba.length !== self.width * self.height * 4) self._initBuffer();
      return {
        fillStyle: '#000000',
        imageSmoothingEnabled: true,
        fillRect(x, y, w, h) {
          if (self._rgba.length !== self.width * self.height * 4) self._initBuffer();
          const [r, g, b, a] = parseColor(this.fillStyle);
          const x0 = Math.max(0, Math.round(x));
          const y0 = Math.max(0, Math.round(y));
          const x1 = Math.min(self.width, Math.round(x + w));
          const y1 = Math.min(self.height, Math.round(y + h));
          for (let py = y0; py < y1; py++) {
            for (let px = x0; px < x1; px++) {
              const idx = (py * self.width + px) * 4;
              self._rgba[idx] = r; self._rgba[idx + 1] = g; self._rgba[idx + 2] = b; self._rgba[idx + 3] = a;
            }
          }
        },
        drawImage(src, dx, dy, dw, dh) {
          if (self._rgba.length !== self.width * self.height * 4) self._initBuffer();
          const sw = src.width, sh = src.height, tw = dw || sw, th = dh || sh;
          for (let py = 0; py < th; py++) {
            const sy = Math.min(sh - 1, Math.floor((py * sh) / th));
            const ty = dy + py;
            if (ty < 0 || ty >= self.height) continue;
            for (let px = 0; px < tw; px++) {
              const sx = Math.min(sw - 1, Math.floor((px * sw) / tw));
              const tx = dx + px;
              if (tx < 0 || tx >= self.width) continue;
              const sIdx = (sy * sw + sx) * 4, dIdx = (ty * self.width + tx) * 4;
              self._rgba[dIdx] = src._rgba[sIdx];
              self._rgba[dIdx + 1] = src._rgba[sIdx + 1];
              self._rgba[dIdx + 2] = src._rgba[sIdx + 2];
              self._rgba[dIdx + 3] = src._rgba[sIdx + 3];
            }
          }
        }
      };
    },
    toDataURL() { return 'data:image/png;base64,MOCK'; }
  };
}

function makeMockElement(tag = 'DIV') {
  return {
    tagName: tag.toUpperCase(),
    className: '',
    style: {},
    children: [],
    _innerHTML: '',
    _textContent: '',
    set innerHTML(v) { this._innerHTML = String(v); this.children = []; },
    get innerHTML() { return this._innerHTML; },
    set textContent(v) { this._textContent = String(v); },
    get textContent() { return this._textContent; },
    appendChild(c) { this.children.push(c); return c; },
    querySelector(sel) {
      if (sel === 'canvas') return this.children.find(c => c.tagName === 'CANVAS') || null;
      if (sel.startsWith('.')) {
        const cls = sel.slice(1);
        return this.children.find(c => String(c.className || '').split(/\s+/).includes(cls)) || null;
      }
      return null;
    }
  };
}

const sandbox = {
  window: {},
  document: {
    createElement(tag) {
      return String(tag).toLowerCase() === 'canvas' ? makeMockCanvas() : makeMockElement(tag);
    },
    getElementById() { return null; }
  },
  console: { log: () => {}, error: () => {}, warn: () => {} },
  TextEncoder,
  Uint8Array,
  Uint8ClampedArray,
  Math,
  Error,
  Array,
  Number,
  String,
  parseInt
};
sandbox.window = sandbox;
sandbox.self = sandbox;
sandbox.global = sandbox;

vm.createContext(sandbox);
vm.runInContext(qrCodeSrc, sandbox);
vm.runInContext(jsQrSrc, sandbox);
vm.runInContext(extractFunction(adminAppSrc, 'getUtf8ByteLength'), sandbox);
vm.runInContext(extractFunction(adminAppSrc, 'renderSafeQrCode'), sandbox);

function addQuietZoneRgba(srcCanvas, marginPx) {
  const outW = srcCanvas.width + marginPx * 2;
  const outH = srcCanvas.height + marginPx * 2;
  const off = makeMockCanvas();
  off.width = outW; off.height = outH;
  const ctx = off.getContext('2d');
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, outW, outH);
  ctx.drawImage(srcCanvas, marginPx, marginPx, srcCanvas.width, srcCanvas.height);
  return off;
}

const results = [];
for (const tc of inputData.cases) {
  const c = makeMockElement('DIV');
  const inst = sandbox.renderSafeQrCode(c, tc.payload, tc.size, '#0f172a', '#ffffff');
  const canvas = c.querySelector('canvas');
  const finalCanvas = tc.margin > 0 ? addQuietZoneRgba(canvas, tc.margin) : canvas;
  const decoded = sandbox.jsQR(finalCanvas._rgba, finalCanvas.width, finalCanvas.height, { inversionAttempts: 'attemptBoth' });
  results.push({
    name: tc.name,
    bytes: Buffer.byteLength(tc.payload, 'utf8'),
    version: inst ? inst._lastVersion : null,
    level: inst ? inst._lastCorrectLevel : null,
    modules: inst ? inst._lastModuleCount : null,
    exportWidth: finalCanvas.width,
    exportHeight: finalCanvas.height,
    decoded: decoded ? decoded.data : null
  });
}

const ovContainer = makeMockElement('DIV');
const ovRes = sandbox.renderSafeQrCode(ovContainer, inputData.overflowPayload, 512, '#0f172a', '#ffffff');
const warnEl = ovContainer.querySelector('.qr-capacity-warning');

process.stdout.write(JSON.stringify({
  results,
  overflowReturnedNull: ovRes === null,
  overflowWarningText: warnEl ? warnEl.textContent : ''
}));
''');

      String deterministicStr(String prefix, int bytes) {
        const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
        final sb = StringBuffer(prefix);
        var i = 0;
        while (sb.length < bytes) {
          sb.write(alphabet[(i * 7 + 13) % alphabet.length]);
          i++;
        }
        return sb.toString();
      }

      final payloadFile = File('${tempDir.path}/payloads.json');
      payloadFile.writeAsStringSync(jsonEncode({
        'cases': [
          {'name': 'ml9_short', 'payload': deterministicStr('ML9-', 220), 'size': 196, 'margin': 0},
          {'name': 'mls1_mid', 'payload': deterministicStr('MLS1-', 460), 'size': 256, 'margin': 0},
          {'name': 'mlc1_std', 'payload': stdToken, 'size': 512, 'margin': 32},
          {'name': 'mlc1_ext', 'payload': extToken, 'size': 512, 'margin': 32},
          {'name': 'stress_v40', 'payload': deterministicStr('MLC1-', 2900), 'size': 640, 'margin': 32},
        ],
        'overflowPayload': deterministicStr('MLC1-', 3100),
      }));

      final adminBundleFile = WebBundleLoader.writeConcatenatedJsTo(
        tempDir,
        filename: 'admin_bundle_p24_f1.js',
      );
      final proc = await Process.run('node', [
        runnerFile.path,
        WebBundleLoader.resolveWebAssetPath('js/qrcode.min.js'),
        WebBundleLoader.resolveWebAssetPath('js/jsqr.min.js'),
        adminBundleFile.path,
        payloadFile.path,
      ]);
      expect(proc.exitCode, equals(0), reason: 'stderr: ${proc.stderr}');

      final parsed = jsonDecode(proc.stdout as String) as Map<String, dynamic>;
      final results = (parsed['results'] as List).cast<Map<String, dynamic>>();
      expect(results.length, equals(5));

      // M=0, L=1
      expect(results[0]['level'], equals(0));
      expect(results[0]['decoded'], isNotEmpty);
      expect(results[1]['level'], equals(0));
      expect(results[1]['decoded'], isNotEmpty);

      // Tokens MLC1 reales: CorrectLevel.L (1), exportación 576x576 px, decodificación exacta y firma válida
      expect(results[2]['level'], equals(1));
      expect(results[2]['exportWidth'], equals(576));
      expect(results[2]['exportHeight'], equals(576));
      expect(results[2]['decoded'], equals(stdToken));

      expect(results[3]['level'], equals(1));
      expect(results[3]['exportWidth'], equals(576));
      expect(results[3]['exportHeight'], equals(576));
      expect(results[3]['decoded'], equals(extToken));

      // Re-verificación Ed25519 sobre el string decodificado directamente desde el QR
      final verifyStd = await syncService.verifySignedToken(
        results[2]['decoded'] as String,
        signer: signer,
      );
      expect(verifyStd['valid'], isTrue);
      final verifyExt = await syncService.verifySignedToken(
        results[3]['decoded'] as String,
        signer: signer,
      );
      expect(verifyExt['valid'], isTrue);
      expect((verifyExt['payload'] as Map)['p']['perpetua']['um'], equals(12));
      expect((verifyExt['payload'] as Map)['p']['pase_anual_updates']['um'], equals(12));
      expect((verifyExt['payload'] as Map)['bcp']['acc'], equals('191-98765432-0-12'));
      expect((verifyExt['payload'] as Map)['bbva']['acc'], equals('0011-0123-0200456789'));

      // Estrés V40-L ~2900 B
      expect(results[4]['version'], equals(40));
      expect(results[4]['level'], equals(1));
      expect((results[4]['decoded'] as String).length, equals(2900));

      // Overflow controlado > 2953 B sin emojis crudos
      expect(parsed['overflowReturnedNull'], isTrue);
      final warnText = parsed['overflowWarningText'] as String;
      expect(warnText, contains('2,953'));
      expect(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true).hasMatch(warnText), isFalse);
    });

    test('2. Saneamiento de raíz Updates = 12 meses (<= 0 -> 12) preservando ediciones > 0 (ej. 24)', () async {
      // Sembrar un owner_config.json legado con updates_window_months: 0 en PERPETUO_LIBERADO y PASE_ACTUALIZACION_ANUAL
      final seedService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await seedService.init();
      final legacyRaw = jsonDecode(jsonEncode(seedService.config)) as Map<String, dynamic>;
      final cat = Map<String, dynamic>.from(legacyRaw['catalog'] as Map);
      cat['PERPETUO_LIBERADO'] = <String, dynamic>{
        ...Map<String, dynamic>.from(cat['PERPETUO_LIBERADO'] as Map),
        'updates_window_months': 0,
        'updates_months': 0,
      };
      cat['PASE_ACTUALIZACION_ANUAL'] = <String, dynamic>{
        ...Map<String, dynamic>.from(cat['PASE_ACTUALIZACION_ANUAL'] as Map),
        'updates_window_months': 0,
        'updates_months': 0,
      };
      legacyRaw['catalog'] = cat;
      seedService.configFile.writeAsStringSync(jsonEncode(legacyRaw));

      // Al inicializar ConfigService sobre el JSON legado, ambos deben sanearse a 12
      final reloaded = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await reloaded.init();
      expect(reloaded.catalog['PERPETUO_LIBERADO']['updates_window_months'], equals(12));
      expect(reloaded.catalog['PERPETUO_LIBERADO']['updates_months'], equals(12));
      expect(reloaded.catalog['PASE_ACTUALIZACION_ANUAL']['updates_window_months'], equals(12));
      expect(reloaded.catalog['PASE_ACTUALIZACION_ANUAL']['updates_months'], equals(12));
      expect(reloaded.catalog['MENSUAL']['updates_window_months'], equals(0));
      expect(reloaded.catalog['RECARGA_IA_150']['updates_window_months'], equals(0));
      expect(reloaded.catalog['HARDWARE_MIGRATION_FEE']['updates_window_months'], equals(0));

      // Si el propietario edita explícitamente a 24 meses, se preserva intacto
      final updatedRaw = jsonDecode(jsonEncode(reloaded.config)) as Map<String, dynamic>;
      updatedRaw['catalog']['PERPETUO_LIBERADO']['updates_window_months'] = 24;
      updatedRaw['catalog']['PERPETUO_LIBERADO']['updates_months'] = 24;
      await reloaded.saveConfig(updatedRaw);
      expect(reloaded.catalog['PERPETUO_LIBERADO']['updates_window_months'], equals(24));

      // Además, buildCanonicalPayload directo sobre un mapa sin normalizar (0 -> 12, 24 -> 24, negativo -> error)
      final syncService = CommercialConfigSyncService();
      final unnormalizedPayload = syncService.buildCanonicalPayload(
        legacyRaw,
        revision: 1,
        nowUtc: DateTime.utc(2026, 11, 25, 17, 10, 0),
      );
      expect(unnormalizedPayload['p']['perpetua']['um'], equals(12));
      expect(unnormalizedPayload['p']['pase_anual_updates']['um'], equals(12));

      final customPayload = syncService.buildCanonicalPayload(
        updatedRaw,
        revision: 2,
        nowUtc: DateTime.utc(2026, 11, 25, 17, 11, 0),
      );
      expect(customPayload['p']['perpetua']['um'], equals(24));

      final negativeRaw = jsonDecode(jsonEncode(legacyRaw)) as Map<String, dynamic>;
      negativeRaw['catalog']['PERPETUO_LIBERADO']['updates_window_months'] = -3;
      negativeRaw['catalog']['PERPETUO_LIBERADO']['updates_months'] = -3;
      expect(
        () => syncService.buildCanonicalPayload(negativeRaw, revision: 3),
        throwsA(isA<CommercialConfigSyncException>()),
      );
    });
  });
}
