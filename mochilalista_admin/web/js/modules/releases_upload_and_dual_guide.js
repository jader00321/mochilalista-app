/**
 * Inicializa los controladores de carga, drag & drop y autodetección de APK
 */
function initReleaseUploadAndAutoDetect() {
  const dropZone = document.getElementById('apkDropZone');
  const fileInput = document.getElementById('apkFileInput');
  const relTypeSelect = document.getElementById('relType');
  const editRelTypeSelect = document.getElementById('editRelType');
  const matrixSearchInput = document.getElementById('inputRelMatrixSearch');

  // Listeners reactivos de tipo de release
  relTypeSelect?.addEventListener('change', () => {
    updateReleaseTypeInfo('relType', 'relTypeInfoText');
  });

  editRelTypeSelect?.addEventListener('change', () => {
    updateReleaseTypeInfo('editRelType', 'editRelTypeInfoText');
  });

  // Búsqueda en vivo en matriz de distribución
  matrixSearchInput?.addEventListener('input', (e) => {
    currentMatrixSearch = e.target.value;
    renderReleaseMatrix();
  });

  // Delegación segura para corrección rápida de versión en matriz (sin window.prompt)
  document.getElementById('matrixTableBody')?.addEventListener('click', (e) => {
    const btn = e.target.closest('.btn-micro-edit-ver');
    if (!btn) return;
    const clientId = btn.dataset.fixClientId;
    if (clientId) openFixClientVersionModal(clientId);
  });

  document.getElementById('fixClientVersionSelect')?.addEventListener('change', (e) => {
    const val = e.target.value;
    const customInput = document.getElementById('fixClientVersionInput');
    if (!customInput) return;
    if (val === '__CUSTOM__') {
      customInput.focus();
      customInput.select();
    } else {
      customInput.value = val;
    }
  });

  document.getElementById('btnSubmitFixClientVersion')?.addEventListener('click', async () => {
    const clientId = document.getElementById('fixClientVersionId')?.value;
    const rawVer = document.getElementById('fixClientVersionInput')?.value?.trim() || '';
    const cleanVer = rawVer.replace(/^[vV]/, '');
    if (!clientId || !cleanVer) {
      showToast('Ingresa una versión SemVer válida (ej: 9.38.0).', 'warning');
      return;
    }
    closeModal('modalFixClientVersion');
    await markClientUpdated(clientId, cleanVer, { force: true, silentUndo: false });
  });

  // Delegación en tarjetas de variantes de #modalEditRelease
  document.getElementById('editRelVariantsContainer')?.addEventListener('click', (e) => {
    const copyBtn = e.target.closest('.btn-copy-variant-sha');
    if (copyBtn) {
      copyPlainTextToClipboard(copyBtn.dataset.sha, 'Hash SHA-256 copiado al portapapeles.');
      return;
    }

    const togglePickerBtn = e.target.closest('.btn-toggle-local-picker');
    if (togglePickerBtn) {
      toggleEditVariantLocalPicker(togglePickerBtn.dataset.variant, togglePickerBtn.dataset.version);
      return;
    }

    const rescanBtn = e.target.closest('.btn-rescan-edit-local');
    if (rescanBtn) {
      loadEditVariantLocalBuilds(rescanBtn.dataset.variant, rescanBtn.dataset.version);
      return;
    }

    const openDirsBtn = e.target.closest('.btn-open-edit-search-dirs');
    if (openDirsBtn) {
      openEditSearchDirsPanel();
      return;
    }

    const closePickerBtn = e.target.closest('.btn-close-edit-local-picker');
    if (closePickerBtn) {
      closeEditVariantLocalPicker(closePickerBtn.dataset.variant);
      return;
    }

    const linkLocalBtn = e.target.closest('.btn-link-local-build');
    if (linkLocalBtn) {
      linkLocalBuildToReleaseVariant(linkLocalBtn.dataset.version, linkLocalBtn.dataset.variant);
      return;
    }

    const unlinkBtn = e.target.closest('.btn-unlink-variant');
    if (unlinkBtn) {
      unlinkReleaseVariant(unlinkBtn.dataset.version, unlinkBtn.dataset.variant);
    }
  });

  // Botones de recarga rápida de notas compañeras (*_cambios.txt y *_atp.txt)
  document.getElementById('btnCreateLoadCambiosTxt')?.addEventListener('click', () => {
    const ver = document.getElementById('relVersionName')?.value || '';
    loadCompanionNoteIntoField(ver, 'relChangelog', 'changelog', lastInspectedCreateData);
  });

  document.getElementById('btnCreateLoadAtpTxt')?.addEventListener('click', () => {
    const ver = document.getElementById('relVersionName')?.value || '';
    loadCompanionNoteIntoField(ver, 'relInternalNotes', 'internal_notes', lastInspectedCreateData);
  });

  document.getElementById('btnEditLoadCambiosTxt')?.addEventListener('click', () => {
    const ver = document.getElementById('editRelVersionName')?.value || '';
    loadCompanionNoteIntoField(ver, 'editRelChangelog', 'changelog');
  });

  document.getElementById('btnEditLoadAtpTxt')?.addEventListener('click', () => {
    const ver = document.getElementById('editRelVersionName')?.value || '';
    loadCompanionNoteIntoField(ver, 'editRelInternalNotes', 'internal_notes');
  });

  // Delegación para botón "Cambiar / Quitar APK" dentro de #activeCreateApkCard
  document.getElementById('activeCreateApkCard')?.addEventListener('click', (e) => {
    const clearBtn = e.target.closest('#btnClearSelectedCreateApk');
    if (clearBtn) {
      clearSelectedCreateApk();
    }
  });

  // Drag & drop handlers
  dropZone?.addEventListener('click', () => fileInput?.click());

  dropZone?.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('dragover');
  });

  dropZone?.addEventListener('dragleave', () => {
    dropZone.classList.remove('dragover');
  });

  dropZone?.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('dragover');
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleApkUpload(e.dataTransfer.files[0]);
    }
  });

  fileInput?.addEventListener('change', () => {
    if (fileInput.files && fileInput.files.length > 0) {
      handleApkUpload(fileInput.files[0]);
    }
  });

  // Delegación segura para importar APKs locales sin interpolar barras Windows en onclick
  const buildsGridEl = document.getElementById('localBuildsGrid');
  buildsGridEl?.addEventListener('click', (e) => {
    const btn = e.target.closest('.btn-import-local-build');
    if (!btn) return;
    const idx = parseInt(btn.dataset.buildIndex || '-1', 10);
    const sourcePath = btn.dataset.sourcePath || availableLocalBuilds[idx]?.file_path;
    if (sourcePath) {
      importLocalApkDirectly(sourcePath, idx, btn);
    }
  });

  // Barra de filtros rápidos en #localBuildsToolbar
  document.getElementById('localBuildsAbiChips')?.addEventListener('click', (e) => {
    const chip = e.target.closest('.local-abi-chip');
    if (!chip) return;
    const abi = chip.dataset.abi || 'ALL';
    localBuildsFilterState.abi = abi;
    document.querySelectorAll('#localBuildsAbiChips .local-abi-chip').forEach((c) => {
      c.classList.toggle('active', c === chip);
    });
    fetchAndRenderLocalBuilds({ silentToast: true });
  });

  document.getElementById('inputLocalBuildsFilter')?.addEventListener('input', (e) => {
    localBuildsFilterState.query = e.target.value || '';
    clearTimeout(localBuildsFilterTimer);
    localBuildsFilterTimer = setTimeout(() => {
      fetchAndRenderLocalBuilds({ silentToast: true });
    }, 220);
  });

  document.getElementById('selectLocalBuildsLimit')?.addEventListener('change', (e) => {
    localBuildsFilterState.limit = parseInt(e.target.value || '6', 10) || 6;
    fetchAndRenderLocalBuilds({ silentToast: true });
  });

  // Mini-panel colapsable "Rutas de búsqueda"
  document.getElementById('btnToggleSearchDirsPanel')?.addEventListener('click', async () => {
    const panel = document.getElementById('createSearchDirsPanel');
    const toggleBtn = document.getElementById('btnToggleSearchDirsPanel');
    if (!panel) return;
    const willOpen = panel.style.display === 'none' || !panel.style.display;
    panel.style.display = willOpen ? 'flex' : 'none';
    toggleBtn?.classList.toggle('active', willOpen);
    if (willOpen) {
      await loadCreateSearchDirs();
    }
  });

  document.getElementById('btnBrowseApkSearchDir')?.addEventListener('click', browseAndFillNewSearchDir);
  document.getElementById('btnAddApkSearchDir')?.addEventListener('click', addCreateSearchDir);
  document.getElementById('btnResetApkSearchDirs')?.addEventListener('click', resetCreateSearchDirs);
  document.getElementById('inputNewApkSearchDir')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addCreateSearchDir();
    }
  });

  function bindSearchDirsListDelegation(listId, context) {
    const listEl = document.getElementById(listId);
    if (!listEl) return;
    listEl.addEventListener('change', async (e) => {
      const chk = e.target.closest('.chk-toggle-search-dir');
      if (!chk) return;
      const idx = parseInt(chk.dataset.dirIndex || '-1', 10);
      if (idx < 0 || idx >= createApkSearchDirs.length) return;
      const next = createApkSearchDirs.map((d, i) => (
        i === idx ? { ...d, enabled: chk.checked } : { ...d }
      ));
      await saveSearchDirsForContext(next, context);
    });

    listEl.addEventListener('click', async (e) => {
      const delBtn = e.target.closest('.btn-remove-search-dir');
      if (!delBtn) return;
      const idx = parseInt(delBtn.dataset.dirIndex || '-1', 10);
      if (idx < 0 || idx >= createApkSearchDirs.length) return;
      const target = createApkSearchDirs[idx];
      if (target?.is_default) return;
      const next = createApkSearchDirs.filter((_, i) => i !== idx);
      await saveSearchDirsForContext(next, context);
    });
  }

  bindSearchDirsListDelegation('createSearchDirsList', 'create');
  bindSearchDirsListDelegation('editSearchDirsList', 'edit');

  document.getElementById('btnCloseEditSearchDirsPanel')?.addEventListener('click', () => {
    const panel = document.getElementById('editSearchDirsPanel');
    if (panel) panel.style.display = 'none';
  });
  document.getElementById('btnEditBrowseApkSearchDir')?.addEventListener('click', () => browseAndFillSearchDirInput('edit'));
  document.getElementById('btnEditAddApkSearchDir')?.addEventListener('click', () => addSearchDirForContext('edit'));
  document.getElementById('btnEditResetApkSearchDirs')?.addEventListener('click', () => resetSearchDirsForContext('edit'));
  document.getElementById('inputEditNewApkSearchDir')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addSearchDirForContext('edit');
    }
  });

  // Controles Expandir/Contraer y contadores en vivo para los 4 textareas (Plan 22.5 Fase 3)
  document.querySelectorAll('.btn-toggle-textarea').forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset?.target || btn.getAttribute?.('data-target') || '';
      if (targetId) toggleExpandableTextarea(targetId);
    });
  });
  EXPANDABLE_TEXTAREA_IDS.forEach((textareaId) => {
    const ta = document.getElementById(textareaId);
    if (ta) {
      ta.addEventListener('input', () => updateTextareaMetaCounter(textareaId));
      updateTextareaMetaCounter(textareaId);
    }
  });

  // Autodetectar builds locales desde rutas configurables
  document.getElementById('btnDetectLocalBuild')?.addEventListener('click', async () => {
    await fetchAndRenderLocalBuilds({ silentToast: false });
  });

  // Verificación masiva de catálogo en 1 clic (Plan 23 Fase 6)
  document.getElementById('btnVerifyAllReleases')?.addEventListener('click', () => {
    verifyAllReleasesCatalog(false);
  });
  document.getElementById('catalogVerifyAllBanner')?.addEventListener('click', (e) => {
    if (e.target.closest('#btnDismissVerifyAllBanner')) {
      dismissCatalogVerifyAllBanner();
    }
  });

  initDualBuildGuide();
}

