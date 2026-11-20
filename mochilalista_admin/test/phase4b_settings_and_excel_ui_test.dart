import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('FASE 4B: Certificación de Interfaz del Centro de Personalización, Plantillas y Excel', () {
    late String htmlContent;
    late String cssContent;
    late String jsContent;

    setUpAll(() {
      final htmlFile = File('web/index.html');
      final cssFile = File('web/css/styles.css');
      final jsFile = File('web/js/admin_app.js');

      expect(htmlFile.existsSync(), isTrue, reason: 'index.html debe existir');
      expect(cssFile.existsSync(), isTrue, reason: 'styles.css debe existir');
      expect(jsFile.existsSync(), isTrue, reason: 'admin_app.js debe existir');

      htmlContent = htmlFile.readAsStringSync();
      cssContent = cssFile.readAsStringSync();
      jsContent = jsFile.readAsStringSync();
    });

    test('1. Interfaz Completa de #tabSettings (4 Sub-pestañas operativas y sin placeholders)', () {
      // Pestaña principal presente y activa
      expect(htmlContent.contains('id="tabSettings"'), isTrue);
      expect(htmlContent.contains('Centro de Personalización Total del Propietario'), isTrue);
      expect(htmlContent.contains('Disponible en Fase 4B'), isFalse, reason: 'Placeholder debe estar completamente eliminado');

      // 4 Sub-pestañas
      expect(htmlContent.contains('data-stab="stabPricing"'), isTrue);
      expect(htmlContent.contains('data-stab="stabTemplates"'), isTrue);
      expect(htmlContent.contains('data-stab="stabPayment"'), isTrue);
      expect(htmlContent.contains('data-stab="stabPreferences"'), isTrue);

      // Paneles de contenido
      expect(htmlContent.contains('id="stabPricing"'), isTrue);
      expect(htmlContent.contains('id="tableConfigCatalog"'), isTrue);
      expect(htmlContent.contains('id="catalogConfigTableBody"'), isTrue);
      expect(htmlContent.contains('id="cfgMigrationFee"'), isTrue);

      // Editor de 6 plantillas y chat en vivo
      expect(htmlContent.contains('id="stabTemplates"'), isTrue);
      expect(htmlContent.contains('id="cfgTemplateSelect"'), isTrue);
      expect(htmlContent.contains('id="cfgTemplateContent"'), isTrue);
      expect(htmlContent.contains('id="waBubbleContent"'), isTrue);
      expect(htmlContent.contains('data-var="{titular}"'), isTrue);
      expect(htmlContent.contains('data-var="{codigo}"'), isTrue);
      expect(htmlContent.contains('data-var="{bloque_banco_bcp}"'), isTrue);
      expect(htmlContent.contains('data-var="{bloque_banco_bbva}"'), isTrue);

      // Medios de pago e identidad legal
      expect(htmlContent.contains('id="stabPayment"'), isTrue);
      expect(htmlContent.contains('id="cfgLegalOwner"'), isTrue);
      expect(htmlContent.contains('id="cfgBrandName"'), isTrue);
      expect(htmlContent.contains('id="cfgYapePhone"'), isTrue);
      expect(htmlContent.contains('id="cfgBcpAccount"'), isTrue);
      expect(htmlContent.contains('id="cfgBbvaAccount"'), isTrue);

      // Preferencias y densidad
      expect(htmlContent.contains('id="stabPreferences"'), isTrue);
      expect(htmlContent.contains('id="cfgDefaultEnv"'), isTrue);
      expect(htmlContent.contains('id="cfgDefaultTheme"'), isTrue);
      expect(htmlContent.contains('id="cfgTableDensity"'), isTrue);
      expect(htmlContent.contains('id="btnSaveSettings"'), isTrue);
      expect(htmlContent.contains('id="btnResetSettings"'), isTrue);
    });

    test('2. Botones de Descarga Excel (.xlsx) en Header, CRM y Finanzas', () {
      expect(htmlContent.contains('id="btnHeaderExportExcel"'), isTrue);
      expect(htmlContent.contains('id="btnCrmExportExcel"'), isTrue);
      expect(htmlContent.contains('id="btnExportFinancesExcel"'), isTrue);
      expect(htmlContent.contains('id="btnExportFinancesCsv"'), isTrue);

      expect(jsContent.contains('/api/export/excel-master'), isTrue);
      expect(jsContent.contains('/api/export/excel-finances'), isTrue);
      expect(jsContent.contains('downloadExcelReport('), isTrue);
    });

    test('3. Micro-Limpiezas y Reglas de Calidad', () {
      // 1. Ausencia de emoji crudo en btnSubmitAndEmit
      expect(htmlContent.contains('Guardar y Emitir Licencia ⚡'), isFalse);
      expect(htmlContent.contains('Guardar y Emitir Licencia'), isTrue);

      // 2. Ausencia de badge FASE 4B en el Sidebar
      expect(htmlContent.contains('sidebar-badge-new">4B</span>'), isFalse);

      // 3. Ausencia de window.alert y window.confirm
      expect(jsContent.contains('window.alert('), isFalse);
      expect(jsContent.contains('alert('), isFalse);
      expect(jsContent.contains('window.confirm('), isFalse);
      expect(jsContent.contains('confirm('), isFalse);
    });

    test('4. Endpoints y Lógica de Sincronización en admin_app.js', () {
      expect(jsContent.contains('/api/config'), isTrue);
      expect(jsContent.contains('/api/config/reset'), isTrue);
      expect(jsContent.contains('/api/config/preview-template'), isTrue);
      expect(jsContent.contains('renderConfigTemplate('), isTrue);
      expect(jsContent.contains('applyConfigToUi('), isTrue);
      expect(jsContent.contains('applyTableDensity('), isTrue);
    });

    test('5. Reglas CSS de Estilos para Fase 4B', () {
      expect(cssContent.contains('.settings-tab-bar'), isTrue);
      expect(cssContent.contains('.settings-tab-btn'), isTrue);
      expect(cssContent.contains('.templates-editor-layout'), isTrue);
      expect(cssContent.contains('.wa-preview-container'), isTrue);
      expect(cssContent.contains('.wa-bubble'), isTrue);
      expect(cssContent.contains('.data-table.table-compact'), isTrue);
    });

    test('6. Micro-Auditoría de Claves ownerConfig y Paridad 1:1 con ConfigService', () {
      // 1. Identidad legal y autor
      expect(jsContent.contains('author_full_name'), isTrue);
      expect(jsContent.contains('legal_framework'), isTrue);
      expect(jsContent.contains('commercial_name'), isTrue);
      expect(jsContent.contains('support_phone'), isTrue);

      // 2. Medios de pago y supresión bancaria
      expect(jsContent.contains('yape_plin_phone'), isTrue);
      expect(jsContent.contains('yape_plin_holder'), isTrue);
      expect(jsContent.contains('bcp_account_number'), isTrue);
      expect(jsContent.contains('bbva_account_number'), isTrue);

      // 3. Tarifa técnica de migración sincronizada con catálogo
      expect(jsContent.contains("HARDWARE_MIGRATION_FEE"), isTrue);
      expect(jsContent.contains("catalog?.HARDWARE_MIGRATION_FEE?.price"), isTrue);

      // 4. Preferencias y sistema
      expect(jsContent.contains('cfg.system'), isTrue);
      expect(jsContent.contains('cfg.preferences'), isTrue);
      expect(jsContent.contains('default_mode'), isTrue);
      expect(jsContent.contains('table_density'), isTrue);

      // 5. Actualización inmediata en vivo tras PUT /api/config
      expect(jsContent.contains("document.querySelector('.author-name')"), isTrue);
      expect(jsContent.contains("applyTableDensity(density)"), isTrue);
      expect(jsContent.contains("updatePlanImpactAndProjection()"), isTrue);
      expect(jsContent.contains("document.getElementById('migFee')"), isTrue);
      expect(jsContent.contains("renderCredentialCanvas()"), isTrue);
    });
  });
}
