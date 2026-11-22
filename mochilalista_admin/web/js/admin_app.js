/**
 * MochilaLista Admin Platform — Centro Ejecutivo de Control, Licencias y Versiones
 * Autor y Titular Exclusivo: Julio Angello Vasquez Navarro
 * Derechos Reservados bajo Decreto Legislativo 822 / INDECOPI Perú
 */

// =================== INTERCEPTOR GLOBAL DE FETCH (SESIÓN PIN VAULT HTTP 423) ===================
const _originalFetch = window.fetch;
window.fetch = async function (...args) {
  let [resource, config] = args;
  config = config || {};
  config.headers = config.headers || {};

  const vaultToken = sessionStorage.getItem('ml_vault_session_token');
  if (vaultToken) {
    if (config.headers instanceof Headers) {
      if (!config.headers.has('X-Vault-Session-Token')) {
        config.headers.set('X-Vault-Session-Token', vaultToken);
      }
    } else if (Array.isArray(config.headers)) {
      if (!config.headers.some(([k]) => k.toLowerCase() === 'x-vault-session-token')) {
        config.headers.push(['X-Vault-Session-Token', vaultToken]);
      }
    } else {
      if (!config.headers['X-Vault-Session-Token'] && !config.headers['x-vault-session-token']) {
        config.headers['X-Vault-Session-Token'] = vaultToken;
      }
    }
  }

  const response = await _originalFetch(resource, config);
  if (response.status === 423) {
    // Sesión bloqueada localmente por PIN
    if (typeof showVaultPinLockOverlay === 'function') {
      showVaultPinLockOverlay();
    }
  }
  return response;
};

// =================== NORMALIZACIÓN DE TELÉFONOS PERÚ (+51) ===================
function normalizePeruPhone(raw) {
  if (!raw) return '';
  const trimmed = String(raw).trim();
  if (!trimmed) return '';
  const hasPlus = trimmed.startsWith('+');
  const digits = trimmed.replace(/\D/g, '');
  if (!digits) return '';

  if (hasPlus) {
    return '+' + digits;
  }
  if (digits.length === 9 && digits.startsWith('9')) {
    return '+51' + digits;
  }
  if (digits.length === 11 && digits.startsWith('519')) {
    return '+' + digits;
  }
  return digits;
}

/**
 * Renderiza de forma segura un código QR vectorial sin fallos por QRCode.CorrectLevel
 */
function renderSafeQrCode(container, text, size = 196, colorDark = '#0f172a', colorLight = '#ffffff') {
  const containerEl = (typeof container === 'string') ? document.getElementById(container) : container;
  if (!containerEl) return null;
  containerEl.innerHTML = '';
  if (typeof QRCode === 'undefined') return null;

  let level = 0;
  if (typeof QRCode.CorrectLevel !== 'undefined' && QRCode.CorrectLevel.M !== undefined) {
    level = QRCode.CorrectLevel.M;
  }

  try {
    return new QRCode(containerEl, {
      text: text,
      width: size,
      height: size,
      colorDark: colorDark,
      colorLight: colorLight,
      correctLevel: level,
    });
  } catch (e) {
    try {
      return new QRCode(containerEl, {
        text: text,
        width: size,
        height: size,
        colorDark: colorDark,
        colorLight: colorLight,
      });
    } catch (e2) {
      console.error('renderSafeQrCode fallback error:', e2);
      return null;
    }
  }
}

let globalClients = [];
let globalReleases = [];
let globalFinances = [];
let lastGeneratedQr = null;
let currentClientFilter = 'all';
let currentSearchQuery = '';
let currentMode = 'sandbox';
let currentHistoryClientId = null;
let activeHistoryTab = 'payments';
let availableLocalBuilds = [];
let currentDrawerClientId = null;
let currentQuickQrClientId = null;
let lastQuickQr = null;
let ownerConfig = null;
let templatePreviewTimer = null;

document.addEventListener('DOMContentLoaded', async () => {
  initNavigation();
  initTheme();
  initModeSwitcher();
  initOmnichannelSearch();
  initModalConfirm();
  initDashboardKpiClickEvents();
  initDrawerEvents();
  initReceiptModalEvents();
  initSettingsEvents();
  initExcelExportEvents();
  initVaultEvents();
  await checkVaultInitialStatus();
  await loadConfig();
  await loadSystemMode();
  await loadDashboard();
  await loadReleases();
  await loadClients();
  await loadReleaseMatrix();
  initLicenseStudioEvents();
  initModalEvents();
  initWaComposerEvents();
  initInspectorEvents();
  initReleaseUploadAndAutoDetect();
  initFinancesAndBackupsEvents();
});

// =================== SISTEMA DE NOTIFICACIONES TOAST ===================
function showToast(message, type = 'info', duration = 3500) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = `toast ${type}`;

  let icon = 'ℹ️';
  if (type === 'success') icon = '✅';
  else if (type === 'error') icon = '❌';
  else if (type === 'warning') icon = '⚠️';

  toast.innerHTML = `
    <span class="toast-icon">${icon}</span>
    <div class="toast-content">${escapeHtml(message)}</div>
    <button class="toast-close" onclick="this.parentElement.remove()">✕</button>
  `;

  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    toast.style.transition = 'all 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

// =================== MODAL DE CONFIRMACIÓN PROFESIONAL ===================
let confirmCallback = null;

function initModalConfirm() {
  const modal = document.getElementById('modalConfirm');
  const btnOk = document.getElementById('btnConfirmOk');
  const btnCancel = document.getElementById('btnConfirmCancel');
  const btnClose = document.getElementById('btnConfirmClose');

  const close = () => {
    modal?.classList.remove('open');
    confirmCallback = null;
  };

  btnCancel?.addEventListener('click', close);
  btnClose?.addEventListener('click', close);

  btnOk?.addEventListener('click', () => {
    if (confirmCallback) {
      confirmCallback();
    }
    close();
  });
}

function showConfirmModal(title, message, onConfirm, isDanger = false) {
  const modal = document.getElementById('modalConfirm');
  const titleEl = document.getElementById('confirmModalTitle');
  const msgEl = document.getElementById('confirmModalMessage');
  const btnOk = document.getElementById('btnConfirmOk');

  if (!modal || !titleEl || !msgEl || !btnOk) return;

  titleEl.textContent = title;
  msgEl.innerHTML = escapeHtml(message);
  confirmCallback = onConfirm;

  if (isDanger) {
    btnOk.className = 'btn btn-outline';
    btnOk.style.color = 'var(--danger)';
    btnOk.style.borderColor = 'var(--danger)';
    btnOk.textContent = 'Confirmar';
  } else {
    btnOk.className = 'btn btn-primary';
    btnOk.style.color = '';
    btnOk.style.borderColor = '';
    btnOk.textContent = 'Confirmar';
  }

  modal.classList.add('open');
}

// =================== NAVEGACIÓN ENTRE PESTAÑAS Y SIDEBAR (FASE 4A) ===================
function initNavigation() {
  const sidebar = document.getElementById('appSidebar');
  const btnToggle = document.getElementById('btnToggleSidebar');
  const btnMobileToggle = document.getElementById('btnMobileSidebarToggle');
  const floatingTooltip = document.getElementById('sidebarFloatingTooltip');

  // 1. Restaurar estado colapsado guardado
  const isCollapsed = localStorage.getItem('ml_admin_sidebar_collapsed') === 'true' ||
    localStorage.getItem('ml_sidebar_collapsed') === 'true';
  if (isCollapsed && sidebar) {
    sidebar.classList.add('collapsed');
  }

  // 2. Evento para colapsar / expandir
  btnToggle?.addEventListener('click', () => {
    if (!sidebar) return;
    const collapsed = sidebar.classList.toggle('collapsed');
    localStorage.setItem('ml_admin_sidebar_collapsed', collapsed ? 'true' : 'false');
    localStorage.setItem('ml_sidebar_collapsed', collapsed ? 'true' : 'false');
    if (floatingTooltip) floatingTooltip.classList.remove('visible');
  });

  // 3. Evento para menú responsive en móviles
  btnMobileToggle?.addEventListener('click', () => {
    sidebar?.classList.toggle('mobile-open');
  });

  // 4. Mapeo de títulos legibles para el Breadcrumb
  const tabTitles = {
    tabDashboard: 'Dashboard Financiero',
    tabClients: 'Cartera CRM',
    tabLicenseStudio: 'Generador de Licencias',
    tabReleaseManager: 'Gestor de Versiones APK',
    tabInspector: 'Inspector Forense ML9',
    tabFinancesAndBackups: 'Finanzas & Respaldos',
    tabSettings: 'Configuración y Personalización',
    tabSecurityVault: 'Seguridad y Portabilidad',
  };

  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(tab => {
    // Preservar título accesible sin provocar tooltips nativos desalineados
    const origTitle = tab.getAttribute('title');
    if (origTitle) {
      tab.setAttribute('data-nav-title', origTitle);
      tab.removeAttribute('title');
    }

    tab.addEventListener('click', () => {
      tabs.forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const targetPane = document.getElementById(tab.dataset.tab);
      if (targetPane) targetPane.classList.add('active');

      // Actualizar Breadcrumb
      const viewNameEl = document.getElementById('currentViewName');
      if (viewNameEl && tabTitles[tab.dataset.tab]) {
        viewNameEl.textContent = tabTitles[tab.dataset.tab];
      }

      // Cerrar sidebar en móviles tras seleccionar vista
      sidebar?.classList.remove('mobile-open');
      if (floatingTooltip) floatingTooltip.classList.remove('visible');

      if (tab.dataset.tab === 'tabDashboard') {
        loadDashboard();
      }
      if (tab.dataset.tab === 'tabClients') {
        loadClients();
      }
      if (tab.dataset.tab === 'tabReleaseManager') {
        loadReleases();
        loadReleaseMatrix();
      }
      if (tab.dataset.tab === 'tabFinancesAndBackups') {
        loadFinances();
        loadBackups();
      }
      if (tab.dataset.tab === 'tabSecurityVault') {
        loadVaultHealth();
      }
    });

    // Tooltip flotante nativo sin recorte por overflow en estado colapsado
    tab.addEventListener('mouseenter', () => {
      if (!sidebar?.classList.contains('collapsed') || !floatingTooltip) return;
      const labelText = tab.querySelector('.nav-label')?.textContent?.trim() ||
        tab.getAttribute('data-nav-title') || '';
      if (!labelText) return;

      floatingTooltip.textContent = labelText;
      const rect = tab.getBoundingClientRect();
      const top = rect.top + (rect.height / 2) - 14;
      const left = rect.right + 10;
      floatingTooltip.style.top = `${Math.max(8, top)}px`;
      floatingTooltip.style.left = `${left}px`;
      floatingTooltip.classList.add('visible');
    });

    tab.addEventListener('mouseleave', () => {
      if (floatingTooltip) floatingTooltip.classList.remove('visible');
    });
  });

  // Ocultar tooltip al hacer scroll en el sidebar o redimensionar
  sidebar?.querySelector('.sidebar-body')?.addEventListener('scroll', () => {
    if (floatingTooltip) floatingTooltip.classList.remove('visible');
  });
  window.addEventListener('resize', () => {
    if (floatingTooltip) floatingTooltip.classList.remove('visible');
  });

  // 5. Botón Discreto "Apagar Servidor" en Sidebar Footer (Plan Maestro 15 - Fase 7)
  const btnShutdown = document.getElementById('btnShutdownServer');
  if (btnShutdown) {
    btnShutdown.addEventListener('mouseenter', () => {
      if (!sidebar?.classList.contains('collapsed') || !floatingTooltip) return;
      floatingTooltip.textContent = 'Apagar Servidor Local';
      const rect = btnShutdown.getBoundingClientRect();
      const top = rect.top + (rect.height / 2) - 14;
      const left = rect.right + 10;
      floatingTooltip.style.top = `${Math.max(8, top)}px`;
      floatingTooltip.style.left = `${left}px`;
      floatingTooltip.classList.add('visible');
    });

    btnShutdown.addEventListener('mouseleave', () => {
      if (floatingTooltip) floatingTooltip.classList.remove('visible');
    });

    btnShutdown.addEventListener('click', () => {
      showConfirmModal(
        'Apagar Servidor Local',
        '¿Deseas detener el servidor local de MochilaLista Admin? Podrás volver a abrirlo en 1 clic desde tu Escritorio.',
        async () => {
          try {
            const res = await fetch('/api/system/shutdown', { method: 'POST' });
            if (res.status === 423) {
              showToast('La sesión está bloqueada con PIN. Desbloquea la consola para apagar.', 'error');
              return;
            }
            if (res.ok) {
              renderShutdownSuccessScreen();
            } else {
              const err = await res.text();
              showToast('No se pudo apagar el servidor: ' + err, 'error');
            }
          } catch (_) {
            // El proceso local cierra el socket al apagarse; esto confirma detención exitosa
            renderShutdownSuccessScreen();
          }
        },
        true
      );
    });
  }
}

function renderShutdownSuccessScreen() {
  document.body.innerHTML = `
    <div style="min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #0b0f19; color: #f8fafc; font-family: system-ui, -apple-system, sans-serif; text-align: center; padding: 24px;">
      <div style="width: 64px; height: 64px; border-radius: 50%; background: rgba(239, 68, 68, 0.15); border: 1px solid rgba(239, 68, 68, 0.3); display: flex; align-items: center; justify-content: center; margin-bottom: 20px;">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M18.36 6.64a9 9 0 1 1-12.73 0"></path>
          <line x1="12" y1="2" x2="12" y2="12"></line>
        </svg>
      </div>
      <h2 style="font-size: 22px; font-weight: 700; margin-bottom: 8px;">Servidor administrativo detenido con éxito</h2>
      <p style="font-size: 14px; color: #94a3b8; max-width: 440px; line-height: 1.6; margin-bottom: 24px;">El proceso local se ha apagado de forma segura y todos los datos han sido preservados en disco. Ya puedes cerrar esta pestaña del navegador.</p>
      <button onclick="try { window.close(); } catch(e) {}" style="background: #1e293b; color: #e2e8f0; border: 1px solid #334155; padding: 10px 22px; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.2s ease;">Cerrar Pestaña</button>
    </div>
  `;
  try { window.close(); } catch (_) {}
}

// =================== TEMA OSCURO / CLARO & EXPORTAR ===================
function initTheme() {
  const savedTheme = localStorage.getItem('ml_admin_theme') || 'dark';
  applyTheme(savedTheme);

  document.getElementById('btnThemeToggle')?.addEventListener('click', () => {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    applyTheme(next);
  });

  document.getElementById('btnExportCsv')?.addEventListener('click', () => {
    window.open('/api/clients/export-csv', '_blank');
    showToast('Exportando cartera a CSV con codificación Excel UTF-8...', 'info');
  });
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('ml_admin_theme', theme);
  const cfgSel = document.getElementById('cfgDefaultTheme');
  if (cfgSel && cfgSel.value !== theme) cfgSel.value = theme;
}

// =================== FASE 1: ARQUITECTURA DE DOBLE ESTADO (SANDBOX VS PROD) ===================
function initModeSwitcher() {
  const btnSandbox = document.getElementById('btnModeSandbox');
  const btnProd = document.getElementById('btnModeProd');
  const btnReset = document.getElementById('btnResetSandbox');

  btnSandbox?.addEventListener('click', () => switchMode('sandbox'));
  btnProd?.addEventListener('click', () => switchMode('prod'));

  btnReset?.addEventListener('click', () => {
    showConfirmModal(
      'Restaurar Datos de Prueba (Sandbox)',
      '¿Deseas restaurar la cartera de clientes y versiones de prueba a su estado inicial? Esta acción solo afecta al entorno Sandbox.',
      async () => {
        try {
          const res = await fetch('/api/system/reset-sandbox', { method: 'POST' });
          if (!res.ok) throw new Error('Error al restaurar sandbox');
          const data = await res.json();
          showToast(data.message || 'Datos de prueba restaurados.', 'success');
          await loadDashboard();
          await loadClients();
          await loadReleases();
          await loadReleaseMatrix();
          await loadFinances();
          await loadBackups();
        } catch (e) {
          showToast('Error: ' + e.message, 'error');
        }
      }
    );
  });
}

let _isSwitchingMode = false;

async function loadSystemMode() {
  try {
    const res = await fetch('/api/system/mode', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) return;
    const data = await res.json();
    currentMode = data.mode || 'sandbox';
    updateModeUI();
  } catch (e) {
    console.error('Error al cargar modo del sistema:', e);
  }
}

async function switchMode(newMode) {
  if (newMode === currentMode || _isSwitchingMode) return;
  _isSwitchingMode = true;

  const modeSwitcher = document.getElementById('modeSwitcher') || document.querySelector('.mode-switcher');
  if (modeSwitcher) modeSwitcher.classList.add('switching');

  try {
    // 1. Limpieza atómica de drawers, modales y referencias del entorno previo
    drawerReturnState = null;
    closeClient360Drawer();
    closeModal('modalWaComposer');
    currentWaComposerClientId = null;
    document.querySelectorAll('.modal-overlay.open').forEach(m => m.classList.remove('open'));

    currentDrawerClientId = null;
    currentQuickQrClientId = null;
    currentHistoryClientId = null;

    const licClientSel = document.getElementById('licClientSelect');
    if (licClientSel) licClientSel.value = '';
    updateGeneratorRightColumn(null);
    updateClientSummaryCard();
    updateLiveLicenseProjection();

    currentSearchQuery = '';
    const searchInput = document.getElementById('searchClientsInput');
    if (searchInput) searchInput.value = '';

    currentClientFilter = 'all';
    document.querySelectorAll('.chip-filter').forEach(c => c.classList.remove('active'));
    document.querySelector('.chip-filter[data-filter="all"]')?.classList.add('active');

    // 2. Coordinación estricta con el backend y confirmación de sincronización
    const res = await fetch('/api/system/mode', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-App-Mode': newMode
      },
      body: JSON.stringify({ mode: newMode }),
    });

    if (!res.ok) throw new Error('Error al cambiar de modo');
    const data = await res.json();
    currentMode = data.mode || newMode;
    updateModeUI();

    showToast(
      currentMode === 'sandbox'
        ? 'Entorno activo: Modo Pruebas (Sandbox).'
        : 'Entorno activo: Modo Real (Producción).',
      'info'
    );

    // 3. Recarga limpia coordinada de todos los datos del entorno activo
    // Cargar releases primero para sincronización inmediata de semver y contadores CRM
    await loadReleases();
    await Promise.allSettled([
      loadDashboard(),
      loadClients(),
      loadReleaseMatrix(),
      loadFinances(),
      loadBackups(),
    ]);

    // 4. Forzar re-renderizado inmediato de la pestaña activa si corresponde
    const activeTabBtn = document.querySelector('.nav-tab.active');
    const activeTabKey = activeTabBtn ? activeTabBtn.dataset.tab : 'tabDashboard';
    if (activeTabKey === 'tabClients') {
      renderClientsTable();
    } else if (activeTabKey === 'tabFinances') {
      renderFinancesTable();
    }
  } catch (e) {
    showToast('Error al cambiar modo: ' + e.message, 'error');
  } finally {
    _isSwitchingMode = false;
    if (modeSwitcher) modeSwitcher.classList.remove('switching');
  }
}

function updateModeUI() {
  const btnSandbox = document.getElementById('btnModeSandbox');
  const btnProd = document.getElementById('btnModeProd');
  const banner = document.getElementById('sandboxBanner');
  const btnReset = document.getElementById('btnResetSandbox');
  const appHeader = document.querySelector('.app-header');
  const kpiSubtitle = document.getElementById('kpiActiveClientsSubtitle');

  if (currentMode === 'sandbox') {
    btnSandbox?.classList.add('active', 'mode-sandbox');
    btnSandbox?.classList.remove('mode-prod');
    btnProd?.classList.remove('active', 'mode-sandbox');
    btnProd?.classList.add('mode-prod');

    if (banner) banner.style.display = 'block';
    if (btnReset) btnReset.style.display = 'inline-flex';

    if (appHeader) {
      appHeader.classList.add('sandbox-mode');
      appHeader.classList.remove('prod-mode');
    }
    if (kpiSubtitle) {
      kpiSubtitle.textContent = 'En pruebas (Sandbox)';
    }
  } else {
    btnProd?.classList.add('active', 'mode-prod');
    btnProd?.classList.remove('mode-sandbox');
    btnSandbox?.classList.remove('active', 'mode-prod');
    btnSandbox?.classList.add('mode-sandbox');

    if (banner) banner.style.display = 'none';
    if (btnReset) btnReset.style.display = 'none';

    if (appHeader) {
      appHeader.classList.add('prod-mode');
      appHeader.classList.remove('sandbox-mode');
    }
    if (kpiSubtitle) {
      kpiSubtitle.textContent = 'En producción (Real)';
    }
  }
}

// =================== 1. DASHBOARD FINANCIERO & MICRO-GRÁFICOS SVG ===================
async function loadDashboard() {
  try {
    const res = await fetch('/api/dashboard', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar dashboard');
    const data = await res.json();

    document.getElementById('kpiRevenueMonth').textContent = `S/ ${data.totalRevenueMonth.toFixed(2)}`;
    document.getElementById('kpiRevenueTotal').textContent = `S/ ${data.totalRevenueAccumulated.toFixed(2)}`;
    document.getElementById('kpiActiveClients').textContent = data.totalActiveClients;
    const kpiProspectsEl = document.getElementById('kpiProspects');
    if (kpiProspectsEl) {
      kpiProspectsEl.textContent = data.prospectClients !== undefined ? data.prospectClients : 0;
    }
    document.getElementById('kpiExpiringSoon').textContent = data.expiringSoonClients;
    document.getElementById('kpiExpired').textContent = data.expiredClients;
    document.getElementById('kpiPerpetual').textContent = data.perpetualClients;
    document.getElementById('kpiOutdated').textContent = data.outdatedAppClients;

    // Tabla de acciones urgentes
    const tbody = document.getElementById('urgentTableBody');
    tbody.innerHTML = '';

    if (!data.urgentActions || data.urgentActions.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1.5rem;">No hay licencias por vencer en los próximos 7 días.</td></tr>';
    } else {
      data.urgentActions.forEach(action => {
        const tr = document.createElement('tr');
        const cleanPhone = (action.phone || '').replace(/[^0-9]/g, '');
        const msgText = renderConfigTemplate('expiring_reminder', {
          titular: action.owner_name,
          negocio: action.business_name,
          dias: action.days_left,
          vencimiento: action.expires_date ? action.expires_date.substring(0, 10) : 'Próximamente',
          device_id: action.current_device_id,
        });
        const waLink = `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(msgText)}`;

        tr.innerHTML = `
          <td><strong>${escapeHtml(action.business_name)}</strong></td>
          <td>${escapeHtml(action.owner_name)}</td>
          <td><span class="device-id-badge" title="Hardware ID (ANDROID_ID)">${escapeHtml(action.current_device_id)}</span></td>
          <td><span class="badge badge-yellow">⏳ ${action.days_left} día(s)</span></td>
          <td>${action.expires_date ? action.expires_date.substring(0, 10) : '-'}</td>
          <td>
            <button type="button" class="btn btn-wa btn-sm" onclick="openWhatsAppComposer('${action.client_id}', 'expiring')" title="Abrir Compositor de WhatsApp">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:14px; height:14px; margin-right:4px;"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>
              <span>Avisar por WhatsApp</span>
            </button>
          </td>
        `;
        tbody.appendChild(tr);
      });
    }

    // Cargar finanzas si están vacías para alimentar el gráfico de ingresos
    if (globalFinances.length === 0) {
      try {
        const finRes = await fetch('/api/finances');
        if (finRes.ok) globalFinances = await finRes.json();
      } catch (_) { }
    }

    // Renderizar los 2 Micro-Gráficos SVG Nativos
    renderMonthlyRevenueChart(globalFinances);
    renderPlanDistributionChart(globalClients);
  } catch (e) {
    console.error('Error al cargar dashboard:', e);
  }
}

// 1.1 Micro-Gráfico SVG: Evolución de Ingresos Mensuales
function renderMonthlyRevenueChart(payments = []) {
  const container = document.getElementById('chartMonthlyRevenue');
  if (!container) return;

  const pList = (payments && payments.length > 0) ? payments : globalFinances;

  if (!pList || pList.length === 0) {
    container.innerHTML = `
      <div class="chart-empty-state">
        <svg style="width:36px; height:36px; color:var(--text-muted); opacity:0.6;" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <span>Sin movimientos contables registrados</span>
        <small style="color:var(--text-muted); font-size:0.75rem;">Los cobros aparecerán aquí en tiempo real.</small>
      </div>
    `;
    return;
  }

  const monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
  const monthsData = [];
  const now = new Date();

  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    monthsData.push({
      key: key,
      label: `${monthNames[d.getMonth()]} ${String(d.getFullYear()).slice(2)}`,
      total: 0,
    });
  }

  pList.forEach(p => {
    if (!p.date) return;
    const pKey = p.date.substring(0, 7);
    const mObj = monthsData.find(m => m.key === pKey);
    if (mObj) {
      mObj.total += (parseFloat(p.amount) || 0);
    }
  });

  const maxTotal = Math.max(100, ...monthsData.map(m => m.total));
  const svgWidth = 460;
  const svgHeight = 210;
  const chartTop = 25;
  const chartBottom = 165;
  const chartHeight = chartBottom - chartTop;
  const barWidth = 38;
  const barGap = (svgWidth - 60 - (barWidth * 6)) / 5;

  let barsSvg = '';
  monthsData.forEach((m, idx) => {
    const x = 30 + idx * (barWidth + barGap);
    const h = (m.total / maxTotal) * chartHeight;
    const y = chartBottom - h;
    const amtLabel = m.total > 0 ? `S/ ${Number(m.total).toFixed(2)}` : 'S/ 0';

    barsSvg += `
      <g class="chart-bar" tabindex="0">
        <title>${m.label}: S/ ${Number(m.total).toFixed(2)}</title>
        <rect x="${x}" y="${y}" width="${barWidth}" height="${Math.max(4, h)}" rx="6" fill="url(#revGrad)" opacity="${m.total > 0 ? '1' : '0.2'}"/>
        <text x="${x + barWidth / 2}" y="${Math.max(15, y - 6)}" text-anchor="middle" font-size="10" font-weight="700" fill="var(--text-primary)">${amtLabel}</text>
        <text x="${x + barWidth / 2}" y="${chartBottom + 18}" text-anchor="middle" font-size="11" font-weight="600" fill="var(--text-secondary)">${m.label}</text>
      </g>
    `;
  });

  container.innerHTML = `
    <svg viewBox="0 0 ${svgWidth} ${svgHeight}" class="svg-chart">
      <defs>
        <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#10b981"/>
          <stop offset="100%" stop-color="#059669"/>
        </linearGradient>
      </defs>
      <line x1="15" y1="${chartBottom}" x2="${svgWidth - 15}" y2="${chartBottom}" stroke="var(--border-color)" stroke-width="1"/>
      <line x1="15" y1="${chartTop + chartHeight / 2}" x2="${svgWidth - 15}" y2="${chartTop + chartHeight / 2}" stroke="var(--border-color)" stroke-width="1" stroke-dasharray="4"/>
      ${barsSvg}
    </svg>
  `;
}

// 1.2 Micro-Gráfico SVG: Distribución de Cartera por Plan (Donut Chart)
function renderPlanDistributionChart(clients = []) {
  const container = document.getElementById('chartPlanDistribution');
  if (!container) return;

  const cList = (clients && clients.length > 0) ? clients : globalClients;
  if (!cList || cList.length === 0) {
    container.innerHTML = `
      <div class="chart-empty-state">
        <svg style="width:36px; height:36px; color:var(--text-muted); opacity:0.6;" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M12 2a10 10 0 0 1 10 10h-10z"/></svg>
        <span>Sin clientes registrados</span>
        <small style="color:var(--text-muted); font-size:0.75rem;">Agrega clientes para visualizar la distribución.</small>
      </div>
    `;
    return;
  }

  const planCounts = {
    MENSUAL: { label: 'Mensual', count: 0, color: '#2563eb' },
    TRIMESTRAL: { label: 'Trimestral', count: 0, color: '#06b6d4' },
    SEMESTRAL: { label: 'Semestral', count: 0, color: '#10b981' },
    ANUAL: { label: 'Anual', count: 0, color: '#f59e0b' },
    PERPETUO: { label: 'Perpetuo', count: 0, color: '#8b5cf6' },
    EXTENSION_CORTESIA: { label: 'Cortesía', count: 0, color: '#d97706' },
    PROSPECTO: { label: 'Prospecto', count: 0, color: '#6366f1' },
    TRIAL: { label: 'Trial', count: 0, color: '#64748b' },
    OTROS: { label: 'Otros', count: 0, color: '#94a3b8' },
  };

  let totalCount = 0;
  cList.forEach(c => {
    const p = (c.license_type || 'MENSUAL').toUpperCase();
    const s = (c.license_status || '').toUpperCase();
    if (p.includes('PERPETUO')) {
      planCounts.PERPETUO.count++;
      totalCount++;
    } else if (p.includes('CORTESIA') || p.includes('EXTENSION_CORTESIA') || s === 'EXTENSION_CORTESIA') {
      planCounts.EXTENSION_CORTESIA.count++;
      totalCount++;
    } else if (p === 'PROSPECTO' || s === 'PROSPECTO') {
      planCounts.PROSPECTO.count++;
      totalCount++;
    } else if (planCounts[p]) {
      planCounts[p].count++;
      totalCount++;
    } else if (p.includes('TRIAL')) {
      planCounts.TRIAL.count++;
      totalCount++;
    } else {
      planCounts.OTROS.count++;
      totalCount++;
    }
  });

  const baseTotal = totalCount > 0 ? totalCount : 1;
  const radius = 62;
  const circumference = 2 * Math.PI * radius;
  let accumulatedOffset = 0;
  let circlesSvg = '';
  let legendHtml = '<div class="donut-legend-wrap">';

  for (const [key, item] of Object.entries(planCounts)) {
    if (item.count === 0) continue;
    const pct = (item.count / baseTotal);
    const strokeDash = pct * circumference;
    const strokeOffset = circumference - accumulatedOffset;
    accumulatedOffset += strokeDash;

    circlesSvg += `
      <circle class="donut-segment" cx="95" cy="100" r="${radius}" fill="none" stroke="${item.color}" stroke-width="26"
        stroke-dasharray="${strokeDash} ${circumference - strokeDash}"
        stroke-dashoffset="${strokeOffset}">
        <title>${item.label}: ${item.count} (${Math.round(pct * 100)}%)</title>
      </circle>
    `;

    legendHtml += `
      <div class="donut-legend-item">
        <span class="donut-legend-dot" style="background:${item.color};"></span>
        <span class="donut-legend-name">${item.label}</span>
        <span class="donut-legend-pct">${item.count} (${Math.round(pct * 100)}%)</span>
      </div>
    `;
  }
  legendHtml += '</div>';

  container.innerHTML = `
    <div style="display:flex; align-items:center; justify-content:center; width:100%; gap:1.5rem; flex-wrap:wrap;">
      <svg width="190" height="200" viewBox="0 0 190 200">
        <g transform="rotate(-90 95 100)">
          <circle cx="95" cy="100" r="${radius}" fill="none" stroke="var(--bg-hover)" stroke-width="26"/>
          ${circlesSvg}
        </g>
        <text x="95" y="96" text-anchor="middle" font-size="24" font-weight="800" fill="var(--text-primary)">${totalCount}</text>
        <text x="95" y="114" text-anchor="middle" font-size="10" font-weight="700" fill="var(--text-muted)" letter-spacing="0.5">CLIENTES</text>
      </svg>
      <div style="flex:1; min-width:180px;">
        ${legendHtml}
      </div>
    </div>
  `;
}

// 1.3 Eventos de Clic en KPI Cards para Filtrar CRM o Cambiar de Pestaña
function initDashboardKpiClickEvents() {
  const cards = document.querySelectorAll('[data-kpi-filter]');
  cards.forEach(card => {
    card.addEventListener('click', () => {
      const filter = card.dataset.kpiFilter;
      if (!filter) return;

      currentClientFilter = filter;

      document.querySelectorAll('.filter-chip').forEach(chip => {
        if (chip.dataset.filter === filter) {
          chip.classList.add('active');
        } else {
          chip.classList.remove('active');
        }
      });

      const tabs = document.querySelectorAll('.nav-tab');
      tabs.forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

      const clientTab = document.querySelector('[data-tab="tabClients"]');
      clientTab?.classList.add('active');
      document.getElementById('tabClients')?.classList.add('active');

      const viewNameEl = document.getElementById('currentViewName');
      if (viewNameEl) viewNameEl.textContent = 'Cartera CRM';

      renderClientsTable();
      showToast(`Filtrando clientes por: ${filter.toUpperCase()}`, 'info');
    });
  });

  // Acceso directo desde KPI de ingresos hacia Finanzas & Respaldos
  const tabCards = document.querySelectorAll('[data-kpi-tab]');
  tabCards.forEach(card => {
    card.addEventListener('click', () => {
      const targetTab = card.dataset.kpiTab;
      if (!targetTab) return;
      const tabBtn = document.querySelector(`.nav-tab[data-tab="${targetTab}"]`);
      if (tabBtn) tabBtn.click();
    });
  });
}

// =================== 2. CRM DE CLIENTES & BUSCADOR OMNICANAL ===================
function initOmnichannelSearch() {
  const searchInput = document.getElementById('inputClientSearch');
  const clearBtn = document.getElementById('btnClearClientSearch');

  searchInput?.addEventListener('input', (e) => {
    currentSearchQuery = e.target.value.trim().toLowerCase();
    if (clearBtn) {
      clearBtn.style.display = currentSearchQuery.length > 0 ? 'block' : 'none';
    }
    renderClientsTable();
  });

  clearBtn?.addEventListener('click', () => {
    if (searchInput) {
      searchInput.value = '';
      currentSearchQuery = '';
      clearBtn.style.display = 'none';
      renderClientsTable();
      searchInput.focus();
    }
  });
}