// =================== MINI-GUÍA RÁPIDA DE COMPILACIÓN DUAL (PLAN 23.5 - FASE 4) ===================
function toggleDualBuildGuide(forceOpen) {
  const panel = document.getElementById('dualBuildGuidePanel');
  const btn = document.getElementById('btnToggleDualBuildGuide');
  if (!panel) return false;
  const currentlyOpen = panel.style.display !== 'none' && panel.style.display !== '';
  const nextOpen = typeof forceOpen === 'boolean' ? forceOpen : !currentlyOpen;
  panel.style.display = nextOpen ? 'block' : 'none';
  if (btn) {
    btn.setAttribute('aria-expanded', nextOpen ? 'true' : 'false');
    btn.classList?.toggle('active', nextOpen);
  }
  return nextOpen;
}

async function copyDualBuildCommand(cmd, btn) {
  const commandText = String(cmd || '').trim();
  if (!commandText) {
    if (typeof showToast === 'function') {
      showToast('No hay comando disponible para copiar.', 'warning');
    }
    return false;
  }

  const copied = await copyPlainTextToClipboard(commandText, '', {
    suppressSuccessToast: true,
  });
  if (!copied) {
    return false;
  }

  if (btn) {
    btn.classList?.add('is-copied');
    const labelEl = btn.querySelector ? btn.querySelector('[data-copy-label]') : null;
    const prevLabel = labelEl ? labelEl.textContent : null;
    if (labelEl) {
      labelEl.textContent = 'Copiado';
    }
    const resetTimer = setTimeout(() => {
      btn.classList?.remove('is-copied');
      if (labelEl && prevLabel) {
        labelEl.textContent = prevLabel;
      }
    }, 1800);
    if (resetTimer && typeof resetTimer.unref === 'function') {
      resetTimer.unref();
    }
  }

  if (typeof showToast === 'function') {
    showToast(`Comando copiado: ${commandText}`, 'success');
  }
  return copied;
}

