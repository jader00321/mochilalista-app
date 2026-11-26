function renderVaultAuditModal(audit) {
  if (!audit) return;

  const scoreBadge = document.getElementById('vaultAuditScoreBadge');
  if (scoreBadge) {
    const score = audit.security_score ?? 0;
    const count = audit.active_factors_count ?? 0;
    scoreBadge.textContent = `${score}% · ${count}/4 Factores`;
    scoreBadge.className = score >= 75 ? 'badge badge-green' : (score >= 50 ? 'badge badge-amber' : 'badge badge-red');
  }

  const tsEl = document.getElementById('vaultAuditTimestamp');
  if (tsEl) {
    tsEl.textContent = `Auditado: ${formatLimaDateTime(audit.audited_at, audit.audited_at_lima || '-')}`;
  }

  const dpapiEl = document.getElementById('vaultAuditDpapiStatus');
  if (dpapiEl) {
    const ok = !!audit.dpapi?.valid;
    dpapiEl.textContent = ok ? 'DPAPI Verificado' : 'DPAPI Con Alertas';
    dpapiEl.style.color = ok ? 'var(--success)' : 'var(--danger)';
  }

  const keyringEl = document.getElementById('vaultAuditKeyringStatus');
  if (keyringEl) {
    const slots = (audit.keyring?.active_slots || []).join(', ') || 'ninguno';
    keyringEl.textContent = `Llavero ${audit.keyring?.version || '-'} (${slots})`;
  }

  const mirrorEl = document.getElementById('vaultAuditMirrorStatus');
  if (mirrorEl) {
    const allMatch = !!audit.mirror?.all_files_matched;
    const matched = audit.matched_files_count ?? 0;
    const total = audit.total_critical_files ?? 5;
    mirrorEl.textContent = allMatch ? `Íntegro (${matched}/${total} SHA-256)` : `Parcial (${matched}/${total} SHA-256)`;
    mirrorEl.style.color = allMatch ? 'var(--success)' : 'var(--warning)';
  }

  const mirrorTimeEl = document.getElementById('vaultAuditMirrorTime');
  if (mirrorTimeEl) {
    mirrorTimeEl.textContent = audit.mirror?.last_sync
      ? formatLimaDateTime(audit.mirror.last_sync, '-')
      : 'Sin sincronizaciones previas';
  }

  const cloudEl = document.getElementById('vaultAuditCloudStatus');
  if (cloudEl) {
    if (!audit.cloud?.configured) {
      cloudEl.textContent = 'No configurada (Opcional)';
      cloudEl.style.color = 'var(--text-muted)';
    } else if (audit.cloud?.accessible && audit.cloud?.mlvault_exists) {
      cloudEl.textContent = 'Nube Activa y Sincronizada';
      cloudEl.style.color = 'var(--success)';
    } else {
      cloudEl.textContent = 'Nube Con Alertas';
      cloudEl.style.color = 'var(--warning)';
    }
  }

  const cloudPathEl = document.getElementById('vaultAuditCloudPath');
  if (cloudPathEl) {
    cloudPathEl.textContent = audit.cloud?.cloud_path || 'Configura en Paso 1';
    cloudPathEl.title = audit.cloud?.cloud_path || '';
  }

  const tbody = document.getElementById('tbodyVaultAuditFiles');
  if (tbody) {
    tbody.innerHTML = '';
    const filesMap = audit.files || {};
    const orderedKeys = ['clients_db', 'releases_db', 'owner_config', 'master_key', 'vault_keyring'];
    orderedKeys.forEach(k => {
      const f = filesMap[k];
      if (!f) return;
      const parityOk = !!f.mirror_parity;
      const localSha = f.sha256 ? `${f.sha256.substring(0, 10)}...` : '-';
      const mirrorSha = f.mirror_sha256 ? `${f.mirror_sha256.substring(0, 10)}...` : '-';
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>
          <div style="font-weight:600;">${escapeHtml(f.label || k)}</div>
          <div style="font-family:var(--font-mono); font-size:0.72rem; color:var(--text-muted);">${escapeHtml(f.relative_path || '')}</div>
        </td>
        <td style="font-family:var(--font-mono); white-space:nowrap;">${f.exists ? escapeHtml(formatVaultBytes(f.size_bytes)) : '-'}</td>
        <td style="white-space:nowrap;">${f.exists ? escapeHtml(formatLimaDateTime(f.modified, '-')) : '-'}</td>
        <td style="font-family:var(--font-mono); font-size:0.72rem;">
          <div>Local: <span title="${escapeHtml(f.sha256 || '')}">${escapeHtml(localSha)}</span></div>
          <div>Espejo: <span title="${escapeHtml(f.mirror_sha256 || '')}">${escapeHtml(mirrorSha)}</span></div>
        </td>
        <td>
          <span class="badge ${parityOk ? 'badge-green' : 'badge-amber'}">${parityOk ? 'Paridad OK' : escapeHtml(f.parity_status || 'Revisar')}</span>
        </td>
      `;
      tbody.appendChild(tr);
    });
  }

  const recList = document.getElementById('vaultAuditRecommendations');
  if (recList) {
    recList.innerHTML = '';
    const recs = Array.isArray(audit.recommendations) ? audit.recommendations : [];
    if (recs.length === 0) {
      const li = document.createElement('li');
      li.style.color = 'var(--success)';
      li.textContent = 'Todas las verificaciones criptográficas y espejos físicos están al 100% sin observaciones.';
      recList.appendChild(li);
    } else {
      recs.forEach(text => {
        const li = document.createElement('li');
        li.textContent = text;
        recList.appendChild(li);
      });
    }
  }
}

async function syncMirrorManual() {
  const topBtn = document.getElementById('btnForceSyncMirrorTop');
  const stepBtn = document.getElementById('btnSyncMirrorNow');
  topBtn?.classList.add('is-spinning');
  if (topBtn) topBtn.disabled = true;
  if (stepBtn) stepBtn.disabled = true;

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
  } finally {
    topBtn?.classList.remove('is-spinning');
    if (topBtn) topBtn.disabled = false;
    if (stepBtn) stepBtn.disabled = false;
  }
}

async function browseCloudSyncPath() {
  const input = document.getElementById('inputCloudSyncPath');
  const btn = document.getElementById('btnBrowseCloudSyncPath');
  if (btn) btn.disabled = true;

  try {
    const initialPath = input ? input.value.trim() : '';
    const res = await fetch('/api/vault/cloud-path/browse', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ initial_path: initialPath || null }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(data.error || `Error HTTP ${res.status}`);
    }
    if (data.cancelled || !data.path) {
      return;
    }
    if (input) {
      input.value = data.path;
    }
    await saveCloudSyncPath();
  } catch (err) {
    showToast(`Error al seleccionar carpeta de nube: ${err.message}`, 'error');
  } finally {
    if (btn) btn.disabled = false;
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

async function executeDownloadMlKey() {
  try {
    showToast('Generando y descargando llave offline (.mlkey)...', 'info');
    const res = await fetch('/api/vault/download-mlkey');
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }
    const data = await res.json();
    const filename = data.filename || 'llave_maestra_mochilalista.mlkey';
    const blob = new Blob([data.mlkey_json], { type: 'application/json;charset=utf-8' });
    const downloadUrl = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = downloadUrl;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => window.URL.revokeObjectURL(downloadUrl), 1500);

    showToast(`Llave offline descargada: ${filename}`, 'success');
    await loadVaultHealth();
  } catch (err) {
    showToast(`Error al descargar .mlkey: ${err.message}`, 'error');
  }
}

async function downloadMlKey() {
  const activeSlots = currentVaultHealth?.keyring_info?.active_slots || [];
  const alreadyEnrolled = !!(currentVaultHealth?.factors?.mlkey_enrolled || activeSlots.includes('mlkey'));
  if (alreadyEnrolled) {
    showConfirmModal(
      'Regenerar Archivo Llave (.mlkey)',
      'Ya existe una llave .mlkey activa en tu llavero. Generar una nueva invalidará permanentemente la llave .mlkey anterior guardada en USB o respaldos externos. ¿Deseas reemplazarla y descargar la nueva?',
      () => executeDownloadMlKey(),
      true
    );
    return;
  }
  await executeDownloadMlKey();
}

async function executeGenerateRescueKit() {
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

    // Fechas y metadatos públicos (jamás exponer prefijos de qr_key)
    const dateEl = document.getElementById('kitGeneratedDate');
    if (dateEl) dateEl.textContent = formatLimaDateTime(new Date().toISOString(), '-');
    const vaultIdEl = document.getElementById('kitVaultId');
    if (vaultIdEl) {
      vaultIdEl.textContent = buildSafePublicKitId();
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

async function openRescueKitModal() {
  const activeSlots = currentVaultHealth?.keyring_info?.active_slots || [];
  const alreadyEnrolled = !!(currentVaultHealth?.factors?.rescue_kit_enrolled || activeSlots.includes('rescue_code'));
  if (alreadyEnrolled) {
    showConfirmModal(
      'Regenerar Kit de Rescate (8 Códigos + QR)',
      'Ya tienes un Kit de Rescate activo. Generar un nuevo kit invalidará permanentemente los 8 códigos y el código QR de cualquier hoja impresa anterior. ¿Deseas reemplazarlos?',
      () => executeGenerateRescueKit(),
      true
    );
    return;
  }
  await executeGenerateRescueKit();
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
    const blob = new Blob([data.vault_json], { type: 'application/json;charset=utf-8' });
    const downloadUrl = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = downloadUrl;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => window.URL.revokeObjectURL(downloadUrl), 1500);

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

function applyVaultInspectMetadataToDom(meta) {
  if (!meta) return;
  const summary = document.getElementById('vaultInspectSummary');
  if (summary) summary.style.display = 'block';

  const clientsCount = meta.stats?.clients_count ?? meta.total_clients ?? 0;
  const releasesCount = meta.stats?.releases_count ?? 0;

  const vVer = document.getElementById('metaVaultVersion');
  if (vVer) vVer.textContent = meta.version || meta.vault_version || '1.0';
  const vDate = document.getElementById('metaVaultCreated');
  if (vDate) vDate.textContent = meta.created_at ? formatLimaDateTime(meta.created_at, '-') : '-';
  const vClients = document.getElementById('metaVaultClients');
  if (vClients) vClients.textContent = `${clientsCount} clientes · ${releasesCount} lanzamientos`;
  const vKey = document.getElementById('metaVaultHasKey');
  if (vKey) {
    if (meta.has_master_key || meta.includes_private_key) {
      vKey.innerHTML = '<span style="display:inline-flex; align-items:center; gap:0.25rem; color:var(--success); font-weight:600;"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> Incluida</span>';
    } else {
      vKey.textContent = 'No incluida';
    }
  }
  const vSlots = document.getElementById('metaVaultSlots');
  if (vSlots) vSlots.textContent = (meta.available_slots || []).join(', ');
  return { clientsCount, releasesCount };
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
    applyVaultInspectMetadataToDom(loadedVaultMetadata);

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
