async function openWhatsAppComposer(clientId, defaultTemplateKey = null, options = {}) {
  const client = (globalClients && globalClients.find(c => c.id === clientId)) ||
                 (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === clientId)) ||
                 currentDispatchClient;
  if (!client) {
    showToast('Cliente no encontrado.', 'error');
    return;
  }

  currentWaComposerClientId = clientId;
  currentWaPreTemplateDraft = '';
  currentWaRenderedTemplateBase = '';
  openedInApkDispatchMode = options.isApkDispatch === true;

  const copyHintEl = document.getElementById('waApkCopySuccessHint');
  if (copyHintEl) copyHintEl.style.display = 'none';

  const bizNameEl = document.getElementById('waCompBizName');
  const ownerNameEl = document.getElementById('waCompOwnerName');
  const planBadgeEl = document.getElementById('waCompPlanBadge');
  const devIdEl = document.getElementById('waCompDeviceId');
  const phoneDisplayEl = document.getElementById('waCompPhoneDisplay');
  const phoneWarningEl = document.getElementById('waCompPhoneWarning');
  const sendBtn = document.getElementById('btnWaCompSend');
  const openEmptyBtn = document.getElementById('btnWaCompOpenEmpty');

  if (bizNameEl) bizNameEl.textContent = client.business_name || 'Sin negocio';
  if (ownerNameEl) ownerNameEl.textContent = client.owner_name || 'Sin titular';
  if (devIdEl) devIdEl.textContent = client.current_device_id || client.device_id || 'PENDIENTE';

  const badgeInfo = getClientStatusBadge(client, { asObject: true });
  if (planBadgeEl) {
    planBadgeEl.className = badgeInfo.className;
    planBadgeEl.textContent = badgeInfo.text;
  }
  const isProspect = badgeInfo.isProspect;
  const isPerp = badgeInfo.isPerp;
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const now = new Date();
  const diffDays = expDate ? Math.max(0, Math.ceil((expDate - now) / (1000 * 60 * 60 * 24))) : 0;

  let rawPhone = (client.phone || '').trim();
  let cleanDigits = rawPhone.replace(/[^0-9]/g, '');
  if (cleanDigits.length === 9 && !cleanDigits.startsWith('51')) {
    cleanDigits = '51' + cleanDigits;
  }
  const hasValidPhone = cleanDigits.length >= 9;

  if (phoneDisplayEl) {
    phoneDisplayEl.textContent = rawPhone || 'No registrado';
  }

  if (phoneWarningEl) {
    phoneWarningEl.style.display = hasValidPhone ? 'none' : 'flex';
  }

  if (sendBtn) {
    sendBtn.style.opacity = hasValidPhone ? '1' : '0.4';
    sendBtn.style.pointerEvents = hasValidPhone ? 'auto' : 'none';
  }
  if (openEmptyBtn) {
    openEmptyBtn.style.opacity = hasValidPhone ? '1' : '0.4';
    openEmptyBtn.style.pointerEvents = hasValidPhone ? 'auto' : 'none';
    openEmptyBtn.href = hasValidPhone ? buildWhatsAppSendUrl(cleanDigits) : '#';
  }

  // Selección inteligente de plantilla
  let initialTpl = 'welcome';
  if (defaultTemplateKey && WA_TEMPLATES[defaultTemplateKey]) {
    initialTpl = defaultTemplateKey;
  } else if (isProspect) {
    initialTpl = 'prospect';
  } else if (!isPerp && diffDays <= 7) {
    initialTpl = 'expiring';
  } else {
    initialTpl = 'welcome';
  }

  // Cargar token histórico más reciente si existe o usar el provisto en options
  let realToken = options.token ? String(options.token).trim() : '';
  let hasRealToken = Boolean(realToken && !realToken.startsWith('ML9-PENDIENTE'));
  if (!options.token) {
    try {
      const res = await fetch(`/api/clients/${clientId}/history`);
      if (res.ok) {
        const history = await res.json();
        if (history.codes && history.codes.length > 0) {
          realToken = String(history.codes[history.codes.length - 1].token || '').trim();
          hasRealToken = Boolean(realToken);
        }
      }
    } catch (_) { }
  }

  const modalEl = document.getElementById('modalWaComposer');
  if (modalEl) {
    modalEl.dataset.lastToken = realToken;
    modalEl.dataset.hasRealToken = hasRealToken ? 'true' : 'false';
    modalEl.dataset.cleanPhone = cleanDigits;
    modalEl.dataset.aiCredits = options.aiCredits !== undefined ? String(options.aiCredits) : '';
    modalEl.dataset.diasExtension = options.diasExtension !== undefined ? String(options.diasExtension) : '';
  }

  // Alternar panel y footer exclusivo de Despacho Asistido de APK (Plan 19 / 22 Fase 3)
  if (options.isApkDispatch === true) {
    const sorted = [...(globalReleases || [])].sort((a, b) => compareSemVer(b.version_name, a.version_name));
    currentDispatchRelease = options.release || sorted[0] || currentDispatchRelease;
    toggleWaApkDispatchPanelVisibility(true);
    if (currentDispatchRelease) {
      syncWaApkDispatchPanel(currentDispatchRelease, { skipMessageUpdate: true });
    }
  } else {
    currentDispatchRelease = null;
    currentDispatchClient = null;
    currentDispatchMode = 'eligible';
    toggleWaApkDispatchPanelVisibility(false);
  }

  if (options.customMessage) {
    const textarea = document.getElementById('waCompMessage');
    if (openedInApkDispatchMode) {
      currentWaComposerTemplateKey = 'update';
      currentWaRenderedTemplateBase = options.customMessage;
      document.querySelectorAll('.wa-template-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.tpl === 'update');
      });
    } else {
      currentWaComposerTemplateKey = null;
      currentWaPreTemplateDraft = options.customMessage;
      document.querySelectorAll('.wa-template-btn').forEach(b => b.classList.remove('active'));
    }
    if (textarea) {
      textarea.value = options.customMessage;
      updateWaComposerStats();
      syncWaInsertChipsState();
    }
  } else {
    currentWaComposerTemplateKey = null;
    selectWaTemplate(initialTpl);
  }
  openModal('modalWaComposer');
}

