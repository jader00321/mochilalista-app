import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Plan Maestro 18.5 - Fase 2: Modal de Confirmación Pre-Emisión, Firma Ed25519 y switchDrawerTab', () {
    late String htmlContent;
    late String jsContent;
    late String cssContent;

    setUpAll(() {
      final htmlFile = File('web/index.html');
      expect(htmlFile.existsSync(), isTrue, reason: 'web/index.html debe existir');
      htmlContent = htmlFile.readAsStringSync();

      final jsFile = File('web/js/admin_app.js');
      expect(jsFile.existsSync(), isTrue, reason: 'web/js/admin_app.js debe existir');
      jsContent = jsFile.readAsStringSync();

      final cssFile = File('web/css/styles.css');
      expect(cssFile.existsSync(), isTrue, reason: 'web/css/styles.css debe existir');
      cssContent = cssFile.readAsStringSync();
    });

    test('2.1. Inspección Estática index.html: Modal #modalConfirmLicenseEmission y cero emojis crudos', () {
      expect(htmlContent.contains('id="modalConfirmLicenseEmission"'), isTrue,
          reason: 'Debe contener el overlay del modal de confirmación');
      expect(htmlContent.contains('id="confirmEmissionSummaryState"'), isTrue,
          reason: 'Debe contener la vista de resumen pre-emisión');
      expect(htmlContent.contains('id="confirmEmissionAnimState"'), isTrue,
          reason: 'Debe contener la vista animada de firma criptográfica');
      expect(htmlContent.contains('id="btnCancelConfirmEmission"'), isTrue,
          reason: 'Debe contener el botón de volver y corregir');
      expect(htmlContent.contains('id="btnExecuteConfirmEmission"'), isTrue,
          reason: 'Debe contener el botón de confirmación de firma');
      expect(htmlContent.contains('id="confirmLicClientName"'), isTrue);
      expect(htmlContent.contains('id="confirmLicHardwareId"'), isTrue);
      expect(htmlContent.contains('id="confirmLicNonce"'), isTrue);
      expect(htmlContent.contains('id="confirmLicFinancial"'), isTrue);
      expect(htmlContent.contains('id="btnDrawerQuickEditFollowup"'), isTrue);

      // Extraer bloque del modal para validar ausencia total de emojis crudos
      final modalStart = htmlContent.indexOf('id="modalConfirmLicenseEmission"');
      final modalEnd = htmlContent.indexOf('<!-- MODAL DE CONFIRMACIÓN PROFESIONAL', modalStart);
      expect(modalStart, isPositive);
      expect(modalEnd, greaterThan(modalStart));
      final modalBlock = htmlContent.substring(modalStart, modalEnd);

      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);
      final emojiMatches = emojiRegex.allMatches(modalBlock);
      expect(emojiMatches, isEmpty,
          reason: 'El modal #modalConfirmLicenseEmission debe contener CERO emojis crudos (solo SVG vectoriales)');
    });

    test('2.2. Inspección Estática admin_app.js: Lógica de confirmación, Nonce exacto, animación y errores', () {
      // Función de apertura pre-emisión
      expect(jsContent.contains('function openConfirmEmissionModal()'), isTrue,
          reason: 'Debe existir la función de apertura de pre-emisión');

      // Intercepción del botón emitir
      expect(jsContent.contains("document.getElementById('btnGenerateLicense')?.addEventListener('click', openConfirmEmissionModal);"), isTrue,
          reason: 'btnGenerateLicense debe estar interceptado por openConfirmEmissionModal');
      expect(jsContent.contains("document.getElementById('btnExecuteConfirmEmission')?.addEventListener('click', executeConfirmedEmission);"), isTrue,
          reason: 'btnExecuteConfirmEmission debe disparar executeConfirmedEmission');

      // Nonce exacto: Último Nonce Emitido -> Próximo Nonce a Firmar
      expect(
        jsContent.contains('Último Nonce Emitido (#\${lastNonce > 0 ? lastNonce : \'Ninguno\'}) → Próximo Nonce a Firmar (#\${nextNonce})'),
        isTrue,
        reason: 'El formato de Nonce debe reflejar rigurosamente el último emitido y el próximo a firmar',
      );

      // Micro-etapas de animación y manejo defensivo de errores
      expect(jsContent.contains('Validando correlativo Nonce y vinculación de Hardware...'), isTrue);
      expect(jsContent.contains('Firmando criptográficamente con clave maestra Ed25519...'), isTrue);
      expect(jsContent.contains('¡Licencia y Credencial Emitidas con Éxito!'), isTrue);

      // Respaldo visual en columna derecha
      expect(jsContent.contains('license-result-highlight'), isTrue,
          reason: 'Debe aplicar la clase de destello visual al emitir con éxito');
      expect(jsContent.contains("resultContainer.scrollIntoView({ behavior: 'smooth', block: 'nearest' });"), isTrue);
    });

    test('2.3. Inspección Estática admin_app.js: switchDrawerTab global y enlace a btnDrawerQuickEditFollowup', () {
      // Exposición global
      expect(jsContent.contains('function switchDrawerTab(targetTabId)'), isTrue);
      expect(jsContent.contains('window.switchDrawerTab = switchDrawerTab;'), isTrue,
          reason: 'switchDrawerTab debe exponerse en window para soportar onclick y llamadas directas');

      // Scroll y focus en drawerEditFollowupDate
      expect(jsContent.contains("normalizedId === 'drawerTabEdit'") || jsContent.contains("targetTabId === 'drawerTabEdit'"), isTrue);
      expect(jsContent.contains("document.getElementById('drawerEditFollowupDate')"), isTrue);
      expect(jsContent.contains("followupInput.scrollIntoView({ behavior: 'smooth', block: 'center' });"), isTrue);

      // Listener limpio para btnDrawerQuickEditFollowup
      expect(jsContent.contains("document.getElementById('btnDrawerQuickEditFollowup')?.addEventListener('click'"), isTrue);
    });

    test('2.4. Inspección Estática styles.css: Estilos de confirmación, animación shieldPulse y resaltado', () {
      expect(cssContent.contains('.confirm-emission-card'), isTrue);
      expect(cssContent.contains('.confirm-row'), isTrue);
      expect(cssContent.contains('.ed25519-shield-anim'), isTrue);
      expect(cssContent.contains('.shield-pulse-ring'), isTrue);
      expect(cssContent.contains('@keyframes shieldPulse'), isTrue);
      expect(cssContent.contains('.license-result-highlight'), isTrue);
      expect(cssContent.contains('@keyframes licenseResultGlow'), isTrue);

      // Soporte tema claro
      expect(cssContent.contains('[data-theme="light"] .confirm-emission-card'), isTrue,
          reason: 'Debe definir reglas específicas para tema claro');
    });
  });
}
