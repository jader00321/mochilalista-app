// =================== 6. FINANZAS & RESPALDOS (NUEVA PESTAÑA OFICIAL) ===================
const BACKUPS_PAGE_SIZE = 20;
let allBackupsCache = [];
let backupsVisibleLimit = BACKUPS_PAGE_SIZE;
let currentBackupFilter = 'all';
let currentBackupSearch = '';
let pendingRestoreBackupFilename = null;

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

  document.getElementById('btnPurgeSandboxBackups')?.addEventListener('click', confirmPurgeSandboxBackups);

  document.querySelectorAll('#backupsFilterPills .backup-pill').forEach(btn => {
    btn.addEventListener('click', () => {
      currentBackupFilter = btn.dataset.bfilter || 'all';
      backupsVisibleLimit = BACKUPS_PAGE_SIZE;
      syncBackupFilterPillsUi();
      renderBackupsTable();
    });
  });

  document.getElementById('btnFilterOnlyProdBackups')?.addEventListener('click', () => {
    currentBackupFilter = 'prod';
    backupsVisibleLimit = BACKUPS_PAGE_SIZE;
    syncBackupFilterPillsUi();
    renderBackupsTable();
  });

  document.getElementById('inputBackupsSearch')?.addEventListener('input', (e) => {
    currentBackupSearch = (e.target.value || '').trim().toLowerCase();
    backupsVisibleLimit = BACKUPS_PAGE_SIZE;
    renderBackupsTable();
  });

  document.getElementById('btnBackupsSearchClear')?.addEventListener('click', () => {
    const inp = document.getElementById('inputBackupsSearch');
    if (inp) inp.value = '';
    currentBackupSearch = '';
    backupsVisibleLimit = BACKUPS_PAGE_SIZE;
    renderBackupsTable();
  });

  document.getElementById('btnLoadMoreBackups')?.addEventListener('click', () => {
    backupsVisibleLimit += BACKUPS_PAGE_SIZE;
    renderBackupsTable();
  });

  // Modal Vista Previa antes de Restaurar
  document.getElementById('btnCloseBackupPreview')?.addEventListener('click', () => {
    pendingRestoreBackupFilename = null;
    closeModal('modalBackupPreview');
  });
  document.getElementById('btnCancelBackupPreview')?.addEventListener('click', () => {
    pendingRestoreBackupFilename = null;
    closeModal('modalBackupPreview');
  });
  document.getElementById('btnConfirmBackupPreview')?.addEventListener('click', executeConfirmedBackupRestore);
}