function selectWaTemplate(tplKey, options = {}) {
  if (!WA_TEMPLATES[tplKey]) tplKey = 'welcome';
  const textarea = document.getElementById('waCompMessage');
  if (!textarea) return;

  const { baseText, activeKeys } = extractBaseAndSnippetsFromText(textarea.value || '');

  // Segundo clic sobre la misma plantilla activa -> desactivar y restaurar borrador previo sin duplicar
  if (!options.forceApply && currentWaComposerTemplateKey === tplKey) {
    currentWaComposerTemplateKey = null;
    document.querySelectorAll('.wa-template-btn').forEach(b => b.classList.remove('active'));

    let restored = currentWaPreTemplateDraft || '';
    activeKeys.forEach(k => {
      const blk = buildWaSnippetBlock(k, { notify: false });
      if (blk) restored = appendSnippetBlockToText(restored, blk);
    });

    textarea.value = restored;
    currentWaPreTemplateDraft = '';
    currentWaRenderedTemplateBase = '';

    if (tplKey === 'update' && !openedInApkDispatchMode) {
      toggleWaApkDispatchPanelVisibility(false);
    }

    updateWaComposerStats();
    syncWaInsertChipsState();
    return;
  }

  // Al pasar desde texto libre hacia una plantilla, resguardar borrador previo
  if (!currentWaComposerTemplateKey || currentWaComposerTemplateKey === 'custom') {
    currentWaPreTemplateDraft = baseText;
  }

  currentWaComposerTemplateKey = tplKey;
  document.querySelectorAll('.wa-template-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.tpl === tplKey);
  });

  if (tplKey === 'update') {
    ensureWaDispatchReleaseInitialized();
    toggleWaApkDispatchPanelVisibility(true);
    if (currentDispatchRelease) {
      syncWaApkDispatchPanel(currentDispatchRelease, { skipMessageUpdate: true });
    }
  } else if (!openedInApkDispatchMode) {
    toggleWaApkDispatchPanelVisibility(false);
  }

  const newBase = renderWaTemplateBaseText(tplKey);
  currentWaRenderedTemplateBase = newBase;

  let nextText = newBase;
  activeKeys.forEach(k => {
    const blk = buildWaSnippetBlock(k, { notify: false });
    if (blk) nextText = appendSnippetBlockToText(nextText, blk);
  });

  textarea.value = nextText;
  updateWaComposerStats();
  syncWaInsertChipsState();
}

function updateWaComposerStats() {
  const textarea = document.getElementById('waCompMessage');
  const counter = document.getElementById('waCompCharCounter');
  const sendBtn = document.getElementById('btnWaCompSend');
  const modalEl = document.getElementById('modalWaComposer');
  const cleanDigits = modalEl?.dataset?.cleanPhone || '';

  if (!textarea) return;
  const text = textarea.value || '';
  if (counter) counter.textContent = `${text.length} caracteres`;

  if (sendBtn && cleanDigits && cleanDigits.length >= 9) {
    sendBtn.href = buildWhatsAppSendUrl(cleanDigits, text);
  }
}