async function loadClients() {
  try {
    const res = await fetch('/api/clients', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar clientes');
    globalClients = await res.json();

    // Poblar selector en Generador
    const licSelect = document.getElementById('licClientSelect');
    const currentVal = licSelect ? licSelect.value : '';
    if (licSelect) {
      licSelect.innerHTML = '<option value="">-- Elige un cliente --</option>';

      globalClients.forEach(c => {
        const opt = document.createElement('option');
        opt.value = c.id;
        opt.textContent = `${c.business_name} (${c.owner_name}) — ${c.current_device_id}`;
        licSelect.appendChild(opt);
      });

      if (currentVal && globalClients.some(c => c.id === currentVal)) {
        licSelect.value = currentVal;
      } else {
        licSelect.value = '';
        currentSelectedClientId = null;
      }
    }

    updateFilterCounts();
    renderClientsTable();
    updateClientSummaryCard();
    updateLiveLicenseProjection();
    const activeClient = globalClients.find(c => c.id === licSelect?.value);
    updateGeneratorRightColumn(activeClient || null);
  } catch (e) {
    console.error('Error al cargar clientes:', e);
  }
}

// =================== COMPARADOR SEMVER RIGUROSO & RELEASES (FASE 4) ===================
function compareSemVer(v1, v2) {
  const parse = (v) => {
    if (!v) return [0, 0, 0];
    const clean = String(v).trim().replace(/^[vV]/, '').split('+')[0].split('-')[0];
    const parts = clean.split('.');
    return [
      parseInt(parts[0], 10) || 0,
      parseInt(parts[1], 10) || 0,
      parseInt(parts[2], 10) || 0,
    ];
  };
  const p1 = parse(v1);
  const p2 = parse(v2);
  for (let i = 0; i < 3; i++) {
    if (p1[i] !== p2[i]) return p1[i] - p2[i];
  }
  return 0;
}

function getLatestPublishedVersion() {
  if (!globalReleases || globalReleases.length === 0) return null;
  let latest = null;
  for (const r of globalReleases) {
    const vn = (r.version_name || '').trim();
    if (vn) {
      if (!latest || compareSemVer(vn, latest) > 0) {
        latest = vn;
      }
    }
  }
  return latest;
}

function updateFilterCounts() {
  const now = new Date();
  let countActive = 0;
  let countExpiring = 0;
  let countExpired = 0;
  let countPerpetual = 0;
  let countProspect = 0;
  let countOutdated = 0;

  const latestVer = getLatestPublishedVersion();

  globalClients.forEach(c => {
    const plan = (c.license_type || 'MENSUAL').toUpperCase();
    const status = (c.license_status || '').toUpperCase();
    const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
    const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
    const expDate = c.license_expires ? new Date(c.license_expires) : null;

    if (isProspect) {
      countProspect++;
    } else if (isPerp) {
      countPerpetual++;
      countActive++;
    } else if (expDate) {
      const diffDays = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
      if (diffDays < 0) {
        countExpired++;
      } else if (diffDays <= 7) {
        countExpiring++;
        countActive++;
      } else {
        countActive++;
      }
    }

    const clientVer = (c.installed_version || '').trim();
    if (!isProspect && latestVer && clientVer.length > 0) {
      if (compareSemVer(clientVer, latestVer) < 0) {
        countOutdated++;
      }
    }
  });

  const setTxt = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
  setTxt('countAll', globalClients.length);
  setTxt('countActive', countActive);
  setTxt('countExpiring', countExpiring);
  setTxt('countExpired', countExpired);
  setTxt('countPerpetual', countPerpetual);
  setTxt('countProspect', countProspect);
  setTxt('countOutdated', countOutdated);
}

// =================== HELPER CENTRALIZADO: BADGE DE ESTADO DEL CLIENTE ===================
function getClientStatusBadge(client, options = {}) {
  const asObject = options.asObject || false;
  if (!client) {
    return asObject
      ? { className: 'badge badge-outline', text: '-', isProspect: false, isTrial: false, isPerp: false, diffDays: 0 }
      : '<span class="badge badge-outline">-</span>';
  }

  const plan = (client.license_type || 'MENSUAL').toUpperCase();
  const status = (client.license_status || '').toUpperCase();
  const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
  const isTrial = plan === 'TRIAL';
  const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const diffDays = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : 999;

  let className = 'badge badge-green';
  let text = 'Activa';

  if (isProspect) {
    className = 'badge badge-prospect';
    text = 'Prospecto';
  } else if (isTrial) {
    className = 'badge badge-yellow';
    const trialDays = (client.trial_days_remaining !== undefined && client.trial_days_remaining !== null)
      ? client.trial_days_remaining
      : (diffDays >= 0 ? diffDays : 0);
    text = `Trial (${trialDays}d)`;
  } else if (isPerp) {
    className = 'badge badge-purple';
    text = 'Perpetua';
  } else if (diffDays < 0) {
    className = 'badge badge-red';
    text = 'Vencida';
  } else if (diffDays <= 7) {
    className = 'badge badge-yellow';
    text = `Vence en ${diffDays}d`;
  } else {
    className = 'badge badge-green';
    text = 'Activa';
  }

  if (asObject) {
    return { className, text, isProspect, isTrial, isPerp, diffDays };
  }
  return `<span class="${className}">${text}</span>`;
}

function renderClientsTable() {
  const tbody = document.getElementById('clientsTableBody');
  tbody.innerHTML = '';

  const now = new Date();
  const latestVer = getLatestPublishedVersion();

  const filtered = globalClients.filter(c => {
    // 1. Filtro por chip de estado
    if (currentClientFilter !== 'all') {
      const plan = (c.license_type || 'MENSUAL').toUpperCase();
      const status = (c.license_status || '').toUpperCase();
      const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
      const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
      const expDate = c.license_expires ? new Date(c.license_expires) : null;
      const diffDays = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : 999;

      if (currentClientFilter === 'prospect' && !isProspect) return false;
      if (currentClientFilter === 'active' && (isProspect || !(isPerp || diffDays >= 0))) return false;
      if (currentClientFilter === 'expiring' && (isProspect || !(!isPerp && diffDays >= 0 && diffDays <= 7))) return false;
      if (currentClientFilter === 'expired' && (isProspect || !(!isPerp && diffDays < 0))) return false;
      if (currentClientFilter === 'perpetual' && (isProspect || !isPerp)) return false;
      if (currentClientFilter === 'outdated') {
        const clientVer = (c.installed_version || '').trim();
        if (isProspect || !latestVer || !clientVer || compareSemVer(clientVer, latestVer) >= 0) {
          return false;
        }
      }
    }

    // 2. Filtro omnicanal por texto
    if (currentSearchQuery) {
      const matchText = [
        c.id,
        c.business_name,
        c.owner_name,
        c.document_id,
        c.phone,
        c.current_device_id,
        c.installed_version,
        c.license_type,
        c.notes,
      ].filter(Boolean).join(' ').toLowerCase();

      if (!matchText.includes(currentSearchQuery)) {
        return false;
      }
    }

    return true;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No se encontraron clientes para este filtro o criterio de búsqueda.</td></tr>';
    return;
  }

  filtered.forEach(c => {
    const tr = document.createElement('tr');
    const badgeInfo = getClientStatusBadge(c, { asObject: true });
    const statusBadge = `<span class="${badgeInfo.className}">${escapeHtml(badgeInfo.text)}</span>`;

    const plan = (c.license_type || 'MENSUAL').toUpperCase();
    const isProspect = badgeInfo.isProspect;
    const isTrial = badgeInfo.isTrial;
    const isPerp = badgeInfo.isPerp;
    const expDate = c.license_expires ? new Date(c.license_expires) : null;

    const expText = isProspect
      ? (c.expected_subscription_date ? `Seguim: ${escapeHtml(c.expected_subscription_date)}` : 'Sin vencimiento')
      : (isPerp ? 'De por Vida' : (c.license_expires ? c.license_expires.substring(0, 10) : 'Sin fecha'));

    const clientVer = (c.installed_version || '').trim();
    const isOutdated = !isProspect && !!latestVer && clientVer.length > 0 && compareSemVer(clientVer, latestVer) < 0;

    let verBadge = '';
    if (isProspect || !clientVer) {
      verBadge = '<span class="badge badge-outline" style="font-size:0.68rem; padding:1px 6px; margin-top:2px; color:var(--text-muted);">Sin versión</span>';
    } else if (!latestVer) {
      verBadge = '<span class="badge badge-green" style="font-size:0.68rem; padding:1px 6px; margin-top:2px;">Al día</span>';
    } else if (isOutdated) {
      verBadge = '<span class="badge badge-yellow" style="font-size:0.68rem; padding:1px 6px; margin-top:2px;">Update pend.</span>';
    } else {
      verBadge = '<span class="badge badge-green" style="font-size:0.68rem; padding:1px 6px; margin-top:2px;">Al día</span>';
    }

    const isPendingDev = !c.current_device_id || c.current_device_id === 'PENDIENTE' || c.current_device_id === 'ML-0000';
    const deviceMarkup = (isProspect && isPendingDev)
      ? '<span class="badge badge-unlinked">Sin vincular</span>'
      : `<span class="device-id-badge" title="Hardware ID derivado de Settings.Secure.ANDROID_ID">
          <span>${escapeHtml(c.current_device_id)}</span>
          <button class="btn-micro" onclick="copyDeviceIdToClipboard('${escapeHtml(c.current_device_id)}')" title="Copiar Hardware ID">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:12px; height:12px;"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
          </button>
        </span>`;

    const pendingBonusBadge = (c.ai_pending_bonus && c.ai_pending_bonus > 0)
      ? `<div class="badge-pending-bonus" title="Bono acordado pendiente de emitir en token Ed25519">+${c.ai_pending_bonus} IA por emitir</div>`
      : '';

    // Saldo real en celular vs Bono pendiente
    const realAiBalance = (c.ai_reported_balance !== undefined && c.ai_reported_balance !== null)
      ? c.ai_reported_balance
      : (c.ai_accumulated_credits ?? c.ai_extra_credits ?? 0);
    const hasAiCredits = realAiBalance > 0 || (c.ai_extra_credits || 0) > 0;
    const aiDisplay = (c.ai_reported_balance !== undefined && c.ai_reported_balance !== null)
      ? `${c.ai_reported_balance} IA`
      : ((c.ai_extra_credits || 0) > 0 ? `+${c.ai_extra_credits} IA` : '0 IA');

    const planSuffix = (!isProspect && !isTrial)
      ? `<small style="font-weight:700; color:var(--text-secondary);">(${escapeHtml(c.license_type || 'MENSUAL')})</small>`
      : '';

    tr.innerHTML = `
      <td style="white-space: nowrap; font-family: var(--font-mono);"><strong>${escapeHtml(c.id)}</strong></td>
      <td>
        <div><strong>${escapeHtml(c.business_name)}</strong></div>
        <div style="font-size:0.8rem; color:var(--text-secondary); margin-top:2px;">
          ${escapeHtml(c.owner_name)}${c.document_id ? ' • ' + escapeHtml(c.document_id) : ''}
        </div>
        ${c.notes ? `<div style="font-size:0.75rem; color:var(--text-muted); margin-top:2px;">${escapeHtml(c.notes)}</div>` : ''}
      </td>
      <td>
        <div style="display:flex; align-items:center; gap:0.35rem; flex-wrap:wrap;">
          ${statusBadge}
          ${planSuffix}
        </div>
        <div style="font-size:0.78rem; color:var(--text-secondary); margin-top:3px; font-family:var(--font-mono);">
          ${expText}
        </div>
      </td>
      <td>
        ${deviceMarkup}
      </td>
      <td>
        <div style="font-weight:600;">${clientVer ? 'v' + escapeHtml(clientVer) : '<span style="color:var(--text-muted); font-size:0.85rem;">-</span>'}</div>
        ${verBadge}
      </td>
      <td>
        ${hasAiCredits
        ? `<span class="badge badge-purple">${aiDisplay}</span>`
        : '<span class="badge badge-outline" style="color:var(--text-muted); border:1px solid var(--border-color);">0 IA</span>'}
        ${pendingBonusBadge}
      </td>
      <td style="text-align:center; white-space: nowrap;">
        <div class="crm-actions-cell">
          <button type="button" class="btn-crm-action" onclick="openClient360Drawer('${c.id}', 'drawerTabOverview')" title="Ficha 360° del Cliente">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
          </button>
          <button type="button" class="btn-crm-action primary" onclick="openClient360Drawer('${c.id}', 'drawerTabQr')" title="Ver QR y Credencial Oficial">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
          </button>
          <button type="button" class="btn-crm-action wa" onclick="openWhatsAppComposer('${c.id}')" title="Enviar WhatsApp (Compositor)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>
          </button>
          <button type="button" class="btn-crm-action" onclick="selectClientForLicense('${c.id}')" title="Emitir Licencia Ed25519">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
          </button>
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function copyDeviceIdToClipboard(deviceId) {
  navigator.clipboard.writeText(deviceId).then(() => {
    showToast(`Hardware ID copiado: ${deviceId}`, 'info');
  }).catch(() => {
    showToast(`Hardware ID: ${deviceId}`, 'info');
  });
}

function selectClientForLicense(clientId, options = {}) {
  drawerReturnState = null;
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

  const studioTab = document.querySelector('[data-tab="tabLicenseStudio"]');
  studioTab?.classList.add('active');
  document.getElementById('tabLicenseStudio')?.classList.add('active');

  const licSelect = document.getElementById('licClientSelect');
  if (licSelect) {
    licSelect.value = clientId;
    const client = globalClients.find(c => c.id === clientId);

    // Si el cliente tiene bono IA acordado pendiente de emitir o se solicitó preferBonus
    if (options.preferBonus && client && (client.ai_pending_bonus || 0) > 0) {
      const planSel = document.getElementById('licPlanSelect');
      if (planSel) planSel.value = 'BONO_IA_PERSONALIZADO';
      const aiInput = document.getElementById('licCustomAiAmount');
      if (aiInput) aiInput.value = client.ai_pending_bonus;
      updateEcoModeUI('free');
    } else if (client && (client.ai_pending_bonus || 0) > 0) {
      const bonusInput = document.getElementById('licCustomAiBonus');
      if (bonusInput) {
        bonusInput.value = client.ai_pending_bonus;
      }
    }

    updateClientSummaryCard();
    updateLiveLicenseProjection();
    updateGeneratorRightColumn(client || null);
  }
}

// =================== 3. GENERADOR DE LICENCIAS ED25519 & ESTUDIO INTERACTIVO ===================
function initLicenseStudioEvents() {
  const planSelect = document.getElementById('licPlanSelect');
  const clientSelect = document.getElementById('licClientSelect');

  planSelect?.addEventListener('change', () => {
    updateLiveLicenseProjection();
  });

  clientSelect?.addEventListener('change', () => {
    updateClientSummaryCard();
    updateLiveLicenseProjection();
    const activeClient = globalClients.find(c => c.id === clientSelect.value);
    updateGeneratorRightColumn(activeClient || null);
  });

  // Modalidad económica de Bono IA (Gratis vs Cobro)
  document.getElementById('ecoModeFree')?.addEventListener('change', () => {
    updateEcoModeUI('free');
    updateLiveLicenseProjection();
  });
  document.getElementById('ecoModePaid')?.addEventListener('change', () => {
    updateEcoModeUI('paid');
    updateLiveLicenseProjection();
  });

  // Chips rápidos de escaneos IA (+20, +50, +100, +150)
  document.querySelectorAll('.ai-chip-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const val = parseInt(btn.getAttribute('data-ai')) || 20;
      const input = document.getElementById('licCustomAiAmount');
      if (input) {
        input.value = val;
        document.querySelectorAll('.ai-chip-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        updateSuggestedPrice();
        updateLiveLicenseProjection();
      }
    });
  });

  // Input manual de escaneos IA
  document.getElementById('licCustomAiAmount')?.addEventListener('input', () => {
    const val = parseInt(document.getElementById('licCustomAiAmount')?.value) || 0;
    document.querySelectorAll('.ai-chip-btn').forEach(b => {
      if (parseInt(b.getAttribute('data-ai')) === val) {
        b.classList.add('active');
      } else {
        b.classList.remove('active');
      }
    });
    updateSuggestedPrice();
    updateLiveLicenseProjection();
  });

  // Botón aplicar precio sugerido
  document.getElementById('btnApplySuggestedPrice')?.addEventListener('click', () => {
    const suggested = updateSuggestedPrice();
    const amountInput = document.getElementById('licPaymentAmount');
    if (amountInput) {
      amountInput.value = suggested.toFixed(2);
      showToast(`Precio sugerido aplicado: S/ ${suggested.toFixed(2)}`, 'info');
      updateLiveLicenseProjection();
    }
  });

  // Acordeón de ajustes comerciales personalizados
  const btnToggleCustom = document.getElementById('btnToggleCustomSettings');
  const customContent = document.getElementById('licCustomContent');
  const accordionArrow = document.getElementById('accordionArrow');

  btnToggleCustom?.addEventListener('click', () => {
    const isOpen = customContent.classList.toggle('open');
    if (accordionArrow) accordionArrow.textContent = isOpen ? '▲' : '▼';
  });

  // Escuchar inputs para recalcular proyección en vivo
  document.getElementById('licCustomDays')?.addEventListener('input', updateLiveLicenseProjection);
  document.getElementById('licCustomAiBonus')?.addEventListener('input', updateLiveLicenseProjection);
  document.getElementById('licCustomComputationMode')?.addEventListener('change', updateLiveLicenseProjection);
  document.getElementById('licPaymentAmount')?.addEventListener('input', updateLiveLicenseProjection);
  document.getElementById('licPaymentMethod')?.addEventListener('change', updateLiveLicenseProjection);
  document.getElementById('licCustomExactDate')?.addEventListener('change', () => {
    const exactDateVal = document.getElementById('licCustomExactDate').value;
    if (exactDateVal) {
      const targetDate = new Date(exactDateVal + 'T23:59:59');
      const now = new Date();
      const diff = Math.max(1, Math.ceil((targetDate - now) / (1000 * 60 * 60 * 24)));
      document.getElementById('licCustomDays').value = diff;
    }
    updateLiveLicenseProjection();
  });

  // Botón de emisión
  document.getElementById('btnGenerateLicense')?.addEventListener('click', generateLicense);

  // Botones de acción sobre la licencia emitida / activa
  document.getElementById('btnCopyCode')?.addEventListener('click', () => {
    const code = document.getElementById('generatedCodeDisplay')?.textContent?.trim();
    if (!code) return;
    navigator.clipboard.writeText(code).then(() => {
      showToast('¡Código copiado al portapapeles!', 'success');
    });
  });

  document.getElementById('btnDownloadQr')?.addEventListener('click', downloadQrCode);
  document.getElementById('btnDownloadCredential')?.addEventListener('click', downloadCredential);
  document.getElementById('btnCopyCredentialImage')?.addEventListener('click', copyCredentialToClipboard);

  document.getElementById('btnSendWa')?.addEventListener('click', () => {
    const clientId = document.getElementById('licClientSelect')?.value;
    const client = globalClients.find(c => c.id === clientId);
    const token = document.getElementById('generatedCodeDisplay')?.textContent?.trim();
    if (!client || !token) {
      showToast('No hay una licencia activa seleccionada para enviar.', 'warning');
      return;
    }
    const cleanPhone = (client.phone || '').replace(/[^0-9]/g, '');
    const msgText = renderConfigTemplate('license_issued', {
      titular: client.owner_name || 'Comerciante',
      negocio: client.business_name || 'tu negocio',
      plan: document.getElementById('metaGenPlan')?.textContent || client.license_type || 'Licencia',
      dias: '-',
      vencimiento: document.getElementById('metaGenExpires')?.textContent || client.license_expires || 'Activa',
      creditos_ia: document.getElementById('metaGenAi')?.textContent || client.ai_reported_balance || 0,
      codigo: token,
      device_id: client.current_device_id || 'ML-0000',
    });
    window.open(`https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(msgText)}`, '_blank');
  });

  // Botón Auditar en el Inspector
  document.getElementById('btnAuditInInspector')?.addEventListener('click', () => {
    const token = document.getElementById('generatedCodeDisplay')?.textContent?.trim();
    if (!token) return;

    const tabs = document.querySelectorAll('.nav-tab');
    tabs.forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

    const inspectTab = document.querySelector('[data-tab="tabInspector"]');
    inspectTab?.classList.add('active');
    document.getElementById('tabInspector')?.classList.add('active');

    const inspectInput = document.getElementById('inspectTokenInput');
    if (inspectInput) {
      inspectInput.value = token;
      inspectToken();
      showToast('Token transferido al Inspector Forense.', 'info');
    }
  });
}

function updateEcoModeUI(mode) {
  const isFree = mode === 'free';
  const freeRadio = document.getElementById('ecoModeFree');
  const paidRadio = document.getElementById('ecoModePaid');
  const lblFree = document.getElementById('lblEcoModeFree');
  const lblPaid = document.getElementById('lblEcoModePaid');
  const boxSuggested = document.getElementById('boxSuggestedPrice');
  const grpAmount = document.getElementById('grpLicPaymentAmount');
  const grpMethod = document.getElementById('grpLicPaymentMethod');
  const grpRef = document.getElementById('grpLicPaymentRef');
  const amountInput = document.getElementById('licPaymentAmount');

  if (freeRadio) freeRadio.checked = isFree;
  if (paidRadio) paidRadio.checked = !isFree;

  if (lblFree) {
    lblFree.style.borderColor = isFree ? 'var(--primary)' : 'var(--border-color)';
    lblFree.style.background = isFree ? 'rgba(37,99,235,0.1)' : 'var(--bg-secondary)';
  }
  if (lblPaid) {
    lblPaid.style.borderColor = !isFree ? 'var(--primary)' : 'var(--border-color)';
    lblPaid.style.background = !isFree ? 'rgba(37,99,235,0.1)' : 'var(--bg-secondary)';
  }

  if (isFree) {
    if (amountInput) amountInput.value = '0.00';
    if (grpAmount) grpAmount.style.opacity = '0.5';
    if (grpMethod) grpMethod.style.opacity = '0.5';
    if (grpRef) grpRef.style.opacity = '0.5';
    if (boxSuggested) boxSuggested.style.display = 'none';
  } else {
    if (grpAmount) grpAmount.style.opacity = '1';
    if (grpMethod) grpMethod.style.opacity = '1';
    if (grpRef) grpRef.style.opacity = '1';
    if (boxSuggested) boxSuggested.style.display = 'block';
    updateSuggestedPrice();
  }
}

function updateSuggestedPrice() {
  const scans = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
  const cfgRecarga = ownerConfig?.catalog?.RECARGA_IA_150;
  const basePrice = (cfgRecarga?.price !== undefined) ? cfgRecarga.price : 20.0;
  const baseScans = (cfgRecarga?.ai_credits !== undefined) ? cfgRecarga.ai_credits : 150;

  const unitRate = basePrice / baseScans;
  let suggested = scans * unitRate;

  // Redondeo comercial al medio punto más cercano (piso S/ 1.00)
  suggested = Math.round(suggested * 2) / 2;
  if (suggested < 1.0) suggested = 1.0;

  const txtCalc = document.getElementById('txtSuggestedCalc');
  const valPrice = document.getElementById('valSuggestedPrice');
  if (txtCalc) txtCalc.textContent = `Tasa base: S/ ${basePrice.toFixed(2)} por ${baseScans} IA (${scans} × S/ ${unitRate.toFixed(3)})`;
  if (valPrice) valPrice.textContent = `S/ ${suggested.toFixed(2)}`;

  return suggested;
}

function updateClientSummaryCard() {
  const clientId = document.getElementById('licClientSelect').value;
  const card = document.getElementById('licClientSummaryCard');
  if (!card) return;

  const client = globalClients.find(c => c.id === clientId);
  if (!client) {
    card.style.display = 'none';
    return;
  }

  card.style.display = 'flex';
  document.getElementById('sumBizName').textContent = client.business_name || 'Negocio Sin Nombre';
  document.getElementById('sumOwnerName').textContent = `• Titular: ${client.owner_name || '-'}`;
  document.getElementById('sumDeviceId').textContent = client.current_device_id || 'ML-0000';
  document.getElementById('sumPlanNonce').textContent = `${(client.license_type || 'MENSUAL').replace(/_/g, ' ')} (Nonce #${client.next_nonce || 1})`;

  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const badgeInfo = getClientStatusBadge(client, { asObject: true });
  const isPerp = badgeInfo.isPerp;
  const isProspect = badgeInfo.isProspect;
  const isTrial = badgeInfo.isTrial;

  const sumStatusBadge = document.getElementById('sumStatusBadge');
  if (sumStatusBadge) {
    sumStatusBadge.className = badgeInfo.className;
    sumStatusBadge.textContent = badgeInfo.text.toUpperCase();
  }

  if (isProspect) {
    document.getElementById('sumExpiresDate').textContent = client.expected_subscription_date
      ? `Seguimiento: ${client.expected_subscription_date}`
      : 'Sin vencimiento (Prospecto)';
  } else if (isTrial) {
    const trialDays = (client.trial_days_remaining !== undefined && client.trial_days_remaining !== null)
      ? client.trial_days_remaining
      : (badgeInfo.diffDays >= 0 ? badgeInfo.diffDays : 0);
    document.getElementById('sumExpiresDate').textContent = `${client.license_expires ? client.license_expires.substring(0, 10) : 'Trial'} (${trialDays}d restantes)`;
  } else if (isPerp) {
    document.getElementById('sumExpiresDate').textContent = 'Vitalicia (De por Vida)';
  } else if (expDate) {
    const diff = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
    document.getElementById('sumExpiresDate').textContent = `${client.license_expires.substring(0, 10)} (${diff}d restantes)`;
  } else {
    document.getElementById('sumExpiresDate').textContent = 'Sin fecha';
  }

  const realAi = (client.ai_reported_balance !== undefined && client.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client.ai_accumulated_credits ?? client.ai_extra_credits ?? 0);
  const pendingAi = client.ai_pending_bonus || 0;
  let aiText = `${realAi} IA en celular`;
  if (pendingAi > 0) {
    aiText += ` (+${pendingAi} IA pendientes de emitir)`;
  } else if ((client.ai_extra_credits || 0) > 0) {
    aiText = `+${client.ai_extra_credits} escaneos IA vitalicios`;
  }
  document.getElementById('sumAiCredits').textContent = aiText;
  document.getElementById('sumInstalledVersion').textContent = `v${client.installed_version || '9.35.0'}`;
  document.getElementById('sumUpdatesUntil').textContent = client.updates_until ? client.updates_until.substring(0, 10) : 'No configurada';
}

function updateLiveLicenseProjection() {
  const planSelect = document.getElementById('licPlanSelect');
  const clientSelect = document.getElementById('licClientSelect');
  const amountInput = document.getElementById('licPaymentAmount');
  const impactBadge = document.getElementById('licPlanImpactBadge');
  const projectionText = document.getElementById('licPlanProjection');
  const panelCustomAi = document.getElementById('panelCustomAiBonus');

  if (!planSelect || !impactBadge || !projectionText) return;

  const plan = planSelect.value;
  const clientId = clientSelect?.value;
  const client = globalClients.find(c => c.id === clientId);

  // Mostrar / Ocultar panel interactivo de Bono IA Personalizado
  if (plan === 'BONO_IA_PERSONALIZADO') {
    if (panelCustomAi) panelCustomAi.style.display = 'block';
  } else {
    if (panelCustomAi) panelCustomAi.style.display = 'none';
  }

  const selectedOpt = planSelect.options[planSelect.selectedIndex];
  const cfgPlan = ownerConfig?.catalog?.[plan];

  if (plan !== 'BONO_IA_PERSONALIZADO') {
    const defaultPrice = (cfgPlan?.price !== undefined) ? cfgPlan.price.toFixed(2) : (selectedOpt?.getAttribute('data-price') || '35.00');
    if (amountInput && document.activeElement !== amountInput) {
      amountInput.value = defaultPrice;
    }
    const grpAmount = document.getElementById('grpLicPaymentAmount');
    const grpMethod = document.getElementById('grpLicPaymentMethod');
    const grpRef = document.getElementById('grpLicPaymentRef');
    if (grpAmount) grpAmount.style.opacity = '1';
    if (grpMethod) grpMethod.style.opacity = '1';
    if (grpRef) grpRef.style.opacity = '1';
  } else {
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    if (isFree && amountInput) {
      amountInput.value = '0.00';
    }
  }

  impactBadge.style.display = 'block';
  projectionText.style.display = 'block';
  impactBadge.className = 'plan-impact-badge';

  const now = new Date();
  let baseDate = now;

  const customMode = document.getElementById('licCustomComputationMode')?.value || 'cumulative';
  const customDaysVal = parseInt(document.getElementById('licCustomDays')?.value) || 0;
  const customAiBonus = parseInt(document.getElementById('licCustomAiBonus')?.value) || 0;

  if (customMode === 'cumulative' && client && client.license_expires) {
    const exp = new Date(client.license_expires);
    if (exp > now && client.license_type !== 'TRIAL_VENCIDO') {
      baseDate = exp;
    }
  }

  const formatDateStr = (d) => {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${day}/${m}/${y}`;
  };

  const currentAi = (client?.ai_reported_balance !== undefined && client?.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client?.ai_accumulated_credits ?? client?.ai_extra_credits ?? 0);
  const currentNonce = client?.next_nonce || 1;

  // 1. Proyección de Bono IA Personalizado (0 días)
  if (plan === 'BONO_IA_PERSONALIZADO') {
    impactBadge.classList.add('recharge');
    const customScans = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    const paymentAmt = parseFloat(amountInput?.value) || 0;
    const paymentMth = document.getElementById('licPaymentMethod')?.value || 'Yape';

    impactBadge.innerHTML = `💡 <strong>Bono / Recarga IA Personalizada:</strong> Otorga <strong>+${customScans} créditos de escaneos IA</strong> vitalicios directos al celular sin alterar días ni suscripción.`;

    const clientExpStr = client?.license_expires ? client.license_expires.substring(0, 10) : 'Sin fecha';
    const isTrial = client?.license_type === 'TRIAL' || client?.trial_days_remaining !== null;
    const trialDays = client?.trial_days_remaining ?? '-';
    const vigenciaTxt = isTrial ? `Trial (${trialDays}d restantes)` : clientExpStr;

    const projectedAi = currentAi + customScans;
    const financeTxt = isFree
      ? 'Cortesía / Sin costo (S/ 0.00) — No afectará ingresos contables'
      : `Cobro acordado: S/ ${paymentAmt.toFixed(2)} vía ${escapeHtml(paymentMth)}`;

    projectionText.innerHTML = `
      <div style="margin-bottom:0.35rem;">📅 <strong>Vigencia:</strong> Mantiene fecha actual (${vigenciaTxt}) (Sin cambios de días).</div>
      <div style="margin-bottom:0.35rem;">⚡ <strong>Créditos IA:</strong> Saldo celular (${currentAi} IA) + Esta emisión (+${customScans} IA) = <strong>Total proyectado (${projectedAi} IA)</strong>.</div>
      <div style="margin-bottom:0.35rem;">🔐 <strong>Nonce Criptográfico:</strong> Nonce actual (#${currentNonce}) → <strong>Siguiente (#${currentNonce + 1})</strong>.</div>
      <div style="font-size:0.82rem; color:var(--text-secondary);">💰 <strong>Impacto Financiero:</strong> ${financeTxt}.</div>
    `;
    return;
  }

  // 2. Si hay días personalizados configurados en el acordeón
  if (customDaysVal > 0) {
    impactBadge.innerHTML = `⚙️ <strong>Ajuste Personalizado:</strong> Se otorgarán <strong>+${customDaysVal} días</strong> directos (${customMode === 'from_today' ? 'contando desde hoy' : 'acumulativos'})` +
      (customAiBonus > 0 ? ` + <strong>${customAiBonus} escaneos IA de regalo</strong>.` : '.');
    const projCustom = new Date(baseDate.getTime() + customDaysVal * 24 * 60 * 60 * 1000);
    const projAi = currentAi + customAiBonus;
    projectionText.innerHTML = `
      <div style="margin-bottom:0.35rem;">📅 <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projCustom)}.</div>
      ${customAiBonus > 0 ? `<div style="margin-bottom:0.35rem;">⚡ <strong>Créditos IA:</strong> ${currentAi} IA + ${customAiBonus} IA = <strong>${projAi} IA</strong> proyectados.</div>` : ''}
      <div>🔐 <strong>Nonce Criptográfico:</strong> Nonce #${currentNonce} → <strong>Nonce #${currentNonce + 1}</strong>.</div>
    `;
    return;
  }

  // 3. Proyección según planes de catálogo
  switch (plan) {
    case 'RECARGA_IA_150': {
      const aiCredits = (cfgPlan?.ai_credits !== undefined) ? cfgPlan.ai_credits : 150;
      impactBadge.classList.add('recharge');
      impactBadge.innerHTML = `💡 <strong>Impacto:</strong> Conservará su plan actual y su fecha de vigencia. Se sumarán <strong>+${aiCredits} créditos de escaneos IA</strong> acumulativos sin fecha de caducidad.`;
      const projAi = currentAi + aiCredits;
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">📅 <strong>Vigencia:</strong> Mantiene su fecha actual (${client?.license_expires ? client.license_expires.substring(0, 10) : 'Activa'}) (Sin alteración de suscripción).</div>
        <div style="margin-bottom:0.35rem;">⚡ <strong>Créditos IA:</strong> Saldo celular (${currentAi} IA) + Recarga (+${aiCredits} IA) = <strong>${projAi} IA</strong> proyectados.</div>
        <div>🔐 <strong>Nonce Criptográfico:</strong> Nonce #${currentNonce} → <strong>Nonce #${currentNonce + 1}</strong>.</div>
      `;
      break;
    }
    case 'PERPETUO_LIBERADO': {
      const updateMonths = (cfgPlan?.updates_window_months !== undefined) ? cfgPlan.updates_window_months : 12;
      impactBadge.classList.add('perpetual');
      impactBadge.innerHTML = `⭐ <strong>Impacto:</strong> Licencia Perpetua Liberada. Acceso ilimitado de por vida (+99,999 días) con ${updateMonths} meses de actualizaciones de funciones incluidas.`;
      const updatesTarget = new Date(now.getTime() + updateMonths * 30 * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">📅 <strong>Vigencia:</strong> Vitalicia de por vida • <strong>Pase de Updates hasta:</strong> ${formatDateStr(updatesTarget)}.</div>
        <div>🔐 <strong>Nonce Criptográfico:</strong> Nonce #${currentNonce} → <strong>Nonce #${currentNonce + 1}</strong>.</div>
      `;
      break;
    }
    case 'PASE_ACTUALIZACION_ANUAL': {
      const passDays = (cfgPlan?.days !== undefined && cfgPlan.days > 0) ? cfgPlan.days : 365;
      impactBadge.classList.add('perpetual');
      impactBadge.innerHTML = `🔄 <strong>Impacto:</strong> Extiende por <strong>+${passDays} días adicionales</strong> la ventana de nuevas versiones y herramientas para clientes perpetuos.`;
      const currentUpdates = client && client.updates_until ? new Date(client.updates_until) : now;
      const baseUp = currentUpdates > now ? currentUpdates : now;
      const newUpdates = new Date(baseUp.getTime() + passDays * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">📅 <strong>Nueva Ventana de Updates:</strong> Hasta el ${formatDateStr(newUpdates)} (+${passDays} días).</div>
        <div>🔐 <strong>Nonce Criptográfico:</strong> Nonce #${currentNonce} → <strong>Nonce #${currentNonce + 1}</strong>.</div>
      `;
      break;
    }
    case 'EXTENSION_CORTESIA': {
      const cortesiaDays = (cfgPlan?.days !== undefined && cfgPlan.days > 0) ? cfgPlan.days : 7;
      impactBadge.innerHTML = `⏳ <strong>Impacto:</strong> Otorga <strong>+${cortesiaDays} días de gracia temporal</strong> (S/ 0.00) para resolver cobranza en trámite o emergencias operativas.`;
      const projCortesia = new Date(baseDate.getTime() + cortesiaDays * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">📅 <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projCortesia)} (+${cortesiaDays} días de gracia).</div>
        <div>🔐 <strong>Nonce Criptográfico:</strong> Nonce #${currentNonce} → <strong>Nonce #${currentNonce + 1}</strong>.</div>
      `;
      break;
    }
    default: {
      const days = (cfgPlan?.days !== undefined) ? cfgPlan.days : (parseInt(selectedOpt?.getAttribute('data-days')) || 30);
      impactBadge.innerHTML = `📅 <strong>Impacto:</strong> Renovación acumulativa sin pérdida de días. Se sumarán <strong>+${days} días</strong> directos al saldo remanente.`;
      const projRegular = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);

      const basePlanAi = (cfgPlan?.ai_credits !== undefined)
        ? cfgPlan.ai_credits
        : (plan === 'TRIMESTRAL' ? 180 : (plan === 'SEMESTRAL' ? 450 : (plan === 'ANUAL' ? 1200 : 50)));
      const totalToAdd = basePlanAi + customAiBonus;
      const projAi = currentAi + totalToAdd;
      const aiBreakdown = customAiBonus > 0
        ? `Saldo celular (${currentAi} IA) + Plan (+${basePlanAi} IA) + Regalo (+${customAiBonus} IA) = <strong>${projAi} IA</strong> proyectados.`
        : `Saldo celular (${currentAi} IA) + Cuota del plan (+${basePlanAi} IA) = <strong>${projAi} IA</strong> proyectados.`;

      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">📅 <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projRegular)} (Cero pérdida de días).</div>
        <div style="margin-bottom:0.35rem;">⚡ <strong>Créditos IA:</strong> ${aiBreakdown}</div>
        <div>🔐 <strong>Nonce Criptográfico:</strong> Nonce #${currentNonce} → <strong>Nonce #${currentNonce + 1}</strong>.</div>
      `;
      break;
    }
  }
}

const updatePlanImpactAndProjection = updateLiveLicenseProjection;

function renderSelectedGeneratorLicense(code, client, isLatest = true) {
  if (!code) return;

  const placeholder = document.getElementById('resultPlaceholder');
  const content = document.getElementById('resultContent');
  const badgeStatus = document.getElementById('licResultBadgeStatus');
  const displayCode = document.getElementById('generatedCodeDisplay');

  if (placeholder) placeholder.style.display = 'none';
  if (content) content.style.display = 'flex';

  if (badgeStatus) {
    badgeStatus.style.display = 'inline-flex';
    if (isLatest) {
      badgeStatus.className = 'badge badge-green';
      badgeStatus.textContent = 'ACTIVA / VIGENTE';
    } else {
      badgeStatus.className = 'badge badge-gray';
      badgeStatus.textContent = 'HISTÓRICA / REEMPLAZADA';
    }
  }

  const token = code.token || '';
  if (displayCode) displayCode.textContent = token;

  // Actualizar metadatos en grid
  const metaPlan = document.getElementById('metaGenPlan');
  const metaNonce = document.getElementById('metaGenNonce');
  const metaEmitted = document.getElementById('metaGenEmitted');
  const metaExpires = document.getElementById('metaGenExpires');
  const metaAi = document.getElementById('metaGenAi');
  const metaDevice = document.getElementById('metaGenDeviceId');

  const pPlan = code.plan || client?.license_type || 'MENSUAL';
  if (metaPlan) metaPlan.textContent = pPlan.replace(/_/g, ' ');
  if (metaNonce) metaNonce.textContent = code.nonce !== undefined ? `#${code.nonce}` : '-';

  const emittedDate = code.emitted_at || code.created_at;
  if (metaEmitted) {
    metaEmitted.textContent = emittedDate ? emittedDate.substring(0, 10) : new Date().toISOString().substring(0, 10);
  }

  if (metaExpires) {
    if (pPlan === 'PERPETUO_LIBERADO') {
      metaExpires.textContent = 'Vitalicia';
    } else if (pPlan === 'BONO_IA_PERSONALIZADO' || pPlan === 'RECARGA_IA_150') {
      metaExpires.textContent = client?.license_expires ? client.license_expires.substring(0, 10) : 'Sin alteración';
    } else if (code.expires_at) {
      metaExpires.textContent = code.expires_at.substring(0, 10);
    } else if (code.expires_result) {
      metaExpires.textContent = code.expires_result.substring(0, 10);
    } else if (client?.license_expires) {
      metaExpires.textContent = client.license_expires.substring(0, 10);
    } else {
      metaExpires.textContent = '-';
    }
  }

  const aiCreds = code.ai_credits ?? code.ai_extra_credits ?? 0;
  if (metaAi) metaAi.textContent = `+${aiCreds} IA`;
  if (metaDevice) metaDevice.textContent = code.device_id || client?.current_device_id || 'ML-0000';

  // Renderizar QR Code
  const qrContainer = document.getElementById('qrContainer');
  lastGeneratedQr = renderSafeQrCode(qrContainer, token, 230);

  // Renderizar Canvas PNG de Alta Resolución tras render del QR
  setTimeout(() => {
    renderCredentialCanvas(code, client);
  }, 150);
}

function updateGeneratorRightColumn(client) {
  const resultPlaceholder = document.getElementById('resultPlaceholder');
  const resultContent = document.getElementById('resultContent');
  const historySec = document.getElementById('genHistorySection');
  const badgeStatus = document.getElementById('licResultBadgeStatus');
  const historyList = document.getElementById('genHistoryList');
  const historyCount = document.getElementById('genHistoryCount');

  if (!client) {
    if (resultPlaceholder) {
      resultPlaceholder.innerHTML = 'Selecciona un cliente y presiona <strong>Firmar y Emitir Licencia</strong> para generar el código, el QR y la credencial oficial.';
      resultPlaceholder.style.display = 'block';
    }
    if (resultContent) resultContent.style.display = 'none';
    if (historySec) historySec.style.display = 'none';
    if (badgeStatus) badgeStatus.style.display = 'none';
    return;
  }

  const history = client.generated_codes_history || [];
  if (history.length === 0) {
    if (resultPlaceholder) {
      resultPlaceholder.innerHTML = `El cliente <strong>${escapeHtml(client.business_name)}</strong> aún no tiene licencias Ed25519 emitidas.<br><span style="font-size:0.85rem; color:var(--text-secondary); margin-top:0.4rem; display:inline-block;">Configura un plan a la izquierda y presiona <strong>Firmar Criptográficamente y Emitir Licencia</strong> para emitir su primera credencial oficial.</span>`;
      resultPlaceholder.style.display = 'block';
    }
    if (resultContent) resultContent.style.display = 'none';
    if (historySec) historySec.style.display = 'none';
    if (badgeStatus) badgeStatus.style.display = 'none';
    return;
  }

  // Ordenar historial: el más reciente primero (mayor nonce o timestamp descendente)
  const sorted = [...history].sort((a, b) => {
    const nA = a.nonce !== undefined ? a.nonce : 0;
    const nB = b.nonce !== undefined ? b.nonce : 0;
    if (nB !== nA) return nB - nA;
    const tA = new Date(a.emitted_at || a.created_at || 0).getTime();
    const tB = new Date(b.emitted_at || b.created_at || 0).getTime();
    return tB - tA;
  });

  // Mostrar la licencia más reciente como activa/vigente
  renderSelectedGeneratorLicense(sorted[0], client, true);

  // Renderizar la lista histórica debajo
  if (historySec) historySec.style.display = 'block';
  if (historyCount) historyCount.textContent = sorted.length;
  if (historyList) {
    historyList.innerHTML = '';
    sorted.forEach((item, idx) => {
      const isVigente = idx === 0;
      const itemEl = document.createElement('div');
      itemEl.className = `gen-history-item ${isVigente ? 'active' : ''}`;
      const dateStr = (item.emitted_at || item.created_at || '').substring(0, 10) || '-';
      const planStr = (item.plan || 'MENSUAL').replace(/_/g, ' ');
      const nonceStr = item.nonce !== undefined ? `#${item.nonce}` : '';
      const aiVal = item.ai_credits ?? item.ai_extra_credits ?? 0;
      const aiBadge = aiVal > 0 ? `<span class="badge badge-purple" style="font-size:0.7rem; padding:1px 6px; margin-left:0.4rem;">+${aiVal} IA</span>` : '';

      itemEl.innerHTML = `
        <div style="display:flex; justify-content:space-between; align-items:center; width:100%;">
          <div>
            <strong style="color:var(--text-primary); font-size:0.85rem;">${escapeHtml(planStr)} ${nonceStr}</strong>
            <span style="font-size:0.75rem; color:var(--text-muted); margin-left:0.4rem;">${dateStr}</span>
            ${aiBadge}
          </div>
          <span class="badge ${isVigente ? 'badge-green' : 'badge-gray'}" style="font-size:0.72rem;">
            ${isVigente ? 'Vigente' : 'Histórica'}
          </span>
        </div>
      `;

      itemEl.addEventListener('click', () => {
        document.querySelectorAll('.gen-history-item').forEach(el => el.classList.remove('active'));
        itemEl.classList.add('active');
        renderSelectedGeneratorLicense(item, client, isVigente);
      });

      historyList.appendChild(itemEl);
    });
  }
}

/**
 * Exporta un código QR con margen reglamentario blanco puro (#FFFFFF) de 32px (Quiet Zone).
 * Resuelve la imposibilidad de detección en cámaras móviles y decodificadores de galería.
 * @param {HTMLElement|string} sourceContainer - Contenedor del canvas/img o elemento directo
 * @param {string} fileName - Nombre de descarga del archivo PNG
 * @param {number} marginPx - Tamaño del margen perimetral blanco en píxeles (default: 32)
 */
function downloadQrWithQuietZone(sourceContainer, fileName, marginPx = 32) {
  let container = null;
  if (typeof sourceContainer === 'string') {
    container = document.querySelector(sourceContainer);
  } else if (sourceContainer instanceof HTMLElement) {
    container = sourceContainer;
  }

  if (!container) {
    showToast('No hay código QR disponible para descargar.', 'warning');
    return;
  }

  const sourceEl = container.tagName && (container.tagName.toLowerCase() === 'canvas' || container.tagName.toLowerCase() === 'img')
    ? container
    : (container.querySelector('canvas') || container.querySelector('img'));

  if (!sourceEl) {
    showToast('No hay código QR disponible para descargar.', 'warning');
    return;
  }

  function doExport(srcCanvasOrImg, w, h) {
    const totalW = w + (marginPx * 2);
    const totalH = h + (marginPx * 2);
    const offscreen = document.createElement('canvas');
    offscreen.width = totalW;
    offscreen.height = totalH;
    const ctx = offscreen.getContext('2d');
    if (!ctx) return;
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, totalW, totalH);
    ctx.drawImage(srcCanvasOrImg, marginPx, marginPx, w, h);

    const a = document.createElement('a');
    a.download = fileName.endsWith('.png') ? fileName : `${fileName}.png`;
    a.href = offscreen.toDataURL('image/png');
    a.click();
    showToast('QR descargado con margen blanco reglamentario.', 'success');
  }

  if (sourceEl.tagName.toLowerCase() === 'canvas') {
    doExport(sourceEl, sourceEl.width, sourceEl.height);
  } else if (sourceEl.tagName.toLowerCase() === 'img') {
    if (sourceEl.complete && sourceEl.naturalWidth > 0) {
      doExport(sourceEl, sourceEl.naturalWidth, sourceEl.naturalHeight);
    } else {
      const img = new Image();
      img.onload = () => doExport(img, img.naturalWidth || 256, img.naturalHeight || 256);
      img.src = sourceEl.src;
    }
  }
}

function downloadQrCode() {
  downloadQrWithQuietZone('#qrContainer', `QR_MochilaLista_${Date.now()}.png`, 32);
}

async function generateLicense() {
  const clientId = document.getElementById('licClientSelect').value;
  if (!clientId) {
    showToast('Por favor selecciona un cliente de la lista.', 'warning');
    return;
  }

  const client = globalClients.find(c => c.id === clientId);
  const plan = document.getElementById('licPlanSelect').value;
  const isBonoIa = plan === 'BONO_IA_PERSONALIZADO';

  let paymentAmount = parseFloat(document.getElementById('licPaymentAmount').value) || 0;
  let paymentMethod = document.getElementById('licPaymentMethod').value;
  let paymentRef = document.getElementById('licPaymentRef').value.trim() || 'Op. Generada';

  let customAiBonus = parseInt(document.getElementById('licCustomAiBonus')?.value) || 0;

  if (isBonoIa) {
    const customAiAmount = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
    if (customAiAmount <= 0) {
      showToast('La cantidad de escaneos IA debe ser mayor a 0.', 'warning');
      return;
    }
    customAiBonus = customAiAmount;
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    if (isFree) {
      paymentAmount = 0.0;
      paymentMethod = 'Cortesia / Promocion';
      paymentRef = 'Bono Gratuito';
    }
  }

  // Parámetros de personalización libre
  const customDaysVal = parseInt(document.getElementById('licCustomDays')?.value) || null;
  const computationMode = document.getElementById('licCustomComputationMode')?.value || 'cumulative';
  const customExactDate = document.getElementById('licCustomExactDate')?.value || null;

  try {
    const res = await fetch('/api/licenses/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: clientId,
        plan: plan,
        payment_amount: paymentAmount,
        payment_method: paymentMethod,
        payment_ref: paymentRef,
        custom_days: customDaysVal,
        custom_ai_bonus: customAiBonus,
        ai_extra_credits: isBonoIa ? customAiBonus : undefined,
        computation_mode: computationMode,
        custom_exact_expiration: customExactDate,
      }),
    });

    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || 'Error al generar licencia');
    }

    const data = await res.json();

    // Actualizar clientes y dashboard
    await loadClients();
    await loadDashboard();

    const updatedClient = globalClients.find(c => c.id === clientId) || client || data.client;

    // Renderizar la licencia emitida como activa / vigente en la columna derecha
    renderSelectedGeneratorLicense(data, updatedClient, true);
    updateGeneratorRightColumn(updatedClient);

    showToast('¡Licencia Ed25519 emitida y firmada con éxito!', 'success');
  } catch (e) {
    showToast('Error al emitir licencia: ' + e.message, 'error');
  }
}

