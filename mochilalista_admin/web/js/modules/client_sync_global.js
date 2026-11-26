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
      rescueEl.innerHTML = renderMigrationRescueCard({
        migrationRescue: mr,
        matchedClient: data.matched_client,
        buttonId: 'btnGlobalSyncRescueMigrate',
        descriptionHtml: 'La app móvil reporta estado <code>PENDIENTE_MIGRACION</code>. Puedes reactivar el nuevo celular transfiriendo sus derechos comerciales con 0 días extra.',
        includeWrapper: true,
        marginBottom: '0',
      });

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

