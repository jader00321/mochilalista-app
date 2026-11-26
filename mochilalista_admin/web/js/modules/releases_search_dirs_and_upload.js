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