function syncBackupFilterPillsUi() {
  document.querySelectorAll('#backupsFilterPills .backup-pill').forEach(btn => {
    btn.classList.toggle('active', (btn.dataset.bfilter || 'all') === currentBackupFilter);
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
    const dateLima = formatLimaIsoDate(f.date, '');
    if (fromVal && dateLima && dateLima < fromVal) return false;
    if (toVal && dateLima && dateLima > toVal) return false;
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
    const dateLima = formatLimaIsoDate(f.date, '-');
    const fullLimaTitle = f.date ? `${formatLimaDateTime(f.date)} | UTC: ${f.date}` : '';

    tr.innerHTML = `
      <td style="white-space:nowrap;" title="${escapeHtml(fullLimaTitle)}">${escapeHtml(dateLima)}</td>
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
  if (typeof applyTableDensity === 'function') {
    applyTableDensity(ownerConfig?.system?.table_density);
  }
}

function updateBackupFilterCounters() {
  const counts = { all: allBackupsCache.length, prod: 0, sandbox: 0, global: 0, manual: 0 };
  allBackupsCache.forEach(b => {
    const m = (b.mode || '').toLowerCase();
    if (m === 'prod') counts.prod++;
    else if (m === 'sandbox') counts.sandbox++;
    else counts.global++;
    if (b.is_manual || (b.filename || '').toLowerCase().includes('manual')) counts.manual++;
  });

  const setTxt = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = String(val); };
  setTxt('bCountAll', counts.all);
  setTxt('bCountProd', counts.prod);
  setTxt('bCountSandbox', counts.sandbox);
  setTxt('bCountGlobal', counts.global);
  setTxt('bCountManual', counts.manual);
}

async function loadBackups() {
  try {
    const res = await fetch('/api/backups', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar respaldos');
    const backups = await res.json();
    allBackupsCache = Array.isArray(backups) ? backups : [];
    backupsVisibleLimit = Math.max(BACKUPS_PAGE_SIZE, backupsVisibleLimit);
    updateBackupFilterCounters();
    renderBackupsTable();
  } catch (e) {
    console.error('Error al cargar backups:', e);
  }
}

function renderBackupsTable() {
  const tbody = document.getElementById('backupsTableBody');
  if (!tbody) return;
  tbody.innerHTML = '';

  const btnClearSearch = document.getElementById('btnBackupsSearchClear');
  if (btnClearSearch) {
    btnClearSearch.style.display = currentBackupSearch ? 'inline-flex' : 'none';
  }

  const filtered = allBackupsCache.filter(b => {
    const mode = (b.mode || 'global').toLowerCase();
    const fname = (b.filename || '').toLowerCase();
    const isManual = !!b.is_manual || fname.includes('manual');

    if (currentBackupFilter === 'prod' && mode !== 'prod') return false;
    if (currentBackupFilter === 'sandbox' && mode !== 'sandbox') return false;
    if (currentBackupFilter === 'global' && mode !== 'global') return false;
    if (currentBackupFilter === 'manual' && !isManual) return false;

    if (currentBackupSearch) {
      const scope = (b.target_scope || '').toLowerCase();
      if (!fname.includes(currentBackupSearch) && !mode.includes(currentBackupSearch) && !scope.includes(currentBackupSearch)) {
        return false;
      }
    }
    return true;
  });

  const modeBanner = document.getElementById('backupsModeBanner');
  if (modeBanner) {
    const hasSandboxVisible = filtered.some(b => (b.mode || '').toLowerCase() === 'sandbox');
    const shouldWarn = currentMode === 'prod' && currentBackupFilter === 'all' && hasSandboxVisible;
    modeBanner.style.display = shouldWarn ? 'flex' : 'none';
  }

  const footer = document.getElementById('backupsPaginationFooter');
  const infoEl = document.getElementById('backupsPaginationInfo');
  const btnMore = document.getElementById('btnLoadMoreBackups');
  const btnMoreTxt = document.getElementById('btnLoadMoreBackupsText');

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No hay respaldos que coincidan con el filtro seleccionado.</td></tr>';
    if (footer) footer.style.display = 'none';
    return;
  }

  const visible = filtered.slice(0, backupsVisibleLimit);
  visible.forEach(b => {
    const tr = document.createElement('tr');
    const modeBadge = b.mode === 'prod'
      ? '<span class="badge badge-green">PROD</span>'
      : (b.mode === 'sandbox' ? '<span class="badge badge-yellow">SANDBOX</span>' : '<span class="badge badge-purple">GLOBAL</span>');

    const protectedHtml = b.is_protected
      ? '<span class="backup-protected-tag" title="Respaldo protegido contra rotación automática"><svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>Protegido</span>'
      : '';

    const limaDisplay = b.modified_at ? formatLimaDateTime(b.modified_at, b.modified_lima || '-') : (b.modified_lima || '-');
    const utcTitle = b.modified_at ? `UTC: ${b.modified_at}` : '';

    tr.innerHTML = `
      <td>
        <code style="font-family:var(--font-mono); font-size:0.8rem;">${escapeHtml(b.filename)}</code>${protectedHtml}
      </td>
      <td title="${escapeHtml(utcTitle)}" style="white-space:nowrap;">${escapeHtml(limaDisplay)}</td>
      <td style="white-space:nowrap;">${escapeHtml(b.size_kb)} KB</td>
      <td>${modeBadge}</td>
      <td>
        <div class="backup-actions-row">
          <a href="/api/backups/download/${encodeURIComponent(b.filename)}" class="btn btn-outline btn-sm backup-action-btn" title="Descargar archivo JSON a PC o USB">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          </a>
          <button type="button" class="btn btn-outline btn-sm backup-action-btn" style="color:var(--warning); border-color:var(--warning);" onclick="openBackupRestorePreview('${escapeHtml(b.filename)}')" title="Ver vista previa y restaurar a este punto">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg>
            <span>Restaurar</span>
          </button>
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  });

  if (footer) {
    footer.style.display = 'flex';
  }
  if (infoEl) {
    infoEl.textContent = `Mostrando ${visible.length} de ${filtered.length} respaldos`;
  }
  if (btnMore) {
    const remaining = filtered.length - visible.length;
    if (remaining > 0) {
      btnMore.style.display = 'inline-flex';
      if (btnMoreTxt) {
        btnMoreTxt.textContent = `Cargar 20 respaldos más (Mostrando ${visible.length} de ${filtered.length})`;
      }
    } else {
      btnMore.style.display = 'none';
    }
  }
  if (typeof applyTableDensity === 'function') {
    applyTableDensity(ownerConfig?.system?.table_density);
  }
}

