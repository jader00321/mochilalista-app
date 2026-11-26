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
    tabInspector: 'Inspector Forense (ML9 / MLS1 / MLC1)',
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
      const targetTabKey = tab.dataset.tab;
      const activeNav = document.querySelector('.nav-tab.active');
      const currentTabKey = activeNav?.dataset?.tab;
      if (currentTabKey === 'tabSettings' && targetTabKey !== 'tabSettings' && typeof guardSettingsExit === 'function') {
        const proceed = guardSettingsExit(() => navigateToSidebarTab(tab));
        if (!proceed) return;
      }
      navigateToSidebarTab(tab);
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

  function navigateToSidebarTab(tab) {
    if (!tab) return;
    tabs.forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

    tab.classList.add('active');
    const targetPane = document.getElementById(tab.dataset.tab);
    if (targetPane) targetPane.classList.add('active');

    const viewNameEl = document.getElementById('currentViewName');
    if (viewNameEl && tabTitles[tab.dataset.tab]) {
      viewNameEl.textContent = tabTitles[tab.dataset.tab];
    }

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
  }

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
  const savedTheme = (typeof localStorage !== 'undefined' && localStorage.getItem('ml_admin_theme')) || 'dark';
  applyTheme(savedTheme, { syncSelect: false });

  document.getElementById('btnThemeToggle')?.addEventListener('click', () => {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    applyTheme(next, { syncSelect: false });
  });

  document.getElementById('btnExportCsv')?.addEventListener('click', () => {
    window.open('/api/clients/export-csv', '_blank');
    showToast('Exportando cartera a CSV con codificación Excel UTF-8...', 'info');
  });
}

function applyTheme(theme, options = {}) {
  const safeTheme = theme === 'light' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', safeTheme);
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem('ml_admin_theme', safeTheme);
  }
  if (options.syncSelect !== false) {
    const cfgSel = document.getElementById('cfgDefaultTheme');
    if (cfgSel && cfgSel.value !== safeTheme) cfgSel.value = safeTheme;
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

async function switchMode(newMode, options = {}) {
  if (newMode === currentMode || _isSwitchingMode) return;
  if (!options.bypassDirtyGuard && typeof guardSettingsExit === 'function') {
    const canProceed = guardSettingsExit(() => switchMode(newMode, { bypassDirtyGuard: true }));
    if (!canProceed) return;
  }
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