// =================== GENERADOR DE CREDENCIAL EN CANVAS (PNG @2x / 900x520) ===================
function renderCredentialCanvas(licenseData, client, targetCanvasId = 'credentialCanvas', qrContainerId = 'qrContainer') {
  const canvas = document.getElementById(targetCanvasId);
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  const width = canvas.width;
  const height = canvas.height;

  // 1. Fondo degradado ejecutivo
  const bgGrad = ctx.createLinearGradient(0, 0, width, height);
  bgGrad.addColorStop(0, '#090d16');
  bgGrad.addColorStop(0.5, '#0f172a');
  bgGrad.addColorStop(1, '#1e293b');
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, width, height);

  // 2. Patrón de líneas guilloche de seguridad
  ctx.strokeStyle = 'rgba(16, 185, 129, 0.06)';
  ctx.lineWidth = 1;
  for (let i = -width; i < width * 2; i += 24) {
    ctx.beginPath();
    ctx.moveTo(i, 0);
    ctx.lineTo(i + height, height);
    ctx.stroke();
  }

  // 3. Borde con acentos y cabecera
  ctx.strokeStyle = '#10b981';
  ctx.lineWidth = 4;
  ctx.strokeRect(8, 8, width - 16, height - 16);

  ctx.fillStyle = '#10b981';
  ctx.fillRect(8, 8, width - 16, 10);

  // 4. Encabezado Oficial
  ctx.fillStyle = '#10b981';
  ctx.font = 'bold 26px -apple-system, sans-serif';
  ctx.fillText('MOCHILALISTA POS', 36, 54);

  ctx.fillStyle = '#94a3b8';
  ctx.font = '600 13px -apple-system, sans-serif';
  ctx.fillText('LICENCIA OFICIAL AUTORIZADA • SISTEMA DE GESTIÓN COMERCIAL', 36, 76);

  // Sello legal superior derecho
  ctx.fillStyle = '#1e3a8a';
  ctx.fillRect(width - 290, 34, 254, 28);
  ctx.fillStyle = '#60a5fa';
  ctx.font = 'bold 11px monospace';
  ctx.fillText('VERIFICADA ED25519 • D.L. 822', width - 275, 52);

  // Línea divisoria
  ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)';
  ctx.beginPath();
  ctx.moveTo(36, 96);
  ctx.lineTo(width - 36, 96);
  ctx.stroke();

  // 5. Datos Comerciales del Cliente (Columna Izquierda)
  const bizName = client ? (client.business_name || 'Negocio Comercial') : 'Negocio Comercial';
  const ownerName = client ? (client.owner_name || 'Propietario') : 'Propietario';
  const docId = client && client.document_id ? `RUC/DNI: ${client.document_id}` : '';
  const deviceId = licenseData.device_id || (client ? client.current_device_id : 'ML-0000');
  const plan = licenseData.plan || 'MENSUAL';

  let vigencia = '30 días de vigencia';
  if (plan === 'PERPETUO_LIBERADO') vigencia = 'Vitalicia (De por Vida)';
  else if (plan === 'RECARGA_IA_150') vigencia = 'Sin vencimiento (Acumulativo)';
  else if (plan === 'BONO_IA_PERSONALIZADO') vigencia = 'Sin alterar suscripción (0 días)';
  else if (licenseData.client && licenseData.client.license_expires) {
    vigencia = `Vence: ${licenseData.client.license_expires.substring(0, 10)}`;
  } else if (licenseData.expires_result) {
    vigencia = `Vence: ${licenseData.expires_result.substring(0, 10)}`;
  }

  // Nombre de Negocio
  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 24px -apple-system, sans-serif';
  ctx.fillText(bizName.length > 28 ? bizName.substring(0, 26) + '...' : bizName, 36, 136);

  // Propietario
  ctx.fillStyle = '#cbd5e1';
  ctx.font = '14px -apple-system, sans-serif';
  ctx.fillText(`Titular: ${ownerName} ${docId ? '• ' + docId : ''}`, 36, 162);

  // Bloque Hardware ID (ANDROID_ID)
  ctx.fillStyle = '#1e293b';
  ctx.fillRect(36, 186, 260, 48);
  ctx.strokeStyle = '#334155';
  ctx.strokeRect(36, 186, 260, 48);

  ctx.fillStyle = '#94a3b8';
  ctx.font = '10px -apple-system, sans-serif';
  ctx.fillText('HARDWARE ID (ANDROID_ID)', 48, 204);

  ctx.fillStyle = '#38bdf8';
  ctx.font = 'bold 18px monospace';
  ctx.fillText(deviceId, 48, 226);

  // Plan y Vigencia
  ctx.fillStyle = '#94a3b8';
  ctx.font = '11px -apple-system, sans-serif';
  ctx.fillText('PLAN Y ESTADO:', 36, 264);

  ctx.fillStyle = plan === 'PERPETUO_LIBERADO' ? '#c084fc' : ((plan === 'RECARGA_IA_150' || plan === 'BONO_IA_PERSONALIZADO') ? '#34d399' : '#60a5fa');
  ctx.font = 'bold 18px -apple-system, sans-serif';
  ctx.fillText(plan.replace(/_/g, ' '), 36, 288);

  ctx.fillStyle = '#f1f5f9';
  ctx.font = '600 14px -apple-system, sans-serif';
  ctx.fillText(`📅 ${vigencia}`, 36, 312);

  // Cuota IA Acumulativa (Regla Plan 08/09)
  const baseScansMap = {
    TRIAL: 50,
    MENSUAL: 50,
    TRIMESTRAL: 180,
    SEMESTRAL: 450,
    ANUAL: 1200,
    PERPETUO_LIBERADO: 200,
    PASE_ACTUALIZACION_ANUAL: 100,
    RECARGA_IA_150: 150,
    BONO_IA_PERSONALIZADO: 0,
    EXTENSION_CORTESIA: 0,
  };
  const cfgPlan = ownerConfig?.catalog?.[plan];
  const baseScans = cfgPlan?.ai_credits !== undefined ? cfgPlan.ai_credits : (baseScansMap[plan] !== undefined ? baseScansMap[plan] : 50);
  const extraCredits = licenseData.ai_extra_credits || licenseData.ai_credits || (client ? client.ai_extra_credits : 0) || 0;
  const totalScans = plan === 'RECARGA_IA_150' ? 150 : (baseScans + extraCredits);
  let aiText = `+${totalScans} escaneos IA acumulativos vitalicios (o BYOK)`;
  if (plan === 'BONO_IA_PERSONALIZADO') {
    aiText = `+${extraCredits} escaneos IA sin caducidad (Bono)`;
  } else if (plan === 'RECARGA_IA_150') {
    aiText = '+150 escaneos IA sin vencimiento (Bolsa Acumulativa)';
  }
  ctx.fillStyle = '#94a3b8';
  ctx.font = '12px -apple-system, sans-serif';
  ctx.fillText(`⚡ Escáner IA: ${aiText}`, 36, 338);

  // Código de Acceso (Snippet)
  const token = licenseData.token || '';
  ctx.fillStyle = '#0f172a';
  ctx.fillRect(36, 360, 490, 44);
  ctx.strokeStyle = '#2563eb';
  ctx.strokeRect(36, 360, 490, 44);

  ctx.fillStyle = '#38bdf8';
  ctx.font = '12px monospace';
  const tokenSnippet = token.length > 56 ? token.substring(0, 54) + '...' : token;
  ctx.fillText(tokenSnippet, 46, 386);

  // 6. Tarjeta Blanca para el Código QR (Columna Derecha)
  const qrX = width - 290;
  const qrY = 120;
  const qrBoxSize = 254;

  ctx.fillStyle = '#ffffff';
  ctx.fillRect(qrX, qrY, qrBoxSize, qrBoxSize + 48);
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 2;
  ctx.strokeRect(qrX, qrY, qrBoxSize, qrBoxSize + 48);

  // Dibujar el QR desde el contenedor HTML designado
  const qrImg = document.querySelector(`#${qrContainerId} img`) || document.querySelector(`#${qrContainerId} canvas`);
  if (qrImg) {
    try {
      ctx.drawImage(qrImg, qrX + 17, qrY + 17, 220, 220);
    } catch (_) { }
  }

  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 11px -apple-system, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('ESCANEA CON LA APP PARA ACTIVAR', qrX + qrBoxSize / 2, qrY + qrBoxSize + 24);
  ctx.fillStyle = '#64748b';
  ctx.font = '10px -apple-system, sans-serif';
  ctx.fillText('Perfil > Licencia > Escanear QR', qrX + qrBoxSize / 2, qrY + qrBoxSize + 40);
  ctx.textAlign = 'left';

  // 7. Pie Legal de la Credencial
  ctx.fillStyle = '#475569';
  ctx.font = '11px -apple-system, sans-serif';
  const authorName = ownerConfig?.legal_identity?.author_full_name || 'Julio Angello Vasquez Navarro';
  const legalFramework = ownerConfig?.legal_identity?.legal_framework || 'Registrado ante INDECOPI bajo D.L. 822';
  ctx.fillText(`Autor y Titular Exclusivo: ${authorName} • ${legalFramework} • Lima, Perú`, 36, 458);

  ctx.fillStyle = '#334155';
  ctx.font = '10px monospace';
  ctx.fillText(`Firma Asimétrica: SHA-512/Ed25519 • Emisión: ${new Date().toLocaleString('es-PE')}`, 36, 478);
}

function downloadCredential() {
  const canvas = document.getElementById('credentialCanvas');
  if (!canvas) return;
  const clientId = document.getElementById('licClientSelect').value;
  const client = globalClients.find(c => c.id === clientId);
  const nameClean = (client ? client.business_name : 'Licencia').replace(/[^a-zA-Z0-9]/g, '_');

  const link = document.createElement('a');
  link.download = `Credencial_MochilaLista_${nameClean}_${Date.now()}.png`;
  link.href = canvas.toDataURL('image/png');
  link.click();
  showToast('Credencial PNG descargada en alta resolución.', 'success');
}

async function copyCredentialToClipboard() {
  const canvas = document.getElementById('credentialCanvas');
  if (!canvas) return;

  try {
    canvas.toBlob(async (blob) => {
      if (!blob) {
        showToast('No se pudo generar la imagen para el portapapeles.', 'error');
        return;
      }
      try {
        await navigator.clipboard.write([
          new ClipboardItem({ 'image/png': blob })
        ]);
        showToast('¡Credencial copiada al portapapeles! Pégala con Ctrl+V en WhatsApp Web.', 'success');
      } catch (err) {
        downloadCredential();
        showToast('El navegador requirió descarga directa del archivo PNG.', 'info');
      }
    }, 'image/png');
  } catch (e) {
    showToast('Error al copiar credencial: ' + e.message, 'error');
  }
}

// =================== MODAL RÁPIDO: VER QR / CREDENCIAL (FASE 4A) ===================
async function openQuickQrModal(clientId) {
  currentQuickQrClientId = clientId;
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  const titleEl = document.getElementById('quickQrTitle');
  const subEl = document.getElementById('quickQrSubtitle');
  if (titleEl) titleEl.textContent = `${client.business_name} — Credencial Oficial`;
  if (subEl) subEl.textContent = `Titular: ${client.owner_name} • Hardware ID: ${client.current_device_id} • Plan: ${(client.license_type || 'MENSUAL').replace(/_/g, ' ')}`;

  let token = '';
  let licenseData = {
    plan: client.license_type || 'MENSUAL',
    device_id: client.current_device_id,
    ai_extra_credits: client.ai_extra_credits || 0,
    client: client,
  };

  try {
    const res = await fetch(`/api/clients/${clientId}/history`);
    if (res.ok) {
      const history = await res.json();
      if (history.codes && history.codes.length > 0) {
        const lastCode = history.codes[history.codes.length - 1];
        token = lastCode.token;
        licenseData.token = token;
        licenseData.plan = lastCode.plan || licenseData.plan;
      }
    }
  } catch (err) {
    console.error('Error fetching client history for QR modal:', err);
  }

  if (!token) {
    token = `ML9-PENDIENTE-${client.current_device_id}`;
    licenseData.token = token;
  }

  const qrContainer = document.getElementById('quickQrContainer');
  lastQuickQr = renderSafeQrCode(qrContainer, token, 236);

  document.getElementById('quickQrCodeDisplay').textContent = token;

  setTimeout(() => {
    renderCredentialCanvas(licenseData, client, 'quickCredentialCanvas', 'quickQrContainer');
  }, 150);

  document.getElementById('btnQuickCopyCode').onclick = () => {
    navigator.clipboard.writeText(token).then(() => {
      showToast('¡Código copiado al portapapeles!', 'success');
    });
  };

  document.getElementById('btnQuickDownloadQr').onclick = () => {
    downloadQrWithQuietZone(qrContainer, `QR_MochilaLista_${client.current_device_id}_${Date.now()}.png`, 32);
  };

  document.getElementById('btnQuickCopyCredential').onclick = async () => {
    const canvas = document.getElementById('quickCredentialCanvas');
    if (!canvas) return;
    try {
      canvas.toBlob(async (blob) => {
        if (!blob) return;
        try {
          await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
          showToast('¡Credencial copiada al portapapeles! Pégala con Ctrl+V en WhatsApp Web.', 'success');
        } catch (_) {
          const a = document.createElement('a');
          a.download = `Credencial_${client.current_device_id}.png`;
          a.href = canvas.toDataURL('image/png');
          a.click();
          showToast('Credencial descargada como archivo PNG.', 'info');
        }
      }, 'image/png');
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  };

  document.getElementById('btnQuickDownloadCredential').onclick = () => {
    const canvas = document.getElementById('quickCredentialCanvas');
    if (!canvas) return;
    const a = document.createElement('a');
    a.download = `Credencial_MochilaLista_${client.current_device_id}_${Date.now()}.png`;
    a.href = canvas.toDataURL('image/png');
    a.click();
    showToast('Credencial oficial PNG descargada.', 'success');
  };

  const cleanPhone = (client.phone || '').replace(/[^0-9]/g, '');
  const tplKey = (client.license_type || '').toUpperCase() === 'TRIAL' ? 'trial_welcome' : 'license_issued';
  const msgText = renderConfigTemplate(tplKey, {
    titular: client.owner_name,
    negocio: client.business_name,
    plan: (client.license_type || 'MENSUAL').replace(/_/g, ' '),
    dias: '30',
    vencimiento: client.license_expires ? client.license_expires.substring(0, 10) : '30 días',
    creditos_ia: client.ai_extra_credits || 0,
    codigo: token,
    device_id: client.current_device_id,
  });
  const waMsg = encodeURIComponent(msgText);
  document.getElementById('btnQuickSendWa').href = `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${waMsg}`;

  document.getElementById('btnQuickAuditInInspector').onclick = () => {
    closeModal('modalQuickQr');
    const tabs = document.querySelectorAll('.nav-tab');
    tabs.forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

    const inspTab = document.querySelector('[data-tab="tabInspector"]');
    inspTab?.classList.add('active');
    document.getElementById('tabInspector')?.classList.add('active');

    const inp = document.getElementById('inspectTokenInput');
    if (inp) {
      inp.value = token;
      inspectToken();
    }
  };

  openModal('modalQuickQr');
}

// =================== DRAWER LATERAL: FICHA 360° DEL CLIENTE (FASE 4A + FASE 5) ===================
let drawerReturnState = null;
let currentDrawerTab = 'drawerTabOverview';

/**
 * Control inteligente del campo Ventana Updates en la Ficha 360°
 */
function updateDrawerEditPlanFields(plan) {
  const p = (plan || '').toUpperCase();
  const updatesInput = document.getElementById('drawerEditUpdates');
  if (!updatesInput) return;
  const isNoUpdates = (p === 'PROSPECTO' || p === 'TRIAL');
  if (isNoUpdates) {
    updatesInput.disabled = true;
    updatesInput.style.opacity = '0.5';
    updatesInput.style.cursor = 'not-allowed';
    updatesInput.title = 'No aplica para Trial o Prospecto';
    updatesInput.value = '';
  } else {
    updatesInput.disabled = false;
    updatesInput.style.opacity = '1';
    updatesInput.style.cursor = 'auto';
    updatesInput.title = '';
  }
}

/**
 * ==========================================================================
 * GENERADOR Y PERSONALIZADOR DE BOLETAS DE PAGO BOL-XXXX (FASE 5)
 * ==========================================================================
 */
let currentReceiptData = null;

function closeReceiptModal() {
  closeModal('modalPaymentReceipt');
}

/**
 * Resuelve y abre la Boleta de Pago con correlativo persistente (idempotente)
 */
async function openPaymentReceiptModal(clientId, paymentId) {
  try {
    const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}/receipt`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'No se pudo resolver la boleta de pago.');
    }
    const data = await res.json();
    currentReceiptData = data;
    populateReceiptUI(data);
    openModal('modalPaymentReceipt');
  } catch (e) {
    showToast('Error al abrir boleta: ' + e.message, 'error');
  }
}

function populateReceiptUI(data) {
  if (!data) return;
  const rc = data.receipt_config || {};
  const payment = data.payment || {};

  const titleInp = document.getElementById('rcInputTitle');
  if (titleInp) titleInp.value = rc.title || 'BOLETA DE PAGO ADMINISTRATIVA';
  const commInp = document.getElementById('rcInputCommercialName');
  if (commInp) commInp.value = rc.commercial_name || 'MochilaLista';
  const issuerInp = document.getElementById('rcInputIssuerName');
  if (issuerInp) issuerInp.value = rc.issuer_name || 'Julio Angello Vasquez Navarro';
  const docInp = document.getElementById('rcInputIssuerDoc');
  if (docInp) docInp.value = rc.issuer_doc || 'D.N.I. / R.U.C. Registrado';
  const phoneInp = document.getElementById('rcInputIssuerPhone');
  if (phoneInp) phoneInp.value = rc.issuer_phone || '+51 922 836 879';
  const cityInp = document.getElementById('rcInputIssuerCity');
  if (cityInp) cityInp.value = rc.issuer_city || 'Piura, Perú';

  const logoChk = document.getElementById('rcCheckShowLogo');
  if (logoChk) logoChk.checked = rc.show_logo !== false;

  const colorInp = document.getElementById('rcInputAccentColor');
  if (colorInp) colorInp.value = rc.accent_color || '#2563eb';

  const noteInp = document.getElementById('rcInputCustomNote');
  if (noteInp) noteInp.value = payment.receipt_custom_note || '';

  const footInp = document.getElementById('rcInputFooterNotes');
  if (footInp) footInp.value = rc.footer_notes || 'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.';

  const signInp = document.getElementById('rcInputSignature');
  if (signInp) signInp.value = rc.signature_text || 'Administración Comercial — MochilaLista';

  const badge = document.getElementById('receiptModalBadge');
  if (badge) badge.textContent = data.receipt_number || 'BOL-0001';

  renderReceiptPreviewAndCanvas();
}

function renderReceiptPreviewAndCanvas() {
  if (!currentReceiptData) return;
  const payment = currentReceiptData.payment || {};
  const client = currentReceiptData.client || {};

  const title = document.getElementById('rcInputTitle')?.value.trim() || 'BOLETA DE PAGO ADMINISTRATIVA';
  const commercial = document.getElementById('rcInputCommercialName')?.value.trim() || 'MochilaLista';
  const issuer = document.getElementById('rcInputIssuerName')?.value.trim() || 'Julio Angello Vasquez Navarro';
  const issuerDoc = document.getElementById('rcInputIssuerDoc')?.value.trim() || 'D.N.I. / R.U.C. Registrado';
  const issuerPhone = document.getElementById('rcInputIssuerPhone')?.value.trim() || '+51 922 836 879';
  const issuerCity = document.getElementById('rcInputIssuerCity')?.value.trim() || 'Piura, Perú';
  const showLogo = document.getElementById('rcCheckShowLogo')?.checked !== false;
  const accentColor = document.getElementById('rcInputAccentColor')?.value || '#2563eb';
  const customNote = document.getElementById('rcInputCustomNote')?.value.trim() || '';
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || '';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || '';

  const correlative = currentReceiptData.receipt_number || 'BOL-0001';
  const rawDate = currentReceiptData.receipt_issued_at || payment.date || new Date().toISOString();
  let dateFormatted = rawDate.substring(0, 10);
  try {
    const d = new Date(rawDate);
    dateFormatted = d.toLocaleDateString('es-PE', { day: '2-digit', month: '2-digit', year: 'numeric' }) + ' ' + d.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' });
  } catch (_) {}

  // Actualizar DOM
  const rdocTitle = document.getElementById('rdocDocTitle');
  if (rdocTitle) rdocTitle.textContent = title;
  const rdocComm = document.getElementById('rdocCommercialName');
  if (rdocComm) {
    rdocComm.textContent = commercial;
    rdocComm.style.color = accentColor;
  }
  const rdocCorr = document.getElementById('rdocCorrelativeNum');
  if (rdocCorr) {
    rdocCorr.textContent = correlative;
    rdocCorr.style.color = accentColor;
  }
  const rdocDateTime = document.getElementById('rdocDateTime');
  if (rdocDateTime) rdocDateTime.textContent = dateFormatted;

  const rdocDiv = document.getElementById('rdocDivider');
  if (rdocDiv) rdocDiv.style.backgroundColor = accentColor;

  const rdocLogoWrap = document.getElementById('rdocLogoWrap');
  if (rdocLogoWrap) rdocLogoWrap.style.display = showLogo ? 'flex' : 'none';

  const rdocIssuer = document.getElementById('rdocIssuerName');
  if (rdocIssuer) rdocIssuer.textContent = issuer;
  const rdocDoc = document.getElementById('rdocIssuerDoc');
  if (rdocDoc) rdocDoc.textContent = issuerDoc;
  const rdocPhone = document.getElementById('rdocIssuerPhone');
  if (rdocPhone) rdocPhone.textContent = issuerPhone;
  const rdocCity = document.getElementById('rdocIssuerCity');
  if (rdocCity) rdocCity.textContent = issuerCity;

  const rdocClientBiz = document.getElementById('rdocClientBiz');
  if (rdocClientBiz) rdocClientBiz.textContent = client.business_name || 'Cliente Registrado';
  const rdocClientOwner = document.getElementById('rdocClientOwner');
  if (rdocClientOwner) rdocClientOwner.textContent = client.owner_name || '-';
  const rdocClientDoc = document.getElementById('rdocClientDoc');
  if (rdocClientDoc) rdocClientDoc.textContent = client.document_number || '-';
  const rdocClientDevId = document.getElementById('rdocClientDevId');
  if (rdocClientDevId) rdocClientDevId.textContent = client.current_device_id || '-';

  const rdocConcept = document.getElementById('rdocPaymentConcept');
  if (rdocConcept) rdocConcept.textContent = payment.plan || 'Pago Registrado';
  const rdocNote = document.getElementById('rdocPaymentCustomNote');
  if (rdocNote) {
    rdocNote.textContent = customNote;
    rdocNote.style.display = customNote ? 'block' : 'none';
  }
  const rdocMethod = document.getElementById('rdocPaymentMethod');
  if (rdocMethod) rdocMethod.textContent = payment.method || 'Yape';
  const rdocRef = document.getElementById('rdocPaymentRef');
  if (rdocRef) rdocRef.textContent = payment.reference || '-';
  const rdocPayDate = document.getElementById('rdocPaymentDate');
  if (rdocPayDate) rdocPayDate.textContent = payment.date ? payment.date.substring(0, 10) : '-';

  const amountVal = (parseFloat(payment.amount) || 0).toFixed(2);
  const rdocRowAmt = document.getElementById('rdocPaymentRowAmount');
  if (rdocRowAmt) rdocRowAmt.textContent = `S/ ${amountVal}`;

  const rdocTotalBox = document.querySelector('.rdoc-total-box');
  if (rdocTotalBox) rdocTotalBox.style.borderColor = accentColor;
  const rdocTotal = document.getElementById('rdocPaymentTotal');
  if (rdocTotal) {
    rdocTotal.textContent = `S/ ${amountVal}`;
    rdocTotal.style.color = accentColor;
  }

  const rdocFoot = document.getElementById('rdocFooterNotes');
  if (rdocFoot) rdocFoot.textContent = footerNotes;
  const rdocSign = document.getElementById('rdocSignatureText');
  if (rdocSign) rdocSign.textContent = signatureText;

  drawReceiptOnCanvas();
}

function drawReceiptOnCanvas() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas || !currentReceiptData) return;

  const payment = currentReceiptData.payment || {};
  const client = currentReceiptData.client || {};

  const title = document.getElementById('rcInputTitle')?.value.trim() || 'BOLETA DE PAGO ADMINISTRATIVA';
  const commercial = document.getElementById('rcInputCommercialName')?.value.trim() || 'MochilaLista';
  const issuer = document.getElementById('rcInputIssuerName')?.value.trim() || 'Julio Angello Vasquez Navarro';
  const issuerDoc = document.getElementById('rcInputIssuerDoc')?.value.trim() || 'D.N.I. / R.U.C. Registrado';
  const issuerPhone = document.getElementById('rcInputIssuerPhone')?.value.trim() || '+51 922 836 879';
  const issuerCity = document.getElementById('rcInputIssuerCity')?.value.trim() || 'Piura, Perú';
  const showLogo = document.getElementById('rcCheckShowLogo')?.checked !== false;
  const accentColor = document.getElementById('rcInputAccentColor')?.value || '#2563eb';
  const customNote = document.getElementById('rcInputCustomNote')?.value.trim() || '';
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || 'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || 'Administración Comercial — MochilaLista';

  const correlative = currentReceiptData.receipt_number || 'BOL-0001';
  const rawDate = currentReceiptData.receipt_issued_at || payment.date || new Date().toISOString();
  let dateFormatted = rawDate.substring(0, 10);
  try {
    const d = new Date(rawDate);
    dateFormatted = d.toLocaleDateString('es-PE', { day: '2-digit', month: '2-digit', year: 'numeric' }) + ' ' + d.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' });
  } catch (_) {}

  const width = 1200;
  const height = 940;
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  // Fondo blanco y marco sutil
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, width, height);
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 2;
  ctx.strokeRect(10, 10, width - 20, height - 20);

  // Cabecera
  let startX = 60;
  if (showLogo) {
    const img = document.getElementById('rdocLogoImg');
    if (img && img.complete && img.naturalWidth > 0) {
      try {
        ctx.drawImage(img, 60, 48, 72, 72);
      } catch (_) {
        drawFallbackLogo(ctx, 60, 48, 72, 72, accentColor);
      }
    } else {
      drawFallbackLogo(ctx, 60, 48, 72, 72, accentColor);
    }
    startX = 150;
  }

  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 30px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText(title, startX, 80);

  ctx.fillStyle = accentColor;
  ctx.font = 'bold 22px sans-serif';
  ctx.fillText(commercial, startX, 112);

  // Caja de correlativo
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 2;
  roundRect(ctx, width - 360, 42, 300, 88, 10, true, true);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 14px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('COMPROBANTE N.°', width - 210, 68);

  ctx.fillStyle = accentColor;
  ctx.font = 'bold 28px monospace';
  ctx.fillText(correlative, width - 210, 98);

  ctx.fillStyle = '#64748b';
  ctx.font = '500 14px sans-serif';
  ctx.fillText(dateFormatted, width - 210, 120);

  // Línea divisoria
  ctx.fillStyle = accentColor;
  ctx.fillRect(60, 145, width - 120, 4);

  // Cajas de Emisor y Cliente
  const colW = (width - 150) / 2;
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 2;
  roundRect(ctx, 60, 165, colW, 160, 8, true, true);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 14px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText('EMISOR DEL COMPROBANTE', 80, 192);

  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 20px sans-serif';
  ctx.fillText(issuer, 80, 222);

  ctx.fillStyle = '#475569';
  ctx.font = '16px sans-serif';
  ctx.fillText(`Documento: ${issuerDoc}`, 80, 252);
  ctx.fillText(`WhatsApp: ${issuerPhone}`, 80, 280);
  ctx.fillText(`Ciudad: ${issuerCity}`, 80, 308);

  // Cliente
  roundRect(ctx, 60 + colW + 30, 165, colW, 160, 8, true, true);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 14px sans-serif';
  ctx.fillText('DATOS DEL CLIENTE', 90 + colW, 192);

  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 20px sans-serif';
  ctx.fillText(client.business_name || 'Cliente Registrado', 90 + colW, 222);

  ctx.fillStyle = '#475569';
  ctx.font = '16px sans-serif';
  ctx.fillText(`Titular: ${client.owner_name || '-'}`, 90 + colW, 252);
  ctx.fillText(`RUC / DNI: ${client.document_number || '-'}`, 90 + colW, 280);
  ctx.fillText(`Hardware ID: ${client.current_device_id || '-'}`, 90 + colW, 308);

  // Tabla de Cobro
  const tableY = 350;
  const tableW = width - 120;
  ctx.fillStyle = '#f1f5f9';
  ctx.fillRect(60, tableY, tableW, 44);
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 1;
  ctx.strokeRect(60, tableY, tableW, 44);

  ctx.fillStyle = '#334155';
  ctx.font = 'bold 16px sans-serif';
  ctx.fillText('Descripción / Concepto', 80, tableY + 28);
  ctx.fillText('Medio', 550, tableY + 28);
  ctx.fillText('N.° Operación', 700, tableY + 28);
  ctx.fillText('Fecha', 880, tableY + 28);
  ctx.textAlign = 'right';
  ctx.fillText('Total (S/)', 60 + tableW - 20, tableY + 28);

  // Fila tabla
  const rowY = tableY + 44;
  const rowH = 75;
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(60, rowY, tableW, rowH);
  ctx.strokeStyle = '#e2e8f0';
  ctx.strokeRect(60, rowY, tableW, rowH);

  ctx.textAlign = 'left';
  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 18px sans-serif';
  ctx.fillText(payment.plan || 'Pago Registrado', 80, rowY + 30);

  if (customNote) {
    ctx.fillStyle = '#64748b';
    ctx.font = '14px sans-serif';
    ctx.fillText(customNote, 80, rowY + 54);
  }

  ctx.fillStyle = '#334155';
  ctx.font = '16px sans-serif';
  ctx.fillText(payment.method || 'Yape', 550, rowY + 35);
  ctx.fillText(payment.reference || '-', 700, rowY + 35);
  ctx.fillText(payment.date ? payment.date.substring(0, 10) : '-', 880, rowY + 35);

  const amountVal = (parseFloat(payment.amount) || 0).toFixed(2);
  ctx.textAlign = 'right';
  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 20px sans-serif';
  ctx.fillText(`S/ ${amountVal}`, 60 + tableW - 20, rowY + 38);

  // Caja Total
  const totalBoxY = 490;
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = accentColor;
  ctx.lineWidth = 3;
  roundRect(ctx, width - 420, totalBoxY, 360, 75, 10, true, true);

  ctx.fillStyle = '#1e293b';
  ctx.font = 'bold 18px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText('TOTAL RECIBIDO:', width - 395, totalBoxY + 45);

  ctx.fillStyle = accentColor;
  ctx.font = '900 32px sans-serif';
  ctx.textAlign = 'right';
  ctx.fillText(`S/ ${amountVal}`, width - 85, totalBoxY + 47);

  // Línea divisoria pie
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 2;
  ctx.setLineDash([6, 6]);
  ctx.beginPath();
  ctx.moveTo(60, 680);
  ctx.lineTo(width - 60, 680);
  ctx.stroke();
  ctx.setLineDash([]);

  // Notas al pie
  ctx.textAlign = 'left';
  ctx.fillStyle = '#64748b';
  ctx.font = '15px sans-serif';
  wrapText(ctx, footerNotes, 60, 725, width - 460, 22);

  // Firma
  const signX = width - 250;
  ctx.strokeStyle = '#64748b';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(signX - 120, 770);
  ctx.lineTo(signX + 120, 770);
  ctx.stroke();

  ctx.textAlign = 'center';
  ctx.fillStyle = '#334155';
  ctx.font = 'bold 15px sans-serif';
  ctx.fillText(signatureText, signX, 795);
}

function drawFallbackLogo(ctx, x, y, w, h, color) {
  ctx.fillStyle = color;
  roundRect(ctx, x, y, w, h, 12, true, false);
  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 36px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('M', x + w / 2, y + h / 2 + 12);
}

function roundRect(ctx, x, y, w, h, r, fill, stroke) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
  if (fill) ctx.fill();
  if (stroke) ctx.stroke();
}

function wrapText(ctx, text, x, y, maxWidth, lineHeight) {
  if (!text) return;
  const words = text.split(' ');
  let line = '';
  for (let n = 0; n < words.length; n++) {
    const testLine = line + words[n] + ' ';
    const metrics = ctx.measureText(testLine);
    if (metrics.width > maxWidth && n > 0) {
      ctx.fillText(line, x, y);
      line = words[n] + ' ';
      y += lineHeight;
    } else {
      line = testLine;
    }
  }
  ctx.fillText(line, x, y);
}

function downloadReceiptPng() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas) return;
  const correlative = currentReceiptData?.receipt_number || 'BOL-0001';
  const biz = (currentReceiptData?.client?.business_name || 'Cliente').replace(/[^a-zA-Z0-9_-]/g, '_');
  const link = document.createElement('a');
  link.download = `Boleta_${correlative}_${biz}.png`;
  link.href = canvas.toDataURL('image/png');
  link.click();
  showToast(`Boleta ${correlative} descargada con éxito.`, 'success');
}

async function copyReceiptToClipboard() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas) return;
  const correlative = currentReceiptData?.receipt_number || 'BOL-0001';
  try {
    canvas.toBlob(async (blob) => {
      if (!blob) {
        showToast('No se pudo generar la imagen para el portapapeles.', 'error');
        return;
      }
      try {
        await navigator.clipboard.write([
          new ClipboardItem({ 'image/png': blob })
        ]);
        showToast(`Boleta ${correlative} copiada al portapapeles. ¡Lista para pegar con Ctrl+V en WhatsApp!`, 'success');
      } catch (err) {
        console.warn('Clipboard write error:', err);
        downloadReceiptPng();
        showToast(`Portapapeles no disponible en este navegador. Se descargó el archivo PNG ${correlative}.`, 'info');
      }
    }, 'image/png');
  } catch (e) {
    showToast('Error al copiar al portapapeles: ' + e.message, 'error');
  }
}

function printReceiptPdf() {
  window.print();
}

function sendReceiptViaWhatsapp() {
  if (!currentReceiptData) return;
  const client = currentReceiptData.client;
  const payment = currentReceiptData.payment;
  const correlative = currentReceiptData.receipt_number || 'BOL-0001';
  const amount = (parseFloat(payment.amount) || 0).toFixed(2);
  const titular = client.owner_name || client.business_name || 'Estimado cliente';
  const concept = payment.plan || 'Servicio MochilaLista';

  const msg = `¡Hola, ${titular}! Te saluda el equipo de MochilaLista.\n\n` +
    `Te hacemos entrega de tu *Boleta de Pago Oficial N.° ${correlative}* por el monto de *S/ ${amount}* correspondiente a *${concept}*.\n\n` +
    `📌 Hemos adjuntado el comprobante digital para tu control contable.\n\n` +
    `¡Muchas gracias por tu confianza y preferencia!`;

  closeReceiptModal();
  if (typeof openWaComposerForClient === 'function' && client.id) {
    openWaComposerForClient(client.id, {
      customMessage: msg,
      templateKey: 'custom'
    });
  } else {
    const phone = (client.phone || '').replace(/[^0-9]/g, '');
    const url = `https://wa.me/${phone}?text=${encodeURIComponent(msg)}`;
    window.open(url, '_blank');
  }
}

