function parseApkSizeMbNumber(raw) {
  if (raw === null || raw === undefined) return null;
  const cleaned = String(raw).trim().replace(/\s*MB\s*$/i, '').trim();
  if (!cleaned) return null;
  const num = Number(cleaned);
  return (!Number.isNaN(num) && Number.isFinite(num)) ? num : null;
}

function updateWaApkSizeWarning(rawSize, hasArm64 = false) {
  const warnEl = document.getElementById('waApkSizeWarning');
  const sizeLabelEl = document.getElementById('waApkWarningSizeLabel');
  const adviceEl = document.getElementById('waApkWarningAdvice');
  if (!warnEl) return;

  const sizeNum = parseApkSizeMbNumber(rawSize);
  if (sizeNum !== null && sizeNum > 100) {
    warnEl.style.display = 'flex';
    if (sizeLabelEl) sizeLabelEl.textContent = formatApkSizeMb(rawSize);
    if (adviceEl) {
      adviceEl.textContent = (hasArm64 && currentDispatchVariant !== 'arm64')
        ? 'Puedes cambiar arriba a la variante ARM64 Ligero (<= 100 MB), usar WhatsApp Desktop (hasta 2 GB) o compartir el enlace externo.'
        : 'Usa WhatsApp Desktop (admite hasta 2 GB) o comparte un enlace externo de Google Drive para evitar el bloqueo de 100 MB en WhatsApp Web.';
    }
  } else {
    warnEl.style.display = 'none';
  }
}

function toggleWaApkDispatchPanelVisibility(show) {
  isApkDispatchMode = !!show;
  const dispatchPanel = document.getElementById('waApkDispatchPanel');
  const standardFooter = document.getElementById('waStandardFooterActions');
  const dispatchFooter = document.getElementById('waApkDispatchFooterActions');
  const copyHint = document.getElementById('waApkCopySuccessHint');
  const sizeWarn = document.getElementById('waApkSizeWarning');

  if (dispatchPanel) dispatchPanel.style.display = show ? 'block' : 'none';
  if (standardFooter) standardFooter.style.display = show ? 'none' : 'flex';
  if (dispatchFooter) dispatchFooter.style.display = show ? 'flex' : 'none';
  if (!show) {
    if (copyHint) copyHint.style.display = 'none';
    if (sizeWarn) sizeWarn.style.display = 'none';
  }
}

function ensureWaDispatchReleaseInitialized() {
  if (currentDispatchRelease) return currentDispatchRelease;
  const sorted = [...(globalReleases || [])].sort((a, b) => compareSemVer(b.version_name, a.version_name));
  if (sorted.length > 0) {
    currentDispatchRelease = sorted[0];
  } else {
    currentDispatchRelease = {
      version_name: '9.40.0',
      version_code: 84,
      db_schema_version: 36,
      type: 'FEATURE_RELEASE',
      file_size_mb: '108.47 MB',
      changelog: 'Mejoras clave de rendimiento, estabilidad y nuevas funciones comerciales.',
      signature_status: 'OFFICIAL_RELEASE',
      signature_verified: true,
    };
  }
  return currentDispatchRelease;
}

function populateWaApkVersionSelect(selectedVersion) {
  const selectEl = document.getElementById('waApkVersionSelect');
  if (!selectEl) return;

  const list = [...(globalReleases || [])].sort((a, b) => compareSemVer(b.version_name, a.version_name));
  if (selectedVersion && !list.some(r => r.version_name === selectedVersion) && currentDispatchRelease) {
    list.unshift(currentDispatchRelease);
  }

  selectEl.innerHTML = '';
  list.forEach(rel => {
    const opt = document.createElement('option');
    opt.value = rel.version_name;
    const typeLabel = rel.type === 'HOTFIX' ? 'HOTFIX' : 'FEATURE';
    opt.textContent = `v${rel.version_name} (Build ${rel.version_code || '-'}) — ${typeLabel}`;
    selectEl.appendChild(opt);
  });

  if (selectedVersion) {
    selectEl.value = selectedVersion;
  } else if (list.length > 0) {
    selectEl.value = list[0].version_name;
  }
}

