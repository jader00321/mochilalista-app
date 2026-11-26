/**
 * Renderiza la tarjeta única de rescate por migración/restauración (DRY D-ADM-07).
 */
function renderMigrationRescueCard({
  migrationRescue,
  matchedClient = null,
  buttonId = 'btnRescueMigrate',
  descriptionHtml = 'La app móvil reporta estado <code>PENDIENTE_MIGRACION</code>. Puedes reactivar el nuevo celular en 1 clic.',
  includeWrapper = true,
  marginBottom = '1rem',
} = {}) {
  const mr = migrationRescue || {};
  const oldHw = escapeHtml(mr.old_hardware_id || '-');
  const newHw = escapeHtml(mr.new_hardware_id || '-');
  const modelStr = mr.device_model ? ` • ${escapeHtml(mr.device_model)}` : '';
  const clientName = matchedClient
    ? `${escapeHtml(matchedClient.business_name)} (${escapeHtml(matchedClient.owner_name)})`
    : 'Cliente Origen';
  const innerHtml = `
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
        ${descriptionHtml}
      </p>
    </div>
    <div style="display:flex; justify-content:flex-end;">
      <button type="button" class="btn btn-warning btn-sm" id="${escapeHtml(buttonId)}">
        <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
        Migrar Dispositivo (Restauración — 0 días)
      </button>
    </div>
  `;
  if (!includeWrapper) return innerHtml;
  const styleAttr = marginBottom ? ` style="margin-bottom:${escapeHtml(marginBottom)};"` : '';
  return `<div class="sync-migration-rescue-card"${styleAttr}>${innerHtml}</div>`;
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
