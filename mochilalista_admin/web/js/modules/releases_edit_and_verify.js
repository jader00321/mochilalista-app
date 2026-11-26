let isVerifyAllCatalogRunning = false;

/**
 * Cierra el resumen visual de auditoría masiva de catálogo
 */
function dismissCatalogVerifyAllBanner() {
  const banner = document.getElementById('catalogVerifyAllBanner');
  if (!banner) return;
  banner.style.display = 'none';
  banner.className = 'catalog-verify-banner';
  banner.innerHTML = '';
}

function renderCatalogVerifyAllBanner(state, text, metaPills = [], dismissible = true) {
  const banner = document.getElementById('catalogVerifyAllBanner');
  if (!banner) return;

  let iconSvg = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>';
  if (state === 'running') {
    iconSvg = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-2.64-6.36"/><polyline points="21 3 21 9 15 9"/></svg>';
  } else if (state === 'warning' || state === 'error') {
    iconSvg = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>';
  }

  const pillsHtml = Array.isArray(metaPills) && metaPills.length > 0
    ? `<div class="catalog-verify-meta-pills">${metaPills.map((p) => `<span class="catalog-verify-pill">${escapeHtml(p)}</span>`).join('')}</div>`
    : '';
  const dismissHtml = dismissible
    ? '<button type="button" class="catalog-verify-dismiss" id="btnDismissVerifyAllBanner" title="Cerrar resumen" aria-label="Cerrar resumen"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>'
    : '';

  banner.className = `catalog-verify-banner is-${state}`;
  banner.style.display = 'flex';
  banner.innerHTML = `
    <div class="catalog-verify-banner-main">
      <span class="catalog-verify-banner-icon">${iconSvg}</span>
      <span class="catalog-verify-summary-text">${escapeHtml(text)}</span>
      ${pillsHtml}
    </div>
    ${dismissHtml}
  `;
}

/**
 * Audita físicamente y criptográficamente todas las versiones publicadas del catálogo (1 clic)
 */
async function verifyAllReleasesCatalog(force = false) {
  if (isVerifyAllCatalogRunning) return;
  const btn = document.getElementById('btnVerifyAllReleases');
  const originalHtml = btn ? btn.innerHTML : '';

  isVerifyAllCatalogRunning = true;
  if (btn) {
    btn.disabled = true;
    btn.classList.add('is-spinning');
    btn.innerHTML = '<svg class="btn-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-2.64-6.36"/><polyline points="21 3 21 9 15 9"/></svg><span>Verificando catálogo...</span>';
  }

  renderCatalogVerifyAllBanner(
    'running',
    'Auditando archivos físicos .apk y firmas RSA-4096 de todo el catálogo...',
    ['En curso'],
    false,
  );

  try {
    const query = force ? '?force=true' : '';
    const res = await fetch(`/api/releases/verify-all${query}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-App-Mode': currentMode,
      },
      body: JSON.stringify({ force: Boolean(force) }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.ok) {
      throw new Error(data.error || 'No se pudo completar la auditoría masiva del catálogo.');
    }

    if (Array.isArray(data.releases)) {
      globalReleases = data.releases;
    }

    await loadReleases();
    await loadReleaseMatrix();

    if (typeof currentDispatchRelease !== 'undefined' && currentDispatchRelease?.version_name) {
      const updatedDispatch = (globalReleases || []).find(
        (r) => r.version_name === currentDispatchRelease.version_name,
      );
      if (updatedDispatch) {
        currentDispatchRelease = updatedDispatch;
        const waOpen = document.getElementById('modalWaComposer')?.classList.contains('open');
        if (waOpen && typeof isApkDispatchMode !== 'undefined' && isApkDispatchMode && typeof syncWaApkDispatchPanel === 'function') {
          syncWaApkDispatchPanel(updatedDispatch, { preserveCopyHint: true });
        }
      }
    }

    const editModalOpen = document.getElementById('modalEditRelease')?.classList.contains('open');
    const editVer = document.getElementById('editRelVersionName')?.value;
    if (editModalOpen && editVer) {
      const updatedEdit = (globalReleases || []).find((r) => r.version_name === editVer);
      if (updatedEdit && typeof renderEditReleaseVariants === 'function') {
        renderEditReleaseVariants(updatedEdit);
      }
    }

    const total = Number(data.total || 0);
    const official = Number(data.official_count || 0);
    const unofficial = Number(data.unofficial_count || 0);
    const unverified = Number(data.unverified_count || 0);
    const missing = Number(data.missing_count || 0);
    const updated = Number(data.updated_count || 0);
    const durationMs = Number(data.duration_ms || 0);

    const verLabel = total === 1 ? '1 versión' : `${total} versiones`;
    const summaryText = total === 0
      ? 'Catálogo vacío: no hay versiones registradas en este entorno.'
      : `Catálogo auditado (${verLabel}): ${official} Oficiales RSA-4096 · ${unofficial} No Oficiales · ${unverified} Sin Verificar · ${missing} Extraviados en disco`;

    const hasWarnings = unofficial > 0 || unverified > 0 || missing > 0;
    const bannerState = hasWarnings ? 'warning' : 'success';
    renderCatalogVerifyAllBanner(
      bannerState,
      summaryText,
      [`${updated} actualizada(s)`, `${durationMs} ms`],
      true,
    );
    showToast(summaryText, hasWarnings ? 'warning' : 'success');
  } catch (e) {
    const errText = 'Error al verificar todo el catálogo: ' + (e.message || e);
    renderCatalogVerifyAllBanner('error', errText, [], true);
    showToast(errText, 'error');
  } finally {
    isVerifyAllCatalogRunning = false;
    if (btn) {
      btn.disabled = false;
      btn.classList.remove('is-spinning');
      btn.innerHTML = originalHtml;
    }
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