function buildApkDispatchMessage(rel, client, mode = 'eligible') {
  const author = ownerConfig?.legal_identity?.author_full_name || 'Julio Angello Vasquez Navarro';
  const ownerName = client?.owner_name || 'Estimado(a) Cliente';
  const bizName = client?.business_name || 'tu negocio';

  if (mode === 'quote') {
    const passPrice = (ownerConfig?.catalog?.PASE_ACTUALIZACION_ANUAL?.price || 150).toFixed(2);
    const installedVer = client?.installed_version || client?.version || '9.0.0';
    return `Hola ${ownerName}, te saluda ${author} de MochilaLista.\n\n` +
      `Acabamos de lanzar la versión oficial *v${rel.version_name}* con mejoras avanzadas.\n` +
      `Tu negocio *${bizName}* cuenta actualmente con la versión v${installedVer}.\n\n` +
      `Para acceder a este paquete de nuevas funciones y soporte continuo, puedes adquirir tu *Pase Anual de Actualizaciones* por solo S/ ${passPrice}.\n\n` +
      `¿Deseas que coordinemos la activación del pase hoy mismo?`;
  }

  const hasDriveUrl = Boolean(rel.apk_download_url && rel.apk_download_url.startsWith('http') && !rel.apk_download_url.includes('localhost'));
  const downloadPart = hasDriveUrl
    ? `*Enlace de Descarga Directa:*\n${rel.apk_download_url}\n\n`
    : (mode === 'courtesy'
        ? `*Archivo APK:* Se adjunta directamente en este chat como cortesía especial para tu negocio.\n\n`
        : `*Archivo APK:* Se adjunta directamente en este chat para su instalación.\n\n`);
  const changelogText = rel.changelog || 'Mejoras clave de rendimiento, estabilidad y nuevas funciones comerciales.';

  if (mode === 'courtesy') {
    return `Hola ${ownerName}, te saluda ${author} de MochilaLista.\n\n` +
      `Como cortesía especial por tu fidelidad comercial, te hemos liberado el acceso directo a la nueva versión *v${rel.version_name}* para tu negocio *${bizName}*.\n\n` +
      `*Versión:* MochilaLista v${rel.version_name}\n` +
      `*Novedades:*\n${changelogText}\n\n` +
      `${downloadPart}` +
      `*Garantía Cero Pérdida:* Al instalar este APK sobre el actual, tu base de datos y productos se mantienen 100% intactos.`;
  }

  if (mode === 'resend') {
    return `Hola ${ownerName}, te saluda ${author} de MochilaLista.\n\n` +
      `Te compartimos nuevamente el instalador oficial para *${bizName}*.\n\n` +
      `*Versión:* MochilaLista v${rel.version_name} (Build ${rel.version_code || 82})\n` +
      `*Novedades:*\n${changelogText}\n\n` +
      `${downloadPart}` +
      `*Garantía Cero Pérdida:* Al instalar este APK sobre el actual, tu base de datos y productos se mantienen 100% intactos.`;
  }

  return `Hola ${ownerName}, te saluda ${author} de MochilaLista.\n\n` +
    `¡Tenemos lista una nueva actualización oficial para *${bizName}*!\n\n` +
    `*Versión:* MochilaLista v${rel.version_name} (Build ${rel.version_code || 82})\n` +
    `*Novedades:*\n${changelogText}\n\n` +
    `${downloadPart}` +
    `*Garantía Cero Pérdida:* Al instalar este APK sobre el actual, tu base de datos y productos se mantienen 100% intactos.`;
}

