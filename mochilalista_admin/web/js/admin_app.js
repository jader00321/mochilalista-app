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
  initSettingsEvents();
  initExcelExportEvents();
  initVaultEvents();
  await checkVaultInitialStatus();
  await loadConfig();
  await loadSystemMode();
  await loadDashboard();
  await loadClients();
  await loadReleases();
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
    closeClient360Drawer();
    closeModal('modalWaComposer');
    currentWaComposerClientId = null;
    document.querySelectorAll('.modal-overlay.open').forEach(m => m.classList.remove('open'));

    currentDrawerClientId = null;
    currentQuickQrClientId = null;
    currentHistoryClientId = null;

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
    await Promise.allSettled([
      loadDashboard(),
      loadClients(),
      loadReleases(),
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
    updatePlanImpactAndProjection();
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
    let statusBadge = '<span class="badge badge-green">Activa</span>';
    const plan = (c.license_type || 'MENSUAL').toUpperCase();
    const status = (c.license_status || '').toUpperCase();
    const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
    const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
    const expDate = c.license_expires ? new Date(c.license_expires) : null;
    const diffDays = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : 999;

    if (isProspect) {
      statusBadge = '<span class="badge badge-prospect">Prospecto</span>';
    } else if (isPerp) {
      statusBadge = '<span class="badge badge-purple">Perpetua</span>';
    } else if (diffDays < 0) {
      statusBadge = '<span class="badge badge-red">Vencida</span>';
    } else if (diffDays <= 7) {
      statusBadge = `<span class="badge badge-yellow">Vence en ${diffDays}d</span>`;
    }

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
          ${!isProspect ? `<small style="font-weight:700; color:var(--text-secondary);">(${escapeHtml(c.license_type || 'MENSUAL')})</small>` : ''}
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
        ${(c.ai_extra_credits || 0) > 0
        ? `<span class="badge badge-purple">+${c.ai_extra_credits} IA</span>`
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

function selectClientForLicense(clientId) {
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

  const studioTab = document.querySelector('[data-tab="tabLicenseStudio"]');
  studioTab?.classList.add('active');
  document.getElementById('tabLicenseStudio')?.classList.add('active');

  const licSelect = document.getElementById('licClientSelect');
  if (licSelect) {
    licSelect.value = clientId;
    updateClientSummaryCard();
    updatePlanImpactAndProjection();

    // Precargar bono IA acordado pendiente de emitir si existe
    const client = globalClients.find(c => c.id === clientId);
    if (client && (client.ai_pending_bonus || 0) > 0) {
      const bonusInput = document.getElementById('licCustomAiBonus');
      if (bonusInput) {
        bonusInput.value = client.ai_pending_bonus;
      }
    }
  }
}

// =================== 3. GENERADOR DE LICENCIAS ED25519 & MODO PERSONALIZADO ===================
function initLicenseStudioEvents() {
  const planSelect = document.getElementById('licPlanSelect');
  const clientSelect = document.getElementById('licClientSelect');

  planSelect?.addEventListener('change', () => {
    updatePlanImpactAndProjection();
  });

  clientSelect?.addEventListener('change', () => {
    updateClientSummaryCard();
    updatePlanImpactAndProjection();
  });

  // Acordeón de ajustes comerciales personalizados
  const btnToggleCustom = document.getElementById('btnToggleCustomSettings');
  const customContent = document.getElementById('licCustomContent');
  const accordionArrow = document.getElementById('accordionArrow');

  btnToggleCustom?.addEventListener('click', () => {
    const isOpen = customContent.classList.toggle('open');
    if (accordionArrow) accordionArrow.textContent = isOpen ? '▲' : '▼';
  });

  // Escuchar inputs personalizados para recalcular proyección en vivo
  document.getElementById('licCustomDays')?.addEventListener('input', updatePlanImpactAndProjection);
  document.getElementById('licCustomAiBonus')?.addEventListener('input', updatePlanImpactAndProjection);
  document.getElementById('licCustomComputationMode')?.addEventListener('change', updatePlanImpactAndProjection);
  document.getElementById('licCustomExactDate')?.addEventListener('change', () => {
    const exactDateVal = document.getElementById('licCustomExactDate').value;
    if (exactDateVal) {
      const targetDate = new Date(exactDateVal + 'T23:59:59');
      const now = new Date();
      const diff = Math.max(1, Math.ceil((targetDate - now) / (1000 * 60 * 60 * 24)));
      document.getElementById('licCustomDays').value = diff;
    }
    updatePlanImpactAndProjection();
  });

  document.getElementById('btnGenerateLicense')?.addEventListener('click', generateLicense);

  document.getElementById('btnCopyCode')?.addEventListener('click', () => {
    const code = document.getElementById('generatedCodeDisplay').textContent;
    navigator.clipboard.writeText(code).then(() => {
      showToast('¡Código copiado al portapapeles!', 'success');
    });
  });

  document.getElementById('btnDownloadQr')?.addEventListener('click', () => {
    if (lastGeneratedQr) {
      const url = lastGeneratedQr.toDataURL();
      const a = document.createElement('a');
      a.download = `QR_MochilaLista_${Date.now()}.png`;
      a.href = url;
      a.click();
      showToast('QR descargado correctamente.', 'success');
    }
  });

  document.getElementById('btnDownloadCredential')?.addEventListener('click', downloadCredential);
  document.getElementById('btnCopyCredentialImage')?.addEventListener('click', copyCredentialToClipboard);

  // Botón Auditar en el Inspector
  document.getElementById('btnAuditInInspector')?.addEventListener('click', () => {
    const token = document.getElementById('generatedCodeDisplay').textContent.trim();
    if (!token) return;

    // Cambiar a la pestaña Inspector
    const tabs = document.querySelectorAll('.nav-tab');
    tabs.forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

    const inspectTab = document.querySelector('[data-tab="tabInspector"]');
    inspectTab?.classList.add('active');
    document.getElementById('tabInspector')?.classList.add('active');

    // Pasar token y auditar
    const inspectInput = document.getElementById('inspectTokenInput');
    if (inspectInput) {
      inspectInput.value = token;
      inspectToken();
      showToast('Token transferido al Inspector Forense.', 'info');
    }
  });
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
  document.getElementById('sumPlanNonce').textContent = `${client.license_type || 'MENSUAL'} (Nonce #${client.next_nonce || 1})`;

  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const isPerp = (client.license_type || '').toUpperCase().includes('PERPETU');
  const isProspect = (client.license_type || '').toUpperCase() === 'PROSPECTO' || (client.license_status || '').toUpperCase() === 'PROSPECTO';

  if (isProspect) {
    document.getElementById('sumExpiresDate').textContent = client.expected_subscription_date
      ? `Seguimiento: ${client.expected_subscription_date}`
      : 'Sin vencimiento (Prospecto)';
    document.getElementById('sumStatusBadge').className = 'badge badge-prospect';
    document.getElementById('sumStatusBadge').textContent = 'PROSPECTO';
  } else if (isPerp) {
    document.getElementById('sumExpiresDate').textContent = 'Vitalicia (De por Vida)';
    document.getElementById('sumStatusBadge').className = 'badge badge-purple';
    document.getElementById('sumStatusBadge').textContent = 'PERPETUA';
  } else if (expDate) {
    const diff = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
    document.getElementById('sumExpiresDate').textContent = `${client.license_expires.substring(0, 10)} (${diff}d restantes)`;
    if (diff < 0) {
      document.getElementById('sumStatusBadge').className = 'badge badge-red';
      document.getElementById('sumStatusBadge').textContent = 'VENCIDA';
    } else if (diff <= 7) {
      document.getElementById('sumStatusBadge').className = 'badge badge-yellow';
      document.getElementById('sumStatusBadge').textContent = `POR VENCER (${diff}d)`;
    } else {
      document.getElementById('sumStatusBadge').className = 'badge badge-green';
      document.getElementById('sumStatusBadge').textContent = 'ACTIVA';
    }
  } else {
    document.getElementById('sumExpiresDate').textContent = 'Sin fecha';
  }

  const aiExtra = client.ai_extra_credits || 0;
  document.getElementById('sumAiCredits').textContent = `+${aiExtra} escaneos IA vitalicios`;
  document.getElementById('sumInstalledVersion').textContent = `v${client.installed_version || '9.34.0'}`;
  document.getElementById('sumUpdatesUntil').textContent = client.updates_until ? client.updates_until.substring(0, 10) : 'No configurada';
}

function updatePlanImpactAndProjection() {
  const planSelect = document.getElementById('licPlanSelect');
  const clientSelect = document.getElementById('licClientSelect');
  const amountInput = document.getElementById('licPaymentAmount');
  const impactBadge = document.getElementById('licPlanImpactBadge');
  const projectionText = document.getElementById('licPlanProjection');

  if (!planSelect || !amountInput || !impactBadge || !projectionText) return;

  const selectedOpt = planSelect.options[planSelect.selectedIndex];
  const plan = planSelect.value;
  const cfgPlan = ownerConfig?.catalog?.[plan];
  const defaultPrice = (cfgPlan?.price !== undefined) ? cfgPlan.price.toFixed(2) : (selectedOpt.getAttribute('data-price') || '35.00');
  amountInput.value = defaultPrice;

  const clientId = clientSelect.value;
  const client = globalClients.find(c => c.id === clientId);

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

  // Si hay días personalizados configurados
  if (customDaysVal > 0) {
    impactBadge.innerHTML = `⚙️ <strong>Ajuste Personalizado:</strong> Se otorgarán <strong>+${customDaysVal} días</strong> directos (${customMode === 'from_today' ? 'contando desde hoy' : 'acumulativos'}).` +
      (customAiBonus > 0 ? ` + <strong>${customAiBonus} escaneos IA de regalo</strong>.` : '');
    const projCustom = new Date(baseDate.getTime() + customDaysVal * 24 * 60 * 60 * 1000);
    projectionText.innerHTML = `📅 <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projCustom)}.`;
    return;
  }

  switch (plan) {
    case 'RECARGA_IA_150':
      const aiCredits = (cfgPlan?.ai_credits !== undefined) ? cfgPlan.ai_credits : 150;
      impactBadge.classList.add('recharge');
      impactBadge.innerHTML = `💡 <strong>Impacto:</strong> Conservará su plan actual y su fecha de vigencia. Se sumarán <strong>+${aiCredits} créditos de escaneos IA</strong> acumulativos sin fecha de caducidad.`;
      projectionText.innerHTML = client
        ? `📅 <strong>Vigencia:</strong> Mantiene su fecha actual (${client.license_expires ? client.license_expires.substring(0, 10) : 'Activa'}).`
        : '📅 <strong>Vigencia:</strong> Sin alteración en la suscripción.';
      break;

    case 'PERPETUO_LIBERADO':
      const updateMonths = (cfgPlan?.updates_window_months !== undefined) ? cfgPlan.updates_window_months : 12;
      impactBadge.classList.add('perpetual');
      impactBadge.innerHTML = `⭐ <strong>Impacto:</strong> Licencia Perpetua Liberada. Acceso ilimitado de por vida (+99,999 días) con ${updateMonths} meses de actualizaciones de funciones incluidas.`;
      const updatesTarget = new Date(now.getTime() + updateMonths * 30 * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `📅 <strong>Vigencia:</strong> Vitalicia de por vida • <strong>Pase de Updates hasta:</strong> ${formatDateStr(updatesTarget)}.`;
      break;

    case 'PASE_ACTUALIZACION_ANUAL':
      const passDays = (cfgPlan?.days !== undefined && cfgPlan.days > 0) ? cfgPlan.days : 365;
      impactBadge.classList.add('perpetual');
      impactBadge.innerHTML = `🔄 <strong>Impacto:</strong> Extiende por <strong>+${passDays} días adicionales</strong> la ventana de nuevas versiones y herramientas para clientes perpetuos.`;
      const currentUpdates = client && client.updates_until ? new Date(client.updates_until) : now;
      const baseUp = currentUpdates > now ? currentUpdates : now;
      const newUpdates = new Date(baseUp.getTime() + passDays * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `📅 <strong>Nueva Ventana de Updates:</strong> Hasta el ${formatDateStr(newUpdates)} (+${passDays} días).`;
      break;

    case 'EXTENSION_CORTESIA':
      const cortesiaDays = (cfgPlan?.days !== undefined && cfgPlan.days > 0) ? cfgPlan.days : 7;
      impactBadge.innerHTML = `⏳ <strong>Impacto:</strong> Otorga <strong>+${cortesiaDays} días de gracia temporal</strong> (S/ 0.00) para resolver cobranza en trámite o emergencias operativas.`;
      const projCortesia = new Date(baseDate.getTime() + cortesiaDays * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `📅 <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projCortesia)} (+${cortesiaDays} días de gracia).`;
      break;

    default: // MENSUAL (30), TRIMESTRAL (90), SEMESTRAL (180), ANUAL (365)
      const days = (cfgPlan?.days !== undefined) ? cfgPlan.days : (parseInt(selectedOpt.getAttribute('data-days')) || 30);
      impactBadge.innerHTML = `📅 <strong>Impacto:</strong> Renovación acumulativa sin pérdida de días. Se sumarán <strong>+${days} días</strong> directos al saldo remanente.`;
      const projRegular = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `📅 <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projRegular)} (Cero pérdida de días).`;
      break;
  }
}

async function generateLicense() {
  const clientId = document.getElementById('licClientSelect').value;
  if (!clientId) {
    showToast('Por favor selecciona un cliente de la lista.', 'warning');
    return;
  }

  const client = globalClients.find(c => c.id === clientId);
  const plan = document.getElementById('licPlanSelect').value;
  const paymentAmount = parseFloat(document.getElementById('licPaymentAmount').value) || 0;
  const paymentMethod = document.getElementById('licPaymentMethod').value;
  const paymentRef = document.getElementById('licPaymentRef').value.trim() || 'Op. Generada';

  // Parámetros de personalización libre
  const customDaysVal = parseInt(document.getElementById('licCustomDays')?.value) || null;
  const customAiBonus = parseInt(document.getElementById('licCustomAiBonus')?.value) || 0;
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
        computation_mode: computationMode,
        custom_exact_expiration: customExactDate,
      }),
    });

    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || 'Error al generar licencia');
    }

    const data = await res.json();

    // Mostrar resultados
    document.getElementById('resultPlaceholder').style.display = 'none';
    const resultBox = document.getElementById('resultContent');
    resultBox.style.display = 'flex';

    document.getElementById('generatedCodeDisplay').textContent = data.token;

    // Enlace de WhatsApp
    const cleanPhone = (client?.phone || data.client?.phone || '').replace(/[^0-9]/g, '');
    const targetClient = client || data.client;
    const msgText = renderConfigTemplate('license_issued', {
      titular: targetClient?.owner_name || 'Comerciante',
      negocio: targetClient?.business_name || 'tu negocio',
      plan: data.plan,
      dias: data.days_added,
      vencimiento: data.expires_result ? data.expires_result.substring(0, 10) : 'Activa',
      creditos_ia: data.ai_extra_credits || targetClient?.ai_extra_credits || 0,
      codigo: data.token,
      device_id: data.device_id,
    });
    document.getElementById('btnSendWa').href = `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(msgText)}`;

    // Renderizar QR Code
    const qrContainer = document.getElementById('qrContainer');
    lastGeneratedQr = renderSafeQrCode(qrContainer, data.token, 230);

    // Renderizar Credencial PNG de Alta Resolución tras render del QR
    setTimeout(() => {
      renderCredentialCanvas(data, client || data.client);
    }, 200);

    showToast('¡Licencia Ed25519 emitida y firmada con éxito!', 'success');

    // Refrescar clientes y dashboard
    await loadClients();
    await loadDashboard();
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

  ctx.fillStyle = plan === 'PERPETUO_LIBERADO' ? '#c084fc' : (plan === 'RECARGA_IA_150' ? '#34d399' : '#60a5fa');
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
    EXTENSION_CORTESIA: 0,
  };
  const cfgPlan = ownerConfig?.catalog?.[plan];
  const baseScans = cfgPlan?.ai_credits !== undefined ? cfgPlan.ai_credits : (baseScansMap[plan] !== undefined ? baseScansMap[plan] : 50);
  const extraCredits = licenseData.ai_extra_credits || (client ? client.ai_extra_credits : 0) || 0;
  const totalScans = plan === 'RECARGA_IA_150' ? 150 : (baseScans + extraCredits);
  const aiText = plan === 'RECARGA_IA_150'
    ? '+150 escaneos IA sin vencimiento (Bolsa Acumulativa)'
    : `+${totalScans} escaneos IA acumulativos vitalicios (o BYOK)`;
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
    const qrCanvas = qrContainer.querySelector('canvas') || qrContainer.querySelector('img');
    if (qrCanvas) {
      const a = document.createElement('a');
      a.download = `QR_MochilaLista_${client.current_device_id}_${Date.now()}.png`;
      a.href = qrCanvas.toDataURL ? qrCanvas.toDataURL('image/png') : qrCanvas.src;
      a.click();
      showToast('QR descargado correctamente.', 'success');
    }
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
function initDrawerEvents() {
  const dtabs = document.querySelectorAll('.drawer-tab-btn');
  dtabs.forEach(btn => {
    btn.addEventListener('click', () => {
      dtabs.forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.drawer-tab-pane').forEach(p => p.classList.remove('active'));

      btn.classList.add('active');
      const targetPane = document.getElementById(btn.dataset.dtab);
      if (targetPane) targetPane.classList.add('active');
    });
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
    closeClient360Drawer();
    selectClientForLicense(cid);
  });

  document.getElementById('btnDrawerMigrateDev')?.addEventListener('click', () => {
    if (!currentDrawerClientId) return;
    const cid = currentDrawerClientId;
    closeClient360Drawer();
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

      closeModal('modalSyncReported');
      showToast('Datos del celular sincronizados con éxito.', 'success');
      await loadClients();
      await loadDashboard();
      if (currentDrawerClientId === clientId) {
        openClient360Drawer(clientId, 'drawerTabOverview');
      }
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });
}