function initDualBuildGuide() {
  const toggleBtn = document.getElementById('btnToggleDualBuildGuide');
  if (toggleBtn && (!toggleBtn.dataset || !toggleBtn.dataset.boundDualGuide)) {
    if (toggleBtn.dataset) toggleBtn.dataset.boundDualGuide = '1';
    toggleBtn.addEventListener('click', () => {
      toggleDualBuildGuide();
    });
  }

  if (typeof document.querySelectorAll === 'function') {
    const copyBtns = document.querySelectorAll('.btn-copy-dual-cmd');
    copyBtns.forEach(btn => {
      if (btn.dataset && btn.dataset.boundDualCopy) return;
      if (btn.dataset) btn.dataset.boundDualCopy = '1';
      btn.addEventListener('click', () => {
        const rawCmd = (btn.dataset && btn.dataset.cmd) || (btn.getAttribute && btn.getAttribute('data-cmd')) || '';
        copyDualBuildCommand(rawCmd, btn);
      });
    });
  }
}

const EXPANDABLE_TEXTAREA_IDS = [
  'relChangelog',
  'relInternalNotes',
  'editRelChangelog',
  'editRelInternalNotes',
];

function computeTextareaStats(value) {
  const raw = String(value ?? '');
  if (raw.length === 0) return { lines: 0, chars: 0 };
  const lines = raw.replace(/\r\n/g, '\n').split('\n').length;
  return { lines, chars: raw.length };
}

