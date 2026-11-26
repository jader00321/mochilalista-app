/**
 * Renderizado de Auditoría para Fichas de Sincronización Offline (CLIENT_SYNC)
 */
function renderInspectClientSync(data, rawToken, options = {}) {
  const container = document.getElementById('inspectResultContainer');
  const badge = document.getElementById('inspectStatusBadge');
  const mlc1AuditCard = document.getElementById('inspectMlc1AuditCard');
  const syncAuditCard = document.getElementById('inspectSyncAuditCard');
  const licenseClaimsWrapper = document.getElementById('inspectLicenseClaimsWrapper');
  const matchBox = document.getElementById('inspectMatchingClientBox');

  container.style.display = 'block';
  if (mlc1AuditCard) mlc1AuditCard.style.display = 'none';
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
    rescueCardHtml = renderMigrationRescueCard({
      migrationRescue: data.migration_rescue,
      matchedClient: data.matched_client,
      buttonId: 'btnInspectRescueMigrate',
      descriptionHtml: 'La app móvil reporta estado <code>PENDIENTE_MIGRACION</code>. Puedes reactivar el nuevo celular en 1 clic.',
      includeWrapper: true,
      marginBottom: '1rem',
    });
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
    showToast('Por favor pega un código ML9, token MLS1, ficha MLC1 o sube un archivo.', 'warning');
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

    // Enrutamiento TRI-PROTOCOLO: MLC1 -> CLIENT_SYNC (MLS1) -> LICENSE_TOKEN (ML9)
    if (data.token_kind === 'MLC1' || data.input_kind === 'COMMERCIAL_CONFIG') {
      renderInspectCommercialConfig(data, token, options);
      return;
    }

    if (data.input_kind === 'CLIENT_SYNC') {
      renderInspectClientSync(data, token, options);
      return;
    }

    const container = document.getElementById('inspectResultContainer');
    const badge = document.getElementById('inspectStatusBadge');
    const tbody = document.getElementById('inspectClaimsTableBody');
    const matchBox = document.getElementById('inspectMatchingClientBox');
    const mlc1AuditCard = document.getElementById('inspectMlc1AuditCard');
    const syncAuditCard = document.getElementById('inspectSyncAuditCard');
    const licenseClaimsWrapper = document.getElementById('inspectLicenseClaimsWrapper');

    container.style.display = 'block';
    if (mlc1AuditCard) mlc1AuditCard.style.display = 'none';
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
