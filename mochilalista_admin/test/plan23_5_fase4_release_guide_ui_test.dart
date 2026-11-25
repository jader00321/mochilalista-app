import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

String _extractSection(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + 1);
  if (start < 0 || end < 0 || end <= start) {
    throw StateError(
        'No se encontraron marcadores "$startMarker" -> "$endMarker"');
  }
  return source.substring(start, end);
}

void main() {
  group(
      'PLAN MAESTRO 23.5 - FASE 4: Mini-Guía Dual en #tabReleaseManager y Manual Operativo 05',
      () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p23_5_fase4_ui_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        '1. Auditoría estática HTML/CSS/JS de #btnToggleDualBuildGuide y #dualBuildGuidePanel (Dark/Light, SVG acotados, 0 emojis y contratos intactos)',
        () {
      final html = File('web/index.html').readAsStringSync();
      final css = File('web/css/styles.css').readAsStringSync();
      final js = File('web/js/admin_app.js').readAsStringSync();

      final releaseTabHtml = _extractSection(
        html,
        'id="tabReleaseManager"',
        'id="tabInspector"',
      );

      // Botón y panel oculto por defecto en #tabReleaseManager
      expect(releaseTabHtml, contains('id="btnToggleDualBuildGuide"'));
      expect(releaseTabHtml, contains('aria-expanded="false"'));
      expect(releaseTabHtml, contains('aria-controls="dualBuildGuidePanel"'));
      expect(releaseTabHtml, contains('Guía de Compilación Dual'));
      expect(
        releaseTabHtml,
        contains(
            '<div id="dualBuildGuidePanel" class="dual-build-guide-panel" style="display:none;">'),
      );

      // Tarjetas Universal vs ARM64 + ruta automática
      expect(releaseTabHtml, contains('APK Universal'));
      expect(releaseTabHtml, contains('~108 MB'));
      expect(releaseTabHtml, contains('APK ARM64 Ligero'));
      expect(releaseTabHtml, contains('~39 MB'));
      expect(releaseTabHtml, contains('100 MB'));
      expect(
        releaseTabHtml,
        contains(r'C:\Users\vjuli\Documents\v-app-offline apks\'),
      );

      // 4 comandos copiables exactos (incluyendo --init-notes de Plan 24)
      expect(releaseTabHtml, contains('data-cmd="compilar_release_dual.bat"'));
      expect(
        releaseTabHtml,
        contains('data-cmd="compilar_release_dual.bat --verify-only --no-pause"'),
      );
      expect(
        releaseTabHtml,
        contains(
            'data-cmd="compilar_release_dual.bat --verify-only --init-notes --no-pause"'),
      );
      expect(
        releaseTabHtml,
        contains('data-cmd="compilar_release_dual.bat --dry-run --no-pause"'),
      );
      expect(
        RegExp(r'class="[^"]*btn-copy-dual-cmd[^"]*"')
            .allMatches(releaseTabHtml)
            .length,
        equals(4),
      );

      // Flujo guiado en 4 pasos
      expect(releaseTabHtml, contains('app_movil/pubspec.yaml'));
      expect(
        releaseTabHtml,
        contains('Subir / Registrar Nueva Versión del APK'),
      );
      expect(releaseTabHtml, contains('Editar Versión'));
      expect(releaseTabHtml, contains('Biblioteca Oficial'));

      // Todos los <svg> dentro de #tabReleaseManager con dimensiones explícitas o clase acotada
      final svgTagRegex = RegExp(r'<svg\b[^>]*>');
      for (final match in svgTagRegex.allMatches(releaseTabHtml)) {
        final tag = match.group(0)!;
        final hasBounds = tag.contains('width=') ||
            tag.contains('width:') ||
            tag.contains('icon-svg') ||
            tag.contains('btn-icon') ||
            tag.contains('search-icon');
        expect(hasBounds, isTrue,
            reason: 'SVG sin dimensiones acotadas en #tabReleaseManager: $tag');
      }

      // CSS Fase 4 Dark + [data-theme="light"]
      final cssPhase4 = css.substring(
        css.indexOf('PLAN MAESTRO 23.5 - FASE 4:'),
      );
      expect(cssPhase4, contains('.dual-build-guide-panel'));
      expect(cssPhase4, contains('[data-theme="light"] .dual-build-guide-panel'));
      expect(cssPhase4, contains('.dual-build-variant-card'));
      expect(cssPhase4, contains('[data-theme="light"] .dual-build-variant-card'));
      expect(cssPhase4, contains('.dual-build-cmd-code'));
      expect(cssPhase4, contains('[data-theme="light"] .dual-build-cmd-code'));
      expect(cssPhase4, contains('.btn-copy-dual-cmd.is-copied'));
      expect(cssPhase4, contains('[data-theme="light"] .btn-copy-dual-cmd.is-copied'));

      // Contratos JS intactos de planes previos
      final fmtIdx = js.indexOf('function formatApkSizeMb(');
      final sigIdx = js.indexOf('function renderSignatureStatusBadge(');
      expect(fmtIdx, isPositive);
      expect(sigIdx, greaterThan(fmtIdx));

      final verifyStart = js.indexOf('let isVerifyAllCatalogRunning = false;');
      final verifyEnd =
          js.indexOf('/**\n * Carga notas compañeras', verifyStart + 1);
      expect(verifyStart, isPositive);
      expect(verifyEnd, greaterThan(verifyStart));

      final sec5Start = js.indexOf('// =================== 5. INSPECTOR FORENSE DUAL');
      final sec6Start = js.indexOf('// =================== 6. FINANZAS');
      expect(sec5Start, isPositive);
      expect(sec6Start, greaterThan(sec5Start));

      final dualJsSlice = _extractSection(
        js,
        '// =================== MINI-GUÍA RÁPIDA DE COMPILACIÓN DUAL',
        'const EXPANDABLE_TEXTAREA_IDS = [',
      );
      expect(dualJsSlice, contains('function toggleDualBuildGuide('));
      expect(dualJsSlice, contains('async function copyDualBuildCommand('));
      expect(dualJsSlice, contains('function initDualBuildGuide('));
      expect(js, contains('initDualBuildGuide();'));

      // Cero emojis crudos en #tabReleaseManager (HTML), CSS Fase 4 y JS Fase 4
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      const bannedSymbols = [
        '✅', '❌', '⚠️', 'ℹ️', '⬇️', '📁', '✏️', '🗑️', '📲', '🚀', '📦',
        '🛡️', '🔍', '💡', '🔐', '📄', '📋', '🪪', '📱', '✕', '✓',
      ];
      for (final chunk in [releaseTabHtml, cssPhase4, dualJsSlice]) {
        expect(emojiRegex.hasMatch(chunk), isFalse,
            reason: 'Emoji Unicode prohibido detectado en UI Fase 4');
        for (final sym in bannedSymbols) {
          expect(chunk.contains(sym), isFalse,
              reason: 'Símbolo crudo prohibido ($sym) detectado en UI Fase 4');
        }
      }
    });

    test(
        '2. Ejecución Node.js real: toggleDualBuildGuide() y copyDualBuildCommand() sobre los 3 comandos oficiales',
        () async {
      final js = File('web/js/admin_app.js').readAsStringSync();
      final dualJsSlice = _extractSection(
        js,
        '// =================== MINI-GUÍA RÁPIDA DE COMPILACIÓN DUAL',
        'const EXPANDABLE_TEXTAREA_IDS = [',
      );

      final nodeScript = File('${tempDir.path}/p23_5_fase4_ui_node.js');
      await nodeScript.writeAsString('''
const assert = require('assert');

class MockClassList {
  constructor() { this.set = new Set(); }
  add(...items) { items.forEach(i => this.set.add(i)); }
  remove(...items) { items.forEach(i => this.set.delete(i)); }
  toggle(cls, force) {
    if (typeof force === 'boolean') {
      if (force) this.set.add(cls); else this.set.delete(cls);
      return force;
    }
    if (this.set.has(cls)) { this.set.delete(cls); return false; }
    this.set.add(cls);
    return true;
  }
  contains(cls) { return this.set.has(cls); }
}

class MockButton {
  constructor(id, cmd = '') {
    this.id = id;
    this.dataset = cmd ? { cmd } : {};
    this.attrs = {};
    this.classList = new MockClassList();
    this.listeners = {};
    this.labelEl = { textContent: 'Copiar' };
  }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k] || ''; }
  querySelector(sel) {
    return sel === '[data-copy-label]' ? this.labelEl : null;
  }
  addEventListener(evt, fn) {
    this.listeners[evt] = this.listeners[evt] || [];
    this.listeners[evt].push(fn);
  }
  click() {
    (this.listeners.click || []).forEach(fn => fn({ target: this }));
  }
}

const panel = {
  id: 'dualBuildGuidePanel',
  style: { display: 'none' },
};
const toggleBtn = new MockButton('btnToggleDualBuildGuide');
toggleBtn.setAttribute('aria-expanded', 'false');

const copyButtons = [
  new MockButton('cmd1', 'compilar_release_dual.bat'),
  new MockButton('cmd2', 'compilar_release_dual.bat --verify-only --no-pause'),
  new MockButton('cmd3', 'compilar_release_dual.bat --verify-only --init-notes --no-pause'),
  new MockButton('cmd4', 'compilar_release_dual.bat --dry-run --no-pause'),
];

const clipboardWrites = [];
const toasts = [];
let execCopyCalls = 0;

global.showToast = (msg, type) => toasts.push({ msg, type });
Object.defineProperty(global, 'navigator', {
  configurable: true,
  writable: true,
  value: {
    clipboard: {
      writeText: async (txt) => { clipboardWrites.push(txt); },
    },
  },
});
global.document = {
  getElementById: (id) => {
    if (id === 'dualBuildGuidePanel') return panel;
    if (id === 'btnToggleDualBuildGuide') return toggleBtn;
    return null;
  },
  querySelectorAll: (sel) => (sel === '.btn-copy-dual-cmd' ? copyButtons : []),
  createElement: () => ({
    value: '',
    style: {},
    select() {},
    remove() {},
  }),
  body: { appendChild() {} },
  execCommand: (cmd) => {
    if (cmd === 'copy') execCopyCalls++;
    return true;
  },
};

$dualJsSlice

initDualBuildGuide();

(async () => {
  // 1. Estado inicial cerrado -> clic abre -> segundo clic cierra
  assert.strictEqual(panel.style.display, 'none');
  toggleBtn.click();
  assert.strictEqual(panel.style.display, 'block');
  assert.strictEqual(toggleBtn.getAttribute('aria-expanded'), 'true');
  assert.strictEqual(toggleBtn.classList.contains('active'), true);

  toggleBtn.click();
  assert.strictEqual(panel.style.display, 'none');
  assert.strictEqual(toggleBtn.getAttribute('aria-expanded'), 'false');
  assert.strictEqual(toggleBtn.classList.contains('active'), false);

  // 2. Copia de los 4 comandos oficiales
  for (const btn of copyButtons) {
    btn.click();
    await new Promise(r => setImmediate(r));
    assert.strictEqual(btn.classList.contains('is-copied'), true);
    assert.strictEqual(btn.labelEl.textContent, 'Copiado');
  }
  assert.deepStrictEqual(clipboardWrites, [
    'compilar_release_dual.bat',
    'compilar_release_dual.bat --verify-only --no-pause',
    'compilar_release_dual.bat --verify-only --init-notes --no-pause',
    'compilar_release_dual.bat --dry-run --no-pause',
  ]);
  assert.strictEqual(toasts.length, 4);
  assert.ok(toasts.every(t => t.type === 'success'));

  // 3. Fallback sin navigator.clipboard
  Object.defineProperty(global, 'navigator', {
    configurable: true,
    writable: true,
    value: {},
  });
  const okFallback = await copyDualBuildCommand('compilar_release_dual.bat --help --no-pause', null);
  assert.strictEqual(okFallback, true);
  assert.strictEqual(execCopyCalls, 1);

  console.log('PLAN23_5_FASE4_NODE_OK');
})();
''');

      final nodeRes = await Process.run('node', [nodeScript.path]);
      expect(
        nodeRes.exitCode,
        equals(0),
        reason:
            'Node UI test Fase 4 falló:\nSTDOUT: ${nodeRes.stdout}\nSTDERR: ${nodeRes.stderr}',
      );
      expect(nodeRes.stdout.toString(), contains('PLAN23_5_FASE4_NODE_OK'));
    });

    test(
        '3. Auditoría documental UTF-8 sin BOM, enlaces e integridad de Guía 1.6 (Tri-Protocolo) y Guía 2 (compilar_release_dual.bat) en Manual 05 y Plan 23.5',
        () {
      final manualFile = File(
          '../informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md');
      final planFile = File(
          '../informe_proyecto/23_5_PLAN_MAESTRO_INSPECTOR_MLC1_Y_COMPILADOR_DUAL.md');

      expect(manualFile.existsSync(), isTrue);
      expect(planFile.existsSync(), isTrue);

      final manualBytes = manualFile.readAsBytesSync();
      final planBytes = planFile.readAsBytesSync();

      // Sin UTF-8 BOM (EF BB BF) y UTF-8 estricto válido
      expect(
        manualBytes.length >= 3 &&
            manualBytes[0] == 0xEF &&
            manualBytes[1] == 0xBB &&
            manualBytes[2] == 0xBF,
        isFalse,
        reason: 'Manual 05 no debe contener BOM UTF-8',
      );
      expect(
        planBytes.length >= 3 &&
            planBytes[0] == 0xEF &&
            planBytes[1] == 0xBB &&
            planBytes[2] == 0xBF,
        isFalse,
        reason: 'Plan 23.5 no debe contener BOM UTF-8',
      );

      final manual = utf8.decode(manualBytes);
      final plan = utf8.decode(planBytes);

      // Índice General punto 3 corregido y coherente con encabezado Guía 3
      expect(
        manual,
        contains(
            '3. [GUÍA 3: Publicación y Notificación de Actualizaciones (Release Manager — Planes 19, 22, 22.5 y 23)](#guía-3-publicación-y-notificación-de-actualizaciones-release-manager--planes-19-22-225-y-23)'),
      );
      expect(
        manual,
        contains(
            '## GUÍA 3: PUBLICACIÓN Y NOTIFICACIÓN DE ACTUALIZACIONES (RELEASE MANAGER — PLANES 19, 22, 22.5 Y 23)'),
      );

      // Guía 1.3 ítem 5 y Guía 1.6 Tri-Protocolo completos
      expect(manual, contains('Inspector Forense Tri-Protocolo'));
      expect(manual, contains('Guía de Protocolos (ML9 / MLS1 / MLC1)'));
      expect(manual, contains('`ML9-...`'));
      expect(manual, contains('`MLS1-...` / `.mlsync`'));
      expect(manual, contains('`MLC1-...`'));
      expect(manual, contains('512 px'));
      expect(manual, contains('#inspectMlc1AuditCard'));
      expect(manual, contains('CURRENT'));
      expect(manual, contains('SUPERSEDED'));
      expect(manual, contains('AHEAD_OR_EXTERNAL'));
      expect(manual, contains('8 productos'));
      expect(manual, contains('5 canales'));
      expect(manual, contains('Copiar Informe Forense'));
      expect(manual, contains('#inspectorSessionHistoryPanel'));

      // Guía 2 con compilar_release_dual.bat + flags + 6 pasos + tabla errores + compatibilidad
      expect(manual, contains('compilar_release_dual.bat'));
      expect(manual, contains('scripts/compilar_release_dual.ps1'));
      expect(manual, contains('--dry-run'));
      expect(manual, contains('--verify-only'));
      expect(manual, contains('--skip-analyze'));
      expect(manual, contains('--no-pause'));
      expect(manual, contains('--out-dir'));
      expect(manual, contains('[Paso 1/6]'));
      expect(manual, contains('[Paso 6/6]'));
      expect(manual, contains('SDK `37+`'));
      expect(manual, contains('QUÉ FALLÓ'));
      expect(manual, contains('CÓMO SOLUCIONARLO'));
      expect(manual, contains('compilar_apk_comercial.bat'));
      expect(manual, contains('compilar_apk_arm64.bat'));

      // Plan 23.5 cerrado v1.4 con Acta Oficial de Cierre
      expect(plan, contains('Versión 1.4'));
      expect(plan, contains('100 % COMPLETADO Y CERTIFICADO'));
      expect(plan, contains('ACTA OFICIAL DE CIERRE'));
    });
  });
}