function updateTextareaMetaCounter(textareaId) {
  const ta = document.getElementById(textareaId);
  const counter = document.getElementById(`${textareaId}Counter`);
  if (!counter) return;
  const stats = computeTextareaStats(ta ? ta.value : '');
  counter.textContent = `${stats.lines} lín. · ${stats.chars} car.`;
}

function setExpandableTextareaState(textareaId, expanded) {
  const ta = document.getElementById(textareaId);
  const btn = document.querySelector(`.btn-toggle-textarea[data-target="${textareaId}"]`);
  const isExpanded = Boolean(expanded);

  if (ta) {
    ta.classList.toggle('is-expanded', isExpanded);
    if (!isExpanded) {
      ta.style.height = '';
    }
  }
  if (btn) {
    btn.setAttribute('aria-expanded', isExpanded ? 'true' : 'false');
    btn.title = isExpanded
      ? 'Contraer área de texto'
      : 'Expandir área de texto';
    const labelEl = btn.querySelector('.btn-toggle-textarea-label');
    if (labelEl) {
      labelEl.textContent = isExpanded ? 'Contraer' : 'Expandir';
    }
    const svg = btn.querySelector('svg');
    if (svg) {
      svg.innerHTML = isExpanded
        ? '<polyline points="4 14 10 14 10 20"/><polyline points="20 10 14 10 14 4"/><line x1="14" y1="10" x2="21" y2="3"/><line x1="3" y1="21" x2="10" y2="14"/>'
        : '<polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/>';
    }
  }
  updateTextareaMetaCounter(textareaId);
}

