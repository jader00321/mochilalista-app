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