function syncWaApkDispatchPanel(rel, options = {}) {
  if (!rel) return;
  currentDispatchRelease = rel;

  populateWaApkVersionSelect(rel.version_name);

  const copyHintEl = document.getElementById('waApkCopySuccessHint');
  if (copyHintEl && !options.preserveCopyHint) {
    copyHintEl.style.display = 'none';
  }

  // Evaluar disponibilidad de variantes
  const hasUniversal = !!rel.universal_apk || (!rel.universal_apk && !rel.arm64_apk);
  const hasArm64 = !!rel.arm64_apk;

  const univCard = document.getElementById('waVariantCardUniversal');
  const armCard = document.getElementById('waVariantCardArm64');
  const univDesc = document.getElementById('waVariantDescUniversal');
  const armDesc = document.getElementById('waVariantDescArm64');

  if (univCard) {
    if (hasUniversal) {
      univCard.classList.remove('disabled');
      if (univDesc) {
        const uSize = formatApkSizeMb(rel.universal_apk?.file_size_mb || rel.file_size_mb);
        univDesc.textContent = uSize !== '-'
          ? `Compatible con cualquier celular Android (${uSize})`
          : 'Compatible con cualquier celular Android';
      }
    } else {
      univCard.classList.add('disabled');
      if (univDesc) univDesc.textContent = 'No disponible para esta versión';
    }
  }

  if (armCard) {
    if (hasArm64) {
      armCard.classList.remove('disabled');
      if (armDesc) {
        const aSize = formatApkSizeMb(rel.arm64_apk?.file_size_mb);
        armDesc.textContent = aSize !== '-'
          ? `Rápido para transferir por WhatsApp (${aSize})`
          : 'Rápido para transferir por WhatsApp (celulares modernos)';
      }
    } else {
      armCard.classList.add('disabled');
      if (armDesc) armDesc.textContent = 'No disponible para esta versión';
    }
  }

  // Selección inteligente por defecto
  if (hasUniversal) {
    setDispatchVariant('universal');
  } else if (hasArm64) {
    setDispatchVariant('arm64');
  } else {
    setDispatchVariant('universal');
  }

  // Encabezado técnico
  const titleEl = document.getElementById('waApkVersionTitle');
  if (titleEl) {
    titleEl.textContent = `Despacho de APK: v${rel.version_name} (Build ${rel.version_code || 82})`;
  }

  const dbSchemaEl = document.getElementById('waApkDbSchema');
  if (dbSchemaEl) {
    dbSchemaEl.textContent = `Esquema v${rel.db_schema_version || 36}`;
  }

  const diskStatusEl = document.getElementById('waApkDiskStatus');
  if (diskStatusEl) {
    const hasPath = !!(rel.apk_file_path || rel.universal_apk?.file_path || rel.arm64_apk?.file_path);
    const hasAnyFile = hasPath && rel.file_exists !== false;
    if (hasAnyFile) {
      diskStatusEl.textContent = 'Verificado en Disco';
      diskStatusEl.style.color = '#22c55e';
    } else {
      diskStatusEl.textContent = 'Sin Binario en Disco';
      diskStatusEl.style.color = '#ef4444';
    }
  }

  const sigBadgeEl = document.getElementById('waApkSigBadge');
  if (sigBadgeEl) {
    sigBadgeEl.innerHTML = renderSignatureStatusBadge(rel.signature_status, rel.signature_verified, 'Oficial RSA-4096');
  }

  // Actualizar texto comercial conservando chips Insertar activos
  if (!options.skipMessageUpdate && (currentWaComposerTemplateKey === 'update' || isApkDispatchMode)) {
    const textarea = document.getElementById('waCompMessage');
    const client = getCurrentWaComposerClient();
    if (textarea && client) {
      const { activeKeys } = extractBaseAndSnippetsFromText(textarea.value || '');
      const updatedBase = buildApkDispatchMessage(rel, client, currentDispatchMode);
      currentWaRenderedTemplateBase = updatedBase;

      let nextValue = updatedBase;
      activeKeys.forEach(k => {
        const blk = buildWaSnippetBlock(k, { notify: false });
        if (blk) nextValue = appendSnippetBlockToText(nextValue, blk);
      });

      textarea.value = nextValue;
      updateWaComposerStats();
      syncWaInsertChipsState();
    }
  }
}