async function openClient360Drawer(clientId) {
  const initialTab = arguments[1] || 'drawerTabOverview';
  currentDrawerClientId = clientId;
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  // Activar pestaña solicitada de inmediato (con soporte para alias drawerTabSummary)
  const targetTabId = (initialTab === 'drawerTabSummary') ? 'drawerTabOverview' : initialTab;
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
  const plan = (client.license_type || 'MENSUAL').toUpperCase();
  const status = (client.license_status || '').toUpperCase();
  const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
  const isTrial = plan === 'TRIAL';
  const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const diffDays = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : 999;

  if (isProspect) {
    statusBadge.className = 'badge badge-prospect';
    statusBadge.textContent = 'Prospecto';
  } else if (isTrial) {
    statusBadge.className = 'badge badge-yellow';
    const trialDays = client.trial_days_remaining !== undefined && client.trial_days_remaining !== null
      ? client.trial_days_remaining
      : (diffDays >= 0 ? diffDays : 0);
    statusBadge.textContent = `Trial (${trialDays}d)`;
  } else if (isPerp) {
    statusBadge.className = 'badge badge-purple';
    statusBadge.textContent = 'Perpetua';
  } else if (diffDays < 0) {
    statusBadge.className = 'badge badge-red';
    statusBadge.textContent = 'Vencida';
  } else if (diffDays <= 7) {
    statusBadge.className = 'badge badge-yellow';
    statusBadge.textContent = `Vence en ${diffDays}d`;
  } else {
    statusBadge.className = 'badge badge-green';
    statusBadge.textContent = 'Activa';
  }

  // Pestaña 1: Resumen y Licencia
  document.getElementById('drawerKpiPlan').textContent = isProspect ? 'PROSPECTO' : plan.replace(/_/g, ' ');
  document.getElementById('drawerKpiExpires').textContent = isProspect
    ? (client.expected_subscription_date ? `Seguimiento: ${client.expected_subscription_date}` : 'Sin vencimiento')
    : (isPerp ? 'De por Vida' : (client.license_expires ? client.license_expires.substring(0, 10) : 'Sin fecha'));
  document.getElementById('drawerKpiAiCredits').textContent = `+${client.ai_extra_credits || 0} IA`;
  document.getElementById('drawerKpiVersion').textContent = `v${client.installed_version || '9.34.0'}`;
  
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
    drawerAiBreakdown.textContent = `Reportado: ${client.ai_reported_balance || 0} IA | Bono: +${client.ai_pending_bonus || 0} IA`;
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
    drawerHwVersionDisplay.innerHTML = `<code>v${escapeHtml(client.installed_version || '9.34.0')}</code> ${badgeHtml}`;
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
  document.getElementById('drawerEditInstalledVersion').value = client.installed_version || '9.34.0';
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

      // --- PESTAÑA 3: PAGOS & FINANZAS ---
      let totalPaid = 0;
      const methodCounts = {};
      let lastDate = '-';
      const paymentsBody = document.getElementById('drawerPaymentsBody');
      paymentsBody.innerHTML = '';

      const payments = history.payments || [];
      if (payments.length > 0) {
        payments.forEach(p => {
          const amt = parseFloat(p.amount) || 0;
          totalPaid += amt;
          const m = p.method || 'Otro';
          methodCounts[m] = (methodCounts[m] || 0) + 1;
          const pDate = p.date ? p.date.substring(0, 10) : '-';
          if (lastDate === '-' || (pDate !== '-' && pDate > lastDate)) {
            lastDate = pDate;
          }

          const tr = document.createElement('tr');
          const safePaymentJson = JSON.stringify(p).replace(/'/g, '&#39;');
          tr.innerHTML = `
            <td>${pDate}</td>
            <td><span class="badge badge-mono">${escapeHtml(p.plan || '-')}</span></td>
            <td><strong style="color:var(--success);">S/ ${amt.toFixed(2)}</strong></td>
            <td>${escapeHtml(p.method || '-')}</td>
            <td>${escapeHtml(p.reference || '-')}</td>
            <td style="text-align: center; white-space: nowrap;">
              <button type="button" class="btn-table-action" title="Editar Pago" onclick='openEditPaymentModal("${clientId}", ${safePaymentJson})'>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:13px; height:13px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
              </button>
              <button type="button" class="btn-table-action danger" title="Eliminar Pago" onclick='confirmDeletePayment("${clientId}", "${p.id}")'>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:13px; height:13px;"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
              </button>
            </td>
          `;
          paymentsBody.appendChild(tr);
        });
      } else {
        paymentsBody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1rem;">Sin pagos registrados</td></tr>';
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

        const renderSelectedDrawerLicense = (selectedCode) => {
          const token = selectedCode.token;
          document.getElementById('drawerCodeDisplay').textContent = token;
          renderSafeQrCode('drawerQrContainer', token, 196);

          // Metadatos
          const metaPlan = document.getElementById('drawerQrMetaPlan');
          if (metaPlan) metaPlan.textContent = selectedCode.plan || client.license_type || 'MENSUAL';
          const metaEmitted = document.getElementById('drawerQrMetaEmitted');
          if (metaEmitted) metaEmitted.textContent = selectedCode.created_at ? selectedCode.created_at.substring(0, 10) : '-';
          const metaExpires = document.getElementById('drawerQrMetaExpires');
          if (metaExpires) metaExpires.textContent = selectedCode.expires_at ? selectedCode.expires_at.substring(0, 10) : (client.license_expires ? client.license_expires.substring(0, 10) : 'Activa');
          const metaNonce = document.getElementById('drawerQrMetaNonce');
          if (metaNonce) metaNonce.textContent = selectedCode.nonce || client.next_nonce || 1;
          const metaAi = document.getElementById('drawerQrMetaAi');
          if (metaAi) metaAi.textContent = `+${selectedCode.ai_credits ?? client.ai_extra_credits ?? 0} IA`;
          const metaDevice = document.getElementById('drawerQrMetaDevice');
          if (metaDevice) metaDevice.textContent = selectedCode.device_id || client.current_device_id || '-';

          // 5 Botones Vectoriales
          document.getElementById('btnDrawerCopyCode').onclick = () => {
            navigator.clipboard.writeText(token).then(() => showToast('¡Código copiado al portapapeles!', 'success'));
          };

          document.getElementById('btnDrawerDownloadQr').onclick = () => {
            const qrBox = document.getElementById('drawerQrContainer');
            const qrCanvas = qrBox?.querySelector('canvas') || qrBox?.querySelector('img');
            if (qrCanvas) {
              const a = document.createElement('a');
              a.download = `QR_${client.current_device_id}_N${selectedCode.nonce || 1}.png`;
              a.href = qrCanvas.toDataURL ? qrCanvas.toDataURL('image/png') : qrCanvas.src;
              a.click();
              showToast('QR descargado correctamente.', 'success');
            }
          };

          document.getElementById('btnDrawerDownloadCredential').onclick = () => {
            renderCredentialCanvas({
              token: selectedCode.token,
              plan: selectedCode.plan || client.license_type,
              device_id: selectedCode.device_id || client.current_device_id,
              days_added: selectedCode.days_added,
              expires_result: selectedCode.expires_at || client.license_expires,
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

          document.getElementById('btnDrawerAuditInspector').onclick = () => {
            auditTokenInInspector(token);
          };

          document.getElementById('btnDrawerSendWa').onclick = () => {
            openWhatsAppComposer(client.id, 'license');
          };
        };

        // Configurar selector histórico si hay más de 1
        if (codes.length > 1) {
          if (selectorContainer) selectorContainer.style.display = 'block';
          if (codeSelector) {
            codeSelector.innerHTML = '';
            codes.forEach((c, idx) => {
              const opt = document.createElement('option');
              opt.value = idx;
              const cDate = c.created_at ? c.created_at.substring(0, 10) : '';
              opt.textContent = `${c.plan || 'LICENCIA'} • Nonce #${c.nonce || 1} • ${cDate}`;
              if (idx === codes.length - 1) opt.selected = true;
              codeSelector.appendChild(opt);
            });
            codeSelector.onchange = () => {
              const selectedIdx = parseInt(codeSelector.value);
              if (codes[selectedIdx]) renderSelectedDrawerLicense(codes[selectedIdx]);
            };
          }
        } else {
          if (selectorContainer) selectorContainer.style.display = 'none';
        }

        // Renderizar la última licencia por defecto
        renderSelectedDrawerLicense(codes[codes.length - 1]);
      }

      // --- PESTAÑA 4: HARDWARE & MIGRACIONES ---
      const hwBody = document.getElementById('drawerHardwareBody');
      hwBody.innerHTML = '';
      const migrations = history.device_history || history.hardware || [];
      if (migrations && migrations.length > 0) {
        migrations.forEach(h => {
          const tr = document.createElement('tr');
          tr.innerHTML = `
            <td>${h.migrated_at ? h.migrated_at.substring(0, 10) : '-'}</td>
            <td><code style="font-family:var(--font-mono);">${escapeHtml(h.old_device_id)}</code></td>
            <td><strong style="font-family:var(--font-mono); color:var(--primary);">${escapeHtml(h.new_device_id)}</strong></td>
            <td>S/ ${(h.fee_amount || h.fee_charged || 0).toFixed(2)}</td>
            <td>${escapeHtml(h.reason || '-')}</td>
          `;
          hwBody.appendChild(tr);
        });
      } else {
        hwBody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:var(--text-muted); padding:1rem;">Sin migraciones registradas.</td></tr>';
      }
    }
  } catch (err) {
    console.error('Error loading history for drawer:', err);
  }

  document.getElementById('drawerClient360Backdrop')?.classList.add('open');
  document.getElementById('drawerClient360')?.classList.add('open');
}

function closeClient360Drawer() {
  document.getElementById('drawerClient360Backdrop')?.classList.remove('open');
  document.getElementById('drawerClient360')?.classList.remove('open');
  currentDrawerClientId = null;
}

/**
 * Eliminación segura con confirmación del cliente desde la Ficha 360°
 */
function deleteClientFromDrawer() {
  if (!currentDrawerClientId) return;
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
function openAddPaymentModal(clientId) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;
  document.getElementById('manualPayClientId').value = clientId;
  const payId = document.getElementById('manualPayId');
  if (payId) payId.value = '';
  const payTitle = document.getElementById('manualPayTitle');
  if (payTitle) payTitle.textContent = 'Registrar Pago Manual';
  const payDate = document.getElementById('manualPayDate');
  if (payDate) payDate.value = new Date().toISOString().substring(0, 10);
  document.getElementById('manualPayAmount').value = '35.00';
  document.getElementById('manualPayPlan').value = 'Renovación Mensual';
  document.getElementById('manualPayMethod').value = 'Yape';
  document.getElementById('manualPayRef').value = '';
  document.getElementById('manualPayNotes').value = '';
  openModal('modalManualPayment');
}

/**
 * Apertura de Modal para Editar Pago Registrado
 */
function openEditPaymentModal(clientId, payment) {
  document.getElementById('manualPayClientId').value = clientId;
  const payId = document.getElementById('manualPayId');
  if (payId) payId.value = payment.id || '';
  const payTitle = document.getElementById('manualPayTitle');
  if (payTitle) payTitle.textContent = 'Editar Pago Registrado';
  const payDate = document.getElementById('manualPayDate');
  if (payDate) payDate.value = payment.date ? payment.date.substring(0, 10) : new Date().toISOString().substring(0, 10);
  document.getElementById('manualPayAmount').value = payment.amount || 0;
  document.getElementById('manualPayPlan').value = payment.plan || '';
  document.getElementById('manualPayMethod').value = payment.method || 'Yape';
  document.getElementById('manualPayRef').value = payment.reference || '';
  document.getElementById('manualPayNotes').value = payment.notes || '';
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
  document.getElementById('syncRepDeviceId').value = (client.current_device_id && client.current_device_id !== 'PENDIENTE') ? client.current_device_id : '';
  document.getElementById('syncRepDeviceModel').value = client.device_model || '';
  document.getElementById('syncRepVersion').value = client.installed_version || '';
  document.getElementById('syncRepAiBalance').value = client.ai_reported_balance || 0;
  document.getElementById('syncRepTrialDays').value = (client.trial_days_remaining !== undefined && client.trial_days_remaining !== null) ? client.trial_days_remaining : '';
  document.getElementById('syncRepExpires').value = client.license_expires ? client.license_expires.substring(0, 10) : '';
  document.getElementById('syncRepNotes').value = '';
  openModal('modalSyncReported');
}

/**
 * Transferir token al Inspector Forense de inmediato
 */
function auditTokenInInspector(token) {
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

  const plan = (client.license_type || 'MENSUAL').toUpperCase();
  const status = (client.license_status || '').toUpperCase();
  const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
  const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const diffDays = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : 999;

  if (planBadgeEl) {
    if (isProspect) {
      planBadgeEl.className = 'badge badge-prospect';
      planBadgeEl.textContent = 'Prospecto';
    } else if (isPerp) {
      planBadgeEl.className = 'badge badge-purple';
      planBadgeEl.textContent = 'Perpetua';
    } else if (diffDays < 0) {
      planBadgeEl.className = 'badge badge-red';
      planBadgeEl.textContent = 'Vencida';
    } else if (diffDays <= 7) {
      planBadgeEl.className = 'badge badge-yellow';
      planBadgeEl.textContent = `Vence en ${diffDays}d`;
    } else {
      planBadgeEl.className = 'badge badge-green';
      planBadgeEl.textContent = 'Activa';
    }
  }

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

  const rawTpl = WA_TEMPLATES[tplKey].text;
  if (!rawTpl) {
    textarea.value = '';
    updateWaComposerStats();
    return;
  }

  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const diffDays = expDate ? Math.max(0, Math.ceil((expDate - now) / (1000 * 60 * 60 * 24))) : 0;
  const latestVer = getLatestPublishedVersion() || client.installed_version || '9.34.0';

  let rendered = rawTpl
    .replace(/\{negocio\}/g, client.business_name || 'su negocio')
    .replace(/\{titular\}/g, client.owner_name || 'Estimado cliente')
    .replace(/\{plan\}/g, formatPlanLabel(client.license_type))
    .replace(/\{dias_restantes\}/g, String(diffDays))
    .replace(/\{vencimiento\}/g, client.license_expires ? client.license_expires.substring(0, 10) : 'Activa')
    .replace(/\{device_id\}/g, client.current_device_id || 'PENDIENTE')
    .replace(/\{version\}/g, latestVer)
    .replace(/\{codigo_licencia\}/g, lastToken);

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

function initWaComposerEvents() {
  document.getElementById('waCompMessage')?.addEventListener('input', updateWaComposerStats);
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
    tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Sin transacciones registradas para este filtro.</td></tr>';
    return;
  }

  filtered.forEach(f => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${f.date ? f.date.substring(0, 10) : '-'}</td>
      <td><strong>${escapeHtml(f.client_id)}</strong></td>
      <td><strong>${escapeHtml(f.business_name)}</strong></td>
      <td>${escapeHtml(f.owner_name)}</td>
      <td><span class="badge badge-mono">${escapeHtml(f.plan)}</span></td>
      <td>${escapeHtml(f.method)}</td>
      <td>${escapeHtml(f.reference)}</td>
      <td><strong style="color:var(--success);">S/ ${(f.amount || 0).toFixed(2)}</strong></td>
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
      if (grpSubDate) grpSubDate.style.display = 'block';
      if (lblDevice) lblDevice.innerHTML = 'Hardware ID (Opcional — PENDIENTE):';
      if (reqDevice) reqDevice.style.display = 'none';
      if (inputDevice) {
        inputDevice.required = false;
        inputDevice.placeholder = 'PENDIENTE (Opcional)';
      }
      if (aiReported && !aiReported.dataset.manual) aiReported.value = 0;
    } else if (sit === 'TRIAL') {
      if (grpPlan) grpPlan.style.display = 'none';
      if (grpTrial) grpTrial.style.display = 'block';
      if (grpSubDate) grpSubDate.style.display = 'none';
      if (lblDevice) lblDevice.innerHTML = 'Hardware ID del Celular (ML-XXXX): <span class="required-star">*</span>';
      if (reqDevice) reqDevice.style.display = 'inline';
      if (inputDevice) {
        inputDevice.required = true;
        inputDevice.placeholder = 'Ej: ML-9K4B';
      }
      if (aiReported && !aiReported.dataset.manual) aiReported.value = 50;
    } else { // COMMERCIAL
      if (grpPlan) grpPlan.style.display = 'block';
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

  document.getElementById('btnOpenCreateClient')?.addEventListener('click', () => {
    document.getElementById('formCreateClient')?.reset();
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
    document.getElementById('manualPayClientId').value = currentHistoryClientId;
    document.getElementById('manualPayAmount').value = '35.00';
    document.getElementById('manualPayPlan').value = 'Renovación Mensual';
    openModal('modalManualPayment');
  });

  document.getElementById('btnSubmitManualPayment')?.addEventListener('click', async () => {
    const clientId = document.getElementById('manualPayClientId').value;
    const paymentId = document.getElementById('manualPayId')?.value?.trim();
    const amount = parseFloat(document.getElementById('manualPayAmount').value) || 0;
    const plan = document.getElementById('manualPayPlan').value.trim();
    const method = document.getElementById('manualPayMethod').value;
    const ref = document.getElementById('manualPayRef').value.trim();
    const notes = document.getElementById('manualPayNotes').value.trim();
    const date = document.getElementById('manualPayDate')?.value || new Date().toISOString().substring(0, 10);

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

      closeModal('modalManualPayment');
      showToast(paymentId ? 'Pago actualizado con éxito.' : 'Pago manual registrado con éxito.', 'success');
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
  const installedVer = document.getElementById('newInstalledVersion').value.trim() || '9.34.0';
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
        license_type: plan,
        license_status: situation === 'PROSPECTO' ? 'PROSPECTO' : (plan.includes('PERPETU') ? 'PERPETUA' : 'ACTIVA'),
        installed_version: installedVer,
        ai_reported_balance: aiReported,
        ai_pending_bonus: aiBonus,
        ai_extra_credits: aiBonus,
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
      selectClientForLicense(createdClient.id);
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
  const fee = parseFloat(document.getElementById('migFee').value) || 0;
  const method = document.getElementById('migPaymentMethod').value;
  const reason = document.getElementById('migReason').value.trim();
  const emitImmediately = document.getElementById('migEmitImmediately')?.checked ?? true;

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
        fee_amount: fee,
        payment_method: method,
        reason: reason,
        emit_immediately: emitImmediately,
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
      if (successBox) successBox.style.display = 'flex';

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
  document.getElementById('migOldDeviceId').value = client.current_device_id;
  document.getElementById('migNewDeviceId').value = '';
  const migDefault = (ownerConfig?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
    ? ownerConfig.catalog.HARDWARE_MIGRATION_FEE.price
    : (ownerConfig?.migration_fee || 40.0);
  document.getElementById('migFee').value = Number(migDefault).toFixed(2);
  document.getElementById('migReason').value = '';
  document.getElementById('migPaymentMethod').value = 'Yape';

  const emitCb = document.getElementById('migEmitImmediately');
  if (emitCb) emitCb.checked = true;

  const form = document.getElementById('formMigrateDevice');
  if (form) form.style.display = 'flex';

  const successBox = document.getElementById('migSuccessInline');
  if (successBox) successBox.style.display = 'none';

  const qrBox = document.getElementById('migSuccessQrContainer');
  if (qrBox) qrBox.innerHTML = '';

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
  document.getElementById(id)?.classList.add('open');
}

function closeModal(id) {
  document.getElementById(id)?.classList.remove('open');
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
          version: '9.34.0',
          version_actual: '9.32.0',
          device_id: 'ML-9K4B',
          changelog: 'Mejoras en el escáner IA y velocidad.',
          link_descarga: 'http://localhost:8080/api/releases/download/9.34.0',
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
