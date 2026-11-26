// ==========================================================================
// FASE 3 PLAN MAESTRO 10 & PLAN MAESTRO 23 FASE 5: BÓVEDA Y PORTABILIDAD (#tabSecurityVault)
// ==========================================================================

let loadedVaultJson = null;
let loadedVaultMetadata = null;
let currentRescueCodes = [];
let recoveryMlKeySecret = null;
let importMlKeySecret = null;
let currentVaultHealth = null;
let currentVaultAudit = null;

function formatVaultBytes(rawBytes) {
  if (rawBytes === null || rawBytes === undefined || Number.isNaN(Number(rawBytes))) {
    return '-';
  }
  const b = Number(rawBytes);
  if (b < 1024) return `${b} B`;
  if (b < 1024 * 1024) return `${(b / 1024).toFixed(1)} KB`;
  return `${(b / (1024 * 1024)).toFixed(2)} MB`;
}

function buildSafePublicKitId() {
  const now = new Date();
  const pad = n => String(n).padStart(2, '0');
  const stamp = `${now.getUTCFullYear()}${pad(now.getUTCMonth() + 1)}${pad(now.getUTCDate())}`;
  let hex = '0000';
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    const arr = new Uint8Array(2);
    crypto.getRandomValues(arr);
    hex = Array.from(arr).map(x => x.toString(16).padStart(2, '0')).join('').toUpperCase();
  } else {
    hex = Math.floor(0x1000 + Math.random() * 0xefff).toString(16).toUpperCase();
  }
  return `MLVAULT-${stamp}-${hex}`;
}

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
  let isLocked = false;
  try {
    // 1. Verificar si la sesión está bloqueada por PIN
    const pinRes = await fetch('/api/vault/pin/status');
    if (pinRes.ok) {
      const pinData = await pinRes.json();
      if (pinData.locked) {
        isLocked = true;
        showVaultPinLockOverlay();
      }
    }

    // 2. Verificar si hay auto-recuperación disponible desde %APPDATA% (solo si no está bloqueado)
    if (!isLocked) {
      const healthRes = await fetch('/api/vault/health');
      if (healthRes.ok) {
        const healthData = await healthRes.json();
        if (healthData.recovery_available) {
          openModal('modalAutoRecovery');
        }
      }
    }
  } catch (err) {
    console.error('Error al verificar estado inicial de Bóveda:', err);
  }
  return isLocked;
}

function initVaultEvents() {
  // 1. Cabecera: Auditoría Integral y Sincronización Manual de Espejo
  document.getElementById('btnRefreshVaultHealth')?.addEventListener('click', runVaultAudit);
  document.getElementById('btnForceSyncMirrorTop')?.addEventListener('click', syncMirrorManual);
  document.getElementById('btnSyncMirrorNow')?.addEventListener('click', syncMirrorManual);
  document.getElementById('btnVaultAuditSyncNow')?.addEventListener('click', async () => {
    closeModal('modalVaultAuditReport');
    await syncMirrorManual();
  });

  // 2. Copiar Rutas Físicas al Portapapeles
  document.getElementById('btnCopyLocalPath')?.addEventListener('click', () => {
    const val = document.getElementById('txtLocalPath')?.value?.trim();
    if (val) {
      copyPlainTextToClipboard(val, 'Ruta local copiada al portapapeles');
    }
  });

  document.getElementById('btnCopyMirrorPath')?.addEventListener('click', () => {
    const val = document.getElementById('txtMirrorPath')?.value?.trim();
    if (val) {
      copyPlainTextToClipboard(val, 'Ruta de bóveda espejo copiada al portapapeles');
    }
  });

  document.getElementById('btnCopyCloudPath')?.addEventListener('click', () => {
    const val = document.getElementById('pathCloudDir')?.textContent?.trim();
    if (!val || val === 'No configurada') {
      showToast('Aún no hay una carpeta de Nube Local configurada.', 'info');
      return;
    }
    copyPlainTextToClipboard(val, 'Ruta de nube local copiada al portapapeles');
  });

  // 3. Delegado para copiar huella SHA-256 completa desde la tabla de archivos
  document.getElementById('tbodyVaultFiles')?.addEventListener('click', e => {
    const copyBtn = e.target.closest('.btn-copy-vault-sha');
    if (!copyBtn) return;
    const sha = copyBtn.getAttribute('data-sha');
    if (sha) {
      copyPlainTextToClipboard(sha, `Huella SHA-256 copiada (${sha.substring(0, 12)}...)`);
    }
  });

  // 4. Selector y Guardado de Carpeta de Sincronización Cloud Secundaria
  document.getElementById('btnBrowseCloudSyncPath')?.addEventListener('click', browseCloudSyncPath);
  document.getElementById('btnSaveCloudSyncPath')?.addEventListener('click', saveCloudSyncPath);

  // 5. Descargar Llave Offline (.mlkey)
  document.getElementById('btnDownloadMlKey')?.addEventListener('click', downloadMlKey);

  // 6. Abrir Generador de Kit de Rescate
  document.getElementById('btnOpenRescueKitModal')?.addEventListener('click', openRescueKitModal);

  // 7. Imprimir Kit y Copiar Códigos de Rescate
  document.getElementById('btnEmergencyPrint')?.addEventListener('click', () => window.print());
  document.getElementById('btnCopyRescueCodes')?.addEventListener('click', () => {
    if (currentRescueCodes.length > 0) {
      copyPlainTextToClipboard(currentRescueCodes.join('\n'), '8 Códigos de Rescate copiados al portapapeles');
    }
  });

  // 8. Exportar Bóveda Portable (.mlvault)
  document.getElementById('btnExportVault')?.addEventListener('click', exportPortableVault);

  // 9. Abrir Modal de Importar Bóveda
  document.getElementById('btnOpenImportVaultModal')?.addEventListener('click', () => {
    resetImportVaultModal();
    openModal('modalImportVault');
  });

  // 10. Drag & Drop y Selección de Archivo .mlvault
  initVaultDropZoneEvents();

  // 11. Selector de Factores de Desbloqueo en Modal de Importación
  initImportFactorSelectorEvents();

  // 12. Confirmar Importación de Bóveda
  document.getElementById('btnSubmitImportVault')?.addEventListener('click', submitImportVault);

  // 13. Auto-Recuperación en 1 Clic
  document.getElementById('btnAutoRecoverNow')?.addEventListener('click', autoRecoverFromMirror);

  // 14. Configuración y Bloqueo por PIN
  initVaultPinEvents();
}

