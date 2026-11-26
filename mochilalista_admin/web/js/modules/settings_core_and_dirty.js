// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL (FASE 4B + PLAN 23 FASE 2) ===================

const SETTINGS_SUBTAB_META = {
  stabPricing: { scope: 'pricing', label: '1. Tarifario & Bolsas IA' },
  stabTemplates: { scope: 'templates', label: '2. Plantillas WhatsApp & Chat en Vivo' },
  stabPayment: { scope: 'payment', label: '3. Medios de Pago & Legal (Perú)' },
  stabPreferences: { scope: 'preferences', label: '4. Preferencias del Sistema' },
};

const SETTINGS_TEMPLATE_KEYS = [
  'license_issued',
  'expiring_reminder',
  'trial_welcome',
  'prospect',
  'ai_bonus',
  'courtesy_extension',
  'apk_update_eligible',
  'apk_update_quote',
  'device_migration',
];

let settingsDraftTemplates = {};
let activeSettingsTemplateKey = 'license_issued';
let savedSettingsSnapshot = null;
let pendingSettingsExitAction = null;
let hasAppliedInitialConfigTheme = false;

function getActiveSettingsSubTabId() {
  return document.querySelector('.settings-tab-btn.active')?.dataset?.stab || 'stabPricing';
}

function getActiveSettingsSubTabScope() {
  return SETTINGS_SUBTAB_META[getActiveSettingsSubTabId()]?.scope || 'pricing';
}

function resolveCanonicalTemplateFromMap(templatesMap, key) {
  const map = templatesMap || {};
  if (map[key] !== undefined && map[key] !== null) return String(map[key]);
  const waAlias = typeof resolveWaTemplateKeyFromConfig === 'function'
    ? resolveWaTemplateKeyFromConfig(key)
    : key;
  if (waAlias !== key && map[waAlias] !== undefined && map[waAlias] !== null) {
    return String(map[waAlias]);
  }
  return '';
}

function syncDraftTemplatesFromConfig(cfg) {
  const src = cfg?.templates || {};
  const next = {};
  SETTINGS_TEMPLATE_KEYS.forEach(k => {
    const val = resolveCanonicalTemplateFromMap(src, k);
    if (val !== '') {
      next[k] = val;
    } else if (typeof WA_TEMPLATES !== 'undefined') {
      const waKey = typeof resolveWaTemplateKeyFromConfig === 'function'
        ? resolveWaTemplateKeyFromConfig(k)
        : k;
      next[k] = WA_TEMPLATES[waKey]?.text || '';
    } else {
      next[k] = '';
    }
  });
  Object.keys(src).forEach(k => {
    const canon = typeof resolveConfigTemplateKeyFromWa === 'function'
      ? resolveConfigTemplateKeyFromWa(k)
      : k;
    if (!(canon in next) && src[k] !== undefined && src[k] !== null) {
      next[canon] = String(src[k]);
    }
  });
  settingsDraftTemplates = next;
}

function syncTemplateDraftFromSavedConfig(canonKey, newText) {
  if (!canonKey) return;
  settingsDraftTemplates[canonKey] = String(newText || '');
  if (savedSettingsSnapshot?.templates) {
    savedSettingsSnapshot.templates[canonKey] = String(newText || '').replace(/\r\n/g, '\n');
  }
  if (activeSettingsTemplateKey === canonKey) {
    const ta = document.getElementById('cfgTemplateContent');
    if (ta) ta.value = String(newText || '');
    renderTemplatePreview();
  }
  updateSettingsDirtyState();
}