function onChangeDispatchReleaseVersion(versionName, options = {}) {
  const rel = (globalReleases && globalReleases.find(r => r.version_name === versionName)) || currentDispatchRelease;
  if (!rel) return;
  syncWaApkDispatchPanel(rel, options);
}

/**
 * Cambia la variante activa en el compositor de despacho APK
 */
function setDispatchVariant(variant) {
  currentDispatchVariant = variant;
  const univCard = document.getElementById('waVariantCardUniversal');
  const armCard = document.getElementById('waVariantCardArm64');

  if (univCard) {
    if (variant === 'universal') univCard.classList.add('active');
    else univCard.classList.remove('active');
  }
  if (armCard) {
    if (variant === 'arm64') armCard.classList.add('active');
    else armCard.classList.remove('active');
  }

  // Actualizar tamaño de APK mostrado siempre con formato MB y evaluar aviso >100 MB
  const sizeEl = document.getElementById('waApkSizeText');
  let rawSize = '';
  if (currentDispatchRelease) {
    if (variant === 'arm64' && currentDispatchRelease.arm64_apk?.file_size_mb) {
      rawSize = currentDispatchRelease.arm64_apk.file_size_mb;
    } else if (variant === 'universal' && currentDispatchRelease.universal_apk?.file_size_mb) {
      rawSize = currentDispatchRelease.universal_apk.file_size_mb;
    } else {
      rawSize = currentDispatchRelease.file_size_mb || '';
    }
  }
  if (sizeEl) {
    sizeEl.textContent = formatApkSizeMb(rawSize);
  }
  const hasArm64 = !!(currentDispatchRelease && currentDispatchRelease.arm64_apk);
  updateWaApkSizeWarning(rawSize, hasArm64);
}

/**
 * Abre el Compositor Universal en modo Despacho Asistido de APK (Plan 19 / 22 Fase 3)
 */
function openApkDispatchComposer(clientId, versionName, mode = 'eligible') {
  const client = (globalClients && globalClients.find(c => c.id === clientId)) ||
                 (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === clientId));
  if (!client) {
    showToast('Cliente no encontrado para despacho de APK.', 'error');
    return;
  }

  const rel = (globalReleases && globalReleases.find(r => r.version_name === versionName)) ||
              (globalReleases && globalReleases[0]) || {
                version_name: versionName,
                version_code: 84,
                db_schema_version: 36,
                type: 'FEATURE_RELEASE',
                file_size_mb: '108.47 MB',
                changelog: 'Mejoras clave de rendimiento, estabilidad y nuevas funciones comerciales.',
                signature_status: 'OFFICIAL_RELEASE',
                signature_verified: true,
              };

  currentDispatchRelease = rel;
  currentDispatchClient = client;
  currentDispatchMode = mode;

  const customMessage = buildApkDispatchMessage(rel, client, mode);

  openWhatsAppComposer(clientId, 'update', {
    isApkDispatch: true,
    release: rel,
    customMessage: customMessage,
  });
}