async function loadVaultHealth() {
  try {
    const [healthRes, pinRes] = await Promise.all([
      fetch('/api/vault/health'),
      fetch('/api/vault/pin/status'),
    ]);

    if (healthRes.status === 423 || pinRes.status === 423) {
      return null;
    }
    if (!healthRes.ok) throw new Error('No se pudo obtener el estado de salud de la bóveda');
    const health = await healthRes.json();
    const pinData = pinRes.ok ? await pinRes.json() : { pin_enabled: false };
    currentVaultHealth = health;

    // Rutas Físicas
    const txtLocal = document.getElementById('txtLocalPath');
    if (txtLocal) {
      txtLocal.value = health.primary_storage_path || 'data/';
      txtLocal.title = txtLocal.value;
    }
    const txtMirror = document.getElementById('txtMirrorPath');
    if (txtMirror) {
      txtMirror.value = health.mirror_storage_path || '%APPDATA%\\MochilaListaAdminVault';
      txtMirror.title = txtMirror.value;
    }
    const cloudPath = (health.cloud_sync_path || '').trim();
    const txtCloud = document.getElementById('inputCloudSyncPath');
    if (txtCloud) txtCloud.value = cloudPath;

    const pathCloudEl = document.getElementById('pathCloudDir');
    if (pathCloudEl) {
      pathCloudEl.textContent = cloudPath || 'No configurada';
      pathCloudEl.title = cloudPath || 'Sin carpeta de nube local configurada';
      pathCloudEl.style.color = cloudPath ? 'var(--text-primary)' : 'var(--text-muted)';
    }
    const btnCopyCloud = document.getElementById('btnCopyCloudPath');
    if (btnCopyCloud) {
      btnCopyCloud.disabled = !cloudPath;
    }

    // Cálculo unificado del Score de Blindaje (0% - 100%) sobre los 4 factores (25% c/u)
    const activeSlots = health.keyring_info?.active_slots || [];
    const factorDpapi = health.factors?.dpapi_enrolled ?? activeSlots.includes('dpapi');
    const factorKey = health.factors?.mlkey_enrolled ?? activeSlots.includes('mlkey');
    const factorRescue = health.factors?.rescue_kit_enrolled ?? activeSlots.includes('rescue_code');
    const factorPin = health.factors?.pin_enabled ?? !!pinData.pin_enabled;
    const activeCount = (factorDpapi ? 1 : 0) + (factorKey ? 1 : 0) + (factorRescue ? 1 : 0) + (factorPin ? 1 : 0);
    const score = typeof health.security_score === 'number' ? health.security_score : activeCount * 25;

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

    const mirrorReady = !!(health.mirror?.mirror_exists && health.mirror?.mlvault_exists);
    const cloudMirrorActive = !!(health.cloud_mirror_active || (health.cloud?.configured && health.cloud?.accessible));
    const secondarySummary = document.getElementById('vaultSecondaryMirrorSummary');
    if (secondarySummary) {
      const mirrorLabel = mirrorReady ? 'Sincronizado' : 'Pendiente';
      const cloudLabel = cloudMirrorActive
        ? 'Activa'
        : (cloudPath ? 'Ruta inaccesible' : 'No configurada');
      secondarySummary.textContent = `Espejo automático (%APPDATA%): ${mirrorLabel} · Nube Local: ${cloudLabel}`;
    }

    const recWarnEl = document.getElementById('vaultRecoveryWarning');
    if (recWarnEl) {
      recWarnEl.style.display = health.recovery_available ? 'flex' : 'none';
    }

    // Actualizar Insignias de los 4 Factores
    updateFactorBadge('factorMirrorStatus', factorDpapi ? 'Activo' : 'Inactivo', factorDpapi ? 'badge-green' : 'badge-red');
    updateFactorBadge('factorKeyStatus', factorKey ? 'Descargado' : 'Pendiente', factorKey ? 'badge-green' : 'badge-amber');
    updateFactorBadge('factorRescueStatus', factorRescue ? 'Generado' : 'Pendiente', factorRescue ? 'badge-green' : 'badge-amber');
    updateFactorBadge('factorPinStatus', factorPin ? 'Activado' : 'Opcional', factorPin ? 'badge-green' : 'badge-gray');

    // Sincronizar Badges y Fecha del Asistente en 3 Pasos
    if (mirrorReady && cloudMirrorActive) {
      updateFactorBadge('badgeStep1Status', 'Bóveda Espejo + Nube', 'badge-green');
    } else if (mirrorReady || health.mirror_exists) {
      updateFactorBadge('badgeStep1Status', 'Bóveda Espejo Activa', 'badge-success');
    } else {
      updateFactorBadge('badgeStep1Status', 'Sin Espejo', 'badge-amber');
    }

    const mirrorLastSyncEl = document.getElementById('mirrorLastSyncLabel');
    if (mirrorLastSyncEl) {
      const lastSyncIso = health.mirror?.last_sync;
      if (lastSyncIso) {
        mirrorLastSyncEl.textContent = `Última sinc: ${formatLimaDateTime(lastSyncIso, '-')}`;
        mirrorLastSyncEl.title = lastSyncIso;
      } else {
        mirrorLastSyncEl.textContent = 'Última sinc: Sin sincronizaciones previas';
        mirrorLastSyncEl.title = '';
      }
    }

    updateFactorBadge('badgeStep2Status', factorKey ? 'Llave Generada y Activa' : 'Pendiente', factorKey ? 'badge-success' : 'badge-amber');
    updateFactorBadge('badgeStep3Status', factorRescue ? '8 Códigos Activos' : 'Pendiente', factorRescue ? 'badge-success' : 'badge-amber');

    // Tabla de Archivos Físicos (6 columnas)
    renderVaultFilesTable(health.files, mirrorReady || !!health.mirror_exists);

    // Controles de PIN
    const chkPin = document.getElementById('chkEnablePin');
    if (chkPin) chkPin.checked = factorPin;
    const btnLock = document.getElementById('btnLockConsoleNow');
    if (btnLock) btnLock.style.display = factorPin ? 'inline-flex' : 'none';

    return health;
  } catch (err) {
    showToast(`Error al cargar estado de la bóveda: ${err.message}`, 'error');
    return null;
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
  if (!tbody) return '';
  tbody.innerHTML = '';

  const fileDefinitions = [
    {
      key: 'clients_db',
      name: 'Cartera de Clientes',
      path: 'data/prod_clients_db.json',
      purpose: 'Base comercial de clientes, hardware IDs y pagos',
    },
    {
      key: 'releases_db',
      name: 'Catálogo de Lanzamientos',
      path: 'data/prod_releases_db.json',
      purpose: 'Historial de versiones APK, hashes SHA-256 y notas',
    },
    {
      key: 'owner_config',
      name: 'Centro de Personalización',
      path: 'data/owner_config.json',
      purpose: 'Tarifario oficial, bolsas IA, plantillas WhatsApp y cuentas',
    },
    {
      key: 'master_key',
      name: 'Firma Digital Privada Ed25519',
      path: 'private_keys/ed25519_master.key',
      purpose: 'Clave asimétrica oficial para firmar licencias ML9 y fichas MLC1',
    },
    {
      key: 'vault_keyring',
      name: 'Llavero de Bóveda Multi-Slot',
      path: 'data/vault_keyring.json',
      purpose: 'Llavero AES-256-GCM con los 4 factores de desbloqueo',
    },
  ];

  const htmlRows = [];
  fileDefinitions.forEach(item => {
    const f = files ? files[item.key] : null;
    const exists = !!(f && f.exists);
    const purpose = f?.purpose || item.purpose;
    const sizeText = exists ? formatVaultBytes(f?.size_bytes ?? f?.bytes) : '-';
    const modifiedText = exists ? formatLimaDateTime(f?.modified, '-') : '-';
    const shaFull = f?.sha256 ? String(f.sha256) : '';
    const shaShort = shaFull ? `${shaFull.substring(0, 12)}...` : '-';

    const diskStatusHtml = exists
      ? '<span style="color:var(--success); font-weight:600; font-size:0.78rem; display:inline-flex; align-items:center; gap:0.3rem;"><svg width="8" height="8" viewBox="0 0 8 8" fill="currentColor"><circle cx="4" cy="4" r="4"/></svg>En Disco</span>'
      : '<span style="color:var(--danger); font-weight:600; font-size:0.78rem; display:inline-flex; align-items:center; gap:0.3rem;"><svg width="8" height="8" viewBox="0 0 8 8" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="4" cy="4" r="3"/></svg>Ausente</span>';

    const mirrorBadgeHtml = (mirrorExists && exists)
      ? '<span class="badge badge-green" style="font-size:0.72rem; margin-top:0.2rem; display:inline-flex; align-items:center; gap:0.25rem;"><svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>Espejo Sincronizado</span>'
      : '<span class="badge badge-amber" style="font-size:0.72rem; margin-top:0.2rem; display:inline-block;">Pendiente</span>';

    const shaCellHtml = shaFull
      ? `<div class="vault-sha-cell">
           <code style="font-family:var(--font-mono); font-size:0.74rem;" title="${escapeHtml(shaFull)}">${escapeHtml(shaShort)}</code>
           <button type="button" class="btn btn-outline btn-xs btn-copy-vault-sha" data-sha="${escapeHtml(shaFull)}" title="Copiar huella SHA-256 completa">
             <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
           </button>
         </div>`
      : '<span style="color:var(--text-muted);">-</span>';

    const rowHtml = `
      <td>
        <div style="font-weight:600; color:var(--text-primary);">${escapeHtml(item.name)}</div>
        <div style="font-family:var(--font-mono); font-size:0.74rem; color:var(--text-muted);">${escapeHtml(item.path)}</div>
      </td>
      <td style="font-size:0.78rem; color:var(--text-secondary); max-width:240px;">${escapeHtml(purpose)}</td>
      <td>
        <div>${diskStatusHtml}</div>
        <div>${mirrorBadgeHtml}</div>
      </td>
      <td style="font-family:var(--font-mono); font-size:0.78rem; white-space:nowrap;">${escapeHtml(sizeText)}</td>
      <td style="font-size:0.78rem; white-space:nowrap;" title="${escapeHtml(f?.modified || '')}">${escapeHtml(modifiedText)}</td>
      <td>${shaCellHtml}</td>
    `;

    htmlRows.push(`<tr>${rowHtml}</tr>`);
    const tr = document.createElement('tr');
    tr.innerHTML = rowHtml;
    tbody.appendChild(tr);
  });

  if (typeof applyTableDensity === 'function') {
    applyTableDensity(ownerConfig?.system?.table_density);
  }
  return htmlRows.join('');
}

async function runVaultAudit() {
  const btnAudit = document.getElementById('btnRefreshVaultHealth');
  btnAudit?.classList.add('is-spinning');
  if (btnAudit) btnAudit.disabled = true;

  try {
    const res = await fetch('/api/vault/audit');
    if (res.status === 423) return;
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }
    const audit = await res.json();
    currentVaultAudit = audit;
    renderVaultAuditModal(audit);
    openModal('modalVaultAuditReport');
    await loadVaultHealth();
  } catch (err) {
    showToast(`Error al ejecutar auditoría: ${err.message}`, 'error');
  } finally {
    btnAudit?.classList.remove('is-spinning');
    if (btnAudit) btnAudit.disabled = false;
  }
}