async function saveReceiptDefaultDesign() {
  const title = document.getElementById('rcInputTitle')?.value.trim() || 'BOLETA DE PAGO ADMINISTRATIVA';
  const commercial = document.getElementById('rcInputCommercialName')?.value.trim() || 'MochilaLista';
  const issuer = document.getElementById('rcInputIssuerName')?.value.trim() || 'Julio Angello Vasquez Navarro';
  const issuerDoc = document.getElementById('rcInputIssuerDoc')?.value.trim() || 'D.N.I. / R.U.C. Registrado';
  const issuerPhone = document.getElementById('rcInputIssuerPhone')?.value.trim() || '+51 922 836 879';
  const issuerCity = document.getElementById('rcInputIssuerCity')?.value.trim() || 'Piura, Perú';
  const showLogo = document.getElementById('rcCheckShowLogo')?.checked !== false;
  const accentColor = document.getElementById('rcInputAccentColor')?.value || '#2563eb';
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || '';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || '';

  const newRc = {
    title,
    commercial_name: commercial,
    issuer_name: issuer,
    issuer_doc: issuerDoc,
    issuer_phone: issuerPhone,
    issuer_city: issuerCity,
    show_logo: showLogo,
    accent_color: accentColor,
    footer_notes: footerNotes,
    signature_text: signatureText,
  };

  try {
    const cfgRes = await fetch('/api/config');
    const currentCfg = cfgRes.ok ? await cfgRes.json() : {};
    currentCfg.receipt_config = Object.assign({}, currentCfg.receipt_config || {}, newRc);

    const saveRes = await fetch('/api/config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(currentCfg),
    });

    if (!saveRes.ok) throw new Error('Error al guardar configuración');
    const saved = await saveRes.json();
    ownerConfig = saved;
    if (currentReceiptData) {
      currentReceiptData.receipt_config = saved.receipt_config;
    }
    showToast('Diseño de boleta guardado como predeterminado con éxito.', 'success');
  } catch (e) {
    showToast('Error al guardar diseño: ' + e.message, 'error');
  }
}

function resetReceiptDefaultDesign() {
  const defaultRc = {
    title: 'BOLETA DE PAGO ADMINISTRATIVA',
    commercial_name: 'MochilaLista',
    issuer_name: 'Julio Angello Vasquez Navarro',
    issuer_doc: 'D.N.I. / R.U.C. Registrado',
    issuer_phone: '+51 922 836 879',
    issuer_city: 'Piura, Perú',
    show_logo: true,
    accent_color: '#2563eb',
    footer_notes: 'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.',
    signature_text: 'Administración Comercial — MochilaLista',
  };
  if (currentReceiptData) {
    currentReceiptData.receipt_config = defaultRc;
    populateReceiptUI(currentReceiptData);
  }
  showToast('Plantilla restablecida a valores de fábrica.', 'info');
}

function initReceiptModalEvents() {
  const inputs = [
    'rcInputTitle', 'rcInputCommercialName', 'rcInputIssuerName',
    'rcInputIssuerDoc', 'rcInputIssuerPhone', 'rcInputIssuerCity',
    'rcInputAccentColor', 'rcInputCustomNote', 'rcInputFooterNotes',
    'rcInputSignature'
  ];
  inputs.forEach(id => {
    document.getElementById(id)?.addEventListener('input', () => {
      renderReceiptPreviewAndCanvas();
    });
  });

  document.getElementById('rcCheckShowLogo')?.addEventListener('change', () => {
    renderReceiptPreviewAndCanvas();
  });

  document.querySelectorAll('.rc-swatch').forEach(swatch => {
    swatch.addEventListener('click', () => {
      const col = swatch.getAttribute('data-color');
      const inp = document.getElementById('rcInputAccentColor');
      if (inp && col) {
        inp.value = col;
        renderReceiptPreviewAndCanvas();
      }
    });
  });

  document.getElementById('btnRcSaveDefault')?.addEventListener('click', saveReceiptDefaultDesign);
  document.getElementById('btnRcResetDefault')?.addEventListener('click', resetReceiptDefaultDesign);
  document.getElementById('btnRcDownloadPng')?.addEventListener('click', downloadReceiptPng);
  document.getElementById('btnRcCopyClipboard')?.addEventListener('click', copyReceiptToClipboard);
  document.getElementById('btnRcPrintPdf')?.addEventListener('click', printReceiptPdf);
  document.getElementById('btnRcSendWhatsapp')?.addEventListener('click', sendReceiptViaWhatsapp);
}

function initDrawerEvents() {
  const dtabs = document.querySelectorAll('.drawer-tab-btn');
  dtabs.forEach(btn => {
    btn.addEventListener('click', () => {
      dtabs.forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.drawer-tab-pane').forEach(p => p.classList.remove('active'));

      btn.classList.add('active');
      currentDrawerTab = btn.dataset.dtab;
      const targetPane = document.getElementById(btn.dataset.dtab);
      if (targetPane) targetPane.classList.add('active');
    });
  });

  // Control inteligente de Ventana Updates en cambio de plan
  document.getElementById('drawerEditPlanSelect')?.addEventListener('change', (e) => {
    updateDrawerEditPlanFields(e.target.value);
  });

  // Edición rápida inline de Modelo Celular en pestaña Hardware
  const btnEditModel = document.getElementById('btnDrawerEditModelInline');
  const modelRow = document.getElementById('drawerHwModelRow');
  const modelForm = document.getElementById('drawerHwModelInlineForm');
  const modelInput = document.getElementById('inputDrawerModelInline');
  const btnSaveModel = document.getElementById('btnSaveDrawerModelInline');
  const btnCancelModel = document.getElementById('btnCancelDrawerModelInline');

  btnEditModel?.addEventListener('click', () => {
    const client = globalClients.find(c => c.id === currentDrawerClientId);
    if (modelInput) modelInput.value = client?.device_model || '';
    if (modelRow) modelRow.style.display = 'none';
    if (modelForm) modelForm.style.display = 'flex';
    modelInput?.focus();
  });

  btnCancelModel?.addEventListener('click', () => {
    if (modelForm) modelForm.style.display = 'none';
    if (modelRow) modelRow.style.display = 'flex';
  });

  btnSaveModel?.addEventListener('click', async () => {
    if (!currentDrawerClientId || !modelInput) return;
    const newModel = modelInput.value.trim();
    try {
      const res = await fetch(`/api/clients/${currentDrawerClientId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_model: newModel }),
      });
      if (!res.ok) throw new Error('Error al actualizar modelo');
      const target = globalClients.find(c => c.id === currentDrawerClientId);
      if (target) target.device_model = newModel;

      const disp = document.getElementById('drawerHwModelDisplay');
      if (disp) disp.textContent = newModel || 'No registrado';
      const disp2 = document.getElementById('drawerDeviceModel');
      if (disp2) disp2.textContent = newModel || 'No registrado';
      const editInp = document.getElementById('drawerEditDeviceModel');
      if (editInp) editInp.value = newModel;

      if (modelForm) modelForm.style.display = 'none';
      if (modelRow) modelRow.style.display = 'flex';
      showToast('Modelo de celular actualizado.', 'success');
      await loadClients();
      await loadDashboard();
    } catch (err) {
      showToast('Error: ' + err.message, 'error');
    }
  });

  document.getElementById('formDrawerEditClient')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!currentDrawerClientId) return;

    const biz = document.getElementById('drawerEditBizName').value.trim();
    const owner = document.getElementById('drawerEditOwnerName').value.trim();
    const doc = document.getElementById('drawerEditDocId').value.trim();
    const phone = document.getElementById('drawerEditPhone').value.trim();
    const device = document.getElementById('drawerEditDeviceId').value.trim().toUpperCase();
    const model = document.getElementById('drawerEditDeviceModel')?.value.trim() || '';
    const plan = document.getElementById('drawerEditPlanSelect')?.value || 'MENSUAL';
    const ver = document.getElementById('drawerEditInstalledVersion').value.trim();
    const exp = document.getElementById('drawerEditExpires')?.value || null;
    const upd = document.getElementById('drawerEditUpdates')?.value || null;
    const aiRep = parseInt(document.getElementById('drawerEditAiReported')?.value) || 0;
    const aiBonus = parseInt(document.getElementById('drawerEditAiPendingBonus')?.value) || 0;
    const notes = document.getElementById('drawerEditNotes').value.trim();

    try {
      const res = await fetch(`/api/clients/${currentDrawerClientId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          business_name: biz,
          owner_name: owner,
          document_id: doc,
          phone: phone,
          current_device_id: device,
          device_model: model,
          license_type: plan,
          installed_version: ver,
          license_expires: exp,
          updates_until: upd,
          ai_reported_balance: aiRep,
          ai_pending_bonus: aiBonus,
          notes: notes,
        }),
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || 'Error al actualizar datos');
      }
      showToast('Ficha 360° del cliente actualizada de inmediato.', 'success');
      await loadClients();
      await loadDashboard();
      openClient360Drawer(currentDrawerClientId, 'drawerTabEdit');
    } catch (err) {
      showToast('Error: ' + err.message, 'error');
    }
  });

  document.getElementById('btnDrawerEmitLicense')?.addEventListener('click', () => {
    if (!currentDrawerClientId) return;
    const cid = currentDrawerClientId;
    drawerReturnState = null;
    closeClient360Drawer();
    selectClientForLicense(cid);
  });

  document.getElementById('btnDrawerMigrateDev')?.addEventListener('click', () => {
    if (!currentDrawerClientId) return;
    const cid = currentDrawerClientId;
    openMigrateModal(cid);
  });

  document.getElementById('btnDrawerAddPayment')?.addEventListener('click', () => {
    if (!currentDrawerClientId) return;
    openAddPaymentModal(currentDrawerClientId);
  });

  // Modal Sincronizar Datos Reportados del Celular (Envío de formulario)
  document.getElementById('btnSubmitSyncReported')?.addEventListener('click', async () => {
    const clientId = document.getElementById('syncRepClientId').value;
    if (!clientId) return;

    const deviceId = document.getElementById('syncRepDeviceId').value.trim();
    const deviceModel = document.getElementById('syncRepDeviceModel').value.trim();
    const version = document.getElementById('syncRepVersion').value.trim();
    const aiBalance = parseInt(document.getElementById('syncRepAiBalance').value);
    const trialDays = document.getElementById('syncRepTrialDays').value ? parseInt(document.getElementById('syncRepTrialDays').value) : null;
    const expires = document.getElementById('syncRepExpires').value || null;
    const notes = document.getElementById('syncRepNotes').value.trim();

    try {
      const res = await fetch(`/api/clients/${clientId}/sync-reported`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          device_id: deviceId || undefined,
          device_model: deviceModel || undefined,
          installed_version: version || undefined,
          ai_reported_balance: !isNaN(aiBalance) ? aiBalance : undefined,
          trial_days_remaining: trialDays !== null && !isNaN(trialDays) ? trialDays : undefined,
          license_expires: expires || undefined,
          notes: notes || undefined,
        }),
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || 'Error al sincronizar datos reportados');
      }

      await loadClients();
      await loadDashboard();
      closeModal('modalSyncReported');
      showToast('Datos del celular sincronizados con éxito.', 'success');
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Bidireccionalidad reactiva en Modal Sincronizar Datos Reportados
  const syncDaysInput = document.getElementById('syncRepTrialDays');
  const syncExpInput = document.getElementById('syncRepExpires');
  if (syncDaysInput && syncExpInput) {
    syncDaysInput.addEventListener('input', () => {
      const days = parseInt(syncDaysInput.value);
      if (!isNaN(days) && days >= 0) {
        const d = new Date();
        d.setDate(d.getDate() + days);
        syncExpInput.value = d.toISOString().substring(0, 10);
      }
    });
    syncExpInput.addEventListener('change', () => {
      if (syncExpInput.value) {
        const target = new Date(syncExpInput.value + 'T00:00:00');
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const diff = Math.max(0, Math.ceil((target - today) / (1000 * 60 * 60 * 24)));
        syncDaysInput.value = diff;
      }
    });
  }
}

async function openClient360Drawer(clientId) {
  const initialTab = arguments[1] || 'drawerTabOverview';
  currentDrawerClientId = clientId;
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  // Activar pestaña solicitada de inmediato (con soporte para alias drawerTabSummary)
  const targetTabId = (initialTab === 'drawerTabSummary') ? 'drawerTabOverview' : initialTab;
  currentDrawerTab = targetTabId;
  const dtabs = document.querySelectorAll('.drawer-tab-btn');
  dtabs.forEach(b => {
    if (b.dataset.dtab === targetTabId) {
      b.classList.add('active');
    } else {
      b.classList.remove('active');
    }
  });
  document.querySelectorAll('.drawer-tab-pane').forEach(p => {
    if (p.id === targetTabId) {
      p.classList.add('active');
    } else {
      p.classList.remove('active');
    }
  });

  // Cabecera Ficha 360°
  document.getElementById('drawerBizName').textContent = client.business_name || 'Sin Nombre';
  document.getElementById('drawerOwnerName').textContent = client.owner_name || '-';
  document.getElementById('drawerDeviceId').textContent = client.current_device_id || 'PENDIENTE';

  const statusBadge = document.getElementById('drawerStatusBadge');
  const badgeInfo = getClientStatusBadge(client, { asObject: true });
  if (statusBadge) {
    statusBadge.className = badgeInfo.className;
    statusBadge.textContent = badgeInfo.text;
  }
  const isProspect = badgeInfo.isProspect;
  const isTrial = badgeInfo.isTrial;
  const isPerp = badgeInfo.isPerp;
  const plan = (client.license_type || 'MENSUAL').toUpperCase();

  // Pestaña 1: Resumen y Licencia
  document.getElementById('drawerKpiPlan').textContent = isProspect ? 'PROSPECTO' : plan.replace(/_/g, ' ');
  document.getElementById('drawerKpiExpires').textContent = isProspect
    ? (client.expected_subscription_date ? `Seguimiento: ${client.expected_subscription_date}` : 'Sin vencimiento')
    : (isPerp ? 'De por Vida' : (client.license_expires ? client.license_expires.substring(0, 10) : 'Sin fecha'));

  const realAi = (client.ai_reported_balance !== undefined && client.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client.ai_accumulated_credits ?? client.ai_extra_credits ?? 0);
  const pendingAi = client.ai_pending_bonus || 0;

  if (isTrial || client.ai_reported_balance !== undefined) {
    document.getElementById('drawerKpiAiCredits').textContent = `${realAi} IA`;
  } else {
    document.getElementById('drawerKpiAiCredits').textContent = (client.ai_extra_credits || 0) > 0 ? `+${client.ai_extra_credits} IA` : '0 IA';
  }
  document.getElementById('drawerKpiVersion').textContent = `v${client.installed_version || '9.35.0'}`;
  
  const drawerKpiUpdates = document.getElementById('drawerBoxUpdates')?.querySelector('.drawer-kpi-val') || document.getElementById('drawerKpiUpdates');
  if (drawerKpiUpdates) {
    if (isProspect || isTrial) {
      drawerKpiUpdates.textContent = 'No aplica';
    } else {
      drawerKpiUpdates.textContent = client.updates_until ? client.updates_until.substring(0, 10) : '-';
    }
  }

  document.getElementById('drawerPhone').textContent = client.phone || '-';
  document.getElementById('drawerDocId').textContent = client.document_id || '-';
  const drawerDeviceModel = document.getElementById('drawerDeviceModel');
  if (drawerDeviceModel) {
    drawerDeviceModel.textContent = client.device_model || 'No registrado';
  }
  const drawerAiBreakdown = document.getElementById('drawerAiBreakdown');
  if (drawerAiBreakdown) {
    drawerAiBreakdown.textContent = `En celular: ${realAi} IA | Bono pendiente: +${pendingAi} IA`;
  }
  document.getElementById('drawerNotes').textContent = client.notes || 'Sin observaciones registradas.';

  // Pestaña 4: Hardware Actual (Caja Superior)
  document.getElementById('drawerCurrentDevIdDisplay').textContent = client.current_device_id || 'PENDIENTE';
  const drawerHwModelDisplay = document.getElementById('drawerHwModelDisplay');
  if (drawerHwModelDisplay) {
    drawerHwModelDisplay.textContent = client.device_model || 'No registrado';
  }
  const drawerHwVersionDisplay = document.getElementById('drawerHwVersionDisplay');
  if (drawerHwVersionDisplay) {
    const latestVer = getLatestPublishedVersion();
    const clientVer = (client.installed_version || '').trim();
    let badgeHtml = '';
    if (isProspect || !clientVer) {
      badgeHtml = '<span class="badge badge-outline" style="font-size:0.68rem; padding:1px 6px; margin-left:4px; color:var(--text-muted);">Sin versión</span>';
    } else if (!latestVer) {
      badgeHtml = '<span class="badge badge-green" style="font-size:0.68rem; padding:1px 6px; margin-left:4px;">Al día</span>';
    } else if (compareSemVer(clientVer, latestVer) < 0) {
      badgeHtml = '<span class="badge badge-yellow" style="font-size:0.68rem; padding:1px 6px; margin-left:4px;">Update pend.</span>';
    } else {
      badgeHtml = '<span class="badge badge-green" style="font-size:0.68rem; padding:1px 6px; margin-left:4px;">Al día</span>';
    }
    drawerHwVersionDisplay.innerHTML = `<code>v${escapeHtml(client.installed_version || '9.35.0')}</code> ${badgeHtml}`;
  }
  const drawerHwNonceDisplay = document.getElementById('drawerHwNonceDisplay');
  if (drawerHwNonceDisplay) {
    drawerHwNonceDisplay.textContent = client.next_nonce || 1;
  }
  const drawerHwLinkedDateDisplay = document.getElementById('drawerHwLinkedDateDisplay');
  if (drawerHwLinkedDateDisplay) {
    drawerHwLinkedDateDisplay.textContent = client.created_at ? client.created_at.substring(0, 10) : 'Al registrar';
  }

  // Pestaña 5: Edición Rápida Form Pre-fill
  document.getElementById('drawerEditClientId').value = client.id;
  document.getElementById('drawerEditBizName').value = client.business_name || '';
  document.getElementById('drawerEditOwnerName').value = client.owner_name || '';
  document.getElementById('drawerEditDocId').value = client.document_id || '';
  document.getElementById('drawerEditPhone').value = client.phone || '';
  document.getElementById('drawerEditDeviceId').value = client.current_device_id || '';
  const editDevModel = document.getElementById('drawerEditDeviceModel');
  if (editDevModel) editDevModel.value = client.device_model || '';
  const editPlanSel = document.getElementById('drawerEditPlanSelect');
  if (editPlanSel) editPlanSel.value = client.license_type || 'MENSUAL';
  updateDrawerEditPlanFields(client.license_type);
  document.getElementById('drawerEditInstalledVersion').value = client.installed_version || '9.35.0';
  const editExpires = document.getElementById('drawerEditExpires');
  if (editExpires) editExpires.value = client.license_expires ? client.license_expires.substring(0, 10) : '';
  const editUpdates = document.getElementById('drawerEditUpdates');
  if (editUpdates) editUpdates.value = client.updates_until ? client.updates_until.substring(0, 10) : '';
  const editAiRep = document.getElementById('drawerEditAiReported');
  if (editAiRep) editAiRep.value = client.ai_reported_balance || 0;
  const editAiBonus = document.getElementById('drawerEditAiPendingBonus');
  if (editAiBonus) editAiBonus.value = client.ai_pending_bonus || 0;
  document.getElementById('drawerEditNotes').value = client.notes || '';

  try {
    const res = await fetch(`/api/clients/${clientId}/history`);
    if (res.ok) {
      const history = await res.json();

      // --- PESTAÑA 3: PAGOS & FINANZAS (Tarjetas Compactas - Cero Scroll Horizontal) ---
      let totalPaid = 0;
      const methodCounts = {};
      let lastDate = '-';
      const paymentsBody = document.getElementById('drawerPaymentsBody');
      if (paymentsBody) paymentsBody.innerHTML = '';

      const payments = history.payments || [];
      if (payments.length > 0 && paymentsBody) {
        payments.forEach(p => {
          const amt = parseFloat(p.amount) || 0;
          totalPaid += amt;
          const m = p.method || 'Otro';
          methodCounts[m] = (methodCounts[m] || 0) + 1;
          const pDate = p.date ? p.date.substring(0, 10) : '-';
          if (lastDate === '-' || (pDate !== '-' && pDate > lastDate)) {
            lastDate = pDate;
          }

          const card = document.createElement('div');
          card.className = 'drawer-payment-card';
          card.innerHTML = `
            <div class="dpc-row-top">
              <div class="dpc-concept-wrap">
                <span class="dpc-date">${escapeHtml(pDate)}</span>
                <span class="badge badge-mono">${escapeHtml(p.plan || '-')}</span>
              </div>
              <div class="dpc-amount">S/ ${amt.toFixed(2)}</div>
            </div>
            <div class="dpc-row-mid">
              <span class="dpc-method">${escapeHtml(p.method || 'Medio no esp.')}</span>
              <span class="dpc-ref">${escapeHtml(p.reference || p.notes || '-')}</span>
            </div>
            <div class="dpc-row-actions">
              <button type="button" class="btn btn-outline btn-xs btn-pay-receipt" title="Emitir Boleta de Pago">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:12px; height:12px; margin-right:3px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
                Boleta
              </button>
              <button type="button" class="btn btn-outline btn-xs btn-pay-edit" title="Editar Pago">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:12px; height:12px; margin-right:3px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                Editar
              </button>
              <button type="button" class="btn btn-outline btn-xs btn-action-danger btn-pay-delete" title="Eliminar Pago">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:12px; height:12px; margin-right:3px;"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                Eliminar
              </button>
            </div>
          `;

          card.querySelector('.btn-pay-receipt').onclick = () => openPaymentReceiptModal(clientId, p.id);
          card.querySelector('.btn-pay-edit').onclick = () => openEditPaymentModal(clientId, p);
          card.querySelector('.btn-pay-delete').onclick = () => confirmDeletePayment(clientId, p.id);
          paymentsBody.appendChild(card);
        });
      } else if (paymentsBody) {
        paymentsBody.innerHTML = `
          <div class="drawer-payment-card" style="text-align:center; padding:1.5rem; color:var(--text-muted); font-size:0.85rem;">
            Sin pagos registrados para este cliente.
          </div>
        `;
      }

      // Calcular medio más frecuente
      let topMethod = '-';
      let maxCount = 0;
      for (const [meth, cnt] of Object.entries(methodCounts)) {
        if (cnt > maxCount) {
          maxCount = cnt;
          topMethod = meth;
        }
      }

      document.getElementById('drawerKpiTotalPaid').textContent = `S/ ${totalPaid.toFixed(2)}`;
      const drawerPayKpiTotal = document.getElementById('drawerPayKpiTotal');
      if (drawerPayKpiTotal) drawerPayKpiTotal.textContent = `S/ ${totalPaid.toFixed(2)}`;
      const drawerPayKpiCount = document.getElementById('drawerPayKpiCount');
      if (drawerPayKpiCount) drawerPayKpiCount.textContent = `${payments.length}`;
      const drawerPayKpiLastDate = document.getElementById('drawerPayKpiLastDate');
      if (drawerPayKpiLastDate) drawerPayKpiLastDate.textContent = lastDate;
      const drawerPayKpiMethod = document.getElementById('drawerPayKpiMethod');
      if (drawerPayKpiMethod) drawerPayKpiMethod.textContent = topMethod;

      // --- PESTAÑA 2: QR & CREDENCIAL OFICIAL ---
      const codes = (history.codes && history.codes.length > 0) ? history.codes : (client.generated_codes_history || []);
      const emptyState = document.getElementById('drawerQrEmptyState');
      const qrContent = document.getElementById('drawerQrContent');
      const selectorContainer = document.getElementById('drawerQrSelectorContainer');
      const codeSelector = document.getElementById('drawerQrCodeSelector');

      if (!codes || codes.length === 0) {
        if (emptyState) emptyState.style.display = 'flex';
        if (qrContent) qrContent.style.display = 'none';
      } else {
        if (emptyState) emptyState.style.display = 'none';
        if (qrContent) qrContent.style.display = 'flex';

        const renderSelectedDrawerLicense = (selectedCode, selectedIdx) => {
          const token = selectedCode.token;
          document.getElementById('drawerCodeDisplay').textContent = token;
          renderSafeQrCode('drawerQrContainer', token, 196);

          // Metadatos precisos sin desincronización (Directo del objeto emitido)
          const metaPlan = document.getElementById('drawerQrMetaPlan');
          if (metaPlan) metaPlan.textContent = (selectedCode.plan || client.license_type || 'MENSUAL').replace(/_/g, ' ');

          const codeDate = selectedCode.created_at || selectedCode.emitted_at;
          const metaEmitted = document.getElementById('drawerQrMetaEmitted');
          if (metaEmitted) metaEmitted.textContent = codeDate ? codeDate.substring(0, 10) : '-';

          const codeExp = selectedCode.expires_at || selectedCode.expires_result;
          const metaExpires = document.getElementById('drawerQrMetaExpires');
          if (metaExpires) metaExpires.textContent = codeExp ? codeExp.substring(0, 10) : (client.license_expires ? client.license_expires.substring(0, 10) : 'Activa');

          const codeNonce = selectedCode.nonce ?? selectedCode.n ?? (selectedIdx !== undefined ? selectedIdx + 1 : (codes.indexOf(selectedCode) + 1));
          const metaNonce = document.getElementById('drawerQrMetaNonce');
          if (metaNonce) metaNonce.textContent = codeNonce;

          const codeAi = selectedCode.ai_credits ?? selectedCode.total_ai_credited ?? selectedCode.base_ai_credits ?? 0;
          const metaAi = document.getElementById('drawerQrMetaAi');
          if (metaAi) metaAi.textContent = `+${codeAi} IA`;

          const metaDevice = document.getElementById('drawerQrMetaDevice');
          if (metaDevice) metaDevice.textContent = selectedCode.device_id || client.current_device_id || '-';

          // Botones de acción en QR & Credencial
          document.getElementById('btnDrawerCopyCode').onclick = () => {
            navigator.clipboard.writeText(token).then(() => showToast('¡Código copiado al portapapeles!', 'success'));
          };

          const btnCopyCred = document.getElementById('btnDrawerCopyCredential');
          if (btnCopyCred) {
            btnCopyCred.onclick = () => {
              renderCredentialCanvas({
                token: selectedCode.token,
                plan: selectedCode.plan || client.license_type,
                device_id: selectedCode.device_id || client.current_device_id,
                days_added: selectedCode.days_added,
                expires_result: selectedCode.expires_at || selectedCode.expires_result || client.license_expires,
                client: client,
              }, client, 'historyCredentialCanvas', 'drawerQrContainer');

              const canvas = document.getElementById('historyCredentialCanvas');
              if (canvas && canvas.toBlob) {
                canvas.toBlob(async (blob) => {
                  if (!blob) {
                    showToast('Error al generar imagen de la credencial', 'error');
                    return;
                  }
                  try {
                    await navigator.clipboard.write([
                      new ClipboardItem({ 'image/png': blob })
                    ]);
                    showToast('¡Imagen de la credencial copiada! Pégala en WhatsApp con Ctrl+V.', 'success');
                  } catch (err) {
                    showToast('Tu navegador no permite copiar imágenes al portapapeles. Usa "Descargar Tarjeta".', 'warning');
                  }
                }, 'image/png');
              }
            };
          }

          document.getElementById('btnDrawerDownloadCredential').onclick = () => {
            renderCredentialCanvas({
              token: selectedCode.token,
              plan: selectedCode.plan || client.license_type,
              device_id: selectedCode.device_id || client.current_device_id,
              days_added: selectedCode.days_added,
              expires_result: selectedCode.expires_at || selectedCode.expires_result || client.license_expires,
              client: client,
            }, client, 'historyCredentialCanvas', 'drawerQrContainer');

            const canvas = document.getElementById('historyCredentialCanvas');
            if (canvas) {
              const nameClean = (client.business_name || 'Licencia').replace(/[^a-zA-Z0-9]/g, '_');
              const link = document.createElement('a');
              link.download = `Credencial_${nameClean}_${selectedCode.plan || 'Oficial'}.png`;
              link.href = canvas.toDataURL('image/png');
              link.click();
              showToast('Credencial descargada en PNG @2x.', 'success');
            }
          };

          document.getElementById('btnDrawerDownloadQr').onclick = () => {
            downloadQrWithQuietZone('#drawerQrContainer', `QR_${client.current_device_id}_N${codeNonce}.png`, 32);
          };

          document.getElementById('btnDrawerAuditInspector').onclick = () => {
            auditTokenInInspector(token);
          };

          document.getElementById('btnDrawerSendWa').onclick = () => {
            openWhatsAppComposer(client.id, 'license');
          };

          const btnQrNew = document.getElementById('btnDrawerQrNewLicense');
          if (btnQrNew) {
            btnQrNew.onclick = () => {
              drawerReturnState = null;
              closeClient360Drawer();
              selectClientForLicense(client.id);
            };
          }
        };

        // Configurar selector histórico ordenado de la más reciente a la más antigua
        if (codes.length > 1) {
          if (selectorContainer) selectorContainer.style.display = 'block';
          if (codeSelector) {
            codeSelector.innerHTML = '';
            const reversed = codes.map((c, originalIdx) => ({ c, originalIdx })).reverse();
            reversed.forEach(({ c, originalIdx }) => {
              const opt = document.createElement('option');
              opt.value = originalIdx;
              const cDate = (c.created_at || c.emitted_at) ? (c.created_at || c.emitted_at).substring(0, 10) : '';
              const nonceVal = c.nonce ?? c.n ?? (originalIdx + 1);
              const isLatest = (originalIdx === codes.length - 1);
              const vigTag = isLatest ? ' [Vigente]' : '';
              const planName = (c.plan || 'LICENCIA').replace(/_/g, ' ');
              opt.textContent = `${planName} • Nonce #${nonceVal} • ${cDate}${vigTag}`;
              if (isLatest) opt.selected = true;
              codeSelector.appendChild(opt);
            });
            codeSelector.onchange = () => {
              const selectedIdx = parseInt(codeSelector.value);
              if (codes[selectedIdx]) renderSelectedDrawerLicense(codes[selectedIdx], selectedIdx);
            };
          }
        } else {
          if (selectorContainer) selectorContainer.style.display = 'none';
        }

        // Renderizar la última licencia por defecto
        renderSelectedDrawerLicense(codes[codes.length - 1], codes.length - 1);
      }

      // --- PESTAÑA 4: HARDWARE & MIGRACIONES (Edición interactiva de Motivo) ---
      const hwBody = document.getElementById('drawerHardwareBody');
      if (hwBody) {
        hwBody.innerHTML = '';
        const migrations = history.device_history || history.hardware || [];
        if (migrations && migrations.length > 0) {
          migrations.forEach((h, hIdx) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
              <td>${h.migrated_at ? h.migrated_at.substring(0, 10) : '-'}</td>
              <td><code style="font-family:var(--font-mono); font-size:0.78rem;">${escapeHtml(h.old_device_id)}</code></td>
              <td><strong style="font-family:var(--font-mono); color:var(--primary); font-size:0.78rem;">${escapeHtml(h.new_device_id)}</strong></td>
              <td>S/ ${(h.fee_amount || h.fee_charged || 0).toFixed(2)}</td>
              <td class="mig-reason-cell">
                <div class="reason-display-wrap" style="display:flex; align-items:center; justify-content:space-between; gap:0.35rem;">
                  <span class="reason-text" style="font-size:0.8rem;">${escapeHtml(h.reason || '-')}</span>
                  <button type="button" class="btn-micro btn-edit-reason" title="Editar motivo de migración">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:11px; height:11px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                </div>
                <div class="reason-edit-wrap" style="display:none; align-items:center; gap:0.25rem;">
                  <input type="text" class="form-control reason-input" style="font-size:0.75rem; padding:2px 4px; height:24px; min-width:120px;" value="${escapeHtml(h.reason || '')}">
                  <button type="button" class="btn btn-primary btn-xs btn-save-reason" style="padding:2px 5px;">✓</button>
                  <button type="button" class="btn btn-outline btn-xs btn-cancel-reason" style="padding:2px 5px;">✕</button>
                </div>
              </td>
            `;

            const dispWrap = tr.querySelector('.reason-display-wrap');
            const editWrap = tr.querySelector('.reason-edit-wrap');
            const btnEditReason = tr.querySelector('.btn-edit-reason');
            const btnCancelReason = tr.querySelector('.btn-cancel-reason');
            const btnSaveReason = tr.querySelector('.btn-save-reason');
            const inputReason = tr.querySelector('.reason-input');

            btnEditReason.onclick = () => {
              dispWrap.style.display = 'none';
              editWrap.style.display = 'flex';
              inputReason.focus();
            };

            btnCancelReason.onclick = () => {
              editWrap.style.display = 'none';
              dispWrap.style.display = 'flex';
            };

            btnSaveReason.onclick = async () => {
              const newReason = inputReason.value.trim();
              try {
                const updateRes = await fetch(`/api/clients/${clientId}/device-history/${hIdx}`, {
                  method: 'PUT',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ reason: newReason }),
                });
                if (!updateRes.ok) throw new Error('Error al actualizar motivo');
                h.reason = newReason;
                tr.querySelector('.reason-text').textContent = newReason || '-';
                editWrap.style.display = 'none';
                dispWrap.style.display = 'flex';
                showToast('Motivo de migración actualizado con éxito.', 'success');
              } catch (err) {
                showToast('Error: ' + err.message, 'error');
              }
            };

            hwBody.appendChild(tr);
          });
        } else {
          hwBody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:var(--text-muted); padding:1rem;">Sin migraciones registradas.</td></tr>';
        }
      }
    }
  } catch (err) {
    console.error('Error loading history for drawer:', err);
  }

  document.getElementById('drawerClient360Backdrop')?.classList.add('open');
  document.getElementById('drawerClient360')?.classList.add('open');
}

function closeClient360Drawer() {
  drawerReturnState = null;
  document.getElementById('drawerClient360Backdrop')?.classList.remove('open');
  document.getElementById('drawerClient360')?.classList.remove('open');
  currentDrawerClientId = null;
}

/**
 * Eliminación segura con confirmación del cliente desde la Ficha 360°
 */
function deleteClientFromDrawer() {
  if (!currentDrawerClientId) return;
  drawerReturnState = null;
  const clientId = currentDrawerClientId;
  const client = globalClients.find(c => c.id === clientId);
  const name = client ? client.business_name : clientId;

  showConfirmModal(
    'Eliminar Cliente Definitivamente',
    `¿Estás seguro de que deseas eliminar permanentemente a "${name}" de la cartera activa? Se creará automáticamente un respaldo de seguridad en disco antes de procesar la eliminación.`,
    async () => {
      try {
        const res = await fetch(`/api/clients/${currentDrawerClientId}`, {
          method: 'DELETE',
        });
        if (!res.ok) {
          const errData = await res.json().catch(() => ({}));
          throw new Error(errData.error || 'Error al eliminar cliente');
        }
        showToast(`Cliente "${name}" eliminado de la cartera exitosamente.`, 'success');
        closeClient360Drawer();
        await loadClients();
        await loadDashboard();
      } catch (err) {
        showToast('Error al eliminar: ' + err.message, 'error');
      }
    },
    true
  );
}

/**
 * Apertura de Modal para Registrar Pago Manual
 */
/**
 * Apertura de Modal para Registrar Pago Manual (Fase 5)
 */
function openAddPaymentModal(clientId) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;
  document.getElementById('manualPayClientId').value = clientId;
  const payId = document.getElementById('manualPayId');
  if (payId) payId.value = '';
  const payTitle = document.getElementById('manualPayTitle');
  if (payTitle) payTitle.textContent = 'Registrar Pago';

  // Resumen del Cliente en Cabecera
  const bizEl = document.getElementById('manualPayBizName');
  if (bizEl) bizEl.textContent = client.business_name || 'Sin negocio';
  const ownerEl = document.getElementById('manualPayOwnerName');
  if (ownerEl) ownerEl.textContent = client.owner_name || 'Sin propietario';
  const devEl = document.getElementById('manualPayDevId');
  if (devEl) devEl.textContent = client.current_device_id || '-';
  const statusBadge = document.getElementById('manualPayStatusBadge');
  if (statusBadge) {
    statusBadge.outerHTML = `<span id="manualPayStatusBadge">${getClientStatusBadge(client)}</span>`;
  }
  const expEl = document.getElementById('manualPayExpiresText');
  if (expEl) expEl.textContent = client.license_expires ? client.license_expires.substring(0, 10) : 'No configurada';

  // Total recaudado
  let totalPaid = 0;
  if (Array.isArray(client.payment_history)) {
    client.payment_history.forEach(p => totalPaid += (parseFloat(p.amount) || 0));
  }
  const totalPaidEl = document.getElementById('manualPayTotalPaid');
  if (totalPaidEl) totalPaidEl.textContent = `S/ ${totalPaid.toFixed(2)}`;

  const payDate = document.getElementById('manualPayDate');
  if (payDate) payDate.value = new Date().toISOString().substring(0, 10);

  // Preset inteligente
  const presetSel = document.getElementById('manualPayPlanPreset');
  const customConcept = document.getElementById('manualPayCustomConcept');
  if (presetSel) {
    presetSel.value = 'Renovación Mensual';
    if (customConcept) {
      customConcept.value = '';
      customConcept.style.display = 'none';
    }
  }

  const defaultPrice = ownerConfig?.catalog?.['MENSUAL']?.price ?? 35.0;
  document.getElementById('manualPayAmount').value = defaultPrice.toFixed(2);
  document.getElementById('manualPayPlan').value = 'Renovación Mensual';
  document.getElementById('manualPayMethod').value = 'Yape';
  document.getElementById('manualPayRef').value = '';
  document.getElementById('manualPayNotes').value = '';

  const genReceiptChk = document.getElementById('manualPayGenerateReceipt');
  if (genReceiptChk) genReceiptChk.checked = true;

  openModal('modalManualPayment');
}

const openManualPaymentModal = openAddPaymentModal;

/**
 * Apertura de Modal para Editar Pago Registrado
 */
function openEditPaymentModal(clientId, payment) {
  const client = globalClients.find(c => c.id === clientId);
  document.getElementById('manualPayClientId').value = clientId;
  const payId = document.getElementById('manualPayId');
  if (payId) payId.value = payment.id || '';
  const payTitle = document.getElementById('manualPayTitle');
  if (payTitle) payTitle.textContent = 'Editar Pago Registrado';

  // Resumen del Cliente en Cabecera
  if (client) {
    const bizEl = document.getElementById('manualPayBizName');
    if (bizEl) bizEl.textContent = client.business_name || 'Sin negocio';
    const ownerEl = document.getElementById('manualPayOwnerName');
    if (ownerEl) ownerEl.textContent = client.owner_name || 'Sin propietario';
    const devEl = document.getElementById('manualPayDevId');
    if (devEl) devEl.textContent = client.current_device_id || '-';
    const statusBadge = document.getElementById('manualPayStatusBadge');
    if (statusBadge) {
      statusBadge.outerHTML = `<span id="manualPayStatusBadge">${getClientStatusBadge(client)}</span>`;
    }
    const expEl = document.getElementById('manualPayExpiresText');
    if (expEl) expEl.textContent = client.license_expires ? client.license_expires.substring(0, 10) : 'No configurada';

    let totalPaid = 0;
    if (Array.isArray(client.payment_history)) {
      client.payment_history.forEach(p => totalPaid += (parseFloat(p.amount) || 0));
    }
    const totalPaidEl = document.getElementById('manualPayTotalPaid');
    if (totalPaidEl) totalPaidEl.textContent = `S/ ${totalPaid.toFixed(2)}`;
  }

  const payDate = document.getElementById('manualPayDate');
  if (payDate) payDate.value = payment.date ? payment.date.substring(0, 10) : new Date().toISOString().substring(0, 10);
  document.getElementById('manualPayAmount').value = payment.amount || 0;

  // Matching preset o fallback a CUSTOM preservando concepto original
  const presetSel = document.getElementById('manualPayPlanPreset');
  const customConcept = document.getElementById('manualPayCustomConcept');
  const planVal = payment.plan || '';
  let matched = false;
  if (presetSel) {
    for (const opt of presetSel.options) {
      if (opt.value !== 'CUSTOM' && (opt.value === planVal || planVal.toLowerCase() === opt.value.toLowerCase())) {
        presetSel.value = opt.value;
        matched = true;
        break;
      }
    }
    if (!matched) {
      presetSel.value = 'CUSTOM';
      if (customConcept) {
        customConcept.value = planVal;
        customConcept.style.display = 'block';
      }
    } else {
      if (customConcept) {
        customConcept.value = '';
        customConcept.style.display = 'none';
      }
    }
  }

  document.getElementById('manualPayPlan').value = planVal;
  document.getElementById('manualPayMethod').value = payment.method || 'Yape';
  document.getElementById('manualPayRef').value = payment.reference || '';
  document.getElementById('manualPayNotes').value = payment.notes || '';

  const genReceiptChk = document.getElementById('manualPayGenerateReceipt');
  if (genReceiptChk) genReceiptChk.checked = false;

  openModal('modalManualPayment');
}

/**
 * Confirmación y eliminación de pago en el historial contable
 */
function confirmDeletePayment(clientId, paymentId) {
  showConfirmModal(
    'Eliminar Registro de Pago',
    '¿Estás seguro de que deseas anular y eliminar este registro de pago del historial contable del cliente?',
    async () => {
      try {
        const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}`, {
          method: 'DELETE',
        });
        if (!res.ok) {
          const errData = await res.json().catch(() => ({}));
          throw new Error(errData.error || 'Error al eliminar pago');
        }
        showToast('Registro de pago eliminado correctamente.', 'success');
        if (currentDrawerClientId === clientId) {
          await openClient360Drawer(clientId, 'drawerTabFinances');
        }
        if (currentHistoryClientId === clientId) {
          await openClientHistoryModal(clientId);
        }
        await loadClients();
        await loadDashboard();
        await loadFinances();
      } catch (err) {
        showToast('Error al eliminar pago: ' + err.message, 'error');
      }
    },
    true
  );
}

/**
 * Apertura del Modal para Sincronizar Datos Reportados en Celular
 */
function openSyncReportedModal(clientId) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;
  document.getElementById('syncRepClientId').value = clientId;

  const bizEl = document.getElementById('syncRepBizName');
  if (bizEl) bizEl.textContent = client.business_name || 'Sin negocio';
  const ownerEl = document.getElementById('syncRepOwnerName');
  if (ownerEl) ownerEl.textContent = client.owner_name || 'Sin titular';
  const devEl = document.getElementById('syncRepCurrentDevId');
  if (devEl) devEl.textContent = (client.current_device_id && client.current_device_id !== 'PENDIENTE') ? client.current_device_id : 'PENDIENTE';

  const badgeEl = document.getElementById('syncRepStatusBadge');
  if (badgeEl) {
    const badgeInfo = getClientStatusBadge(client, { asObject: true });
    badgeEl.className = badgeInfo.className;
    badgeEl.textContent = badgeInfo.text;
  }

  document.getElementById('syncRepDeviceId').value = (client.current_device_id && client.current_device_id !== 'PENDIENTE') ? client.current_device_id : '';
  document.getElementById('syncRepDeviceModel').value = client.device_model || '';
  document.getElementById('syncRepVersion').value = client.installed_version || '';
  document.getElementById('syncRepAiBalance').value = client.ai_reported_balance || 0;

  let trialDaysVal = '';
  if (client.trial_days_remaining !== undefined && client.trial_days_remaining !== null) {
    trialDaysVal = client.trial_days_remaining;
  } else if (client.license_expires) {
    const expD = new Date(client.license_expires);
    const nowD = new Date();
    trialDaysVal = Math.max(0, Math.ceil((expD - nowD) / (1000 * 60 * 60 * 24)));
  }
  document.getElementById('syncRepTrialDays').value = trialDaysVal;
  document.getElementById('syncRepExpires').value = client.license_expires ? client.license_expires.substring(0, 10) : '';
  document.getElementById('syncRepNotes').value = '';
  openModal('modalSyncReported');
}