function copyWaComposerMessage() {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea || !textarea.value.trim()) {
    showToast('El mensaje está vacío.', 'warning');
    return;
  }
  copyPlainTextToClipboard(textarea.value, 'Mensaje copiado al portapapeles.');
}

function insertTextAtCursor(textarea, textToInsert) {
  if (!textarea) return;
  const start = textarea.selectionStart ?? textarea.value.length;
  const end = textarea.selectionEnd ?? textarea.value.length;
  const current = textarea.value;
  textarea.value = current.substring(0, start) + textToInsert + current.substring(end);
  textarea.selectionStart = textarea.selectionEnd = start + textToInsert.length;
  textarea.focus?.();
  updateWaComposerStats();
  syncWaInsertChipsState();
}

function insertWaSnippet(type) {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea) return;

  const key = normalizeWaSnippetKey(type);
  const block = buildWaSnippetBlock(key, { notify: true });
  if (!block) {
    syncWaInsertChipsState();
    return;
  }

  const normalized = (textarea.value || '').replace(/\r\n/g, '\n');
  if (normalized.includes(block)) {
    textarea.value = removeSnippetBlockFromText(normalized, block);
  } else {
    textarea.value = appendSnippetBlockToText(normalized, block);
  }

  textarea.focus?.();
  updateWaComposerStats();
  syncWaInsertChipsState();
}

async function saveCurrentWaTemplate() {
  const textarea = document.getElementById('waCompMessage');
  if (!textarea) return;
  const tplKey = currentWaComposerTemplateKey;
  if (!tplKey || !WA_TEMPLATES[tplKey]) {
    showToast('Selecciona primero una plantilla para guardar cambios.', 'warning');
    return;
  }

  const { baseText } = extractBaseAndSnippetsFromText(textarea.value || '');
  const newText = baseText;
  const canonKey = resolveConfigTemplateKeyFromWa(tplKey);

  if (!ownerConfig) ownerConfig = {};
  if (!ownerConfig.templates) ownerConfig.templates = {};
  ownerConfig.templates[canonKey] = newText;
  if (canonKey !== tplKey) {
    delete ownerConfig.templates[tplKey];
  }
  WA_TEMPLATES[tplKey].text = newText;

  try {
    const res = await fetch('/api/config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(ownerConfig),
    });
    if (!res.ok) throw new Error('Error al guardar plantilla');
    const saved = await res.json().catch(() => null);
    if (saved && saved.templates) {
      ownerConfig = saved;
    }
    syncWaTemplatesFromOwnerConfig(ownerConfig);
    if (typeof syncTemplateDraftFromSavedConfig === 'function') {
      syncTemplateDraftFromSavedConfig(canonKey, newText);
    }
    showToast('Plantilla guardada y sincronizada con Configuración.', 'success');
  } catch (e) {
    showToast('Error al guardar plantilla: ' + e.message, 'error');
  }
}

async function resetCurrentWaTemplate() {
  const tplKey = (currentWaComposerTemplateKey && DEFAULT_WA_TEMPLATES[currentWaComposerTemplateKey])
    ? currentWaComposerTemplateKey
    : 'welcome';
  const canonKey = resolveConfigTemplateKeyFromWa(tplKey);
  const defaultText = DEFAULT_WA_TEMPLATES[tplKey]?.text || '';
  if (WA_TEMPLATES[tplKey]) {
    WA_TEMPLATES[tplKey].text = defaultText;
  }

  if (ownerConfig?.templates) {
    delete ownerConfig.templates[canonKey];
    delete ownerConfig.templates[tplKey];
    try {
      const res = await fetch('/api/config', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(ownerConfig),
      });
      if (res.ok) {
        const saved = await res.json().catch(() => null);
        if (saved && saved.templates) {
          ownerConfig = saved;
          syncWaTemplatesFromOwnerConfig(ownerConfig);
          if (typeof syncTemplateDraftFromSavedConfig === 'function') {
            syncTemplateDraftFromSavedConfig(canonKey, saved.templates[canonKey] || defaultText);
          }
        }
      }
    } catch (_) { }
  }

  selectWaTemplate(tplKey, { forceApply: true });
  showToast('Plantilla restaurada a los valores predeterminados.', 'info');
}

function initWaComposerEvents() {
  document.getElementById('waCompMessage')?.addEventListener('input', () => {
    updateWaComposerStats();
    syncWaInsertChipsState();
  });
}