async function copyCurrentDispatchApkToClipboard() {
  if (!currentDispatchRelease) return { ok: false };
  const versionName = currentDispatchRelease.version_name;
  const variant = currentDispatchVariant || 'universal';
  const copyHintEl = document.getElementById('waApkCopySuccessHint');
  const copyHintTextEl = document.getElementById('waApkCopySuccessText');

  const copyRes = await fetch(`/api/releases/${encodeURIComponent(versionName)}/copy-file?variant=${encodeURIComponent(variant)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  });
  const copyData = await copyRes.json().catch(() => ({}));

  if (!copyRes.ok || copyData.ok !== true) {
    if (copyHintEl) copyHintEl.style.display = 'none';
    const errMsg = copyRes.status === 404
      ? `No se encontró el archivo .apk físico en disco para v${versionName} (${variant}).`
      : (copyData.error || 'No se pudo copiar el archivo .apk al portapapeles de Windows.');
    showToast(errMsg, 'error');
    return { ok: false, error: errMsg };
  }

  const fileName = copyData.file_name || `mochilalista-v${versionName}.apk`;
  showToast(`Archivo .apk copiado: presiona Ctrl + V en WhatsApp (${fileName}).`, 'success');
  if (copyHintEl) copyHintEl.style.display = 'flex';
  if (copyHintTextEl) {
    copyHintTextEl.textContent = `Listo en portapapeles de Windows: ${fileName} — En el chat de WhatsApp que se abrió, presiona Ctrl + V para adjuntar el archivo.`;
  }
  return { ok: true, data: copyData, fileName };
}

async function reCopyCurrentDispatchApk() {
  const btn = document.getElementById('btnWaReCopyApk');
  if (btn) btn.disabled = true;
  try {
    await copyCurrentDispatchApkToClipboard();
  } catch (e) {
    showToast('Error al volver a copiar APK: ' + e.message, 'error');
  } finally {
    if (btn) btn.disabled = false;
  }
}

/**
 * Copia el binario .APK al portapapeles de Windows y abre WhatsApp (Acción Principal de Fase 3)
 */
async function copyApkAndOpenWhatsApp() {
  if (!currentDispatchRelease) return;
  const versionName = currentDispatchRelease.version_name;
  const variant = currentDispatchVariant || 'universal';
  const clientId = currentWaComposerClientId;
  const client = getCurrentWaComposerClient();

  let rawPhone = (client?.phone || '').trim();
  let cleanDigits = rawPhone.replace(/[^0-9]/g, '');
  if (cleanDigits.length === 9 && !cleanDigits.startsWith('51')) {
    cleanDigits = '51' + cleanDigits;
  }
  const hasValidPhone = cleanDigits.length >= 9;

  const btn = document.getElementById('btnWaCopyApkAndSend');
  if (btn) btn.disabled = true;

  try {
    // 1. Verificar explícitamente POST /api/releases/:version/copy-file?variant=...
    const copyOutcome = await copyCurrentDispatchApkToClipboard();
    if (!copyOutcome.ok) {
      return;
    }

    // 2. Registrar trazabilidad comercial de despacho en backend
    if (clientId) {
      await recordApkSent(clientId, versionName, variant);
    }

    // 3. Abrir WhatsApp oficial si el cliente tiene teléfono registrado
    const text = document.getElementById('waCompMessage')?.value || '';
    if (hasValidPhone) {
      const waUrl = buildWhatsAppSendUrl(cleanDigits, text);
      window.open(waUrl, '_blank');
    } else {
      showToast('Teléfono no registrado: APK copiado, pero WhatsApp no se abrió automáticamente.', 'info');
    }

    // 4. Refrescar matriz en vivo conservando el modal abierto con #waApkCopySuccessHint visible
    await loadReleaseMatrix();
  } catch (e) {
    showToast('Error en despacho asistido: ' + e.message, 'error');
  } finally {
    if (btn) btn.disabled = false;
  }
}

/**
 * Abre en el explorador de Windows la carpeta del APK a despachar
 */
function revealCurrentDispatchApkFolder() {
  if (!currentDispatchRelease) return;
  revealReleaseInExplorer(currentDispatchRelease.version_name, currentDispatchVariant);
}

/**
 * Despacha únicamente el mensaje de texto por WhatsApp sin copiar binario
 */
async function sendWaDispatchTextOnly() {
  if (!currentDispatchRelease) return;
  const versionName = currentDispatchRelease.version_name;
  const variant = currentDispatchVariant || 'universal';
  const clientId = currentWaComposerClientId;
  const client = (globalClients && globalClients.find(c => c.id === clientId)) ||
                 (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === clientId)) ||
                 currentDispatchClient;

  let rawPhone = (client?.phone || '').trim();
  let cleanDigits = rawPhone.replace(/[^0-9]/g, '');
  if (cleanDigits.length === 9 && !cleanDigits.startsWith('51')) {
    cleanDigits = '51' + cleanDigits;
  }
  const hasValidPhone = cleanDigits.length >= 9;

  if (clientId) {
    await recordApkSent(clientId, versionName, variant);
  }

  const text = document.getElementById('waCompMessage')?.value || '';
  if (hasValidPhone) {
    const waUrl = buildWhatsAppSendUrl(cleanDigits, text);
    window.open(waUrl, '_blank');
  }

  closeModal('modalWaComposer');
  await loadReleaseMatrix();
}

async function markClientUpdated(clientId, versionName, options = {}) {
  const force = !!options.force;
  const silentUndo = !!options.silentUndo;
  try {
    const res = await fetch(`/api/clients/${clientId}/mark-updated`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ version_name: versionName, force: force }),
    });
    if (!res.ok) throw new Error('Error al marcar cliente actualizado');
    const data = await res.json().catch(() => ({}));
    const updatedVer = data.installed_version || versionName;
    const prevVer = data.previous_installed_version;

    if (!silentUndo && prevVer && prevVer !== updatedVer) {
      showToast(`Cliente actualizado a v${updatedVer} (antes v${prevVer}).`, 'success', {
        duration: 8000,
        actionLabel: 'Deshacer',
        onAction: async () => {
          await markClientUpdated(clientId, prevVer, { force: true, silentUndo: true });
        },
      });
    } else {
      showToast(`Cliente actualizado a v${updatedVer} en el registro.`, 'success');
    }

    await loadReleaseMatrix();
    await loadClients();
    await loadReleases();
    await loadDashboard();
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

/**
 * Abre el modal compacto para corregir manualmente la versión instalada (force: true)
 */
function openFixClientVersionModal(clientId) {
  const row = (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === clientId)) ||
              (globalClients && globalClients.find(c => c.id === clientId));
  if (!row) {
    showToast('Cliente no encontrado.', 'error');
    return;
  }

  const currentVer = String(row.installed_version || '9.0.0').trim();
  const idInput = document.getElementById('fixClientVersionId');
  const bizEl = document.getElementById('fixClientVersionBiz');
  const curEl = document.getElementById('fixClientVersionCurrent');
  const selEl = document.getElementById('fixClientVersionSelect');
  const customInput = document.getElementById('fixClientVersionInput');

  if (idInput) idInput.value = clientId;
  if (bizEl) bizEl.textContent = row.business_name || row.owner_name || clientId;
  if (curEl) curEl.textContent = `v${currentVer}`;
  if (customInput) customInput.value = currentVer;

  if (selEl) {
    selEl.innerHTML = '';
    const seen = new Set();
    const versions = [];
    (globalReleases || []).forEach(r => {
      if (r.version_name && !seen.has(r.version_name)) {
        seen.add(r.version_name);
        versions.push({
          version: r.version_name,
          label: `v${r.version_name} (${r.type === 'HOTFIX' ? 'HOTFIX' : 'FEATURE'})`,
        });
      }
    });
    if (!seen.has(currentVer)) {
      versions.push({ version: currentVer, label: `v${currentVer} (actual)` });
    }
    versions.forEach(item => {
      const opt = document.createElement('option');
      opt.value = item.version;
      opt.textContent = item.label;
      if (item.version === currentVer) opt.selected = true;
      selEl.appendChild(opt);
    });
    const manualOpt = document.createElement('option');
    manualOpt.value = '__CUSTOM__';
    manualOpt.textContent = 'Otra versión manual...';
    selEl.appendChild(manualOpt);
  }

  openModal('modalFixClientVersion');
}