function toggleExpandableTextarea(textareaId) {
  const ta = document.getElementById(textareaId);
  if (!ta) return false;
  const nextExpanded = !ta.classList.contains('is-expanded');
  setExpandableTextareaState(textareaId, nextExpanded);
  return nextExpanded;
}

function resetExpandableTextarea(textareaId, options = {}) {
  const ta = document.getElementById(textareaId);
  if (ta && options.clearValue === true) {
    ta.value = '';
  }
  setExpandableTextareaState(textareaId, false);
}

function resetAllModalExpandableTextareas(ids = EXPANDABLE_TEXTAREA_IDS, options = {}) {
  ids.forEach((id) => resetExpandableTextarea(id, options));
}

function normalizePathForCompare(rawPath) {
  return String(rawPath || '').trim().replace(/\\/g, '/').toLowerCase();
}

function resetDropZoneDefaultState() {
  const dropZone = document.getElementById('apkDropZone');
  const fileInput = document.getElementById('apkFileInput');
  const iconEl = document.getElementById('apkDropZoneIcon');
  const titleEl = document.getElementById('apkDropZoneTitle');
  const subEl = document.getElementById('apkDropZoneSubtitle');
  const progressContainer = document.getElementById('apkUploadProgress');
  const progressBar = document.getElementById('apkProgressBar');
  const progressText = document.getElementById('apkUploadStatusText');

  if (fileInput) fileInput.value = '';
  if (dropZone) {
    dropZone.classList.remove('dragover', 'has-manual-apk');
  }
  if (iconEl) {
    iconEl.innerHTML = '<svg width="38" height="38" style="width:38px; height:38px; color:var(--primary);" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>';
  }
  if (titleEl) {
    titleEl.textContent = 'Arrastra tu archivo .APK aquí o haz clic para seleccionarlo';
  }
  if (subEl) {
    subEl.textContent = 'Compatible con APK Universal (~110 MB) y APK Ligero ARM64 (~30 MB)';
  }
  if (progressContainer) progressContainer.style.display = 'none';
  if (progressBar) progressBar.style.width = '0%';
  if (progressText) progressText.textContent = 'Procesando archivo e inspeccionando metadatos...';
}

function setDropZoneManualLoadedState(fileName, sizeLabel) {
  const dropZone = document.getElementById('apkDropZone');
  const iconEl = document.getElementById('apkDropZoneIcon');
  const titleEl = document.getElementById('apkDropZoneTitle');
  const subEl = document.getElementById('apkDropZoneSubtitle');

  if (dropZone) {
    dropZone.classList.remove('dragover');
    dropZone.classList.add('has-manual-apk');
  }
  if (iconEl) {
    iconEl.innerHTML = '<svg width="38" height="38" style="width:38px; height:38px; color:#0ea5e9;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>';
  }
  if (titleEl) {
    titleEl.textContent = `Archivo manual listo: ${fileName || 'archivo.apk'}`;
  }
  if (subEl) {
    const cleanSize = sizeLabel && sizeLabel !== '-' ? `${sizeLabel} · ` : '';
    subEl.textContent = `${cleanSize}Verificado e inspeccionado — Haz clic o arrastra otro .APK para reemplazarlo`;
  }
}