function buildNormalizedSettingsSnapshotFromConfig(cfg) {
  const catalogSnap = {};
  const cat = cfg?.catalog || {};
  Object.keys(cat).sort().forEach(slug => {
    const item = cat[slug] || {};
    catalogSnap[slug] = {
      label: String(item.label || slug).trim(),
      price: Number(item.price || 0).toFixed(2),
      days: String(parseInt(item.days ?? 0, 10) || 0),
      ai_credits: String(parseInt(item.ai_credits ?? 0, 10) || 0),
      updates_window_months: String(parseInt(item.updates_window_months ?? item.updates_months ?? 0, 10) || 0),
      description: String(item.description || '').trim(),
    };
  });
  const migFeeNum = (cfg?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
    ? cfg.catalog.HARDWARE_MIGRATION_FEE.price
    : (cfg?.migration_fee ?? 40.0);

  const templatesSnap = {};
  SETTINGS_TEMPLATE_KEYS.forEach(k => {
    templatesSnap[k] = resolveCanonicalTemplateFromMap(cfg?.templates, k).replace(/\r\n/g, '\n');
  });

  const li = cfg?.legal_identity || {};
  const pm = cfg?.payment_methods || {};
  const sys = cfg?.system || cfg?.preferences || {};

  return {
    pricing: {
      migration_fee: Number(migFeeNum || 0).toFixed(2),
      catalog: catalogSnap,
    },
    templates: templatesSnap,
    payment: {
      author_full_name: String(li.author_full_name || '').trim(),
      commercial_name: String(li.commercial_name || li.brand_name || '').trim(),
      support_phone: String(li.support_phone || '').trim(),
      yape_plin_phone: String(pm.yape_plin_phone || '').trim(),
      yape_plin_holder: String(pm.yape_plin_holder || '').trim(),
      bcp_account_holder: String(pm.bcp_account_holder || '').trim(),
      bcp_account_number: String(pm.bcp_account_number || '').trim(),
      bcp_cci: String(pm.bcp_cci || '').trim(),
      bbva_account_holder: String(pm.bbva_account_holder || '').trim(),
      bbva_account_number: String(pm.bbva_account_number || '').trim(),
      bbva_cci: String(pm.bbva_cci || '').trim(),
    },
    preferences: {
      default_mode: String(sys.default_mode || sys.default_environment || 'sandbox').trim(),
      theme: String(sys.theme || sys.default_theme || 'dark').trim(),
      table_density: String(sys.table_density || 'comfortable').trim(),
    },
  };
}

function readCurrentSettingsSnapshotFromDom() {
  const rawCatalogSnap = {};
  document.querySelectorAll('.cfg-plan-price').forEach(inp => {
    const slug = inp.dataset.slug;
    if (!slug) return;
    rawCatalogSnap[slug] = {
      label: String(document.querySelector(`.cfg-plan-label[data-slug="${slug}"]`)?.value || slug).trim(),
      price: Number(parseFloat(inp.value) || 0).toFixed(2),
      days: String(parseInt(document.querySelector(`.cfg-plan-days[data-slug="${slug}"]`)?.value ?? 0, 10) || 0),
      ai_credits: String(parseInt(document.querySelector(`.cfg-plan-ai[data-slug="${slug}"]`)?.value ?? 0, 10) || 0),
      updates_window_months: String(parseInt(document.querySelector(`.cfg-plan-updates[data-slug="${slug}"]`)?.value ?? 0, 10) || 0),
      description: String(document.querySelector(`.cfg-plan-desc[data-slug="${slug}"]`)?.value || '').trim(),
    };
  });
  const migFeeEl = document.getElementById('cfgMigrationFee');
  const migFee = Number(parseFloat(migFeeEl?.value) || 0).toFixed(2);
  if (rawCatalogSnap.HARDWARE_MIGRATION_FEE) {
    rawCatalogSnap.HARDWARE_MIGRATION_FEE.price = migFee;
  }
  const catalogSnap = {};
  Object.keys(rawCatalogSnap).sort().forEach(slug => {
    catalogSnap[slug] = rawCatalogSnap[slug];
  });

  const tplTextarea = document.getElementById('cfgTemplateContent');
  if (activeSettingsTemplateKey && tplTextarea) {
    settingsDraftTemplates[activeSettingsTemplateKey] = tplTextarea.value || '';
  }
  const templatesSnap = {};
  SETTINGS_TEMPLATE_KEYS.forEach(k => {
    templatesSnap[k] = String(settingsDraftTemplates[k] ?? '').replace(/\r\n/g, '\n');
  });

  return {
    pricing: {
      migration_fee: migFee,
      catalog: catalogSnap,
    },
    templates: templatesSnap,
    payment: {
      author_full_name: String(document.getElementById('cfgLegalOwner')?.value || '').trim(),
      commercial_name: String(document.getElementById('cfgBrandName')?.value || '').trim(),
      support_phone: String(document.getElementById('cfgSupportPhone')?.value || '').trim(),
      yape_plin_phone: String(document.getElementById('cfgYapePhone')?.value || '').trim(),
      yape_plin_holder: String(document.getElementById('cfgYapeHolder')?.value || '').trim(),
      bcp_account_holder: String(document.getElementById('cfgBcpHolder')?.value || '').trim(),
      bcp_account_number: String(document.getElementById('cfgBcpAccount')?.value || '').trim(),
      bcp_cci: String(document.getElementById('cfgBcpCci')?.value || '').trim(),
      bbva_account_holder: String(document.getElementById('cfgBbvaHolder')?.value || '').trim(),
      bbva_account_number: String(document.getElementById('cfgBbvaAccount')?.value || '').trim(),
      bbva_cci: String(document.getElementById('cfgBbvaCci')?.value || '').trim(),
    },
    preferences: {
      default_mode: String(document.getElementById('cfgDefaultEnv')?.value || 'sandbox').trim(),
      theme: String(document.getElementById('cfgDefaultTheme')?.value || 'dark').trim(),
      table_density: String(document.getElementById('cfgTableDensity')?.value || 'comfortable').trim(),
    },
  };
}

function getDirtySettingsTabs() {
  if (!savedSettingsSnapshot || !ownerConfig) return [];
  const current = readCurrentSettingsSnapshotFromDom();
  const dirty = [];
  if (JSON.stringify(current.pricing) !== JSON.stringify(savedSettingsSnapshot.pricing)) {
    dirty.push('stabPricing');
  }
  if (JSON.stringify(current.templates) !== JSON.stringify(savedSettingsSnapshot.templates)) {
    dirty.push('stabTemplates');
  }
  if (JSON.stringify(current.payment) !== JSON.stringify(savedSettingsSnapshot.payment)) {
    dirty.push('stabPayment');
  }
  if (JSON.stringify(current.preferences) !== JSON.stringify(savedSettingsSnapshot.preferences)) {
    dirty.push('stabPreferences');
  }
  return dirty;
}

function updateSettingsDirtyState() {
  const dirtyTabs = getDirtySettingsTabs();
  Object.keys(SETTINGS_SUBTAB_META).forEach(stabId => {
    const dot = document.querySelector(`.stab-dirty-dot[data-dirty-for="${stabId}"]`);
    if (dot) dot.classList.toggle('visible', dirtyTabs.includes(stabId));
  });
  const badge = document.getElementById('settingsDirtyBadge');
  const badgeTxt = document.getElementById('settingsDirtyBadgeText');
  if (badge) {
    badge.style.display = dirtyTabs.length > 0 ? 'inline-flex' : 'none';
  }
  if (badgeTxt && dirtyTabs.length > 0) {
    badgeTxt.textContent = dirtyTabs.length === 1
      ? 'Cambios sin guardar (1 sección)'
      : `Cambios sin guardar (${dirtyTabs.length} secciones)`;
  }
  return dirtyTabs;
}

function guardSettingsExit(proceedCallback) {
  const dirtyTabs = getDirtySettingsTabs();
  if (!dirtyTabs || dirtyTabs.length === 0) {
    return true;
  }

  pendingSettingsExitAction = typeof proceedCallback === 'function' ? proceedCallback : null;
  const listEl = document.getElementById('unsavedSettingsList');
  if (listEl) {
    listEl.innerHTML = dirtyTabs
      .map(id => `<div>• <strong>${escapeHtml(SETTINGS_SUBTAB_META[id]?.label || id)}</strong></div>`)
      .join('');
  }
  openModal('modalUnsavedSettings');
  return false;
}

async function loadConfig() {
  try {
    const res = await fetch('/api/config');
    if (!res.ok) throw new Error('Error al cargar configuración del propietario');
    ownerConfig = await res.json();
    if (!hasAppliedInitialConfigTheme && ownerConfig?.system?.theme) {
      applyTheme(ownerConfig.system.theme);
      hasAppliedInitialConfigTheme = true;
    }
    populateSettingsForm(ownerConfig);
    applyConfigToUi(ownerConfig);
    renderTemplatePreview();
  } catch (err) {
    console.error('Error al cargar configuración:', err);
  }
}

function initSettingsEvents() {
  // Sub-tabs switching
  const tabs = document.querySelectorAll('.settings-tab-btn');
  tabs.forEach(btn => {
    btn.addEventListener('click', () => {
      tabs.forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.settings-pane').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      const targetPane = document.getElementById(btn.dataset.stab);
      if (targetPane) targetPane.classList.add('active');
    });
  });

  // Selector de plantilla con preservación de borrador en memoria entre cambios
  const tplSelect = document.getElementById('cfgTemplateSelect');
  tplSelect?.addEventListener('change', () => {
    const textarea = document.getElementById('cfgTemplateContent');
    if (activeSettingsTemplateKey && textarea) {
      settingsDraftTemplates[activeSettingsTemplateKey] = textarea.value || '';
    }
    const nextKey = tplSelect.value || 'license_issued';
    activeSettingsTemplateKey = nextKey;
    const nextVal = settingsDraftTemplates[nextKey] ?? resolveCanonicalTemplateFromMap(ownerConfig?.templates, nextKey);
    if (textarea) textarea.value = nextVal || '';
    renderTemplatePreview();
    updateSettingsDirtyState();
  });

  // Tooltips e inserción de variables en textarea
  const varHintEl = document.getElementById('templateVarTooltipText');
  document.querySelectorAll('.var-chip').forEach(chip => {
    chip.addEventListener('mouseenter', () => {
      if (varHintEl && chip.title) varHintEl.textContent = `${chip.dataset.var}: ${chip.title}`;
    });
    chip.addEventListener('focus', () => {
      if (varHintEl && chip.title) varHintEl.textContent = `${chip.dataset.var}: ${chip.title}`;
    });
    chip.addEventListener('click', () => {
      const v = chip.dataset.var;
      const textarea = document.getElementById('cfgTemplateContent');
      if (!textarea || !v) return;
      const start = textarea.selectionStart ?? textarea.value.length;
      const end = textarea.selectionEnd ?? textarea.value.length;
      const text = textarea.value;
      textarea.value = text.substring(0, start) + v + text.substring(end);
      textarea.selectionStart = textarea.selectionEnd = start + v.length;
      textarea.focus?.();
      settingsDraftTemplates[activeSettingsTemplateKey] = textarea.value;
      triggerTemplatePreviewDebounced();
      updateSettingsDirtyState();
    });
  });

  // Input en textarea con debounce y borrador en memoria
  document.getElementById('cfgTemplateContent')?.addEventListener('input', (e) => {
    if (activeSettingsTemplateKey) {
      settingsDraftTemplates[activeSettingsTemplateKey] = e.target.value || '';
    }
    triggerTemplatePreviewDebounced();
    updateSettingsDirtyState();
  });

  // Copiar Vista Previa renderizada
  document.getElementById('btnCopyWaPreview')?.addEventListener('click', () => {
    const bubble = document.getElementById('waBubbleContent');
    const rawPreviewText = (bubble?.innerText || bubble?.textContent || '').trim();
    if (!rawPreviewText || rawPreviewText === 'Cargando vista previa interactiva...') {
      showToast('No hay vista previa disponible para copiar todavía.', 'warning');
      return;
    }
    copyPlainTextToClipboard(rawPreviewText, 'Vista previa de WhatsApp copiada al portapapeles.');
  });

  // Sincronización bidireccional en vivo Tarifa de Migración (cabecera <-> HARDWARE_MIGRATION_FEE)
  document.getElementById('cfgMigrationFee')?.addEventListener('input', (e) => {
    const tablePriceInput = document.querySelector('.cfg-plan-price[data-slug="HARDWARE_MIGRATION_FEE"]');
    if (tablePriceInput) {
      tablePriceInput.value = e.target.value;
    }
    updateSettingsDirtyState();
  });

  document.getElementById('catalogConfigTableBody')?.addEventListener('input', (e) => {
    const target = e.target;
    if (target?.classList?.contains('cfg-plan-price') && target?.dataset?.slug === 'HARDWARE_MIGRATION_FEE') {
      const topMigInput = document.getElementById('cfgMigrationFee');
      if (topMigInput) topMigInput.value = target.value;
    }
    updateSettingsDirtyState();
  });

  // Tracking de dirty state global dentro de #tabSettings
  const settingsPane = document.getElementById('tabSettings');
  settingsPane?.addEventListener('input', () => updateSettingsDirtyState());
  settingsPane?.addEventListener('change', () => updateSettingsDirtyState());

  // Cambio reactivo de tema y densidad desde preferencias
  document.getElementById('cfgDefaultTheme')?.addEventListener('change', (e) => {
    applyTheme(e.target.value);
    updateSettingsDirtyState();
  });

  document.getElementById('cfgTableDensity')?.addEventListener('change', (e) => {
    applyTableDensity(e.target.value);
    updateSettingsDirtyState();
  });

  // Atajo a Rutas de Búsqueda de APKs en Tab 4
  document.getElementById('btnGoToApkSearchDirs')?.addEventListener('click', () => {
    const releaseNav = document.querySelector('.nav-tab[data-tab="tabReleaseManager"]');
    if (releaseNav) {
      releaseNav.click();
      setTimeout(() => {
        const targetBtn = document.getElementById('btnManageApkSearchDirs');
        if (targetBtn && typeof targetBtn.scrollIntoView === 'function') {
          targetBtn.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
        targetBtn?.focus?.();
      }, 180);
    }
  });

  // Guardar solo esta pestaña / Guardar todo
  document.getElementById('btnSaveSettingsTab')?.addEventListener('click', () => {
    saveOwnerConfig({ scope: getActiveSettingsSubTabScope() });
  });
  document.getElementById('btnSaveSettings')?.addEventListener('click', () => {
    saveOwnerConfig({ scope: 'all' });
  });

  // Modal de Restauración con Alcance Explícito (#btnResetSettings)
  document.getElementById('btnResetSettings')?.addEventListener('click', () => {
    const activeId = getActiveSettingsSubTabId();
    const lblEl = document.getElementById('resetCurrentTabLabel');
    if (lblEl) {
      lblEl.textContent = SETTINGS_SUBTAB_META[activeId]?.label || 'Pestaña actual';
    }
    openModal('modalResetSettingsScope');
  });

  document.getElementById('btnResetScopeCurrentTab')?.addEventListener('click', async () => {
    closeModal('modalResetSettingsScope');
    await resetOwnerConfigByScope(getActiveSettingsSubTabScope());
  });
  document.getElementById('btnResetScopeAll')?.addEventListener('click', async () => {
    closeModal('modalResetSettingsScope');
    await resetOwnerConfigByScope('all');
  });
  document.getElementById('btnResetScopeCancel')?.addEventListener('click', () => closeModal('modalResetSettingsScope'));
  document.getElementById('btnCloseResetScopeModal')?.addEventListener('click', () => closeModal('modalResetSettingsScope'));

  // Modal de Dirty Guard (#modalUnsavedSettings)
  const closeUnsaved = () => {
    pendingSettingsExitAction = null;
    closeModal('modalUnsavedSettings');
  };
  document.getElementById('btnUnsavedKeepEditing')?.addEventListener('click', closeUnsaved);
  document.getElementById('btnCloseUnsavedSettingsModal')?.addEventListener('click', closeUnsaved);
  document.getElementById('btnUnsavedDiscardAndContinue')?.addEventListener('click', () => {
    const nextAction = pendingSettingsExitAction;
    pendingSettingsExitAction = null;
    closeModal('modalUnsavedSettings');
    populateSettingsForm(ownerConfig);
    applyConfigToUi(ownerConfig);
    renderTemplatePreview();
    if (nextAction) nextAction();
  });
  document.getElementById('btnUnsavedSaveAndContinue')?.addEventListener('click', async () => {
    const nextAction = pendingSettingsExitAction;
    const ok = await saveOwnerConfig({ scope: 'all' });
    if (ok) {
      pendingSettingsExitAction = null;
      closeModal('modalUnsavedSettings');
      if (nextAction) nextAction();
    }
  });

  if (typeof initCommercialSyncModalEvents === 'function') {
    initCommercialSyncModalEvents();
  }
}