/**
 * Transferir token al Inspector Forense de inmediato
 */
function auditTokenInInspector(token) {
  drawerReturnState = null;
  closeClient360Drawer();
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

  const inspTab = document.querySelector('[data-tab="tabInspector"]');
  inspTab?.classList.add('active');
  document.getElementById('tabInspector')?.classList.add('active');

  const inp = document.getElementById('inspectTokenInput');
  if (inp) {
    inp.value = token;
    inspectToken();
    showToast('Token transferido al Inspector Forense.', 'info');
  }
}

// =================== 3B. COMPOSITOR UNIVERSAL DE WHATSAPP (FASE 4) ===================
let currentWaComposerClientId = null;
let currentWaComposerTemplateKey = 'welcome';

const WA_TEMPLATES = {
  welcome: {
    name: 'Saludo y Bienvenida',
    text: '¡Hola, {titular}! 👋 Te saluda el equipo de MochilaLista.\nQueremos darte la más cordial bienvenida a nuestra plataforma de punto de venta 100% Offline-First para tu negocio *{negocio}*.\nTu sistema ya está configurado para operar con el Hardware ID: `{device_id}`.\nCuentas con soporte técnico y todas las herramientas de control comercial sin depender de conexión a internet.\n¡Quedamos atentos a cualquier consulta! 🎒🚀'
  },
  expiring: {
    name: 'Recordatorio de Renovación Preventiva',
    text: 'Estimado(a) {titular}, te saludamos de MochilaLista.\nTe recordamos cordialmente que la licencia de tu sistema para *{negocio}* (Plan {plan}) se encuentra próxima a vencer en *{dias_restantes} día(s)* (Fecha de vencimiento: *{vencimiento}*).\nPara garantizar la continuidad ininterrumpida de tus ventas y la emisión de comprobantes, te invitamos a coordinar tu renovación anticipada.\nHardware ID: `{device_id}`.\n¡Estamos a tu entera disposición! 📲✨'
  },
  prospect: {
    name: 'Seguimiento a Prospecto',
    text: '¡Hola, {titular}! Te saludamos cordialmente de MochilaLista.\nNos comunicamos para hacer seguimiento a la evaluación del sistema de punto de venta en tu negocio *{negocio}*.\n¿Has tenido oportunidad de revisar las funciones de cobro rápido, inventario e IA offline?\nCon gusto podemos coordinar una breve demostración o habilitarte una activación personalizada adaptada al ritmo de tu negocio.\n¡Quedamos a tu orden! 💼📊'
  },
  license: {
    name: 'Entrega Oficial de Licencia / Credencial',
    text: '¡Excelente noticia, {titular}!\nTu licencia oficial de MochilaLista para el negocio *{negocio}* ha sido generada exitosamente.\n\n📌 Detalles de la Licencia:\n• Plan: {plan}\n• Hardware ID: `{device_id}`\n• Vigencia: {vencimiento}\n• Versión: {version}\n\n🔑 Código de Activación:\n`{codigo_licencia}`\n\nPuedes ingresar este código o escanear el QR desde la pantalla de activación de tu aplicación móvil. ¡Gracias por confiar en MochilaLista! 🎒✅'
  },
  update: {
    name: 'Aviso de Nueva Versión APK',
    text: '¡Hola, {titular}! Te saludamos de MochilaLista.\nTe informamos que ya se encuentra disponible una nueva actualización de la aplicación: versión *v{version}* con mejoras clave de rendimiento, estabilidad y nuevas funciones comerciales para tu negocio *{negocio}*.\nTu equipo actual (`{device_id}`) es totalmente compatible.\nContáctanos por este medio para facilitarte el enlace de descarga directa del APK oficial. 🚀📲'
  },
  empty: {
    name: 'Chat Vacío',
    text: ''
  }
};

const DEFAULT_WA_TEMPLATES = JSON.parse(JSON.stringify(WA_TEMPLATES));

function formatPlanLabel(plan) {
  if (!plan) return 'MENSUAL';
  const p = plan.toUpperCase();
  if (p === 'TRIAL') return 'Trial Gratuito';
  if (p === 'MENSUAL') return 'Mensual';
  if (p === 'SEMESTRAL') return 'Semestral';
  if (p === 'ANUAL') return 'Anual';
  if (p === 'PERPETUO_LIBERADO' || p === 'PERPETUO') return 'Perpetuo Liberado';
  if (p === 'EXTENSION_CORTESIA') return 'Cortesía';
  if (p === 'PROSPECTO') return 'Prospecto';
  return plan.replace(/_/g, ' ');
}

async function openWhatsAppComposer(clientId, defaultTemplateKey = null) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) {
    showToast('Cliente no encontrado.', 'error');
    return;
  }

  currentWaComposerClientId = clientId;

  const bizNameEl = document.getElementById('waCompBizName');
  const ownerNameEl = document.getElementById('waCompOwnerName');
  const planBadgeEl = document.getElementById('waCompPlanBadge');
  const devIdEl = document.getElementById('waCompDeviceId');
  const phoneDisplayEl = document.getElementById('waCompPhoneDisplay');
  const phoneWarningEl = document.getElementById('waCompPhoneWarning');
  const sendBtn = document.getElementById('btnWaCompSend');
  const openEmptyBtn = document.getElementById('btnWaCompOpenEmpty');

  if (bizNameEl) bizNameEl.textContent = client.business_name || 'Sin negocio';
  if (ownerNameEl) ownerNameEl.textContent = client.owner_name || 'Sin titular';
  if (devIdEl) devIdEl.textContent = client.current_device_id || 'PENDIENTE';

  const badgeInfo = getClientStatusBadge(client, { asObject: true });
  if (planBadgeEl) {
    planBadgeEl.className = badgeInfo.className;
    planBadgeEl.textContent = badgeInfo.text;
  }
  const isProspect = badgeInfo.isProspect;
  const isPerp = badgeInfo.isPerp;
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const now = new Date();
  const diffDays = expDate ? Math.max(0, Math.ceil((expDate - now) / (1000 * 60 * 60 * 24))) : 0;

  let rawPhone = (client.phone || '').trim();
  let cleanDigits = rawPhone.replace(/[^0-9]/g, '');
  if (cleanDigits.length === 9 && !cleanDigits.startsWith('51')) {
    cleanDigits = '51' + cleanDigits;
  }
  const hasValidPhone = cleanDigits.length >= 9;

  if (phoneDisplayEl) {
    phoneDisplayEl.textContent = rawPhone || 'No registrado';
  }

  if (phoneWarningEl) {
    phoneWarningEl.style.display = hasValidPhone ? 'none' : 'flex';
  }

  if (sendBtn) {
    sendBtn.style.opacity = hasValidPhone ? '1' : '0.4';
    sendBtn.style.pointerEvents = hasValidPhone ? 'auto' : 'none';
  }
  if (openEmptyBtn) {
    openEmptyBtn.style.opacity = hasValidPhone ? '1' : '0.4';
    openEmptyBtn.style.pointerEvents = hasValidPhone ? 'auto' : 'none';
    openEmptyBtn.href = hasValidPhone ? `https://wa.me/${cleanDigits}` : '#';
  }

  // Selección inteligente de plantilla
  let initialTpl = 'welcome';
  if (defaultTemplateKey && WA_TEMPLATES[defaultTemplateKey]) {
    initialTpl = defaultTemplateKey;
  } else if (isProspect) {
    initialTpl = 'prospect';
  } else if (!isPerp && diffDays <= 7) {
    initialTpl = 'expiring';
  } else {
    initialTpl = 'welcome';
  }

  // Cargar token histórico más reciente si existe
  let lastToken = `ML9-PENDIENTE-${client.current_device_id || 'DISPOSITIVO'}`;
  try {
    const res = await fetch(`/api/clients/${clientId}/history`);
    if (res.ok) {
      const history = await res.json();
      if (history.codes && history.codes.length > 0) {
        lastToken = history.codes[history.codes.length - 1].token;
      }
    }
  } catch (_) { }

  const modalEl = document.getElementById('modalWaComposer');
  if (modalEl) {
    modalEl.dataset.lastToken = lastToken;
    modalEl.dataset.cleanPhone = cleanDigits;
  }

  selectWaTemplate(initialTpl);
  openModal('modalWaComposer');
}

function selectWaTemplate(tplKey) {
  if (!WA_TEMPLATES[tplKey]) tplKey = 'welcome';
  currentWaComposerTemplateKey = tplKey;

  document.querySelectorAll('.wa-template-btn').forEach(b => {
    if (b.dataset.tpl === tplKey) {
      b.classList.add('active');
    } else {
      b.classList.remove('active');
    }
  });

  const client = globalClients.find(c => c.id === currentWaComposerClientId);
  const modalEl = document.getElementById('modalWaComposer');
  const lastToken = modalEl?.dataset?.lastToken || 'ML9-PENDIENTE';
  const textarea = document.getElementById('waCompMessage');

  if (!client || !textarea) return;

  const customText = ownerConfig?.templates?.[tplKey];
  const rawTpl = (customText !== undefined && customText !== null) ? customText : (WA_TEMPLATES[tplKey]?.text || '');

  if (!rawTpl) {
    textarea.value = '';
    updateWaComposerStats();
    return;
  }

  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const diffDays = expDate ? Math.max(0, Math.ceil((expDate - now) / (1000 * 60 * 60 * 24))) : 0;
  const latestVer = getLatestPublishedVersion() || client.installed_version || '9.35.0';

  const pm = ownerConfig?.payment_methods || {};
  const li = ownerConfig?.legal_identity || {};
  const yapePhone = pm.yape_plin_phone || '922836879';
  const yapeTitular = pm.yape_plin_holder || li.author_full_name || 'Julio Angello Vasquez Navarro';
  const autor = li.author_full_name || 'Julio Angello Vasquez Navarro';

  let rendered = rawTpl
    .replace(/\{negocio\}/g, client.business_name || 'su negocio')
    .replace(/\{titular\}/g, client.owner_name || 'Estimado cliente')
    .replace(/\{plan\}/g, formatPlanLabel(client.license_type))
    .replace(/\{dias_restantes\}/g, String(diffDays))
    .replace(/\{vencimiento\}/g, client.license_expires ? client.license_expires.substring(0, 10) : 'Activa')
    .replace(/\{device_id\}/g, client.current_device_id || 'PENDIENTE')
    .replace(/\{version\}/g, latestVer)
    .replace(/\{codigo_licencia\}/g, lastToken)
    .replace(/\{codigo\}/g, lastToken)
    .replace(/\{yape_phone\}/g, yapePhone)
    .replace(/\{yape_titular\}/g, yapeTitular)
    .replace(/\{autor\}/g, autor);

  textarea.value = rendered;
  updateWaComposerStats();
}

function updateWaComposerStats() {
  const textarea = document.getElementById('waCompMessage');
  const counter = document.getElementById('waCompCharCounter');
  const sendBtn = document.getElementById('btnWaCompSend');
  const modalEl = document.getElementById('modalWaComposer');
  const cleanDigits = modalEl?.dataset?.cleanPhone || '';

  if (!textarea) return;
  const text = textarea.value;
  if (counter) counter.textContent = `${text.length} caracteres`;

  if (sendBtn && cleanDigits && cleanDigits.length >= 9) {
    sendBtn.href = `https://wa.me/${cleanDigits}?text=${encodeURIComponent(text)}`;
  }
}

function copyWaComposerMessage() {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea || !textarea.value) {
    showToast('El mensaje está vacío.', 'warning');
    return;
  }
  navigator.clipboard.writeText(textarea.value).then(() => {
    showToast('¡Mensaje copiado al portapapeles!', 'success');
  }).catch(() => {
    showToast('Error al copiar el mensaje.', 'error');
  });
}

function insertTextAtCursor(textarea, textToInsert) {
  if (!textarea) return;
  const start = textarea.selectionStart ?? textarea.value.length;
  const end = textarea.selectionEnd ?? textarea.value.length;
  const current = textarea.value;
  textarea.value = current.substring(0, start) + textToInsert + current.substring(end);
  textarea.selectionStart = textarea.selectionEnd = start + textToInsert.length;
  textarea.focus();
  updateWaComposerStats();
}

function insertWaSnippet(type) {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea) return;
  const pm = ownerConfig?.payment_methods || {};
  const li = ownerConfig?.legal_identity || {};
  const client = globalClients.find(c => c.id === currentWaComposerClientId);
  const modalEl = document.getElementById('modalWaComposer');
  const lastToken = modalEl?.dataset?.lastToken || 'ML9-PENDIENTE';

  let textToInsert = '';
  if (type === 'payment' || type === 'yape') {
    const phone = pm.yape_plin_phone || '922836879';
    const titular = pm.yape_plin_holder || li.author_full_name || 'Julio Angello Vasquez Navarro';
    textToInsert = `\n📲 *Datos de Pago Yape / Plin:*\n• Número: *${phone}*\n• Titular: *${titular}*\n• Enviar comprobante por este medio.`;
  } else if (type === 'device' || type === 'hardware') {
    const devId = client?.current_device_id || 'PENDIENTE';
    textToInsert = `\n📱 *Hardware ID:* \`${devId}\``;
  } else if (type === 'expiration' || type === 'vencimiento') {
    const exp = client?.license_expires ? client.license_expires.substring(0, 10) : 'Activa';
    textToInsert = `\n📅 *Vencimiento:* ${exp}`;
  } else if (type === 'token') {
    textToInsert = `\n🔑 *Código de Licencia:*\n\`${lastToken}\``;
  }

  if (textToInsert) {
    insertTextAtCursor(textarea, textToInsert);
  }
}

async function saveCurrentWaTemplate() {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea) return;
  const newText = textarea.value;

  if (!ownerConfig) ownerConfig = {};
  if (!ownerConfig.templates) ownerConfig.templates = {};
  ownerConfig.templates[currentWaComposerTemplateKey] = newText;
  if (WA_TEMPLATES[currentWaComposerTemplateKey]) {
    WA_TEMPLATES[currentWaComposerTemplateKey].text = newText;
  }

  try {
    const res = await fetch('/api/config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(ownerConfig),
    });
    if (!res.ok) throw new Error('Error al guardar plantilla');
    showToast('Plantilla guardada exitosamente.', 'success');
  } catch (e) {
    showToast('Error al guardar plantilla: ' + e.message, 'error');
  }
}

async function resetCurrentWaTemplate() {
  const defaultText = DEFAULT_WA_TEMPLATES[currentWaComposerTemplateKey]?.text || '';
  if (WA_TEMPLATES[currentWaComposerTemplateKey]) {
    WA_TEMPLATES[currentWaComposerTemplateKey].text = defaultText;
  }

  if (ownerConfig?.templates) {
    delete ownerConfig.templates[currentWaComposerTemplateKey];
    try {
      await fetch('/api/config', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(ownerConfig),
      });
    } catch (_) { }
  }

  selectWaTemplate(currentWaComposerTemplateKey);
  showToast('Plantilla restaurada a los valores predeterminados.', 'info');
}

function initWaComposerEvents() {
  document.getElementById('waCompMessage')?.addEventListener('input', updateWaComposerStats);

  // Botones de selección de plantillas
  document.querySelectorAll('.wa-template-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      selectWaTemplate(btn.dataset.tpl);
    });
  });

  // Botones de acción en compositor
  document.getElementById('btnWaSaveTemplate')?.addEventListener('click', saveCurrentWaTemplate);
  document.getElementById('btnWaResetTemplate')?.addEventListener('click', resetCurrentWaTemplate);
  document.getElementById('btnWaCompCopy')?.addEventListener('click', copyWaComposerMessage);
}

// =================== 4. RELEASE MANAGER & SUBIDA DE APK DIRECTA ===================
async function loadReleases() {
  try {
    const res = await fetch('/api/releases', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar versiones');
    globalReleases = await res.json();

    const tbody = document.getElementById('releasesTableBody');
    tbody.innerHTML = '';

    if (globalReleases.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No hay versiones registradas en este entorno.</td></tr>';
      if (globalClients && globalClients.length > 0) {
        updateFilterCounts();
        renderClientsTable();
      }
      return;
    }

    globalReleases.forEach(r => {
      const tr = document.createElement('tr');
      const badge = r.type === 'HOTFIX'
        ? '<span class="badge badge-green">HOTFIX (Parche)</span>'
        : '<span class="badge badge-purple">FEATURE RELEASE</span>';

      const shortSha = r.apk_sha256 ? `${r.apk_sha256.substring(0, 12)}...` : '-';
      const sizeInfo = r.file_size_mb ? `${r.file_size_mb} MB` : '-';

      tr.innerHTML = `
        <td><strong>v${escapeHtml(r.version_name)}</strong></td>
        <td>${r.version_code}</td>
        <td>Esquema v${r.db_schema_version}</td>
        <td>${badge}</td>
        <td>${r.release_date ? r.release_date.substring(0, 10) : '-'}</td>
        <td>
          <div style="font-size:0.75rem; color:var(--text-secondary);">${sizeInfo}</div>
          <code style="font-family:var(--font-mono); font-size:0.75rem;" title="${escapeHtml(r.apk_sha256)}">${shortSha}</code>
        </td>
        <td>
          <div style="display:flex; gap:0.35rem; flex-wrap:wrap;">
            <a href="/api/releases/download/${encodeURIComponent(r.version_name)}" class="btn btn-outline btn-sm" title="Descargar APK directo del servidor">
              ⬇️ APK
            </a>
            <button class="btn btn-outline btn-sm" onclick="revealReleaseInExplorer('${escapeHtml(r.version_name)}')" title="Mostrar en Carpeta de Windows">
              📂 Carpeta
            </button>
            <button class="btn btn-outline btn-sm" onclick="openEditReleaseModal('${escapeHtml(r.version_name)}')" title="Editar Changelog">
              ✏️
            </button>
            <button class="btn btn-outline btn-sm" style="color:var(--danger); border-color:var(--danger);" onclick="deleteRelease('${escapeHtml(r.version_name)}')" title="Eliminar Versión">
              🗑️
            </button>
          </div>
        </td>
      `;
      tbody.appendChild(tr);
    });

    if (globalClients && globalClients.length > 0) {
      updateFilterCounts();
      renderClientsTable();
    }
  } catch (e) {
    console.error('Error al cargar releases:', e);
  }
}

async function revealReleaseInExplorer(versionName) {
  try {
    const res = await fetch('/api/releases/reveal-file', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ version_name: versionName }),
    });
    if (!res.ok) throw new Error('No se pudo abrir el explorador');
    showToast(`Mostrando versión v${versionName} en el Explorador de Windows.`, 'info');
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

function openEditReleaseModal(versionName) {
  const rel = globalReleases.find(r => r.version_name === versionName);
  if (!rel) return;

  document.getElementById('editRelVersionName').value = rel.version_name;
  document.getElementById('editRelVersionDisplay').value = `v${rel.version_name} (Build ${rel.version_code})`;
  document.getElementById('editRelType').value = rel.type || 'FEATURE_RELEASE';
  document.getElementById('editRelDownloadUrl').value = rel.apk_download_url || '';
  document.getElementById('editRelChangelog').value = rel.changelog || '';

  openModal('modalEditRelease');
}

function deleteRelease(versionName) {
  showConfirmModal(
    'Eliminar Versión del Catálogo',
    `¿Estás seguro de eliminar permanentemente la versión v${versionName}? Si el archivo .apk existe en disco, también se eliminará.`,
    async () => {
      try {
        const res = await fetch(`/api/releases/${encodeURIComponent(versionName)}`, {
          method: 'DELETE',
        });
        if (!res.ok) throw new Error('Error al eliminar versión');
        showToast(`Versión v${versionName} eliminada.`, 'success');
        await loadReleases();
        await loadReleaseMatrix();
        await loadDashboard();
      } catch (e) {
        showToast('Error: ' + e.message, 'error');
      }
    },
    true
  );
}

async function loadReleaseMatrix() {
  try {
    const res = await fetch('/api/releases/matrix', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar matriz');
    const matrix = await res.json();

    const tbody = document.getElementById('matrixTableBody');
    tbody.innerHTML = '';

    if (matrix.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Sin clientes para evaluar matriz.</td></tr>';
      return;
    }

    matrix.forEach(row => {
      const tr = document.createElement('tr');

      let statusBadge = '<span class="badge badge-green">✓ Al Día</span>';
      if (!row.is_up_to_date) {
        statusBadge = row.is_eligible_for_free
          ? '<span class="badge badge-green">Derecho Gratuito</span>'
          : '<span class="badge badge-yellow">Requiere Pase / Renovación</span>';
      }

      const cleanPhone = (row.phone || '').replace(/[^0-9]/g, '');
      const downloadLink = row.download_url || `http://localhost:8080/api/releases/download/${encodeURIComponent(row.latest_version)}`;

      // Mensaje WA para elegibles
      const waMsgEligible = encodeURIComponent(
        renderConfigTemplate('apk_update_eligible', {
          titular: row.owner_name,
          negocio: row.business_name,
          version: row.latest_version,
          changelog: row.changelog || 'Mejoras de rendimiento, seguridad y nuevas funciones.',
          link_descarga: downloadLink,
        })
      );

      // Mensaje WA para NO elegibles (cotización)
      const passPrice = (ownerConfig?.catalog?.PASE_ACTUALIZACION_ANUAL?.price || 150).toFixed(2);
      const waMsgQuote = encodeURIComponent(
        renderConfigTemplate('apk_update_quote', {
          titular: row.owner_name,
          negocio: row.business_name,
          version: row.latest_version,
          version_actual: row.installed_version,
          precio_pase: passPrice,
        })
      );

      let actionButtons = '<span style="color:var(--text-muted); font-size:0.8rem;">Sin acción requerida</span>';

      if (!row.is_up_to_date) {
        if (row.is_eligible_for_free) {
          actionButtons = `
            <a href="https://api.whatsapp.com/send?phone=${cleanPhone}&text=${waMsgEligible}" target="_blank" class="btn btn-wa btn-sm">
              📲 Enviar APK
            </a>
            <button class="btn btn-outline btn-sm" onclick="markClientUpdated('${row.client_id}', '${row.latest_version}')" title="Marcar como actualizado a v${row.latest_version}">
              ✓ Marcar Actualizado
            </button>
          `;
        } else {
          // Requiere pase, pero con botón secundario discreto de autorización de cortesía
          actionButtons = `
            <a href="https://api.whatsapp.com/send?phone=${cleanPhone}&text=${waMsgQuote}" target="_blank" class="btn btn-outline btn-sm">
              💳 Cotizar Pase
            </a>
            <button class="btn btn-primary btn-sm" onclick="jumpToIssuePass('${row.client_id}')" title="Ir a Emitir Pase Anual">
              🔑 Emitir Pase
            </button>
            <button class="btn btn-outline btn-sm" style="opacity:0.85;" onclick="authorizeCourtesyUpdate('${row.client_id}', '${row.latest_version}', '${escapeHtml(row.business_name)}', '${cleanPhone}', '${escapeHtml(row.owner_name)}')" title="Autorizar Envío de Cortesía Excepcional">
              🎁 Cortesía
            </button>
          `;
        }
      }

      tr.innerHTML = `
        <td><strong>${escapeHtml(row.business_name)}</strong></td>
        <td>${escapeHtml(row.phone)}</td>
        <td>v${escapeHtml(row.installed_version)}</td>
        <td>v${escapeHtml(row.latest_version)}</td>
        <td>${escapeHtml(row.release_type)}</td>
        <td>${statusBadge}</td>
        <td>
          <div style="display:flex; gap:0.4rem; flex-wrap:wrap;">
            ${actionButtons}
          </div>
        </td>
      `;
      tbody.appendChild(tr);
    });
  } catch (e) {
    console.error('Error al cargar matriz:', e);
  }
}

function jumpToIssuePass(clientId) {
  selectClientForLicense(clientId);
  const planSelect = document.getElementById('licPlanSelect');
  if (planSelect) {
    planSelect.value = 'PASE_ACTUALIZACION_ANUAL';
    updatePlanImpactAndProjection();
  }
}

function authorizeCourtesyUpdate(clientId, latestVersion, businessName, cleanPhone, ownerName) {
  showConfirmModal(
    'Autorizar Envío de Cortesía',
    `¿Deseas autorizar excepcionalmente el envío gratuito de la versión v${latestVersion} a "${businessName}" sin requerir el pago del pase anual?`,
    async () => {
      await markClientUpdated(clientId, latestVersion);
      const downloadLink = `http://localhost:8080/api/releases/download/${encodeURIComponent(latestVersion)}`;
      const waMsg = encodeURIComponent(
        `Hola ${ownerName}, te saluda Julio Angello Vasquez Navarro de MochilaLista.\n\n` +
        `Como cortesía especial por tu fidelidad comercial, te hemos liberado el acceso directo a la nueva versión *v${latestVersion}* para tu negocio *${businessName}*.\n\n` +
        `📥 *Enlace de descarga:* ${downloadLink}\n\n` +
        `¡Disfruta de las nuevas funciones!`
      );
      if (cleanPhone) {
        window.open(`https://api.whatsapp.com/send?phone=${cleanPhone}&text=${waMsg}`, '_blank');
      }
      showToast(`Cortesía autorizada para ${businessName}.`, 'success');
    }
  );
}

async function markClientUpdated(clientId, versionName) {
  try {
    const res = await fetch(`/api/clients/${clientId}/mark-updated`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ version_name: versionName }),
    });
    if (!res.ok) throw new Error('Error al marcar cliente actualizado');
    showToast(`Cliente actualizado a v${versionName} en el registro.`, 'success');
    loadReleaseMatrix();
    loadClients();
    loadDashboard();
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

