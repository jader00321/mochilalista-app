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
  await loadClients();
  await loadDashboard();
  await loadReleases();
  await loadReleaseMatrix();
  initLicenseStudioEvents();
  initModalEvents();
  initWaComposerEvents();
  initInspectorEvents();
  initClientSyncEvents();
  initReleaseUploadAndAutoDetect();
  initFinancesAndBackupsEvents();
});

// =================== SISTEMA DE NOTIFICACIONES TOAST ===================
function showToast(message, type = 'info', durationOrOptions = 3500) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  let duration = 3500;
  let actionLabel = null;
  let onAction = null;

  if (typeof durationOrOptions === 'number') {
    duration = durationOrOptions;
  } else if (durationOrOptions && typeof durationOrOptions === 'object') {
    if (typeof durationOrOptions.duration === 'number') {
      duration = durationOrOptions.duration;
    }
    if (durationOrOptions.actionLabel) {
      actionLabel = String(durationOrOptions.actionLabel);
    }
    if (typeof durationOrOptions.onAction === 'function') {
      onAction = durationOrOptions.onAction;
    }
    if (actionLabel && typeof durationOrOptions.duration !== 'number') {
      duration = 7500;
    }
  }

  const toast = document.createElement('div');
  toast.className = `toast ${type} toast-${type}`;

  let iconSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>';
  if (type === 'success') {
    iconSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>';
  } else if (type === 'error') {
    iconSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>';
  } else if (type === 'warning') {
    iconSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>';
  }

  const iconSpan = document.createElement('span');
  iconSpan.className = 'toast-icon';
  iconSpan.innerHTML = iconSvg;

  const contentDiv = document.createElement('div');
  contentDiv.className = 'toast-content';
  contentDiv.textContent = message == null ? '' : String(message);

  toast.appendChild(iconSpan);
  toast.appendChild(contentDiv);

  let dismissTimer = null;
  let removed = false;
  const removeToast = () => {
    if (removed) return;
    removed = true;
    if (dismissTimer) clearTimeout(dismissTimer);
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    toast.style.transition = 'all 0.25s ease';
    setTimeout(() => toast.remove(), 260);
  };

  if (actionLabel && onAction) {
    let actionRan = false;
    const actionBtn = document.createElement('button');
    actionBtn.type = 'button';
    actionBtn.className = 'toast-action-btn';
    actionBtn.textContent = actionLabel;
    actionBtn.addEventListener('click', async () => {
      if (actionRan) return;
      actionRan = true;
      actionBtn.disabled = true;
      try {
        await onAction();
      } finally {
        removeToast();
      }
    });
    toast.appendChild(actionBtn);
  }

  const closeBtn = document.createElement('button');
  closeBtn.type = 'button';
  closeBtn.className = 'toast-close';
  closeBtn.title = 'Cerrar';
  closeBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
  closeBtn.addEventListener('click', removeToast);
  toast.appendChild(closeBtn);

  container.appendChild(toast);

  dismissTimer = setTimeout(removeToast, duration);
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

// =================== DETECCIÓN DE ENTORNO NATIVO / ESCRITORIO ===================
/**
 * Detecta si la interfaz se está ejecutando en Modo Aplicación de Escritorio
 * (parámetro ?mode=app o modo standalone / minimal-ui de PWA/Chrome App).
 */
function isDesktopAppMode() {
  const params = new URLSearchParams(window.location.search);
  if (params.get('mode') === 'app') return true;
  if (window.matchMedia) {
    if (window.matchMedia('(display-mode: standalone)').matches) return true;
    if (window.matchMedia('(display-mode: minimal-ui)').matches) return true;
  }
  return false;
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

  // 5. Botón Discreto "Abrir en Chrome" en Sidebar Footer (Plan Maestro 18 - Fase 1 / Plan 18.5)
  const btnOpenChrome = document.getElementById('btnOpenInChrome');
  if (btnOpenChrome) {
    // Visibilidad contextual: visible únicamente en modo app de escritorio (?mode=app o standalone)
    btnOpenChrome.style.display = isDesktopAppMode() ? 'flex' : 'none';

    btnOpenChrome.addEventListener('mouseenter', () => {
      if (!sidebar?.classList.contains('collapsed') || !floatingTooltip) return;
      floatingTooltip.textContent = 'Abrir en Google Chrome';
      const rect = btnOpenChrome.getBoundingClientRect();
      const top = rect.top + (rect.height / 2) - 14;
      const left = rect.right + 10;
      floatingTooltip.style.top = `${Math.max(8, top)}px`;
      floatingTooltip.style.left = `${left}px`;
      floatingTooltip.classList.add('visible');
    });

    btnOpenChrome.addEventListener('mouseleave', () => {
      if (floatingTooltip) floatingTooltip.classList.remove('visible');
    });

    btnOpenChrome.addEventListener('click', async () => {
      try {
        const res = await fetch('/api/system/open-browser', { method: 'POST' });
        if (!res.ok) {
          throw new Error('Servidor no pudo lanzar navegador');
        }
        showToast('Abriendo MochilaLista Admin en Google Chrome...', 'success');
      } catch (err) {
        window.open('http://localhost:8080', '_blank');
        showToast('Abriendo pestaña en navegador...', 'info');
      }
    });
  }

  // 6. Botón Discreto "Apagar Servidor" en Sidebar Footer (Plan Maestro 15 - Fase 7)
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

  // 7. Acciones Pendientes en Dashboard hacia Cartera CRM (Plan Maestro 18 - Fase 3)
  const dashFollowupItem = document.getElementById('dashFollowupAlertItem');
  if (dashFollowupItem) {
    dashFollowupItem.addEventListener('click', () => {
      const clientTab = document.querySelector('.nav-tab[data-tab="tabClients"]');
      if (clientTab) clientTab.click();
      const chip = document.getElementById('chipFilterFollowupDue');
      if (chip) chip.click();
    });
  }

  const dashBonusItem = document.getElementById('dashBonusAlertItem');
  if (dashBonusItem) {
    dashBonusItem.addEventListener('click', () => {
      const clientTab = document.querySelector('.nav-tab[data-tab="tabClients"]');
      if (clientTab) clientTab.click();
      const chip = document.getElementById('chipFilterPendingBonus');
      if (chip) chip.click();
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
          await loadClients();
          await loadDashboard();
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
    // Cargar releases y clientes primero para sincronización inmediata de semver, contadores CRM y dona del Dashboard
    await loadReleases();
    await loadClients();
    await loadDashboard();
    await Promise.allSettled([
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
          <td><span class="badge badge-yellow" style="display:inline-flex; align-items:center; gap:4px;"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg> ${action.days_left} día(s)</span></td>
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

    // Acciones pendientes CRM (Plan Maestro 18 - Fase 3): Seguimientos pendientes y Bonos IA por emitir
    const todayStr = getLocalIsoDate();
    let countFollowupDue = 0;
    let countPendingBonus = 0;
    if (globalClients && globalClients.length > 0) {
      globalClients.forEach(c => {
        if (c.next_followup_date && c.next_followup_date <= todayStr) countFollowupDue++;
        if ((c.ai_pending_bonus || 0) > 0) countPendingBonus++;
      });
    }

    const alertBanner = document.getElementById('dashPendingActionsAlert');
    const followupItem = document.getElementById('dashFollowupAlertItem');
    const bonusItem = document.getElementById('dashBonusAlertItem');
    const followupCountEl = document.getElementById('dashFollowupAlertCount');
    const bonusCountEl = document.getElementById('dashBonusAlertCount');

    if (alertBanner) {
      if (countFollowupDue > 0 || countPendingBonus > 0) {
        alertBanner.style.display = 'block';
        if (followupItem) {
          followupItem.style.display = countFollowupDue > 0 ? 'inline-flex' : 'none';
          if (followupCountEl) followupCountEl.textContent = countFollowupDue;
        }
        if (bonusItem) {
          bonusItem.style.display = countPendingBonus > 0 ? 'inline-flex' : 'none';
          if (bonusCountEl) bonusCountEl.textContent = countPendingBonus;
        }
      } else {
        alertBanner.style.display = 'none';
      }
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
    if (typeof renderPlanDistributionChart === 'function') {
      renderPlanDistributionChart(globalClients);
    }
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

// =================== HELPERS COMERCIALES & FORMATO (FASE 3) ===================
function getLocalIsoDate(d = new Date()) {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatPeruvianPhoneDisplay(phone) {
  if (!phone) return '-';
  const raw = String(phone).trim();
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 9) {
    return `+51${digits}`;
  }
  if (digits.length === 11 && digits.startsWith('51')) {
    return `+${digits}`;
  }
  return raw.startsWith('+') ? raw : (digits ? `+${digits}` : raw);
}

function formatPlanHumanLabel(planCode) {
  if (!planCode) return '-';
  const p = String(planCode).toUpperCase().trim();
  switch (p) {
    case 'MENSUAL': return 'Plan Mensual';
    case 'TRIMESTRAL': return 'Plan Trimestral';
    case 'SEMESTRAL': return 'Plan Semestral';
    case 'ANUAL': return 'Plan Anual';
    case 'PERPETUO_LIBERADO':
    case 'PERPETUO': return 'Licencia Perpetua';
    case 'TRIAL':
    case 'TRIAL_GRATUITO': return 'Trial Gratuito';
    case 'EXTENSION_CORTESIA': return 'Extensión Cortesía';
    case 'PASE_ACTUALIZACION_ANUAL': return 'Pase Actualización Anual';
    case 'RECARGA_IA_150': return 'Recarga IA 150';
    case 'BONO_IA_PERSONALIZADO': return 'Recarga IA Personalizada';
    case 'SERVICIO_MIGRACION': return 'Servicio de Migración';
    case 'ABONO_PARCIAL': return 'Abono Parcial';
    case 'PROSPECTO': return 'Prospecto Comercial';
    default:
      return p.replace(/_/g, ' ');
  }
}

/**
 * Normaliza cualquier denominación de plan (canónica o legada) a su slug oficial.
 * Retorna null si es un concepto personalizado no catalogado.
 */
function normalizePlanToSlug(rawPlan) {
  if (!rawPlan) return null;
  const p = String(rawPlan).trim().toUpperCase();

  // Coincidencias directas con slugs canónicos
  if (p === 'MENSUAL') return 'MENSUAL';
  if (p === 'TRIMESTRAL') return 'TRIMESTRAL';
  if (p === 'SEMESTRAL') return 'SEMESTRAL';
  if (p === 'ANUAL') return 'ANUAL';
  if (p === 'PERPETUO_LIBERADO' || p === 'PERPETUO') return 'PERPETUO_LIBERADO';
  if (p === 'PASE_ACTUALIZACION_ANUAL') return 'PASE_ACTUALIZACION_ANUAL';
  if (p === 'RECARGA_IA_150') return 'RECARGA_IA_150';
  if (p === 'BONO_IA_PERSONALIZADO') return 'BONO_IA_PERSONALIZADO';
  if (p === 'SERVICIO_MIGRACION') return 'SERVICIO_MIGRACION';
  if (p === 'EXTENSION_CORTESIA') return 'EXTENSION_CORTESIA';
  if (p === 'ABONO_PARCIAL') return 'ABONO_PARCIAL';

  // Normalización defensiva para textos descriptivos legados
  if (p.includes('MENSUAL')) return 'MENSUAL';
  if (p.includes('TRIMESTRAL')) return 'TRIMESTRAL';
  if (p.includes('SEMESTRAL')) return 'SEMESTRAL';
  if (p.includes('ANUAL') && !p.includes('UPDATE') && !p.includes('ACTUALIZAC')) return 'ANUAL';
  if (p.includes('PERPETU')) return 'PERPETUO_LIBERADO';
  if (p.includes('PASE') || (p.includes('UPDATE') && p.includes('ANUAL')) || p.includes('ACTUALIZACION')) return 'PASE_ACTUALIZACION_ANUAL';
  if (p.includes('150') || p.includes('BOLSA EXTRA IA') || p.includes('RECARGA EXTRA IA') || p.includes('RECARGA IA 150')) return 'RECARGA_IA_150';
  if (p.includes('BONO IA') || p.includes('RECARGA IA PERSONALIZADA')) return 'BONO_IA_PERSONALIZADO';
  if (p.includes('MIGRAC') || p.includes('SERVICIO TÉCNICO') || p.includes('SERVICIO TECNICO')) return 'SERVICIO_MIGRACION';
  if (p.includes('CORTES') || p.includes('EXTENSION') || p.includes('EXTENSIÓN')) return 'EXTENSION_CORTESIA';
  if (p.includes('ABONO') || p.includes('PARCIAL') || p.includes('A CUENTA')) return 'ABONO_PARCIAL';

  return null;
}

function updateFilterCounts() {
  const now = new Date();
  const todayStr = getLocalIsoDate(now);
  let countActive = 0;
  let countExpiring = 0;
  let countExpired = 0;
  let countPerpetual = 0;
  let countProspect = 0;
  let countOutdated = 0;
  let countTrial = 0;
  let countPendingBonus = 0;
  let countFollowupDue = 0;

  const latestVer = getLatestPublishedVersion();

  globalClients.forEach(c => {
    const plan = (c.license_type || 'MENSUAL').toUpperCase();
    const status = (c.license_status || '').toUpperCase();
    const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
    const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
    const isTrial = plan === 'TRIAL' || status === 'TRIAL' || plan === 'TRIAL_GRATUITO';
    const expDate = c.license_expires ? new Date(c.license_expires) : null;

    if (isTrial) {
      countTrial++;
    }

    if ((c.ai_pending_bonus || 0) > 0) {
      countPendingBonus++;
    }

    if (c.next_followup_date && c.next_followup_date <= todayStr) {
      countFollowupDue++;
    }

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
  setTxt('countTrial', countTrial);
  setTxt('countPendingBonus', countPendingBonus);
  setTxt('countFollowupDue', countFollowupDue);

  const chipBonus = document.getElementById('chipFilterPendingBonus');
  if (chipBonus) {
    if (countPendingBonus > 0) {
      chipBonus.classList.add('accent-pending');
    } else {
      chipBonus.classList.remove('accent-pending');
    }
  }
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
  const todayStr = getLocalIsoDate(now);
  const latestVer = getLatestPublishedVersion();

  const filtered = globalClients.filter(c => {
    // 1. Filtro por chip de estado
    if (currentClientFilter !== 'all') {
      const plan = (c.license_type || 'MENSUAL').toUpperCase();
      const status = (c.license_status || '').toUpperCase();
      const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
      const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
      const isTrial = plan === 'TRIAL' || status === 'TRIAL' || plan === 'TRIAL_GRATUITO';
      const expDate = c.license_expires ? new Date(c.license_expires) : null;
      const diffDays = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : 999;

      if (currentClientFilter === 'prospect' && !isProspect) return false;
      if (currentClientFilter === 'active' && (isProspect || !(isPerp || diffDays >= 0))) return false;
      if (currentClientFilter === 'expiring' && (isProspect || !(!isPerp && diffDays >= 0 && diffDays <= 7))) return false;
      if (currentClientFilter === 'expired' && (isProspect || !(!isPerp && diffDays < 0))) return false;
      if (currentClientFilter === 'perpetual' && (isProspect || !isPerp)) return false;
      if (currentClientFilter === 'trial' && !isTrial) return false;
      if (currentClientFilter === 'pending_bonus' && (!c.ai_pending_bonus || c.ai_pending_bonus <= 0)) return false;
      if (currentClientFilter === 'followup_due' && (!c.next_followup_date || c.next_followup_date > todayStr)) return false;
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
        c.next_followup_date,
      ].filter(Boolean).join(' ').toLowerCase();

      if (!matchText.includes(currentSearchQuery)) {
        return false;
      }
    }

    return true;
  });

  // Si se filtra por seguimientos pendientes, ordenar por fecha más vencida primero (ascendente)
  if (currentClientFilter === 'followup_due') {
    filtered.sort((a, b) => (a.next_followup_date || '').localeCompare(b.next_followup_date || ''));
  }

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

    // Homogeneización 1:1 de Créditos IA (Plan Maestro 18 - Fase 3)
    const displayAi = (c.ai_reported_balance !== undefined && c.ai_reported_balance !== null)
      ? c.ai_reported_balance
      : (c.ai_accumulated_credits ?? c.ai_extra_credits ?? 0);
    const hasAiCredits = displayAi > 0;
    const aiMarkup = hasAiCredits
      ? `<span class="badge badge-purple">${displayAi} IA</span>`
      : '<span class="badge badge-outline" style="color:var(--text-muted); border:1px solid var(--border-color);">0 IA</span>';

    const pendingBonusBadge = (c.ai_pending_bonus && c.ai_pending_bonus > 0)
      ? `<div class="badge-pending-bonus" title="Bono acordado pendiente de emitir en token Ed25519">+${c.ai_pending_bonus} pend.</div>`
      : '';

    // Seguimiento en columna Negocio & Titular
    let followupBadge = '';
    if (c.next_followup_date) {
      if (c.next_followup_date < todayStr) {
        followupBadge = `<div style="margin-top:3px;"><span class="badge badge-red badge-xs" style="font-size:0.7rem; padding:1px 6px;" title="Seguimiento comercial vencido">Seg. Vencido: ${escapeHtml(c.next_followup_date)}</span></div>`;
      } else if (c.next_followup_date === todayStr) {
        followupBadge = `<div style="margin-top:3px;"><span class="badge badge-yellow badge-xs" style="font-size:0.7rem; padding:1px 6px;" title="Seguimiento programado para hoy">Seg. Hoy</span></div>`;
      } else {
        followupBadge = `<div style="margin-top:3px;"><span class="badge badge-outline badge-xs" style="font-size:0.7rem; padding:1px 6px; color:var(--text-muted); border-color:var(--border-color);" title="Próximo seguimiento">Seg: ${escapeHtml(c.next_followup_date)}</span></div>`;
      }
    }

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
        ${followupBadge}
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
        ${aiMarkup}
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

let currentSelectedGeneratorCode = null;

const GEN_SVGS = {
  lightbulb: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/></svg>`,
  calendar: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>`,
  bolt: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>`,
  lock: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`,
  coin: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>`,
  gear: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>`,
  star: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`,
  refresh: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>`,
  clock: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`
};

function decodeMl9TokenPayload(token) {
  if (!token || typeof token !== 'string') return null;
  const trimmed = token.trim();
  let b64Part = '';
  if (trimmed.startsWith('ML9-')) {
    const parts = trimmed.substring(4).split('.');
    b64Part = parts[0] || '';
  } else if (trimmed.includes('.')) {
    b64Part = trimmed.split('.')[0] || '';
  } else {
    b64Part = trimmed;
  }
  if (!b64Part) return null;
  try {
    let base64 = b64Part.replace(/-/g, '+').replace(/_/g, '/');
    while (base64.length % 4 !== 0) {
      base64 += '=';
    }
    const decodedStr = atob(base64);
    return JSON.parse(decodedStr);
  } catch (e) {
    return null;
  }
}

function resetCustomSettings() {
  const customDays = document.getElementById('licCustomDays');
  const customAi = document.getElementById('licCustomAiBonus');
  const customDate = document.getElementById('licCustomExactDate');
  const chkCustom = document.getElementById('chkEnableCustomSettings');
  const customContent = document.getElementById('licCustomContent');
  const accordionArrow = document.getElementById('accordionArrow');
  if (customDays) customDays.value = '';
  if (customAi) customAi.value = '0';
  if (customDate) customDate.value = '';
  if (chkCustom) chkCustom.checked = false;
  if (customContent) customContent.classList.remove('open');
  if (accordionArrow) accordionArrow.textContent = '▼';
}

function buildGeneratorWhatsAppMessage(code, client) {
  const token = code?.token || '';
  const plan = code?.plan || client?.license_type || 'MENSUAL';
  const titular = client?.owner_name || 'Comerciante';
  const negocio = client?.business_name || 'su negocio';
  const deviceId = code?.device_id || client?.current_device_id || 'ML-0000';
  const aiVal = (code?.ai_credits !== undefined && code?.ai_credits !== null) ? code.ai_credits : (code?.ai_extra_credits ?? 0);
  const expires = (plan === 'PERPETUO_LIBERADO') ? 'Vitalicia' : (code?.expires_at ? code.expires_at.substring(0, 10) : (client?.license_expires ? client.license_expires.substring(0, 10) : 'Activa'));
  const version = client?.installed_version ? `v${client.installed_version}` : 'v9.35.0';

  if (plan === 'BONO_IA_PERSONALIZADO' || plan === 'RECARGA_IA_150') {
    return `¡Hola, ${titular}! 👋 Te saludamos de MochilaLista.\nTu recarga de escaneos de Inteligencia Artificial para *${negocio}* ha sido acreditada con éxito.\n\n⚡ Detalle de la Recarga:\n• Créditos IA Otorgados: +${aiVal} escaneos vitalicios\n• Hardware ID Vinculado: \`${deviceId}\`\n\n🔑 Token de Activación IA:\n\`${token}\`\n\nPuedes ingresar este token o escanear el QR en tu app para sumarlos inmediatamente a tu saldo disponible. ¡A seguir potenciando tu negocio! 🚀`;
  } else if (plan === 'EXTENSION_CORTESIA') {
    return `Estimado(a) ${titular}, te saludamos de MochilaLista.\nTe confirmamos la habilitación de una extensión de cortesía para tu sistema en *${negocio}*.\n\n📌 Nueva vigencia temporal: *${expires}*\n• Hardware ID: \`${deviceId}\`\n\n🔑 Código de Activación:\n\`${token}\`\n\nIngresa este código o escanea el QR en tu aplicación para continuar operando sin interrupciones. ¡Quedamos a tu servicio! 🎒✅`;
  } else {
    return `¡Excelente noticia, ${titular}!\nTu licencia oficial de MochilaLista para el negocio *${negocio}* ha sido generada exitosamente.\n\n📌 Detalles de la Licencia:\n• Plan: ${plan.replace(/_/g, ' ')}\n• Hardware ID: \`${deviceId}\`\n• Vigencia: ${expires}\n• Versión: ${version}\n\n🔑 Código de Activación:\n\`${token}\`\n\nPuedes ingresar este código o escanear el QR desde la pantalla de activación de tu aplicación móvil. ¡Gracias por confiar en MochilaLista! 🎒✅`;
  }
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

    resetCustomSettings();

    // Si el cliente tiene bono IA acordado pendiente de emitir o se solicitó preferBonus
    if (client && (client.ai_pending_bonus || 0) > 0) {
      const planSel = document.getElementById('licPlanSelect');
      if (planSel) planSel.value = 'BONO_IA_PERSONALIZADO';
      const aiInput = document.getElementById('licCustomAiAmount');
      if (aiInput) aiInput.value = client.ai_pending_bonus;
      updateEcoModeUI('free');
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
    resetCustomSettings();
    updateLiveLicenseProjection();
  });

  clientSelect?.addEventListener('change', () => {
    resetCustomSettings();
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

  // Checkbox de habilitación explícita de ajustes personalizados
  document.getElementById('chkEnableCustomSettings')?.addEventListener('change', (e) => {
    if (e.target.checked) {
      if (customContent) customContent.classList.add('open');
      if (accordionArrow) accordionArrow.textContent = '▲';
    }
    updateLiveLicenseProjection();
  });

  // Botón para restablecer ajustes personalizados a los valores originales del plan
  document.getElementById('btnResetCustomSettings')?.addEventListener('click', () => {
    resetCustomSettings();
    updateLiveLicenseProjection();
    showToast('Ajustes comerciales personalizados restablecidos.', 'info');
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

  // Botón de emisión (Interceptado con Modal de Confirmación Pre-Emisión - Fase 2 Plan 18.5)
  document.getElementById('btnGenerateLicense')?.addEventListener('click', openConfirmEmissionModal);
  document.getElementById('btnExecuteConfirmEmission')?.addEventListener('click', executeConfirmedEmission);

  // Botones de acción sobre la licencia emitida / activa
  document.getElementById('btnCopyCode')?.addEventListener('click', () => {
    const code = document.getElementById('generatedCodeDisplay')?.textContent?.trim();
    if (!code) return;
    navigator.clipboard.writeText(code).then(() => {
      showToast('¡Código copiado al portapapeles!', 'success');
    });
  });

  document.getElementById('btnGenCopyMessageAndCode')?.addEventListener('click', () => {
    const clientId = document.getElementById('licClientSelect')?.value;
    const client = globalClients.find(c => c.id === clientId);
    if (!currentSelectedGeneratorCode || !client) {
      showToast('No hay una licencia activa seleccionada para copiar.', 'warning');
      return;
    }
    const msg = buildGeneratorWhatsAppMessage(currentSelectedGeneratorCode, client);
    navigator.clipboard.writeText(msg).then(() => {
      showToast('¡Mensaje contextual y código copiados para WhatsApp!', 'success');
    });
  });

  document.getElementById('btnDownloadQr')?.addEventListener('click', downloadQrCode);
  document.getElementById('btnDownloadCredential')?.addEventListener('click', downloadCredential);
  document.getElementById('btnCopyCredentialImage')?.addEventListener('click', copyCredentialToClipboard);

  document.getElementById('btnSendWa')?.addEventListener('click', () => {
    const clientId = document.getElementById('licClientSelect')?.value;
    const client = globalClients.find(c => c.id === clientId);
    if (!client || !currentSelectedGeneratorCode) {
      showToast('No hay una licencia activa seleccionada para enviar.', 'warning');
      return;
    }
    const plan = currentSelectedGeneratorCode.plan || client.license_type;
    let tpl = 'license';
    if (plan === 'BONO_IA_PERSONALIZADO' || plan === 'RECARGA_IA_150') {
      tpl = 'ai_bonus';
    } else if (plan === 'EXTENSION_CORTESIA') {
      tpl = 'courtesy_extension';
    }
    if (typeof openWhatsAppComposer === 'function') {
      openWhatsAppComposer(client.id, tpl, {
        token: currentSelectedGeneratorCode.token,
        aiCredits: (currentSelectedGeneratorCode.ai_credits ?? currentSelectedGeneratorCode.ai_extra_credits ?? 0),
        diasExtension: currentSelectedGeneratorCode.days || 7,
      });
    }
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
    if (grpAmount) grpAmount.style.display = 'none';
    if (grpMethod) grpMethod.style.display = 'none';
    if (grpRef) grpRef.style.display = 'none';
    if (boxSuggested) boxSuggested.style.display = 'none';
  } else {
    if (grpAmount) { grpAmount.style.display = ''; grpAmount.style.opacity = '1'; }
    if (grpMethod) { grpMethod.style.display = ''; grpMethod.style.opacity = '1'; }
    if (grpRef) { grpRef.style.display = ''; grpRef.style.opacity = '1'; }
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
  const nextNonce = client.next_nonce || 1;
  document.getElementById('sumPlanNonce').textContent = `${(client.license_type || 'MENSUAL').replace(/_/g, ' ')} (Próximo Nonce: #${nextNonce})`;

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

  // Anti-doble bono: Ocultar y forzar a 0 el bono de regalo si el plan es Bono IA Personalizado
  const grpLicCustomAiBonus = document.getElementById('grpLicCustomAiBonus');
  if (plan === 'BONO_IA_PERSONALIZADO') {
    if (grpLicCustomAiBonus) grpLicCustomAiBonus.style.display = 'none';
    const customAiInput = document.getElementById('licCustomAiBonus');
    if (customAiInput) customAiInput.value = '0';
  } else {
    if (grpLicCustomAiBonus) grpLicCustomAiBonus.style.display = '';
  }

  // Mostrar / Ocultar panel interactivo de Bono IA Personalizado
  if (plan === 'BONO_IA_PERSONALIZADO') {
    if (panelCustomAi) panelCustomAi.style.display = 'block';
  } else {
    if (panelCustomAi) panelCustomAi.style.display = 'none';
  }

  const selectedOpt = planSelect.options[planSelect.selectedIndex];
  const cfgPlan = ownerConfig?.catalog?.[plan];

  const grpAmount = document.getElementById('grpLicPaymentAmount');
  const grpMethod = document.getElementById('grpLicPaymentMethod');
  const grpRef = document.getElementById('grpLicPaymentRef');

  if (plan === 'EXTENSION_CORTESIA') {
    if (grpAmount) grpAmount.style.display = 'none';
    if (grpMethod) grpMethod.style.display = 'none';
    if (grpRef) grpRef.style.display = 'none';
    if (amountInput) amountInput.value = '0.00';
  } else if (plan === 'BONO_IA_PERSONALIZADO') {
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    if (isFree) {
      if (amountInput) amountInput.value = '0.00';
      if (grpAmount) grpAmount.style.display = 'none';
      if (grpMethod) grpMethod.style.display = 'none';
      if (grpRef) grpRef.style.display = 'none';
    } else {
      if (grpAmount) { grpAmount.style.display = ''; grpAmount.style.opacity = '1'; }
      if (grpMethod) { grpMethod.style.display = ''; grpMethod.style.opacity = '1'; }
      if (grpRef) { grpRef.style.display = ''; grpRef.style.opacity = '1'; }
    }
  } else {
    const defaultPrice = (cfgPlan?.price !== undefined) ? cfgPlan.price.toFixed(2) : (selectedOpt?.getAttribute('data-price') || '35.00');
    if (amountInput && document.activeElement !== amountInput) {
      amountInput.value = defaultPrice;
    }
    if (grpAmount) { grpAmount.style.display = ''; grpAmount.style.opacity = '1'; }
    if (grpMethod) { grpMethod.style.display = ''; grpMethod.style.opacity = '1'; }
    if (grpRef) { grpRef.style.display = ''; grpRef.style.opacity = '1'; }
  }

  impactBadge.style.display = 'block';
  projectionText.style.display = 'block';
  impactBadge.className = 'plan-impact-badge';

  const now = new Date();
  let baseDate = now;

  // Leer ajustes personalizados estrictamente si el switch está activado y el plan no es Bono IA
  const isCustomEnabled = (document.getElementById('chkEnableCustomSettings')?.checked === true) && (plan !== 'BONO_IA_PERSONALIZADO');
  const customMode = document.getElementById('licCustomComputationMode')?.value || 'cumulative';
  const customDaysVal = isCustomEnabled ? (parseInt(document.getElementById('licCustomDays')?.value) || 0) : 0;
  const customAiBonus = isCustomEnabled ? (parseInt(document.getElementById('licCustomAiBonus')?.value) || 0) : 0;

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
  const nextNonce = client?.next_nonce || 1;
  const lastNonce = nextNonce > 1 ? nextNonce - 1 : 0;
  const nonceHtml = `<div>${GEN_SVGS.lock} <strong>Nonce Criptográfico:</strong> Último Nonce Emitido (#${lastNonce > 0 ? lastNonce : 'Ninguno'}) → <strong>Próximo Nonce a Firmar (#${nextNonce})</strong>.</div>`;

  // 1. Proyección de Bono IA Personalizado (0 días)
  if (plan === 'BONO_IA_PERSONALIZADO') {
    impactBadge.classList.add('recharge');
    const customScans = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    const paymentAmt = parseFloat(amountInput?.value) || 0;
    const paymentMth = document.getElementById('licPaymentMethod')?.value || 'Yape';

    impactBadge.innerHTML = `${GEN_SVGS.lightbulb} <strong>Bono / Recarga IA Personalizada:</strong> Otorga <strong>+${customScans} créditos de escaneos IA</strong> vitalicios directos al celular sin alterar días ni suscripción.`;

    const clientExpStr = client?.license_expires ? client.license_expires.substring(0, 10) : 'Sin fecha';
    const isTrial = client?.license_type === 'TRIAL' || client?.trial_days_remaining !== null;
    const trialDays = client?.trial_days_remaining ?? '-';
    const vigenciaTxt = isTrial ? `Trial (${trialDays}d restantes)` : clientExpStr;

    const projectedAi = currentAi + customScans;
    const financeTxt = isFree
      ? 'Cortesía / Sin costo (S/ 0.00) — No afectará ingresos contables'
      : `Cobro acordado: S/ ${paymentAmt.toFixed(2)} vía ${escapeHtml(paymentMth)}`;

    projectionText.innerHTML = `
      <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Vigencia:</strong> Mantiene fecha actual (${vigenciaTxt}) (Sin cambios de días).</div>
      <div style="margin-bottom:0.35rem;">${GEN_SVGS.bolt} <strong>Créditos IA:</strong> Saldo celular (${currentAi} IA) + Esta emisión (+${customScans} IA) = <strong>Total proyectado (${projectedAi} IA)</strong>.</div>
      <div style="margin-bottom:0.35rem;">${nonceHtml}</div>
      <div style="font-size:0.82rem; color:var(--text-secondary);">${GEN_SVGS.coin} <strong>Impacto Financiero:</strong> ${financeTxt}.</div>
    `;
    return;
  }

  // 2. Si hay días personalizados configurados en el acordeón
  if (customDaysVal > 0) {
    impactBadge.innerHTML = `${GEN_SVGS.gear} <strong>Ajuste Personalizado:</strong> Se otorgarán <strong>+${customDaysVal} días</strong> directos (${customMode === 'from_today' ? 'contando desde hoy' : 'acumulativos'})` +
      (customAiBonus > 0 ? ` + <strong>${customAiBonus} escaneos IA de regalo</strong>.` : '.');
    const projCustom = new Date(baseDate.getTime() + customDaysVal * 24 * 60 * 60 * 1000);
    const projAi = currentAi + customAiBonus;
    projectionText.innerHTML = `
      <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projCustom)}.</div>
      ${customAiBonus > 0 ? `<div style="margin-bottom:0.35rem;">${GEN_SVGS.bolt} <strong>Créditos IA:</strong> ${currentAi} IA + ${customAiBonus} IA = <strong>${projAi} IA</strong> proyectados.</div>` : ''}
      ${nonceHtml}
    `;
    return;
  }

  // 3. Proyección según planes de catálogo
  switch (plan) {
    case 'RECARGA_IA_150': {
      const aiCredits = (cfgPlan?.ai_credits !== undefined) ? cfgPlan.ai_credits : 150;
      impactBadge.classList.add('recharge');
      impactBadge.innerHTML = `${GEN_SVGS.lightbulb} <strong>Impacto:</strong> Conservará su plan actual y su fecha de vigencia. Se sumarán <strong>+${aiCredits} créditos de escaneos IA</strong> acumulativos sin fecha de caducidad.`;
      const projAi = currentAi + aiCredits;
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Vigencia:</strong> Mantiene su fecha actual (${client?.license_expires ? client.license_expires.substring(0, 10) : 'Activa'}) (Sin alteración de suscripción).</div>
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.bolt} <strong>Créditos IA:</strong> Saldo celular (${currentAi} IA) + Recarga (+${aiCredits} IA) = <strong>${projAi} IA</strong> proyectados.</div>
        ${nonceHtml}
      `;
      break;
    }
    case 'PERPETUO_LIBERADO': {
      const updateMonths = (cfgPlan?.updates_window_months !== undefined) ? cfgPlan.updates_window_months : 12;
      impactBadge.classList.add('perpetual');
      impactBadge.innerHTML = `${GEN_SVGS.star} <strong>Impacto:</strong> Licencia Perpetua Liberada. Acceso ilimitado de por vida (+99,999 días) con ${updateMonths} meses de actualizaciones de funciones incluidas.`;
      const updatesTarget = new Date(now.getTime() + updateMonths * 30 * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Vigencia:</strong> Vitalicia de por vida • <strong>Pase de Updates hasta:</strong> ${formatDateStr(updatesTarget)}.</div>
        ${nonceHtml}
      `;
      break;
    }
    case 'PASE_ACTUALIZACION_ANUAL': {
      const passDays = (cfgPlan?.days !== undefined && cfgPlan.days > 0) ? cfgPlan.days : 365;
      impactBadge.classList.add('perpetual');
      impactBadge.innerHTML = `${GEN_SVGS.refresh} <strong>Impacto:</strong> Extiende por <strong>+${passDays} días adicionales</strong> la ventana de nuevas versiones y herramientas para clientes perpetuos.`;
      const currentUpdates = client && client.updates_until ? new Date(client.updates_until) : now;
      const baseUp = currentUpdates > now ? currentUpdates : now;
      const newUpdates = new Date(baseUp.getTime() + passDays * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Nueva Ventana de Updates:</strong> Hasta el ${formatDateStr(newUpdates)} (+${passDays} días).</div>
        ${nonceHtml}
      `;
      break;
    }
    case 'EXTENSION_CORTESIA': {
      const cortesiaDays = (cfgPlan?.days !== undefined && cfgPlan.days > 0) ? cfgPlan.days : 7;
      impactBadge.innerHTML = `${GEN_SVGS.clock} <strong>Impacto:</strong> Otorga <strong>+${cortesiaDays} días de gracia temporal</strong> (S/ 0.00) para resolver cobranza en trámite o emergencias operativas.`;
      const projCortesia = new Date(baseDate.getTime() + cortesiaDays * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projCortesia)} (+${cortesiaDays} días de gracia).</div>
        ${nonceHtml}
      `;
      break;
    }
    default: {
      const days = (cfgPlan?.days !== undefined) ? cfgPlan.days : (parseInt(selectedOpt?.getAttribute('data-days')) || 30);
      impactBadge.innerHTML = `${GEN_SVGS.calendar} <strong>Impacto:</strong> Renovación acumulativa sin pérdida de días. Se sumarán <strong>+${days} días</strong> directos al saldo remanente.`;
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
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projRegular)} (Cero pérdida de días).</div>
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.bolt} <strong>Créditos IA:</strong> ${aiBreakdown}</div>
        ${nonceHtml}
      `;
      break;
    }
  }
}

const updatePlanImpactAndProjection = updateLiveLicenseProjection;

function renderSelectedGeneratorLicense(code, client, isLatest = true) {
  if (!code) return;
  currentSelectedGeneratorCode = code;

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

  // Decodificación defensiva desacoplada del token Ed25519 como fallback
  const claims = decodeMl9TokenPayload(token) || {};

  // Actualizar metadatos en grid
  const metaPlan = document.getElementById('metaGenPlan');
  const metaNonce = document.getElementById('metaGenNonce');
  const metaEmitted = document.getElementById('metaGenEmitted');
  const metaExpires = document.getElementById('metaGenExpires');
  const metaAi = document.getElementById('metaGenAi');
  const metaDevice = document.getElementById('metaGenDeviceId');

  const pPlan = code.plan || (claims.y ? claims.y : client?.license_type) || 'MENSUAL';
  if (metaPlan) metaPlan.textContent = pPlan.replace(/_/g, ' ');

  const nonceVal = (code.nonce !== undefined && code.nonce !== null)
    ? code.nonce
    : (claims.n !== undefined ? claims.n : null);
  if (metaNonce) metaNonce.textContent = nonceVal !== null ? `#${nonceVal}` : '-';

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
    } else if (claims.x) {
      metaExpires.textContent = new Date(claims.x * 1000).toISOString().substring(0, 10);
    } else if (client?.license_expires) {
      metaExpires.textContent = client.license_expires.substring(0, 10);
    } else {
      metaExpires.textContent = '-';
    }
  }

  const aiCreds = (code.ai_credits !== undefined && code.ai_credits !== null)
    ? code.ai_credits
    : ((code.ai_extra_credits !== undefined && code.ai_extra_credits !== null)
      ? code.ai_extra_credits
      : (claims.c !== undefined ? claims.c : 0));
  if (metaAi) metaAi.textContent = `+${aiCreds} IA`;
  if (metaDevice) metaDevice.textContent = code.device_id || claims.d || client?.current_device_id || 'ML-0000';

  // Configuración dinámica del botón directo 'Generar / Ver Boleta'
  const btnOpenReceipt = document.getElementById('btnGenOpenReceipt');
  if (btnOpenReceipt) {
    let matchedPayment = null;
    const historyPayments = client?.payment_history || [];
    if (code.payment_id) {
      matchedPayment = historyPayments.find(p => p.id === code.payment_id);
    }
    if (!matchedPayment && code.amount_paid > 0) {
      const codeDate = (code.emitted_at || code.created_at || '').substring(0, 10);
      matchedPayment = historyPayments.find(p => {
        const pDate = (p.date || '').substring(0, 10);
        return pDate === codeDate && Math.abs((p.amount || 0) - (code.amount_paid || 0)) < 0.01;
      });
    }

    if (matchedPayment || (code.amount_paid && code.amount_paid > 0) || code.payment_id) {
      btnOpenReceipt.style.display = 'inline-flex';
      const receiptNum = matchedPayment?.receipt_number;
      const btnSpan = document.getElementById('btnGenOpenReceiptText');
      if (btnSpan) {
        btnSpan.textContent = receiptNum ? `Ver Boleta (${receiptNum})` : 'Generar / Ver Boleta';
      }
      btnOpenReceipt.onclick = () => {
        const targetPaymentId = matchedPayment?.id || code.payment_id;
        if (targetPaymentId && typeof openPaymentReceiptModal === 'function') {
          openPaymentReceiptModal(client.id, targetPaymentId);
        } else {
          showToast('No se encontró el registro contable del pago.', 'warning');
        }
      };
    } else {
      btnOpenReceipt.style.display = 'none';
      btnOpenReceipt.onclick = null;
    }
  }

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

// =================== MODAL DE CONFIRMACIÓN PRE-EMISIÓN Y FIRMA ED25519 (FASE 2 PLAN 18.5) ===================
function openConfirmEmissionModal() {
  const clientId = document.getElementById('licClientSelect')?.value;
  if (!clientId) {
    showToast('Por favor selecciona un cliente de la lista.', 'warning');
    return;
  }

  const client = globalClients.find(c => c.id === clientId);
  if (!client) {
    showToast('Cliente seleccionado no encontrado en el sistema.', 'warning');
    return;
  }

  const devId = (client.current_device_id || '').trim();
  if (!devId) {
    showToast('El cliente seleccionado no cuenta con un Hardware ID vinculado.', 'warning');
    return;
  }

  const plan = document.getElementById('licPlanSelect')?.value;
  const isBonoIa = plan === 'BONO_IA_PERSONALIZADO';

  let paymentAmount = parseFloat(document.getElementById('licPaymentAmount')?.value);
  if (isNaN(paymentAmount) || paymentAmount < 0) {
    showToast('El monto de cobro debe ser un número válido mayor o igual a 0.', 'warning');
    return;
  }

  const isCustomEnabled = (document.getElementById('chkEnableCustomSettings')?.checked === true) && !isBonoIa;
  let customDaysVal = null;
  let customAiBonus = 0;
  let computationMode = 'cumulative';
  let customExactDate = null;

  if (isCustomEnabled) {
    customDaysVal = parseInt(document.getElementById('licCustomDays')?.value) || null;
    customAiBonus = parseInt(document.getElementById('licCustomAiBonus')?.value) || 0;
    computationMode = document.getElementById('licCustomComputationMode')?.value || 'cumulative';
    customExactDate = document.getElementById('licCustomExactDate')?.value || null;
  }

  let customAiScans = 0;
  if (isBonoIa) {
    customAiScans = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
    if (customAiScans <= 0) {
      showToast('La cantidad de escaneos IA debe ser mayor a 0.', 'warning');
      return;
    }
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    if (isFree) {
      paymentAmount = 0.0;
    }
  } else if (plan === 'EXTENSION_CORTESIA') {
    paymentAmount = 0.0;
  }

  // 1. Cliente y Dispositivo
  const elClientName = document.getElementById('confirmLicClientName');
  const elOwnerDoc = document.getElementById('confirmLicOwnerDoc');
  const elHwId = document.getElementById('confirmLicHardwareId');
  const elAppVer = document.getElementById('confirmLicAppVersion');

  if (elClientName) elClientName.textContent = client.business_name || 'Sin Nombre';
  const docText = client.doc_id ? ` • DNI/RUC: ${client.doc_id}` : '';
  if (elOwnerDoc) elOwnerDoc.textContent = `${client.owner_name || 'Sin Titular'}${docText}`;
  if (elHwId) elHwId.textContent = devId;
  if (elAppVer) elAppVer.textContent = client.installed_version ? `(v${client.installed_version})` : '(v9.34.0)';

  // 2. Plan / Modalidad y Beneficios
  const elPlanLabel = document.getElementById('confirmLicPlanLabel');
  if (elPlanLabel) {
    if (isBonoIa) {
      elPlanLabel.innerHTML = `<strong>Bono / Recarga IA Personalizada (+${customAiScans} IA)</strong>`;
    } else {
      elPlanLabel.innerHTML = `<strong>${escapeHtml(formatPlanHumanLabel(plan))}</strong>`;
    }
  }

  // Vigencia Proyectada
  const elExpiration = document.getElementById('confirmLicExpiration');
  const formatDateStr = (d) => {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${day}/${m}/${y}`;
  };

  const now = new Date();
  let baseDate = now;
  if (computationMode === 'cumulative' && client.license_expires) {
    const exp = new Date(client.license_expires);
    if (exp > now && client.license_type !== 'TRIAL_VENCIDO') {
      baseDate = exp;
    }
  }

  if (elExpiration) {
    if (isBonoIa || plan === 'RECARGA_IA_150') {
      const curExp = client.license_expires ? client.license_expires.substring(0, 10) : 'Activa';
      const isTrial = client.license_type === 'TRIAL' || client.trial_days_remaining !== null;
      const vig = isTrial ? `Trial (${client.trial_days_remaining ?? '-'}d restantes)` : curExp;
      elExpiration.textContent = `${vig} (Sin cambio de días)`;
    } else if (plan === 'PERPETUO_LIBERADO') {
      elExpiration.textContent = 'De por Vida / Sin Caducidad';
    } else if (customExactDate) {
      elExpiration.textContent = `Sobrescrita fija al ${customExactDate}`;
    } else {
      const curExpStr = client.license_expires ? client.license_expires.substring(0, 10) : 'Nueva emisión';
      const days = (customDaysVal && customDaysVal > 0)
        ? customDaysVal
        : (ownerConfig?.catalog?.[plan]?.days ?? (plan === 'EXTENSION_CORTESIA' ? 7 : 30));
      const proj = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);
      elExpiration.textContent = `${curExpStr} → ${formatDateStr(proj)} (+${days} días)`;
    }
  }

  // Créditos IA Celular
  const elAi = document.getElementById('confirmLicAiCredits');
  const currentAi = (client.ai_reported_balance !== undefined && client.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client.ai_accumulated_credits ?? client.ai_extra_credits ?? 0);

  if (elAi) {
    if (isBonoIa) {
      const totalProj = currentAi + customAiScans;
      elAi.textContent = `${currentAi} IA (celular) + ${customAiScans} IA = ${totalProj} IA proyectados`;
    } else {
      const basePlanAi = ownerConfig?.catalog?.[plan]?.ai_credits ?? (plan === 'TRIMESTRAL' ? 180 : (plan === 'SEMESTRAL' ? 450 : (plan === 'ANUAL' ? 1200 : (plan === 'PERPETUO_LIBERADO' ? 0 : 50))));
      const toAdd = basePlanAi + customAiBonus;
      if (toAdd > 0) {
        const totalProj = currentAi + toAdd;
        elAi.textContent = `${currentAi} IA (celular) + ${toAdd} IA = ${totalProj} IA proyectados`;
      } else {
        elAi.textContent = `${currentAi} IA (celular) (Sin bonos de escaneo)`;
      }
    }
  }

  // 3. Nonce Criptográfico (Estricto Plan 18/18.5: Último Nonce Emitido -> Próximo Nonce a Firmar)
  const elNonce = document.getElementById('confirmLicNonce');
  const nextNonce = client.next_nonce || 1;
  const lastNonce = nextNonce > 1 ? nextNonce - 1 : 0;
  if (elNonce) {
    elNonce.textContent = `Último Nonce Emitido (#${lastNonce > 0 ? lastNonce : 'Ninguno'}) → Próximo Nonce a Firmar (#${nextNonce})`;
  }

  // 4. Impacto Financiero
  const elFinancial = document.getElementById('confirmLicFinancial');
  const paymentMethod = document.getElementById('licPaymentMethod')?.value || 'Yape';
  const paymentRef = document.getElementById('licPaymentRef')?.value?.trim() || '';
  if (elFinancial) {
    if (paymentAmount > 0) {
      const refText = paymentRef ? ` - ${paymentRef}` : '';
      elFinancial.innerHTML = `<strong>S/ ${paymentAmount.toFixed(2)}</strong> (${escapeHtml(paymentMethod)}${escapeHtml(refText)})`;
    } else {
      elFinancial.textContent = 'Cortesía / Sin Costo (S/ 0.00)';
    }
  }

  // 5. Badge de Ajustes Personalizados
  const badgeBox = document.getElementById('confirmLicCustomBadgeBox');
  const customDetails = document.getElementById('confirmLicCustomDetails');
  if (isCustomEnabled && (customDaysVal !== null || customAiBonus > 0 || customExactDate || computationMode !== 'cumulative')) {
    const details = [];
    if (customDaysVal !== null && customDaysVal > 0) {
      details.push(`Días manuales: +${customDaysVal} (${computationMode === 'from_today' ? 'desde hoy' : 'acumulativos'})`);
    }
    if (customAiBonus > 0) {
      details.push(`Bono IA regalo: +${customAiBonus} escaneos`);
    }
    if (customExactDate) {
      details.push(`Fecha fija exacta: ${customExactDate}`);
    }
    if (badgeBox && customDetails) {
      customDetails.innerHTML = details.join(' • ') || 'Ajustes comerciales manuales aplicados';
      badgeBox.style.display = 'block';
    }
  } else {
    if (badgeBox) badgeBox.style.display = 'none';
  }

  // Restaurar vistas y habilitar botones
  const summaryState = document.getElementById('confirmEmissionSummaryState');
  const animState = document.getElementById('confirmEmissionAnimState');
  const footer = document.getElementById('confirmEmissionFooter');
  const btnCancel = document.getElementById('btnCancelConfirmEmission');
  const btnExecute = document.getElementById('btnExecuteConfirmEmission');

  if (summaryState) summaryState.style.display = 'block';
  if (animState) animState.style.display = 'none';
  if (footer) footer.style.display = 'flex';
  if (btnCancel) btnCancel.disabled = false;
  if (btnExecute) btnExecute.disabled = false;

  openModal('modalConfirmLicenseEmission');
}

const generateLicense = openConfirmEmissionModal;

async function executeConfirmedEmission() {
  const clientId = document.getElementById('licClientSelect')?.value;
  const client = globalClients.find(c => c.id === clientId);
  if (!clientId || !client) {
    showToast('Por favor selecciona un cliente válido.', 'warning');
    closeModal('modalConfirmLicenseEmission');
    return;
  }

  const plan = document.getElementById('licPlanSelect')?.value;
  const isBonoIa = plan === 'BONO_IA_PERSONALIZADO';

  let paymentAmount = parseFloat(document.getElementById('licPaymentAmount')?.value) || 0;
  let paymentMethod = document.getElementById('licPaymentMethod')?.value || 'Yape';
  let paymentRef = document.getElementById('licPaymentRef')?.value?.trim() || 'Op. Generada';

  const isCustomEnabled = (document.getElementById('chkEnableCustomSettings')?.checked === true) && !isBonoIa;
  let customDaysVal = null;
  let customAiBonus = 0;
  let computationMode = 'cumulative';
  let customExactDate = null;

  if (isCustomEnabled) {
    customDaysVal = parseInt(document.getElementById('licCustomDays')?.value) || null;
    customAiBonus = parseInt(document.getElementById('licCustomAiBonus')?.value) || 0;
    computationMode = document.getElementById('licCustomComputationMode')?.value || 'cumulative';
    customExactDate = document.getElementById('licCustomExactDate')?.value || null;
  }

  if (isBonoIa) {
    const customAiAmount = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
    customAiBonus = customAiAmount;
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    if (isFree) {
      paymentAmount = 0.0;
      paymentMethod = 'Cortesia / Promocion';
      paymentRef = 'Bono Gratuito';
    }
  } else if (plan === 'EXTENSION_CORTESIA') {
    paymentAmount = 0.0;
    paymentMethod = 'Cortesia / Promocion';
    paymentRef = 'Extension Cortesia';
  }

  // 1. Deshabilitar botones para impedir doble emisión accidental y activar vista animada
  const btnCancel = document.getElementById('btnCancelConfirmEmission');
  const btnExecute = document.getElementById('btnExecuteConfirmEmission');
  const summaryState = document.getElementById('confirmEmissionSummaryState');
  const animState = document.getElementById('confirmEmissionAnimState');
  const footer = document.getElementById('confirmEmissionFooter');

  if (btnCancel) btnCancel.disabled = true;
  if (btnExecute) btnExecute.disabled = true;
  if (summaryState) summaryState.style.display = 'none';
  if (footer) footer.style.display = 'none';
  if (animState) animState.style.display = 'block';

  // Configurar animación en Etapa 1
  const animTitle = document.getElementById('confirmEmissionAnimTitle');
  const animSubtitle = document.getElementById('confirmEmissionAnimSubtitle');
  const shieldSvg = animState?.querySelector('.shield-svg');
  const shieldKeyHole = document.getElementById('shieldKeyHole');
  const shieldCheckPath = document.getElementById('shieldCheckPath');

  if (animTitle) animTitle.textContent = 'Validando correlativo Nonce y vinculación de Hardware...';
  if (animSubtitle) animSubtitle.textContent = 'Sincronizando estado criptográfico seguro con la bóveda';
  if (shieldKeyHole) shieldKeyHole.style.display = 'block';
  if (shieldCheckPath) shieldCheckPath.style.display = 'none';
  if (shieldSvg) shieldSvg.style.color = 'var(--primary)';

  // Programar transición a Etapa 2 (~260ms)
  const stage2Timer = setTimeout(() => {
    if (animTitle) animTitle.textContent = 'Firmando criptográficamente con clave maestra Ed25519...';
    if (animSubtitle) animSubtitle.textContent = 'Generando firma asimétrica de 64 bytes (Envelope DPAPI)';
  }, 260);

  const startTime = Date.now();

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
    currentSelectedGeneratorCode = data;

    // Etapa 3: Asegurar tiempo mínimo (~650ms total) para fluidez profesional
    const elapsed = Date.now() - startTime;
    const waitTime = Math.max(0, 650 - elapsed);

    setTimeout(async () => {
      if (animTitle) animTitle.textContent = '¡Licencia y Credencial Emitidas con Éxito!';
      if (animSubtitle) animSubtitle.textContent = 'Firma Ed25519 verificada e integrada en el historial comercial';
      if (shieldKeyHole) shieldKeyHole.style.display = 'none';
      if (shieldCheckPath) shieldCheckPath.style.display = 'block';
      if (shieldSvg) shieldSvg.style.color = 'var(--success)';

      // Cierre y transición suave a columna de resultado
      setTimeout(async () => {
        closeModal('modalConfirmLicenseEmission');

        await loadClients();
        await loadDashboard();

        const updatedClient = globalClients.find(c => c.id === clientId) || client || data.client;
        renderSelectedGeneratorLicense(data, updatedClient, true);
        updateGeneratorRightColumn(updatedClient);

        // Feedback visual en la columna derecha
        const resultContainer = document.getElementById('licenseResultContainer');
        if (resultContainer) {
          resultContainer.classList.remove('license-result-highlight');
          void resultContainer.offsetWidth; // Forzar reflow del DOM
          resultContainer.classList.add('license-result-highlight');
          setTimeout(() => {
            resultContainer.classList.remove('license-result-highlight');
          }, 1800);
          resultContainer.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }

        showToast('¡Licencia Ed25519 emitida y firmada con éxito!', 'success');
      }, 250);
    }, waitTime);

  } catch (e) {
    clearTimeout(stage2Timer);
    if (animState) animState.style.display = 'none';
    if (summaryState) summaryState.style.display = 'block';
    if (footer) footer.style.display = 'flex';
    if (btnCancel) btnCancel.disabled = false;
    if (btnExecute) btnExecute.disabled = false;
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
  const grpUpdates = document.getElementById('grpDrawerEditUpdates');
  const updatesInput = document.getElementById('drawerEditUpdates');
  const isPerpetualOrPass = (p === 'PERPETUO_LIBERADO' || p === 'PERPETUO' || p === 'PASE_ACTUALIZACION_ANUAL');
  if (grpUpdates) {
    grpUpdates.style.display = isPerpetualOrPass ? 'block' : 'none';
  }
  if (updatesInput) {
    if (!isPerpetualOrPass) {
      updatesInput.value = '';
    }
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
async function openPaymentReceiptModal(clientId, paymentId, voucherType = null) {
  try {
    const payload = {};
    if (voucherType) payload.voucher_type = voucherType;
    const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}/receipt`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'No se pudo resolver el comprobante de pago.');
    }
    const data = await res.json();
    currentReceiptData = data;
    populateReceiptUI(data);
    openModal('modalPaymentReceipt');
  } catch (e) {
    showToast('Error al abrir comprobante: ' + e.message, 'error');
  }
}

async function switchReceiptVoucherType(newType) {
  if (!currentReceiptData || !currentReceiptData.client || !currentReceiptData.payment) return;
  const clientId = currentReceiptData.client.id;
  const paymentId = currentReceiptData.payment.id;
  try {
    const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}/receipt`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        voucher_type: newType,
        invoice_ruc: document.getElementById('rcInputInvoiceRuc')?.value.trim() || undefined,
        invoice_business_name: document.getElementById('rcInputInvoiceBizName')?.value.trim() || undefined,
        invoice_fiscal_address: document.getElementById('rcInputInvoiceAddress')?.value.trim() || undefined,
        show_igv_breakdown: document.getElementById('rcCheckShowIgv')?.checked ?? false,
      }),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Error al cambiar serie del comprobante.');
    }
    const data = await res.json();
    currentReceiptData = data;
    populateReceiptUI(data);
  } catch (e) {
    showToast('Error al alternar serie: ' + e.message, 'error');
  }
}

function populateReceiptUI(data) {
  if (!data) return;
  const rc = data.receipt_config || {};
  const payment = data.payment || {};
  const client = data.client || {};
  const voucherType = data.voucher_type || (data.receipt_number?.startsWith('FAC') ? 'FAC' : 'BOL');
  const isInvoice = voucherType === 'FAC';

  // Modal header badge & main title
  const mainTitle = document.getElementById('receiptModalMainTitle');
  if (mainTitle) {
    mainTitle.textContent = isInvoice ? 'Factura de Pago Oficial & Comprobante Digital' : 'Generador de Boleta de Pago';
  }
  const badge = document.getElementById('receiptModalBadge');
  if (badge) badge.textContent = data.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');

  // Selector de Tipo de Comprobante
  const selectVoucher = document.getElementById('rcSelectVoucherType');
  if (selectVoucher) selectVoucher.value = voucherType;

  // Bloque de datos fiscales de factura
  const invoiceBlock = document.getElementById('rcInvoiceFieldsBlock');
  if (invoiceBlock) invoiceBlock.style.display = isInvoice ? 'block' : 'none';

  const invRuc = document.getElementById('rcInputInvoiceRuc');
  if (invRuc) invRuc.value = payment.invoice_ruc || client.document_number || '';
  const invBiz = document.getElementById('rcInputInvoiceBizName');
  if (invBiz) invBiz.value = payment.invoice_business_name || client.business_name || '';
  const invAddr = document.getElementById('rcInputInvoiceAddress');
  if (invAddr) invAddr.value = payment.invoice_fiscal_address || '';
  const invIgv = document.getElementById('rcCheckShowIgv');
  if (invIgv) invIgv.checked = payment.show_igv_breakdown === true || (isInvoice && rc.show_igv_breakdown === true);

  // Título de comprobante
  const titleInp = document.getElementById('rcInputTitle');
  if (titleInp) {
    if (isInvoice) {
      titleInp.value = rc.invoice_title || 'FACTURA DE VENTA / PAGO';
    } else {
      titleInp.value = rc.title || 'BOLETA DE PAGO ADMINISTRATIVA';
    }
  }

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

  // 9 Interruptores de Visibilidad
  const setChk = (id, val) => {
    const el = document.getElementById(id);
    if (el) el.checked = val !== false;
  };
  setChk('rcCheckShowLogo', rc.show_logo);
  setChk('rcCheckShowIssuerDoc', rc.show_issuer_doc);
  setChk('rcCheckShowIssuerPhone', rc.show_issuer_phone);
  setChk('rcCheckShowClientDoc', rc.show_client_doc);
  setChk('rcCheckShowHardwareId', rc.show_hardware_id);
  setChk('rcCheckShowOperationNumber', rc.show_operation_number);
  setChk('rcCheckShowObservation', rc.show_observation);
  setChk('rcCheckShowSignature', rc.show_signature);
  setChk('rcCheckShowFooterNotes', rc.show_footer_notes);

  const colorInp = document.getElementById('rcInputAccentColor');
  if (colorInp) colorInp.value = rc.accent_color || '#2563eb';

  const noteInp = document.getElementById('rcInputCustomNote');
  if (noteInp) noteInp.value = payment.receipt_custom_note || '';

  const footInp = document.getElementById('rcInputFooterNotes');
  if (footInp) footInp.value = rc.footer_notes || 'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.';

  const signInp = document.getElementById('rcInputSignature');
  if (signInp) signInp.value = rc.signature_text || 'Administración Comercial — MochilaLista';

  renderReceiptPreviewAndCanvas();
}

function renderReceiptPreviewAndCanvas() {
  if (!currentReceiptData) return;
  const payment = currentReceiptData.payment || {};
  const client = currentReceiptData.client || {};
  const voucherType = currentReceiptData.voucher_type || (currentReceiptData.receipt_number?.startsWith('FAC') ? 'FAC' : 'BOL');
  const isInvoice = voucherType === 'FAC';

  const title = document.getElementById('rcInputTitle')?.value.trim() || (isInvoice ? 'FACTURA DE VENTA / PAGO' : 'BOLETA DE PAGO ADMINISTRATIVA');
  const commercial = document.getElementById('rcInputCommercialName')?.value.trim() || 'MochilaLista';
  const issuer = document.getElementById('rcInputIssuerName')?.value.trim() || 'Julio Angello Vasquez Navarro';
  const issuerDoc = document.getElementById('rcInputIssuerDoc')?.value.trim() || 'D.N.I. / R.U.C. Registrado';
  const issuerPhone = document.getElementById('rcInputIssuerPhone')?.value.trim() || '+51 922 836 879';
  const issuerCity = document.getElementById('rcInputIssuerCity')?.value.trim() || 'Piura, Perú';

  // Toggles de visibilidad
  const showLogo = document.getElementById('rcCheckShowLogo')?.checked !== false;
  const showIssuerDoc = document.getElementById('rcCheckShowIssuerDoc')?.checked !== false;
  const showIssuerPhone = document.getElementById('rcCheckShowIssuerPhone')?.checked !== false;
  const showClientDoc = document.getElementById('rcCheckShowClientDoc')?.checked !== false;
  const showHardwareId = document.getElementById('rcCheckShowHardwareId')?.checked !== false;
  const showOperationNumber = document.getElementById('rcCheckShowOperationNumber')?.checked !== false;
  const showObservation = document.getElementById('rcCheckShowObservation')?.checked !== false;
  const showSignature = document.getElementById('rcCheckShowSignature')?.checked !== false;
  const showFooterNotes = document.getElementById('rcCheckShowFooterNotes')?.checked !== false;

  const accentColor = document.getElementById('rcInputAccentColor')?.value || '#2563eb';
  const customNote = document.getElementById('rcInputCustomNote')?.value.trim() || '';
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || '';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || '';

  // Datos fiscales de factura
  const invoiceRuc = document.getElementById('rcInputInvoiceRuc')?.value.trim() || '';
  const invoiceBiz = document.getElementById('rcInputInvoiceBizName')?.value.trim() || '';
  const invoiceAddress = document.getElementById('rcInputInvoiceAddress')?.value.trim() || '';
  const showIgv = document.getElementById('rcCheckShowIgv')?.checked === true;

  const correlative = currentReceiptData.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
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
  const rdocCorrLbl = document.getElementById('rdocCorrelativeLbl');
  if (rdocCorrLbl) {
    rdocCorrLbl.textContent = isInvoice ? 'FACTURA N.°' : 'COMPROBANTE N.°';
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
  const rdocDocRow = document.getElementById('rdocIssuerDocRow');
  if (rdocDocRow) rdocDocRow.style.display = showIssuerDoc ? 'block' : 'none';
  const rdocDoc = document.getElementById('rdocIssuerDoc');
  if (rdocDoc) rdocDoc.textContent = issuerDoc;
  const rdocPhoneRow = document.getElementById('rdocIssuerPhoneRow');
  if (rdocPhoneRow) rdocPhoneRow.style.display = showIssuerPhone ? 'block' : 'none';
  const rdocPhone = document.getElementById('rdocIssuerPhone');
  if (rdocPhone) rdocPhone.textContent = issuerPhone;
  const rdocCity = document.getElementById('rdocIssuerCity');
  if (rdocCity) rdocCity.textContent = issuerCity;

  // Cliente o Empresa
  const rdocClientTag = document.getElementById('rdocClientTag');
  if (rdocClientTag) {
    rdocClientTag.textContent = isInvoice ? 'DATOS DE LA EMPRESA / CLIENTE' : 'DATOS DEL CLIENTE';
  }
  const rdocClientBiz = document.getElementById('rdocClientBiz');
  if (rdocClientBiz) {
    rdocClientBiz.textContent = (isInvoice && invoiceBiz) ? invoiceBiz : (client.business_name || 'Cliente Registrado');
  }
  const rdocClientOwnerRow = document.getElementById('rdocClientOwnerRow');
  if (rdocClientOwnerRow) {
    rdocClientOwnerRow.style.display = (!isInvoice && client.owner_name) ? 'block' : 'none';
  }
  const rdocClientOwner = document.getElementById('rdocClientOwner');
  if (rdocClientOwner) rdocClientOwner.textContent = client.owner_name || '-';

  const rdocClientDocRow = document.getElementById('rdocClientDocRow');
  if (rdocClientDocRow) rdocClientDocRow.style.display = showClientDoc ? 'block' : 'none';
  const rdocClientDocLbl = document.getElementById('rdocClientDocLbl');
  if (rdocClientDocLbl) rdocClientDocLbl.textContent = isInvoice ? 'RUC:' : 'RUC / DNI:';
  const rdocClientDoc = document.getElementById('rdocClientDoc');
  if (rdocClientDoc) {
    rdocClientDoc.textContent = (isInvoice && invoiceRuc) ? invoiceRuc : (client.document_number || '-');
  }

  const rdocClientAddressRow = document.getElementById('rdocClientAddressRow');
  if (rdocClientAddressRow) {
    rdocClientAddressRow.style.display = (isInvoice && invoiceAddress) ? 'block' : 'none';
  }
  const rdocClientAddress = document.getElementById('rdocClientAddress');
  if (rdocClientAddress) rdocClientAddress.textContent = invoiceAddress;

  const rdocClientDevIdRow = document.getElementById('rdocClientDevIdRow');
  if (rdocClientDevIdRow) {
    rdocClientDevIdRow.style.display = (showHardwareId && !isInvoice) ? 'block' : 'none';
  }
  const rdocClientDevId = document.getElementById('rdocClientDevId');
  if (rdocClientDevId) rdocClientDevId.textContent = client.current_device_id || '-';

  const rdocConcept = document.getElementById('rdocPaymentConcept');
  if (rdocConcept) rdocConcept.textContent = formatPlanHumanLabel(payment.plan) || payment.plan || 'Pago Registrado';
  const rdocNote = document.getElementById('rdocPaymentCustomNote');
  if (rdocNote) {
    rdocNote.textContent = customNote;
    rdocNote.style.display = (showObservation && customNote) ? 'block' : 'none';
  }
  const rdocMethod = document.getElementById('rdocPaymentMethod');
  if (rdocMethod) rdocMethod.textContent = payment.method || 'Yape';
  const rdocRef = document.getElementById('rdocPaymentRef');
  if (rdocRef) rdocRef.textContent = showOperationNumber ? (payment.reference || '-') : '-';
  const rdocPayDate = document.getElementById('rdocPaymentDate');
  if (rdocPayDate) rdocPayDate.textContent = payment.date ? payment.date.substring(0, 10) : '-';

  const totalVal = parseFloat(payment.amount) || 0;
  const rdocRowAmt = document.getElementById('rdocPaymentRowAmount');
  if (rdocRowAmt) rdocRowAmt.textContent = `S/ ${totalVal.toFixed(2)}`;

  // Cálculo de IGV 18% opcional
  let subtotalVal = totalVal;
  let igvVal = 0;
  if (showIgv) {
    subtotalVal = +(totalVal / 1.18).toFixed(2);
    igvVal = +(totalVal - subtotalVal).toFixed(2);
  }

  const rdocTotalBox = document.querySelector('.rdoc-total-box');
  if (rdocTotalBox) {
    rdocTotalBox.style.borderColor = accentColor;
    if (showIgv) {
      rdocTotalBox.classList.add('with-igv');
      rdocTotalBox.innerHTML = `
        <div class="rdoc-igv-row">
          <span style="color:#475569;">Subtotal (Op. Gravada):</span>
          <strong style="color:#1e293b;">S/ ${subtotalVal.toFixed(2)}</strong>
        </div>
        <div class="rdoc-igv-row">
          <span style="color:#475569;">I.G.V. (18%):</span>
          <strong style="color:#1e293b;">S/ ${igvVal.toFixed(2)}</strong>
        </div>
        <div class="rdoc-igv-total-row">
          <span style="font-weight:700; color:#0f172a;">TOTAL A PAGAR:</span>
          <span id="rdocPaymentTotal" style="color:${accentColor}; font-weight:900; font-size:1.35rem;">S/ ${totalVal.toFixed(2)}</span>
        </div>
      `;
    } else {
      rdocTotalBox.classList.remove('with-igv');
      rdocTotalBox.innerHTML = `
        <span style="font-size:0.8rem; font-weight:700; color:#334155;">${isInvoice ? 'TOTAL FACTURADO:' : 'TOTAL RECIBIDO:'}</span>
        <span id="rdocPaymentTotal" style="color:${accentColor}; font-weight:900; font-size:1.5rem;">S/ ${totalVal.toFixed(2)}</span>
      `;
    }
  }

  const rdocFoot = document.getElementById('rdocFooterNotes');
  if (rdocFoot) {
    rdocFoot.textContent = footerNotes;
    rdocFoot.style.display = showFooterNotes ? 'block' : 'none';
  }
  const rdocSignBlock = document.getElementById('rdocSignatureBlock');
  if (rdocSignBlock) rdocSignBlock.style.display = showSignature ? 'flex' : 'none';
  const rdocSign = document.getElementById('rdocSignatureText');
  if (rdocSign) rdocSign.textContent = signatureText;

  drawReceiptOnCanvas();
}

function drawReceiptOnCanvas() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas || !currentReceiptData) return;

  const payment = currentReceiptData.payment || {};
  const client = currentReceiptData.client || {};
  const voucherType = currentReceiptData.voucher_type || (currentReceiptData.receipt_number?.startsWith('FAC') ? 'FAC' : 'BOL');
  const isInvoice = voucherType === 'FAC';

  const title = document.getElementById('rcInputTitle')?.value.trim() || (isInvoice ? 'FACTURA DE VENTA / PAGO' : 'BOLETA DE PAGO ADMINISTRATIVA');
  const commercial = document.getElementById('rcInputCommercialName')?.value.trim() || 'MochilaLista';
  const issuer = document.getElementById('rcInputIssuerName')?.value.trim() || 'Julio Angello Vasquez Navarro';
  const issuerDoc = document.getElementById('rcInputIssuerDoc')?.value.trim() || 'D.N.I. / R.U.C. Registrado';
  const issuerPhone = document.getElementById('rcInputIssuerPhone')?.value.trim() || '+51 922 836 879';
  const issuerCity = document.getElementById('rcInputIssuerCity')?.value.trim() || 'Piura, Perú';

  // Toggles de visibilidad
  const showLogo = document.getElementById('rcCheckShowLogo')?.checked !== false;
  const showIssuerDoc = document.getElementById('rcCheckShowIssuerDoc')?.checked !== false;
  const showIssuerPhone = document.getElementById('rcCheckShowIssuerPhone')?.checked !== false;
  const showClientDoc = document.getElementById('rcCheckShowClientDoc')?.checked !== false;
  const showHardwareId = document.getElementById('rcCheckShowHardwareId')?.checked !== false;
  const showOperationNumber = document.getElementById('rcCheckShowOperationNumber')?.checked !== false;
  const showObservation = document.getElementById('rcCheckShowObservation')?.checked !== false;
  const showSignature = document.getElementById('rcCheckShowSignature')?.checked !== false;
  const showFooterNotes = document.getElementById('rcCheckShowFooterNotes')?.checked !== false;

  const accentColor = document.getElementById('rcInputAccentColor')?.value || '#2563eb';
  const customNote = document.getElementById('rcInputCustomNote')?.value.trim() || '';
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || 'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || 'Administración Comercial — MochilaLista';

  // Datos fiscales de factura
  const invoiceRuc = document.getElementById('rcInputInvoiceRuc')?.value.trim() || '';
  const invoiceBiz = document.getElementById('rcInputInvoiceBizName')?.value.trim() || '';
  const invoiceAddress = document.getElementById('rcInputInvoiceAddress')?.value.trim() || '';
  const showIgv = document.getElementById('rcCheckShowIgv')?.checked === true;

  const correlative = currentReceiptData.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const rawDate = currentReceiptData.receipt_issued_at || payment.date || new Date().toISOString();
  let dateFormatted = rawDate.substring(0, 10);
  try {
    const d = new Date(rawDate);
    dateFormatted = d.toLocaleDateString('es-PE', { day: '2-digit', month: '2-digit', year: 'numeric' }) + ' ' + d.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' });
  } catch (_) {}

  const totalVal = parseFloat(payment.amount) || 0;
  let subtotalVal = totalVal;
  let igvVal = 0;
  if (showIgv) {
    subtotalVal = +(totalVal / 1.18).toFixed(2);
    igvVal = +(totalVal - subtotalVal).toFixed(2);
  }

  const width = 1200;
  const height = 940;
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  // Fondo blanco y marco exterior sutil
  ctx.save();
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, width, height);
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 2;
  ctx.strokeRect(10, 10, width - 20, height - 20);
  ctx.restore();

  // Cabecera superior
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

  ctx.save();
  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 30px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText(title, startX, 80);

  ctx.fillStyle = accentColor;
  ctx.font = 'bold 22px sans-serif';
  ctx.fillText(commercial, startX, 112);
  ctx.restore();

  // Caja de correlativo (esquina superior derecha)
  ctx.save();
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 2;
  roundRect(ctx, width - 360, 42, 300, 88, 10, true, true);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 13px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText(isInvoice ? 'FACTURA DE VENTA N.°' : 'COMPROBANTE N.°', width - 210, 68);

  ctx.fillStyle = accentColor;
  ctx.font = 'bold 28px monospace';
  ctx.fillText(correlative, width - 210, 98);

  ctx.fillStyle = '#64748b';
  ctx.font = '500 13px sans-serif';
  ctx.fillText(dateFormatted, width - 210, 120);
  ctx.restore();

  // Línea divisoria de acento
  ctx.save();
  ctx.fillStyle = accentColor;
  ctx.fillRect(60, 145, width - 120, 4);
  ctx.restore();

  // Cajas de Emisor y Cliente
  const colW = (width - 150) / 2;

  // 1. Tarjeta Emisor
  ctx.save();
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 1.5;
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
  let emitY = 252;
  if (showIssuerDoc) {
    ctx.fillText(`Documento: ${issuerDoc}`, 80, emitY);
    emitY += 28;
  }
  if (showIssuerPhone) {
    ctx.fillText(`WhatsApp: ${issuerPhone}`, 80, emitY);
    emitY += 28;
  }
  ctx.fillText(`Ciudad: ${issuerCity}`, 80, emitY);
  ctx.restore();

  // 2. Tarjeta Cliente / Empresa (con aislamiento estricto y padding interno exacto)
  const clientCardX = 60 + colW + 30;
  const clientTextX = clientCardX + 20; // 110 + colW (exact 20px padding)

  ctx.save();
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 1.5;
  roundRect(ctx, clientCardX, 165, colW, 160, 8, true, true);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 14px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText(isInvoice ? 'DATOS DE LA EMPRESA / CLIENTE' : 'DATOS DEL CLIENTE', clientTextX, 192);

  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 20px sans-serif';
  const clientBizDisplay = (isInvoice && invoiceBiz) ? invoiceBiz : (client.business_name || 'Cliente Registrado');
  ctx.fillText(clientBizDisplay, clientTextX, 222);

  ctx.fillStyle = '#475569';
  ctx.font = '16px sans-serif';
  let cliY = 252;
  if (isInvoice) {
    if (showClientDoc) {
      ctx.fillText(`RUC: ${invoiceRuc || client.document_number || '-'}`, clientTextX, cliY);
      cliY += 28;
    }
    if (invoiceAddress) {
      ctx.fillText(`Dirección: ${invoiceAddress}`, clientTextX, cliY);
      cliY += 28;
    }
  } else {
    ctx.fillText(`Titular: ${client.owner_name || '-'}`, clientTextX, cliY);
    cliY += 28;
    if (showClientDoc) {
      ctx.fillText(`RUC / DNI: ${client.document_number || '-'}`, clientTextX, cliY);
      cliY += 28;
    }
    if (showHardwareId) {
      ctx.fillText(`Hardware ID: ${client.current_device_id || '-'}`, clientTextX, cliY);
    }
  }
  ctx.restore();

  // Tabla de Cobro
  const tableY = 350;
  const tableW = width - 120;
  ctx.save();
  ctx.fillStyle = '#f1f5f9';
  ctx.fillRect(60, tableY, tableW, 44);
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 1;
  ctx.strokeRect(60, tableY, tableW, 44);

  ctx.fillStyle = '#334155';
  ctx.font = 'bold 16px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText('Descripción / Concepto', 80, tableY + 28);
  ctx.fillText('Medio', 550, tableY + 28);
  ctx.fillText('N.° Operación', 700, tableY + 28);
  ctx.fillText('Fecha', 880, tableY + 28);
  ctx.textAlign = 'right';
  ctx.fillText('Total (S/)', 60 + tableW - 20, tableY + 28);
  ctx.restore();

  // Fila tabla
  const rowY = tableY + 44;
  const rowH = 75;
  ctx.save();
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(60, rowY, tableW, rowH);
  ctx.strokeStyle = '#e2e8f0';
  ctx.strokeRect(60, rowY, tableW, rowH);

  ctx.textAlign = 'left';
  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 18px sans-serif';
  ctx.fillText(formatPlanHumanLabel(payment.plan) || payment.plan || 'Pago Registrado', 80, rowY + 30);

  if (showObservation && customNote) {
    ctx.fillStyle = '#64748b';
    ctx.font = '14px sans-serif';
    ctx.fillText(customNote, 80, rowY + 54);
  }

  ctx.fillStyle = '#334155';
  ctx.font = '16px sans-serif';
  ctx.fillText(payment.method || 'Yape', 550, rowY + 35);
  ctx.fillText(showOperationNumber ? (payment.reference || '-') : '-', 700, rowY + 35);
  ctx.fillText(payment.date ? payment.date.substring(0, 10) : '-', 880, rowY + 35);

  ctx.textAlign = 'right';
  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 20px sans-serif';
  ctx.fillText(`S/ ${totalVal.toFixed(2)}`, 60 + tableW - 20, rowY + 38);
  ctx.restore();

  // Caja de Totales (con o sin desglose de IGV - Cero colisión con ancho >= 430px)
  if (showIgv) {
    ctx.save();
    const boxW = Math.max(430, width - 120 > 430 ? 430 : width - 120);
    const boxH = 115;
    const boxX = width - 60 - boxW;
    const boxY = 470;
    ctx.fillStyle = '#f8fafc';
    ctx.strokeStyle = accentColor;
    ctx.lineWidth = 2.5;
    roundRect(ctx, boxX, boxY, boxW, boxH, 10, true, true);

    ctx.font = '500 15px sans-serif';
    ctx.fillStyle = '#475569';
    ctx.textAlign = 'left';
    ctx.fillText('SUBTOTAL (OP. GRAVADA):', boxX + 24, boxY + 30);
    ctx.font = 'bold 15px sans-serif';
    ctx.fillStyle = '#1e293b';
    ctx.textAlign = 'right';
    ctx.fillText(`S/ ${subtotalVal.toFixed(2)}`, boxX + boxW - 24, boxY + 30);

    ctx.font = '500 15px sans-serif';
    ctx.fillStyle = '#475569';
    ctx.textAlign = 'left';
    ctx.fillText('I.G.V. (18%):', boxX + 24, boxY + 58);
    ctx.font = 'bold 15px sans-serif';
    ctx.fillStyle = '#1e293b';
    ctx.textAlign = 'right';
    ctx.fillText(`S/ ${igvVal.toFixed(2)}`, boxX + boxW - 24, boxY + 58);

    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(boxX + 15, boxY + 70);
    ctx.lineTo(boxX + boxW - 15, boxY + 70);
    ctx.stroke();

    ctx.font = 'bold 17px sans-serif';
    ctx.fillStyle = '#0f172a';
    ctx.textAlign = 'left';
    ctx.fillText('TOTAL A PAGAR:', boxX + 24, boxY + 95);
    ctx.font = '900 24px sans-serif';
    ctx.fillStyle = accentColor;
    ctx.textAlign = 'right';
    ctx.fillText(`S/ ${totalVal.toFixed(2)}`, boxX + boxW - 24, boxY + 96);
    ctx.restore();
  } else {
    ctx.save();
    const labelText = isInvoice ? 'TOTAL FACTURADO:' : 'TOTAL RECIBIDO:';
    const amountText = `S/ ${totalVal.toFixed(2)}`;

    ctx.font = 'bold 18px sans-serif';
    const labelW = ctx.measureText(labelText).width;
    ctx.font = '900 30px sans-serif';
    const amountW = ctx.measureText(amountText).width;

    const boxW = Math.max(430, labelW + amountW + 70);
    const boxH = 75;
    const boxX = width - 60 - boxW;
    const totalBoxY = 490;

    ctx.fillStyle = '#f8fafc';
    ctx.strokeStyle = accentColor;
    ctx.lineWidth = 3;
    roundRect(ctx, boxX, totalBoxY, boxW, boxH, 10, true, true);

    ctx.fillStyle = '#1e293b';
    ctx.font = 'bold 18px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText(labelText, boxX + 24, totalBoxY + 45);

    ctx.fillStyle = accentColor;
    ctx.font = '900 30px sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(amountText, boxX + boxW - 24, totalBoxY + 47);
    ctx.restore();
  }

  // Línea divisoria pie
  ctx.save();
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 2;
  ctx.setLineDash([6, 6]);
  ctx.beginPath();
  ctx.moveTo(60, 680);
  ctx.lineTo(width - 60, 680);
  ctx.stroke();
  ctx.restore();

  // Notas al pie
  if (showFooterNotes) {
    ctx.save();
    ctx.textAlign = 'left';
    ctx.fillStyle = '#64748b';
    ctx.font = '15px sans-serif';
    wrapText(ctx, footerNotes, 60, 725, width - 460, 22);
    ctx.restore();
  }

  // Firma
  if (showSignature) {
    ctx.save();
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
    ctx.restore();
  }
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

function generateOfflinePdfFromCanvas(canvas, fileName) {
  const dataUrl = canvas.toDataURL('image/jpeg', 0.95);
  const base64Data = dataUrl.split(',')[1];
  const binaryImg = atob(base64Data);
  const imgLen = binaryImg.length;
  const imgBytes = new Uint8Array(imgLen);
  for (let i = 0; i < imgLen; i++) {
    imgBytes[i] = binaryImg.charCodeAt(i);
  }

  const pageWidth = 842; // A4 horizontal en puntos tipográficos (~841.89 pt)
  const pageHeight = 595; // A4 horizontal (~595.28 pt)
  const imgW = 760;
  const imgH = +(imgW * (canvas.height / canvas.width)).toFixed(2);
  const imgX = +((pageWidth - imgW) / 2).toFixed(2);
  const imgY = +((pageHeight - imgH) / 2).toFixed(2);

  const enc = new TextEncoder();
  const parts = [];
  const offsets = [];

  function addString(str) {
    const b = enc.encode(str);
    parts.push(b);
    return b.length;
  }

  function addBytes(bytes) {
    parts.push(bytes);
    return bytes.length;
  }

  let currentOffset = 0;
  function markObj(num) {
    offsets[num] = currentOffset;
  }

  // Encabezado PDF 1.4 binario estándar
  currentOffset += addString('%PDF-1.4\n%\xFF\xFF\xFF\xFF\n');

  // Objeto 1: Catalog
  markObj(1);
  currentOffset += addString('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

  // Objeto 2: Pages
  markObj(2);
  currentOffset += addString('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');

  // Objeto 3: Page
  markObj(3);
  currentOffset += addString(
    `3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageWidth} ${pageHeight}] ` +
    `/Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n`
  );

  // Objeto 4: Image XObject (JPEG /DCTDecode)
  markObj(4);
  currentOffset += addString(
    `4 0 obj\n<< /Type /XObject /Subtype /Image /Width ${canvas.width} /Height ${canvas.height} ` +
    `/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${imgLen} >>\nstream\n`
  );
  currentOffset += addBytes(imgBytes);
  currentOffset += addString('\nendstream\nendobj\n');

  // Objeto 5: Page Content stream
  const contentStream = `q\n${imgW} 0 0 ${imgH} ${imgX} ${imgY} cm\n/Im1 Do\nQ\n`;
  const contentLen = enc.encode(contentStream).length;
  markObj(5);
  currentOffset += addString(`5 0 obj\n<< /Length ${contentLen} >>\nstream\n${contentStream}endstream\nendobj\n`);

  // Tabla Xref
  const xrefStart = currentOffset;
  let xrefStr = 'xref\n0 6\n0000000000 65535 f \n';
  for (let i = 1; i <= 5; i++) {
    const offStr = String(offsets[i]).padStart(10, '0');
    xrefStr += `${offStr} 00000 n \n`;
  }
  xrefStr += `trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xrefStart}\n%%EOF\n`;
  addString(xrefStr);

  // Consolidar buffer binario completo
  const totalLength = parts.reduce((acc, p) => acc + p.length, 0);
  const pdfBytes = new Uint8Array(totalLength);
  let pos = 0;
  for (const p of parts) {
    pdfBytes.set(p, pos);
    pos += p.length;
  }

  const blob = new Blob([pdfBytes], { type: 'application/pdf' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = fileName;
  link.click();
  setTimeout(() => URL.revokeObjectURL(link.href), 10000);
}

function sanitizeDownloadFileName(str) {
  return String(str || '').replace(/[\/\\:*?"<>|]/g, '_').replace(/\s+/g, '_');
}

function downloadReceiptPdf() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas) return;
  const isInvoice = currentReceiptData?.voucher_type === 'FAC';
  const correlative = currentReceiptData?.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const biz = sanitizeDownloadFileName(currentReceiptData?.client?.business_name || 'Cliente');
  const prefix = isInvoice ? 'Factura' : 'Boleta';
  const cleanCorrelative = sanitizeDownloadFileName(correlative);
  const fileName = `${prefix}_${cleanCorrelative}_${biz}.pdf`;

  try {
    generateOfflinePdfFromCanvas(canvas, fileName);
    showToast(`${prefix} ${correlative} descargada en PDF con éxito.`, 'success');
  } catch (e) {
    console.error('Error generando PDF offline:', e);
    showToast('Error al generar PDF: ' + e.message, 'error');
  }
}

function downloadReceiptPng() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas) return;
  const isInvoice = currentReceiptData?.voucher_type === 'FAC';
  const correlative = currentReceiptData?.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const biz = sanitizeDownloadFileName(currentReceiptData?.client?.business_name || 'Cliente');
  const prefix = isInvoice ? 'Factura' : 'Boleta';
  const cleanCorrelative = sanitizeDownloadFileName(correlative);
  const link = document.createElement('a');
  link.download = `${prefix}_${cleanCorrelative}_${biz}.png`;
  link.href = canvas.toDataURL('image/png');
  link.click();
  showToast(`${prefix} ${correlative} descargada en PNG con éxito.`, 'success');
}

async function copyReceiptToClipboard() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas) return;
  const isInvoice = currentReceiptData?.voucher_type === 'FAC';
  const correlative = currentReceiptData?.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const docName = isInvoice ? 'Factura' : 'Boleta';
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
        showToast(`${docName} ${correlative} copiada al portapapeles. ¡Lista para pegar con Ctrl+V en WhatsApp!`, 'success');
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
  const isInvoice = currentReceiptData.voucher_type === 'FAC';
  const correlative = currentReceiptData.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const amount = (parseFloat(payment.amount) || 0).toFixed(2);
  const titular = client.owner_name || client.business_name || 'Estimado cliente';
  const concept = payment.plan || 'Servicio MochilaLista';

  const docTypeName = isInvoice ? 'Factura de Pago Oficial' : 'Boleta de Pago Oficial';
  const docExtra = isInvoice ? 'fiscal para tu control tributario y administrativo' : 'para tu control contable';

  const msg = `¡Hola, ${titular}! Te saluda el equipo de MochilaLista.\n\n` +
    `Te hacemos entrega de tu *${docTypeName} N.° ${correlative}* por el monto de *S/ ${amount}* correspondiente a *${concept}*.\n\n` +
    `📌 Hemos adjuntado el comprobante digital ${docExtra}.\n\n` +
    `¡Muchas gracias por tu confianza y preferencia!`;

  closeReceiptModal();
  if (typeof openWhatsAppComposer === 'function' && client.id) {
    openWhatsAppComposer(client.id, null, {
      customMessage: msg,
      templateKey: 'custom'
    });
  } else if (typeof openWaComposerForClient === 'function' && client.id) {
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

window.openWaComposerForClient = function(clientId, options = {}) {
  return openWhatsAppComposer(clientId, options.templateKey || null, options);
};

async function saveReceiptDefaultDesign() {
  const isInvoice = currentReceiptData?.voucher_type === 'FAC';
  const title = document.getElementById('rcInputTitle')?.value.trim() || 'BOLETA DE PAGO ADMINISTRATIVA';
  const commercial = document.getElementById('rcInputCommercialName')?.value.trim() || 'MochilaLista';
  const issuer = document.getElementById('rcInputIssuerName')?.value.trim() || 'Julio Angello Vasquez Navarro';
  const issuerDoc = document.getElementById('rcInputIssuerDoc')?.value.trim() || 'D.N.I. / R.U.C. Registrado';
  const issuerPhone = document.getElementById('rcInputIssuerPhone')?.value.trim() || '+51 922 836 879';
  const issuerCity = document.getElementById('rcInputIssuerCity')?.value.trim() || 'Piura, Perú';
  const showLogo = document.getElementById('rcCheckShowLogo')?.checked !== false;
  const showIssuerDoc = document.getElementById('rcCheckShowIssuerDoc')?.checked !== false;
  const showIssuerPhone = document.getElementById('rcCheckShowIssuerPhone')?.checked !== false;
  const showClientDoc = document.getElementById('rcCheckShowClientDoc')?.checked !== false;
  const showHardwareId = document.getElementById('rcCheckShowHardwareId')?.checked !== false;
  const showOperationNumber = document.getElementById('rcCheckShowOperationNumber')?.checked !== false;
  const showObservation = document.getElementById('rcCheckShowObservation')?.checked !== false;
  const showSignature = document.getElementById('rcCheckShowSignature')?.checked !== false;
  const showFooterNotes = document.getElementById('rcCheckShowFooterNotes')?.checked !== false;
  const showIgv = document.getElementById('rcCheckShowIgv')?.checked === true;
  const accentColor = document.getElementById('rcInputAccentColor')?.value || '#2563eb';
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || '';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || '';

  const newRc = {
    title: isInvoice ? (ownerConfig?.receipt_config?.title || 'BOLETA DE PAGO ADMINISTRATIVA') : title,
    invoice_title: isInvoice ? title : (ownerConfig?.receipt_config?.invoice_title || 'FACTURA DE VENTA / PAGO'),
    commercial_name: commercial,
    issuer_name: issuer,
    issuer_doc: issuerDoc,
    issuer_phone: issuerPhone,
    issuer_city: issuerCity,
    show_logo: showLogo,
    show_issuer_doc: showIssuerDoc,
    show_issuer_phone: showIssuerPhone,
    show_client_doc: showClientDoc,
    show_hardware_id: showHardwareId,
    show_operation_number: showOperationNumber,
    show_observation: showObservation,
    show_signature: showSignature,
    show_footer_notes: showFooterNotes,
    show_igv_breakdown: showIgv,
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
    showToast('Diseño y preferencias de comprobante guardados con éxito.', 'success');
  } catch (e) {
    showToast('Error al guardar diseño: ' + e.message, 'error');
  }
}

function resetReceiptDefaultDesign() {
  const defaultRc = {
    title: 'BOLETA DE PAGO ADMINISTRATIVA',
    invoice_title: 'FACTURA DE VENTA / PAGO',
    commercial_name: 'MochilaLista',
    issuer_name: 'Julio Angello Vasquez Navarro',
    issuer_doc: 'D.N.I. / R.U.C. Registrado',
    issuer_phone: '+51 922 836 879',
    issuer_city: 'Piura, Perú',
    show_logo: true,
    show_issuer_doc: true,
    show_issuer_phone: true,
    show_client_doc: true,
    show_hardware_id: true,
    show_operation_number: true,
    show_observation: true,
    show_signature: true,
    show_footer_notes: true,
    show_igv_breakdown: false,
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
  const textInputs = [
    'rcInputTitle', 'rcInputCommercialName', 'rcInputIssuerName',
    'rcInputIssuerDoc', 'rcInputIssuerPhone', 'rcInputIssuerCity',
    'rcInputAccentColor', 'rcInputCustomNote', 'rcInputFooterNotes',
    'rcInputSignature', 'rcInputInvoiceRuc', 'rcInputInvoiceBizName',
    'rcInputInvoiceAddress'
  ];
  textInputs.forEach(id => {
    document.getElementById(id)?.addEventListener('input', () => {
      renderReceiptPreviewAndCanvas();
    });
  });

  // Selector de Tipo de Comprobante (BOL vs FAC)
  document.getElementById('rcSelectVoucherType')?.addEventListener('change', (e) => {
    switchReceiptVoucherType(e.target.value);
  });

  // Checkbox de IGV 18%
  document.getElementById('rcCheckShowIgv')?.addEventListener('change', () => {
    renderReceiptPreviewAndCanvas();
  });

  // 9 Interruptores de visibilidad
  const toggleCheckIds = [
    'rcCheckShowLogo', 'rcCheckShowIssuerDoc', 'rcCheckShowIssuerPhone',
    'rcCheckShowClientDoc', 'rcCheckShowHardwareId', 'rcCheckShowOperationNumber',
    'rcCheckShowObservation', 'rcCheckShowSignature', 'rcCheckShowFooterNotes'
  ];
  toggleCheckIds.forEach(id => {
    document.getElementById(id)?.addEventListener('change', () => {
      renderReceiptPreviewAndCanvas();
    });
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
  document.getElementById('btnRcDownloadPdf')?.addEventListener('click', downloadReceiptPdf);
  document.getElementById('btnRcCopyClipboard')?.addEventListener('click', copyReceiptToClipboard);
  document.getElementById('btnRcPrintPdf')?.addEventListener('click', printReceiptPdf);
  document.getElementById('btnRcSendWhatsapp')?.addEventListener('click', sendReceiptViaWhatsapp);
}

// =================== GESTIÓN GLOBAL DE PESTAÑAS EN DRAWER 360° (FASE 2 PLAN 18.5) ===================
function switchDrawerTab(targetTabId) {
  const normalizedId = (targetTabId === 'drawerTabSummary') ? 'drawerTabOverview' : targetTabId;
  currentDrawerTab = normalizedId;
  const dtabs = document.querySelectorAll('.drawer-tab-btn');
  dtabs.forEach(b => {
    if (b.dataset.dtab === normalizedId) {
      b.classList.add('active');
    } else {
      b.classList.remove('active');
    }
  });
  document.querySelectorAll('.drawer-tab-pane').forEach(p => {
    if (p.id === normalizedId) {
      p.classList.add('active');
    } else {
      p.classList.remove('active');
    }
  });

  if (normalizedId === 'drawerTabEdit') {
    setTimeout(() => {
      const followupInput = document.getElementById('drawerEditFollowupDate');
      if (followupInput) {
        followupInput.focus();
        followupInput.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 150);
  }
}
window.switchDrawerTab = switchDrawerTab;

function initDrawerEvents() {
  const dtabs = document.querySelectorAll('.drawer-tab-btn');
  dtabs.forEach(btn => {
    btn.addEventListener('click', () => {
      switchDrawerTab(btn.dataset.dtab);
    });
  });

  // Botón rápido en datos de contacto "Editar Seguimiento / Notas"
  document.getElementById('btnDrawerQuickEditFollowup')?.addEventListener('click', (e) => {
    e.preventDefault();
    switchDrawerTab('drawerTabEdit');
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
    const followup = document.getElementById('drawerEditFollowupDate')?.value || null;
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
          next_followup_date: followup,
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
  switchDrawerTab(targetTabId);

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
  document.getElementById('drawerKpiPlan').textContent = isProspect ? 'Prospecto' : formatPlanHumanLabel(client.license_type);
  document.getElementById('drawerKpiExpires').textContent = isProspect
    ? (client.expected_subscription_date ? `Seguimiento: ${client.expected_subscription_date}` : 'Sin vencimiento')
    : (isPerp ? 'De por Vida' : (client.license_expires ? client.license_expires.substring(0, 10) : 'Sin fecha'));

  const realAi = (client.ai_reported_balance !== undefined && client.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client.ai_accumulated_credits ?? client.ai_extra_credits ?? 0);
  const pendingAi = client.ai_pending_bonus || 0;

  document.getElementById('drawerKpiAiCredits').textContent = `${realAi} IA`;
  document.getElementById('drawerKpiVersion').textContent = `v${client.installed_version || '9.35.0'}`;
  
  const drawerKpiUpdates = document.getElementById('drawerBoxUpdates')?.querySelector('.drawer-kpi-val') || document.getElementById('drawerKpiUpdates');
  if (drawerKpiUpdates) {
    if (isPerp || plan === 'PASE_ACTUALIZACION_ANUAL') {
      drawerKpiUpdates.textContent = client.updates_until ? client.updates_until.substring(0, 10) : 'Vigente';
    } else if (isProspect || isTrial) {
      drawerKpiUpdates.textContent = 'No aplica';
    } else {
      drawerKpiUpdates.textContent = 'Incluido en suscripción';
    }
  }

  document.getElementById('drawerPhone').textContent = formatPeruvianPhoneDisplay(client.phone);
  document.getElementById('drawerDocId').textContent = client.document_id || '-';
  const drawerDeviceModel = document.getElementById('drawerDeviceModel');
  if (drawerDeviceModel) {
    drawerDeviceModel.textContent = client.device_model || 'No registrado';
  }
  const drawerAiBreakdown = document.getElementById('drawerAiBreakdown');
  if (drawerAiBreakdown) {
    const usedAi = client.ai_credits_used_total ?? 0;
    const deltaAi = client.ai_credits_used_delta ?? 0;
    const deltaTxt = deltaAi > 0 ? ` (+${deltaAi} reciente)` : '';
    drawerAiBreakdown.textContent = `En celular: ${realAi} IA | Consumidos: ${usedAi} IA${deltaTxt} | Bono pend: +${pendingAi} IA`;
  }
  const drawerLastSync = document.getElementById('drawerLastSync');
  if (drawerLastSync) {
    if (client.last_sync_at) {
      drawerLastSync.textContent = formatLimaDateTime(client.last_sync_at);
      drawerLastSync.title = `UTC: ${client.last_sync_at}`;
    } else {
      drawerLastSync.textContent = 'Nunca sincronizado';
      drawerLastSync.title = '';
    }
  }
  const drawerBackupDrive = document.getElementById('drawerBackupDrive');
  if (drawerBackupDrive) {
    if (client.backup_drive_linked) {
      const bh = humanizeSyncFieldValue('backup_health_status', client.backup_health_status || 'OK');
      drawerBackupDrive.textContent = `Vinculado (${bh})`;
    } else {
      drawerBackupDrive.textContent = 'No vinculado';
    }
  }
  const drawerProfilesCount = document.getElementById('drawerProfilesCount');
  if (drawerProfilesCount) {
    drawerProfilesCount.textContent = (client.profiles_count !== undefined && client.profiles_count !== null)
      ? String(client.profiles_count)
      : '-';
  }
  const drawerUltimoNonce = document.getElementById('drawerUltimoNonce');
  if (drawerUltimoNonce) {
    drawerUltimoNonce.textContent = (client.ultimo_nonce !== undefined && client.ultimo_nonce !== null)
      ? `#${client.ultimo_nonce}`
      : 'Sin reporte';
  }
  const drawerFollowup = document.getElementById('drawerFollowup');
  if (drawerFollowup) {
    if (client.next_followup_date) {
      const todayStr = getLocalIsoDate();
      if (client.next_followup_date < todayStr) {
        drawerFollowup.innerHTML = `<span style="color:var(--danger); font-weight:700;">Vencido (${escapeHtml(client.next_followup_date)})</span>`;
      } else if (client.next_followup_date === todayStr) {
        drawerFollowup.innerHTML = `<span style="color:var(--warning); font-weight:700;">¡Hoy! (${escapeHtml(client.next_followup_date)})</span>`;
      } else {
        drawerFollowup.innerHTML = `<span style="color:var(--primary); font-weight:600;">Programado (${escapeHtml(client.next_followup_date)})</span>`;
      }
    } else {
      drawerFollowup.textContent = 'Sin programar';
    }
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
  const editFollowup = document.getElementById('drawerEditFollowupDate');
  if (editFollowup) editFollowup.value = client.next_followup_date ? client.next_followup_date.substring(0, 10) : '';
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
              <div class="dpc-concept-wrap" style="display:flex; align-items:center; gap:0.4rem; flex-wrap:wrap;">
                <span class="dpc-date">${escapeHtml(pDate)}</span>
                <span class="badge badge-mono">${escapeHtml(formatPlanHumanLabel(p.plan || '-'))}</span>
                ${p.updated_at ? `
                  <span class="badge-edited-payment" title="Pago editado el ${escapeHtml(p.updated_at.substring(0, 10))} ${escapeHtml(p.updated_at.substring(11, 16))} UTC">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:middle;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                    <span>Editado</span>
                  </span>
                ` : ''}
                ${p.receipt_number ? `
                  <button type="button" class="btn-micro-receipt" onclick="openPaymentReceiptModal('${clientId}', '${p.id}')" title="Ver / Reimprimir Comprobante Oficial">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:middle; margin-right:2px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
                    <span>${escapeHtml(p.receipt_number)}</span>
                  </button>
                ` : ''}
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
              <td style="white-space: nowrap; min-width: 96px;">${h.migrated_at ? h.migrated_at.substring(0, 10) : '-'}</td>
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
                  <button type="button" class="btn btn-primary btn-xs btn-save-reason" style="padding:2px 5px;" title="Guardar motivo">
                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                  </button>
                  <button type="button" class="btn btn-outline btn-xs btn-cancel-reason" style="padding:2px 5px;" title="Cancelar">
                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                  </button>
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

  // Preset inteligente homologado
  const presetSel = document.getElementById('manualPayPlanPreset');
  const customConcept = document.getElementById('manualPayCustomConcept');
  if (presetSel) {
    presetSel.value = 'MENSUAL';
    if (customConcept) {
      customConcept.value = '';
      customConcept.style.display = 'none';
    }
  }

  const defaultPrice = ownerConfig?.catalog?.['MENSUAL']?.price ?? 35.0;
  document.getElementById('manualPayAmount').value = parseFloat(defaultPrice).toFixed(2);
  document.getElementById('manualPayPlan').value = 'MENSUAL';
  document.getElementById('manualPayMethod').value = 'Yape';
  document.getElementById('manualPayRef').value = '';
  document.getElementById('manualPayNotes').value = '';

  // Banner y Checkbox de Comprobante
  const receiptNotice = document.getElementById('manualPayReceiptNotice');
  if (receiptNotice) receiptNotice.style.display = 'none';
  const receiptLabel = document.getElementById('manualPayGenerateReceiptLabel');
  if (receiptLabel) receiptLabel.textContent = 'Generar Boleta de Pago al guardar (Abre comprobante BOL-XXXX de inmediato)';
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
  document.getElementById('manualPayAmount').value = parseFloat(payment.amount ?? 0).toFixed(2);

  // Matching de slug canónico con retrocompatibilidad o fallback a CUSTOM
  const presetSel = document.getElementById('manualPayPlanPreset');
  const customConcept = document.getElementById('manualPayCustomConcept');
  const planVal = payment.plan || '';
  const slug = normalizePlanToSlug(planVal);

  if (slug && presetSel) {
    presetSel.value = slug;
    if (customConcept) {
      customConcept.value = '';
      customConcept.style.display = 'none';
    }
    document.getElementById('manualPayPlan').value = slug;
  } else {
    if (presetSel) presetSel.value = 'CUSTOM';
    if (customConcept) {
      customConcept.value = planVal;
      customConcept.style.display = 'block';
    }
    document.getElementById('manualPayPlan').value = planVal;
  }

  document.getElementById('manualPayMethod').value = payment.method || 'Yape';
  document.getElementById('manualPayRef').value = payment.reference || '';
  document.getElementById('manualPayNotes').value = payment.notes || '';

  // Blindaje contable de comprobante previo
  const receiptNotice = document.getElementById('manualPayReceiptNotice');
  const receiptBadge = document.getElementById('manualPayReceiptNumberBadge');
  const receiptLabel = document.getElementById('manualPayGenerateReceiptLabel');
  const genReceiptChk = document.getElementById('manualPayGenerateReceipt');

  if (payment.receipt_number) {
    if (receiptNotice) receiptNotice.style.display = 'flex';
    if (receiptBadge) receiptBadge.textContent = payment.receipt_number;
    if (receiptLabel) receiptLabel.textContent = `Abrir comprobante ${payment.receipt_number} actualizado al guardar`;
    if (genReceiptChk) genReceiptChk.checked = true;
  } else {
    if (receiptNotice) receiptNotice.style.display = 'none';
    if (receiptLabel) receiptLabel.textContent = 'Generar Boleta de Pago al guardar (Abre comprobante BOL-XXXX de inmediato)';
    if (genReceiptChk) genReceiptChk.checked = false;
  }

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
 * Apertura del Modal para Sincronizar Datos Reportados en Celular (Fase 4 Plan 19)
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

  // Limpiar panel de importación y análisis previo
  const syncRawInput = document.getElementById('syncRawInput');
  if (syncRawInput) syncRawInput.value = '';
  const syncAnalysisResult = document.getElementById('syncAnalysisResult');
  if (syncAnalysisResult) {
    syncAnalysisResult.style.display = 'none';
    syncAnalysisResult.dataset.parsedToken = '';
    syncAnalysisResult.dataset.parsedRaw = '';
  }
  updateSyncApplyButtonState(document.getElementById('btnApplySyncReported'), false, 'Aplicar Sincronización en Ficha');

  // Activar pestaña principal de importación por defecto
  switchSyncReportedTab('import');

  // Rellenar formulario manual existente como fallback
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
 * Conmutador de Pestañas en Modal de Sincronización
 */
function switchSyncReportedTab(tab) {
  const btnImport = document.getElementById('tabBtnSyncImport');
  const btnManual = document.getElementById('tabBtnSyncManual');
  const paneImport = document.getElementById('syncPaneImport');
  const paneManual = document.getElementById('syncPaneManual');

  if (tab === 'import') {
    btnImport?.classList.add('active', 'btn-primary');
    btnImport?.classList.remove('btn-outline');
    btnManual?.classList.remove('active', 'btn-primary');
    btnManual?.classList.add('btn-outline');
    if (paneImport) paneImport.style.display = 'block';
    if (paneManual) paneManual.style.display = 'none';
  } else {
    btnManual?.classList.add('active', 'btn-primary');
    btnManual?.classList.remove('btn-outline');
    btnImport?.classList.remove('active', 'btn-primary');
    btnImport?.classList.add('btn-outline');
    if (paneImport) paneImport.style.display = 'none';
    if (paneManual) paneManual.style.display = 'block';
  }
}

/**
 * Convierte timestamps ISO UTC o epoch ms a hora oficial Perú (America/Lima, GMT-5)
 * con formato DD/MM/YYYY HH:mm:ss (Lima GMT-5) y fallback aritmético determinista -5h.
 */
function formatLimaDateTime(isoOrEpoch, fallback = '-') {
  if (isoOrEpoch === null || isoOrEpoch === undefined || isoOrEpoch === '') return fallback;
  let dateObj = null;
  if (typeof isoOrEpoch === 'number') {
    dateObj = new Date(isoOrEpoch);
  } else {
    const raw = String(isoOrEpoch).trim();
    if (!raw || raw === '-' || raw === 'Nunca' || raw === 'Sin respaldos' || raw === 'Sin copias registradas' || raw === 'No aplica') {
      return raw || fallback;
    }
    if (/^\d{10,13}$/.test(raw)) {
      const n = Number(raw);
      dateObj = new Date(raw.length === 10 ? n * 1000 : n);
    } else {
      dateObj = new Date(raw);
    }
  }
  if (!dateObj || Number.isNaN(dateObj.getTime())) {
    return String(isoOrEpoch);
  }

  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: 'America/Lima',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    }).formatToParts(dateObj);
    const map = {};
    parts.forEach(p => { map[p.type] = p.value; });
    const hh = map.hour === '24' ? '00' : map.hour;
    return `${map.day}/${map.month}/${map.year} ${hh}:${map.minute}:${map.second} (Lima GMT-5)`;
  } catch (_) {
    const lima = new Date(dateObj.getTime() - 5 * 60 * 60 * 1000);
    const pad = (n) => String(n).padStart(2, '0');
    return `${pad(lima.getUTCDate())}/${pad(lima.getUTCMonth() + 1)}/${lima.getUTCFullYear()} ${pad(lima.getUTCHours())}:${pad(lima.getUTCMinutes())}:${pad(lima.getUTCSeconds())} (Lima GMT-5)`;
  }
}

/**
 * Humaniza campos técnicos de sincronización .mlsync al español operativo del propietario.
 */
function humanizeSyncFieldValue(field, val) {
  if (field === 'backup_drive_linked' || field === 'uses_byok' || field === 'drv' || field === 'byok' || typeof val === 'boolean') {
    if (val === true || String(val).toLowerCase() === 'true') return 'Sí';
    if (val === false || String(val).toLowerCase() === 'false') return 'No';
  }
  if (field === 'backup_health_status' || field === 'bh') {
    const norm = String(val ?? 'NONE').trim().toUpperCase();
    if (norm === 'OK' || norm === 'OPTIMAL') return 'Óptimo';
    if (norm === 'ATTENTION') return 'Requiere atención';
    if (norm === 'CRITICAL') return 'Crítico';
    if (norm === 'NONE' || norm === '-' || norm === '') return 'Sin respaldo';
    return String(val);
  }
  if (field === 'last_backup_at' || field === 'last_sync_at' || field === 'lb' || field === 'ts') {
    return formatLimaDateTime(val, 'Sin respaldos');
  }
  if (val === null || val === undefined || val === '') return '-';
  return String(val);
}

function updateSyncApplyButtonState(btn, isAllUnchanged, defaultLabel = 'Aplicar Sincronización') {
  if (!btn) return;
  const checkIcon = '<svg class="btn-icon" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>';
  if (isAllUnchanged) {
    btn.classList.remove('btn-primary');
    btn.classList.add('btn-outline');
    btn.innerHTML = `${checkIcon} Re-confirmar Ficha`;
  } else {
    btn.classList.remove('btn-outline');
    btn.classList.add('btn-primary');
    btn.innerHTML = `${checkIcon} ${escapeHtml(defaultLabel)}`;
  }
}

/**
 * Generador HTML de Tabla Diff Estructurada: Antes (Admin) -> Real (Celular)
 */
function renderSyncDiffTable(changes, meta = {}) {
  if (!changes || !changes.length) {
    return '<p style="color:var(--text-muted); font-size:0.83rem;">No se detectaron diferencias respecto a los datos actuales.</p>';
  }

  let bannerHtml = '';
  const allUnchanged = Boolean(meta.allUnchanged ?? meta.all_unchanged ?? changes.every(c => !c.is_different && !c.changed));
  const sameTimestamp = Boolean(meta.sameTimestamp ?? meta.same_timestamp);
  if (allUnchanged || sameTimestamp) {
    bannerHtml = `
      <div class="sync-all-unchanged-banner">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" style="flex-shrink:0;"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
        <span>La ficha coincide al 100% con el estado actual del CRM — Sin cambios por aplicar</span>
      </div>
    `;
  }

  let rowsHtml = '';
  changes.forEach(c => {
    const isChanged = Boolean(c.changed || c.is_different);
    const rowClass = isChanged ? 'sync-diff-row-changed' : '';
    const badgeHtml = isChanged
      ? '<span class="sync-diff-badge-changed">Modificado</span>'
      : '<span class="sync-diff-badge-same">Sin cambios</span>';

    const beforeRaw = c.before;
    const afterRaw = c.after;
    const beforeDisplay = humanizeSyncFieldValue(c.field, beforeRaw);
    const afterDisplay = humanizeSyncFieldValue(c.field, afterRaw);

    const isDateField = c.type === 'datetime' || c.field === 'last_backup_at' || c.field === 'last_sync_at';
    const beforeTitleAttr = (isDateField && beforeRaw && beforeRaw !== 'Nunca' && beforeRaw !== 'Sin respaldos')
      ? ` title="UTC: ${escapeHtml(String(beforeRaw))}"`
      : '';
    const afterTitleAttr = (isDateField && afterRaw && afterRaw !== 'Nunca' && afterRaw !== 'Sin respaldos')
      ? ` title="UTC: ${escapeHtml(String(afterRaw))}"`
      : '';

    const deltaHtml = (c.field === 'ai_credits_used_total' && typeof c.delta === 'number' && c.delta > 0)
      ? `<span class="sync-diff-delta-pill">(+${c.delta} desde última sync)</span>`
      : '';

    rowsHtml += `
      <tr class="${rowClass}">
        <td><strong>${escapeHtml(c.label || c.field)}</strong></td>
        <td class="sync-diff-before"${beforeTitleAttr}>${escapeHtml(beforeDisplay)}</td>
        <td class="sync-diff-after"${afterTitleAttr}>${escapeHtml(afterDisplay)}${deltaHtml}</td>
        <td>${badgeHtml}</td>
      </tr>
    `;
  });

  return `
    ${bannerHtml}
    <div style="font-weight:700; font-size:0.86rem; color:var(--text-primary); margin-bottom:0.35rem;">
      Comparador: Antes (Admin) &rarr; Real (Celular)
    </div>
    <div class="table-responsive">
      <table class="sync-diff-table">
        <thead>
          <tr>
            <th>Métrica / Campo</th>
            <th>Antes (Admin)</th>
            <th>Real (Celular)</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          ${rowsHtml}
        </tbody>
      </table>
    </div>
  `;
}

/**
 * Analizar Ficha de Sincronización en #modalSyncReported
 */
async function analyzeSyncReported() {
  const clientId = document.getElementById('syncRepClientId').value;
  if (!clientId) return;
  const rawInput = document.getElementById('syncRawInput').value.trim();
  if (!rawInput) {
    showToast('Pega el código MLS1-... o arrastra un archivo .mlsync primero.', 'warning');
    return;
  }

  try {
    const res = await fetch('/api/sync/parse', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        raw_input: rawInput,
        expected_client_id: clientId,
      }),
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || 'Error al analizar ficha de sincronización');
    }

    const container = document.getElementById('syncAnalysisResult');
    const badgeEl = document.getElementById('syncHmacBadge');
    const hwMismatchEl = document.getElementById('syncHwMismatchAlert');
    const rescueEl = document.getElementById('syncRescueCard');
    const staleEl = document.getElementById('syncStaleWarning');
    const diffContainer = document.getElementById('syncDiffContainer');

    container.style.display = 'block';
    container.dataset.parsedRaw = rawInput;

    // 1. Sello HMAC
    if (data.valid) {
      badgeEl.className = 'sync-hmac-badge valid';
      badgeEl.innerHTML = `
        <svg class="sync-hmac-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg>
        <span>Integridad HMAC-SHA256 Verificada con éxito. Reporte auténtico de la app móvil.</span>
      `;
    } else {
      badgeEl.className = 'sync-hmac-badge invalid';
      badgeEl.innerHTML = `
        <svg class="sync-hmac-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <span>Firma HMAC-SHA256 Inválida o Alterada (${escapeHtml(data.error_code || 'INVALID_SIGNATURE')}).</span>
      `;
    }

    // 2. Hardware ID Mismatch Warning
    const client = globalClients.find(c => c.id === clientId);
    const p = data.payload || {};
    if (p.hw && client && client.current_device_id && client.current_device_id !== 'PENDIENTE' && p.hw !== client.current_device_id && data.match_type !== 'MIGRATION_SOURCE') {
      hwMismatchEl.style.display = 'block';
      hwMismatchEl.innerHTML = `
        <strong>Advertencia de Hardware:</strong> El reporte pertenece a <code>${escapeHtml(p.hw)}</code>, pero la ficha abierta es <code>${escapeHtml(client.current_device_id)}</code>.
      `;
    } else {
      hwMismatchEl.style.display = 'none';
    }

    // 3. Rescate PENDIENTE_MIGRACION
    if (data.migration_rescue && data.migration_rescue.detected) {
      rescueEl.style.display = 'block';
      const mr = data.migration_rescue;
      const oldHw = escapeHtml(mr.old_hardware_id || '-');
      const newHw = escapeHtml(mr.new_hardware_id || '-');
      const modelStr = mr.device_model ? ` • ${escapeHtml(mr.device_model)}` : '';
      rescueEl.innerHTML = `
        <div class="sync-rescue-header">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
          <span>Dispositivo Bloqueado por Migración / Restauración</span>
        </div>
        <div class="sync-rescue-body">
          <div class="sync-rescue-hw-flow">
            <span class="sync-rescue-hw-old">Celular anterior (bhw): ${oldHw}</span>
            <span class="sync-rescue-hw-arrow">&rarr;</span>
            <span class="sync-rescue-hw-new">Nuevo celular (hw): ${newHw}${modelStr}</span>
          </div>
          <p style="margin:0.25rem 0 0.5rem 0; font-size:0.8rem; color:var(--text-secondary);">
            La app móvil reporta estado <code>PENDIENTE_MIGRACION</code> tras restaurar un respaldo en un equipo diferente. Puedes transferir la licencia y autorizar el nuevo equipo sin costo y sin duplicar días.
          </p>
        </div>
        <div style="display:flex; justify-content:flex-end;">
          <button type="button" class="btn btn-warning btn-sm" id="btnSyncRescueMigrate">
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
            Migrar Dispositivo (Restauración — 0 días)
          </button>
        </div>
      `;

      document.getElementById('btnSyncRescueMigrate')?.addEventListener('click', () => {
        closeModal('modalSyncReported');
        const targetClientId = (data.matched_client && data.matched_client.id) ? data.matched_client.id : clientId;
        openMigrateModal(targetClientId, {
          newDeviceId: mr.new_hardware_id,
          newDeviceModel: mr.device_model,
          scenario: 'RESTORED_BACKUP'
        });
      });
    } else {
      rescueEl.style.display = 'none';
    }

    // 4. Anti-Sobreescritura por reporte antiguo
    if (data.is_older_than_last_sync) {
      staleEl.style.display = 'block';
      staleEl.innerHTML = `
        <div class="sync-stale-banner">
          <strong>Aviso Anti-Sobreescritura:</strong> Esta ficha técnica tiene fecha de reporte anterior a la última sincronización guardada.
          <div style="margin-top:0.4rem;">
            <label style="display:inline-flex; align-items:center; gap:0.4rem; cursor:pointer; font-weight:600;">
              <input type="checkbox" id="chkForceOlderSync"> Confirmar sobrescritura con ficha más antigua
            </label>
          </div>
        </div>
      `;
    } else {
      staleEl.style.display = 'none';
    }

    // 5. Tabla Diff + Adaptación botón Re-confirmar Ficha
    const allUnchanged = Boolean(data.all_unchanged ?? data.analysis?.all_unchanged);
    const sameTimestamp = Boolean(data.same_timestamp ?? data.analysis?.same_timestamp);
    diffContainer.innerHTML = renderSyncDiffTable(data.changes || [], { allUnchanged, sameTimestamp });
    updateSyncApplyButtonState(
      document.getElementById('btnApplySyncReported'),
      allUnchanged || sameTimestamp,
      'Aplicar Sincronización en Ficha'
    );
    showToast('Ficha de sincronización analizada.', 'success');
  } catch (err) {
    showToast('Error al analizar ficha: ' + err.message, 'error');
  }
}

/**
 * Aplicar Sincronización en #modalSyncReported
 */
async function applySyncReported() {
  const clientId = document.getElementById('syncRepClientId').value;
  if (!clientId) return;
  const container = document.getElementById('syncAnalysisResult');
  const rawInput = container?.dataset.parsedRaw || document.getElementById('syncRawInput').value.trim();
  if (!rawInput) {
    showToast('Por favor analiza una ficha de sincronización primero.', 'warning');
    return;
  }

  const forceOlder = document.getElementById('chkForceOlderSync')?.checked || false;

  try {
    const res = await fetch('/api/sync/apply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: clientId,
        raw_input: rawInput,
        force_older: forceOlder,
      }),
    });

    const data = await res.json();
    if (!res.ok) {
      if (res.status === 409) {
        showToast('Conflicto: El reporte es anterior a la última sincronización. Marca la casilla de confirmación para sobrescribir.', 'warning');
        return;
      }
      throw new Error(data.error || 'Error al aplicar sincronización');
    }

    showToast('¡Datos del celular sincronizados con éxito!', 'success');
    await loadClients();
    await loadDashboard();
    await loadReleaseMatrix();
    if (currentDrawerClientId === clientId) {
      await openClient360Drawer(clientId, 'drawerTabOverview');
    }
    closeModal('modalSyncReported');
  } catch (err) {
    showToast('Error al aplicar sincronización: ' + err.message, 'error');
  }
}

/**
 * Modal Global de Importación de Ficha Offline (.mlsync / MLS1)
 */
function openGlobalClientSyncModal() {
  const rawInput = document.getElementById('globalSyncRawInput');
  if (rawInput) rawInput.value = '';
  const resultContainer = document.getElementById('globalSyncResultContainer');
  if (resultContainer) {
    resultContainer.style.display = 'none';
    resultContainer.dataset.parsedRaw = '';
    resultContainer.dataset.targetClientId = '';
  }
  const footer = document.getElementById('globalSyncModalFooter');
  if (footer) footer.style.display = 'none';
  updateSyncApplyButtonState(document.getElementById('btnApplyGlobalSync'), false, 'Aplicar Sincronización');
  openModal('modalGlobalClientSync');
}

async function analyzeGlobalSync() {
  const rawInput = document.getElementById('globalSyncRawInput').value.trim();
  if (!rawInput) {
    showToast('Pega el código MLS1-... o arrastra un archivo .mlsync primero.', 'warning');
    return;
  }

  try {
    const res = await fetch('/api/sync/parse', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ raw_input: rawInput }),
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || 'Error al analizar ficha');
    }

    const container = document.getElementById('globalSyncResultContainer');
    const badgeEl = document.getElementById('globalSyncHmacBadge');
    const rescueEl = document.getElementById('globalSyncRescueCard');
    const matchEl = document.getElementById('globalSyncClientMatchCard');
    const diffContainer = document.getElementById('globalSyncDiffContainer');
    const staleEl = document.getElementById('globalSyncStaleWarning');
    const footer = document.getElementById('globalSyncModalFooter');

    container.style.display = 'block';
    container.dataset.parsedRaw = rawInput;

    // 1. Sello HMAC
    if (data.valid) {
      badgeEl.className = 'sync-hmac-badge valid';
      badgeEl.innerHTML = `
        <svg class="sync-hmac-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg>
        <span>Integridad HMAC-SHA256 Verificada con éxito. Reporte auténtico de la app móvil.</span>
      `;
    } else {
      badgeEl.className = 'sync-hmac-badge invalid';
      badgeEl.innerHTML = `
        <svg class="sync-hmac-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <span>Firma HMAC-SHA256 Inválida o Alterada (${escapeHtml(data.error_code || 'INVALID_SIGNATURE')}).</span>
      `;
    }

    const p = data.payload || {};

    // 2. Rescate PENDIENTE_MIGRACION
    if (data.migration_rescue && data.migration_rescue.detected) {
      rescueEl.style.display = 'block';
      const mr = data.migration_rescue;
      const oldHw = escapeHtml(mr.old_hardware_id || '-');
      const newHw = escapeHtml(mr.new_hardware_id || '-');
      const modelStr = mr.device_model ? ` • ${escapeHtml(mr.device_model)}` : '';
      const clientName = data.matched_client ? `${escapeHtml(data.matched_client.business_name)} (${escapeHtml(data.matched_client.owner_name)})` : 'Cliente Origen';
      rescueEl.innerHTML = `
        <div class="sync-rescue-header">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
          <span>Dispositivo Bloqueado por Migración / Restauración</span>
        </div>
        <div class="sync-rescue-body">
          <div><strong>Titular Detectado:</strong> ${clientName}</div>
          <div class="sync-rescue-hw-flow">
            <span class="sync-rescue-hw-old">Celular anterior (bhw): ${oldHw}</span>
            <span class="sync-rescue-hw-arrow">&rarr;</span>
            <span class="sync-rescue-hw-new">Nuevo celular (hw): ${newHw}${modelStr}</span>
          </div>
          <p style="margin:0.25rem 0 0.5rem 0; font-size:0.8rem; color:var(--text-secondary);">
            La app móvil reporta estado <code>PENDIENTE_MIGRACION</code>. Puedes reactivar el nuevo celular transfiriendo sus derechos comerciales con 0 días extra.
          </p>
        </div>
        <div style="display:flex; justify-content:flex-end;">
          <button type="button" class="btn btn-warning btn-sm" id="btnGlobalSyncRescueMigrate">
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
            Migrar Dispositivo (Restauración — 0 días)
          </button>
        </div>
      `;

      document.getElementById('btnGlobalSyncRescueMigrate')?.addEventListener('click', () => {
        closeModal('modalGlobalClientSync');
        if (data.matched_client && data.matched_client.id) {
          openMigrateModal(data.matched_client.id, {
            newDeviceId: mr.new_hardware_id,
            newDeviceModel: mr.device_model,
            scenario: 'RESTORED_BACKUP'
          });
        }
      });
      if (footer) footer.style.display = 'none';
      matchEl.style.display = 'none';
      diffContainer.innerHTML = '';
      staleEl.style.display = 'none';
      return;
    } else {
      rescueEl.style.display = 'none';
    }

    // 3. Cliente Coincidente o Nuevo Cliente
    if (data.matched_client) {
      const c = data.matched_client;
      container.dataset.targetClientId = c.id;
      matchEl.style.display = 'block';
      matchEl.innerHTML = `
        <div class="sync-client-match-card">
          <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem;">
            <div>
              <strong style="color:var(--text-primary); font-size:1rem;">${escapeHtml(c.business_name)}</strong>
              <div style="font-size:0.82rem; color:var(--text-secondary); margin-top:2px;">
                ${escapeHtml(c.owner_name)} • WhatsApp: <strong>${escapeHtml(c.phone)}</strong>
              </div>
            </div>
            <code style="font-family:var(--font-mono); color:var(--primary); font-weight:700;">${escapeHtml(c.current_device_id || '-')}</code>
          </div>
        </div>
      `;

      // Anti-Sobreescritura
      if (data.is_older_than_last_sync) {
        staleEl.style.display = 'block';
        staleEl.innerHTML = `
          <div class="sync-stale-banner">
            <strong>Aviso Anti-Sobreescritura:</strong> Esta ficha técnica tiene fecha de reporte anterior a la última sincronización guardada.
            <div style="margin-top:0.4rem;">
              <label style="display:inline-flex; align-items:center; gap:0.4rem; cursor:pointer; font-weight:600;">
                <input type="checkbox" id="chkGlobalForceOlderSync"> Confirmar sobrescritura con ficha más antigua
              </label>
            </div>
          </div>
        `;
      } else {
        staleEl.style.display = 'none';
      }

      const allUnchanged = Boolean(data.all_unchanged ?? data.analysis?.all_unchanged);
      const sameTimestamp = Boolean(data.same_timestamp ?? data.analysis?.same_timestamp);
      diffContainer.innerHTML = renderSyncDiffTable(data.changes || [], { allUnchanged, sameTimestamp });
      updateSyncApplyButtonState(
        document.getElementById('btnApplyGlobalSync'),
        allUnchanged || sameTimestamp,
        'Aplicar Sincronización'
      );
      if (footer) footer.style.display = 'flex';
    } else {
      // Nuevo cliente no registrado
      container.dataset.targetClientId = '';
      matchEl.style.display = 'block';
      matchEl.innerHTML = `
        <div class="sync-client-match-card" style="border-left:4px solid var(--primary);">
          <div style="font-weight:700; color:var(--primary); font-size:0.95rem; margin-bottom:0.25rem;">
            Nuevo Celular No Registrado en Cartera
          </div>
          <div style="font-size:0.84rem; color:var(--text-secondary); margin-bottom:0.75rem;">
            Hardware ID: <code style="font-family:var(--font-mono); font-weight:700; color:var(--text-primary);">${escapeHtml(p.hw || '-')}</code>
            • Modelo: <strong>${escapeHtml(p.mod || 'No especificado')}</strong>
            • Versión APK: <strong>v${escapeHtml(p.av || '-')}</strong>
            • Saldo IA: <strong>${p.ai || 0} IA</strong>
          </div>
          <button type="button" class="btn btn-primary btn-sm" id="btnGlobalSyncCreateClient">
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            Registrar Nuevo Cliente con estos datos
          </button>
        </div>
      `;

      document.getElementById('btnGlobalSyncCreateClient')?.addEventListener('click', () => {
        closeModal('modalGlobalClientSync');
        const modalCreate = document.getElementById('modalCreateClient');
        if (modalCreate) {
          openModal('modalCreateClient');
          const devInp = document.getElementById('clientDeviceId') || document.getElementById('newClientDeviceId');
          if (devInp) devInp.value = p.hw || '';
          const modInp = document.getElementById('clientDeviceModel') || document.getElementById('newClientDeviceModel');
          if (modInp) modInp.value = p.mod || '';
          const aiInp = document.getElementById('clientAiBalance') || document.getElementById('newClientAiBalance');
          if (aiInp) aiInp.value = p.ai || 0;
        }
      });

      diffContainer.innerHTML = '';
      staleEl.style.display = 'none';
      if (footer) footer.style.display = 'none';
    }

    showToast('Ficha de sincronización analizada.', 'success');
  } catch (err) {
    showToast('Error al analizar ficha: ' + err.message, 'error');
  }
}

async function applyGlobalSync() {
  const container = document.getElementById('globalSyncResultContainer');
  const clientId = container?.dataset.targetClientId;
  if (!clientId) {
    showToast('No hay cliente seleccionado para aplicar la sincronización.', 'warning');
    return;
  }
  const rawInput = container?.dataset.parsedRaw || document.getElementById('globalSyncRawInput').value.trim();
  const forceOlder = document.getElementById('chkGlobalForceOlderSync')?.checked || false;

  try {
    const res = await fetch('/api/sync/apply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: clientId,
        raw_input: rawInput,
        force_older: forceOlder,
      }),
    });

    const data = await res.json();
    if (!res.ok) {
      if (res.status === 409) {
        showToast('Conflicto: El reporte es anterior a la última sincronización. Marca la casilla para confirmar sobrescritura.', 'warning');
        return;
      }
      throw new Error(data.error || 'Error al aplicar sincronización');
    }

    showToast('¡Sincronización aplicada exitosamente!', 'success');
    await loadClients();
    await loadDashboard();
    await loadReleaseMatrix();
    closeModal('modalGlobalClientSync');
  } catch (err) {
    showToast('Error al aplicar sincronización: ' + err.message, 'error');
  }
}

/**
 * Inicialización de Eventos de Sincronización Offline (Fase 4 Plan 19)
 */
function initClientSyncEvents() {
  // 1. Botón global en Cartera CRM
  document.getElementById('btnImportClientSync')?.addEventListener('click', openGlobalClientSyncModal);

  // 2. Eventos en modal local de sincronización
  document.getElementById('btnAnalyzeSyncReported')?.addEventListener('click', analyzeSyncReported);
  document.getElementById('btnClearSyncInput')?.addEventListener('click', () => {
    document.getElementById('syncRawInput').value = '';
    document.getElementById('syncAnalysisResult').style.display = 'none';
  });
  document.getElementById('btnApplySyncReported')?.addEventListener('click', applySyncReported);

  // Drag & drop en modal local
  const syncDropZone = document.getElementById('syncDropZone');
  const syncFileInput = document.getElementById('syncFileInput');
  syncDropZone?.addEventListener('click', () => syncFileInput?.click());
  syncDropZone?.addEventListener('dragover', (e) => {
    e.preventDefault();
    syncDropZone.classList.add('dragover');
  });
  syncDropZone?.addEventListener('dragleave', () => syncDropZone.classList.remove('dragover'));
  syncDropZone?.addEventListener('drop', (e) => {
    e.preventDefault();
    syncDropZone.classList.remove('dragover');
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0];
      const reader = new FileReader();
      reader.onload = (evt) => {
        document.getElementById('syncRawInput').value = evt.target.result;
        analyzeSyncReported();
      };
      reader.readAsText(file);
    }
  });
  syncFileInput?.addEventListener('change', () => {
    if (syncFileInput.files && syncFileInput.files.length > 0) {
      const reader = new FileReader();
      reader.onload = (evt) => {
        document.getElementById('syncRawInput').value = evt.target.result;
        analyzeSyncReported();
      };
      reader.readAsText(syncFileInput.files[0]);
    }
  });

  // 3. Eventos en modal global
  document.getElementById('btnAnalyzeGlobalSync')?.addEventListener('click', analyzeGlobalSync);
  document.getElementById('btnClearGlobalSync')?.addEventListener('click', () => {
    document.getElementById('globalSyncRawInput').value = '';
    document.getElementById('globalSyncResultContainer').style.display = 'none';
    document.getElementById('globalSyncModalFooter').style.display = 'none';
  });
  document.getElementById('btnApplyGlobalSync')?.addEventListener('click', applyGlobalSync);

  // Drag & drop en modal global
  const globalDropZone = document.getElementById('globalSyncDropZone');
  const globalFileInput = document.getElementById('globalSyncFileInput');
  globalDropZone?.addEventListener('click', () => globalFileInput?.click());
  globalDropZone?.addEventListener('dragover', (e) => {
    e.preventDefault();
    globalDropZone.classList.add('dragover');
  });
  globalDropZone?.addEventListener('dragleave', () => globalDropZone.classList.remove('dragover'));
  globalDropZone?.addEventListener('drop', (e) => {
    e.preventDefault();
    globalDropZone.classList.remove('dragover');
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0];
      const reader = new FileReader();
      reader.onload = (evt) => {
        document.getElementById('globalSyncRawInput').value = evt.target.result;
        analyzeGlobalSync();
      };
      reader.readAsText(file);
    }
  });
  globalFileInput?.addEventListener('change', () => {
    if (globalFileInput.files && globalFileInput.files.length > 0) {
      const reader = new FileReader();
      reader.onload = (evt) => {
        document.getElementById('globalSyncRawInput').value = evt.target.result;
        analyzeGlobalSync();
      };
      reader.readAsText(globalFileInput.files[0]);
    }
  });
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

// =================== 3B. COMPOSITOR UNIVERSAL DE WHATSAPP (PLAN 22 FASE 3) ===================
let currentWaComposerClientId = null;
let currentWaComposerTemplateKey = 'welcome';
let currentWaPreTemplateDraft = '';
let currentWaRenderedTemplateBase = '';
let openedInApkDispatchMode = false;
let currentDispatchRelease = null;
let currentDispatchClient = null;
let currentDispatchMode = 'eligible';
let currentDispatchVariant = 'universal';
let isApkDispatchMode = false;

const WA_SNIPPET_KEYS = ['payment', 'device', 'expiration', 'token'];

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
  ai_bonus: {
    name: 'Bono / Recarga IA',
    text: '¡Hola, {titular}! 👋 Te saludamos de MochilaLista.\nTu recarga de escaneos de Inteligencia Artificial para *{negocio}* ha sido acreditada con éxito.\n\n⚡ Detalle de la Recarga:\n• Créditos IA Otorgados: +{creditos_ia} escaneos vitalicios\n• Hardware ID Vinculado: `{device_id}`\n\n🔑 Token de Activación IA:\n`{codigo_licencia}`\n\nPuedes ingresar este token o escanear el QR en tu app para sumarlos inmediatamente a tu saldo disponible. ¡A seguir potenciando tu negocio! 🚀'
  },
  courtesy_extension: {
    name: 'Extensión de Cortesía',
    text: 'Estimado(a) {titular}, te saludamos de MochilaLista.\nTe confirmamos la habilitación de una extensión de cortesía por *{dias} día(s)* adicionales para tu sistema en *{negocio}*.\n\n📌 Nueva vigencia temporal: *{vencimiento}*\n• Hardware ID: `{device_id}`\n\n🔑 Código de Activación:\n`{codigo_licencia}`\n\nIngresa este código o escanea el QR en tu aplicación para continuar operando sin interrupciones. ¡Quedamos a tu servicio! 🎒✅'
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

function getCurrentWaComposerClient() {
  return (globalClients && globalClients.find(c => c.id === currentWaComposerClientId)) ||
         (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === currentWaComposerClientId)) ||
         currentDispatchClient ||
         null;
}

function normalizeWaSnippetKey(rawType) {
  if (rawType === 'payment' || rawType === 'yape') return 'payment';
  if (rawType === 'device' || rawType === 'hardware') return 'device';
  if (rawType === 'expiration' || rawType === 'vencimiento') return 'expiration';
  if (rawType === 'token') return 'token';
  return rawType;
}

function buildWaSnippetBlock(rawType, options = {}) {
  const key = normalizeWaSnippetKey(rawType);
  const notify = options.notify === true;
  const client = getCurrentWaComposerClient();
  const modalEl = document.getElementById('modalWaComposer');
  const pm = ownerConfig?.payment_methods || {};
  const li = ownerConfig?.legal_identity || {};

  if (key === 'payment') {
    const hasConfiguredPm = Boolean(ownerConfig && ownerConfig.payment_methods);
    const phone = hasConfiguredPm
      ? String(pm.yape_plin_phone ?? '').trim()
      : '922836879';
    const titular = String(pm.yape_plin_holder || li.author_full_name || '').trim() || 'Julio Angello Vasquez Navarro';
    if (!phone) {
      if (notify) showToast('No hay número Yape / Plin configurado en Ajustes.', 'warning');
      return null;
    }
    return `*Datos de Pago Yape / Plin:*\n• Número: *${phone}*\n• Titular: *${titular}*\n• Enviar comprobante por este medio.`;
  }

  if (key === 'device') {
    const devId = String(client?.current_device_id || client?.device_id || '').trim();
    if (!devId || devId === 'PENDIENTE' || devId === '-') {
      if (notify) showToast('Este cliente aún no tiene un Hardware ID vinculado.', 'warning');
      return null;
    }
    return `*Hardware ID:* \`${devId}\``;
  }

  if (key === 'expiration') {
    const licType = String(client?.license_type || '').toUpperCase();
    const isPerp = licType === 'PERPETUO_LIBERADO' || licType === 'PERPETUO';
    const expRaw = String(client?.license_expires || '').trim();
    if ((!expRaw && !isPerp) || licType === 'PROSPECTO') {
      if (notify) showToast('Este cliente no tiene fecha de vencimiento activa registrada.', 'warning');
      return null;
    }
    if (expRaw) {
      const expDate = new Date(expRaw);
      const diffDays = Number.isNaN(expDate.getTime())
        ? 0
        : Math.max(0, Math.ceil((expDate - new Date()) / (1000 * 60 * 60 * 24)));
      return `*Vencimiento:* ${expRaw.substring(0, 10)} (${diffDays} día(s) restantes)`;
    }
    const updStr = client?.updates_until ? String(client.updates_until).substring(0, 10) : 'Vigente';
    return `*Vencimiento:* Licencia Perpetua (Updates hasta: ${updStr})`;
  }

  if (key === 'token') {
    const hasRealToken = modalEl?.dataset?.hasRealToken === 'true';
    const lastToken = String(modalEl?.dataset?.lastToken || '').trim();
    if (!hasRealToken || !lastToken || lastToken.startsWith('ML9-PENDIENTE')) {
      if (notify) showToast('Este cliente aún no tiene un token de licencia emitido.', 'warning');
      return null;
    }
    return `*Último Token de Licencia:*\n\`${lastToken}\``;
  }

  return null;
}

function appendSnippetBlockToText(text, block) {
  const cleanText = String(text || '').replace(/\r\n/g, '\n');
  if (!block) return cleanText;
  if (cleanText.includes(block)) return cleanText;
  const trimmedEnd = cleanText.replace(/\s+$/, '');
  return trimmedEnd ? `${trimmedEnd}\n\n${block}` : block;
}

function removeSnippetBlockFromText(text, block) {
  const cleanText = String(text || '').replace(/\r\n/g, '\n');
  if (!block || !cleanText.includes(block)) return cleanText;
  return cleanText
    .split(block)
    .join('')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/^\n+|\n+$/g, '')
    .trim();
}

function extractBaseAndSnippetsFromText(text) {
  let working = String(text || '').replace(/\r\n/g, '\n');
  const activeMatches = [];

  WA_SNIPPET_KEYS.forEach(k => {
    const blk = buildWaSnippetBlock(k, { notify: false });
    if (blk && working.includes(blk)) {
      activeMatches.push({ key: k, block: blk, index: working.indexOf(blk) });
    }
  });

  activeMatches.sort((a, b) => a.index - b.index);
  activeMatches.forEach(item => {
    working = removeSnippetBlockFromText(working, item.block);
  });

  return {
    baseText: working,
    activeKeys: activeMatches.map(item => item.key),
  };
}

function syncWaInsertChipsState() {
  const textarea = document.getElementById('waCompMessage');
  const normalized = String(textarea?.value || '').replace(/\r\n/g, '\n');
  document.querySelectorAll('.wa-insert-chip').forEach(chip => {
    const key = normalizeWaSnippetKey(chip.dataset.snippet || '');
    if (!key) {
      chip.classList.remove('active');
      return;
    }
    const blk = buildWaSnippetBlock(key, { notify: false });
    const isActive = Boolean(blk && normalized.includes(blk));
    chip.classList.toggle('active', isActive);
  });
}

function renderWaTemplateBaseText(tplKey) {
  const client = getCurrentWaComposerClient();
  const modalEl = document.getElementById('modalWaComposer');
  if (!client) return '';

  if (tplKey === 'update' && currentDispatchRelease) {
    return buildApkDispatchMessage(currentDispatchRelease, client, currentDispatchMode);
  }

  const customText = ownerConfig?.templates?.[tplKey];
  const rawTpl = (customText !== undefined && customText !== null) ? customText : (WA_TEMPLATES[tplKey]?.text || '');
  if (!rawTpl) return '';

  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const diffDays = expDate ? Math.max(0, Math.ceil((expDate - now) / (1000 * 60 * 60 * 24))) : 0;
  const latestVer = getLatestPublishedVersion() || client.installed_version || '9.40.0';

  const pm = ownerConfig?.payment_methods || {};
  const li = ownerConfig?.legal_identity || {};
  const yapePhone = pm.yape_plin_phone || '922836879';
  const yapeTitular = pm.yape_plin_holder || li.author_full_name || 'Julio Angello Vasquez Navarro';
  const autor = li.author_full_name || 'Julio Angello Vasquez Navarro';
  const aiCredsVal = modalEl?.dataset?.aiCredits || client.ai_reported_balance || '0';
  const diasVal = modalEl?.dataset?.diasExtension || '7';
  const lastToken = (modalEl?.dataset?.lastToken || '').trim() || `ML9-PENDIENTE-${client.current_device_id || 'DISPOSITIVO'}`;

  return rawTpl
    .replace(/\{negocio\}/g, client.business_name || 'su negocio')
    .replace(/\{titular\}/g, client.owner_name || 'Estimado cliente')
    .replace(/\{plan\}/g, formatPlanLabel(client.license_type))
    .replace(/\{dias_restantes\}/g, String(diffDays))
    .replace(/\{dias\}/g, String(diasVal))
    .replace(/\{creditos_ia\}/g, String(aiCredsVal))
    .replace(/\{vencimiento\}/g, client.license_expires ? client.license_expires.substring(0, 10) : 'Activa')
    .replace(/\{device_id\}/g, client.current_device_id || client.device_id || 'PENDIENTE')
    .replace(/\{version\}/g, latestVer)
    .replace(/\{codigo_licencia\}/g, lastToken)
    .replace(/\{codigo\}/g, lastToken)
    .replace(/\{yape_phone\}/g, yapePhone)
    .replace(/\{yape_titular\}/g, yapeTitular)
    .replace(/\{autor\}/g, autor);
}

async function openWhatsAppComposer(clientId, defaultTemplateKey = null, options = {}) {
  const client = (globalClients && globalClients.find(c => c.id === clientId)) ||
                 (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === clientId)) ||
                 currentDispatchClient;
  if (!client) {
    showToast('Cliente no encontrado.', 'error');
    return;
  }

  currentWaComposerClientId = clientId;
  currentWaPreTemplateDraft = '';
  currentWaRenderedTemplateBase = '';
  openedInApkDispatchMode = options.isApkDispatch === true;

  const copyHintEl = document.getElementById('waApkCopySuccessHint');
  if (copyHintEl) copyHintEl.style.display = 'none';

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
  if (devIdEl) devIdEl.textContent = client.current_device_id || client.device_id || 'PENDIENTE';

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

  // Cargar token histórico más reciente si existe o usar el provisto en options
  let realToken = options.token ? String(options.token).trim() : '';
  let hasRealToken = Boolean(realToken && !realToken.startsWith('ML9-PENDIENTE'));
  if (!options.token) {
    try {
      const res = await fetch(`/api/clients/${clientId}/history`);
      if (res.ok) {
        const history = await res.json();
        if (history.codes && history.codes.length > 0) {
          realToken = String(history.codes[history.codes.length - 1].token || '').trim();
          hasRealToken = Boolean(realToken);
        }
      }
    } catch (_) { }
  }

  const modalEl = document.getElementById('modalWaComposer');
  if (modalEl) {
    modalEl.dataset.lastToken = realToken;
    modalEl.dataset.hasRealToken = hasRealToken ? 'true' : 'false';
    modalEl.dataset.cleanPhone = cleanDigits;
    modalEl.dataset.aiCredits = options.aiCredits !== undefined ? String(options.aiCredits) : '';
    modalEl.dataset.diasExtension = options.diasExtension !== undefined ? String(options.diasExtension) : '';
  }

  // Alternar panel y footer exclusivo de Despacho Asistido de APK (Plan 19 / 22 Fase 3)
  if (options.isApkDispatch === true) {
    const sorted = [...(globalReleases || [])].sort((a, b) => compareSemVer(b.version_name, a.version_name));
    currentDispatchRelease = options.release || sorted[0] || currentDispatchRelease;
    toggleWaApkDispatchPanelVisibility(true);
    if (currentDispatchRelease) {
      syncWaApkDispatchPanel(currentDispatchRelease, { skipMessageUpdate: true });
    }
  } else {
    currentDispatchRelease = null;
    currentDispatchClient = null;
    currentDispatchMode = 'eligible';
    toggleWaApkDispatchPanelVisibility(false);
  }

  if (options.customMessage) {
    const textarea = document.getElementById('waCompMessage');
    if (openedInApkDispatchMode) {
      currentWaComposerTemplateKey = 'update';
      currentWaRenderedTemplateBase = options.customMessage;
      document.querySelectorAll('.wa-template-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.tpl === 'update');
      });
    } else {
      currentWaComposerTemplateKey = null;
      currentWaPreTemplateDraft = options.customMessage;
      document.querySelectorAll('.wa-template-btn').forEach(b => b.classList.remove('active'));
    }
    if (textarea) {
      textarea.value = options.customMessage;
      updateWaComposerStats();
      syncWaInsertChipsState();
    }
  } else {
    currentWaComposerTemplateKey = null;
    selectWaTemplate(initialTpl);
  }
  openModal('modalWaComposer');
}

function selectWaTemplate(tplKey, options = {}) {
  if (!WA_TEMPLATES[tplKey]) tplKey = 'welcome';
  const textarea = document.getElementById('waCompMessage');
  if (!textarea) return;

  const { baseText, activeKeys } = extractBaseAndSnippetsFromText(textarea.value || '');

  // Segundo clic sobre la misma plantilla activa -> desactivar y restaurar borrador previo sin duplicar
  if (!options.forceApply && currentWaComposerTemplateKey === tplKey) {
    currentWaComposerTemplateKey = null;
    document.querySelectorAll('.wa-template-btn').forEach(b => b.classList.remove('active'));

    let restored = currentWaPreTemplateDraft || '';
    activeKeys.forEach(k => {
      const blk = buildWaSnippetBlock(k, { notify: false });
      if (blk) restored = appendSnippetBlockToText(restored, blk);
    });

    textarea.value = restored;
    currentWaPreTemplateDraft = '';
    currentWaRenderedTemplateBase = '';

    if (tplKey === 'update' && !openedInApkDispatchMode) {
      toggleWaApkDispatchPanelVisibility(false);
    }

    updateWaComposerStats();
    syncWaInsertChipsState();
    return;
  }

  // Al pasar desde texto libre hacia una plantilla, resguardar borrador previo
  if (!currentWaComposerTemplateKey || currentWaComposerTemplateKey === 'custom') {
    currentWaPreTemplateDraft = baseText;
  }

  currentWaComposerTemplateKey = tplKey;
  document.querySelectorAll('.wa-template-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.tpl === tplKey);
  });

  if (tplKey === 'update') {
    ensureWaDispatchReleaseInitialized();
    toggleWaApkDispatchPanelVisibility(true);
    if (currentDispatchRelease) {
      syncWaApkDispatchPanel(currentDispatchRelease, { skipMessageUpdate: true });
    }
  } else if (!openedInApkDispatchMode) {
    toggleWaApkDispatchPanelVisibility(false);
  }

  const newBase = renderWaTemplateBaseText(tplKey);
  currentWaRenderedTemplateBase = newBase;

  let nextText = newBase;
  activeKeys.forEach(k => {
    const blk = buildWaSnippetBlock(k, { notify: false });
    if (blk) nextText = appendSnippetBlockToText(nextText, blk);
  });

  textarea.value = nextText;
  updateWaComposerStats();
  syncWaInsertChipsState();
}

function updateWaComposerStats() {
  const textarea = document.getElementById('waCompMessage');
  const counter = document.getElementById('waCompCharCounter');
  const sendBtn = document.getElementById('btnWaCompSend');
  const modalEl = document.getElementById('modalWaComposer');
  const cleanDigits = modalEl?.dataset?.cleanPhone || '';

  if (!textarea) return;
  const text = textarea.value || '';
  if (counter) counter.textContent = `${text.length} caracteres`;

  if (sendBtn && cleanDigits && cleanDigits.length >= 9) {
    sendBtn.href = `https://wa.me/${cleanDigits}?text=${encodeURIComponent(text)}`;
  }
}

function copyWaComposerMessage() {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea || !textarea.value.trim()) {
    showToast('El mensaje está vacío.', 'warning');
    return;
  }
  copyPlainTextToClipboard(textarea.value, 'Mensaje copiado al portapapeles.');
}

function insertTextAtCursor(textarea, textToInsert) {
  if (!textarea) return;
  const start = textarea.selectionStart ?? textarea.value.length;
  const end = textarea.selectionEnd ?? textarea.value.length;
  const current = textarea.value;
  textarea.value = current.substring(0, start) + textToInsert + current.substring(end);
  textarea.selectionStart = textarea.selectionEnd = start + textToInsert.length;
  textarea.focus?.();
  updateWaComposerStats();
  syncWaInsertChipsState();
}

function insertWaSnippet(type) {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea) return;

  const key = normalizeWaSnippetKey(type);
  const block = buildWaSnippetBlock(key, { notify: true });
  if (!block) {
    syncWaInsertChipsState();
    return;
  }

  const normalized = (textarea.value || '').replace(/\r\n/g, '\n');
  if (normalized.includes(block)) {
    textarea.value = removeSnippetBlockFromText(normalized, block);
  } else {
    textarea.value = appendSnippetBlockToText(normalized, block);
  }

  textarea.focus?.();
  updateWaComposerStats();
  syncWaInsertChipsState();
}

async function saveCurrentWaTemplate() {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea) return;
  const tplKey = currentWaComposerTemplateKey;
  if (!tplKey || !WA_TEMPLATES[tplKey]) {
    showToast('Selecciona primero una plantilla para guardar cambios.', 'warning');
    return;
  }

  const { baseText } = extractBaseAndSnippetsFromText(textarea.value || '');
  const newText = baseText;

  if (!ownerConfig) ownerConfig = {};
  if (!ownerConfig.templates) ownerConfig.templates = {};
  ownerConfig.templates[tplKey] = newText;
  WA_TEMPLATES[tplKey].text = newText;

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
  const tplKey = (currentWaComposerTemplateKey && DEFAULT_WA_TEMPLATES[currentWaComposerTemplateKey])
    ? currentWaComposerTemplateKey
    : 'welcome';
  const defaultText = DEFAULT_WA_TEMPLATES[tplKey]?.text || '';
  if (WA_TEMPLATES[tplKey]) {
    WA_TEMPLATES[tplKey].text = defaultText;
  }

  if (ownerConfig?.templates) {
    delete ownerConfig.templates[tplKey];
    try {
      await fetch('/api/config', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(ownerConfig),
      });
    } catch (_) { }
  }

  selectWaTemplate(tplKey, { forceApply: true });
  showToast('Plantilla restaurada a los valores predeterminados.', 'info');
}

function initWaComposerEvents() {
  document.getElementById('waCompMessage')?.addEventListener('input', () => {
    updateWaComposerStats();
    syncWaInsertChipsState();
  });
}

// =================== 4. RELEASE MANAGER & MATRIZ INTELIGENTE (PLAN 19 / 22) ===================
let globalReleaseMatrix = [];
let currentMatrixFilter = 'ALL';
let currentMatrixSearch = '';
let lastInspectedCreateData = null;
let editModalLocalBuildsCache = [];
let activeCreateApkSource = null; // null | 'manual' | 'autodetect'
let selectedLocalBuildPath = null;
let selectedLocalBuildIndex = -1;
let pendingManualFileMeta = null;
let createApkSearchDirs = [];
let localBuildsFilterState = { abi: 'ALL', query: '', limit: 6 };
let localBuildsFilterTimer = null;

/**
 * Normaliza tamaños APK para evitar valores sin sufijo o "MB MB" duplicado
 */
function formatApkSizeMb(raw) {
  if (raw === null || raw === undefined) return '-';
  const s = String(raw).trim();
  if (!s || s === '-' || s === 'null' || s === 'undefined') return '-';
  const cleaned = s.replace(/\s*MB\s*$/i, '').trim();
  if (!cleaned) return '-';
  const num = Number(cleaned);
  if (!Number.isNaN(num) && Number.isFinite(num)) {
    return `${num.toFixed(2)} MB`;
  }
  return /\bMB$/i.test(s) ? s.replace(/\s*MB$/i, ' MB') : `${s} MB`;
}

/**
 * Infiere tipo de lanzamiento sugerido desde SemVer:
 * patch > 0 -> HOTFIX, patch == 0 -> FEATURE_RELEASE
 */
function inferReleaseTypeFromSemVer(versionName) {
  if (!versionName) return 'FEATURE_RELEASE';
  const clean = String(versionName).trim().replace(/^[vV]/, '').split('+')[0].split('-')[0];
  const segs = clean.split('.');
  const patch = segs.length > 2 ? (parseInt(segs[2], 10) || 0) : 0;
  return patch > 0 ? 'HOTFIX' : 'FEATURE_RELEASE';
}

/**
 * Renderiza el badge de firma criptográfica de 3 estados honestos
 */
function renderSignatureStatusBadge(sigStatus, sigVerified, labelOfficial = 'Oficial RSA-4096') {
  if (sigStatus === 'OFFICIAL_RELEASE' || sigVerified === true) {
    return `<span class="badge badge-official-sig" title="Firma Oficial Verificada (RSA-4096 — Julio Angello Vasquez Navarro)"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg> ${escapeHtml(labelOfficial)}</span>`;
  }
  if (sigStatus === 'UNOFFICIAL_SIGNATURE' || (sigVerified === false && sigStatus !== 'UNVERIFIED')) {
    return '<span class="badge badge-unofficial-sig" title="Firma No Oficial / Debug Keystore"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg> No Oficial</span>';
  }
  return '<span class="badge badge-unverified-sig" title="Firma no verificada en este entorno"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg> Sin Verificar</span>';
}

/**
 * Copia texto plano (ej. SHA-256) al portapapeles de forma segura
 */
async function copyPlainTextToClipboard(text, successMsg = 'Texto copiado al portapapeles.') {
  if (!text) return;
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
    } else {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
    }
    showToast(successMsg, 'success');
  } catch (err) {
    showToast('No se pudo copiar al portapapeles: ' + err.message, 'error');
  }
}

/**
 * Comparador SemVer numérico client-side determinista
 */
function compareSemVer(a, b) {
  if (!a && !b) return 0;
  if (!a) return -1;
  if (!b) return 1;

  const parseParts = (s) => {
    const clean = String(s).trim().replace(/^[vV]/, '');
    const withoutSuffix = clean.split('-')[0];
    const buildSplit = withoutSuffix.split('+');
    const segs = buildSplit[0].split('.');
    const major = parseInt(segs[0], 10) || 0;
    const minor = segs.length > 1 ? parseInt(segs[1], 10) || 0 : 0;
    const patch = segs.length > 2 ? parseInt(segs[2], 10) || 0 : 0;
    const build = buildSplit.length > 1 ? parseInt(buildSplit[1], 10) || null : null;
    return { major, minor, patch, build };
  };

  const pa = parseParts(a);
  const pb = parseParts(b);

  if (pa.major !== pb.major) return pa.major - pb.major;
  if (pa.minor !== pb.minor) return pa.minor - pb.minor;
  if (pa.patch !== pb.patch) return pa.patch - pb.patch;
  if (pa.build != null && pb.build != null && pa.build !== pb.build) {
    return pa.build - pb.build;
  }
  return 0;
}

/**
 * Carga el catálogo de versiones publicadas
 */
async function loadReleases() {
  try {
    const res = await fetch('/api/releases', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar versiones');
    globalReleases = await res.json();

    const tbody = document.getElementById('releasesTableBody');
    if (!tbody) return;
    tbody.innerHTML = '';

    if (globalReleases.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No hay versiones registradas en este entorno.</td></tr>';
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
      const sizeInfo = formatApkSizeMb(r.file_size_mb);

      const verNorm = String(r.version_name || '').trim().replace(/^[vV]/, '');
      const adoptionCount = (globalClients || []).filter(c => {
        const inst = String(c.installed_version || '').trim().replace(/^[vV]/, '');
        return inst && inst === verNorm;
      }).length;
      const adoptionLabel = adoptionCount === 1 ? '1 cliente' : `${adoptionCount} clientes`;

      // Badges de variantes
      const variantsBadges = [];
      if (r.universal_apk || r.abi_variant === 'UNIVERSAL' || (!r.universal_apk && !r.arm64_apk)) {
        variantsBadges.push('<span class="badge badge-universal" title="Compatible con todos los procesadores">Universal</span>');
      }
      if (r.arm64_apk || r.abi_variant === 'ARM64') {
        variantsBadges.push('<span class="badge badge-arm64" title="Optimizado para 64 bits">ARM64</span>');
      }

      // Badge de firma oficial de 3 estados honestos
      const sigBadge = renderSignatureStatusBadge(r.signature_status, r.signature_verified, 'Oficial');

      tr.innerHTML = `
        <td>
          <div class="release-version-cell">
            <strong>v${escapeHtml(r.version_name)}</strong>
            <span class="release-adoption-pill ${adoptionCount > 0 ? 'has-clients' : ''}" title="${adoptionCount} cliente(s) con esta versión instalada">${adoptionLabel}</span>
          </div>
        </td>
        <td>${r.version_code || '-'}</td>
        <td>Esquema v${r.db_schema_version || 36}</td>
        <td>${badge}</td>
        <td style="white-space:nowrap;">${r.release_date ? r.release_date.substring(0, 10) : '-'}</td>
        <td>
          <div style="display:flex; gap:0.3rem; flex-wrap:wrap; align-items:center;">
            ${variantsBadges.join(' ')}
            ${sigBadge}
          </div>
        </td>
        <td>
          <div style="font-size:0.75rem; color:var(--text-secondary); white-space:nowrap;">${escapeHtml(sizeInfo)}</div>
          <code style="font-family:var(--font-mono); font-size:0.72rem;" title="${escapeHtml(r.apk_sha256 || '')}">${shortSha}</code>
        </td>
        <td>
          <div class="release-actions-row" style="display:flex; gap:0.25rem; flex-wrap:nowrap; align-items:center; white-space:nowrap;">
            ${(() => {
              const hasUniversal = !!r.universal_apk || (!r.universal_apk && !r.arm64_apk);
              const hasArm64 = !!r.arm64_apk;
              if (hasUniversal && hasArm64) {
                return `
                  <div class="variant-btn-group" title="Descargar APK directo del servidor">
                    <a href="/api/releases/download/${encodeURIComponent(r.version_name)}?variant=universal" class="btn btn-outline btn-xs" title="Descargar APK Universal">Univ</a>
                    <a href="/api/releases/download/${encodeURIComponent(r.version_name)}?variant=arm64" class="btn btn-outline btn-xs" title="Descargar APK ARM64 Ligero">ARM64</a>
                  </div>
                  <div class="variant-btn-group" title="Copiar archivo APK al portapapeles">
                    <button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(r.version_name)}', 'universal')" title="Copiar APK Universal al portapapeles">Copiar Univ</button>
                    <button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(r.version_name)}', 'arm64')" title="Copiar APK ARM64 Ligero al portapapeles">ARM64</button>
                  </div>
                `;
              } else if (hasArm64) {
                return `
                  <a href="/api/releases/download/${encodeURIComponent(r.version_name)}?variant=arm64" class="btn btn-outline btn-xs" title="Descargar APK ARM64 Ligero">
                    <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                    APK ARM64
                  </a>
                  <button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(r.version_name)}', 'arm64')" title="Copiar APK ARM64 Ligero al portapapeles">
                    <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                    Copiar ARM64
                  </button>
                `;
              } else {
                return `
                  <a href="/api/releases/download/${encodeURIComponent(r.version_name)}?variant=universal" class="btn btn-outline btn-xs" title="Descargar APK directo del servidor">
                    <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                    APK
                  </a>
                  <button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(r.version_name)}', 'universal')" title="Copiar archivo APK binario al portapapeles para pegar en WhatsApp">
                    <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                    Copiar
                  </button>
                `;
              }
            })()}
            <button type="button" class="btn btn-outline btn-xs" onclick="revealReleaseInExplorer('${escapeHtml(r.version_name)}')" title="Mostrar en Carpeta de Windows">
              <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
              Carpeta
            </button>
            <button type="button" class="btn btn-outline btn-xs" onclick="verifyReleaseIntegrity('${escapeHtml(r.version_name)}')" title="Verificar archivo en disco y firma criptográfica RSA-4096">
              <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
              Verificar
            </button>
            <button type="button" class="btn btn-outline btn-xs" onclick="openEditReleaseModal('${escapeHtml(r.version_name)}')" title="Editar Versión y Changelog">
              <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
            </button>
            <button type="button" class="btn btn-outline btn-xs" style="color:var(--danger); border-color:var(--danger);" onclick="deleteRelease('${escapeHtml(r.version_name)}')" title="Eliminar Versión">
              <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
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

const editModalLocalBuildsByVariant = { universal: [], arm64: [] };

/**
 * Valida estrictamente que la arquitectura ABI detectada del APK coincida con la ranura destino
 */
function validateApkAbiForVariantSlot(detectedAbi, targetSlot) {
  const normalizedDetected = String(detectedAbi || '').trim().toUpperCase();
  const normalizedTarget = String(targetSlot || '').trim().toUpperCase();
  const isArm64Slot = normalizedTarget === 'ARM64';
  const expectedAbi = isArm64Slot ? 'ARM64' : 'UNIVERSAL';

  if (!normalizedDetected) {
    return {
      ok: false,
      expectedAbi,
      detectedAbi: 'DESCONOCIDA',
      error: `No se pudo confirmar la arquitectura ABI del APK para la ranura ${expectedAbi}.`,
    };
  }

  if (isArm64Slot && normalizedDetected !== 'ARM64') {
    return {
      ok: false,
      expectedAbi: 'ARM64',
      detectedAbi: normalizedDetected,
      error: `Arquitectura incompatible: el archivo es ${normalizedDetected}, pero esta ranura exige un APK ARM64 Ligero (~30 MB). Selecciona un build compilado con compilar_apk_arm64.bat.`,
    };
  }

  if (!isArm64Slot && normalizedDetected === 'ARM64') {
    return {
      ok: false,
      expectedAbi: 'UNIVERSAL',
      detectedAbi: normalizedDetected,
      error: `Arquitectura incompatible: el archivo es ARM64 Ligero, pero esta ranura exige un APK Universal (~110 MB). Adjúntalo en ARM64 Ligero o usa compilar_apk_comercial.bat.`,
    };
  }

  return {
    ok: true,
    expectedAbi,
    detectedAbi: normalizedDetected,
    error: null,
  };
}

function getEditVariantData(rel, variantKey) {
  if (!rel) return null;
  if (variantKey === 'arm64') {
    return rel.arm64_apk || (rel.apk_file_path && rel.abi_variant === 'ARM64' ? {
      file_path: rel.apk_file_path,
      file_size_mb: rel.file_size_mb,
      sha256: rel.apk_sha256,
      signature_status: rel.signature_status,
      signature_verified: rel.signature_verified,
      file_exists: rel.file_exists,
    } : null);
  }
  return rel.universal_apk || (rel.apk_file_path && rel.abi_variant !== 'ARM64' ? {
    file_path: rel.apk_file_path,
    file_size_mb: rel.file_size_mb,
    sha256: rel.apk_sha256,
    signature_status: rel.signature_status,
    signature_verified: rel.signature_verified,
    file_exists: rel.file_exists,
  } : null);
}

function canUnlinkEditVariantSlot(rel, variantKey) {
  if (!rel) return { allowed: false, reason: 'Versión no cargada.' };
  const slotData = getEditVariantData(rel, variantKey);
  if (!slotData || !slotData.file_path) {
    return { allowed: false, reason: 'Esta variante no tiene ningún archivo vinculado.' };
  }
  if (variantKey === 'arm64') {
    return { allowed: true, reason: null };
  }
  const arm64Data = getEditVariantData(rel, 'arm64');
  const hasHealthyArm64 = Boolean(arm64Data && arm64Data.file_path && arm64Data.file_exists !== false);
  const isUniversalMissing = slotData.file_exists === false;
  if (hasHealthyArm64 || isUniversalMissing) {
    return { allowed: true, reason: null };
  }
  return {
    allowed: false,
    reason: 'No puedes desvincular Universal mientras sea el único APK válido en disco (adjunta primero ARM64 Ligero o reemplaza Universal).',
  };
}

/**
 * Sincroniza una versión actualizada hacia globalReleases, #modalEditRelease, Catálogo, Matriz y #modalWaComposer
 */
async function syncReleaseAcrossUiAndComposer(versionName, updatedRel, options = {}) {
  if (updatedRel) {
    const idx = globalReleases.findIndex(r => r.version_name === versionName);
    if (idx !== -1) {
      globalReleases[idx] = updatedRel;
    } else {
      globalReleases.unshift(updatedRel);
    }

    const editModalOpen = document.getElementById('modalEditRelease')?.classList.contains('open');
    const currentEditVer = document.getElementById('editRelVersionName')?.value;
    if ((editModalOpen || options.forceRenderEditModal) && currentEditVer === versionName) {
      const vcInput = document.getElementById('editRelVersionCode');
      const dbInput = document.getElementById('editRelDbSchema');
      if (vcInput && updatedRel.version_code) vcInput.value = updatedRel.version_code;
      if (dbInput && updatedRel.db_schema_version) dbInput.value = updatedRel.db_schema_version;
      renderEditReleaseVariants(updatedRel);
    }
  }

  await loadReleases();
  await loadReleaseMatrix();

  if (updatedRel) {
    const idxAfter = globalReleases.findIndex(r => r.version_name === versionName);
    if (idxAfter !== -1) globalReleases[idxAfter] = updatedRel;
    if (typeof currentDispatchRelease !== 'undefined' && currentDispatchRelease?.version_name === versionName) {
      currentDispatchRelease = updatedRel;
      const waOpen = document.getElementById('modalWaComposer')?.classList.contains('open');
      if ((waOpen && typeof isApkDispatchMode !== 'undefined' && isApkDispatchMode) || options.forceSyncWaComposer) {
        syncWaApkDispatchPanel(updatedRel, { preserveCopyHint: true });
      }
    }
  }
}

async function commitReleaseVariantUpdate(versionName, variantKey, inspectedData, filePath, originText = '') {
  const normalizedSize = formatApkSizeMb(inspectedData.size_mb);
  const variantData = {
    file_path: filePath,
    file_size_mb: normalizedSize,
    sha256: inspectedData.sha256,
    signature_status: inspectedData.signature_status,
    signature_verified: inspectedData.signature_verified,
    signature_detail: inspectedData.signature_detail,
    signer_sha256: inspectedData.signer_sha256,
    signer_dn: inspectedData.signer_dn,
    file_exists: true,
  };

  const updates = {};
  if (variantKey === 'arm64') {
    updates.arm64_apk = variantData;
  } else {
    updates.universal_apk = variantData;
    updates.apk_file_path = filePath;
    updates.file_size_mb = normalizedSize;
    updates.apk_sha256 = inspectedData.sha256;
    updates.signature_status = inspectedData.signature_status;
    updates.signature_verified = inspectedData.signature_verified;
    updates.signature_detail = inspectedData.signature_detail;
    updates.signer_sha256 = inspectedData.signer_sha256;
    updates.signer_dn = inspectedData.signer_dn;
  }

  const putRes = await fetch(`/api/releases/${encodeURIComponent(versionName)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(updates),
  });
  const updatedRel = await putRes.json().catch(() => ({}));
  if (!putRes.ok) {
    throw new Error(updatedRel.error || 'Error al vincular variante en la base de datos');
  }
  updatedRel.file_exists = true;

  await syncReleaseAcrossUiAndComposer(versionName, updatedRel);
  const suffix = originText ? ` ${originText}` : '';
  showToast(`Variante ${variantKey.toUpperCase()} vinculada${suffix} (${normalizedSize}).`, 'success');
  return updatedRel;
}

/**
 * Re-verifica en disco duro el archivo físico y firma RSA-4096 de una versión
 */
async function verifyReleaseIntegrity(versionName, fromEditModal = false) {
  if (!versionName) return;
  try {
    showToast(`Auditando archivo y firma de v${versionName}...`, 'info', 2500);
    const res = await fetch(`/api/releases/${encodeURIComponent(versionName)}/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      throw new Error(data.error || 'No se pudo verificar la versión');
    }

    const updatedRel = data.release;
    await syncReleaseAcrossUiAndComposer(versionName, updatedRel, {
      forceRenderEditModal: Boolean(fromEditModal),
    });

    if (!data.file_exists) {
      showToast(`No se encontró ningún APK físico en disco para v${versionName}.`, 'warning');
    } else if (updatedRel?.signature_status === 'OFFICIAL_RELEASE' || updatedRel?.signature_verified === true) {
      showToast(`v${versionName} verificada: Firma Oficial RSA-4096 y archivo en disco OK.`, 'success');
    } else if (updatedRel?.signature_status === 'UNOFFICIAL_SIGNATURE' || updatedRel?.signature_verified === false) {
      showToast(`v${versionName} auditada: se detectó firma NO OFICIAL.`, 'warning');
    } else {
      showToast(`v${versionName} auditada en disco (${updatedRel?.signature_detail || 'Sin Verificar'}).`, 'info');
    }
  } catch (e) {
    showToast('Error al verificar versión: ' + e.message, 'error');
  }
}

/**
 * Carga notas compañeras (*_cambios.txt o *_atp.txt) en el campo indicado sin mezclarlas
 */
async function loadCompanionNoteIntoField(versionName, targetFieldId, noteKind, cachedData = null) {
  const field = document.getElementById(targetFieldId);
  if (!field) return;

  const cleanVer = String(versionName || '').trim().replace(/^[vV]/, '');
  let noteText = '';

  if (cachedData && cleanVer && String(cachedData.version_name || '').trim().replace(/^[vV]/, '') === cleanVer) {
    noteText = noteKind === 'internal_notes'
      ? (cachedData.suggested_internal_notes || '')
      : (cachedData.suggested_changelog || '');
  }

  if (!noteText && cleanVer) {
    try {
      const res = await fetch(`/api/releases/${encodeURIComponent(cleanVer)}/companion-notes`);
      if (res.ok) {
        const data = await res.json();
        noteText = noteKind === 'internal_notes'
          ? (data.suggested_internal_notes || '')
          : (data.suggested_changelog || '');
      }
    } catch (e) {
      showToast('Error al leer notas compañeras: ' + e.message, 'error');
      return;
    }
  }

  const filePattern = noteKind === 'internal_notes' ? '*_atp.txt' : '*_cambios.txt';
  if (!noteText.trim()) {
    showToast(`No se encontró archivo ${filePattern} en disco para la versión ${cleanVer || 'indicada'}.`, 'warning');
    return;
  }

  field.value = noteText;
  if (typeof updateTextareaMetaCounter === 'function') {
    updateTextareaMetaCounter(targetFieldId);
  }
  showToast(
    noteKind === 'internal_notes'
      ? `Notas internas cargadas desde ${filePattern}.`
      : `Changelog comercial cargado desde ${filePattern}.`,
    'success'
  );
}

/**
 * Copia el archivo APK al portapapeles de Windows vía /copy-file
 */
async function copyReleaseApkToClipboard(versionName, variant = 'universal') {
  try {
    const res = await fetch(`/api/releases/${encodeURIComponent(versionName)}/copy-file?variant=${encodeURIComponent(variant)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      throw new Error(data.error || 'No se pudo copiar el archivo al portapapeles');
    }
    showToast(`Archivo .apk copiado: presiona Ctrl + V en WhatsApp para enviarlo (${data.file_name || versionName}).`, 'success');
  } catch (e) {
    showToast('Error al copiar APK: ' + e.message, 'error');
  }
}

/**
 * Abre el explorador de Windows resaltando el APK de la versión
 */
async function revealReleaseInExplorer(versionName, variant = null) {
  try {
    const res = await fetch('/api/releases/reveal-file', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ version_name: versionName, variant: variant }),
    });
    if (!res.ok) throw new Error('No se pudo abrir el explorador');
    showToast(`Mostrando versión v${versionName} en el Explorador de Windows.`, 'info');
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

let currentUploadVariantVersion = null;
let currentUploadVariantType = 'universal';

/**
 * Construye una tarjeta enriquecida de variante APK dentro de #modalEditRelease (Plan 22.5 Fase 3)
 */
function buildEditVariantCardHtml(rel, variantKey, titleLabel, badgeClass, vData, options = {}) {
  const versionName = rel.version_name || '';
  const hasPath = !!(vData && vData.file_path);
  const diskState = hasPath
    ? (vData.file_exists !== undefined ? vData.file_exists : rel.file_exists)
    : null;
  const isMissingOnDisk = hasPath && diskState === false;
  const isVerifiedOnDisk = hasPath && diskState === true;
  const canUnlink = hasPath && options.canUnlink === true;

  const sizeFormatted = hasPath ? formatApkSizeMb(vData.file_size_mb) : 'Sin archivo adjunto';
  const sha = (vData && vData.sha256) ? String(vData.sha256) : '';
  const shortSha = sha ? `${sha.substring(0, 14)}...` : '-';

  // Estado honesto en 3 niveles: No adjuntado (Opcional) | Extraviado en disco | Verificado / Pendiente
  let statusBadgeHtml = '<span class="badge badge-variant-optional">No adjuntado (Opcional)</span>';
  let sigBadgeHtml = '';
  if (hasPath) {
    if (isMissingOnDisk) {
      statusBadgeHtml = '<span class="badge badge-disk-missing">Archivo extraviado en disco</span>';
    } else if (isVerifiedOnDisk) {
      statusBadgeHtml = '<span class="badge badge-disk-ok">Verificado en disco</span>';
    } else {
      statusBadgeHtml = '<span class="badge badge-unverified-sig">Pendiente verificar</span>';
    }
    const sigStatus = vData?.signature_status ?? rel.signature_status ?? 'UNVERIFIED';
    const sigVerified = vData?.signature_verified !== undefined
      ? vData.signature_verified
      : rel.signature_verified;
    sigBadgeHtml = renderSignatureStatusBadge(sigStatus, sigVerified, 'Oficial RSA-4096');
  }

  const sizeClass = hasPath ? 'color:var(--text-primary);' : 'color:var(--text-muted); font-weight:500;';

  let detailHtml = '';
  if (!hasPath) {
    detailHtml = `<div class="edit-variant-optional-note">Variante opcional no adjuntada para esta versión. Usa "Subir desde PC" o "Vincular desde Biblioteca Local".</div>`;
  } else {
    const missingBannerHtml = isMissingOnDisk
      ? `<div class="edit-variant-missing-note">No encontrado en la ruta registrada en disco — usa "Re-verificar", "Subir desde PC", "Vincular desde Biblioteca Local" o "Desvincular".</div>`
      : '';
    detailHtml = `
      ${missingBannerHtml}
      <div class="edit-variant-meta-row">
        <span style="color:var(--text-muted);">SHA-256:</span>
        <code style="font-family:var(--font-mono); color:var(--text-primary);" title="${escapeHtml(sha)}">${escapeHtml(shortSha)}</code>
        ${sha ? `<button type="button" class="btn btn-outline btn-xs btn-copy-variant-sha" data-sha="${escapeHtml(sha)}">Copiar SHA</button>` : ''}
      </div>
      <div style="font-size:0.73rem; color:var(--text-secondary); font-family:var(--font-mono); word-break:break-all;">
        ${escapeHtml(vData.file_path || '')}
      </div>
    `;
  }

  const verifyBtnHtml = hasPath
    ? `<button type="button" class="btn btn-outline btn-xs" onclick="verifyReleaseIntegrity('${escapeHtml(versionName)}', true)" title="Re-verificar archivo en disco y firma RSA-4096">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
        Re-verificar
      </button>`
    : '';

  const copyRevealBtnsHtml = (hasPath && !isMissingOnDisk)
    ? `<button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(versionName)}', '${variantKey}')">Copiar</button>
       <button type="button" class="btn btn-outline btn-xs" onclick="revealReleaseInExplorer('${escapeHtml(versionName)}', '${variantKey}')">Carpeta</button>`
    : '';

  const unlinkBtnHtml = canUnlink
    ? `<button type="button" class="btn btn-outline btn-xs btn-unlink-variant edit-variant-unlink-btn" data-variant="${variantKey}" data-version="${escapeHtml(versionName)}" title="Desvincular esta variante de v${escapeHtml(versionName)}">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18"/><path d="M6 6l12 12"/></svg>
        Desvincular
      </button>`
    : '';

  const abiExpectedLabel = variantKey === 'arm64' ? 'ARM64 Ligero' : 'Universal';

  return `
    <div class="edit-variant-card" data-variant="${variantKey}">
      <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.4rem;">
        <div style="display:flex; align-items:center; gap:0.4rem; flex-wrap:wrap;">
          <span class="badge ${badgeClass}">${escapeHtml(titleLabel)}</span>
          <strong style="font-size:0.78rem; ${sizeClass}">${escapeHtml(sizeFormatted)}</strong>
          ${statusBadgeHtml}
          ${sigBadgeHtml}
        </div>
        <div style="display:flex; gap:0.3rem; flex-wrap:wrap; align-items:center;">
          <button type="button" class="btn btn-outline btn-xs" onclick="triggerVariantUpload('${variantKey}', '${escapeHtml(versionName)}')">
            <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
            Subir desde PC
          </button>
          <button type="button" class="btn btn-outline btn-xs btn-toggle-local-picker" data-variant="${variantKey}" data-version="${escapeHtml(versionName)}">
            <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
            Vincular desde Biblioteca Local
          </button>
          ${verifyBtnHtml}
          ${copyRevealBtnsHtml}
          ${unlinkBtnHtml}
        </div>
      </div>
      ${detailHtml}
      <div class="edit-variant-local-picker" id="editVariantLocalPicker_${variantKey}" style="display:none;">
        <div class="edit-variant-picker-header">
          <div style="display:flex; align-items:center; gap:0.45rem; flex-wrap:wrap;">
            <strong style="font-size:0.75rem; color:var(--primary);">Seleccionar APK ${escapeHtml(abiExpectedLabel)} detectado:</strong>
            <span style="font-size:0.71rem; color:var(--text-muted);" id="editVariantLocalStatus_${variantKey}">Cargando...</span>
          </div>
          <div class="edit-picker-header-actions">
            <button type="button" class="btn btn-outline btn-xs btn-rescan-edit-local" data-variant="${variantKey}" data-version="${escapeHtml(versionName)}" title="Re-escanear rutas configuradas">
              <svg class="btn-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
              Re-escanear rutas
            </button>
            <button type="button" class="btn btn-outline btn-xs btn-open-edit-search-dirs" data-variant="${variantKey}" data-version="${escapeHtml(versionName)}" title="Configurar carpetas de búsqueda APK">
              <svg class="btn-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
              Rutas...
            </button>
            <button type="button" class="btn btn-outline btn-xs btn-close-edit-local-picker" data-variant="${variantKey}" title="Cerrar selector local">
              <svg class="btn-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              Cerrar
            </button>
          </div>
        </div>
        <div style="display:flex; gap:0.4rem; flex-wrap:wrap; align-items:center;">
          <select id="editVariantLocalSelect_${variantKey}" style="flex:1; min-width:220px; font-size:0.76rem; padding:0.35rem 0.55rem;"></select>
          <button type="button" class="btn btn-primary btn-xs btn-link-local-build" id="btnLinkLocalBuild_${variantKey}" data-variant="${variantKey}" data-version="${escapeHtml(versionName)}">
            Vincular Seleccionado
          </button>
        </div>
        <div id="editVariantLocalEmptyHint_${variantKey}" class="edit-variant-picker-empty" style="display:none;"></div>
      </div>
    </div>
  `;
}

/**
 * Renderiza el estado y acciones de variantes físicas dentro del modal de edición
 */
function renderEditReleaseVariants(rel) {
  const container = document.getElementById('editRelVariantsContainer');
  if (!container) return;

  const universalData = getEditVariantData(rel, 'universal');
  const arm64Data = getEditVariantData(rel, 'arm64');
  const canUnlinkUniversal = canUnlinkEditVariantSlot(rel, 'universal').allowed;
  const canUnlinkArm64 = canUnlinkEditVariantSlot(rel, 'arm64').allowed;

  container.innerHTML = `
    <div style="display:flex; flex-direction:column; gap:0.75rem;">
      ${buildEditVariantCardHtml(rel, 'universal', 'Universal (~110 MB)', 'badge-universal', universalData, { canUnlink: canUnlinkUniversal })}
      ${buildEditVariantCardHtml(rel, 'arm64', 'ARM64 Ligero (~30 MB)', 'badge-arm64', arm64Data, { canUnlink: canUnlinkArm64 })}
    </div>
  `;
}

/**
 * Consulta APKs locales filtrados estrictamente por arquitectura ABI de la variante
 */
async function loadEditVariantLocalBuilds(variantKey, versionName) {
  const statusEl = document.getElementById(`editVariantLocalStatus_${variantKey}`);
  const selectEl = document.getElementById(`editVariantLocalSelect_${variantKey}`);
  const linkBtn = document.getElementById(`btnLinkLocalBuild_${variantKey}`);
  const emptyHintEl = document.getElementById(`editVariantLocalEmptyHint_${variantKey}`);
  if (!selectEl) return;

  const abiParam = variantKey === 'arm64' ? 'ARM64' : 'UNIVERSAL';
  if (statusEl) statusEl.textContent = `Escaneando APKs ${abiParam}...`;
  selectEl.innerHTML = `<option value="">Buscando APKs ${abiParam}...</option>`;
  selectEl.disabled = true;
  if (linkBtn) linkBtn.disabled = true;
  if (emptyHintEl) {
    emptyHintEl.style.display = 'none';
    emptyHintEl.textContent = '';
  }

  try {
    const res = await fetch(`/api/releases/detect-local-build?limit=24&abi=${encodeURIComponent(abiParam)}`);
    if (!res.ok) throw new Error('Error al consultar biblioteca local');
    const data = await res.json();

    const rawBuilds = Array.isArray(data.available_builds) ? data.available_builds : [];
    const compatibleBuilds = rawBuilds.filter((b) => validateApkAbiForVariantSlot(b.abi_variant, variantKey).ok);

    editModalLocalBuildsByVariant[variantKey] = compatibleBuilds;
    editModalLocalBuildsCache = compatibleBuilds;

    if (compatibleBuilds.length === 0) {
      if (statusEl) {
        statusEl.textContent = variantKey === 'arm64'
          ? 'Sin APKs ARM64 compatibles'
          : 'Sin APKs Universal compatibles';
      }
      selectEl.innerHTML = `<option value="">No hay APKs ${abiParam} compatibles detectados</option>`;
      selectEl.disabled = true;
      if (linkBtn) linkBtn.disabled = true;
      if (emptyHintEl) {
        emptyHintEl.style.display = 'block';
        emptyHintEl.textContent = variantKey === 'arm64'
          ? 'No se encontraron APKs ARM64 Ligero (~30 MB) en las rutas configuradas. Compílalo ejecutando compilar_apk_arm64.bat o agrega su carpeta desde "Rutas...".'
          : 'No se encontraron APKs Universal (~110 MB) en las rutas configuradas. Compílalo ejecutando compilar_apk_comercial.bat o agrega su carpeta desde "Rutas...".';
      }
      return;
    }

    if (statusEl) statusEl.textContent = `${compatibleBuilds.length} APK(s) ${abiParam} detectados`;
    selectEl.disabled = false;
    if (linkBtn) linkBtn.disabled = false;
    selectEl.innerHTML = '';

    compatibleBuilds.forEach((b, idx) => {
      const opt = document.createElement('option');
      opt.value = String(idx);
      const sizeStr = formatApkSizeMb(b.size_mb);
      const srcLower = (b.source_label || '').toLowerCase();
      const originStr = srcLower.includes('biblioteca')
        ? 'Biblioteca'
        : (srcLower.includes('compilación') || srcLower.includes('build') ? 'Build Local' : (b.source_label || 'Carpeta Local'));
      opt.textContent = `v${b.version_name || '?'} · ${b.abi_variant || abiParam} · ${sizeStr} · ${originStr} (${b.file_name || ''})`;
      if (b.version_name === versionName) {
        opt.selected = true;
      }
      selectEl.appendChild(opt);
    });
  } catch (e) {
    if (statusEl) statusEl.textContent = 'Error';
    selectEl.innerHTML = `<option value="">Error: ${escapeHtml(e.message)}</option>`;
    selectEl.disabled = true;
    if (linkBtn) linkBtn.disabled = true;
  }
}

/**
 * Abre o cierra el selector inline de Biblioteca Local para una variante en #modalEditRelease
 */
async function toggleEditVariantLocalPicker(variantKey, versionName) {
  const picker = document.getElementById(`editVariantLocalPicker_${variantKey}`);
  if (!picker) return;

  const isVisible = picker.style.display !== 'none';
  if (isVisible) {
    picker.style.display = 'none';
    return;
  }

  picker.style.display = 'flex';
  await loadEditVariantLocalBuilds(variantKey, versionName);
}

function closeEditVariantLocalPicker(variantKey) {
  const picker = document.getElementById(`editVariantLocalPicker_${variantKey}`);
  if (picker) picker.style.display = 'none';
}

async function openEditSearchDirsPanel() {
  const panel = document.getElementById('editSearchDirsPanel');
  if (!panel) return;
  panel.style.display = 'flex';
  await loadSearchDirsForContext('edit');
  if (typeof panel.scrollIntoView === 'function') {
    panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }
}

/**
 * Importa localmente el APK elegido de Biblioteca Local y lo vincula a la variante del release
 */
async function linkLocalBuildToReleaseVariant(versionName, variantKey) {
  const selectEl = document.getElementById(`editVariantLocalSelect_${variantKey}`);
  const idx = parseInt(selectEl?.value ?? '', 10);
  const variantList = Array.isArray(editModalLocalBuildsByVariant[variantKey]) && editModalLocalBuildsByVariant[variantKey].length > 0
    ? editModalLocalBuildsByVariant[variantKey]
    : editModalLocalBuildsCache;
  const build = Number.isInteger(idx) ? variantList[idx] : null;
  if (!build || !build.file_path) {
    showToast('Selecciona un APK válido de la lista local.', 'warning');
    return;
  }

  const preCheck = validateApkAbiForVariantSlot(build.abi_variant, variantKey);
  if (!preCheck.ok) {
    showToast(preCheck.error, 'error');
    return;
  }

  try {
    showToast(`Vinculando ${build.file_name} a v${versionName} (${variantKey.toUpperCase()})...`, 'info');
    const impRes = await fetch('/api/releases/import-local-apk', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ source_path: build.file_path }),
    });
    const impData = await impRes.json();
    if (!impRes.ok || !impData.ok) {
      throw new Error(impData.error || 'No se pudo importar el APK local');
    }

    const postCheck = validateApkAbiForVariantSlot(impData.abi_variant, variantKey);
    if (!postCheck.ok) {
      showToast(postCheck.error, 'error');
      return;
    }

    await commitReleaseVariantUpdate(
      versionName,
      variantKey,
      impData,
      impData.imported_path || impData.file_path,
      'desde biblioteca local'
    );
  } catch (err) {
    showToast('Error al vincular desde biblioteca: ' + err.message, 'error');
  }
}

function unlinkReleaseVariant(versionName, variantKey) {
  const rel = globalReleases.find(r => r.version_name === versionName);
  const check = canUnlinkEditVariantSlot(rel, variantKey);
  if (!check.allowed) {
    showToast(check.reason || 'No se puede desvincular esta variante.', 'warning');
    return;
  }

  const slotLabel = variantKey === 'arm64' ? 'ARM64 Ligero (~30 MB)' : 'Universal (~110 MB)';
  showConfirmModal(
    `Desvincular APK ${slotLabel}`,
    `¿Deseas desvincular la variante "${slotLabel}" de la versión v${versionName}? Los archivos físicos no se borrarán del disco y podrás volver a vincular otro APK cuando lo necesites.`,
    async () => {
      try {
        const payload = variantKey === 'arm64'
          ? { arm64_apk: null }
          : { universal_apk: null };
        const putRes = await fetch(`/api/releases/${encodeURIComponent(versionName)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        const updatedRel = await putRes.json().catch(() => ({}));
        if (!putRes.ok) {
          throw new Error(updatedRel.error || 'No se pudo desvincular la variante');
        }
        await syncReleaseAcrossUiAndComposer(versionName, updatedRel);
        showToast(`Variante ${slotLabel} desvinculada de v${versionName}.`, 'success');
      } catch (err) {
        showToast('Error al desvincular variante: ' + err.message, 'error');
      }
    },
    true
  );
}

function triggerVariantUpload(variant, versionName) {
  currentUploadVariantVersion = versionName;
  currentUploadVariantType = variant;
  const inputId = variant === 'arm64' ? 'editRelArm64Input' : 'editRelUniversalInput';
  const input = document.getElementById(inputId);
  if (input) {
    input.value = '';
    input.click();
  }
}

async function handleVariantFileSelected(file, variant, versionName) {
  if (!file || !versionName) return;
  if (!String(file.name || '').toLowerCase().endsWith('.apk')) {
    showToast('El archivo seleccionado no es un archivo .APK válido.', 'error');
    return;
  }
  showToast(`Analizando variante ${variant.toUpperCase()} para v${versionName}...`, 'info');
  try {
    const res = await fetch(`/api/releases/upload-apk?filename=${encodeURIComponent(file.name)}`, {
      method: 'POST',
      body: file,
    });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      throw new Error(data.error || 'Error al inspeccionar archivo subido');
    }

    const abiCheck = validateApkAbiForVariantSlot(data.abi_variant, variant);
    if (!abiCheck.ok) {
      showToast(abiCheck.error, 'error');
      return;
    }

    await commitReleaseVariantUpdate(
      versionName,
      variant,
      data,
      data.file_path,
      'por subida directa'
    );
  } catch (err) {
    showToast('Error al actualizar variante: ' + err.message, 'error');
  }
}

/**
 * Abre el modal de edición de versión
 */
function openEditReleaseModal(versionName) {
  const rel = globalReleases.find(r => r.version_name === versionName);
  if (!rel) return;

  document.getElementById('editRelVersionName').value = rel.version_name;
  document.getElementById('editRelVersionDisplay').value = `v${rel.version_name}`;
  document.getElementById('editRelVersionCode').value = rel.version_code || 82;
  document.getElementById('editRelDbSchema').value = rel.db_schema_version || 36;
  document.getElementById('editRelMinRequiredVersion').value = rel.min_required_version || '9.0.0';
  document.getElementById('editRelType').value = rel.type || 'FEATURE_RELEASE';
  document.getElementById('editRelDownloadUrl').value = rel.apk_download_url || '';
  document.getElementById('editRelChangelog').value = rel.changelog || '';
  document.getElementById('editRelInternalNotes').value = rel.internal_notes || '';

  if (typeof resetExpandableTextarea === 'function') {
    resetExpandableTextarea('editRelChangelog');
    resetExpandableTextarea('editRelInternalNotes');
  }
  const editDirsPanel = document.getElementById('editSearchDirsPanel');
  if (editDirsPanel) editDirsPanel.style.display = 'none';
  const newEditDirInp = document.getElementById('inputEditNewApkSearchDir');
  if (newEditDirInp) newEditDirInp.value = '';

  // Actualizar tarjeta explicativa reactiva
  updateReleaseTypeInfo('editRelType', 'editRelTypeInfoText');

  // Variantes físicas en disco con soporte de reemplazo/subida
  renderEditReleaseVariants(rel);

  openModal('modalEditRelease');
}

/**
 * Elimina una versión
 */
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

/**
 * Actualiza la información explicativa de tipo de release
 */
function updateReleaseTypeInfo(selectId, textId) {
  const sel = document.getElementById(selectId);
  const textEl = document.getElementById(textId);
  if (!sel || !textEl) return;

  if (sel.value === 'HOTFIX') {
    textEl.textContent = 'Parche de corrección o estabilidad. Derecho gratuito vitalicio para todos los clientes con la app instalada, incluidos Perpetuos sin pase vigente.';
  } else {
    textEl.textContent = 'Nuevas funciones comerciales. Gratis para suscripciones activas, Trial y Perpetuos con pase de updates vigente; requiere Pase Anual (S/ 150.00) o cortesía para Perpetuos con pase vencido.';
  }
}

/**
 * Carga la matriz de distribución desde el backend
 */
async function loadReleaseMatrix() {
  try {
    const res = await fetch('/api/releases/matrix', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar matriz');
    globalReleaseMatrix = await res.json();
    renderReleaseMatrix();
  } catch (e) {
    console.error('Error al cargar matriz:', e);
  }
}

/**
 * Establece el filtro activo de la matriz
 */
function setMatrixFilter(filterType) {
  currentMatrixFilter = filterType;
  const chips = document.querySelectorAll('#matrixFilterChips .rel-chip');
  chips.forEach(c => {
    if (c.getAttribute('data-filter') === filterType) {
      c.classList.add('active');
    } else {
      c.classList.remove('active');
    }
  });
  renderReleaseMatrix();
}

/**
 * Renderiza la matriz de distribución y la barra de progreso de despliegue
 */
function renderReleaseMatrix() {
  const tbody = document.getElementById('matrixTableBody');
  if (!tbody) return;
  tbody.innerHTML = '';

  if (!globalReleaseMatrix || globalReleaseMatrix.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Sin clientes para evaluar matriz.</td></tr>';
    updateRolloutProgress(0, 0, 0, 0);
    return;
  }

  // Identificar última versión lanzada
  const latestRelease = globalReleases?.[0];
  const latestVersion = latestRelease?.version_name || (globalReleaseMatrix[0]?.latest_version || '9.38.0');

  // Calcular métricas de despliegue global (excluyendo prospectos sin app instalada)
  let totalWithApp = 0;
  let countUpToDate = 0;
  let countSent = 0;
  let countOutdated = 0;

  globalReleaseMatrix.forEach(row => {
    const isProspect = (row.situation === 'PROSPECTO') || (row.license_type === 'PROSPECTO') || (row.update_status === 'PROSPECT');
    if (isProspect) return;

    totalWithApp++;
    const status = row.update_status || (row.is_up_to_date ? 'UP_TO_DATE' : 'OUTDATED');
    if (status === 'UP_TO_DATE' || status === 'AHEAD') {
      countUpToDate++;
    } else if (status === 'SENT') {
      countSent++;
    } else {
      countOutdated++;
    }
  });

  updateRolloutProgress(totalWithApp, countUpToDate, countSent, countOutdated);

  // Filtrado de filas
  const term = currentMatrixSearch.trim().toLowerCase();
  const filtered = globalReleaseMatrix.filter(row => {
    // Filtro por texto
    if (term) {
      const matchText = (row.business_name || '').toLowerCase().includes(term) ||
                        (row.owner_name || '').toLowerCase().includes(term) ||
                        (row.phone || '').includes(term) ||
                        (row.installed_version || '').includes(term);
      if (!matchText) return false;
    }

    const isProspect = (row.situation === 'PROSPECTO') || (row.license_type === 'PROSPECTO') || (row.update_status === 'PROSPECT');
    const status = row.update_status || (row.is_up_to_date ? 'UP_TO_DATE' : 'OUTDATED');

    if (currentMatrixFilter === 'ALL') {
      return true;
    } else if (currentMatrixFilter === 'OUTDATED') {
      return !isProspect && (status === 'OUTDATED');
    } else if (currentMatrixFilter === 'REQUIRES_PASS') {
      return !isProspect && !row.is_eligible_for_free && (status === 'OUTDATED');
    } else if (currentMatrixFilter === 'SENT') {
      return !isProspect && (status === 'SENT');
    } else if (currentMatrixFilter === 'UP_TO_DATE') {
      return !isProspect && (status === 'UP_TO_DATE' || status === 'AHEAD');
    }
    return true;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No se encontraron clientes con el filtro aplicado.</td></tr>';
    return;
  }

  filtered.forEach(row => {
    const tr = document.createElement('tr');
    const isProspect = (row.situation === 'PROSPECTO') || (row.license_type === 'PROSPECTO') || (row.update_status === 'PROSPECT');
    const status = row.update_status || (row.is_up_to_date ? 'UP_TO_DATE' : 'OUTDATED');
    const cmp = compareSemVer(row.installed_version, row.latest_version);

    // Estado & Derecho Badge
    let statusBadge = '';
    if (isProspect) {
      statusBadge = '<span class="badge" style="background:rgba(148,163,184,0.15); color:var(--text-muted);">Prospecto (Sin App)</span>';
    } else if (status === 'AHEAD' || cmp > 0) {
      statusBadge = `<span class="badge badge-ahead" title="Cliente cuenta con versión superior de prueba o desarrollo">Versión superior (v${escapeHtml(row.installed_version)})</span>`;
    } else if (status === 'UP_TO_DATE' || row.is_up_to_date) {
      statusBadge = '<span class="badge badge-green"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> Al Día</span>';
    } else if (status === 'SENT') {
      let sentDate = '';
      if (row.last_apk_sent_at) {
        const isoDate = String(row.last_apk_sent_at).substring(0, 10).split('-');
        sentDate = isoDate.length === 3 ? `${isoDate[2]}/${isoDate[1]}` : '';
      }
      statusBadge = `<span class="badge badge-sent" title="APK enviado: pendiente de confirmación en cliente">Enviado ${sentDate}</span>`;
    } else {
      statusBadge = row.is_eligible_for_free
        ? '<span class="badge badge-yellow">Desactualizado (Derecho Gratuito)</span>'
        : '<span class="badge" style="background:rgba(239,68,68,0.15); color:#ef4444; border:1px solid rgba(239,68,68,0.3);">Requiere Pase</span>';
    }

    const cleanPhone = (row.phone || '').replace(/[^0-9]/g, '');
    const phoneDisplay = formatPeruvianPhoneDisplay(row.phone);

    let actionButtons = '<span style="color:var(--text-muted); font-size:0.8rem;">Sin acción requerida</span>';

    if (!isProspect && (status === 'OUTDATED' || status === 'SENT')) {
      if (row.is_eligible_for_free) {
        const sendLabel = status === 'SENT' ? 'Reenviar APK' : 'Enviar APK';
        actionButtons = `
          <button type="button" class="btn btn-wa btn-sm" onclick="openApkDispatchComposer('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}', 'eligible')" title="${sendLabel} por WhatsApp con copia de binario APK al portapapeles">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 2L11 13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
            ${sendLabel}
          </button>
          <button type="button" class="btn btn-outline btn-sm" onclick="markClientUpdated('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}')" title="Marcar como actualizado a v${escapeHtml(row.latest_version)}">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="20 6 9 17 4 12"/></svg>
            Marcar Actualizado
          </button>
        `;
      } else {
        actionButtons = `
          <button type="button" class="btn btn-outline btn-sm" onclick="openApkDispatchComposer('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}', 'quote')" title="Cotizar Pase Anual de Actualizaciones por WhatsApp">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
            Cotizar Pase
          </button>
          <button type="button" class="btn btn-primary btn-sm" onclick="jumpToIssuePass('${escapeHtml(row.client_id)}')" title="Ir a Emitir Pase Anual">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
            Emitir Pase
          </button>
          <button type="button" class="btn btn-outline btn-sm" style="opacity:0.85;" onclick="authorizeCourtesyUpdate('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}', '${escapeHtml(row.business_name)}', '${cleanPhone}', '${escapeHtml(row.owner_name)}')" title="Autorizar Envío de Cortesía Excepcional">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="20 12 20 22 4 22 4 12"/><rect x="2" y="7" width="20" height="5"/><line x1="12" y1="22" x2="12" y2="7"/></svg>
            Cortesía
          </button>
        `;
      }
    } else if (!isProspect && (status === 'UP_TO_DATE' || status === 'AHEAD' || row.is_up_to_date || cmp >= 0)) {
      actionButtons = `
        <button type="button" class="btn btn-outline btn-sm" onclick="openApkDispatchComposer('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}', 'resend')" title="Reenviar APK o elegir versión para este cliente">
          <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 2L11 13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
          Reenviar / Elegir APK
        </button>
      `;
    }

    tr.innerHTML = `
      <td>
        <strong>${escapeHtml(row.business_name)}</strong>
        <div style="font-size:0.75rem; color:var(--text-muted);">${escapeHtml(row.owner_name || '')}</div>
      </td>
      <td>${escapeHtml(phoneDisplay)}</td>
      <td>
        <div class="matrix-installed-ver-cell">
          <span>v${escapeHtml(row.installed_version)}</span>
          ${!isProspect ? `
            <button type="button" class="btn-micro-edit-ver" data-fix-client-id="${escapeHtml(row.client_id)}" title="Corregir versión instalada">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
            </button>
          ` : ''}
        </div>
      </td>
      <td>v${escapeHtml(row.latest_version)}</td>
      <td>${escapeHtml(row.release_type || 'FEATURE_RELEASE')}</td>
      <td>${statusBadge}</td>
      <td>
        <div style="display:flex; gap:0.4rem; flex-wrap:wrap; align-items:center;">
          ${actionButtons}
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

/**
 * Actualiza los contadores y barra segmentada de despliegue
 */
function updateRolloutProgress(total, upToDate, sent, pending) {
  const totalEl = document.getElementById('rolloutTotal');
  const upToDateEl = document.getElementById('rolloutUpToDate');
  const sentEl = document.getElementById('rolloutSent');
  const pendingEl = document.getElementById('rolloutPending');

  const segUp = document.getElementById('segmentUpToDate');
  const segSent = document.getElementById('segmentSent');
  const segPen = document.getElementById('segmentPending');

  if (totalEl) totalEl.textContent = total;

  if (total === 0) {
    if (upToDateEl) upToDateEl.textContent = '0 (0%)';
    if (sentEl) sentEl.textContent = '0 (0%)';
    if (pendingEl) pendingEl.textContent = '0 (0%)';
    if (segUp) segUp.style.width = '0%';
    if (segSent) segSent.style.width = '0%';
    if (segPen) segPen.style.width = '100%';
    return;
  }

  const pctUp = Math.round((upToDate / total) * 100);
  const pctSent = Math.round((sent / total) * 100);
  const pctPen = Math.max(0, 100 - pctUp - pctSent);

  if (upToDateEl) upToDateEl.textContent = `${upToDate} (${pctUp}%)`;
  if (sentEl) sentEl.textContent = `${sent} (${pctSent}%)`;
  if (pendingEl) pendingEl.textContent = `${pending} (${pctPen}%)`;

  if (segUp) segUp.style.width = `${pctUp}%`;
  if (segSent) segSent.style.width = `${pctSent}%`;
  if (segPen) segPen.style.width = `${pctPen}%`;
}

/**
 * Registra despacho comercial de APK en backend
 */
async function recordApkSent(clientId, version, variant = 'universal') {
  try {
    await fetch('/api/releases/mark-sent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: clientId, version: version, variant: variant })
    });
    await loadReleaseMatrix();
  } catch (_) {}
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
      showToast(`Cortesía autorizada para ${businessName}. Abriendo compositor de despacho...`, 'success');
      openApkDispatchComposer(clientId, latestVersion, 'courtesy');
    }
  );
}

function parseApkSizeMbNumber(raw) {
  if (raw === null || raw === undefined) return null;
  const cleaned = String(raw).trim().replace(/\s*MB\s*$/i, '').trim();
  if (!cleaned) return null;
  const num = Number(cleaned);
  return (!Number.isNaN(num) && Number.isFinite(num)) ? num : null;
}

function updateWaApkSizeWarning(rawSize, hasArm64 = false) {
  const warnEl = document.getElementById('waApkSizeWarning');
  const sizeLabelEl = document.getElementById('waApkWarningSizeLabel');
  const adviceEl = document.getElementById('waApkWarningAdvice');
  if (!warnEl) return;

  const sizeNum = parseApkSizeMbNumber(rawSize);
  if (sizeNum !== null && sizeNum > 100) {
    warnEl.style.display = 'flex';
    if (sizeLabelEl) sizeLabelEl.textContent = formatApkSizeMb(rawSize);
    if (adviceEl) {
      adviceEl.textContent = (hasArm64 && currentDispatchVariant !== 'arm64')
        ? 'Puedes cambiar arriba a la variante ARM64 Ligero (<= 100 MB), usar WhatsApp Desktop (hasta 2 GB) o compartir el enlace externo.'
        : 'Usa WhatsApp Desktop (admite hasta 2 GB) o comparte un enlace externo de Google Drive para evitar el bloqueo de 100 MB en WhatsApp Web.';
    }
  } else {
    warnEl.style.display = 'none';
  }
}

function toggleWaApkDispatchPanelVisibility(show) {
  isApkDispatchMode = !!show;
  const dispatchPanel = document.getElementById('waApkDispatchPanel');
  const standardFooter = document.getElementById('waStandardFooterActions');
  const dispatchFooter = document.getElementById('waApkDispatchFooterActions');
  const copyHint = document.getElementById('waApkCopySuccessHint');
  const sizeWarn = document.getElementById('waApkSizeWarning');

  if (dispatchPanel) dispatchPanel.style.display = show ? 'block' : 'none';
  if (standardFooter) standardFooter.style.display = show ? 'none' : 'flex';
  if (dispatchFooter) dispatchFooter.style.display = show ? 'flex' : 'none';
  if (!show) {
    if (copyHint) copyHint.style.display = 'none';
    if (sizeWarn) sizeWarn.style.display = 'none';
  }
}

function ensureWaDispatchReleaseInitialized() {
  if (currentDispatchRelease) return currentDispatchRelease;
  const sorted = [...(globalReleases || [])].sort((a, b) => compareSemVer(b.version_name, a.version_name));
  if (sorted.length > 0) {
    currentDispatchRelease = sorted[0];
  } else {
    currentDispatchRelease = {
      version_name: '9.40.0',
      version_code: 84,
      db_schema_version: 36,
      type: 'FEATURE_RELEASE',
      file_size_mb: '108.47 MB',
      changelog: 'Mejoras clave de rendimiento, estabilidad y nuevas funciones comerciales.',
      signature_status: 'OFFICIAL_RELEASE',
      signature_verified: true,
    };
  }
  return currentDispatchRelease;
}

function populateWaApkVersionSelect(selectedVersion) {
  const selectEl = document.getElementById('waApkVersionSelect');
  if (!selectEl) return;

  const list = [...(globalReleases || [])].sort((a, b) => compareSemVer(b.version_name, a.version_name));
  if (selectedVersion && !list.some(r => r.version_name === selectedVersion) && currentDispatchRelease) {
    list.unshift(currentDispatchRelease);
  }

  selectEl.innerHTML = '';
  list.forEach(rel => {
    const opt = document.createElement('option');
    opt.value = rel.version_name;
    const typeLabel = rel.type === 'HOTFIX' ? 'HOTFIX' : 'FEATURE';
    opt.textContent = `v${rel.version_name} (Build ${rel.version_code || '-'}) — ${typeLabel}`;
    selectEl.appendChild(opt);
  });

  if (selectedVersion) {
    selectEl.value = selectedVersion;
  } else if (list.length > 0) {
    selectEl.value = list[0].version_name;
  }
}

function buildApkDispatchMessage(rel, client, mode = 'eligible') {
  const author = ownerConfig?.legal_identity?.author_full_name || 'Julio Angello Vasquez Navarro';
  const ownerName = client?.owner_name || 'Estimado(a) Cliente';
  const bizName = client?.business_name || 'tu negocio';

  if (mode === 'quote') {
    const passPrice = (ownerConfig?.catalog?.PASE_ACTUALIZACION_ANUAL?.price || 150).toFixed(2);
    const installedVer = client?.installed_version || client?.version || '9.0.0';
    return `Hola ${ownerName}, te saluda ${author} de MochilaLista.\n\n` +
      `Acabamos de lanzar la versión oficial *v${rel.version_name}* con mejoras avanzadas.\n` +
      `Tu negocio *${bizName}* cuenta actualmente con la versión v${installedVer}.\n\n` +
      `Para acceder a este paquete de nuevas funciones y soporte continuo, puedes adquirir tu *Pase Anual de Actualizaciones* por solo S/ ${passPrice}.\n\n` +
      `¿Deseas que coordinemos la activación del pase hoy mismo?`;
  }

  const hasDriveUrl = Boolean(rel.apk_download_url && rel.apk_download_url.startsWith('http') && !rel.apk_download_url.includes('localhost'));
  const downloadPart = hasDriveUrl
    ? `*Enlace de Descarga Directa:*\n${rel.apk_download_url}\n\n`
    : (mode === 'courtesy'
        ? `*Archivo APK:* Se adjunta directamente en este chat como cortesía especial para tu negocio.\n\n`
        : `*Archivo APK:* Se adjunta directamente en este chat para su instalación.\n\n`);
  const changelogText = rel.changelog || 'Mejoras clave de rendimiento, estabilidad y nuevas funciones comerciales.';

  if (mode === 'courtesy') {
    return `Hola ${ownerName}, te saluda ${author} de MochilaLista.\n\n` +
      `Como cortesía especial por tu fidelidad comercial, te hemos liberado el acceso directo a la nueva versión *v${rel.version_name}* para tu negocio *${bizName}*.\n\n` +
      `*Versión:* MochilaLista v${rel.version_name}\n` +
      `*Novedades:*\n${changelogText}\n\n` +
      `${downloadPart}` +
      `*Garantía Cero Pérdida:* Al instalar este APK sobre el actual, tu base de datos y productos se mantienen 100% intactos.`;
  }

  if (mode === 'resend') {
    return `Hola ${ownerName}, te saluda ${author} de MochilaLista.\n\n` +
      `Te compartimos nuevamente el instalador oficial para *${bizName}*.\n\n` +
      `*Versión:* MochilaLista v${rel.version_name} (Build ${rel.version_code || 82})\n` +
      `*Novedades:*\n${changelogText}\n\n` +
      `${downloadPart}` +
      `*Garantía Cero Pérdida:* Al instalar este APK sobre el actual, tu base de datos y productos se mantienen 100% intactos.`;
  }

  return `Hola ${ownerName}, te saluda ${author} de MochilaLista.\n\n` +
    `¡Tenemos lista una nueva actualización oficial para *${bizName}*!\n\n` +
    `*Versión:* MochilaLista v${rel.version_name} (Build ${rel.version_code || 82})\n` +
    `*Novedades:*\n${changelogText}\n\n` +
    `${downloadPart}` +
    `*Garantía Cero Pérdida:* Al instalar este APK sobre el actual, tu base de datos y productos se mantienen 100% intactos.`;
}

function syncWaApkDispatchPanel(rel, options = {}) {
  if (!rel) return;
  currentDispatchRelease = rel;

  populateWaApkVersionSelect(rel.version_name);

  const copyHintEl = document.getElementById('waApkCopySuccessHint');
  if (copyHintEl && !options.preserveCopyHint) {
    copyHintEl.style.display = 'none';
  }

  // Evaluar disponibilidad de variantes
  const hasUniversal = !!rel.universal_apk || (!rel.universal_apk && !rel.arm64_apk);
  const hasArm64 = !!rel.arm64_apk;

  const univCard = document.getElementById('waVariantCardUniversal');
  const armCard = document.getElementById('waVariantCardArm64');
  const univDesc = document.getElementById('waVariantDescUniversal');
  const armDesc = document.getElementById('waVariantDescArm64');

  if (univCard) {
    if (hasUniversal) {
      univCard.classList.remove('disabled');
      if (univDesc) {
        const uSize = formatApkSizeMb(rel.universal_apk?.file_size_mb || rel.file_size_mb);
        univDesc.textContent = uSize !== '-'
          ? `Compatible con cualquier celular Android (${uSize})`
          : 'Compatible con cualquier celular Android';
      }
    } else {
      univCard.classList.add('disabled');
      if (univDesc) univDesc.textContent = 'No disponible para esta versión';
    }
  }

  if (armCard) {
    if (hasArm64) {
      armCard.classList.remove('disabled');
      if (armDesc) {
        const aSize = formatApkSizeMb(rel.arm64_apk?.file_size_mb);
        armDesc.textContent = aSize !== '-'
          ? `Rápido para transferir por WhatsApp (${aSize})`
          : 'Rápido para transferir por WhatsApp (celulares modernos)';
      }
    } else {
      armCard.classList.add('disabled');
      if (armDesc) armDesc.textContent = 'No disponible para esta versión';
    }
  }

  // Selección inteligente por defecto
  if (hasUniversal) {
    setDispatchVariant('universal');
  } else if (hasArm64) {
    setDispatchVariant('arm64');
  } else {
    setDispatchVariant('universal');
  }

  // Encabezado técnico
  const titleEl = document.getElementById('waApkVersionTitle');
  if (titleEl) {
    titleEl.textContent = `Despacho de APK: v${rel.version_name} (Build ${rel.version_code || 82})`;
  }

  const dbSchemaEl = document.getElementById('waApkDbSchema');
  if (dbSchemaEl) {
    dbSchemaEl.textContent = `Esquema v${rel.db_schema_version || 36}`;
  }

  const diskStatusEl = document.getElementById('waApkDiskStatus');
  if (diskStatusEl) {
    const hasPath = !!(rel.apk_file_path || rel.universal_apk?.file_path || rel.arm64_apk?.file_path);
    const hasAnyFile = hasPath && rel.file_exists !== false;
    if (hasAnyFile) {
      diskStatusEl.textContent = 'Verificado en Disco';
      diskStatusEl.style.color = '#22c55e';
    } else {
      diskStatusEl.textContent = 'Sin Binario en Disco';
      diskStatusEl.style.color = '#ef4444';
    }
  }

  const sigBadgeEl = document.getElementById('waApkSigBadge');
  if (sigBadgeEl) {
    sigBadgeEl.innerHTML = renderSignatureStatusBadge(rel.signature_status, rel.signature_verified, 'Oficial RSA-4096');
  }

  // Actualizar texto comercial conservando chips Insertar activos
  if (!options.skipMessageUpdate && (currentWaComposerTemplateKey === 'update' || isApkDispatchMode)) {
    const textarea = document.getElementById('waCompMessage');
    const client = getCurrentWaComposerClient();
    if (textarea && client) {
      const { activeKeys } = extractBaseAndSnippetsFromText(textarea.value || '');
      const updatedBase = buildApkDispatchMessage(rel, client, currentDispatchMode);
      currentWaRenderedTemplateBase = updatedBase;

      let nextValue = updatedBase;
      activeKeys.forEach(k => {
        const blk = buildWaSnippetBlock(k, { notify: false });
        if (blk) nextValue = appendSnippetBlockToText(nextValue, blk);
      });

      textarea.value = nextValue;
      updateWaComposerStats();
      syncWaInsertChipsState();
    }
  }
}

function onChangeDispatchReleaseVersion(versionName, options = {}) {
  const rel = (globalReleases && globalReleases.find(r => r.version_name === versionName)) || currentDispatchRelease;
  if (!rel) return;
  syncWaApkDispatchPanel(rel, options);
}

/**
 * Cambia la variante activa en el compositor de despacho APK
 */
function setDispatchVariant(variant) {
  currentDispatchVariant = variant;
  const univCard = document.getElementById('waVariantCardUniversal');
  const armCard = document.getElementById('waVariantCardArm64');

  if (univCard) {
    if (variant === 'universal') univCard.classList.add('active');
    else univCard.classList.remove('active');
  }
  if (armCard) {
    if (variant === 'arm64') armCard.classList.add('active');
    else armCard.classList.remove('active');
  }

  // Actualizar tamaño de APK mostrado siempre con formato MB y evaluar aviso >100 MB
  const sizeEl = document.getElementById('waApkSizeText');
  let rawSize = '';
  if (currentDispatchRelease) {
    if (variant === 'arm64' && currentDispatchRelease.arm64_apk?.file_size_mb) {
      rawSize = currentDispatchRelease.arm64_apk.file_size_mb;
    } else if (variant === 'universal' && currentDispatchRelease.universal_apk?.file_size_mb) {
      rawSize = currentDispatchRelease.universal_apk.file_size_mb;
    } else {
      rawSize = currentDispatchRelease.file_size_mb || '';
    }
  }
  if (sizeEl) {
    sizeEl.textContent = formatApkSizeMb(rawSize);
  }
  const hasArm64 = !!(currentDispatchRelease && currentDispatchRelease.arm64_apk);
  updateWaApkSizeWarning(rawSize, hasArm64);
}

/**
 * Abre el Compositor Universal en modo Despacho Asistido de APK (Plan 19 / 22 Fase 3)
 */
function openApkDispatchComposer(clientId, versionName, mode = 'eligible') {
  const client = (globalClients && globalClients.find(c => c.id === clientId)) ||
                 (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === clientId));
  if (!client) {
    showToast('Cliente no encontrado para despacho de APK.', 'error');
    return;
  }

  const rel = (globalReleases && globalReleases.find(r => r.version_name === versionName)) ||
              (globalReleases && globalReleases[0]) || {
                version_name: versionName,
                version_code: 84,
                db_schema_version: 36,
                type: 'FEATURE_RELEASE',
                file_size_mb: '108.47 MB',
                changelog: 'Mejoras clave de rendimiento, estabilidad y nuevas funciones comerciales.',
                signature_status: 'OFFICIAL_RELEASE',
                signature_verified: true,
              };

  currentDispatchRelease = rel;
  currentDispatchClient = client;
  currentDispatchMode = mode;

  const customMessage = buildApkDispatchMessage(rel, client, mode);

  openWhatsAppComposer(clientId, 'update', {
    isApkDispatch: true,
    release: rel,
    customMessage: customMessage,
  });
}

async function copyCurrentDispatchApkToClipboard() {
  if (!currentDispatchRelease) return { ok: false };
  const versionName = currentDispatchRelease.version_name;
  const variant = currentDispatchVariant || 'universal';
  const copyHintEl = document.getElementById('waApkCopySuccessHint');
  const copyHintTextEl = document.getElementById('waApkCopySuccessText');

  const copyRes = await fetch(`/api/releases/${encodeURIComponent(versionName)}/copy-file?variant=${encodeURIComponent(variant)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  });
  const copyData = await copyRes.json().catch(() => ({}));

  if (!copyRes.ok || copyData.ok !== true) {
    if (copyHintEl) copyHintEl.style.display = 'none';
    const errMsg = copyRes.status === 404
      ? `No se encontró el archivo .apk físico en disco para v${versionName} (${variant}).`
      : (copyData.error || 'No se pudo copiar el archivo .apk al portapapeles de Windows.');
    showToast(errMsg, 'error');
    return { ok: false, error: errMsg };
  }

  const fileName = copyData.file_name || `mochilalista-v${versionName}.apk`;
  showToast(`Archivo .apk copiado: presiona Ctrl + V en WhatsApp (${fileName}).`, 'success');
  if (copyHintEl) copyHintEl.style.display = 'flex';
  if (copyHintTextEl) {
    copyHintTextEl.textContent = `Listo en portapapeles de Windows: ${fileName} — En el chat de WhatsApp que se abrió, presiona Ctrl + V para adjuntar el archivo.`;
  }
  return { ok: true, data: copyData, fileName };
}

async function reCopyCurrentDispatchApk() {
  const btn = document.getElementById('btnWaReCopyApk');
  if (btn) btn.disabled = true;
  try {
    await copyCurrentDispatchApkToClipboard();
  } catch (e) {
    showToast('Error al volver a copiar APK: ' + e.message, 'error');
  } finally {
    if (btn) btn.disabled = false;
  }
}

/**
 * Copia el binario .APK al portapapeles de Windows y abre WhatsApp (Acción Principal de Fase 3)
 */
async function copyApkAndOpenWhatsApp() {
  if (!currentDispatchRelease) return;
  const versionName = currentDispatchRelease.version_name;
  const variant = currentDispatchVariant || 'universal';
  const clientId = currentWaComposerClientId;
  const client = getCurrentWaComposerClient();

  let rawPhone = (client?.phone || '').trim();
  let cleanDigits = rawPhone.replace(/[^0-9]/g, '');
  if (cleanDigits.length === 9 && !cleanDigits.startsWith('51')) {
    cleanDigits = '51' + cleanDigits;
  }
  const hasValidPhone = cleanDigits.length >= 9;

  const btn = document.getElementById('btnWaCopyApkAndSend');
  if (btn) btn.disabled = true;

  try {
    // 1. Verificar explícitamente POST /api/releases/:version/copy-file?variant=...
    const copyOutcome = await copyCurrentDispatchApkToClipboard();
    if (!copyOutcome.ok) {
      return;
    }

    // 2. Registrar trazabilidad comercial de despacho en backend
    if (clientId) {
      await recordApkSent(clientId, versionName, variant);
    }

    // 3. Abrir WhatsApp oficial si el cliente tiene teléfono registrado
    const text = document.getElementById('waCompMessage')?.value || '';
    if (hasValidPhone) {
      const waUrl = `https://api.whatsapp.com/send?phone=${cleanDigits}&text=${encodeURIComponent(text)}`;
      window.open(waUrl, '_blank');
    } else {
      showToast('Teléfono no registrado: APK copiado, pero WhatsApp no se abrió automáticamente.', 'info');
    }

    // 4. Refrescar matriz en vivo conservando el modal abierto con #waApkCopySuccessHint visible
    await loadReleaseMatrix();
  } catch (e) {
    showToast('Error en despacho asistido: ' + e.message, 'error');
  } finally {
    if (btn) btn.disabled = false;
  }
}

/**
 * Abre en el explorador de Windows la carpeta del APK a despachar
 */
function revealCurrentDispatchApkFolder() {
  if (!currentDispatchRelease) return;
  revealReleaseInExplorer(currentDispatchRelease.version_name, currentDispatchVariant);
}

/**
 * Despacha únicamente el mensaje de texto por WhatsApp sin copiar binario
 */
async function sendWaDispatchTextOnly() {
  if (!currentDispatchRelease) return;
  const versionName = currentDispatchRelease.version_name;
  const variant = currentDispatchVariant || 'universal';
  const clientId = currentWaComposerClientId;
  const client = (globalClients && globalClients.find(c => c.id === clientId)) ||
                 (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === clientId)) ||
                 currentDispatchClient;

  let rawPhone = (client?.phone || '').trim();
  let cleanDigits = rawPhone.replace(/[^0-9]/g, '');
  if (cleanDigits.length === 9 && !cleanDigits.startsWith('51')) {
    cleanDigits = '51' + cleanDigits;
  }
  const hasValidPhone = cleanDigits.length >= 9;

  if (clientId) {
    await recordApkSent(clientId, versionName, variant);
  }

  const text = document.getElementById('waCompMessage')?.value || '';
  if (hasValidPhone) {
    const waUrl = `https://api.whatsapp.com/send?phone=${cleanDigits}&text=${encodeURIComponent(text)}`;
    window.open(waUrl, '_blank');
  }

  closeModal('modalWaComposer');
  await loadReleaseMatrix();
}

async function markClientUpdated(clientId, versionName, options = {}) {
  const force = !!options.force;
  const silentUndo = !!options.silentUndo;
  try {
    const res = await fetch(`/api/clients/${clientId}/mark-updated`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ version_name: versionName, force: force }),
    });
    if (!res.ok) throw new Error('Error al marcar cliente actualizado');
    const data = await res.json().catch(() => ({}));
    const updatedVer = data.installed_version || versionName;
    const prevVer = data.previous_installed_version;

    if (!silentUndo && prevVer && prevVer !== updatedVer) {
      showToast(`Cliente actualizado a v${updatedVer} (antes v${prevVer}).`, 'success', {
        duration: 8000,
        actionLabel: 'Deshacer',
        onAction: async () => {
          await markClientUpdated(clientId, prevVer, { force: true, silentUndo: true });
        },
      });
    } else {
      showToast(`Cliente actualizado a v${updatedVer} en el registro.`, 'success');
    }

    await loadReleaseMatrix();
    await loadClients();
    await loadReleases();
    await loadDashboard();
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

/**
 * Abre el modal compacto para corregir manualmente la versión instalada (force: true)
 */
function openFixClientVersionModal(clientId) {
  const row = (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === clientId)) ||
              (globalClients && globalClients.find(c => c.id === clientId));
  if (!row) {
    showToast('Cliente no encontrado.', 'error');
    return;
  }

  const currentVer = String(row.installed_version || '9.0.0').trim();
  const idInput = document.getElementById('fixClientVersionId');
  const bizEl = document.getElementById('fixClientVersionBiz');
  const curEl = document.getElementById('fixClientVersionCurrent');
  const selEl = document.getElementById('fixClientVersionSelect');
  const customInput = document.getElementById('fixClientVersionInput');

  if (idInput) idInput.value = clientId;
  if (bizEl) bizEl.textContent = row.business_name || row.owner_name || clientId;
  if (curEl) curEl.textContent = `v${currentVer}`;
  if (customInput) customInput.value = currentVer;

  if (selEl) {
    selEl.innerHTML = '';
    const seen = new Set();
    const versions = [];
    (globalReleases || []).forEach(r => {
      if (r.version_name && !seen.has(r.version_name)) {
        seen.add(r.version_name);
        versions.push({
          version: r.version_name,
          label: `v${r.version_name} (${r.type === 'HOTFIX' ? 'HOTFIX' : 'FEATURE'})`,
        });
      }
    });
    if (!seen.has(currentVer)) {
      versions.push({ version: currentVer, label: `v${currentVer} (actual)` });
    }
    versions.forEach(item => {
      const opt = document.createElement('option');
      opt.value = item.version;
      opt.textContent = item.label;
      if (item.version === currentVer) opt.selected = true;
      selEl.appendChild(opt);
    });
    const manualOpt = document.createElement('option');
    manualOpt.value = '__CUSTOM__';
    manualOpt.textContent = 'Otra versión manual...';
    selEl.appendChild(manualOpt);
  }

  openModal('modalFixClientVersion');
}

/**
 * Inicializa los controladores de carga, drag & drop y autodetección de APK
 */
function initReleaseUploadAndAutoDetect() {
  const dropZone = document.getElementById('apkDropZone');
  const fileInput = document.getElementById('apkFileInput');
  const relTypeSelect = document.getElementById('relType');
  const editRelTypeSelect = document.getElementById('editRelType');
  const matrixSearchInput = document.getElementById('inputRelMatrixSearch');

  // Listeners reactivos de tipo de release
  relTypeSelect?.addEventListener('change', () => {
    updateReleaseTypeInfo('relType', 'relTypeInfoText');
  });

  editRelTypeSelect?.addEventListener('change', () => {
    updateReleaseTypeInfo('editRelType', 'editRelTypeInfoText');
  });

  // Búsqueda en vivo en matriz de distribución
  matrixSearchInput?.addEventListener('input', (e) => {
    currentMatrixSearch = e.target.value;
    renderReleaseMatrix();
  });

  // Delegación segura para corrección rápida de versión en matriz (sin window.prompt)
  document.getElementById('matrixTableBody')?.addEventListener('click', (e) => {
    const btn = e.target.closest('.btn-micro-edit-ver');
    if (!btn) return;
    const clientId = btn.dataset.fixClientId;
    if (clientId) openFixClientVersionModal(clientId);
  });

  document.getElementById('fixClientVersionSelect')?.addEventListener('change', (e) => {
    const val = e.target.value;
    const customInput = document.getElementById('fixClientVersionInput');
    if (!customInput) return;
    if (val === '__CUSTOM__') {
      customInput.focus();
      customInput.select();
    } else {
      customInput.value = val;
    }
  });

  document.getElementById('btnSubmitFixClientVersion')?.addEventListener('click', async () => {
    const clientId = document.getElementById('fixClientVersionId')?.value;
    const rawVer = document.getElementById('fixClientVersionInput')?.value?.trim() || '';
    const cleanVer = rawVer.replace(/^[vV]/, '');
    if (!clientId || !cleanVer) {
      showToast('Ingresa una versión SemVer válida (ej: 9.38.0).', 'warning');
      return;
    }
    closeModal('modalFixClientVersion');
    await markClientUpdated(clientId, cleanVer, { force: true, silentUndo: false });
  });

  // Delegación en tarjetas de variantes de #modalEditRelease
  document.getElementById('editRelVariantsContainer')?.addEventListener('click', (e) => {
    const copyBtn = e.target.closest('.btn-copy-variant-sha');
    if (copyBtn) {
      copyPlainTextToClipboard(copyBtn.dataset.sha, 'Hash SHA-256 copiado al portapapeles.');
      return;
    }

    const togglePickerBtn = e.target.closest('.btn-toggle-local-picker');
    if (togglePickerBtn) {
      toggleEditVariantLocalPicker(togglePickerBtn.dataset.variant, togglePickerBtn.dataset.version);
      return;
    }

    const rescanBtn = e.target.closest('.btn-rescan-edit-local');
    if (rescanBtn) {
      loadEditVariantLocalBuilds(rescanBtn.dataset.variant, rescanBtn.dataset.version);
      return;
    }

    const openDirsBtn = e.target.closest('.btn-open-edit-search-dirs');
    if (openDirsBtn) {
      openEditSearchDirsPanel();
      return;
    }

    const closePickerBtn = e.target.closest('.btn-close-edit-local-picker');
    if (closePickerBtn) {
      closeEditVariantLocalPicker(closePickerBtn.dataset.variant);
      return;
    }

    const linkLocalBtn = e.target.closest('.btn-link-local-build');
    if (linkLocalBtn) {
      linkLocalBuildToReleaseVariant(linkLocalBtn.dataset.version, linkLocalBtn.dataset.variant);
      return;
    }

    const unlinkBtn = e.target.closest('.btn-unlink-variant');
    if (unlinkBtn) {
      unlinkReleaseVariant(unlinkBtn.dataset.version, unlinkBtn.dataset.variant);
    }
  });

  // Botones de recarga rápida de notas compañeras (*_cambios.txt y *_atp.txt)
  document.getElementById('btnCreateLoadCambiosTxt')?.addEventListener('click', () => {
    const ver = document.getElementById('relVersionName')?.value || '';
    loadCompanionNoteIntoField(ver, 'relChangelog', 'changelog', lastInspectedCreateData);
  });

  document.getElementById('btnCreateLoadAtpTxt')?.addEventListener('click', () => {
    const ver = document.getElementById('relVersionName')?.value || '';
    loadCompanionNoteIntoField(ver, 'relInternalNotes', 'internal_notes', lastInspectedCreateData);
  });

  document.getElementById('btnEditLoadCambiosTxt')?.addEventListener('click', () => {
    const ver = document.getElementById('editRelVersionName')?.value || '';
    loadCompanionNoteIntoField(ver, 'editRelChangelog', 'changelog');
  });

  document.getElementById('btnEditLoadAtpTxt')?.addEventListener('click', () => {
    const ver = document.getElementById('editRelVersionName')?.value || '';
    loadCompanionNoteIntoField(ver, 'editRelInternalNotes', 'internal_notes');
  });

  // Delegación para botón "Cambiar / Quitar APK" dentro de #activeCreateApkCard
  document.getElementById('activeCreateApkCard')?.addEventListener('click', (e) => {
    const clearBtn = e.target.closest('#btnClearSelectedCreateApk');
    if (clearBtn) {
      clearSelectedCreateApk();
    }
  });

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

  // Delegación segura para importar APKs locales sin interpolar barras Windows en onclick
  const buildsGridEl = document.getElementById('localBuildsGrid');
  buildsGridEl?.addEventListener('click', (e) => {
    const btn = e.target.closest('.btn-import-local-build');
    if (!btn) return;
    const idx = parseInt(btn.dataset.buildIndex || '-1', 10);
    const sourcePath = btn.dataset.sourcePath || availableLocalBuilds[idx]?.file_path;
    if (sourcePath) {
      importLocalApkDirectly(sourcePath, idx, btn);
    }
  });

  // Barra de filtros rápidos en #localBuildsToolbar
  document.getElementById('localBuildsAbiChips')?.addEventListener('click', (e) => {
    const chip = e.target.closest('.local-abi-chip');
    if (!chip) return;
    const abi = chip.dataset.abi || 'ALL';
    localBuildsFilterState.abi = abi;
    document.querySelectorAll('#localBuildsAbiChips .local-abi-chip').forEach((c) => {
      c.classList.toggle('active', c === chip);
    });
    fetchAndRenderLocalBuilds({ silentToast: true });
  });

  document.getElementById('inputLocalBuildsFilter')?.addEventListener('input', (e) => {
    localBuildsFilterState.query = e.target.value || '';
    clearTimeout(localBuildsFilterTimer);
    localBuildsFilterTimer = setTimeout(() => {
      fetchAndRenderLocalBuilds({ silentToast: true });
    }, 220);
  });

  document.getElementById('selectLocalBuildsLimit')?.addEventListener('change', (e) => {
    localBuildsFilterState.limit = parseInt(e.target.value || '6', 10) || 6;
    fetchAndRenderLocalBuilds({ silentToast: true });
  });

  // Mini-panel colapsable "Rutas de búsqueda"
  document.getElementById('btnToggleSearchDirsPanel')?.addEventListener('click', async () => {
    const panel = document.getElementById('createSearchDirsPanel');
    const toggleBtn = document.getElementById('btnToggleSearchDirsPanel');
    if (!panel) return;
    const willOpen = panel.style.display === 'none' || !panel.style.display;
    panel.style.display = willOpen ? 'flex' : 'none';
    toggleBtn?.classList.toggle('active', willOpen);
    if (willOpen) {
      await loadCreateSearchDirs();
    }
  });

  document.getElementById('btnBrowseApkSearchDir')?.addEventListener('click', browseAndFillNewSearchDir);
  document.getElementById('btnAddApkSearchDir')?.addEventListener('click', addCreateSearchDir);
  document.getElementById('btnResetApkSearchDirs')?.addEventListener('click', resetCreateSearchDirs);
  document.getElementById('inputNewApkSearchDir')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addCreateSearchDir();
    }
  });

  function bindSearchDirsListDelegation(listId, context) {
    const listEl = document.getElementById(listId);
    if (!listEl) return;
    listEl.addEventListener('change', async (e) => {
      const chk = e.target.closest('.chk-toggle-search-dir');
      if (!chk) return;
      const idx = parseInt(chk.dataset.dirIndex || '-1', 10);
      if (idx < 0 || idx >= createApkSearchDirs.length) return;
      const next = createApkSearchDirs.map((d, i) => (
        i === idx ? { ...d, enabled: chk.checked } : { ...d }
      ));
      await saveSearchDirsForContext(next, context);
    });

    listEl.addEventListener('click', async (e) => {
      const delBtn = e.target.closest('.btn-remove-search-dir');
      if (!delBtn) return;
      const idx = parseInt(delBtn.dataset.dirIndex || '-1', 10);
      if (idx < 0 || idx >= createApkSearchDirs.length) return;
      const target = createApkSearchDirs[idx];
      if (target?.is_default) return;
      const next = createApkSearchDirs.filter((_, i) => i !== idx);
      await saveSearchDirsForContext(next, context);
    });
  }

  bindSearchDirsListDelegation('createSearchDirsList', 'create');
  bindSearchDirsListDelegation('editSearchDirsList', 'edit');

  document.getElementById('btnCloseEditSearchDirsPanel')?.addEventListener('click', () => {
    const panel = document.getElementById('editSearchDirsPanel');
    if (panel) panel.style.display = 'none';
  });
  document.getElementById('btnEditBrowseApkSearchDir')?.addEventListener('click', () => browseAndFillSearchDirInput('edit'));
  document.getElementById('btnEditAddApkSearchDir')?.addEventListener('click', () => addSearchDirForContext('edit'));
  document.getElementById('btnEditResetApkSearchDirs')?.addEventListener('click', () => resetSearchDirsForContext('edit'));
  document.getElementById('inputEditNewApkSearchDir')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addSearchDirForContext('edit');
    }
  });

  // Controles Expandir/Contraer y contadores en vivo para los 4 textareas (Plan 22.5 Fase 3)
  document.querySelectorAll('.btn-toggle-textarea').forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset?.target || btn.getAttribute?.('data-target') || '';
      if (targetId) toggleExpandableTextarea(targetId);
    });
  });
  EXPANDABLE_TEXTAREA_IDS.forEach((textareaId) => {
    const ta = document.getElementById(textareaId);
    if (ta) {
      ta.addEventListener('input', () => updateTextareaMetaCounter(textareaId));
      updateTextareaMetaCounter(textareaId);
    }
  });

  // Autodetectar builds locales desde rutas configurables
  document.getElementById('btnDetectLocalBuild')?.addEventListener('click', async () => {
    await fetchAndRenderLocalBuilds({ silentToast: false });
  });
}

const EXPANDABLE_TEXTAREA_IDS = [
  'relChangelog',
  'relInternalNotes',
  'editRelChangelog',
  'editRelInternalNotes',
];

function computeTextareaStats(value) {
  const raw = String(value ?? '');
  if (raw.length === 0) return { lines: 0, chars: 0 };
  const lines = raw.replace(/\r\n/g, '\n').split('\n').length;
  return { lines, chars: raw.length };
}

function updateTextareaMetaCounter(textareaId) {
  const ta = document.getElementById(textareaId);
  const counter = document.getElementById(`${textareaId}Counter`);
  if (!counter) return;
  const stats = computeTextareaStats(ta ? ta.value : '');
  counter.textContent = `${stats.lines} lín. · ${stats.chars} car.`;
}

function setExpandableTextareaState(textareaId, expanded) {
  const ta = document.getElementById(textareaId);
  const btn = document.querySelector(`.btn-toggle-textarea[data-target="${textareaId}"]`);
  const isExpanded = Boolean(expanded);

  if (ta) {
    ta.classList.toggle('is-expanded', isExpanded);
    if (!isExpanded) {
      ta.style.height = '';
    }
  }
  if (btn) {
    btn.setAttribute('aria-expanded', isExpanded ? 'true' : 'false');
    btn.title = isExpanded
      ? 'Contraer área de texto'
      : 'Expandir área de texto';
    const labelEl = btn.querySelector('.btn-toggle-textarea-label');
    if (labelEl) {
      labelEl.textContent = isExpanded ? 'Contraer' : 'Expandir';
    }
    const svg = btn.querySelector('svg');
    if (svg) {
      svg.innerHTML = isExpanded
        ? '<polyline points="4 14 10 14 10 20"/><polyline points="20 10 14 10 14 4"/><line x1="14" y1="10" x2="21" y2="3"/><line x1="3" y1="21" x2="10" y2="14"/>'
        : '<polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/>';
    }
  }
  updateTextareaMetaCounter(textareaId);
}

function toggleExpandableTextarea(textareaId) {
  const ta = document.getElementById(textareaId);
  if (!ta) return false;
  const nextExpanded = !ta.classList.contains('is-expanded');
  setExpandableTextareaState(textareaId, nextExpanded);
  return nextExpanded;
}

function resetExpandableTextarea(textareaId, options = {}) {
  const ta = document.getElementById(textareaId);
  if (ta && options.clearValue === true) {
    ta.value = '';
  }
  setExpandableTextareaState(textareaId, false);
}

function resetAllModalExpandableTextareas(ids = EXPANDABLE_TEXTAREA_IDS, options = {}) {
  ids.forEach((id) => resetExpandableTextarea(id, options));
}

function normalizePathForCompare(rawPath) {
  return String(rawPath || '').trim().replace(/\\/g, '/').toLowerCase();
}

function resetDropZoneDefaultState() {
  const dropZone = document.getElementById('apkDropZone');
  const fileInput = document.getElementById('apkFileInput');
  const iconEl = document.getElementById('apkDropZoneIcon');
  const titleEl = document.getElementById('apkDropZoneTitle');
  const subEl = document.getElementById('apkDropZoneSubtitle');
  const progressContainer = document.getElementById('apkUploadProgress');
  const progressBar = document.getElementById('apkProgressBar');
  const progressText = document.getElementById('apkUploadStatusText');

  if (fileInput) fileInput.value = '';
  if (dropZone) {
    dropZone.classList.remove('dragover', 'has-manual-apk');
  }
  if (iconEl) {
    iconEl.innerHTML = '<svg width="38" height="38" style="width:38px; height:38px; color:var(--primary);" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>';
  }
  if (titleEl) {
    titleEl.textContent = 'Arrastra tu archivo .APK aquí o haz clic para seleccionarlo';
  }
  if (subEl) {
    subEl.textContent = 'Compatible con APK Universal (~110 MB) y APK Ligero ARM64 (~30 MB)';
  }
  if (progressContainer) progressContainer.style.display = 'none';
  if (progressBar) progressBar.style.width = '0%';
  if (progressText) progressText.textContent = 'Procesando archivo e inspeccionando metadatos...';
}

function setDropZoneManualLoadedState(fileName, sizeLabel) {
  const dropZone = document.getElementById('apkDropZone');
  const iconEl = document.getElementById('apkDropZoneIcon');
  const titleEl = document.getElementById('apkDropZoneTitle');
  const subEl = document.getElementById('apkDropZoneSubtitle');

  if (dropZone) {
    dropZone.classList.remove('dragover');
    dropZone.classList.add('has-manual-apk');
  }
  if (iconEl) {
    iconEl.innerHTML = '<svg width="38" height="38" style="width:38px; height:38px; color:#0ea5e9;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>';
  }
  if (titleEl) {
    titleEl.textContent = `Archivo manual listo: ${fileName || 'archivo.apk'}`;
  }
  if (subEl) {
    const cleanSize = sizeLabel && sizeLabel !== '-' ? `${sizeLabel} · ` : '';
    subEl.textContent = `${cleanSize}Verificado e inspeccionado — Haz clic o arrastra otro .APK para reemplazarlo`;
  }
}

/**
 * Renderiza la tarjeta unívoca de APK Activo Listo para Publicar (#activeCreateApkCard)
 */
function renderActiveCreateApkCard(data, sourceKind = 'manual', sourceMeta = {}) {
  const card = document.getElementById('activeCreateApkCard');
  if (!card || !data) return;

  activeCreateApkSource = sourceKind === 'autodetect' ? 'autodetect' : 'manual';
  const isManual = activeCreateApkSource === 'manual';

  const originBadge = isManual
    ? '<span class="badge badge-source-manual"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg> Subido manualmente desde PC</span>'
    : `<span class="badge badge-source-autodetect"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/><polyline points="9 13 11 15 15 11"/></svg> Seleccionado desde Autodetección</span>`;

  const variant = (data.abi_variant || 'UNIVERSAL').toUpperCase();
  const variantBadge = variant === 'ARM64'
    ? '<span class="badge badge-arm64">ARM64 LIGERO</span>'
    : '<span class="badge badge-universal">UNIVERSAL</span>';
  const sigBadge = renderSignatureStatusBadge(
    data.signature_status,
    data.signature_verified,
    'Oficial RSA-4096'
  );
  const sizeFormatted = formatApkSizeMb(data.size_mb);
  const sha = data.sha256 ? String(data.sha256) : '';
  const shortSha = sha ? `${sha.substring(0, 14)}...` : '-';
  const sourceDetail = sourceMeta.sourceLabel
    ? ` · Origen: ${escapeHtml(sourceMeta.sourceLabel)}`
    : '';

  card.className = `active-apk-card ${isManual ? 'source-manual' : 'source-autodetect'} visible`;
  card.style.display = 'flex';
  card.innerHTML = `
    <div class="active-apk-card-top">
      <div class="active-apk-card-badges">
        ${originBadge}
        ${variantBadge}
        ${sigBadge}
      </div>
      <button type="button" class="btn btn-outline btn-xs" id="btnClearSelectedCreateApk" title="Quitar APK seleccionado sin cerrar el modal">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        Cambiar / Quitar APK
      </button>
    </div>
    <div class="active-apk-card-details">
      <div>
        <strong style="color:var(--text-primary);">${escapeHtml(data.file_name || 'app-release.apk')}</strong>
        <span> · v${escapeHtml(data.version_name || '-')} (Build ${escapeHtml(String(data.version_code || '-'))})${sourceDetail}</span>
      </div>
      <div style="display:flex; align-items:center; gap:0.5rem; flex-wrap:wrap;">
        <span><strong>${escapeHtml(sizeFormatted)}</strong></span>
        <span>·</span>
        <code style="font-family:var(--font-mono); font-size:0.74rem;" title="${escapeHtml(sha)}">SHA-256: ${escapeHtml(shortSha)}</code>
      </div>
    </div>
  `;
}

/**
 * Limpia únicamente el APK activo seleccionado sin cerrar #modalCreateRelease ni borrar notas escritas
 */
function clearSelectedCreateApk() {
  lastInspectedCreateData = null;
  activeCreateApkSource = null;
  selectedLocalBuildPath = null;
  selectedLocalBuildIndex = -1;
  pendingManualFileMeta = null;

  resetDropZoneDefaultState();

  const card = document.getElementById('activeCreateApkCard');
  if (card) {
    card.style.display = 'none';
    card.className = 'active-apk-card';
    card.innerHTML = '';
  }

  const banner = document.getElementById('apkSignatureBanner');
  if (banner) {
    banner.style.display = 'none';
    banner.className = 'apk-signature-banner';
    banner.innerHTML = '';
  }

  const clearIds = [
    'relUploadedPath',
    'relSignatureVerified',
    'relSignatureStatus',
    'relSignerSha256',
    'relSignerDn',
    'relSizeMb',
    'relSha256',
  ];
  clearIds.forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });

  const abiInput = document.getElementById('relAbiVariant');
  if (abiInput) abiInput.value = 'UNIVERSAL';
  const badge = document.getElementById('badgeRelVariantDisplay');
  if (badge) {
    badge.className = 'badge badge-universal';
    badge.textContent = 'UNIVERSAL';
  }

  syncLocalBuildsSelectionUi(null);
}

/**
 * Restablece de forma 100% determinista el estado visual, DOM y variables de #modalCreateRelease
 */
function resetCreateReleaseModalState() {
  lastInspectedCreateData = null;
  availableLocalBuilds = [];
  activeCreateApkSource = null;
  selectedLocalBuildPath = null;
  selectedLocalBuildIndex = -1;
  pendingManualFileMeta = null;
  localBuildsFilterState = { abi: 'ALL', query: '', limit: 6 };
  clearTimeout(localBuildsFilterTimer);

  resetDropZoneDefaultState();

  const activeCard = document.getElementById('activeCreateApkCard');
  if (activeCard) {
    activeCard.style.display = 'none';
    activeCard.className = 'active-apk-card';
    activeCard.innerHTML = '';
  }

  const banner = document.getElementById('apkSignatureBanner');
  if (banner) {
    banner.style.display = 'none';
    banner.className = 'apk-signature-banner';
    banner.innerHTML = '';
  }

  const grid = document.getElementById('localBuildsGrid');
  if (grid) {
    grid.style.display = 'none';
    grid.innerHTML = '';
  }

  const toolbar = document.getElementById('localBuildsToolbar');
  if (toolbar) toolbar.style.display = 'none';
  document.querySelectorAll('#localBuildsAbiChips .local-abi-chip').forEach((chip) => {
    chip.classList.toggle('active', chip.dataset.abi === 'ALL');
  });
  const filterInp = document.getElementById('inputLocalBuildsFilter');
  if (filterInp) filterInp.value = '';
  const limitSel = document.getElementById('selectLocalBuildsLimit');
  if (limitSel) limitSel.value = '6';

  const searchDirsPanel = document.getElementById('createSearchDirsPanel');
  if (searchDirsPanel) searchDirsPanel.style.display = 'none';
  document.getElementById('btnToggleSearchDirsPanel')?.classList.remove('active');
  const newDirInp = document.getElementById('inputNewApkSearchDir');
  if (newDirInp) newDirInp.value = '';

  const statusEl = document.getElementById('detectApkStatus');
  if (statusEl) {
    statusEl.textContent = 'Escanea tus rutas configuradas (Biblioteca Oficial, compilaciones locales o carpetas personalizadas) con fecha, SHA-256 y firma real.';
  }

  const form = document.getElementById('formCreateRelease');
  form?.reset();

  const defaults = {
    relUploadedPath: '',
    relAbiVariant: 'UNIVERSAL',
    relSignatureVerified: '',
    relSignatureStatus: '',
    relSignerSha256: '',
    relSignerDn: '',
    relVersionName: '',
    relVersionCode: '',
    relMinRequiredVersion: '9.0.0',
    relDbSchema: '36',
    relType: 'FEATURE_RELEASE',
    relSizeMb: '',
    relSha256: '',
    relDownloadUrl: '',
    relChangelog: '',
    relInternalNotes: '',
  };
  Object.entries(defaults).forEach(([id, val]) => {
    const el = document.getElementById(id);
    if (el) el.value = val;
  });

  if (typeof resetExpandableTextarea === 'function') {
    resetExpandableTextarea('relChangelog');
    resetExpandableTextarea('relInternalNotes');
  }

  const badge = document.getElementById('badgeRelVariantDisplay');
  if (badge) {
    badge.className = 'badge badge-universal';
    badge.textContent = 'UNIVERSAL';
  }
  updateReleaseTypeInfo('relType', 'relTypeInfoText');
}

function syncLocalBuildsSelectionUi(selectedPath) {
  const gridEl = document.getElementById('localBuildsGrid');
  if (!gridEl) return;
  const targetNorm = normalizePathForCompare(selectedPath);
  const hasSelection = Boolean(targetNorm);

  gridEl.querySelectorAll('.local-build-card').forEach((card) => {
    const cardPathNorm = normalizePathForCompare(card.dataset.sourcePath);
    const isMatch = hasSelection && cardPathNorm && cardPathNorm === targetNorm;
    const pillEl = card.querySelector('.local-build-selected-pill');
    const btn = card.querySelector('.btn-import-local-build');

    card.classList.toggle('is-selected', isMatch);
    card.classList.toggle('is-dimmed', hasSelection && !isMatch);
    if (pillEl) pillEl.style.display = isMatch ? 'inline-flex' : 'none';

    if (btn) {
      btn.disabled = false;
      btn.classList.remove('is-loading');
      if (isMatch) {
        btn.className = 'btn btn-sm btn-import-local-build btn-selected-apk';
        btn.innerHTML = `
          <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
          Seleccionado (Activo)
        `;
      } else {
        btn.className = 'btn btn-outline btn-sm btn-import-local-build';
        btn.innerHTML = `
          <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          Seleccionar e Importar
        `;
      }
    }
  });
}

function renderLocalBuildsGrid(builds) {
  const gridEl = document.getElementById('localBuildsGrid');
  if (!gridEl) return;
  gridEl.style.display = 'grid';
  gridEl.innerHTML = '';

  builds.forEach((b, idx) => {
    const card = document.createElement('div');
    card.className = 'local-build-card';
    card.dataset.sourcePath = b.file_path || '';

    const srcLower = (b.source_label || '').toLowerCase();
    const originBadge = srcLower.includes('biblioteca')
      ? '<span class="badge badge-origin-lib">Biblioteca Oficial</span>'
      : (srcLower.includes('compilación') || srcLower.includes('build')
          ? '<span class="badge badge-origin-local">Build Local</span>'
          : `<span class="badge badge-origin-local">${escapeHtml(b.source_label || 'Carpeta Local')}</span>`);

    const variantBadge = b.abi_variant === 'ARM64'
      ? '<span class="badge badge-arm64">ARM64 Ligero</span>'
      : '<span class="badge badge-universal">Universal</span>';

    const sigBadge = renderSignatureStatusBadge(b.signature_status, b.signature_verified, 'Oficial RSA-4096');
    const modDate = b.modified_at ? b.modified_at.substring(0, 16).replace('T', ' ') : '-';
    const shortSha = b.sha256 ? `${b.sha256.substring(0, 10)}...` : '-';
    const sizeFormatted = formatApkSizeMb(b.size_mb);
    const dupPaths = Array.isArray(b.duplicate_paths) ? b.duplicate_paths : [];
    const dupHtml = dupPaths.length > 0
      ? `<div class="local-build-dup" title="${escapeHtml(dupPaths.join('\n'))}">Deduplicado por SHA-256 (${dupPaths.length} copia idéntica omitida)</div>`
      : '';

    card.innerHTML = `
      <div class="local-build-header">
        <div style="display:flex; align-items:center; gap:0.35rem; flex-wrap:wrap;">
          <strong style="color:var(--text-primary); font-size:0.85rem;">v${escapeHtml(b.version_name || '')} (Build ${b.version_code || '-'})</strong>
          <span class="local-build-selected-pill" style="display:none;"><svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> Seleccionado</span>
        </div>
        <div style="display:flex; gap:0.25rem; flex-wrap:wrap; justify-content:flex-end;">
          ${originBadge}
          ${variantBadge}
          ${sigBadge}
        </div>
      </div>
      <div class="local-build-path" title="${escapeHtml(b.file_path || '')}">${escapeHtml(b.file_path || b.file_name)}</div>
      <div class="local-build-meta">
        <span>${escapeHtml(sizeFormatted)}</span>
        <span>•</span>
        <span>${escapeHtml(modDate)}</span>
        <span>•</span>
        <code style="font-size:0.7rem;">${escapeHtml(shortSha)}</code>
      </div>
      ${dupHtml}
    `;

    const importBtn = document.createElement('button');
    importBtn.type = 'button';
    importBtn.className = 'btn btn-outline btn-sm btn-import-local-build';
    importBtn.style.marginTop = '0.4rem';
    importBtn.style.width = '100%';
    importBtn.dataset.sourcePath = b.file_path || '';
    importBtn.dataset.buildIndex = String(idx);
    importBtn.innerHTML = `
      <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
      Seleccionar e Importar
    `;
    card.appendChild(importBtn);
    gridEl.appendChild(card);
  });

  syncLocalBuildsSelectionUi(
    activeCreateApkSource === 'autodetect' ? selectedLocalBuildPath : null
  );
}

async function fetchAndRenderLocalBuilds(options = {}) {
  const silentToast = options.silentToast === true;
  const statusEl = document.getElementById('detectApkStatus');
  const gridEl = document.getElementById('localBuildsGrid');
  const toolbarEl = document.getElementById('localBuildsToolbar');

  if (statusEl) statusEl.textContent = 'Escaneando rutas configuradas (Biblioteca Oficial, compilaciones y carpetas activas)...';

  try {
    const params = new URLSearchParams({
      limit: String(localBuildsFilterState.limit || 6),
      abi: localBuildsFilterState.abi || 'ALL',
      q: localBuildsFilterState.query || '',
    });
    const res = await fetch(`/api/releases/detect-local-build?${params.toString()}`);
    if (!res.ok) throw new Error('Error al autodetectar build');
    const data = await res.json();

    if (Array.isArray(data.per_dir_stats)) {
      createApkSearchDirs = data.per_dir_stats;
      const panel = document.getElementById('createSearchDirsPanel');
      if (panel && panel.style.display !== 'none') {
        renderCreateSearchDirsList(createApkSearchDirs);
      }
    }

    if (toolbarEl) toolbarEl.style.display = 'flex';

    if (data.apk_found && Array.isArray(data.available_builds) && data.available_builds.length > 0) {
      availableLocalBuilds = data.available_builds;
      const totalUnique = data.total_unique_found ?? data.available_builds.length;
      const totalAll = data.total_all_unique ?? totalUnique;
      if (statusEl) {
        statusEl.textContent = `Mostrando ${data.available_builds.length} de ${totalUnique} APK(s) únicos (${totalAll} totales en rutas activas). Selecciona uno para importar:`;
      }
      renderLocalBuildsGrid(data.available_builds);
    } else {
      availableLocalBuilds = [];
      const hasFilters = (localBuildsFilterState.abi && localBuildsFilterState.abi !== 'ALL') ||
        Boolean((localBuildsFilterState.query || '').trim());
      if (statusEl) {
        statusEl.textContent = hasFilters
          ? 'Ningún APK coincide con el filtro actual. Prueba cambiar a "Todos" o limpiar la búsqueda.'
          : 'No se encontraron archivos APK en las rutas de búsqueda configuradas.';
      }
      if (gridEl) {
        gridEl.style.display = 'none';
        gridEl.innerHTML = '';
      }
      if (!silentToast) {
        showToast('No se encontraron compilaciones APK con los criterios actuales.', 'info');
      }
    }
  } catch (e) {
    if (statusEl) statusEl.textContent = 'Error: ' + e.message;
    if (!silentToast) showToast('Error: ' + e.message, 'error');
  }
}

function getSearchDirsPanelConfig(context = 'create') {
  if (context === 'edit') {
    return {
      context: 'edit',
      listId: 'editSearchDirsList',
      inputId: 'inputEditNewApkSearchDir',
      browseBtnId: 'btnEditBrowseApkSearchDir',
      panelId: 'editSearchDirsPanel',
    };
  }
  return {
    context: 'create',
    listId: 'createSearchDirsList',
    inputId: 'inputNewApkSearchDir',
    browseBtnId: 'btnBrowseApkSearchDir',
    panelId: 'createSearchDirsPanel',
  };
}

function renderSearchDirsListInto(listId, dirs) {
  const listEl = document.getElementById(listId);
  if (!listEl) return;
  listEl.innerHTML = '';

  if (!Array.isArray(dirs) || dirs.length === 0) {
    listEl.innerHTML = '<div style="font-size:0.76rem; color:var(--text-muted);">No hay rutas configuradas.</div>';
    return;
  }

  dirs.forEach((d, idx) => {
    const item = document.createElement('div');
    item.className = `search-dir-item${d.enabled === false ? ' disabled' : ''}`;
    const existsBadge = d.exists
      ? '<span class="badge badge-dir-exists">Existe en disco</span>'
      : '<span class="badge badge-dir-missing">No encontrada</span>';
    const countLabel = `${d.apk_count ?? 0} APK(s)`;
    const removeBtnHtml = d.is_default
      ? ''
      : `<button type="button" class="btn btn-outline btn-xs btn-remove-search-dir" data-dir-index="${idx}" title="Eliminar ruta personalizada" style="color:var(--danger); border-color:var(--danger);">
          <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
        </button>`;

    item.innerHTML = `
      <label class="search-dir-info" style="cursor:pointer;">
        <input type="checkbox" class="chk-toggle-search-dir" data-dir-index="${idx}" ${d.enabled !== false ? 'checked' : ''} style="margin-top:3px;">
        <div>
          <div style="font-size:0.78rem; font-weight:600; color:var(--text-primary);">${escapeHtml(d.label || 'Carpeta')}</div>
          <div class="search-dir-path">${escapeHtml(d.path || '')}</div>
        </div>
      </label>
      <div class="search-dir-actions">
        ${existsBadge}
        <span class="release-adoption-pill">${escapeHtml(countLabel)}</span>
        ${removeBtnHtml}
      </div>
    `;
    listEl.appendChild(item);
  });
}

function renderAllSearchDirsLists(dirs) {
  renderSearchDirsListInto('createSearchDirsList', dirs);
  renderSearchDirsListInto('editSearchDirsList', dirs);
}

function renderCreateSearchDirsList(dirs) {
  renderSearchDirsListInto('createSearchDirsList', dirs);
}

function renderEditSearchDirsList(dirs) {
  renderSearchDirsListInto('editSearchDirsList', dirs);
}

async function rescanOpenSearchDirsPickers(context = 'create') {
  if (context === 'create' || document.getElementById('modalCreateRelease')?.classList.contains('open')) {
    await fetchAndRenderLocalBuilds({ silentToast: true });
  }
  const editModalOpen = document.getElementById('modalEditRelease')?.classList.contains('open');
  if (context === 'edit' || editModalOpen) {
    const editVer = document.getElementById('editRelVersionName')?.value || '';
    for (const vk of ['universal', 'arm64']) {
      const picker = document.getElementById(`editVariantLocalPicker_${vk}`);
      if (picker && picker.style.display !== 'none' && typeof loadEditVariantLocalBuilds === 'function') {
        await loadEditVariantLocalBuilds(vk, editVer);
      }
    }
  }
}

async function loadSearchDirsForContext(context = 'create') {
  try {
    const res = await fetch('/api/releases/search-dirs');
    if (!res.ok) throw new Error('No se pudieron cargar las rutas de búsqueda');
    const data = await res.json();
    createApkSearchDirs = Array.isArray(data.search_dirs) ? data.search_dirs : [];
    renderAllSearchDirsLists(createApkSearchDirs);
  } catch (e) {
    showToast('Error cargando rutas: ' + e.message, 'error');
  }
}

async function loadCreateSearchDirs() {
  return loadSearchDirsForContext('create');
}

async function saveSearchDirsForContext(nextDirs, context = 'create') {
  try {
    const payloadDirs = nextDirs.map((d) => ({
      path: d.path,
      label: d.label,
      enabled: d.enabled !== false,
      is_default: d.is_default === true,
      kind: d.kind || 'custom',
    }));
    const res = await fetch('/api/releases/search-dirs', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ search_dirs: payloadDirs }),
    });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      throw new Error(data.error || 'No se pudieron guardar las rutas');
    }
    createApkSearchDirs = Array.isArray(data.search_dirs) ? data.search_dirs : [];
    editModalLocalBuildsCache = [];
    if (typeof editModalLocalBuildsByVariant !== 'undefined') {
      editModalLocalBuildsByVariant.universal = [];
      editModalLocalBuildsByVariant.arm64 = [];
    }
    renderAllSearchDirsLists(createApkSearchDirs);
    showToast('Rutas de búsqueda actualizadas. Re-escaneando APKs...', 'success');
    await rescanOpenSearchDirsPickers(context);
  } catch (e) {
    showToast(e.message, 'error');
    await loadSearchDirsForContext(context);
  }
}

async function saveCreateSearchDirs(nextDirs) {
  return saveSearchDirsForContext(nextDirs, 'create');
}

async function browseAndFillSearchDirInput(context = 'create') {
  const cfg = getSearchDirsPanelConfig(context);
  const inputEl = document.getElementById(cfg.inputId);
  const btn = document.getElementById(cfg.browseBtnId);
  if (btn) btn.disabled = true;
  try {
    const res = await fetch('/api/releases/browse-search-dir', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ initial_path: inputEl?.value?.trim() || '' }),
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || 'Carpeta rechazada o error al examinar');
    }
    if (data.supported === false) {
      showToast(data.error || 'Selector nativo no disponible en este sistema; escribe la ruta manualmente.', 'info');
      inputEl?.focus();
      return;
    }
    if (data.cancelled) {
      showToast('Selección de carpeta cancelada.', 'info');
      return;
    }
    if (data.path && inputEl) {
      inputEl.value = data.path;
      inputEl.focus();
      showToast('Carpeta seleccionada. Pulsa "Agregar ruta" para guardarla.', 'success');
    }
  } catch (e) {
    showToast('Error al examinar carpeta: ' + e.message, 'error');
  } finally {
    if (btn) btn.disabled = false;
  }
}

async function browseAndFillNewSearchDir() {
  return browseAndFillSearchDirInput('create');
}

async function addSearchDirForContext(context = 'create') {
  const cfg = getSearchDirsPanelConfig(context);
  const inputEl = document.getElementById(cfg.inputId);
  const rawPath = inputEl?.value?.trim() || '';
  if (!rawPath) {
    showToast('Ingresa o examina una ruta de carpeta válida.', 'warning');
    inputEl?.focus();
    return;
  }
  if (createApkSearchDirs.length === 0) {
    await loadSearchDirsForContext(context);
  }
  const norm = normalizePathForCompare(rawPath);
  if (createApkSearchDirs.some((d) => normalizePathForCompare(d.path) === norm || normalizePathForCompare(d.canonical_path) === norm)) {
    showToast('Esa ruta ya está registrada en la lista.', 'info');
    return;
  }
  const segs = rawPath.replace(/\\/g, '/').split('/').filter(Boolean);
  const folderName = segs.length > 0 ? segs[segs.length - 1] : 'Carpeta Personalizada';
  const next = [
    ...createApkSearchDirs,
    {
      path: rawPath,
      label: `Carpeta: ${folderName}`,
      enabled: true,
      is_default: false,
      kind: 'custom',
    },
  ];
  await saveSearchDirsForContext(next, context);
  if (inputEl) inputEl.value = '';
}

async function addCreateSearchDir() {
  return addSearchDirForContext('create');
}

async function resetSearchDirsForContext(context = 'create') {
  try {
    const res = await fetch('/api/releases/search-dirs/reset', { method: 'POST' });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      throw new Error(data.error || 'No se pudieron restablecer las rutas');
    }
    createApkSearchDirs = Array.isArray(data.search_dirs) ? data.search_dirs : [];
    editModalLocalBuildsCache = [];
    if (typeof editModalLocalBuildsByVariant !== 'undefined') {
      editModalLocalBuildsByVariant.universal = [];
      editModalLocalBuildsByVariant.arm64 = [];
    }
    renderAllSearchDirsLists(createApkSearchDirs);
    showToast('Rutas de búsqueda restablecidas a los valores por defecto.', 'success');
    await rescanOpenSearchDirsPickers(context);
  } catch (e) {
    showToast('Error al restablecer rutas: ' + e.message, 'error');
  }
}

async function resetCreateSearchDirs() {
  return resetSearchDirsForContext('create');
}

/**
 * Importa atómicamente un build local en disco sin subirlo por la red
 */
async function importLocalApkDirectly(sourcePath, buildIndex = -1, triggerBtn = null) {
  const gridEl = document.getElementById('localBuildsGrid');
  const btn = triggerBtn || (gridEl && Array.from(gridEl.querySelectorAll('.btn-import-local-build')).find(
    (el) => normalizePathForCompare(el.dataset.sourcePath) === normalizePathForCompare(sourcePath)
  ));

  if (btn) {
    btn.disabled = true;
    btn.classList.add('is-loading');
    btn.innerHTML = `
      <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
      Importando e inspeccionando...
    `;
  }

  try {
    const res = await fetch('/api/releases/import-local-apk', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ source_path: sourcePath })
    });
    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || 'Error al importar APK local');
    }
    const data = await res.json();

    // Limpiar estado manual del dropzone para garantizar origen único
    resetDropZoneDefaultState();
    pendingManualFileMeta = null;
    selectedLocalBuildPath = sourcePath;
    selectedLocalBuildIndex = buildIndex;

    const matchedBuild = availableLocalBuilds[buildIndex] || availableLocalBuilds.find(
      (b) => normalizePathForCompare(b.file_path) === normalizePathForCompare(sourcePath)
    );
    populateCreateReleaseFormFromInspection(data, 'autodetect', {
      sourceLabel: matchedBuild?.source_label || '',
    });
    syncLocalBuildsSelectionUi(sourcePath);

    showToast(`APK importado exitosamente: ${data.file_name} (${formatApkSizeMb(data.size_mb)}).`, 'success');
  } catch (e) {
    syncLocalBuildsSelectionUi(activeCreateApkSource === 'autodetect' ? selectedLocalBuildPath : null);
    showToast('Error: ' + e.message, 'error');
  }
}

/**
 * Rellena el formulario de nuevo release a partir de la inspección real
 */
function populateCreateReleaseFormFromInspection(data, sourceKind = 'manual', sourceMeta = {}) {
  lastInspectedCreateData = data;
  document.getElementById('relUploadedPath').value = data.imported_path || data.file_path || '';
  document.getElementById('relVersionName').value = data.version_name || '';
  document.getElementById('relVersionCode').value = data.version_code || 82;
  document.getElementById('relDbSchema').value = data.db_schema_version || 36;
  document.getElementById('relMinRequiredVersion').value = data.min_required_version || '9.0.0';
  const normalizedSize = formatApkSizeMb(data.size_mb);
  document.getElementById('relSizeMb').value = normalizedSize === '-' ? '' : normalizedSize;
  document.getElementById('relSha256').value = data.sha256 || '';

  const relTypeSel = document.getElementById('relType');
  if (relTypeSel) {
    const suggestedType = (data.suggested_release_type === 'HOTFIX' || data.suggested_release_type === 'FEATURE_RELEASE')
      ? data.suggested_release_type
      : inferReleaseTypeFromSemVer(data.version_name);
    relTypeSel.value = suggestedType;
    updateReleaseTypeInfo('relType', 'relTypeInfoText');
  }

  const variant = data.abi_variant || 'UNIVERSAL';
  document.getElementById('relAbiVariant').value = variant;
  const variantBadge = document.getElementById('badgeRelVariantDisplay');
  if (variantBadge) {
    variantBadge.className = variant === 'ARM64' ? 'badge badge-arm64' : 'badge badge-universal';
    variantBadge.textContent = variant === 'ARM64' ? 'ARM64 LIGERO' : 'UNIVERSAL';
  }

  // Sugerencia de changelog comercial (*_cambios.txt) sin mezclar notas de ingeniería
  const changelogInput = document.getElementById('relChangelog');
  if (changelogInput && !changelogInput.value.trim() && data.suggested_changelog) {
    changelogInput.value = data.suggested_changelog;
  }

  // Pre-relleno automático de notas internas técnicas (*_atp.txt) cuando esté vacío
  const internalNotesInput = document.getElementById('relInternalNotes');
  if (internalNotesInput && !internalNotesInput.value.trim() && data.suggested_internal_notes) {
    internalNotesInput.value = data.suggested_internal_notes;
  }

  if (typeof updateTextareaMetaCounter === 'function') {
    updateTextareaMetaCounter('relChangelog');
    updateTextareaMetaCounter('relInternalNotes');
  }

  // Tarjeta unívoca de APK Activo + Escudo Anti-debug.apk
  renderActiveCreateApkCard(data, sourceKind, sourceMeta);
  renderSignatureShieldBanner(data);
}

/**
 * Renderiza el banner del escudo anti-debug con 3 estados honestos
 */
function renderSignatureShieldBanner(data) {
  const banner = document.getElementById('apkSignatureBanner');
  if (!banner) return;

  const status = data.signature_status || 'UNVERIFIED';
  document.getElementById('relSignatureVerified').value =
    data.signature_verified === true ? 'true' : (data.signature_verified === false ? 'false' : '');
  document.getElementById('relSignatureStatus').value = status;
  document.getElementById('relSignerSha256').value = data.signer_sha256 || '';
  document.getElementById('relSignerDn').value = data.signer_dn || '';

  banner.style.display = 'block';

  const isUnofficial = status === 'UNOFFICIAL_SIGNATURE' || (data.signature_verified === false && status !== 'UNVERIFIED');

  if (status === 'OFFICIAL_RELEASE' || data.signature_verified === true) {
    const shortSignerSha = data.signer_sha256 ? `${String(data.signer_sha256).substring(0, 16)}...` : '';
    const dnPart = data.signer_dn ? `Titular: <code>${escapeHtml(data.signer_dn)}</code>` : 'Titular: Julio Angello Vasquez Navarro';
    const shaPart = shortSignerSha ? ` · Huella: <code>${escapeHtml(shortSignerSha)}</code>` : '';
    banner.className = 'apk-signature-banner sig-official';
    banner.innerHTML = `
      <div style="display:flex; align-items:center; gap:0.5rem; font-weight:700;">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
        Firma Comercial Oficial Verificada (RSA-4096)
      </div>
      <div style="font-size:0.75rem; opacity:0.92;">
        ${dnPart}${shaPart}. El certificado criptográfico coincide con la clave maestra comercial.
      </div>
    `;
  } else if (isUnofficial) {
    banner.className = 'apk-signature-banner sig-unofficial';
    banner.innerHTML = `
      <div style="display:flex; align-items:center; gap:0.5rem; font-weight:700;">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        ¡ATENCIÓN! Este APK no cuenta con la firma comercial oficial (posible debug.apk)
      </div>
      <div style="font-size:0.76rem;">
        ${data.signer_dn ? `Firmado por: <code>${escapeHtml(data.signer_dn)}</code>. ` : ''}
        ${data.signature_detail ? `${escapeHtml(data.signature_detail)} ` : ''}
        No distribuyas este binario a clientes comerciales de producción.
      </div>
      <label style="display:flex; align-items:center; gap:0.5rem; margin-top:0.4rem; cursor:pointer; font-weight:600; font-size:0.78rem;">
        <input type="checkbox" id="chkAcknowledgeUnofficialApk">
        <span>Comprendo los riesgos y autorizo publicar este APK no oficial</span>
      </label>
    `;
  } else {
    banner.className = 'apk-signature-banner sig-unverified';
    banner.innerHTML = `
      <div style="display:flex; align-items:center; gap:0.5rem; font-weight:600;">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        Firma no verificable en este entorno
      </div>
      <div style="font-size:0.75rem; opacity:0.88;">
        ${escapeHtml(data.signature_detail || 'apksigner no disponible o sin huella legible en el entorno actual. Los metadatos SemVer, tamaño y SHA-256 fueron extraídos en Dart puro.')}
      </div>
    `;
  }
}

/**
 * Carga directa de archivo APK desde el navegador con análisis forense
 */
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
    if (progressText) progressText.textContent = `${data.file_name} verificado e inspeccionado (${formatApkSizeMb(data.size_mb)}).`;

    selectedLocalBuildPath = null;
    selectedLocalBuildIndex = -1;
    pendingManualFileMeta = {
      fileName: data.file_name || file.name,
      sizeMb: formatApkSizeMb(data.size_mb),
    };
    setDropZoneManualLoadedState(
      pendingManualFileMeta.fileName,
      pendingManualFileMeta.sizeMb
    );
    syncLocalBuildsSelectionUi(null);
    populateCreateReleaseFormFromInspection(data, 'manual');

    showToast(`APK ${data.file_name} subido y analizado con éxito.`, 'success');
  } catch (e) {
    if (progressBar) progressBar.style.width = '0%';
    if (progressText) progressText.textContent = 'Error al subir APK.';
    showToast('Error al subir APK: ' + e.message, 'error');
  }
}

// =================== 5. INSPECTOR FORENSE DUAL (ML9 / MLS1 — PLAN 22 FASE 4) ===================
const INSPECTOR_HISTORY_STORAGE_KEY = 'ml_inspector_session_history_v1';
const MAX_INSPECTOR_SESSION_HISTORY = 10;
let inspectorSessionHistory = [];
let currentInspectorAuditSnapshot = null;

function reconcileInspectorNonceStatus(tNonceRaw, matchedClient) {
  const tNonce = Number(tNonceRaw ?? 0);
  const cNonce = Number(matchedClient?.next_nonce ?? 1);
  const hasSyncedNonce = Boolean(
    matchedClient &&
    matchedClient.ultimo_nonce !== null &&
    matchedClient.ultimo_nonce !== undefined
  );
  const syncedNonce = hasSyncedNonce ? Number(matchedClient.ultimo_nonce) : null;

  if (syncedNonce !== null && !Number.isNaN(syncedNonce) && tNonce <= syncedNonce) {
    return {
      state: 'REDEEMED_SYNCED',
      badgeClass: 'badge badge-green',
      label: `Canjeado en celular (Verificado por .mlsync #${syncedNonce})`,
    };
  }
  if (tNonce === cNonce - 1) {
    return {
      state: 'EMITTED_PENDING',
      badgeClass: 'badge badge-blue',
      label: 'Emitido — Pendiente de canje en celular (Sin .mlsync reciente)',
    };
  }
  if (tNonce >= cNonce) {
    return {
      state: 'FUTURE_READY',
      badgeClass: 'badge badge-yellow',
      label: 'Nonce futuro listo para canje',
    };
  }
  return {
    state: 'HISTORICAL_SUPERSEDED',
    badgeClass: 'badge badge-purple',
    label: 'Superado / Histórico',
  };
}

function loadInspectorSessionHistory() {
  try {
    const raw = typeof sessionStorage !== 'undefined'
      ? sessionStorage.getItem(INSPECTOR_HISTORY_STORAGE_KEY)
      : null;
    if (raw) {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        inspectorSessionHistory = parsed.slice(0, MAX_INSPECTOR_SESSION_HISTORY);
      }
    }
  } catch (_) {
    // fallback in-memory si sessionStorage no está disponible
  }
  return inspectorSessionHistory;
}

function saveInspectorSessionHistory() {
  try {
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.setItem(
        INSPECTOR_HISTORY_STORAGE_KEY,
        JSON.stringify(inspectorSessionHistory.slice(0, MAX_INSPECTOR_SESSION_HISTORY))
      );
    }
  } catch (_) {
    // ignore storage errors
  }
}

function recordInspectorSessionEntry(entry) {
  if (!entry || !entry.rawInput) return;
  loadInspectorSessionHistory();
  const filtered = inspectorSessionHistory.filter(item => item.rawInput !== entry.rawInput);
  filtered.unshift({
    kind: entry.kind || 'ML9',
    summaryLabel: entry.summaryLabel || '-',
    hardwareId: entry.hardwareId || '-',
    statusText: entry.statusText || '-',
    statusTone: entry.statusTone || 'badge-mono',
    timestampIso: entry.timestampIso || new Date().toISOString(),
    timestampLima: formatLimaDateTime(entry.timestampIso || Date.now()),
    rawInput: entry.rawInput,
  });
  inspectorSessionHistory = filtered.slice(0, MAX_INSPECTOR_SESSION_HISTORY);
  saveInspectorSessionHistory();
  renderInspectorSessionHistory();
}

function clearInspectorSessionHistory() {
  inspectorSessionHistory = [];
  saveInspectorSessionHistory();
  renderInspectorSessionHistory();
  showToast('Historial de auditorías de sesión limpiado.', 'info');
}

function reloadInspectorHistoryEntry(idx) {
  const entry = inspectorSessionHistory[idx];
  if (!entry) return;
  const input = document.getElementById('inspectTokenInput');
  if (input) {
    input.value = entry.rawInput;
    inspectToken({ skipHistoryRecord: true });
  }
}

function renderInspectorSessionHistory() {
  const panel = document.getElementById('inspectorSessionHistoryPanel');
  const listEl = document.getElementById('inspectorSessionHistoryList');
  const countEl = document.getElementById('inspectorHistoryCount');
  if (!panel || !listEl) return;

  loadInspectorSessionHistory();
  if (countEl) countEl.textContent = String(inspectorSessionHistory.length);

  if (inspectorSessionHistory.length === 0) {
    panel.style.display = 'none';
    listEl.innerHTML = '';
    return;
  }

  panel.style.display = 'block';
  listEl.innerHTML = '';
  inspectorSessionHistory.forEach((item, idx) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'inspector-history-item';
    btn.title = 'Clic para recargar y volver a auditar';
    btn.innerHTML = `
      <div style="display:flex; align-items:center; gap:0.5rem; flex-wrap:wrap;">
        <span class="badge ${escapeHtml(item.kind === 'MLS1' ? 'badge-blue' : 'badge-mono')}">${escapeHtml(item.kind)}</span>
        <strong style="font-size:0.84rem;">${escapeHtml(item.summaryLabel)}</strong>
        <code style="font-family:var(--font-mono); font-size:0.78rem; color:var(--primary);">${escapeHtml(item.hardwareId)}</code>
      </div>
      <div style="display:flex; align-items:center; gap:0.5rem; flex-wrap:wrap;">
        <span class="badge ${escapeHtml(item.statusTone)}">${escapeHtml(item.statusText)}</span>
        <span style="font-size:0.74rem; color:var(--text-muted);" title="UTC: ${escapeHtml(item.timestampIso)}">${escapeHtml(item.timestampLima)}</span>
      </div>
    `;
    btn.addEventListener('click', () => reloadInspectorHistoryEntry(idx));
    listEl.appendChild(btn);
  });
}

function openClientDrawerFromInspector(clientId) {
  if (!clientId) return;
  document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
  document.querySelector('[data-tab="tabClients"]')?.classList.add('active');
  document.getElementById('tabClients')?.classList.add('active');
  openClient360Drawer(clientId, 'drawerTabOverview');
}

function buildInspectorForensicReportText(snapshot) {
  if (!snapshot) return '';
  const lines = [
    `INFORME FORENSE MOCHILALISTA (${snapshot.kind})`,
    `Fecha de Auditoría: ${formatLimaDateTime(snapshot.auditedAtIso)} [UTC: ${snapshot.auditedAtIso}]`,
    `Validez Criptográfica: ${snapshot.valid ? 'VÁLIDA' : 'INVÁLIDA'} (${snapshot.statusDetail || '-'})`,
  ];
  if (snapshot.clientSummary) {
    lines.push(`Cliente CRM: ${snapshot.clientSummary}`);
  }
  if (snapshot.nonceStatusLabel) {
    lines.push(`Estado de Nonce Reconciliado: ${snapshot.nonceStatusLabel}`);
  }
  if (Array.isArray(snapshot.highlights) && snapshot.highlights.length > 0) {
    lines.push('Detalle Técnico:');
    snapshot.highlights.forEach(h => lines.push(`- ${h.label}: ${h.value}`));
  }
  return lines.join('\n');
}

function copyInspectorForensicReport() {
  const reportText = buildInspectorForensicReportText(currentInspectorAuditSnapshot);
  if (!reportText) {
    showToast('No hay informe forense activo para copiar.', 'warning');
    return;
  }
  copyPlainTextToClipboard(reportText, 'Informe forense copiado al portapapeles.');
}

function renderInspectorQuickActionsBar(matchedClient) {
  if (!matchedClient || !matchedClient.id) return '';
  return `
    <div class="inspector-actions-bar">
      <button type="button" class="btn btn-outline btn-xs" id="btnInspectOpenDrawer360">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        Abrir Ficha 360°
      </button>
      <button type="button" class="btn btn-outline btn-xs" id="btnInspectOpenWa">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>
        Abrir WhatsApp
      </button>
      <button type="button" class="btn btn-outline btn-xs" id="btnInspectCopyReport">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
        Copiar Informe Forense
      </button>
    </div>
  `;
}

function bindInspectorQuickActions(clientId) {
  document.getElementById('btnInspectOpenDrawer360')?.addEventListener('click', () => {
    openClientDrawerFromInspector(clientId);
  });
  document.getElementById('btnInspectOpenWa')?.addEventListener('click', () => {
    openWhatsAppComposer(clientId);
  });
  document.getElementById('btnInspectCopyReport')?.addEventListener('click', () => {
    copyInspectorForensicReport();
  });
}

function initInspectorEvents() {
  document.getElementById('btnInspectToken')?.addEventListener('click', () => inspectToken());
  document.getElementById('btnClearInspectToken')?.addEventListener('click', () => {
    document.getElementById('inspectTokenInput').value = '';
    document.getElementById('inspectResultContainer').style.display = 'none';
  });
  renderInspectorSessionHistory();

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
  // Soporte directo para archivos de sincronización .mlsync o JSON
  if (file.name.endsWith('.mlsync') || file.name.endsWith('.json') || file.type === 'application/json') {
    const reader = new FileReader();
    reader.onload = (e) => {
      document.getElementById('inspectTokenInput').value = e.target.result;
      showToast('Archivo .mlsync cargado en Inspector Forense.', 'success');
      inspectToken();
    };
    reader.readAsText(file);
    return;
  }

  if (!file.type.startsWith('image/')) {
    showToast('El archivo no es una imagen válida ni un archivo .mlsync.', 'error');
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

/**
 * Renderizado de Auditoría para Fichas de Sincronización Offline (CLIENT_SYNC)
 */
function renderInspectClientSync(data, rawToken, options = {}) {
  const container = document.getElementById('inspectResultContainer');
  const badge = document.getElementById('inspectStatusBadge');
  const syncAuditCard = document.getElementById('inspectSyncAuditCard');
  const licenseClaimsWrapper = document.getElementById('inspectLicenseClaimsWrapper');
  const matchBox = document.getElementById('inspectMatchingClientBox');

  container.style.display = 'block';
  if (licenseClaimsWrapper) licenseClaimsWrapper.style.display = 'none';
  if (syncAuditCard) syncAuditCard.style.display = 'block';

  // 1. Sello de Integridad HMAC
  if (data.valid) {
    badge.style.background = 'rgba(16, 185, 129, 0.15)';
    badge.style.border = '1px solid rgba(16, 185, 129, 0.4)';
    badge.style.color = '#10b981';
    badge.innerHTML = `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg>
      <span><strong>FICHA DE SINCRONIZACIÓN OFFLINE VÁLIDA:</strong> ${escapeHtml(data.message || 'Integridad HMAC-SHA256 verificada.')}</span>
    `;
  } else {
    badge.style.background = 'rgba(239, 68, 68, 0.15)';
    badge.style.border = '1px solid rgba(239, 68, 68, 0.4)';
    badge.style.color = '#ef4444';
    badge.innerHTML = `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
      <span><strong>FIRMA ALTERADA O CORRUPTA (${escapeHtml(data.error_code || 'INVALID_SIGNATURE')}):</strong> ${escapeHtml(data.message || data.error || 'Firma inválida')}</span>
    `;
  }

  const p = data.payload || {};
  let rescueCardHtml = '';
  if (data.migration_rescue && data.migration_rescue.detected) {
    const mr = data.migration_rescue;
    const oldHw = escapeHtml(mr.old_hardware_id || '-');
    const newHw = escapeHtml(mr.new_hardware_id || '-');
    const modelStr = mr.device_model ? ` • ${escapeHtml(mr.device_model)}` : '';
    const clientName = data.matched_client ? `${escapeHtml(data.matched_client.business_name)} (${escapeHtml(data.matched_client.owner_name)})` : 'Cliente Origen';
    rescueCardHtml = `
      <div class="sync-migration-rescue-card" style="margin-bottom:1rem;">
        <div class="sync-rescue-header">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
          <span>Dispositivo Bloqueado por Migración / Restauración</span>
        </div>
        <div class="sync-rescue-body">
          <div><strong>Titular Detectado:</strong> ${clientName}</div>
          <div class="sync-rescue-hw-flow">
            <span class="sync-rescue-hw-old">Celular anterior (bhw): ${oldHw}</span>
            <span class="sync-rescue-hw-arrow">&rarr;</span>
            <span class="sync-rescue-hw-new">Nuevo celular (hw): ${newHw}${modelStr}</span>
          </div>
          <p style="margin:0.25rem 0 0.5rem 0; font-size:0.8rem; color:var(--text-secondary);">
            La app móvil reporta estado <code>PENDIENTE_MIGRACION</code>. Puedes reactivar el nuevo celular en 1 clic.
          </p>
        </div>
        <div style="display:flex; justify-content:flex-end;">
          <button type="button" class="btn btn-warning btn-sm" id="btnInspectRescueMigrate">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
            Migrar Dispositivo (Restauración — 0 días)
          </button>
        </div>
      </div>
    `;
  }

  const tsIso = p.ts ? new Date(p.ts).toISOString() : '';
  const syncFields = [
    { key: 'v', name: 'version_protocolo', desc: 'Versión del protocolo de sincronización', val: p.v || 1 },
    { key: 'hw', name: 'hardware_id', desc: 'Identificador único del hardware actual', val: p.hw || '-' },
    { key: 'bhw', name: 'bound_hardware_id', desc: 'Hardware ID previo si proviene de backup restaurado', val: p.bhw || 'No aplica' },
    { key: 'mod', name: 'device_model', desc: 'Marca y modelo del dispositivo móvil', val: p.mod || '-' },
    { key: 'os', name: 'android_version', desc: 'Versión del sistema operativo Android', val: p.os || '-' },
    { key: 'av', name: 'installed_version', desc: 'Versión del APK instalada en el celular', val: `v${p.av || '-'}` },
    { key: 'bc', name: 'build_code', desc: 'Código de compilación (versionCode)', val: p.bc !== undefined ? p.bc : '-' },
    { key: 'db', name: 'sqlite_schema', desc: 'Versión del esquema de base de datos SQLite', val: `Esquema v${p.db || '-'}` },
    { key: 'pl', name: 'license_plan', desc: 'Plan comercial activo en el teléfono', val: p.pl || '-' },
    { key: 'st', name: 'license_status', desc: 'Estado operativo de la licencia', val: p.st || '-' },
    { key: 'exp', name: 'license_expires', desc: 'Fecha límite de vigencia de la licencia', val: p.exp || 'Sin vencimiento' },
    { key: 'dr', name: 'days_remaining', desc: 'Días de evaluación o suscripción restantes', val: `${p.dr !== undefined ? p.dr : 0} días` },
    { key: 'n', name: 'last_nonce', desc: 'Último Nonce criptográfico consumido', val: `#${p.n !== undefined ? p.n : 0}` },
    { key: 'ai', name: 'ai_balance', desc: 'Saldo real disponible de créditos IA', val: `${p.ai !== undefined ? p.ai : 0} IA` },
    { key: 'aiu', name: 'ai_used_total', desc: 'Total histórico de consultas IA consumidas', val: `${p.aiu !== undefined ? p.aiu : 0} IA` },
    { key: 'byok', name: 'uses_byok', desc: 'Utiliza clave de API propia (Bring Your Own Key)', val: `${humanizeSyncFieldValue('uses_byok', p.byok)} (${p.byok ? 'Clave Propia' : 'Gestionado'})` },
    { key: 'pc', name: 'profiles_count', desc: 'Cantidad de perfiles de negocio creados', val: p.pc !== undefined ? p.pc : 1 },
    { key: 'drv', name: 'drive_linked', desc: 'Copia de seguridad en Google Drive activa', val: p.drv ? 'Sí (Vinculado)' : 'No (Sin vincular)' },
    { key: 'bh', name: 'backup_health', desc: 'Estado de salud del respaldo en la nube', val: humanizeSyncFieldValue('backup_health_status', p.bh || 'OK') },
    { key: 'lb', name: 'last_backup_at', desc: 'Fecha y hora del último respaldo exitoso (Lima GMT-5)', val: p.lb ? formatLimaDateTime(p.lb) : 'Sin respaldos', rawTitle: p.lb ? `UTC: ${p.lb}` : '' },
    { key: 'ts', name: 'generated_at', desc: 'Marca de tiempo de generación del reporte (Lima GMT-5)', val: p.ts ? formatLimaDateTime(p.ts) : '-', rawTitle: tsIso ? `UTC: ${tsIso}` : '' },
  ];

  let syncTableRows = '';
  syncFields.forEach(f => {
    const titleAttr = f.rawTitle ? ` title="${escapeHtml(f.rawTitle)}"` : '';
    syncTableRows += `
      <tr>
        <td><span class="claims-compact-key">${escapeHtml(f.key)}</span></td>
        <td><code>${escapeHtml(f.name)}</code></td>
        <td style="color:var(--text-secondary);">${escapeHtml(f.desc)}</td>
        <td${titleAttr}><strong>${escapeHtml(String(f.val))}</strong></td>
      </tr>
    `;
  });

  const allUnchanged = Boolean(data.all_unchanged ?? data.analysis?.all_unchanged);
  const sameTimestamp = Boolean(data.same_timestamp ?? data.analysis?.same_timestamp);
  const diffSectionHtml = (Array.isArray(data.changes) && data.changes.length > 0)
    ? `<div id="inspectSyncDiffSection" style="margin-top:1rem;">${renderSyncDiffTable(data.changes, { allUnchanged, sameTimestamp })}</div>`
    : '';

  syncAuditCard.innerHTML = `
    ${rescueCardHtml}
    <h4 style="font-size:0.95rem; font-weight:700; color:var(--text-primary); margin-bottom:0.5rem;">
      Métricas Técnicas & Operativas Reportadas (.mlsync)
    </h4>
    <div class="table-responsive">
      <table class="claims-table">
        <thead>
          <tr>
            <th style="width:100px;">Clave</th>
            <th style="width:160px;">Campo Técnico</th>
            <th>Descripción de Métrica</th>
            <th style="width:260px;">Valor Reportado</th>
          </tr>
        </thead>
        <tbody>
          ${syncTableRows}
        </tbody>
      </table>
    </div>
    ${diffSectionHtml}
  `;

  document.getElementById('btnInspectRescueMigrate')?.addEventListener('click', () => {
    if (data.matched_client && data.matched_client.id) {
      openMigrateModal(data.matched_client.id, {
        newDeviceId: data.migration_rescue.new_hardware_id,
        newDeviceModel: data.migration_rescue.device_model,
        scenario: 'RESTORED_BACKUP'
      });
    }
  });

  const matchedClient = data.matched_client;
  currentInspectorAuditSnapshot = {
    kind: 'MLS1',
    auditedAtIso: new Date().toISOString(),
    valid: Boolean(data.valid),
    statusDetail: data.valid ? 'Integridad HMAC-SHA256 verificada' : (data.error_code || 'INVALID_SIGNATURE'),
    clientSummary: matchedClient
      ? `${matchedClient.business_name} (${matchedClient.owner_name}) | ${matchedClient.current_device_id}`
      : `Sin coincidencia en CRM (hw=${p.hw || '-'})`,
    highlights: [
      { label: 'Hardware ID', value: p.hw || '-' },
      { label: 'Versión APK', value: `v${p.av || '-'}` },
      { label: 'Plan / Vigencia', value: `${p.pl || '-'} / ${p.st || '-'}` },
      { label: 'Saldo IA / Consumidos', value: `${p.ai ?? 0} IA / ${p.aiu ?? 0} IA` },
      { label: 'Nonce Reportado', value: `#${p.n ?? 0}` },
      { label: 'Generado (Lima)', value: p.ts ? formatLimaDateTime(p.ts) : '-' },
    ],
  };

  if (matchedClient) {
    matchBox.style.display = 'block';
    const canApplyDirectly = data.valid && data.match_type === 'EXACT_HARDWARE';
    matchBox.innerHTML = `
      <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem; margin-bottom:0.4rem;">
        <div style="display:flex; align-items:center; gap:6px;">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color:var(--primary);"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          <strong style="color:var(--primary); font-size:0.95rem;">Cliente Coincidente en Cartera:</strong>
        </div>
        ${canApplyDirectly ? `
          <button type="button" class="btn btn-primary btn-sm" id="btnInspectApplySync">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6L9 17l-5-5"/></svg>
            ${allUnchanged || sameTimestamp ? 'Re-confirmar Ficha en Cartera CRM' : 'Aplicar Sincronización en Cartera CRM'}
          </button>
        ` : ''}
      </div>
      <p style="margin:0; color:var(--text-primary); font-size:0.88rem;">
        <strong>${escapeHtml(matchedClient.business_name)}</strong> (${escapeHtml(matchedClient.owner_name)})
        • WhatsApp: <strong>${escapeHtml(matchedClient.phone)}</strong>
        • Hardware ID: <code style="font-family:var(--font-mono); font-weight:700;">${escapeHtml(matchedClient.current_device_id || '-')}</code>
        • Plan: <span class="badge badge-mono">${escapeHtml(matchedClient.license_type)}</span>
      </p>
      ${renderInspectorQuickActionsBar(matchedClient)}
    `;

    bindInspectorQuickActions(matchedClient.id);

    document.getElementById('btnInspectApplySync')?.addEventListener('click', async () => {
      try {
        const res = await fetch('/api/sync/apply', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            client_id: matchedClient.id,
            raw_input: rawToken,
            force_older: false,
          }),
        });
        const resData = await res.json();
        if (!res.ok) {
          if (res.status === 409) {
            showToast('Conflicto: El reporte es anterior a la última sincronización guardada.', 'warning');
            return;
          }
          throw new Error(resData.error || 'Error al aplicar sincronización');
        }
        showToast(`¡Sincronización aplicada exitosamente para ${matchedClient.business_name}!`, 'success');
        await loadClients();
        await loadDashboard();
        await loadReleaseMatrix();
      } catch (err) {
        showToast('Error: ' + err.message, 'error');
      }
    });
  } else {
    matchBox.style.display = 'block';
    matchBox.innerHTML = `
      <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem;">
        <span style="color:var(--text-muted); font-size:0.85rem;">
          Hardware ID <code>${escapeHtml(p.hw || '-')}</code> no está registrado en la Cartera CRM actual.
        </span>
        <div style="display:flex; gap:0.45rem; flex-wrap:wrap;">
          <button type="button" class="btn btn-outline btn-xs" id="btnInspectCopyReport">
            <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
            Copiar Informe Forense
          </button>
          <button type="button" class="btn btn-outline btn-sm" id="btnInspectCreateClient">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            Registrar Nuevo Cliente
          </button>
        </div>
      </div>
    `;
    document.getElementById('btnInspectCopyReport')?.addEventListener('click', copyInspectorForensicReport);

    document.getElementById('btnInspectCreateClient')?.addEventListener('click', () => {
      openModal('modalCreateClient');
      const devInp = document.getElementById('clientDeviceId') || document.getElementById('newClientDeviceId');
      if (devInp) devInp.value = p.hw || '';
      const modInp = document.getElementById('clientDeviceModel') || document.getElementById('newClientDeviceModel');
      if (modInp) modInp.value = p.mod || '';
      const aiInp = document.getElementById('clientAiBalance') || document.getElementById('newClientAiBalance');
      if (aiInp) aiInp.value = p.ai || 0;
    });
  }

  if (!options.skipHistoryRecord) {
    recordInspectorSessionEntry({
      kind: 'MLS1',
      summaryLabel: matchedClient ? matchedClient.business_name : (p.mod || 'Dispositivo sin registrar'),
      hardwareId: p.hw || '-',
      statusText: data.valid ? (allUnchanged ? 'Sin cambios' : 'Válida HMAC') : (data.error_code || 'Inválida'),
      statusTone: data.valid ? 'badge-green' : 'badge-red',
      timestampIso: new Date().toISOString(),
      rawInput: rawToken,
    });
  }
}

async function inspectToken(options = {}) {
  const token = document.getElementById('inspectTokenInput').value.trim();
  if (!token) {
    showToast('Por favor pega un código de licencia, token MLS1 o sube un archivo.', 'warning');
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

    // Enrutamiento DUAL: Si es CLIENT_SYNC, delegar al renderizado especializado
    if (data.input_kind === 'CLIENT_SYNC') {
      renderInspectClientSync(data, token, options);
      return;
    }

    const container = document.getElementById('inspectResultContainer');
    const badge = document.getElementById('inspectStatusBadge');
    const tbody = document.getElementById('inspectClaimsTableBody');
    const matchBox = document.getElementById('inspectMatchingClientBox');
    const syncAuditCard = document.getElementById('inspectSyncAuditCard');
    const licenseClaimsWrapper = document.getElementById('inspectLicenseClaimsWrapper');

    container.style.display = 'block';
    if (syncAuditCard) syncAuditCard.style.display = 'none';
    if (licenseClaimsWrapper) licenseClaimsWrapper.style.display = 'block';

    const isTokenValid = Boolean(data.valid || data.isValid);
    if (isTokenValid) {
      badge.style.background = 'rgba(16, 185, 129, 0.15)';
      badge.style.border = '1px solid rgba(16, 185, 129, 0.4)';
      badge.style.color = '#10b981';
      badge.innerHTML = `
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg>
        <span><strong>TOKEN VÁLIDO:</strong> ${escapeHtml(data.message || 'Firma criptográfica Ed25519 auténtica.')}</span>
      `;
    } else {
      badge.style.background = 'rgba(239, 68, 68, 0.15)';
      badge.style.border = '1px solid rgba(239, 68, 68, 0.4)';
      badge.style.color = '#ef4444';
      badge.innerHTML = `
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <span><strong>TOKEN INVÁLIDO (${escapeHtml(data.status || 'ERROR')}):</strong> ${escapeHtml(data.message || data.error)}</span>
      `;
    }

    if (!data.payload) {
      tbody.innerHTML = '<tr><td colspan="4" style="text-align:center; color:var(--text-muted); padding:1rem;">El token no contiene un payload decodificable.</td></tr>';
      matchBox.style.display = 'none';
      currentInspectorAuditSnapshot = {
        kind: 'ML9',
        auditedAtIso: new Date().toISOString(),
        valid: false,
        statusDetail: data.message || data.error || 'Token ilegible',
        highlights: [],
      };
      return;
    }

    const p = data.payload;
    const rawIat = p.e || p.iat || data.emitted_at || '';
    const rawU = p.u || data.updates_until || '';
    const formattedU = rawU
      ? (String(rawU).includes('T') ? formatLimaDateTime(rawU) : String(rawU))
      : 'No aplica';

    const claims = [
      { key: 'd', name: 'hardware_id', desc: 'Hardware ID único generado desde Settings.Secure.ANDROID_ID', val: p.d || data.device_id || '-' },
      { key: 'p', name: 'plan', desc: 'Tipo de plan comercial otorgado', val: p.p || data.plan || '-' },
      { key: 'y', name: 'days_added', desc: 'Días acumulativos sumados a la vigencia', val: `+${p.y !== undefined ? p.y : data.days_added} días` },
      { key: 'n', name: 'nonce', desc: 'Contador correlativo anti-reutilización', val: `#${p.n !== undefined ? p.n : data.nonce}` },
      { key: 'v', name: 'min_app_version', desc: 'Versión mayor mínima requerida', val: `v${p.v !== undefined ? p.v : data.max_major_version}` },
      { key: 'iat', name: 'emitted_at', desc: 'Fecha de emisión (Hora Perú GMT-5)', val: rawIat ? formatLimaDateTime(rawIat) : '-', rawTitle: rawIat ? `UTC: ${rawIat}` : '' },
      { key: 'u', name: 'updates_until', desc: 'Fecha límite de actualizaciones (updates)', val: formattedU, rawTitle: rawU && String(rawU).includes('T') ? `UTC: ${rawU}` : '' },
      { key: 'b', name: 'business_tag', desc: 'Razón social o etiqueta del negocio', val: p.b || data.business_tag || '-' },
      { key: 'c', name: 'ai_extra_credits', desc: 'Créditos IA extras/recarga (claim c de transporte anti-doble conteo)', val: `+${p.c !== undefined ? p.c : data.ai_extra_credits} escaneos` },
    ];

    tbody.innerHTML = '';
    claims.forEach(c => {
      const tr = document.createElement('tr');
      const titleAttr = c.rawTitle ? ` title="${escapeHtml(c.rawTitle)}"` : '';
      tr.innerHTML = `
        <td><span class="claims-compact-key">${escapeHtml(c.key)}</span></td>
        <td><code>${escapeHtml(c.name)}</code></td>
        <td style="color:var(--text-secondary);">${escapeHtml(c.desc)}</td>
        <td${titleAttr}><strong>${escapeHtml(String(c.val))}</strong></td>
      `;
      tbody.appendChild(tr);
    });

    // Cruce con Cliente Registrado en CRM + Matriz de 4 Estados de Nonce
    const matchedClient = data.matching_client || data.registered_client;
    const tNonce = p.n !== undefined ? p.n : data.nonce;
    let nonceInfo = null;

    if (matchedClient) {
      matchBox.style.display = 'block';
      nonceInfo = reconcileInspectorNonceStatus(tNonce, matchedClient);
      const nonceStatusBadge = `<span class="${escapeHtml(nonceInfo.badgeClass)}">${escapeHtml(nonceInfo.label)}</span>`;
      const lastSyncHint = matchedClient.last_sync_at
        ? ` • Últ. Sync: <span title="UTC: ${escapeHtml(matchedClient.last_sync_at)}">${escapeHtml(formatLimaDateTime(matchedClient.last_sync_at))}</span>`
        : '';

      matchBox.innerHTML = `
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem; margin-bottom:0.4rem;">
          <div style="display:flex; align-items:center; gap:6px;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color:var(--primary);"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            <strong style="color:var(--primary); font-size:0.95rem;">Cliente Coincidente en Cartera:</strong>
          </div>
          ${nonceStatusBadge}
        </div>
        <p style="margin:0; color:var(--text-primary); font-size:0.88rem;">
          <strong>${escapeHtml(matchedClient.business_name)}</strong> (${escapeHtml(matchedClient.owner_name)})
          • WhatsApp: <strong>${escapeHtml(matchedClient.phone)}</strong>
          • Plan en DB: <span class="badge badge-mono">${escapeHtml(matchedClient.license_type)}</span>
          • Versión Instalada: v${escapeHtml(matchedClient.installed_version || '9.24.0')}${lastSyncHint}
        </p>
        ${renderInspectorQuickActionsBar(matchedClient)}
      `;
      bindInspectorQuickActions(matchedClient.id);
    } else {
      matchBox.style.display = 'block';
      matchBox.innerHTML = `
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem;">
          <span style="color:var(--text-muted); font-size:0.85rem;">
            El token fue firmado válidamente con tu clave maestra pero el Device ID <code>${escapeHtml(p.d || '-')}</code> no coincide con ningún cliente registrado en este entorno.
          </span>
          <button type="button" class="btn btn-outline btn-xs" id="btnInspectCopyReport">
            <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
            Copiar Informe Forense
          </button>
        </div>
      `;
      document.getElementById('btnInspectCopyReport')?.addEventListener('click', copyInspectorForensicReport);
    }

    currentInspectorAuditSnapshot = {
      kind: 'ML9',
      auditedAtIso: new Date().toISOString(),
      valid: isTokenValid,
      statusDetail: isTokenValid ? 'Firma Ed25519 auténtica' : (data.status || 'ERROR'),
      clientSummary: matchedClient
        ? `${matchedClient.business_name} (${matchedClient.owner_name}) | ${p.d || '-'}`
        : `Sin coincidencia en CRM (d=${p.d || '-'})`,
      nonceStatusLabel: nonceInfo ? nonceInfo.label : `Nonce #${tNonce ?? '-'} (sin cliente CRM)`,
      highlights: [
        { label: 'Hardware ID (d)', value: p.d || '-' },
        { label: 'Plan (p)', value: p.p || '-' },
        { label: 'Días / Créditos IA', value: `+${p.y ?? 0}d / +${p.c ?? 0} IA` },
        { label: 'Nonce Token (n)', value: `#${tNonce ?? '-'}` },
        { label: 'Emitido (Lima)', value: rawIat ? formatLimaDateTime(rawIat) : '-' },
      ],
    };

    if (!options.skipHistoryRecord) {
      recordInspectorSessionEntry({
        kind: 'ML9',
        summaryLabel: matchedClient ? matchedClient.business_name : (p.b || 'Licencia Ed25519'),
        hardwareId: p.d || data.device_id || '-',
        statusText: nonceInfo ? nonceInfo.label : (isTokenValid ? 'Token válido' : 'Token inválido'),
        statusTone: isTokenValid ? 'badge-green' : 'badge-red',
        timestampIso: new Date().toISOString(),
        rawInput: token,
      });
    }
  } catch (e) {
    showToast('Error al auditar token: ' + e.message, 'error');
  }
}

// =================== 6. FINANZAS & RESPALDOS (NUEVA PESTAÑA OFICIAL) ===================
function initFinancesAndBackupsEvents() {
  // Filtros de Finanzas
  document.getElementById('inputFinSearch')?.addEventListener('input', renderFinancesTable);
  document.getElementById('btnFinSearchClear')?.addEventListener('click', () => {
    const inputSearch = document.getElementById('inputFinSearch');
    if (inputSearch) inputSearch.value = '';
    renderFinancesTable();
  });
  document.getElementById('finFilterFrom')?.addEventListener('change', renderFinancesTable);
  document.getElementById('finFilterTo')?.addEventListener('change', renderFinancesTable);
  document.getElementById('finFilterPlan')?.addEventListener('change', renderFinancesTable);
  document.getElementById('finFilterMethod')?.addEventListener('change', renderFinancesTable);
  document.getElementById('btnFinFilterClear')?.addEventListener('click', () => {
    const inputSearch = document.getElementById('inputFinSearch');
    if (inputSearch) inputSearch.value = '';
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

  const searchVal = (document.getElementById('inputFinSearch')?.value || '').trim().toLowerCase();
  const btnClear = document.getElementById('btnFinSearchClear');
  if (btnClear) {
    btnClear.style.display = searchVal ? 'block' : 'none';
  }

  const fromVal = document.getElementById('finFilterFrom')?.value;
  const toVal = document.getElementById('finFilterTo')?.value;
  const planVal = document.getElementById('finFilterPlan')?.value || 'all';
  const methodVal = document.getElementById('finFilterMethod')?.value || 'all';

  const filtered = globalFinances.filter(f => {
    if (fromVal && f.date && f.date.substring(0, 10) < fromVal) return false;
    if (toVal && f.date && f.date.substring(0, 10) > toVal) return false;
    if (planVal !== 'all' && !(f.plan || '').toUpperCase().includes(planVal.toUpperCase())) return false;
    if (methodVal !== 'all' && !(f.method || '').toUpperCase().includes(methodVal.toUpperCase())) return false;

    if (searchVal) {
      const receiptNo = (f.receipt_number || '').toLowerCase();
      const bolNo = (f.receipt_bol_number || '').toLowerCase();
      const facNo = (f.receipt_fac_number || '').toLowerCase();
      const clientName = (f.business_name || '').toLowerCase();
      const ownerName = (f.owner_name || '').toLowerCase();
      const clientId = (f.client_id || '').toLowerCase();
      const docId = (f.document_number || '').toLowerCase();
      const ref = (f.reference || '').toLowerCase();
      const plan = (f.plan || '').toLowerCase();
      const planHuman = (typeof formatPlanHumanLabel === 'function' ? formatPlanHumanLabel(f.plan) : '').toLowerCase();
      const notes = (f.notes || '').toLowerCase();

      const matches = receiptNo.includes(searchVal) ||
        bolNo.includes(searchVal) ||
        facNo.includes(searchVal) ||
        clientName.includes(searchVal) ||
        ownerName.includes(searchVal) ||
        clientId.includes(searchVal) ||
        docId.includes(searchVal) ||
        ref.includes(searchVal) ||
        plan.includes(searchVal) ||
        planHuman.includes(searchVal) ||
        notes.includes(searchVal);
      if (!matches) return false;
    }

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
    tbody.innerHTML = '<tr><td colspan="9" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Sin transacciones registradas para este filtro o criterio de búsqueda.</td></tr>';
    return;
  }

  filtered.forEach(f => {
    const tr = document.createElement('tr');

    let receiptCellHtml = '';
    const receiptNum = f.receipt_number || f.receipt_fac_number || f.receipt_bol_number;
    const rType = f.receipt_type || (receiptNum && receiptNum.startsWith('FAC') ? 'FAC' : (receiptNum && receiptNum.startsWith('BOL') ? 'BOL' : null));

    if (rType === 'FAC' || (receiptNum && receiptNum.startsWith('FAC'))) {
      const displayNum = receiptNum || 'FAC-XXXX';
      receiptCellHtml = `
        <button type="button" class="badge-receipt-fac" title="Ver / Reimprimir Factura Oficial" onclick="openPaymentReceiptModal('${escapeHtml(f.client_id)}', '${escapeHtml(f.id)}')">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
          <span>${escapeHtml(displayNum)}</span>
        </button>
      `;
    } else if (rType === 'BOL' || (receiptNum && receiptNum.startsWith('BOL'))) {
      const displayNum = receiptNum || 'BOL-XXXX';
      receiptCellHtml = `
        <button type="button" class="badge-receipt-bol" title="Ver / Reimprimir Boleta Oficial" onclick="openPaymentReceiptModal('${escapeHtml(f.client_id)}', '${escapeHtml(f.id)}')">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
          <span>${escapeHtml(displayNum)}</span>
        </button>
      `;
    } else {
      receiptCellHtml = `
        <button type="button" class="btn-fin-emit" title="Emitir Boleta o Factura Oficial para este pago" onclick="openPaymentReceiptModal('${escapeHtml(f.client_id)}', '${escapeHtml(f.id)}')">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
          <span>Emitir</span>
        </button>
      `;
    }

    let prevCorrelativeHtml = '';
    if (searchVal) {
      const activeNum = (f.receipt_number || '').toLowerCase();
      const bolNum = (f.receipt_bol_number || '').toLowerCase();
      const facNum = (f.receipt_fac_number || '').toLowerCase();

      if (bolNum && bolNum !== activeNum && bolNum.includes(searchVal)) {
        prevCorrelativeHtml = `<small class="receipt-matched-prev">Previo: ${escapeHtml(f.receipt_bol_number)}</small>`;
      } else if (facNum && facNum !== activeNum && facNum.includes(searchVal)) {
        prevCorrelativeHtml = `<small class="receipt-matched-prev">Previo: ${escapeHtml(f.receipt_fac_number)}</small>`;
      }
    }
    if (prevCorrelativeHtml) {
      receiptCellHtml = `<div style="display:flex; flex-direction:column; align-items:center; gap:2px;">${receiptCellHtml}${prevCorrelativeHtml}</div>`;
    }

    const planLabel = typeof formatPlanHumanLabel === 'function' ? formatPlanHumanLabel(f.plan) : (f.plan || '-');

    tr.innerHTML = `
      <td style="white-space:nowrap;">${f.date ? f.date.substring(0, 10) : '-'}</td>
      <td><strong style="font-family:var(--font-mono);">${escapeHtml(f.client_id)}</strong></td>
      <td><strong>${escapeHtml(f.business_name || '-')}</strong></td>
      <td>${escapeHtml(f.owner_name || '-')}</td>
      <td><span class="badge badge-mono">${escapeHtml(planLabel)}</span></td>
      <td>${escapeHtml(f.method || '-')}</td>
      <td><span style="font-family:var(--font-mono); font-size:0.8rem;">${escapeHtml(f.reference || '-')}</span></td>
      <td><strong style="color:var(--success); font-family:var(--font-mono);">S/ ${(f.amount || 0).toFixed(2)}</strong></td>
      <td style="text-align:center;">${receiptCellHtml}</td>
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

    // Versión instalada dinámica según último release publicado (Plan 19)
    const verInput = document.getElementById('newInstalledVersion');
    if (verInput) {
      verInput.value = (globalReleases && globalReleases.length > 0) ? (globalReleases[0].version_name || '9.38.0') : '9.38.0';
    }

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
    resetCreateReleaseModalState();
    openModal('modalCreateRelease');
  });

  document.getElementById('btnSubmitCreateRelease')?.addEventListener('click', async () => {
    const versionName = document.getElementById('relVersionName').value.trim();
    const versionCode = parseInt(document.getElementById('relVersionCode').value, 10) || 82;
    const minRequired = document.getElementById('relMinRequiredVersion').value.trim() || '9.0.0';
    const schemaVersion = parseInt(document.getElementById('relDbSchema').value, 10) || 36;
    const type = document.getElementById('relType').value;
    const rawSizeMb = document.getElementById('relSizeMb').value.trim();
    const sizeMb = rawSizeMb ? formatApkSizeMb(rawSizeMb) : '';
    const url = document.getElementById('relDownloadUrl').value.trim();
    const sha = document.getElementById('relSha256').value.trim();
    const changelog = document.getElementById('relChangelog').value.trim();
    const internalNotes = document.getElementById('relInternalNotes').value.trim();
    const uploadedPath = document.getElementById('relUploadedPath').value.trim();
    const abiVariant = document.getElementById('relAbiVariant').value || 'UNIVERSAL';

    const sigStatus = document.getElementById('relSignatureStatus')?.value;
    const sigVerifiedRaw = document.getElementById('relSignatureVerified')?.value;
    const sigVerified = sigVerifiedRaw === 'true' ? true : (sigVerifiedRaw === 'false' ? false : null);
    const signerSha = document.getElementById('relSignerSha256')?.value;
    const signerDn = document.getElementById('relSignerDn')?.value;

    // Escudo Anti-debug.apk: Bloqueo preventivo de firmas no oficiales
    if (sigStatus === 'UNOFFICIAL_SIGNATURE') {
      const chkAck = document.getElementById('chkAcknowledgeUnofficialApk');
      if (!chkAck || !chkAck.checked) {
        showToast('ATENCIÓN: Este APK no cuenta con la firma comercial oficial. Debes confirmar la casilla de advertencia para poder publicarlo.', 'error');
        return;
      }
    }

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
          apk_file_path: uploadedPath,
          apk_download_url: url,
          apk_sha256: sha,
          changelog: changelog,
          internal_notes: internalNotes,
          abi_variant: abiVariant,
          signature_verified: sigVerified,
          signature_status: sigStatus || 'UNVERIFIED',
          signer_sha256: signerSha,
          signer_dn: signerDn,
        }),
      });

      if (!res.ok) throw new Error('Error al publicar versión');
      closeModal('modalCreateRelease');
      resetCreateReleaseModalState();
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
    const versionCode = parseInt(document.getElementById('editRelVersionCode').value, 10) || 82;
    const dbSchema = parseInt(document.getElementById('editRelDbSchema').value, 10) || 36;
    const minRequired = document.getElementById('editRelMinRequiredVersion').value.trim() || '9.0.0';
    const type = document.getElementById('editRelType').value;
    const url = document.getElementById('editRelDownloadUrl').value.trim();
    const changelog = document.getElementById('editRelChangelog').value.trim();
    const internalNotes = document.getElementById('editRelInternalNotes').value.trim();

    try {
      const res = await fetch(`/api/releases/${encodeURIComponent(versionName)}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          version_code: versionCode,
          db_schema_version: dbSchema,
          min_required_version: minRequired,
          type: type,
          apk_download_url: url,
          changelog: changelog,
          internal_notes: internalNotes,
        }),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || 'Error al actualizar versión');
      }
      const updatedRel = await res.json().catch(() => null);
      closeModal('modalEditRelease');
      showToast(`Versión v${versionName} actualizada.`, 'success');
      if (updatedRel && typeof syncReleaseAcrossUiAndComposer === 'function') {
        await syncReleaseAcrossUiAndComposer(versionName, updatedRel);
      } else {
        await loadReleases();
        await loadReleaseMatrix();
      }
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Inputs ocultos para subida de variantes en modal de edición
  document.getElementById('editRelUniversalInput')?.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (file) {
      handleVariantFileSelected(file, 'universal', currentUploadVariantVersion);
    }
    e.target.value = '';
  });

  document.getElementById('editRelArm64Input')?.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (file) {
      handleVariantFileSelected(file, 'arm64', currentUploadVariantVersion);
    }
    e.target.value = '';
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
      if (planInput) planInput.value = customConcept?.value?.trim() || '';
    } else {
      if (customConcept) {
        customConcept.style.display = 'none';
        customConcept.value = '';
      }
      if (planInput) planInput.value = val;
      const selectedOpt = e.target.selectedOptions?.[0];
      const price = selectedOpt?.dataset?.price;
      if (price !== undefined && !paymentId && amountInput) {
        amountInput.value = parseFloat(price).toFixed(2);
      }
    }
  });

  document.getElementById('btnSubmitManualPayment')?.addEventListener('click', async () => {
    const clientId = document.getElementById('manualPayClientId').value;
    const paymentId = document.getElementById('manualPayId')?.value?.trim();
    const rawAmt = parseFloat(document.getElementById('manualPayAmount').value);
    if (isNaN(rawAmt) || rawAmt < 0) {
      showToast('El monto debe ser mayor o igual a cero.', 'warning');
      return;
    }
    const amount = parseFloat(rawAmt.toFixed(2));
    
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

    if (!plan) {
      showToast('Por favor completa el concepto o plan del pago.', 'warning');
      return;
    }

    const method = document.getElementById('manualPayMethod').value;
    const ref = document.getElementById('manualPayRef').value.trim();
    const notes = document.getElementById('manualPayNotes').value.trim();
    const date = document.getElementById('manualPayDate')?.value || new Date().toISOString().substring(0, 10);
    const shouldGenerateReceipt = document.getElementById('manualPayGenerateReceipt')?.checked ?? false;

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

      // Si se marcó emitir o abrir comprobante de pago al guardar
      if (shouldGenerateReceipt) {
        if (paymentId) {
          openPaymentReceiptModal(clientId, paymentId);
        } else if (updatedClient && Array.isArray(updatedClient.payment_history)) {
          const newPayment = updatedClient.payment_history[updatedClient.payment_history.length - 1];
          if (newPayment && newPayment.id) {
            openPaymentReceiptModal(clientId, newPayment.id);
          }
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
          <td>${escapeHtml(formatPlanHumanLabel(p.plan || '-'))}${p.updated_at ? ` <span class="badge-edited-payment" title="Pago editado el ${escapeHtml(p.updated_at.substring(0, 10))} ${escapeHtml(p.updated_at.substring(11, 16))} UTC"><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:middle;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg> <span>Editado</span></span>` : ''}</td>
          <td>${escapeHtml(p.method || '-')}</td>
          <td>${escapeHtml(p.reference || '-')}</td>
          <td>
            <button class="btn btn-outline btn-sm" style="color:var(--danger); border-color:var(--danger); font-size:0.75rem; display:inline-flex; align-items:center; gap:0.3rem;" onclick="voidPayment('${client.id}', '${p.id}')" title="Anular transacción">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
              <span>Anular</span>
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
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
              </button>
              <button class="btn btn-primary btn-sm" onclick="downloadHistoricalCredential(${idx})" title="Descargar Credencial PNG Oficial" style="display:inline-flex; align-items:center; gap:0.3rem;">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><line x1="15" y1="10" x2="19" y2="10"/><line x1="7" y1="15" x2="19" y2="15"/></svg>
                <span>Tarjeta PNG</span>
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
      <div style="font-size:1.1rem; font-weight:700; color:var(--success); font-family:var(--font-mono); display:flex; align-items:center; gap:0.4rem;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
        <span>${escapeHtml(client.current_device_id)}</span>
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
          <td style="white-space: nowrap; min-width: 96px;">${h.migrated_at ? h.migrated_at.substring(0, 10) : '-'}</td>
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
  const followupDate = document.getElementById('newFollowupDate')?.value || null;
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
        next_followup_date: followupDate,
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

function openMigrateModal(clientId, options = {}) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  document.getElementById('migClientId').value = client.id;
  document.getElementById('migClientName').value = `${client.business_name} (${client.owner_name})`;
  document.getElementById('migOldDeviceId').value = client.current_device_id || '';
  document.getElementById('migNewDeviceId').value = options.newDeviceId || '';
  document.getElementById('migNewDeviceModel').value = options.newDeviceModel || '';

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

  // Escenario por defecto o prellenado desde rescate
  const scenarioSel = document.getElementById('migScenario');
  if (scenarioSel) scenarioSel.value = options.scenario || 'RESTORED_BACKUP';
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
  if (id === 'modalCreateRelease' && typeof resetCreateReleaseModalState === 'function') {
    resetCreateReleaseModalState();
  }
  if (id === 'modalEditRelease') {
    if (typeof resetExpandableTextarea === 'function') {
      resetExpandableTextarea('editRelChangelog');
      resetExpandableTextarea('editRelInternalNotes');
    }
    const editDirsPanel = document.getElementById('editSearchDirsPanel');
    if (editDirsPanel) editDirsPanel.style.display = 'none';
    const newEditDirInp = document.getElementById('inputEditNewApkSearchDir');
    if (newEditDirInp) newEditDirInp.value = '';
  }
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
          link_descarga: 'https://drive.google.com/file/d/demo/view (o adjunto en chat)',
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
      ...(ownerConfig?.system || {}),
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
        ? '<span style="color:var(--cyan); font-weight:600; font-size:0.8rem; display:inline-flex; align-items:center; gap:0.25rem;"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg> Bóveda Espejo</span>'
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
    if (vKey) {
      if (loadedVaultMetadata.has_master_key) {
        vKey.innerHTML = '<span style="display:inline-flex; align-items:center; gap:0.25rem; color:var(--success); font-weight:600;"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> Incluida</span>';
      } else {
        vKey.textContent = 'No incluida';
      }
    }
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