function buildBackupComparisonRows(scope, snap, cur) {
  if (scope === 'config') {
    return [
      { label: 'Planes en Tarifario', snapVal: String(snap.catalog_plans_count ?? '-'), curVal: String(cur.catalog_plans_count ?? '-') },
      { label: 'Plantillas WhatsApp', snapVal: String(snap.templates_count ?? '-'), curVal: String(cur.templates_count ?? '-') },
      { label: 'Entorno Inicial', snapVal: String(snap.default_mode ?? '-').toUpperCase(), curVal: String(cur.default_mode ?? '-').toUpperCase() },
      { label: 'Tema Predeterminado', snapVal: String(snap.theme ?? '-'), curVal: String(cur.theme ?? '-') },
    ];
  }
  if (scope === 'releases') {
    return [
      { label: 'Versiones APK Registradas', snapVal: String(snap.releases_count ?? 0), curVal: String(cur.releases_count ?? 0) },
      { label: 'Última Versión Publicada', snapVal: String(snap.latest_version ?? '-'), curVal: String(cur.latest_version ?? '-') },
    ];
  }
  return [
    { label: 'Clientes Registrados', snapVal: String(snap.clients_count ?? 0), curVal: String(cur.clients_count ?? 0) },
    { label: 'Transacciones / Pagos', snapVal: String(snap.payments_count ?? 0), curVal: String(cur.payments_count ?? 0) },
    { label: 'Ingresos Acumulados', snapVal: `S/ ${Number(snap.total_revenue_pen ?? 0).toFixed(2)}`, curVal: `S/ ${Number(cur.total_revenue_pen ?? 0).toFixed(2)}` },
    { label: 'Licencias Perpetuas', snapVal: String(snap.perpetual_count ?? 0), curVal: String(cur.perpetual_count ?? 0) },
  ];
}