function initReleaseUploadAndAutoDetect() {
  const dropZone = document.getElementById('apkDropZone');
  const fileInput = document.getElementById('apkFileInput');
  const progressBar = document.getElementById('apkProgressBar');
  const progressContainer = document.getElementById('apkUploadProgress');
  const progressText = document.getElementById('apkUploadStatusText');

  // Drag & drop handlers
  dropZone?.addEventListener('click', () => fileInput?.click());

  dropZone?.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('dragover');
  });

  dropZone?.addEventListener('dragleave', () => {
    dropZone.classList.remove('dragover');
  });

  dropZone?.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('dragover');
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleApkUpload(e.dataTransfer.files[0]);
    }
  });

  fileInput?.addEventListener('change', () => {
    if (fileInput.files && fileInput.files.length > 0) {
      handleApkUpload(fileInput.files[0]);
    }
  });

  // Autodetectar build local
  document.getElementById('btnDetectLocalBuild')?.addEventListener('click', async () => {
    const statusEl = document.getElementById('detectApkStatus');
    const buttonsContainer = document.getElementById('detectApkButtonsContainer');
    if (statusEl) statusEl.textContent = 'Buscando compilaciones locales en app_movil...';

    try {
      const res = await fetch('/api/releases/detect-local-build');
      if (!res.ok) throw new Error('Error al autodetectar build');
      const data = await res.json();

      document.getElementById('relVersionName').value = data.version_name || '';
      document.getElementById('relVersionCode').value = data.version_code || 24;

      if (data.apk_found) {
        document.getElementById('relSha256').value = data.sha256 || '';
        document.getElementById('relSizeMb').value = data.file_size_mb || '';

        if (statusEl) {
          statusEl.innerHTML = `✅ <strong style="color:var(--success);">${data.file_name} (${data.file_size_mb})</strong> seleccionado.`;
        }

        // Si existen múltiples compilaciones (ARM64 vs Universal)
        if (buttonsContainer && data.available_builds && data.available_builds.length > 1) {
          buttonsContainer.style.display = 'flex';
          buttonsContainer.innerHTML = '';
          data.available_builds.forEach(b => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'btn btn-outline btn-sm';
            btn.innerHTML = `${b.architecture === 'arm64-v8a' ? '🚀 ARM64 Ligero' : '📦 Universal'} (${b.size_mb})`;
            btn.onclick = () => {
              document.getElementById('relSha256').value = b.sha256;
              document.getElementById('relSizeMb').value = b.size_mb;
              if (statusEl) {
                statusEl.innerHTML = `✅ <strong style="color:var(--success);">${b.file_name} (${b.size_mb})</strong> seleccionado.`;
              }
              showToast(`Seleccionado ${b.label}`, 'info');
            };
            buttonsContainer.appendChild(btn);
          });
        }

        showToast(`APK detectado: ${data.file_name} (${data.file_size_mb})`, 'success');
      } else {
        if (statusEl) {
          statusEl.innerHTML = `ℹ️ Versión detectada <strong>v${data.version_name}</strong>. No se encontró APK en app_movil/build/... (compila con compilar_apk_arm64.bat).`;
        }
        if (buttonsContainer) buttonsContainer.style.display = 'none';
        showToast(`Versión encontrada: v${data.version_name} (sin archivo APK compilado)`, 'info');
      }
    } catch (e) {
      if (statusEl) statusEl.textContent = 'Error: ' + e.message;
      showToast('Error: ' + e.message, 'error');
    }
  });
}

async function handleApkUpload(file) {
  if (!file.name.toLowerCase().endsWith('.apk')) {
    showToast('El archivo seleccionado no es un archivo .APK válido.', 'error');
    return;
  }

  const progressBar = document.getElementById('apkProgressBar');
  const progressContainer = document.getElementById('apkUploadProgress');
  const progressText = document.getElementById('apkUploadStatusText');

  if (progressContainer) progressContainer.style.display = 'block';
  if (progressBar) progressBar.style.width = '20%';
  if (progressText) progressText.textContent = `Subiendo ${file.name} (${(file.size / (1024 * 1024)).toFixed(2)} MB)...`;

  try {
    const res = await fetch(`/api/releases/upload-apk?filename=${encodeURIComponent(file.name)}`, {
      method: 'POST',
      body: file,
    });

    if (progressBar) progressBar.style.width = '80%';

    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || 'Fallo en la subida del APK');
    }

    const data = await res.json();

    if (progressBar) progressBar.style.width = '100%';
    if (progressText) progressText.textContent = `✅ ${data.file_name} guardado con éxito (${data.file_size_mb}).`;

    document.getElementById('relSha256').value = data.sha256 || '';
    document.getElementById('relSizeMb').value = data.file_size_mb || '';

    // Inferir versión si viene en el nombre
    const match = file.name.match(/(\d+\.\d+\.\d+)/);
    if (match && !document.getElementById('relVersionName').value) {
      document.getElementById('relVersionName').value = match[1];
    }

    showToast(`APK ${data.file_name} subido y verificado criptográficamente.`, 'success');
  } catch (e) {
    if (progressBar) progressBar.style.width = '0%';
    if (progressText) progressText.textContent = '❌ Error al subir APK.';
    showToast('Error al subir APK: ' + e.message, 'error');
  }
}

// =================== 5. INSPECTOR DE TOKENS ML9 CON LECTOR ÓPTICO QR ===================
function initInspectorEvents() {
  document.getElementById('btnInspectToken')?.addEventListener('click', inspectToken);
  document.getElementById('btnClearInspectToken')?.addEventListener('click', () => {
    document.getElementById('inspectTokenInput').value = '';
    document.getElementById('inspectResultContainer').style.display = 'none';
  });

  // Lector óptico Drag & Drop
  const qrDropZone = document.getElementById('qrOpticalDropZone');
  const qrFileInput = document.getElementById('qrOpticalFileInput');

  qrDropZone?.addEventListener('click', () => qrFileInput?.click());

  qrDropZone?.addEventListener('dragover', (e) => {
    e.preventDefault();
    qrDropZone.classList.add('dragover');
  });

  qrDropZone?.addEventListener('dragleave', () => {
    qrDropZone.classList.remove('dragover');
  });

  qrDropZone?.addEventListener('drop', (e) => {
    e.preventDefault();
    qrDropZone.classList.remove('dragover');
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleOpticalQrFile(e.dataTransfer.files[0]);
    }
  });

  qrFileInput?.addEventListener('change', () => {
    if (qrFileInput.files && qrFileInput.files.length > 0) {
      handleOpticalQrFile(qrFileInput.files[0]);
    }
  });
}

async function handleOpticalQrFile(file) {
  if (!file.type.startsWith('image/')) {
    showToast('El archivo no es una imagen válida (PNG, JPG, etc.).', 'error');
    return;
  }

  showToast('Procesando imagen ópticamente...', 'info');

  const reader = new FileReader();
  reader.onload = async (e) => {
    const img = new Image();
    img.onload = async () => {
      // 1. Intentar decodificación con jsQR
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0);

      let decodedText = null;

      if (typeof jsQR !== 'undefined') {
        try {
          const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
          const code = jsQR(imgData.data, imgData.width, imgData.height, {
            inversionAttempts: 'dontInvert',
          });
          if (code && code.data) {
            decodedText = code.data;
          }
        } catch (err) {
          console.error('jsQR error:', err);
        }
      }

      // 2. Fallback con BarcodeDetector si está disponible en el navegador
      if (!decodedText && 'BarcodeDetector' in window) {
        try {
          const detector = new BarcodeDetector({ formats: ['qr_code'] });
          const barcodes = await detector.detect(img);
          if (barcodes.length > 0) {
            decodedText = barcodes[0].rawValue;
          }
        } catch (err) {
          console.error('BarcodeDetector error:', err);
        }
      }

      if (decodedText) {
        document.getElementById('inspectTokenInput').value = decodedText;
        showToast('¡Código QR detectado y decodificado ópticamente!', 'success');
        inspectToken();
      } else {
        showToast('No se encontró un código QR legible en la imagen. Intenta con una imagen más nítida.', 'warning');
      }
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
}

async function inspectToken() {
  const token = document.getElementById('inspectTokenInput').value.trim();
  if (!token) {
    showToast('Por favor pega un código de licencia o sube una imagen con QR.', 'warning');
    return;
  }

  try {
    const res = await fetch('/api/licenses/inspect', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: token }),
    });

    if (!res.ok) throw new Error('Error al auditar el código');
    const data = await res.json();

    const container = document.getElementById('inspectResultContainer');
    const badge = document.getElementById('inspectStatusBadge');
    const tbody = document.getElementById('inspectClaimsTableBody');
    const matchBox = document.getElementById('inspectMatchingClientBox');

    container.style.display = 'block';

    if (data.valid || data.isValid) {
      badge.style.background = 'rgba(16, 185, 129, 0.15)';
      badge.style.border = '1px solid rgba(16, 185, 129, 0.4)';
      badge.style.color = '#10b981';
      badge.innerHTML = `✅ <strong>TOKEN VÁLIDO:</strong> ${escapeHtml(data.message || 'Firma criptográfica Ed25519 auténtica.')}`;
    } else {
      badge.style.background = 'rgba(239, 68, 68, 0.15)';
      badge.style.border = '1px solid rgba(239, 68, 68, 0.4)';
      badge.style.color = '#ef4444';
      badge.innerHTML = `❌ <strong>TOKEN INVÁLIDO (${escapeHtml(data.status || 'ERROR')}):</strong> ${escapeHtml(data.message || data.error)}`;
    }

    if (!data.payload) {
      tbody.innerHTML = '<tr><td colspan="4" style="text-align:center; color:var(--text-muted); padding:1rem;">El token no contiene un payload decodificable.</td></tr>';
      matchBox.style.display = 'none';
      return;
    }

    // Tabla Unificada de Claims (Sincronizada con Planes 07 y 08)
    const p = data.payload;
    const claims = [
      { key: 'd', name: 'hardware_id', desc: 'Hardware ID único generado desde Settings.Secure.ANDROID_ID', val: p.d || data.device_id || '-' },
      { key: 'p', name: 'plan', desc: 'Tipo de plan comercial otorgado', val: p.p || data.plan || '-' },
      { key: 'y', name: 'days_added', desc: 'Días acumulativos sumados a la vigencia', val: `+${p.y !== undefined ? p.y : data.days_added} días` },
      { key: 'n', name: 'nonce', desc: 'Contador correlativo anti-reutilización', val: `#${p.n !== undefined ? p.n : data.nonce}` },
      { key: 'v', name: 'min_app_version', desc: 'Versión mayor mínima requerida', val: `v${p.v !== undefined ? p.v : data.max_major_version}` },
      { key: 'iat', name: 'emitted_at', desc: 'Marca de tiempo ISO-8601 de emisión (UTC)', val: p.e || p.iat || data.emitted_at || '-' },
      { key: 'u', name: 'updates_until', desc: 'Fecha límite de actualizaciones (updates)', val: p.u || data.updates_until || 'No aplica' },
      { key: 'b', name: 'business_tag', desc: 'Razón social o etiqueta del negocio', val: p.b || data.business_tag || '-' },
      { key: 'c', name: 'ai_extra_credits', desc: 'Créditos IA extras/recarga (claim c de transporte anti-doble conteo)', val: `+${p.c !== undefined ? p.c : data.ai_extra_credits} escaneos` },
    ];

    tbody.innerHTML = '';
    claims.forEach(c => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><span class="claims-compact-key">${escapeHtml(c.key)}</span></td>
        <td><code>${escapeHtml(c.name)}</code></td>
        <td style="color:var(--text-secondary);">${escapeHtml(c.desc)}</td>
        <td><strong>${escapeHtml(String(c.val))}</strong></td>
      `;
      tbody.appendChild(tr);
    });

    // Cruce con Cliente Registrado en CRM
    const matchedClient = data.matching_client || data.registered_client;
    if (matchedClient) {
      matchBox.style.display = 'block';
      const cNonce = matchedClient.next_nonce || 1;
      const tNonce = p.n !== undefined ? p.n : data.nonce;
      let nonceStatusBadge = '';

      if (tNonce === cNonce - 1) {
        nonceStatusBadge = '<span class="badge badge-green">✓ Nonce vigente (última emitida)</span>';
      } else if (tNonce >= cNonce) {
        nonceStatusBadge = '<span class="badge badge-yellow">⚡ Nonce futuro listo para canje</span>';
      } else {
        nonceStatusBadge = '<span class="badge badge-purple">ℹ️ Nonce histórico ya superado</span>';
      }

      matchBox.innerHTML = `
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem; margin-bottom:0.4rem;">
          <strong style="color:var(--primary); font-size:0.95rem;">🏢 Cliente Coincidente en Cartera:</strong>
          ${nonceStatusBadge}
        </div>
        <p style="margin:0; color:var(--text-primary); font-size:0.88rem;">
          <strong>${escapeHtml(matchedClient.business_name)}</strong> (${escapeHtml(matchedClient.owner_name)})
          • WhatsApp: <strong>${escapeHtml(matchedClient.phone)}</strong>
          • Plan en DB: <span class="badge badge-mono">${escapeHtml(matchedClient.license_type)}</span>
          • Versión Instalada: v${escapeHtml(matchedClient.installed_version || '9.24.0')}
        </p>
      `;
    } else {
      matchBox.style.display = 'block';
      matchBox.innerHTML = `
        <span style="color:var(--text-muted); font-size:0.85rem;">
          ℹ️ El token fue firmado válidamente con tu clave maestra pero el Device ID <code>${escapeHtml(p.d || '-')}</code> no coincide con ningún cliente registrado en este entorno.
        </span>
      `;
    }
  } catch (e) {
    showToast('Error al auditar token: ' + e.message, 'error');
  }
}

// =================== 6. FINANZAS & RESPALDOS (NUEVA PESTAÑA OFICIAL) ===================
function initFinancesAndBackupsEvents() {
  // Filtros de Finanzas
  document.getElementById('finFilterFrom')?.addEventListener('change', renderFinancesTable);
  document.getElementById('finFilterTo')?.addEventListener('change', renderFinancesTable);
  document.getElementById('finFilterPlan')?.addEventListener('change', renderFinancesTable);
  document.getElementById('finFilterMethod')?.addEventListener('change', renderFinancesTable);
  document.getElementById('btnFinFilterClear')?.addEventListener('click', () => {
    document.getElementById('finFilterFrom').value = '';
    document.getElementById('finFilterTo').value = '';
    document.getElementById('finFilterPlan').value = 'all';
    document.getElementById('finFilterMethod').value = 'all';
    renderFinancesTable();
  });

  document.getElementById('btnExportFinancesCsv')?.addEventListener('click', () => {
    window.open('/api/finances/export-csv', '_blank');
    showToast('Exportando libro contable a CSV...', 'info');
  });

  // Acciones de Respaldos
  document.getElementById('btnCreateBackupNow')?.addEventListener('click', async () => {
    try {
      const res = await fetch('/api/backups/create', { method: 'POST' });
      if (!res.ok) throw new Error('Error al crear respaldo');
      showToast('Snapshot manual creado exitosamente en disco.', 'success');
      await loadBackups();
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  document.getElementById('btnOpenBackupsFolder')?.addEventListener('click', async () => {
    try {
      const res = await fetch('/api/backups/open-folder', { method: 'POST' });
      if (!res.ok) throw new Error('No se pudo abrir la carpeta');
      showToast('Carpeta backups/ abierta en el Explorador de Windows.', 'info');
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });
}

async function loadFinances() {
  try {
    const res = await fetch('/api/finances', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar finanzas');
    globalFinances = await res.json();
    renderFinancesTable();
  } catch (e) {
    console.error('Error al cargar finanzas:', e);
  }
}

function renderFinancesTable() {
  const tbody = document.getElementById('financesTableBody');
  if (!tbody) return;
  tbody.innerHTML = '';

  const fromVal = document.getElementById('finFilterFrom')?.value;
  const toVal = document.getElementById('finFilterTo')?.value;
  const planVal = document.getElementById('finFilterPlan')?.value || 'all';
  const methodVal = document.getElementById('finFilterMethod')?.value || 'all';

  const filtered = globalFinances.filter(f => {
    if (fromVal && f.date && f.date.substring(0, 10) < fromVal) return false;
    if (toVal && f.date && f.date.substring(0, 10) > toVal) return false;
    if (planVal !== 'all' && !(f.plan || '').toUpperCase().includes(planVal.toUpperCase())) return false;
    if (methodVal !== 'all' && !(f.method || '').toUpperCase().includes(methodVal.toUpperCase())) return false;
    return true;
  });

  // Calcular KPIs contables dinámicos
  let totalRev = 0.0;
  const methodCounts = {};

  filtered.forEach(f => {
    const amt = parseFloat(f.amount) || 0;
    totalRev += amt;
    const m = f.method || 'Otro';
    methodCounts[m] = (methodCounts[m] || 0) + amt;
  });

  const count = filtered.length;
  const avg = count > 0 ? (totalRev / count) : 0;

  let topMethod = '-';
  let maxMethodAmt = 0;
  for (const [m, amt] of Object.entries(methodCounts)) {
    if (amt > maxMethodAmt) {
      maxMethodAmt = amt;
      topMethod = m;
    }
  }

  document.getElementById('finKpiTotalRevenue').textContent = `S/ ${totalRev.toFixed(2)}`;
  document.getElementById('finKpiAverageTicket').textContent = `S/ ${avg.toFixed(2)}`;
  document.getElementById('finKpiCount').textContent = count;
  document.getElementById('finKpiTopMethod').textContent = topMethod;

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="9" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Sin transacciones registradas para este filtro.</td></tr>';
    return;
  }

  filtered.forEach(f => {
    const tr = document.createElement('tr');
    const receiptBadge = f.receipt_number 
      ? `<span class="badge badge-success" style="font-size:0.75rem; letter-spacing:0.5px; padding:3px 6px;">${escapeHtml(f.receipt_number)}</span>`
      : `<span style="font-size:0.75rem; color:var(--text-muted);">Sin emitir</span>`;
    tr.innerHTML = `
      <td>${f.date ? f.date.substring(0, 10) : '-'}</td>
      <td><strong>${escapeHtml(f.client_id)}</strong></td>
      <td><strong>${escapeHtml(f.business_name)}</strong></td>
      <td>${escapeHtml(f.owner_name)}</td>
      <td><span class="badge badge-mono">${escapeHtml(f.plan)}</span></td>
      <td>${escapeHtml(f.method)}</td>
      <td>${escapeHtml(f.reference)}</td>
      <td><strong style="color:var(--success);">S/ ${(f.amount || 0).toFixed(2)}</strong></td>
      <td style="text-align:center;">
        <button type="button" class="btn btn-secondary btn-xs btn-fin-receipt" title="Generar o Ver Boleta Oficial" onclick="openPaymentReceiptModal('${escapeHtml(f.client_id)}', '${escapeHtml(f.id)}')">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right:4px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
          ${f.receipt_number ? escapeHtml(f.receipt_number) : 'Boleta'}
        </button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

async function loadBackups() {
  try {
    const res = await fetch('/api/backups', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar respaldos');
    const backups = await res.json();

    const tbody = document.getElementById('backupsTableBody');
    if (!tbody) return;
    tbody.innerHTML = '';

    if (backups.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No hay respaldos generados en la carpeta backups/.</td></tr>';
      return;
    }

    backups.forEach(b => {
      const tr = document.createElement('tr');
      const modeBadge = b.mode === 'prod'
        ? '<span class="badge badge-green">PROD</span>'
        : (b.mode === 'sandbox' ? '<span class="badge badge-yellow">SANDBOX</span>' : '<span class="badge badge-purple">GLOBAL</span>');

      tr.innerHTML = `
        <td><code style="font-family:var(--font-mono); font-size:0.8rem;">${escapeHtml(b.filename)}</code></td>
        <td>${b.modified_at ? b.modified_at.replace('T', ' ').substring(0, 19) : '-'}</td>
        <td>${b.size_kb} KB</td>
        <td>${modeBadge}</td>
        <td>
          <div style="display:flex; gap:0.35rem;">
            <a href="/api/backups/download/${encodeURIComponent(b.filename)}" class="btn btn-outline btn-sm" title="Descargar archivo JSON a PC o USB">
              ⬇️
            </a>
            <button class="btn btn-outline btn-sm" style="color:var(--warning); border-color:var(--warning);" onclick="restoreBackup('${escapeHtml(b.filename)}')" title="Restaurar a este punto">
              ⏪ Restaurar
            </button>
          </div>
        </td>
      `;
      tbody.appendChild(tr);
    });
  } catch (e) {
    console.error('Error al cargar backups:', e);
  }
}

function restoreBackup(filename) {
  showConfirmModal(
    'Restaurar Base de Datos a este Punto',
    `¿Estás seguro de restaurar el sistema a partir de "${filename}"? Se creará automáticamente un snapshot de seguridad previo.`,
    async () => {
      try {
        const res = await fetch('/api/backups/restore', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ filename: filename }),
        });
        if (!res.ok) {
          const err = await res.json();
          throw new Error(err.error || 'Error al restaurar');
        }
        showToast('Base de datos restaurada con éxito.', 'success');
        await loadDashboard();
        await loadClients();
        await loadReleases();
        await loadReleaseMatrix();
        await loadFinances();
        await loadBackups();
      } catch (e) {
        showToast('Error al restaurar: ' + e.message, 'error');
      }
    },
    true
  );
}

// =================== 7. MODALES Y CRUD ===================
function initModalEvents() {
  // Cierre de modales al hacer clic en el backdrop exterior
  document.querySelectorAll('.modal-overlay').forEach(modal => {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        closeModal(modal.id);
      }
    });
  });

  // Listener global de tecla Escape para modales y drawer
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const openModals = document.querySelectorAll('.modal-overlay.open');
      if (openModals.length > 0) {
        const topModal = openModals[openModals.length - 1];
        closeModal(topModal.id);
      } else {
        const drawer = document.getElementById('drawerClient360');
        if (drawer && drawer.classList.contains('open')) {
          closeClient360Drawer();
        }
      }
    }
  });

  // Filtros de cartera
  document.querySelectorAll('.filter-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      currentClientFilter = chip.dataset.filter;
      renderClientsTable();
    });
  });

  // Modal Crear Cliente (Reingeniería Fase 3)
  const situationSelect = document.getElementById('newClientSituation');
  const updateSituationFields = () => {
    const sit = situationSelect?.value || 'TRIAL';
    const grpPlan = document.getElementById('grpNewPlan');
    const grpTrial = document.getElementById('grpTrialDaysRemaining');
    const grpSubDate = document.getElementById('grpExpectedSubscriptionDate');
    const lblDevice = document.getElementById('lblNewDeviceId');
    const reqDevice = document.getElementById('reqStarDeviceId');
    const inputDevice = document.getElementById('newDeviceId');
    const aiReported = document.getElementById('newAiReportedBalance');

    if (sit === 'PROSPECTO') {
      if (grpPlan) grpPlan.style.display = 'none';
      if (grpTrial) grpTrial.style.display = 'none';
      if (grpSubDate) grpSubDate.style.display = 'flex';
      if (lblDevice) lblDevice.innerHTML = 'Hardware ID (Opcional — PENDIENTE):';
      if (reqDevice) reqDevice.style.display = 'none';
      if (inputDevice) {
        inputDevice.required = false;
        inputDevice.placeholder = 'PENDIENTE (Opcional)';
      }
      if (aiReported && !aiReported.dataset.manual) aiReported.value = 0;
    } else if (sit === 'TRIAL') {
      if (grpPlan) grpPlan.style.display = 'none';
      if (grpTrial) grpTrial.style.display = 'flex';
      if (grpSubDate) grpSubDate.style.display = 'none';
      if (lblDevice) lblDevice.innerHTML = 'Hardware ID del Celular (ML-XXXX): <span class="required-star">*</span>';
      if (reqDevice) reqDevice.style.display = 'inline';
      if (inputDevice) {
        inputDevice.required = true;
        inputDevice.placeholder = 'Ej: ML-9K4B';
      }
      if (aiReported && !aiReported.dataset.manual) aiReported.value = 50;
    } else { // COMMERCIAL
      if (grpPlan) grpPlan.style.display = 'flex';
      if (grpTrial) grpTrial.style.display = 'none';
      if (grpSubDate) grpSubDate.style.display = 'none';
      if (lblDevice) lblDevice.innerHTML = 'Hardware ID del Celular (ML-XXXX): <span class="required-star">*</span>';
      if (reqDevice) reqDevice.style.display = 'inline';
      if (inputDevice) {
        inputDevice.required = true;
        inputDevice.placeholder = 'Ej: ML-9K4B';
      }
      if (aiReported && !aiReported.dataset.manual) aiReported.value = 0;
    }
  };

  situationSelect?.addEventListener('change', updateSituationFields);

  // Aviso Contextual de Crédito IA Offline
  const aiBonusInput = document.getElementById('newAiPendingBonus');
  aiBonusInput?.addEventListener('input', () => {
    const val = parseInt(aiBonusInput.value) || 0;
    const notice = document.getElementById('noticeAiBonus');
    if (notice) {
      notice.style.display = val > 0 ? 'block' : 'none';
    }
  });

  // Normalización interactiva de Teléfono
  const phoneInput = document.getElementById('newPhone');
  phoneInput?.addEventListener('input', () => {
    const hint = document.getElementById('hintPhonePreview');
    if (hint) {
      const norm = normalizePeruPhone(phoneInput.value);
      hint.textContent = norm ? `Formato normalizado: ${norm}` : 'Se normalizará automáticamente con prefijo Perú +51';
    }
  });
  phoneInput?.addEventListener('blur', () => {
    const norm = normalizePeruPhone(phoneInput.value);
    if (norm) phoneInput.value = norm;
  });

  // Cálculo en vivo de vencimiento de Trial
  const trialDaysInput = document.getElementById('newTrialDaysRemaining');
  trialDaysInput?.addEventListener('input', () => {
    const days = parseInt(trialDaysInput.value) || 30;
    const hint = document.getElementById('hintTrialExpires');
    if (hint) {
      const expDate = new Date();
      expDate.setDate(expDate.getDate() + days);
      hint.textContent = `Vencerá el ${expDate.toISOString().substring(0, 10)} (en ${days} días).`;
    }
  });

  const aiRepInput = document.getElementById('newAiReportedBalance');
  aiRepInput?.addEventListener('input', () => {
    aiRepInput.dataset.manual = 'true';
  });

  document.getElementById('btnOpenCreateClient')?.addEventListener('click', () => {
    document.getElementById('formCreateClient')?.reset();
    const aiRep = document.getElementById('newAiReportedBalance');
    if (aiRep) delete aiRep.dataset.manual;
    const notice = document.getElementById('noticeAiBonus');
    if (notice) notice.style.display = 'none';
    updateSituationFields();
    openModal('modalCreateClient');
  });

  document.getElementById('btnSubmitCreateClient')?.addEventListener('click', () => {
    handleCreateClient(false);
  });

  document.getElementById('btnSubmitAndEmit')?.addEventListener('click', () => {
    handleCreateClient(true);
  });

  // Modal Editar Cliente (Guardar)
  document.getElementById('btnSubmitEditClient')?.addEventListener('click', async () => {
    const id = document.getElementById('editClientId').value;
    const biz = document.getElementById('editBizName').value.trim();
    const owner = document.getElementById('editOwnerName').value.trim();
    const doc = document.getElementById('editDocId').value.trim();
    const phone = document.getElementById('editPhone').value.trim();
    const device = document.getElementById('editDeviceId').value.trim().toUpperCase();
    const ver = document.getElementById('editInstalledVersion').value.trim();
    const licType = document.getElementById('editLicenseType').value;
    const licStatus = document.getElementById('editLicenseStatus').value;
    const licExpires = document.getElementById('editLicenseExpires').value;
    const updatesUntil = document.getElementById('editUpdatesUntil').value;
    const aiExtra = parseInt(document.getElementById('editAiExtraCredits').value) || 0;
    const nonce = parseInt(document.getElementById('editNextNonce').value) || 1;
    const notes = document.getElementById('editNotes').value.trim();

    if (!biz || !owner || !phone || !device) {
      showToast('Por favor completa los campos requeridos.', 'warning');
      return;
    }

    try {
      const res = await fetch(`/api/clients/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          business_name: biz,
          owner_name: owner,
          document_id: doc,
          phone: phone,
          current_device_id: device,
          installed_version: ver || '9.24.0',
          license_type: licType,
          license_status: licStatus,
          license_expires: licExpires || null,
          updates_until: updatesUntil || null,
          ai_extra_credits: aiExtra,
          next_nonce: nonce,
          notes: notes,
        }),
      });

      if (!res.ok) throw new Error('Error al actualizar cliente');
      closeModal('modalEditClient');
      showToast('Cliente y directivas actualizados con éxito.', 'success');
      await loadClients();
      await loadDashboard();
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Modal Editar Cliente (Eliminar Cliente)
  document.getElementById('btnDeleteClient')?.addEventListener('click', () => {
    const id = document.getElementById('editClientId').value;
    const biz = document.getElementById('editBizName').value;

    showConfirmModal(
      'Eliminar Cliente Permanentemente',
      `¿Estás seguro de eliminar a "${biz}" (${id}) y todo su historial de pagos y licencias? Esta acción no se puede deshacer.`,
      async () => {
        try {
          const res = await fetch(`/api/clients/${id}`, { method: 'DELETE' });
          if (!res.ok) throw new Error('Error al eliminar cliente');
          closeModal('modalEditClient');
          showToast(`Cliente "${biz}" eliminado permanentemente.`, 'success');
          await loadClients();
          await loadDashboard();
        } catch (e) {
          showToast('Error: ' + e.message, 'error');
        }
      },
      true
    );
  });

  // Modal Migrar Dispositivo
  document.getElementById('btnSubmitMigrateDevice')?.addEventListener('click', handleMigrateDeviceSubmit);

  document.getElementById('migFeeMode')?.addEventListener('change', (e) => {
    const mode = e.target.value;
    const feeInput = document.getElementById('migFee');
    const customGroup = document.getElementById('migCustomFeeGroup');
    const paymentGroup = document.getElementById('migPaymentFieldsGroup');
    const reasonInput = document.getElementById('migReason');
    const defaultFee = (ownerConfig?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
      ? ownerConfig.catalog.HARDWARE_MIGRATION_FEE.price
      : (ownerConfig?.migration_fee || 40.0);

    if (mode === 'FREE') {
      if (feeInput) feeInput.value = '0.00';
      if (customGroup) customGroup.style.display = 'none';
      if (paymentGroup) paymentGroup.style.display = 'none';
      if (reasonInput && !reasonInput.value) {
        reasonInput.value = 'Garantía de equipo / Traslado gratuito por cortesía';
      }
    } else if (mode === 'CUSTOM') {
      if (customGroup) customGroup.style.display = 'block';
      if (paymentGroup) paymentGroup.style.display = 'block';
    } else {
      // STANDARD
      if (feeInput) feeInput.value = Number(defaultFee).toFixed(2);
      if (customGroup) customGroup.style.display = 'none';
      if (paymentGroup) paymentGroup.style.display = 'block';
      if (reasonInput && reasonInput.value === 'Garantía de equipo / Traslado gratuito por cortesía') {
        reasonInput.value = '';
      }
    }
  });

  document.getElementById('migScenario')?.addEventListener('change', (e) => {
    const scenario = e.target.value;
    const hint = document.getElementById('migScenarioHint');
    if (hint) {
      if (scenario === 'RESTORED_BACKUP') {
        hint.textContent = 'Recomendado si el cliente restauró su copia de Google Drive o .mlbg: reactiva el nuevo equipo preservando exactamente su vencimiento con cero duplicación de días.';
      } else {
        hint.textContent = 'Instalación limpia desde cero: el token transferirá exactamente los días restantes hasta la fecha de expiración.';
      }
    }
  });

  // Modal Crear Release
  document.getElementById('btnOpenCreateRelease')?.addEventListener('click', () => {
    openModal('modalCreateRelease');
  });

  document.getElementById('btnSubmitCreateRelease')?.addEventListener('click', async () => {
    const versionName = document.getElementById('relVersionName').value.trim();
    const versionCode = parseInt(document.getElementById('relVersionCode').value) || 24;
    const minRequired = document.getElementById('relMinRequiredVersion').value.trim() || '9.0.0';
    const schemaVersion = parseInt(document.getElementById('relDbSchema').value) || 35;
    const type = document.getElementById('relType').value;
    const sizeMb = parseFloat(document.getElementById('relSizeMb').value) || null;
    const url = document.getElementById('relDownloadUrl').value.trim();
    const sha = document.getElementById('relSha256').value.trim();
    const changelog = document.getElementById('relChangelog').value.trim();

    if (!versionName) {
      showToast('Por favor completa el nombre de la versión.', 'warning');
      return;
    }

    try {
      const res = await fetch('/api/releases', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          version_name: versionName,
          version_code: versionCode,
          min_required_version: minRequired,
          db_schema_version: schemaVersion,
          type: type,
          file_size_mb: sizeMb,
          apk_download_url: url,
          apk_sha256: sha,
          changelog: changelog,
        }),
      });

      if (!res.ok) throw new Error('Error al publicar versión');
      closeModal('modalCreateRelease');
      document.getElementById('formCreateRelease').reset();
      showToast(`Versión v${versionName} registrada y publicada.`, 'success');
      await loadReleases();
      await loadReleaseMatrix();
      await loadDashboard();
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Modal Editar Release / Changelog (Guardar)
  document.getElementById('btnSubmitEditRelease')?.addEventListener('click', async () => {
    const versionName = document.getElementById('editRelVersionName').value;
    const type = document.getElementById('editRelType').value;
    const url = document.getElementById('editRelDownloadUrl').value.trim();
    const changelog = document.getElementById('editRelChangelog').value.trim();

    try {
      const res = await fetch(`/api/releases/${encodeURIComponent(versionName)}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: type,
          apk_download_url: url,
          changelog: changelog,
        }),
      });

      if (!res.ok) throw new Error('Error al actualizar versión');
      closeModal('modalEditRelease');
      showToast(`Versión v${versionName} actualizada.`, 'success');
      await loadReleases();
      await loadReleaseMatrix();
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Modal Registrar Pago Manual (Abrir y Guardar)
  document.getElementById('btnOpenManualPayment')?.addEventListener('click', () => {
    if (!currentHistoryClientId) return;
    openAddPaymentModal(currentHistoryClientId);
  });

  // Cambio reactivo de preset de concepto en modal de pago
  document.getElementById('manualPayPlanPreset')?.addEventListener('change', (e) => {
    const val = e.target.value;
    const customConcept = document.getElementById('manualPayCustomConcept');
    const amountInput = document.getElementById('manualPayAmount');
    const planInput = document.getElementById('manualPayPlan');
    const paymentId = document.getElementById('manualPayId')?.value?.trim();

    if (val === 'CUSTOM') {
      if (customConcept) {
        customConcept.style.display = 'block';
        customConcept.focus();
      }
    } else {
      if (customConcept) {
        customConcept.style.display = 'none';
        customConcept.value = '';
      }
      if (planInput) planInput.value = val;
      const selectedOpt = e.target.selectedOptions?.[0];
      const price = selectedOpt?.dataset?.price;
      if (price && !paymentId && amountInput) {
        amountInput.value = parseFloat(price).toFixed(2);
      }
    }
  });

  document.getElementById('btnSubmitManualPayment')?.addEventListener('click', async () => {
    const clientId = document.getElementById('manualPayClientId').value;
    const paymentId = document.getElementById('manualPayId')?.value?.trim();
    const amount = parseFloat(document.getElementById('manualPayAmount').value) || 0;
    
    // Resolver concepto según preset o personalizado
    let plan = '';
    const presetSelect = document.getElementById('manualPayPlanPreset');
    const customConceptInput = document.getElementById('manualPayCustomConcept');
    if (presetSelect && presetSelect.value === 'CUSTOM') {
      plan = customConceptInput?.value?.trim() || '';
    } else if (presetSelect && presetSelect.value) {
      plan = presetSelect.value;
    } else {
      plan = document.getElementById('manualPayPlan')?.value?.trim() || '';
    }

    const method = document.getElementById('manualPayMethod').value;
    const ref = document.getElementById('manualPayRef').value.trim();
    const notes = document.getElementById('manualPayNotes').value.trim();
    const date = document.getElementById('manualPayDate')?.value || new Date().toISOString().substring(0, 10);
    const shouldGenerateReceipt = document.getElementById('manualPayGenerateReceipt')?.checked ?? false;

    if (!amount || !plan) {
      showToast('Por favor completa el monto y concepto.', 'warning');
      return;
    }

    try {
      let res;
      if (paymentId) {
        // Actualizar pago existente (PUT)
        res = await fetch(`/api/clients/${clientId}/payments/${paymentId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            amount: amount,
            plan: plan,
            method: method,
            reference: ref,
            notes: notes,
            date: date,
          }),
        });
      } else {
        // Registrar nuevo pago (POST)
        res = await fetch(`/api/clients/${clientId}/payments`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            amount: amount,
            plan: plan,
            method: method,
            reference: ref,
            notes: notes,
            date: date,
          }),
        });
      }

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || 'Error al procesar registro de pago');
      }

      const updatedClient = await res.json();
      closeModal('modalManualPayment');
      showToast(paymentId ? 'Pago actualizado con éxito.' : 'Pago manual registrado con éxito.', 'success');

      // Si se marcó emitir boleta de inmediato al registrar un nuevo pago
      if (shouldGenerateReceipt && !paymentId && updatedClient && Array.isArray(updatedClient.payment_history)) {
        const newPayment = updatedClient.payment_history[updatedClient.payment_history.length - 1];
        if (newPayment && newPayment.id) {
          openPaymentReceiptModal(clientId, newPayment.id);
        }
      }

      if (currentHistoryClientId === clientId) {
        await openClientHistoryModal(clientId);
      }
      if (currentDrawerClientId === clientId) {
        await openClient360Drawer(clientId, 'drawerTabFinances');
      }
      await loadClients();
      await loadDashboard();
      await loadFinances();
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });
}

function openEditClientModal(clientId) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  document.getElementById('editClientId').value = client.id;
  document.getElementById('editBizName').value = client.business_name || '';
  document.getElementById('editOwnerName').value = client.owner_name || '';
  document.getElementById('editDocId').value = client.document_id || '';
  document.getElementById('editPhone').value = client.phone || '';
  document.getElementById('editDeviceId').value = client.current_device_id || '';
  document.getElementById('editInstalledVersion').value = client.installed_version || '9.24.0';
  document.getElementById('editLicenseType').value = client.license_type || 'MENSUAL';
  document.getElementById('editLicenseStatus').value = client.license_status || 'ACTIVE';

  if (client.license_expires) {
    document.getElementById('editLicenseExpires').value = client.license_expires.substring(0, 10);
  } else {
    document.getElementById('editLicenseExpires').value = '';
  }

  if (client.updates_until) {
    document.getElementById('editUpdatesUntil').value = client.updates_until.substring(0, 10);
  } else {
    document.getElementById('editUpdatesUntil').value = '';
  }

  document.getElementById('editAiExtraCredits').value = client.ai_extra_credits || 0;
  document.getElementById('editNextNonce').value = client.next_nonce || 1;
  document.getElementById('editNotes').value = client.notes || '';

  openModal('modalEditClient');
}

// =================== HISTORIAL MULTI-PESTAÑA (PAGOS & HARDWARE) ===================
function switchHistoryTab(tabName) {
  activeHistoryTab = tabName;
  const btnPayments = document.getElementById('tabBtnHistoryPayments');
  const btnHardware = document.getElementById('tabBtnHistoryHardware');
  const viewPayments = document.getElementById('historyViewPayments');
  const viewHardware = document.getElementById('historyViewHardware');

  if (tabName === 'payments') {
    btnPayments?.classList.add('active');
    btnHardware?.classList.remove('active');
    if (viewPayments) viewPayments.style.display = 'flex';
    if (viewHardware) viewHardware.style.display = 'none';
  } else {
    btnHardware?.classList.add('active');
    btnPayments?.classList.remove('active');
    if (viewHardware) viewHardware.style.display = 'flex';
    if (viewPayments) viewPayments.style.display = 'none';
  }
}

async function openClientHistoryModal(clientId) {
  try {
    currentHistoryClientId = clientId;
    const res = await fetch(`/api/clients/${clientId}/history`);
    if (!res.ok) throw new Error('Error al cargar historial del cliente');
    const data = await res.json();
    const client = data.client;

    document.getElementById('historyModalTitle').textContent = `Historial Comercial — ${client.business_name}`;
    document.getElementById('historyClientSummary').innerHTML = `
      <strong>Titular:</strong> ${escapeHtml(client.owner_name)} (${escapeHtml(client.document_id || 'Sin doc')})
      • <strong>Dispositivo Actual:</strong> <span class="device-id-badge">${escapeHtml(client.current_device_id)}</span>
      • <strong>Plan:</strong> ${escapeHtml(client.license_type)}
      • <strong>Total Pagado Histórico:</strong> <strong style="color:var(--success);">S/ ${(data.total_paid || 0).toFixed(2)}</strong>
    `;

    // 1. Pagos registrados
    const payBody = document.getElementById('historyPaymentsBody');
    payBody.innerHTML = '';
    if (!data.payments || data.payments.length === 0) {
      payBody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1rem;">Sin pagos registrados</td></tr>';
    } else {
      data.payments.forEach(p => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${p.date ? p.date.substring(0, 10) : '-'}</td>
          <td><strong>S/ ${(p.amount || 0).toFixed(2)}</strong></td>
          <td>${escapeHtml(p.plan || '-')}</td>
          <td>${escapeHtml(p.method || '-')}</td>
          <td>${escapeHtml(p.reference || '-')}</td>
          <td>
            <button class="btn btn-outline btn-sm" style="color:var(--danger); border-color:var(--danger); font-size:0.75rem;" onclick="voidPayment('${client.id}', '${p.id}')" title="Anular transacción">
              🗑️ Anular
            </button>
          </td>
        `;
        payBody.appendChild(tr);
      });
    }

    // 2. Códigos Ed25519 Emitidos con Re-descarga de Credencial PNG
    const codesBody = document.getElementById('historyCodesBody');
    codesBody.innerHTML = '';
    if (!data.codes || data.codes.length === 0) {
      codesBody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1rem;">Sin códigos emitidos</td></tr>';
    } else {
      data.codes.forEach((c, idx) => {
        const tr = document.createElement('tr');
        const shortToken = c.token ? `${c.token.substring(0, 18)}...` : '-';
        tr.innerHTML = `
          <td>${c.emitted_at ? c.emitted_at.substring(0, 10) : '-'}</td>
          <td>${escapeHtml(c.plan || '-')}</td>
          <td>+${c.days_added} días</td>
          <td><span class="device-id-badge">${escapeHtml(c.device_id || '-')}</span></td>
          <td><code style="font-family:var(--font-mono); font-size:0.75rem;">${shortToken}</code></td>
          <td>
            <div style="display:flex; gap:0.3rem;">
              <button class="btn btn-outline btn-sm" onclick="copyTokenToClipboard('${escapeHtml(c.token)}')" title="Copiar Token">
                📋
              </button>
              <button class="btn btn-primary btn-sm" onclick="downloadHistoricalCredential(${idx})" title="Descargar Credencial PNG Oficial">
                🪪 Tarjeta PNG
              </button>
            </div>
          </td>
        `;
        codesBody.appendChild(tr);
      });
    }

    // 3. Pestaña de Hardware y Migraciones
    const hwBox = document.getElementById('historyCurrentDeviceBox');
    hwBox.innerHTML = `
      <div style="font-size:0.85rem; color:var(--text-secondary); margin-bottom:0.25rem;">Dispositivo Actualmente Vinculado:</div>
      <div style="font-size:1.1rem; font-weight:700; color:var(--success); font-family:var(--font-mono);">
        📱 ${escapeHtml(client.current_device_id)}
      </div>
      <div style="font-size:0.78rem; color:var(--text-muted); margin-top:0.25rem;">
        Versión de la app: v${escapeHtml(client.installed_version || '9.24.0')} • Licencia válida exclusivamente para esta placa.
      </div>
    `;

    const hwBody = document.getElementById('historyHardwareBody');
    hwBody.innerHTML = '';
    if (!data.hardware_history || data.hardware_history.length === 0) {
      hwBody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1rem;">El cliente no ha realizado cambios de teléfono (opera en su dispositivo original).</td></tr>';
    } else {
      data.hardware_history.forEach(h => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${h.migrated_at ? h.migrated_at.substring(0, 10) : '-'}</td>
          <td><span class="device-id-badge" style="opacity:0.7;">${escapeHtml(h.old_device_id)}</span></td>
          <td><span class="device-id-badge" style="color:var(--success);">${escapeHtml(h.new_device_id)}</span></td>
          <td>S/ ${(h.fee_charged || h.fee_amount || 0).toFixed(2)}</td>
          <td>${escapeHtml(h.payment_method || '-')}</td>
          <td>${escapeHtml(h.reason || 'Sin motivo')}</td>
        `;
        hwBody.appendChild(tr);
      });
    }

    // Guardar referencia a códigos para la re-descarga histórica
    window._currentHistoryData = data;

    // Iniciar en la pestaña de pagos
    switchHistoryTab('payments');
    openModal('modalClientHistory');
  } catch (e) {
    showToast('Error al abrir historial: ' + e.message, 'error');
  }
}

function downloadHistoricalCredential(codeIndex) {
  const data = window._currentHistoryData;
  if (!data || !data.codes || !data.codes[codeIndex]) return;
  const c = data.codes[codeIndex];
  const client = data.client;

  // Renderizar en el canvas oculto
  renderCredentialCanvas({
    token: c.token,
    plan: c.plan,
    device_id: c.device_id,
    days_added: c.days_added,
    expires_result: c.expires_result,
    client: client,
  }, client, 'historyCredentialCanvas');

  const canvas = document.getElementById('historyCredentialCanvas');
  if (!canvas) return;

  const nameClean = (client.business_name || 'Licencia').replace(/[^a-zA-Z0-9]/g, '_');
  const link = document.createElement('a');
  link.download = `Credencial_MochilaLista_${nameClean}_${c.plan}_${Date.now()}.png`;
  link.href = canvas.toDataURL('image/png');
  link.click();
  showToast('Credencial histórica descargada en PNG @2x.', 'success');
}

function copyTokenToClipboard(token) {
  navigator.clipboard.writeText(token).then(() => {
    showToast('¡Token copiado al portapapeles!', 'success');
  }).catch(() => {
    showToast('Token copiado.', 'info');
  });
}

function voidPayment(clientId, paymentId) {
  showConfirmModal(
    'Anular Pago Registrado',
    '¿Estás seguro de anular y eliminar este registro de pago? Se descontará del total histórico cobrado del cliente.',
    async () => {
      try {
        const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}`, {
          method: 'DELETE',
        });
        if (!res.ok) throw new Error('Error al anular pago');
        showToast('Pago anulado con éxito.', 'success');
        await openClientHistoryModal(clientId);
        await loadClients();
        await loadDashboard();
        await loadFinances();
      } catch (e) {
        showToast('Error: ' + e.message, 'error');
      }
    },
    true
  );
}

