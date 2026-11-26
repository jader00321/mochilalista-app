import 'package:test/test.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('FASE 4A: Verificación Estructural de Interfaz, CSS y Lógica JS', () {
    late String htmlContent;
    late String cssContent;
    late String jsContent;

    setUpAll(() {
      htmlContent = WebBundleLoader.loadHtml();
      cssContent = WebBundleLoader.loadCss();
      jsContent = WebBundleLoader.loadJs();

      expect(htmlContent, isNotEmpty, reason: 'index.html debe existir');
      expect(cssContent, isNotEmpty, reason: 'styles.css debe existir');
      expect(jsContent, isNotEmpty, reason: 'admin_app.js debe existir');
    });

    test('1. Sidebar Lateral Colapsable y Header Ejecutivo (HTML & CSS)', () {
      // Sidebar layout y estructura
      expect(htmlContent.contains('class="app-layout"'), isTrue);
      expect(htmlContent.contains('class="app-sidebar" id="appSidebar"'), isTrue);
      expect(htmlContent.contains('class="sidebar-brand"'), isTrue);
      expect(htmlContent.contains('id="btnToggleSidebar"'), isTrue);
      expect(htmlContent.contains('class="sidebar-group-label">Operaciones</div>'), isTrue);
      expect(htmlContent.contains('class="sidebar-group-label">Auditoría</div>'), isTrue);
      expect(htmlContent.contains('class="sidebar-group-label">Sistema</div>'), isTrue);

      // Header Ejecutivo
      expect(htmlContent.contains('class="app-header"'), isTrue);
      expect(htmlContent.contains('id="currentViewName"'), isTrue);
      expect(htmlContent.contains('id="btnModeSandbox"'), isTrue);
      expect(htmlContent.contains('id="btnModeProd"'), isTrue);
      expect(htmlContent.contains('Julio Angello Vasquez Navarro'), isTrue);
      expect(htmlContent.contains('id="btnThemeToggle"'), isTrue);

      // Reglas CSS del Sidebar y Header
      expect(cssContent.contains('.app-layout'), isTrue);
      expect(cssContent.contains('.app-sidebar'), isTrue);
      expect(cssContent.contains('width: 260px;'), isTrue);
      expect(cssContent.contains('.app-sidebar.collapsed'), isTrue);
      expect(cssContent.contains('width: 68px;'), isTrue);
      expect(cssContent.contains('.app-header'), isTrue);
    });

    test('2. Dashboard con KPIs Interactivos y 2 Micro-Gráficos SVG Puros', () {
      // HTML
      expect(htmlContent.contains('id="chartMonthlyRevenue"'), isTrue);
      expect(htmlContent.contains('id="chartPlanDistribution"'), isTrue);
      expect(htmlContent.contains('data-kpi-filter="active"'), isTrue);
      expect(htmlContent.contains('data-kpi-filter="expiring"'), isTrue);
      expect(htmlContent.contains('data-kpi-filter="expired"'), isTrue);
      expect(htmlContent.contains('data-kpi-filter="perpetual"'), isTrue);
      expect(htmlContent.contains('data-kpi-filter="outdated"'), isTrue);

      // JS Lógica de renderizado SVG
      expect(jsContent.contains('function renderMonthlyRevenueChart('), isTrue);
      expect(jsContent.contains('function renderPlanDistributionChart('), isTrue);
      expect(jsContent.contains('initDashboardKpiClickEvents('), isTrue);
      expect(jsContent.contains('chart-empty-state'), isTrue);

      // CSS de Gráficos
      expect(cssContent.contains('.dashboard-charts-grid'), isTrue);
      expect(cssContent.contains('.svg-chart'), isTrue);
      expect(cssContent.contains('.chart-bar'), isTrue);
      expect(cssContent.contains('.donut-segment'), isTrue);
    });

    test('3. Tabla CRM Simplificada (7 Columnas) y 4 Botones de Acción Clave', () {
      // Cabeceras en index.html
      expect(htmlContent.contains('ID</th>'), isTrue);
      expect(htmlContent.contains('Negocio & Titular</th>'), isTrue);
      expect(htmlContent.contains('Plan & Vigencia</th>'), isTrue);
      expect(htmlContent.contains('Hardware ID (ANDROID_ID)</th>'), isTrue);
      expect(htmlContent.contains('Versión APK</th>'), isTrue);
      expect(htmlContent.contains('Créditos IA</th>'), isTrue);
      expect(htmlContent.contains('Acciones Clave</th>'), isTrue);

      // JS Generación de 4 botones
      expect(jsContent.contains('openClient360Drawer('), isTrue);
      expect(jsContent.contains('openQuickQrModal('), isTrue);
      expect(jsContent.contains('btn-crm-action'), isTrue);
      expect(jsContent.contains('api.whatsapp.com/send'), isTrue);
      expect(jsContent.contains('selectClientForLicense('), isTrue);
    });

    test('4. Modal Rápido Ver QR / Credencial Oficial (@2x Canvas & Anti-Doble Conteo)', () {
      // HTML
      expect(htmlContent.contains('id="modalQuickQr"'), isTrue);
      expect(htmlContent.contains('id="quickQrContainer"'), isTrue);
      expect(htmlContent.contains('id="quickCredentialCanvas"'), isTrue);
      expect(htmlContent.contains('id="btnQuickCopyCode"'), isTrue);
      expect(htmlContent.contains('id="btnQuickDownloadQr"'), isTrue);
      expect(htmlContent.contains('id="btnQuickCopyCredential"'), isTrue);
      expect(htmlContent.contains('id="btnQuickDownloadCredential"'), isTrue);
      expect(htmlContent.contains('id="btnQuickSendWa"'), isTrue);
      expect(htmlContent.contains('id="btnQuickAuditInInspector"'), isTrue);

      // JS
      expect(jsContent.contains('function openQuickQrModal(clientId)'), isTrue);
      expect(jsContent.contains('renderCredentialCanvas('), isTrue);
      expect(jsContent.contains('HARDWARE ID (ANDROID_ID)'), isTrue);
      expect(jsContent.contains('escaneos IA acumulativos vitalicios (o BYOK)'), isTrue);
      expect(jsContent.contains('Julio Angello Vasquez Navarro'), isTrue);
      expect(jsContent.contains('D.L. 822'), isTrue);
    });

    test('5. Drawer Lateral Deslizable Ficha 360° del Cliente (5 Pestañas)', () {
      // HTML
      expect(htmlContent.contains('id="drawerClient360"'), isTrue);
      expect(htmlContent.contains('id="drawerClient360Backdrop"'), isTrue);
      expect(htmlContent.contains('data-dtab="drawerTabOverview"'), isTrue);
      expect(htmlContent.contains('data-dtab="drawerTabQr"'), isTrue);
      expect(htmlContent.contains('data-dtab="drawerTabFinances"'), isTrue);
      expect(htmlContent.contains('data-dtab="drawerTabHardware"'), isTrue);
      expect(htmlContent.contains('data-dtab="drawerTabEdit"'), isTrue);
      expect(htmlContent.contains('id="formDrawerEditClient"'), isTrue);

      // JS
      expect(jsContent.contains('function openClient360Drawer(clientId)'), isTrue);
      expect(jsContent.contains('function closeClient360Drawer()'), isTrue);
      expect(jsContent.contains('function initDrawerEvents()'), isTrue);
      expect(jsContent.contains(r'/api/clients/${currentDrawerClientId}'), isTrue);

      // CSS
      expect(cssContent.contains('.drawer-panel'), isTrue);
      expect(cssContent.contains('.drawer-panel.open'), isTrue);
      expect(cssContent.contains('.drawer-backdrop.open'), isTrue);
    });

    test('6. Flujos de 1 Solo Paso (Guardar y Emitir + Migración Inmediata)', () {
      // Registro y Emisión Inmediata
      expect(htmlContent.contains('id="btnSubmitAndEmit"'), isTrue);
      expect(jsContent.contains('handleCreateClient(true)'), isTrue);
      expect(jsContent.contains('handleCreateClient(false)'), isTrue);

      // Migración Inmediata
      expect(htmlContent.contains('id="migEmitImmediately"'), isTrue);
      expect(htmlContent.contains('id="migSuccessInline"'), isTrue);
      expect(htmlContent.contains('id="migSuccessQrContainer"'), isTrue);
      expect(jsContent.contains('emit_immediately: emitImmediately'), isTrue);
      expect(jsContent.contains('handleMigrateDeviceSubmit'), isTrue);
    });

    test('7. Centro de Personalización Presente y Activo', () {
      expect(htmlContent.contains('id="tabSettings"'), isTrue);
      expect(htmlContent.contains('Centro de Personalización Total del Propietario'), isTrue);
    });
  });
}