async function openBackupRestorePreview(filename) {
  try {
    showToast('Analizando respaldo antes de restaurar...', 'info');
    const res = await fetch(`/api/backups/preview/${encodeURIComponent(filename)}`);
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || 'No se pudo previsualizar el respaldo');
    }

    pendingRestoreBackupFilename = filename;
    const setEl = (id, text) => { const el = document.getElementById(id); if (el) el.textContent = text; };
    setEl('bpFilename', data.filename || filename);
    setEl('bpModifiedLima', formatLimaDateTime(data.modified_at, data.modified_lima || '-'));
    setEl('bpModifiedUtc', data.modified_at || '-');
    setEl('bpSizeKb', `${data.size_kb || '0.0'} KB`);

    const envBadge = document.getElementById('bpEnvironmentBadge');
    if (envBadge) {
      const env = (data.environment || 'global').toLowerCase();
      envBadge.textContent = env.toUpperCase();
      envBadge.className = `badge ${env === 'prod' ? 'badge-green' : (env === 'sandbox' ? 'badge-yellow' : 'badge-purple')}`;
    }

    const scopeLabels = {
      clients: 'Cartera CRM y Pagos',
      releases: 'Catálogo de Versiones APK',
      config: 'Configuración GLOBAL',
    };
    const scopeBadge = document.getElementById('bpScopeBadge');
    if (scopeBadge) {
      scopeBadge.textContent = scopeLabels[data.target_scope] || data.target_scope || 'Respaldo JSON';
    }

    const tbody = document.getElementById('bpComparisonBody');
    if (tbody) {
      const rows = buildBackupComparisonRows(data.target_scope, data.snapshot_summary || {}, data.current_summary || {});
      tbody.innerHTML = rows.map(r => `
        <tr>
          <td><strong>${escapeHtml(r.label)}</strong></td>
          <td><span style="font-family:var(--font-mono); color:var(--primary); font-weight:700;">${escapeHtml(r.snapVal)}</span></td>
          <td><span style="font-family:var(--font-mono); color:var(--text-secondary);">${escapeHtml(r.curVal)}</span></td>
        </tr>
      `).join('');
    }

    const btnConfirm = document.getElementById('btnConfirmBackupPreview');
    if (btnConfirm) btnConfirm.disabled = false;

    openModal('modalBackupPreview');
  } catch (e) {
    showToast('Error al cargar vista previa: ' + e.message, 'error');
  }
}

const restoreBackup = openBackupRestorePreview;

async function executeConfirmedBackupRestore() {
  if (!pendingRestoreBackupFilename) return;
  const filename = pendingRestoreBackupFilename;
  const btnConfirm = document.getElementById('btnConfirmBackupPreview');
  if (btnConfirm) btnConfirm.disabled = true;

  try {
    const res = await fetch('/api/backups/restore', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filename }),
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || 'Error al restaurar respaldo');
    }

    pendingRestoreBackupFilename = null;
    closeModal('modalBackupPreview');
    showToast(data.message || 'Respaldo restaurado exitosamente.', 'success');

    if (data.restored_scope === 'config') {
      await loadConfig();
      if (typeof applyConfigToUi === 'function' && ownerConfig) {
        applyConfigToUi(ownerConfig);
      }
      if (typeof renderTemplatePreview === 'function') {
        renderTemplatePreview();
      }
    } else {
      await loadDashboard();
      await loadClients();
      await loadReleases();
      await loadReleaseMatrix();
      await loadFinances();
    }
    await loadBackups();
  } catch (e) {
    if (btnConfirm) btnConfirm.disabled = false;
    showToast('Error al restaurar: ' + e.message, 'error');
  }
}

function confirmPurgeSandboxBackups() {
  showConfirmModal(
    'Limpiar Snapshots Antiguos de Pruebas (Sandbox)',
    'Se conservarán los 10 snapshots automáticos de Sandbox más recientes y se preservará el 100% de PROD, GLOBAL y respaldos manuales o protegidos (vault/pre_restore). ¿Deseas continuar?',
    async () => {
      try {
        const res = await fetch('/api/backups/purge-sandbox', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ keep_recent: 10 }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Error al limpiar snapshots Sandbox');
        const kb = ((data.freed_bytes || 0) / 1024).toFixed(1);
        showToast(
          `Limpieza completada: ${data.deleted_count || 0} snapshots Sandbox eliminados (${kb} KB liberados). PROD/GLOBAL/Manuales intactos.`,
          'success'
        );
        await loadBackups();
      } catch (e) {
        showToast('Error al limpiar Sandbox: ' + e.message, 'error');
      }
    },
    true
  );
}