// =================== FLUJOS DE 1 SOLO PASO (FASE 4A / REINGENIERÍA FASE 3) ===================
async function handleCreateClient(andEmit = false) {
  const situation = document.getElementById('newClientSituation')?.value || 'TRIAL';
  const biz = document.getElementById('newBizName').value.trim();
  const owner = document.getElementById('newOwnerName').value.trim();
  const doc = document.getElementById('newDocId').value.trim();
  const rawPhone = document.getElementById('newPhone').value.trim();
  const phone = normalizePeruPhone(rawPhone);
  let device = document.getElementById('newDeviceId').value.trim().toUpperCase();
  const deviceModel = document.getElementById('newDeviceModel')?.value.trim() || '';
  const installedVer = document.getElementById('newInstalledVersion').value.trim() || '9.35.0';
  const aiReported = parseInt(document.getElementById('newAiReportedBalance').value) || 0;
  const aiBonus = parseInt(document.getElementById('newAiPendingBonus').value) || 0;
  const trialDays = parseInt(document.getElementById('newTrialDaysRemaining')?.value) || 30;
  const expectedSubDate = document.getElementById('newExpectedSubscriptionDate')?.value || null;
  const notes = document.getElementById('newNotes').value.trim();

  let plan = 'TRIAL';
  if (situation === 'PROSPECTO') {
    plan = 'PROSPECTO';
    if (!device) device = 'PENDIENTE';
  } else if (situation === 'TRIAL') {
    plan = 'TRIAL';
  } else { // COMMERCIAL
    plan = document.getElementById('newPlan').value;
  }

  // Validaciones según situación
  if (!biz || !owner || !phone) {
    showToast('Por favor completa los campos obligatorios: Negocio, Titular y Teléfono WhatsApp.', 'warning');
    return;
  }

  if (situation !== 'PROSPECTO' && (!device || device === 'PENDIENTE')) {
    showToast('Para clientes con app instalada o licencia comercial, el Hardware ID es obligatorio.', 'warning');
    return;
  }

  try {
    const res = await fetch('/api/clients', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        business_name: biz,
        owner_name: owner,
        document_id: doc,
        phone: phone,
        current_device_id: device,
        device_model: deviceModel,
        license_type: plan,
        license_status: situation === 'PROSPECTO' ? 'PROSPECTO' : (plan.includes('PERPETU') ? 'PERPETUA' : 'ACTIVA'),
        installed_version: installedVer,
        ai_reported_balance: aiReported,
        ai_pending_bonus: aiBonus,
        ai_extra_credits: 0,
        trial_days_remaining: situation === 'TRIAL' ? trialDays : null,
        expected_subscription_date: situation === 'PROSPECTO' ? expectedSubDate : null,
        notes: notes,
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Error al registrar cliente');
    }

    const createdClient = await res.json();
    closeModal('modalCreateClient');
    document.getElementById('formCreateClient').reset();
    const notice = document.getElementById('noticeAiBonus');
    if (notice) notice.style.display = 'none';

    await loadClients();
    await loadDashboard();

    if (andEmit && createdClient && createdClient.id) {
      showToast(`¡Cliente "${biz}" guardado! Abriendo Generador de Licencias...`, 'success');
      const hasBonus = (createdClient.ai_pending_bonus || 0) > 0;
      selectClientForLicense(createdClient.id, { preferBonus: hasBonus });
      const curView = document.getElementById('currentViewName');
      if (curView) curView.textContent = 'Generar Licencia';
    } else {
      showToast(`Cliente "${biz}" registrado con éxito.`, 'success');
    }
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

async function handleMigrateDeviceSubmit() {
  const clientId = document.getElementById('migClientId').value;
  const newDeviceId = document.getElementById('migNewDeviceId').value.trim().toUpperCase();
  const newDeviceModel = document.getElementById('migNewDeviceModel')?.value.trim() || '';
  const scenario = document.getElementById('migScenario')?.value || 'RESTORED_BACKUP';
  const feeMode = document.getElementById('migFeeMode')?.value || 'STANDARD';
  const fee = feeMode === 'FREE' ? 0.0 : (parseFloat(document.getElementById('migFee').value) || 0);
  const method = feeMode === 'FREE' ? 'Gratuito / Cortesía' : document.getElementById('migPaymentMethod').value;
  const ref = document.getElementById('migPaymentRef')?.value.trim() || '';
  const reason = document.getElementById('migReason').value.trim();
  const emitImmediately = document.getElementById('migEmitImmediately')?.checked ?? true;
  const shouldGenReceipt = document.getElementById('migGenerateReceipt')?.checked ?? false;

  if (!newDeviceId) {
    showToast('Por favor ingresa el nuevo Hardware ID (ML-YYYY).', 'warning');
    return;
  }

  try {
    const res = await fetch(`/api/clients/${clientId}/migrate-device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        new_device_id: newDeviceId,
        device_model: newDeviceModel,
        fee_mode: feeMode,
        fee_amount: fee,
        payment_method: method,
        payment_reference: ref,
        reason: reason,
        emit_immediately: emitImmediately,
        migration_scenario: scenario,
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Error al migrar dispositivo');
    }

    const data = await res.json();
    await loadClients();
    await loadDashboard();

    const client = globalClients.find(c => c.id === clientId) || data;

    if (emitImmediately && data.emitted_migration_token) {
      const token = data.emitted_migration_token;
      const form = document.getElementById('formMigrateDevice');
      if (form) form.style.display = 'none';

      const successBox = document.getElementById('migSuccessInline');
      if (successBox) successBox.style.display = 'block';

      const devEl = document.getElementById('migSuccessNewDev');
      if (devEl) devEl.textContent = newDeviceId;

      const codeEl = document.getElementById('migSuccessCode');
      if (codeEl) codeEl.textContent = token;

      const qrBox = document.getElementById('migSuccessQrContainer');
      if (qrBox) {
        renderSafeQrCode(qrBox, token, 170);
      }

      document.getElementById('btnMigCopyCode').onclick = () => {
        navigator.clipboard.writeText(token).then(() => {
          showToast('¡Código de migración copiado al portapapeles!', 'success');
        });
      };

      const cleanPhone = (client.phone || '').replace(/[^0-9]/g, '');
      const msgText = renderConfigTemplate('device_migration', {
        titular: client.owner_name,
        negocio: client.business_name,
        device_id: newDeviceId,
        vencimiento: (client.license_expires || '').substring(0, 10),
        creditos_ia: client.ai_extra_credits || 0,
        codigo: token,
      });
      document.getElementById('btnMigSendWa').href = `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(msgText)}`;

      // Botón para generar boleta si se registró cobro de tarifa
      const receiptBtn = document.getElementById('btnMigViewReceipt');
      if (data.payment_id && receiptBtn) {
        receiptBtn.style.display = 'inline-flex';
        receiptBtn.onclick = () => {
          openPaymentReceiptModal(clientId, data.payment_id);
        };
      } else if (receiptBtn) {
        receiptBtn.style.display = 'none';
      }

      const footer = document.getElementById('migModalFooter');
      if (footer) {
        footer.innerHTML = `
          <button type="button" class="btn btn-primary" onclick="closeModal('modalMigrateDevice')">Aceptar y Cerrar</button>
        `;
      }
      showToast(`¡Dispositivo migrado y token emitido para ${newDeviceId}!`, 'success');
    } else {
      closeModal('modalMigrateDevice');
      showToast(`¡Dispositivo migrado a ${newDeviceId}! Emite ahora su licencia en el Generador.`, 'success');
      selectClientForLicense(clientId);
      if (shouldGenReceipt && data.payment_id) {
        openPaymentReceiptModal(clientId, data.payment_id);
      }
    }
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

function openMigrateModal(clientId) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  document.getElementById('migClientId').value = client.id;
  document.getElementById('migClientName').value = `${client.business_name} (${client.owner_name})`;
  document.getElementById('migOldDeviceId').value = client.current_device_id || '';
  document.getElementById('migNewDeviceId').value = '';
  document.getElementById('migNewDeviceModel').value = '';

  // Poblar Tarjeta Resumen de Preservación
  const planEl = document.getElementById('migPreservePlan');
  if (planEl) planEl.textContent = client.license_type || 'MENSUAL';

  const expEl = document.getElementById('migPreserveExpires');
  if (expEl) {
    if (client.license_expires) {
      const expDate = new Date(client.license_expires);
      const now = new Date();
      const days = Math.max(0, Math.ceil((expDate - now) / 86400000));
      expEl.textContent = `${client.license_expires.substring(0, 10)} • ${days} días restantes`;
    } else {
      expEl.textContent = 'Sin vencimiento';
    }
  }

  const aiEl = document.getElementById('migPreserveAi');
  if (aiEl) {
    const totalAi = (client.ai_reported_balance || 0) + (client.ai_extra_bonus || 0);
    aiEl.textContent = `+${totalAi} escaneos`;
  }

  const updatesWrapper = document.getElementById('migPreserveUpdatesWrapper');
  const updatesEl = document.getElementById('migPreserveUpdates');
  if (client.updates_until && updatesWrapper && updatesEl) {
    updatesWrapper.style.display = 'flex';
    updatesEl.textContent = client.updates_until.substring(0, 10);
  } else if (updatesWrapper) {
    updatesWrapper.style.display = 'none';
  }

  // Escenario por defecto
  const scenarioSel = document.getElementById('migScenario');
  if (scenarioSel) scenarioSel.value = 'RESTORED_BACKUP';
  const hint = document.getElementById('migScenarioHint');
  if (hint) {
    hint.textContent = 'Recomendado si el cliente restauró su copia de Google Drive o .mlbg: reactiva el nuevo equipo preservando exactamente su vencimiento con cero duplicación de días.';
  }

  // Modalidad de cobro
  const feeModeSel = document.getElementById('migFeeMode');
  if (feeModeSel) feeModeSel.value = 'STANDARD';
  const customFeeGroup = document.getElementById('migCustomFeeGroup');
  if (customFeeGroup) customFeeGroup.style.display = 'none';
  const payGroup = document.getElementById('migPaymentFieldsGroup');
  if (payGroup) payGroup.style.display = 'block';

  const migDefault = (ownerConfig?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
    ? ownerConfig.catalog.HARDWARE_MIGRATION_FEE.price
    : (ownerConfig?.migration_fee || 40.0);
  document.getElementById('migFee').value = Number(migDefault).toFixed(2);
  document.getElementById('migPaymentMethod').value = 'Yape';
  document.getElementById('migPaymentRef').value = '';
  document.getElementById('migReason').value = '';

  const genReceiptChk = document.getElementById('migGenerateReceipt');
  if (genReceiptChk) genReceiptChk.checked = true;

  const emitCb = document.getElementById('migEmitImmediately');
  if (emitCb) emitCb.checked = true;

  const form = document.getElementById('formMigrateDevice');
  if (form) form.style.display = 'flex';

  const successBox = document.getElementById('migSuccessInline');
  if (successBox) successBox.style.display = 'none';

  const qrBox = document.getElementById('migSuccessQrContainer');
  if (qrBox) qrBox.innerHTML = '';

  const receiptBtn = document.getElementById('btnMigViewReceipt');
  if (receiptBtn) receiptBtn.style.display = 'none';

  const footer = document.getElementById('migModalFooter');
  if (footer) {
    footer.innerHTML = `
      <button type="button" class="btn btn-outline" onclick="closeModal('modalMigrateDevice')">Cancelar</button>
      <button type="button" class="btn btn-primary" id="btnSubmitMigrateDevice">Confirmar Migración</button>
    `;
    document.getElementById('btnSubmitMigrateDevice')?.addEventListener('click', handleMigrateDeviceSubmit);
  }

  openModal('modalMigrateDevice');
}

// =================== UTILIDADES GENÉRICAS ===================
function openModal(id) {
  const drawer = document.getElementById('drawerClient360');
  const isDrawerOpen = drawer && drawer.classList.contains('open');
  if (isDrawerOpen && currentDrawerClientId) {
    drawerReturnState = {
      clientId: currentDrawerClientId,
      tabId: currentDrawerTab || 'drawerTabOverview',
    };
    drawer.classList.remove('open');
    document.getElementById('drawerClient360Backdrop')?.classList.remove('open');
  }
  document.getElementById(id)?.classList.add('open');
}

function openModalFromDrawer(modalId) {
  openModal(modalId);
}

function closeModal(id) {
  document.getElementById(id)?.classList.remove('open');
  const remainingModals = document.querySelectorAll('.modal-overlay.open');
  if (remainingModals.length === 0 && drawerReturnState) {
    const returnInfo = drawerReturnState;
    drawerReturnState = null;
    openClient360Drawer(returnInfo.clientId, returnInfo.tabId);
  }
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL (FASE 4B) ===================

async function loadConfig() {
  try {
    const res = await fetch('/api/config');
    if (!res.ok) throw new Error('Error al cargar configuración del propietario');
    ownerConfig = await res.json();
    populateSettingsForm(ownerConfig);
    applyConfigToUi(ownerConfig);
    renderTemplatePreview();
  } catch (err) {
    console.error('Error al cargar configuración:', err);
  }
}

function initSettingsEvents() {
  // Sub-tabs switching
  const tabs = document.querySelectorAll('.settings-tab-btn');
  tabs.forEach(btn => {
    btn.addEventListener('click', () => {
      tabs.forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.settings-pane').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      const targetPane = document.getElementById(btn.dataset.stab);
      if (targetPane) targetPane.classList.add('active');
    });
  });

  // Selector de plantilla
  const tplSelect = document.getElementById('cfgTemplateSelect');
  tplSelect?.addEventListener('change', () => {
    const tplKey = tplSelect.value;
    if (ownerConfig && ownerConfig.templates && ownerConfig.templates[tplKey]) {
      document.getElementById('cfgTemplateContent').value = ownerConfig.templates[tplKey];
      renderTemplatePreview();
    }
  });

  // Inserción de variable en textarea
  document.querySelectorAll('.var-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      const v = chip.dataset.var;
      const textarea = document.getElementById('cfgTemplateContent');
      if (!textarea || !v) return;
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      const text = textarea.value;
      textarea.value = text.substring(0, start) + v + text.substring(end);
      textarea.selectionStart = textarea.selectionEnd = start + v.length;
      textarea.focus();
      triggerTemplatePreviewDebounced();
    });
  });

  // Input en textarea con debounce para preview en vivo
  document.getElementById('cfgTemplateContent')?.addEventListener('input', () => {
    triggerTemplatePreviewDebounced();
  });

  // Cambio reactivo de tema y densidad desde preferencias
  document.getElementById('cfgDefaultTheme')?.addEventListener('change', (e) => {
    applyTheme(e.target.value);
  });

  document.getElementById('cfgTableDensity')?.addEventListener('change', (e) => {
    applyTableDensity(e.target.value);
  });

  // Guardar Configuración
  document.getElementById('btnSaveSettings')?.addEventListener('click', saveOwnerConfig);

  // Restaurar Valores de Fábrica (ambos botones)
  const triggerReset = () => {
    showConfirmModal(
      'Restaurar Valores de Fábrica',
      '¿Estás seguro de restablecer todas las tarifas comerciales, plantillas de WhatsApp, datos bancarios y preferencias a los valores de fábrica oficiales? Se creará automáticamente un snapshot de respaldo antes de aplicar la restauración.',
      async () => {
        try {
          const res = await fetch('/api/config/reset', { method: 'POST' });
          if (!res.ok) throw new Error('Error al restablecer configuración');
          const data = await res.json();
          ownerConfig = data.config;
          populateSettingsForm(ownerConfig);
          applyConfigToUi(ownerConfig);
          renderTemplatePreview();
          showToast('Configuración restablecida a los valores oficiales de fábrica.', 'success');
        } catch (e) {
          showToast('Error: ' + e.message, 'error');
        }
      },
      true
    );
  };

  document.getElementById('btnResetSettings')?.addEventListener('click', triggerReset);
  document.getElementById('btnTriggerResetSettings')?.addEventListener('click', triggerReset);
}

function triggerTemplatePreviewDebounced() {
  clearTimeout(templatePreviewTimer);
  templatePreviewTimer = setTimeout(() => {
    renderTemplatePreview();
  }, 250);
}

async function renderTemplatePreview() {
  const content = document.getElementById('cfgTemplateContent')?.value;
  const key = document.getElementById('cfgTemplateSelect')?.value;
  const bubble = document.getElementById('waBubbleContent');
  if (!bubble) return;

  try {
    const res = await fetch('/api/config/preview-template', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        template: content,
        template_key: key,
        context: {
          titular: 'Juan Pérez',
          negocio: 'Librería Central',
          plan: 'MENSUAL',
          dias: '30',
          vencimiento: '2026-12-31',
          creditos_ia: '100',
          codigo: 'ML9-DEMO-ACTIVATION-TOKEN-XXXXX',
          version: '9.35.0',
          version_actual: '9.32.0',
          device_id: 'ML-9K4B',
          changelog: 'Mejoras en el escáner IA y velocidad.',
          link_descarga: 'http://localhost:8080/api/releases/download/9.35.0',
          precio_pase: '150.00',
        },
      }),
    });

    if (res.ok) {
      const data = await res.json();
      bubble.innerHTML = formatWhatsAppPreview(data.rendered || '');
    } else {
      bubble.textContent = content || '';
    }
  } catch (_) {
    bubble.textContent = content || '';
  }
}

function formatWhatsAppPreview(rawText) {
  if (!rawText) return '';
  let escaped = escapeHtml(rawText);
  // Reemplazar *negrita* con <strong>negrita</strong>
  escaped = escaped.replace(/\*([^*\n]+)\*/g, '<strong>$1</strong>');
  // Reemplazar _cursiva_ con <em>cursiva</em>
  escaped = escaped.replace(/_([^_\n]+)_/g, '<em>$1</em>');
  // Reemplazar ~tachado~ con <del>tachado</del>
  escaped = escaped.replace(/~([^~\n]+)~/g, '<del>$1</del>');
  // Saltos de línea
  return escaped.replace(/\n/g, '<br>');
}

function populateSettingsForm(cfg) {
  if (!cfg) return;

  // 1. Catálogo
  const tbody = document.getElementById('catalogConfigTableBody');
  if (tbody && cfg.catalog) {
    tbody.innerHTML = '';
    const catalog = cfg.catalog;
    for (const [slug, item] of Object.entries(catalog)) {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><strong style="font-family:var(--font-mono);">${slug}</strong></td>
        <td><input type="text" class="cfg-plan-label" data-slug="${slug}" value="${escapeHtml(item.label || slug)}" style="width:100%; min-width:140px; font-size:0.85rem;"></td>
        <td><input type="number" class="cfg-plan-price" data-slug="${slug}" value="${(item.price || 0).toFixed(2)}" step="0.5" min="0" style="width:100%; font-weight:700; text-align:right;"></td>
        <td><input type="number" class="cfg-plan-days" data-slug="${slug}" value="${item.days || 0}" min="0" style="width:100%; text-align:right;"></td>
        <td><input type="number" class="cfg-plan-ai" data-slug="${slug}" value="${item.ai_credits || 0}" min="0" style="width:100%; text-align:right; color:var(--primary); font-weight:700;"></td>
        <td><input type="number" class="cfg-plan-updates" data-slug="${slug}" value="${item.updates_window_months || 0}" min="0" style="width:100%; text-align:right;"></td>
        <td><input type="text" class="cfg-plan-desc" data-slug="${slug}" value="${escapeHtml(item.description || '')}" style="width:100%; min-width:180px; font-size:0.82rem;"></td>
      `;
      tbody.appendChild(tr);
    }
  }

  // Tarifa de migración
  const migFeeInput = document.getElementById('cfgMigrationFee');
  if (migFeeInput) {
    const migPrice = (cfg?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
      ? cfg.catalog.HARDWARE_MIGRATION_FEE.price
      : (cfg?.migration_fee || 40.0);
    migFeeInput.value = Number(migPrice).toFixed(2);
  }

  // 2. Plantillas
  const tplSelect = document.getElementById('cfgTemplateSelect');
  const tplTextarea = document.getElementById('cfgTemplateContent');
  if (tplSelect && tplTextarea && cfg.templates) {
    const selKey = tplSelect.value || 'license_issued';
    tplTextarea.value = cfg.templates[selKey] || '';
  }

  // 3. Legal & Pagos
  if (cfg.legal_identity) {
    const li = cfg.legal_identity;
    setInputValue('cfgLegalOwner', li.author_full_name);
    setInputValue('cfgBrandName', li.commercial_name || li.brand_name);
    setInputValue('cfgSupportPhone', li.support_phone);
  }

  if (cfg.payment_methods) {
    const pm = cfg.payment_methods;
    setInputValue('cfgYapePhone', pm.yape_plin_phone);
    setInputValue('cfgYapeHolder', pm.yape_plin_holder);
    setInputValue('cfgBcpHolder', pm.bcp_account_holder);
    setInputValue('cfgBcpAccount', pm.bcp_account_number);
    setInputValue('cfgBcpCci', pm.bcp_cci);
    setInputValue('cfgBbvaHolder', pm.bbva_account_holder);
    setInputValue('cfgBbvaAccount', pm.bbva_account_number);
    setInputValue('cfgBbvaCci', pm.bbva_cci);
  }

  // 4. Preferencias y Sistema
  const sys = cfg.system || cfg.preferences || {};
  setInputValue('cfgDefaultEnv', sys.default_mode || sys.default_environment || 'sandbox');
  setInputValue('cfgDefaultTheme', sys.theme || sys.default_theme || 'dark');
  setInputValue('cfgTableDensity', sys.table_density || 'comfortable');
}

function setInputValue(id, val) {
  const el = document.getElementById(id);
  if (el) el.value = val !== undefined && val !== null ? val : '';
}

function applyConfigToUi(cfg) {
  if (!cfg) return;

  // Actualizar sello de autor en el header
  if (cfg.legal_identity && cfg.legal_identity.author_full_name) {
    const seal = document.querySelector('.author-name');
    if (seal) seal.textContent = cfg.legal_identity.author_full_name;
  }

  // Aplicar densidad de tablas
  const density = cfg.system?.table_density || cfg.preferences?.table_density || 'comfortable';
  applyTableDensity(density);

  // Actualizar opciones en el Generador de Licencias
  if (cfg.catalog) {
    const planSelect = document.getElementById('licPlanSelect');
    if (planSelect) {
      for (const opt of planSelect.options) {
        const item = cfg.catalog[opt.value];
        if (item) {
          opt.setAttribute('data-price', (item.price || 0).toFixed(2));
          opt.setAttribute('data-days', item.days || 0);
          opt.setAttribute('data-scans', item.ai_credits || 0);
          opt.textContent = `${item.label || opt.value} (S/ ${(item.price || 0).toFixed(2)})`;
        }
      }
      updatePlanImpactAndProjection();
    }
  }

  // Actualizar tarifa de migración por defecto en modal
  const migFee = document.getElementById('migFee');
  if (migFee) {
    const p = (cfg?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
      ? cfg.catalog.HARDWARE_MIGRATION_FEE.price
      : (cfg?.migration_fee || 40.0);
    migFee.value = Number(p).toFixed(2);
  }

  // Si hay una credencial generada visible, re-renderizar el canvas con la nueva identidad legal
  const licCode = document.getElementById('licCode')?.value;
  if (licCode && typeof renderCredentialCanvas === 'function') {
    renderCredentialCanvas();
  }
}

function applyTableDensity(density) {
  const isCompact = density === 'compact';
  document.querySelectorAll('.data-table').forEach(tbl => {
    if (isCompact) {
      tbl.classList.add('table-compact');
    } else {
      tbl.classList.remove('table-compact');
    }
  });
}

async function saveOwnerConfig() {
  if (!ownerConfig) return;

  try {
    // 1. Recoger valores del catálogo
    const catalog = { ...ownerConfig.catalog };
    document.querySelectorAll('.cfg-plan-price').forEach(inp => {
      const slug = inp.dataset.slug;
      if (catalog[slug]) {
        catalog[slug] = {
          ...catalog[slug],
          price: Math.max(0, parseFloat(inp.value) || 0),
          days: Math.max(0, parseInt(document.querySelector(`.cfg-plan-days[data-slug="${slug}"]`)?.value) || 0),
          ai_credits: Math.max(0, parseInt(document.querySelector(`.cfg-plan-ai[data-slug="${slug}"]`)?.value) || 0),
          updates_window_months: Math.max(0, parseInt(document.querySelector(`.cfg-plan-updates[data-slug="${slug}"]`)?.value) || 0),
          label: document.querySelector(`.cfg-plan-label[data-slug="${slug}"]`)?.value?.trim() || catalog[slug].label,
          description: document.querySelector(`.cfg-plan-desc[data-slug="${slug}"]`)?.value?.trim() || catalog[slug].description,
        };
      }
    });

    const migFeeVal = Math.max(0, parseFloat(document.getElementById('cfgMigrationFee')?.value) || 40.0);
    catalog['HARDWARE_MIGRATION_FEE'] = {
      price: migFeeVal,
      label: 'Tarifa Técnica de Migración',
    };

    // 2. Plantillas
    const templates = { ...ownerConfig.templates };
    const curKey = document.getElementById('cfgTemplateSelect')?.value;
    const curContent = document.getElementById('cfgTemplateContent')?.value;
    if (curKey && curContent) {
      templates[curKey] = curContent;
    }

    // 3. Legal
    const legalIdentity = {
      author_full_name: document.getElementById('cfgLegalOwner')?.value?.trim() || 'Julio Angello Vasquez Navarro',
      brand_name: document.getElementById('cfgBrandName')?.value?.trim() || 'MochilaLista',
      commercial_name: document.getElementById('cfgBrandName')?.value?.trim() || 'MochilaLista',
      support_phone: document.getElementById('cfgSupportPhone')?.value?.trim() || '+51 922 836 879',
      support_whatsapp_url: ownerConfig?.legal_identity?.support_whatsapp_url || 'https://wa.me/51922836879',
      official_website: ownerConfig?.legal_identity?.official_website || 'https://mochilalista.com',
      legal_framework: ownerConfig?.legal_identity?.legal_framework || 'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI Perú',
      personal_data_law: ownerConfig?.legal_identity?.personal_data_law || 'Ley N° 29733 (Ley de Protección de Datos Personales)',
    };

    // 4. Medios de pago
    const paymentMethods = {
      yape_plin_phone: document.getElementById('cfgYapePhone')?.value?.trim() || '922836879',
      yape_plin_holder: document.getElementById('cfgYapeHolder')?.value?.trim() || 'Julio Angello Vasquez Navarro',
      bcp_account_holder: document.getElementById('cfgBcpHolder')?.value?.trim() || '',
      bcp_account_number: document.getElementById('cfgBcpAccount')?.value?.trim() || '',
      bcp_cci: document.getElementById('cfgBcpCci')?.value?.trim() || '',
      bbva_account_holder: document.getElementById('cfgBbvaHolder')?.value?.trim() || '',
      bbva_account_number: document.getElementById('cfgBbvaAccount')?.value?.trim() || '',
      bbva_cci: document.getElementById('cfgBbvaCci')?.value?.trim() || '',
    };

    // 5. Preferencias y Sistema
    const defaultEnv = document.getElementById('cfgDefaultEnv')?.value || 'sandbox';
    const defaultTheme = document.getElementById('cfgDefaultTheme')?.value || 'dark';
    const tableDensity = document.getElementById('cfgTableDensity')?.value || 'comfortable';

    const system = {
      default_mode: defaultEnv,
      theme: defaultTheme,
      table_density: tableDensity,
      version: ownerConfig?.system?.version || '1.0.0',
    };

    const preferences = {
      default_environment: defaultEnv,
      default_theme: defaultTheme,
      table_density: tableDensity,
    };

    const newConfig = {
      ...ownerConfig,
      catalog,
      migration_fee: migFeeVal,
      templates,
      legal_identity: legalIdentity,
      payment_methods: paymentMethods,
      system,
      preferences,
    };

    const res = await fetch('/api/config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newConfig),
    });

    if (!res.ok) throw new Error('Error al guardar la configuración');

    ownerConfig = await res.json();
    populateSettingsForm(ownerConfig);
    applyConfigToUi(ownerConfig);
    showToast('¡Configuración guardada exitosamente! Snapshot automático creado en backups/.', 'success');
  } catch (err) {
    showToast('Error al guardar: ' + err.message, 'error');
  }
}

function renderConfigTemplate(templateKey, context = {}) {
  if (!ownerConfig || !ownerConfig.templates || !ownerConfig.templates[templateKey]) {
    return context.codigo ? `Código: ${context.codigo}` : 'MochilaLista';
  }

  let template = ownerConfig.templates[templateKey];
  const pm = ownerConfig.payment_methods || {};
  const li = ownerConfig.legal_identity || {};

  // Bloques bancarios con supresión inteligente
  const bcpAccount = (pm.bcp_account_number || '').trim();
  const bcpHolder = (pm.bcp_account_holder || '').trim();
  const bcpCci = (pm.bcp_cci || '').trim();
  let bcpBlock = '';
  if (bcpAccount) {
    const cciPart = bcpCci ? ` (CCI: ${bcpCci})` : '';
    const holderPart = bcpHolder ? ` - ${bcpHolder}` : '';
    bcpBlock = `\n🏦 BCP: ${bcpAccount}${cciPart}${holderPart}`;
  }

  const bbvaAccount = (pm.bbva_account_number || '').trim();
  const bbvaHolder = (pm.bbva_account_holder || '').trim();
  const bbvaCci = (pm.bbva_cci || '').trim();
  let bbvaBlock = '';
  if (bbvaAccount) {
    const cciPart = bbvaCci ? ` (CCI: ${bbvaCci})` : '';
    const holderPart = bbvaHolder ? ` - ${bbvaHolder}` : '';
    bbvaBlock = `\n🏦 BBVA: ${bbvaAccount}${cciPart}${holderPart}`;
  }

  const vars = {
    '{autor}': li.author_full_name || 'Julio Angello Vasquez Navarro',
    '{commercial_name}': li.commercial_name || li.brand_name || 'MochilaLista',
    '{support_phone}': li.support_phone || '+51 922 836 879',
    '{website}': li.official_website || 'https://mochilalista.com',
    '{official_website}': li.official_website || 'https://mochilalista.com',
    '{legal_framework}': li.legal_framework || 'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI Perú',
    '{personal_data_law}': li.personal_data_law || 'Ley N° 29733 (Ley de Protección de Datos Personales)',
    '{yape_phone}': pm.yape_plin_phone || '922836879',
    '{yape_titular}': pm.yape_plin_holder || 'Julio Angello Vasquez Navarro',
    '{bloque_banco_bcp}': bcpBlock,
    '{bloque_banco_bbva}': bbvaBlock,
  };

  for (const [k, v] of Object.entries(context)) {
    const cleanK = k.startsWith('{') && k.endsWith('}') ? k : `{${k}}`;
    vars[cleanK] = v !== undefined && v !== null ? String(v) : '';
  }

  for (const [pattern, replacement] of Object.entries(vars)) {
    template = template.split(pattern).join(replacement);
  }

  return template;
}

// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL .XLSX (FASE 4B) ===================

function initExcelExportEvents() {
  document.getElementById('btnHeaderExportExcel')?.addEventListener('click', () => {
    downloadExcelReport('/api/export/excel-master', `mochilalista_maestro_${Date.now()}.xlsx`);
  });

  document.getElementById('btnCrmExportExcel')?.addEventListener('click', () => {
    downloadExcelReport('/api/export/excel-master', `mochilalista_cartera_${Date.now()}.xlsx`);
  });

  document.getElementById('btnExportFinancesExcel')?.addEventListener('click', () => {
    const from = document.getElementById('finFilterFrom')?.value || '';
    const to = document.getElementById('finFilterTo')?.value || '';
    const query = new URLSearchParams();
    if (from) query.append('from', from);
    if (to) query.append('to', to);
    const qStr = query.toString() ? `?${query.toString()}` : '';
    downloadExcelReport(`/api/export/excel-finances${qStr}`, `mochilalista_finanzas_${Date.now()}.xlsx`);
  });
}

async function downloadExcelReport(url, defaultFilename) {
  try {
    showToast('Generando libro de Microsoft Excel (.xlsx)...', 'info');
    const res = await fetch(url);
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error del servidor HTTP ${res.status}`);
    }

    let filename = defaultFilename;
    const disposition = res.headers.get('content-disposition');
    if (disposition && disposition.indexOf('filename=') !== -1) {
      const match = disposition.match(/filename="?([^"]+)"?/);
      if (match && match[1]) filename = match[1];
    }

    const blob = await res.blob();
    const downloadUrl = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = downloadUrl;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.URL.revokeObjectURL(downloadUrl);

    showToast(`Libro Excel descargado: ${filename}`, 'success');
  } catch (err) {
    showToast(`Error al exportar Excel: ${err.message}`, 'error');
  }
}

// ==========================================================================
// FASE 3 PLAN MAESTRO 10: CENTRO DE SEGURIDAD, BÓVEDA Y PORTABILIDAD (#tabSecurityVault)
// ==========================================================================

let loadedVaultJson = null;
let loadedVaultMetadata = null;
let currentRescueCodes = [];
let recoveryMlKeySecret = null;
let importMlKeySecret = null;

function showVaultPinLockOverlay() {
  const overlay = document.getElementById('vaultPinLockOverlay');
  if (overlay) {
    overlay.style.display = 'flex';
    const pinInput = document.getElementById('vaultPinInput');
    if (pinInput) {
      pinInput.value = '';
      setTimeout(() => pinInput.focus(), 100);
    }
  }
}

function hideVaultPinLockOverlay() {
  const overlay = document.getElementById('vaultPinLockOverlay');
  if (overlay) {
    overlay.style.display = 'none';
    const notice = document.getElementById('vaultPinBackoffNotice');
    if (notice) notice.style.display = 'none';
  }
}

async function checkVaultInitialStatus() {
  try {
    // 1. Verificar si la sesión está bloqueada por PIN
    const pinRes = await fetch('/api/vault/pin/status');
    if (pinRes.ok) {
      const pinData = await pinRes.json();
      if (pinData.locked) {
        showVaultPinLockOverlay();
      }
    }

    // 2. Verificar si hay auto-recuperación disponible desde %APPDATA%
    const healthRes = await fetch('/api/vault/health');
    if (healthRes.ok) {
      const healthData = await healthRes.json();
      if (healthData.recovery_available) {
        openModal('modalAutoRecovery');
      }
    }
  } catch (err) {
    console.error('Error al verificar estado inicial de Bóveda:', err);
  }
}

function initVaultEvents() {
  // 1. Sincronización Manual de Espejo
  document.getElementById('btnSyncMirrorNow')?.addEventListener('click', syncMirrorManual);

  // 2. Copiar Rutas Físicas al Portapapeles
  document.getElementById('btnCopyLocalPath')?.addEventListener('click', () => {
    const val = document.getElementById('txtLocalPath')?.value;
    if (val) {
      navigator.clipboard.writeText(val).then(() => showToast('Ruta local copiada al portapapeles', 'success'));
    }
  });

  document.getElementById('btnCopyMirrorPath')?.addEventListener('click', () => {
    const val = document.getElementById('txtMirrorPath')?.value;
    if (val) {
      navigator.clipboard.writeText(val).then(() => showToast('Ruta de bóveda espejo copiada al portapapeles', 'success'));
    }
  });

  // 3. Guardar Ruta de Sincronización Cloud Secundaria
  document.getElementById('btnSaveCloudSyncPath')?.addEventListener('click', saveCloudSyncPath);

  // 4. Descargar Llave Offline (.mlkey)
  document.getElementById('btnDownloadMlKey')?.addEventListener('click', downloadMlKey);

  // 5. Abrir Generador de Kit de Rescate
  document.getElementById('btnOpenRescueKitModal')?.addEventListener('click', openRescueKitModal);

  // 6. Imprimir Kit y Copiar Códigos de Rescate
  document.getElementById('btnEmergencyPrint')?.addEventListener('click', () => window.print());
  document.getElementById('btnCopyRescueCodes')?.addEventListener('click', () => {
    if (currentRescueCodes.length > 0) {
      navigator.clipboard.writeText(currentRescueCodes.join('\n')).then(() => {
        showToast('8 Códigos de Rescate copiados al portapapeles', 'success');
      });
    }
  });

  // 7. Exportar Bóveda Portable (.mlvault)
  document.getElementById('btnExportVault')?.addEventListener('click', exportPortableVault);

  // 8. Abrir Modal de Importar Bóveda
  document.getElementById('btnOpenImportVaultModal')?.addEventListener('click', () => {
    resetImportVaultModal();
    openModal('modalImportVault');
  });

  // 9. Drag & Drop y Selección de Archivo .mlvault
  initVaultDropZoneEvents();

  // 10. Selector de Factores de Desbloqueo en Modal de Importación
  initImportFactorSelectorEvents();

  // 11. Confirmar Importación de Bóveda
  document.getElementById('btnSubmitImportVault')?.addEventListener('click', submitImportVault);

  // 12. Auto-Recuperación en 1 Clic
  document.getElementById('btnAutoRecoverNow')?.addEventListener('click', autoRecoverFromMirror);

  // 13. Configuración y Bloqueo por PIN
  initVaultPinEvents();
}

async function loadVaultHealth() {
  try {
    const [healthRes, pinRes] = await Promise.all([
      fetch('/api/vault/health'),
      fetch('/api/vault/pin/status'),
    ]);

    if (!healthRes.ok) throw new Error('No se pudo obtener el estado de salud de la bóveda');
    const health = await healthRes.json();
    const pinData = pinRes.ok ? await pinRes.json() : { pin_enabled: false };

    // Rutas Físicas
    const txtLocal = document.getElementById('txtLocalPath');
    if (txtLocal) txtLocal.value = health.primary_storage_path || 'data/';
    const txtMirror = document.getElementById('txtMirrorPath');
    if (txtMirror) txtMirror.value = health.mirror_storage_path || '%APPDATA%\\MochilaListaAdminVault';
    const txtCloud = document.getElementById('inputCloudSyncPath');
    if (txtCloud && health.cloud_sync_path) txtCloud.value = health.cloud_sync_path;

    // Cálculo del Score de Blindaje (0% - 100%)
    let score = 0;
    const factorMirror = !!health.mirror_exists;
    const factorKey = health.keyring_info?.active_slots?.includes('mlkey') || false;
    const factorRescue = health.keyring_info?.active_slots?.includes('rescue_code') || false;
    const factorPin = !!pinData.pin_enabled;

    if (factorMirror) score += 25;
    if (factorKey) score += 25;
    if (factorRescue) score += 25;
    if (factorPin) score += 25;

    // Actualizar Score y Barra de Progreso
    const scoreEl = document.getElementById('vaultHealthScore');
    if (scoreEl) scoreEl.textContent = `${score}%`;

    const progBar = document.getElementById('vaultProgressBar');
    if (progBar) {
      progBar.style.width = `${score}%`;
      if (score === 100) {
        progBar.style.background = 'linear-gradient(90deg, #10b981, #059669)';
      } else if (score >= 50) {
        progBar.style.background = 'linear-gradient(90deg, #f59e0b, #10b981)';
      } else {
        progBar.style.background = 'linear-gradient(90deg, #ef4444, #f59e0b)';
      }
    }

    const statusTextEl = document.getElementById('vaultHealthStatusText');
    const badgeEl = document.getElementById('vaultHealthBadge');
    if (statusTextEl) {
      const activeCount = (factorMirror ? 1 : 0) + (factorKey ? 1 : 0) + (factorRescue ? 1 : 0) + (factorPin ? 1 : 0);
      if (activeCount === 4) {
        statusTextEl.textContent = '4 de 4 Factores Activos (100% BLINDADO)';
        statusTextEl.style.color = 'var(--success)';
        if (badgeEl) { badgeEl.textContent = '100% BLINDADO'; badgeEl.className = 'badge badge-green'; }
      } else if (activeCount === 3) {
        statusTextEl.textContent = '3 de 4 Factores Activos (Alta Protección)';
        statusTextEl.style.color = 'var(--cyan)';
        if (badgeEl) { badgeEl.textContent = 'ALTA PROTECCIÓN'; badgeEl.className = 'badge badge-green'; }
      } else if (activeCount === 2) {
        statusTextEl.textContent = '2 de 4 Factores Activos (Protección Media)';
        statusTextEl.style.color = 'var(--warning)';
        if (badgeEl) { badgeEl.textContent = 'PROTECCIÓN MEDIA'; badgeEl.className = 'badge badge-amber'; }
      } else if (activeCount === 1) {
        statusTextEl.textContent = '1 de 4 Factores Activos (Protección Básica)';
        statusTextEl.style.color = 'var(--warning)';
        if (badgeEl) { badgeEl.textContent = 'PROTECCIÓN BÁSICA'; badgeEl.className = 'badge badge-amber'; }
      } else {
        statusTextEl.textContent = '0 de 4 Factores Activos (Vulnerable)';
        statusTextEl.style.color = 'var(--danger)';
        if (badgeEl) { badgeEl.textContent = 'VULNERABLE'; badgeEl.className = 'badge badge-red'; }
      }
    }

    const recWarnEl = document.getElementById('vaultRecoveryWarning');
    if (recWarnEl) {
      recWarnEl.style.display = health.recovery_available ? 'block' : 'none';
    }

    // Actualizar Insignias de Factores
    updateFactorBadge('factorMirrorStatus', factorMirror ? 'Activo' : 'Inactivo', factorMirror ? 'badge-green' : 'badge-red');
    updateFactorBadge('factorKeyStatus', factorKey ? 'Descargado' : 'Pendiente', factorKey ? 'badge-green' : 'badge-amber');
    updateFactorBadge('factorRescueStatus', factorRescue ? 'Generado' : 'Pendiente', factorRescue ? 'badge-green' : 'badge-amber');
    updateFactorBadge('factorPinStatus', factorPin ? 'Activado' : 'Opcional', factorPin ? 'badge-green' : 'badge-gray');

    // Tabla de Archivos Físicos
    renderVaultFilesTable(health.files, factorMirror);

    // Controles de PIN
    const chkPin = document.getElementById('chkEnablePin');
    if (chkPin) chkPin.checked = factorPin;
    const btnLock = document.getElementById('btnLockConsoleNow');
    if (btnLock) btnLock.style.display = factorPin ? 'inline-flex' : 'none';
  } catch (err) {
    showToast(`Error al cargar estado de la bóveda: ${err.message}`, 'error');
  }
}

function updateFactorBadge(elementId, text, badgeClass) {
  const el = document.getElementById(elementId);
  if (!el) return;
  el.textContent = text;
  el.className = `badge ${badgeClass}`;
}

function renderVaultFilesTable(files, mirrorExists) {
  const tbody = document.getElementById('tbodyVaultFiles');
  if (!tbody) return;
  tbody.innerHTML = '';

  const fileDefinitions = [
    { key: 'clients_db', name: 'Cartera de Clientes', path: 'data/prod_clients_db.json' },
    { key: 'releases_db', name: 'Catálogo de Lanzamientos', path: 'data/prod_releases_db.json' },
    { key: 'owner_config', name: 'Centro de Personalización', path: 'data/owner_config.json' },
    { key: 'master_key', name: 'Firma Digital Privada Ed25519', path: 'private_keys/ed25519_master.key' },
    { key: 'vault_keyring', name: 'Llavero de Bóveda Multi-Slot', path: 'data/vault_keyring.json' },
  ];

  fileDefinitions.forEach(item => {
    const f = files ? files[item.key] : null;
    const exists = f?.exists ?? false;
    const bytes = f?.bytes != null ? `${f.bytes} B` : '-';
    const sha = f?.sha256 ? `${f.sha256.substring(0, 8)}...` : '-';

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>
        <div style="font-weight:600; color:var(--text-primary);">${escapeHtml(item.name)}</div>
        <div style="font-family:var(--font-mono); font-size:0.75rem; color:var(--text-muted);">${escapeHtml(item.path)}</div>
      </td>
      <td>
        ${exists
        ? '<span style="color:var(--success); font-weight:600; font-size:0.8rem;">● En Disco</span>'
        : '<span style="color:var(--danger); font-weight:600; font-size:0.8rem;">○ Ausente</span>'
      }
      </td>
      <td>
        ${(mirrorExists && exists)
        ? '<span style="color:var(--cyan); font-weight:600; font-size:0.8rem;">🛡️ Bóveda Espejo</span>'
        : '<span style="color:var(--text-muted); font-size:0.8rem;">-</span>'
      }
      </td>
      <td>
        <div style="font-family:var(--font-mono); font-size:0.78rem;">${bytes}</div>
        <div style="font-family:var(--font-mono); font-size:0.72rem; color:var(--text-muted);">${sha}</div>
      </td>
      <td>
        ${exists
        ? '<span class="badge badge-green" style="font-size:0.75rem;">Sincronizado</span>'
        : '<span class="badge badge-amber" style="font-size:0.75rem;">Pendiente</span>'
      }
      </td>
    `;
    tbody.appendChild(tr);
  });
}

async function syncMirrorManual() {
  try {
    showToast('Sincronizando Bóveda Espejo en Windows (%APPDATA%)...', 'info');
    const res = await fetch('/api/vault/sync-mirror', { method: 'POST' });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }
    showToast('Bóveda Espejo sincronizada exitosamente.', 'success');
    await loadVaultHealth();
  } catch (err) {
    showToast(`Error al sincronizar espejo: ${err.message}`, 'error');
  }
}

async function saveCloudSyncPath() {
  const input = document.getElementById('inputCloudSyncPath');
  const path = input ? input.value.trim() : '';

  try {
    showToast('Guardando configuración de nube local...', 'info');
    const res = await fetch('/api/vault/set-cloud-path', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cloud_path: path || null }),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }
    const data = await res.json();
    showToast(data.message || 'Ruta guardada correctamente.', 'success');
    await loadVaultHealth();
  } catch (err) {
    showToast(`Error al guardar ruta de nube: ${err.message}`, 'error');
  }
}

async function downloadMlKey() {
  try {
    showToast('Generando y descargando llave offline (.mlkey)...', 'info');
    const res = await fetch('/api/vault/download-mlkey');
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }
    const data = await res.json();
    const filename = data.filename || 'llave_maestra_mochilalista.mlkey';
    const blob = new Blob([data.mlkey_json], { type: 'application/json' });
    const downloadUrl = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = downloadUrl;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.URL.revokeObjectURL(downloadUrl);

    showToast(`Llave offline descargada: ${filename}`, 'success');
    await loadVaultHealth();
  } catch (err) {
    showToast(`Error al descargar .mlkey: ${err.message}`, 'error');
  }
}

async function openRescueKitModal() {
  try {
    showToast('Generando 8 Códigos de Rescate Criptográficos...', 'info');
    const res = await fetch('/api/vault/generate-rescue-kit', { method: 'POST' });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }
    const data = await res.json();
    currentRescueCodes = data.codes || [];

    // Renderizar grilla de 8 códigos
    const grid = document.getElementById('rescueCodesGrid');
    if (grid) {
      grid.innerHTML = '';
      currentRescueCodes.forEach(code => {
        const div = document.createElement('div');
        div.className = 'rescue-code-item';
        div.textContent = code;
        grid.appendChild(div);
      });
    }

    // Fechas y metadatos
    const dateEl = document.getElementById('kitGeneratedDate');
    if (dateEl) dateEl.textContent = new Date().toLocaleString('es-PE');
    const vaultIdEl = document.getElementById('kitVaultId');
    if (vaultIdEl && data.qr_key) {
      vaultIdEl.textContent = `${data.qr_key.substring(0, 16)}...`;
    }

    // Código QR Vectorial
    const qrContainer = document.getElementById('rescueQrContainer');
    if (qrContainer) {
      renderSafeQrCode(qrContainer, data.qr_key || 'MOCHILALISTA-RESCUE-KIT', 140, '#000000', '#ffffff');
    }

    openModal('printableEmergencyKit');
    await loadVaultHealth();
  } catch (err) {
    showToast(`Error al generar kit de rescate: ${err.message}`, 'error');
  }
}

async function exportPortableVault() {
  const chkKey = document.getElementById('chkExportIncludeKey');
  const includeMasterKey = chkKey ? chkKey.checked : true;

  try {
    showToast('Empaquetando y cifrando Bóveda Portable (.mlvault)...', 'info');
    const res = await fetch('/api/vault/export', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ include_master_key: includeMasterKey }),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }
    const data = await res.json();
    const filename = data.filename || 'mochilalista_vault.mlvault';
    const blob = new Blob([data.vault_json], { type: 'application/json' });
    const downloadUrl = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = downloadUrl;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.URL.revokeObjectURL(downloadUrl);

    showToast(`Bóveda portable descargada con éxito: ${filename}`, 'success');
  } catch (err) {
    showToast(`Error al exportar bóveda: ${err.message}`, 'error');
  }
}

function resetImportVaultModal() {
  loadedVaultJson = null;
  loadedVaultMetadata = null;
  importMlKeySecret = null;

  const dropZone = document.getElementById('vaultDropZone');
  if (dropZone) dropZone.classList.remove('dragover');
  const nameDisplay = document.getElementById('vaultFileNameDisplay');
  if (nameDisplay) nameDisplay.textContent = '';
  const fileInput = document.getElementById('vaultFileInput');
  if (fileInput) fileInput.value = '';

  const summary = document.getElementById('vaultInspectSummary');
  if (summary) summary.style.display = 'none';
  const factors = document.getElementById('vaultUnlockFactorSection');
  if (factors) factors.style.display = 'none';

  const btnSubmit = document.getElementById('btnSubmitImportVault');
  if (btnSubmit) btnSubmit.disabled = true;

  const keyDisplay = document.getElementById('importKeyFileNameDisplay');
  if (keyDisplay) keyDisplay.textContent = '';
  const keyInput = document.getElementById('importKeyFileInput');
  if (keyInput) keyInput.value = '';
  const rescueInput = document.getElementById('importRescueCodeInput');
  if (rescueInput) rescueInput.value = '';
  const pinInput = document.getElementById('importPinInput');
  if (pinInput) pinInput.value = '';
}

function initVaultDropZoneEvents() {
  const dropZone = document.getElementById('vaultDropZone');
  const fileInput = document.getElementById('vaultFileInput');
  if (!dropZone || !fileInput) return;

  ['dragenter', 'dragover'].forEach(eventName => {
    dropZone.addEventListener(eventName, e => {
      e.preventDefault();
      e.stopPropagation();
      dropZone.classList.add('dragover');
    });
  });

  ['dragleave', 'drop'].forEach(eventName => {
    dropZone.addEventListener(eventName, e => {
      e.preventDefault();
      e.stopPropagation();
      dropZone.classList.remove('dragover');
    });
  });

  dropZone.addEventListener('drop', e => {
    const files = e.dataTransfer.files;
    if (files.length > 0) {
      handleVaultFileSelected(files[0]);
    }
  });

  fileInput.addEventListener('change', e => {
    if (e.target.files.length > 0) {
      handleVaultFileSelected(e.target.files[0]);
    }
  });
}

function handleVaultFileSelected(file) {
  if (!file.name.endsWith('.mlvault') && !file.name.endsWith('.json')) {
    showToast('El archivo seleccionado debe tener extensión .mlvault', 'warning');
    return;
  }

  const nameDisplay = document.getElementById('vaultFileNameDisplay');
  if (nameDisplay) nameDisplay.textContent = `Archivo: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;

  const reader = new FileReader();
  reader.onload = async e => {
    loadedVaultJson = e.target.result;
    await inspectLoadedVault();
  };
  reader.onerror = () => showToast('Error al leer el archivo seleccionado.', 'error');
  reader.readAsText(file);
}

async function inspectLoadedVault() {
  if (!loadedVaultJson) return;

  try {
    showToast('Inspeccionando integridad de la Bóveda Portable...', 'info');
    const res = await fetch('/api/vault/inspect', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ vault_json: loadedVaultJson }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }

    const data = await res.json();
    loadedVaultMetadata = data.metadata;

    // Mostrar panel de resumen
    const summary = document.getElementById('vaultInspectSummary');
    if (summary) summary.style.display = 'block';

    const vVer = document.getElementById('metaVaultVersion');
    if (vVer) vVer.textContent = loadedVaultMetadata.vault_version || '1.0';
    const vDate = document.getElementById('metaVaultCreated');
    if (vDate) vDate.textContent = loadedVaultMetadata.created_at ? loadedVaultMetadata.created_at.substring(0, 10) : '-';
    const vClients = document.getElementById('metaVaultClients');
    if (vClients) vClients.textContent = `${loadedVaultMetadata.total_clients ?? 0} clientes`;
    const vKey = document.getElementById('metaVaultHasKey');
    if (vKey) vKey.textContent = loadedVaultMetadata.has_master_key ? '✅ Incluida' : '○ No incluida';
    const vSlots = document.getElementById('metaVaultSlots');
    if (vSlots) vSlots.textContent = (loadedVaultMetadata.available_slots || []).join(', ');

    // Mostrar sección de selección de factores y ajustar visibilidad según slots disponibles
    const factorSection = document.getElementById('vaultUnlockFactorSection');
    if (factorSection) factorSection.style.display = 'block';

    const slots = loadedVaultMetadata.available_slots || [];
    const hasMlKey = slots.includes('mlkey');
    const hasRescue = slots.includes('rescue_code');
    const hasPin = slots.includes('pin');
    const hasDpapi = slots.includes('dpapi');

    const rowMlKey = document.getElementById('rowFactorMlKey');
    const rowRescue = document.getElementById('rowFactorRescue');
    const rowPin = document.getElementById('rowFactorPin');
    const rowDpapi = document.getElementById('rowFactorDpapi');

    if (rowMlKey) rowMlKey.style.display = hasMlKey ? 'flex' : 'none';
    if (rowRescue) rowRescue.style.display = hasRescue ? 'flex' : 'none';
    if (rowPin) rowPin.style.display = hasPin ? 'flex' : 'none';
    if (rowDpapi) rowDpapi.style.display = hasDpapi ? 'flex' : 'none';

    // Seleccionar por defecto el primer factor disponible
    const radios = document.querySelectorAll('input[name="importFactorType"]');
    for (const r of radios) {
      if (slots.includes(r.value)) {
        r.checked = true;
        triggerImportFactorChange(r.value);
        break;
      }
    }

    const btnSubmit = document.getElementById('btnSubmitImportVault');
    if (btnSubmit) btnSubmit.disabled = false;
    showToast('Bóveda inspeccionada con éxito. Selecciona el factor para desencriptar.', 'success');
  } catch (err) {
    showToast(`Error al inspeccionar bóveda: ${err.message}`, 'error');
  }
}

function initImportFactorSelectorEvents() {
  const radios = document.querySelectorAll('input[name="importFactorType"]');
  radios.forEach(radio => {
    radio.addEventListener('change', e => {
      triggerImportFactorChange(e.target.value);
    });
  });

  // Selector de archivo .mlkey para importación
  const keyFileInput = document.getElementById('importKeyFileInput');
  keyFileInput?.addEventListener('change', e => {
    if (e.target.files.length > 0) {
      const file = e.target.files[0];
      const nameEl = document.getElementById('importKeyFileNameDisplay');
      if (nameEl) nameEl.textContent = file.name;
      const reader = new FileReader();
      reader.onload = ev => {
        importMlKeySecret = ev.target.result;
        showToast('Archivo .mlkey cargado correctamente.', 'info');
      };
      reader.readAsText(file);
    }
  });
}

function triggerImportFactorChange(selectedFactor) {
  const cKey = document.getElementById('factorMlKeyInputContainer');
  const cRescue = document.getElementById('factorRescueInputContainer');
  const cPin = document.getElementById('factorPinInputContainer');

  if (cKey) cKey.style.display = selectedFactor === 'mlkey' ? 'block' : 'none';
  if (cRescue) cRescue.style.display = selectedFactor === 'rescue_code' ? 'block' : 'none';
  if (cPin) cPin.style.display = selectedFactor === 'pin' ? 'block' : 'none';
}

async function submitImportVault() {
  if (!loadedVaultJson) {
    showToast('Debes seleccionar o arrastrar un archivo .mlvault válido.', 'warning');
    return;
  }

  const selectedRadio = document.querySelector('input[name="importFactorType"]:checked');
  const factorType = selectedRadio ? selectedRadio.value : 'mlkey';

  let secret = null;
  if (factorType === 'mlkey') {
    if (!importMlKeySecret) {
      showToast('Por favor selecciona el archivo .mlkey para desencriptar.', 'warning');
      return;
    }
    secret = importMlKeySecret;
  } else if (factorType === 'rescue_code') {
    const code = document.getElementById('importRescueCodeInput')?.value.trim();
    if (!code) {
      showToast('Por favor ingresa un Código de Rescate (XXXX-XXXX-XXXX).', 'warning');
      return;
    }
    secret = code;
  } else if (factorType === 'pin') {
    const pin = document.getElementById('importPinInput')?.value.trim();
    if (!pin) {
      showToast('Por favor ingresa el PIN de la máquina de origen.', 'warning');
      return;
    }
    secret = pin;
  }

  const chkRewrap = document.getElementById('chkImportRewrap');
  const rewrapDpapi = chkRewrap ? chkRewrap.checked : true;

  try {
    showToast('Restaurando base de datos, firmas y configuraciones en caliente...', 'info');
    const res = await fetch('/api/vault/import', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        vault_json: loadedVaultJson,
        credential_type: factorType,
        secret: secret,
        rewrap_dpapi: rewrapDpapi,
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }

    const data = await res.json();
    closeModal('modalImportVault');
    showToast(data.message || 'Bóveda importada exitosamente y recargada en caliente.', 'success');

    // Recargar todas las vistas
    await Promise.all([
      loadVaultHealth(),
      loadClients(),
      loadDashboard(),
      loadReleases(),
      loadConfig(),
    ]);
  } catch (err) {
    showToast(`Error al importar bóveda: ${err.message}`, 'error');
  }
}

async function autoRecoverFromMirror() {
  try {
    showToast('Restaurando Bóveda Espejo en 1 Clic con DPAPI...', 'info');
    const res = await fetch('/api/vault/recover-from-mirror', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ credential_type: 'dpapi' }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }

    const data = await res.json();
    closeModal('modalAutoRecovery');
    showToast(data.message || 'Bóveda recuperada automáticamente con éxito.', 'success');

    await Promise.all([
      loadVaultHealth(),
      loadClients(),
      loadDashboard(),
      loadReleases(),
      loadConfig(),
    ]);
  } catch (err) {
    showToast(`Error al restaurar desde espejo: ${err.message}`, 'error');
  }
}

function initVaultPinEvents() {
  const chkPin = document.getElementById('chkEnablePin');
  const pinSetup = document.getElementById('pinSetupContainer');
  const btnSavePin = document.getElementById('btnSavePinConfig');
  const btnLockNow = document.getElementById('btnLockConsoleNow');

  chkPin?.addEventListener('change', e => {
    if (e.target.checked) {
      if (pinSetup) pinSetup.style.display = 'block';
    } else {
      showConfirmModal(
        'Desactivar Bloqueo por PIN',
        '¿Estás seguro de que deseas desactivar el PIN de consola? Cualquier usuario con acceso a tu navegador podrá ver la plataforma sin restricciones.',
        async () => {
          try {
            const res = await fetch('/api/vault/pin/configure', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ enabled: false }),
            });
            if (res.ok) {
              if (pinSetup) pinSetup.style.display = 'none';
              showToast('Bloqueo por PIN desactivado exitosamente.', 'info');
              await loadVaultHealth();
            }
          } catch (err) {
            showToast(`Error al desactivar PIN: ${err.message}`, 'error');
          }
        }
      );
    }
  });

  btnSavePin?.addEventListener('click', async () => {
    const pin = document.getElementById('inputVaultPin')?.value.trim();
    const pinConfirm = document.getElementById('inputVaultPinConfirm')?.value.trim();

    if (!pin || pin.length < 4) {
      showToast('El PIN debe contener al menos 4 caracteres.', 'warning');
      return;
    }
    if (pin !== pinConfirm) {
      showToast('Los campos de PIN y confirmación no coinciden.', 'warning');
      return;
    }

    try {
      const res = await fetch('/api/vault/pin/configure', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: true, pin: pin }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || `Error HTTP ${res.status}`);
      }
      showToast('PIN configurado y activado exitosamente.', 'success');
      document.getElementById('inputVaultPin').value = '';
      document.getElementById('inputVaultPinConfirm').value = '';
      if (pinSetup) pinSetup.style.display = 'none';
      await loadVaultHealth();
    } catch (err) {
      showToast(`Error al guardar PIN: ${err.message}`, 'error');
    }
  });

  btnLockNow?.addEventListener('click', async () => {
    try {
      await fetch('/api/vault/pin/lock', { method: 'POST' });
      sessionStorage.removeItem('ml_vault_session_token');
      showVaultPinLockOverlay();
      showToast('Consola bloqueada por PIN.', 'info');
    } catch (err) {
      showVaultPinLockOverlay();
    }
  });

  // Desbloqueo mediante formulario
  document.getElementById('formUnlockPin')?.addEventListener('submit', async e => {
    e.preventDefault();
    const pin = document.getElementById('vaultPinInput')?.value.trim();
    if (!pin) return;

    try {
      const res = await fetch('/api/vault/pin/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pin: pin }),
      });
      const data = await res.json();
      if (data.ok && data.session_token) {
        sessionStorage.setItem('ml_vault_session_token', data.session_token);
        hideVaultPinLockOverlay();
        showToast('Consola desbloqueada correctamente.', 'success');
      } else {
        const notice = document.getElementById('vaultPinBackoffNotice');
        if (notice) {
          notice.style.display = 'block';
          notice.textContent = data.error || 'PIN incorrecto.';
        }
      }
    } catch (err) {
      showToast(`Error al verificar PIN: ${err.message}`, 'error');
    }
  });

  // Enlace "¿Olvidaste tu PIN?"
  document.getElementById('linkForgotPin')?.addEventListener('click', () => {
    const panel = document.getElementById('vaultPinRecoveryPanel');
    if (panel) {
      panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
    }
  });

  // Carga de archivo .mlkey para recuperación
  const recKeyInput = document.getElementById('recoveryKeyFileInput');
  recKeyInput?.addEventListener('change', e => {
    if (e.target.files.length > 0) {
      const file = e.target.files[0];
      const nameEl = document.getElementById('recoveryKeyFileName');
      if (nameEl) nameEl.textContent = file.name;
      const reader = new FileReader();
      reader.onload = ev => {
        recoveryMlKeySecret = ev.target.result;
        showToast('Archivo .mlkey de recuperación listo.', 'info');
      };
      reader.readAsText(file);
    }
  });

  // Recuperación mediante DPAPI directa
  document.getElementById('btnRecoveryDpapi')?.addEventListener('click', async () => {
    await executePinRecovery('dpapi', null);
  });

  // Recuperación mediante Botón Confirmar
  document.getElementById('btnSubmitRecovery')?.addEventListener('click', async () => {
    const code = document.getElementById('recoveryCodeInput')?.value.trim();
    if (recoveryMlKeySecret) {
      await executePinRecovery('mlkey', recoveryMlKeySecret);
    } else if (code) {
      await executePinRecovery('rescue_code', code);
    } else {
      showToast('Selecciona un archivo .mlkey o ingresa un Código de Rescate.', 'warning');
    }
  });
}

async function executePinRecovery(credType, secretVal) {
  try {
    showToast('Recuperando acceso a la consola...', 'info');
    const res = await fetch('/api/vault/pin/recover', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        credential_type: credType,
        secret: secretVal,
        disable_pin: true,
      }),
    });

    const data = await res.json();
    if (data.ok) {
      if (data.session_token) {
        sessionStorage.setItem('ml_vault_session_token', data.session_token);
      }
      hideVaultPinLockOverlay();
      showToast('Acceso recuperado y consola desbloqueada con éxito.', 'success');
      await loadVaultHealth();
    } else {
      showToast(`No se pudo recuperar: ${data.error || 'Factor inválido'}`, 'error');
    }
  } catch (err) {
    showToast(`Error en recuperación: ${err.message}`, 'error');
  }
}
