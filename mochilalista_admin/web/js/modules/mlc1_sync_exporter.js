// =================== 8B. EMISOR DECLARATIVO MLC1- Y EXPORTADOR DART (PLAN 23 FASE 3) ===================

let lastGeneratedMlc1Data = null;
let currentMlc1DartFilename = 'owner_commercial_defaults.dart';

function _syncMlc1DartTargetMetadata(data) {
  if (!data || typeof data !== 'object') return;
  if (typeof data.download_filename === 'string' && data.download_filename.trim()) {
    currentMlc1DartFilename = data.download_filename.trim();
  }
  const targetPathEl = document.getElementById('mlc1DartTargetPath');
  if (targetPathEl && typeof data.target_file_path === 'string' && data.target_file_path.trim()) {
    targetPathEl.textContent = data.target_file_path.trim();
  }
}

function initCommercialSyncModalEvents() {
  document.getElementById('btnOpenCommercialSyncModal')?.addEventListener('click', () => {
    openCommercialConfigSyncModal();
  });

  document.querySelectorAll('.btn-open-commercial-sync').forEach(btn => {
    btn.addEventListener('click', () => {
      openCommercialConfigSyncModal();
    });
  });

  document.getElementById('btnCloseCommercialSyncModal')?.addEventListener('click', () => {
    closeModal('modalCommercialConfigSync');
  });
  document.getElementById('btnDismissCommercialSyncModal')?.addEventListener('click', () => {
    closeModal('modalCommercialConfigSync');
  });

  document.querySelectorAll('.mlc1-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset.mlc1Tab;
      document.querySelectorAll('.mlc1-tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.mlc1-tab-pane').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      if (targetId) document.getElementById(targetId)?.classList.add('active');
    });
  });

  document.getElementById('btnGenerateMlc1Token')?.addEventListener('click', () => {
    generateMlc1SyncToken();
  });

  document.getElementById('btnCopyMlc1Token')?.addEventListener('click', () => {
    const tok = document.getElementById('mlc1TokenOutput')?.value?.trim() || '';
    if (!tok) {
      showToast('Genera primero una ficha MLC1 para copiarla.', 'warning');
      return;
    }
    copyPlainTextToClipboard(tok, 'Código MLC1 copiado al portapapeles.');
  });

  document.getElementById('btnDownloadMlc1Qr')?.addEventListener('click', () => {
    const rev = lastGeneratedMlc1Data?.revision || ownerConfig?.system?.commercial_sync_revision || 1;
    downloadQrWithQuietZone('#mlc1QrContainer', `QR_Tarifas_MochilaLista_MLC1_Rev${rev}.png`, 32);
  });

  document.getElementById('btnCopyMlc1Qr')?.addEventListener('click', () => {
    copyMlc1QrToClipboard();
  });

  document.getElementById('btnSendMlc1Whatsapp')?.addEventListener('click', () => {
    shareMlc1TokenViaWhatsApp();
  });

  document.getElementById('btnAuditMlc1InInspector')?.addEventListener('click', () => {
    auditMlc1TokenInInspector();
  });

  document.getElementById('btnCopyMlc1Dart')?.addEventListener('click', () => {
    const code = document.getElementById('mlc1DartSnippetOutput')?.value || '';
    if (!code.trim()) {
      showToast('No hay archivo Dart cargado todavía.', 'warning');
      return;
    }
    copyPlainTextToClipboard(code, 'Archivo Dart completo copiado al portapapeles.');
  });

  document.getElementById('btnDownloadMlc1Dart')?.addEventListener('click', () => {
    downloadMlc1DartDefaultsFile();
  });
}

function openCommercialConfigSyncModal() {
  const dirtyTabs = typeof getDirtySettingsTabs === 'function' ? getDirtySettingsTabs() : [];
  if (dirtyTabs.length > 0) {
    const labels = dirtyTabs
      .map(id => SETTINGS_SUBTAB_META[id]?.label || id)
      .join(', ');
    if (typeof showConfirmModal === 'function') {
      showConfirmModal(
        'Cambios sin guardar en Configuración',
        `Tienes modificaciones pendientes en: ${labels}. Para evitar emitir una ficha MLC1 con tarifas o cuentas desactualizadas, debes guardar primero. ¿Deseas guardar todos los cambios ahora y continuar?`,
        async () => {
          const savedOk = await saveOwnerConfig({ scope: 'all' });
          if (savedOk) {
            await loadAndOpenCommercialSyncModal();
          }
        }
      );
    } else {
      showToast('Guarda primero los cambios pendientes antes de sincronizar con la app móvil.', 'warning');
    }
    return false;
  }

  loadAndOpenCommercialSyncModal();
  return true;
}

function renderMlc1CommercialSummary(summary) {
  const accEl = document.getElementById('mlc1AccountsSummary');
  const tbody = document.getElementById('mlc1PlansSummaryBody');
  if (!summary) return;

  if (accEl) {
    const bcpTxt = summary.bcp_configured && summary.bcp?.acc
      ? `BCP: ${summary.bcp.acc}${summary.bcp.cci ? ` (CCI: ${summary.bcp.cci})` : ''}`
      : 'BCP: Omitido';
    const bbvaTxt = summary.bbva_configured && summary.bbva?.acc
      ? `BBVA: ${summary.bbva.acc}${summary.bbva.cci ? ` (CCI: ${summary.bbva.cci})` : ''}`
      : 'BBVA: Omitido';
    accEl.innerHTML = `
      <span><strong>Soporte:</strong> ${escapeHtml(summary.support_phone || '-')}</span>
      <span><strong>Yape/Plin:</strong> ${escapeHtml(summary.yape_phone || '-')} (${escapeHtml(summary.yape_holder || '-')})</span>
      <span><strong>${escapeHtml(bcpTxt)}</strong></span>
      <span><strong>${escapeHtml(bbvaTxt)}</strong></span>
    `;
  }

  if (tbody && Array.isArray(summary.plans)) {
    tbody.innerHTML = summary.plans.map(p => {
      let daysTxt;
      if ((p.days || 0) >= 99999) {
        daysTxt = 'Vitalicia';
      } else if (p.id === 'bolsa_extra_ia') {
        daysTxt = 'Recarga';
      } else if (p.id === 'pase_anual_updates') {
        daysTxt = 'Pase anual';
      } else if (p.id === 'migracion') {
        daysTxt = 'Único';
      } else if ((p.days || 0) > 0) {
        daysTxt = `${p.days} días`;
      } else {
        daysTxt = 'Único';
      }
      const updTxt = (p.updates_months || 0) > 0 ? `${p.updates_months} meses` : '-';
      return `
        <tr>
          <td><strong>${escapeHtml(p.label || p.id)}</strong> <code style="font-size:0.72rem; color:var(--text-muted);">${escapeHtml(p.id)}</code></td>
          <td style="text-align:right; font-family:var(--font-mono);">S/ ${Number(p.price || 0).toFixed(2)}</td>
          <td style="text-align:right;">${daysTxt}</td>
          <td style="text-align:right;">+${p.ai_credits || 0} IA</td>
          <td style="text-align:right;">${updTxt}</td>
        </tr>
      `;
    }).join('');
  }
}

function updateMlc1QrAndInspectorUiState(qrInst, hasToken) {
  const auditBtn = document.getElementById('btnAuditMlc1InInspector');
  if (auditBtn) {
    auditBtn.disabled = !hasToken;
  }

  const metaBadge = document.getElementById('mlc1QrMetaBadge');
  if (!metaBadge) return;

  metaBadge.classList.remove('is-ready', 'is-error');
  if (!hasToken) {
    metaBadge.textContent = 'QR pendiente de emisión';
    return;
  }

  const qrContainer = document.getElementById('mlc1QrContainer');
  const hasCapacityError = Boolean(
    qrInst === null ||
    (qrContainer && typeof qrContainer.querySelector === 'function' && qrContainer.querySelector('.qr-capacity-warning'))
  );
  if (hasCapacityError) {
    metaBadge.classList.add('is-error');
    metaBadge.textContent = 'QR excede capacidad física (2,953 B) — usa texto MLC1';
    return;
  }

  const lvlMap = { 1: 'L', 0: 'M', 3: 'Q', 2: 'H' };
  const verPart = qrInst && qrInst._lastVersion ? ` · V${qrInst._lastVersion}` : '';
  const lvlPart = (qrInst && qrInst._lastCorrectLevel !== undefined)
    ? ` · Nivel ${lvlMap[qrInst._lastCorrectLevel] || 'L'}`
    : ' · Nivel L';
  metaBadge.classList.add('is-ready');
  metaBadge.textContent = `QR 512 px${verPart}${lvlPart} · Listo para escanear`;
}

async function loadAndOpenCommercialSyncModal() {
  // Asegurar pestaña Vía 1 activa al abrir
  document.querySelectorAll('.mlc1-tab-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.mlc1Tab === 'mlc1PaneToken');
  });
  document.querySelectorAll('.mlc1-tab-pane').forEach(p => {
    p.classList.toggle('active', p.id === 'mlc1PaneToken');
  });

  openModal('modalCommercialConfigSync');

  try {
    const res = await fetch('/api/config/dart-defaults-snippet');
    if (!res.ok) throw new Error('Error al consultar configuración comercial');
    const data = await res.json();

    const revBadge = document.getElementById('mlc1RevisionBadge');
    if (revBadge) revBadge.textContent = `Revisión #${data.revision ?? 0}`;

    const dartOut = document.getElementById('mlc1DartSnippetOutput');
    if (dartOut) dartOut.value = data.dart_snippet || '';
    _syncMlc1DartTargetMetadata(data);

    if (data.summary) renderMlc1CommercialSummary(data.summary);

    const hasSameToken = Boolean(
      lastGeneratedMlc1Data &&
      lastGeneratedMlc1Data.revision === data.revision &&
      data.revision > 0 &&
      lastGeneratedMlc1Data.token
    );
    const resultContainer = document.getElementById('mlc1TokenResultContainer');
    const emptyHint = document.getElementById('mlc1EmptyResultHint');
    if (resultContainer && emptyHint) {
      resultContainer.style.display = hasSameToken ? 'grid' : 'none';
      emptyHint.style.display = hasSameToken ? 'none' : 'block';
    }
    if (!hasSameToken) {
      const issuedBadge = document.getElementById('mlc1IssuedAtLimaBadge');
      const sizeBadge = document.getElementById('mlc1PayloadSizeBadge');
      const tokOut = document.getElementById('mlc1TokenOutput');
      const qrContainer = document.getElementById('mlc1QrContainer');
      if (issuedBadge) issuedBadge.textContent = 'Pendiente de emitir nueva ficha';
      if (sizeBadge) sizeBadge.textContent = '0 B / 8192 B';
      if (tokOut) tokOut.value = '';
      if (qrContainer) qrContainer.innerHTML = '';
      updateMlc1QrAndInspectorUiState(undefined, false);
    } else {
      const tokOut = document.getElementById('mlc1TokenOutput');
      if (tokOut) tokOut.value = lastGeneratedMlc1Data.token;
      const qrContainer = document.getElementById('mlc1QrContainer');
      let qrInst;
      if (qrContainer && typeof renderSafeQrCode === 'function') {
        const hasCanvas = typeof qrContainer.querySelector === 'function' && Boolean(qrContainer.querySelector('canvas'));
        if (!hasCanvas) {
          qrInst = renderSafeQrCode(qrContainer, lastGeneratedMlc1Data.token, 512, '#0f172a', '#ffffff');
        }
      }
      updateMlc1QrAndInspectorUiState(qrInst, true);
    }
  } catch (err) {
    showToast('Error al cargar datos MLC1: ' + err.message, 'error');
  }
}

async function generateMlc1SyncToken() {
  const dirtyTabs = typeof getDirtySettingsTabs === 'function' ? getDirtySettingsTabs() : [];
  if (dirtyTabs.length > 0) {
    showToast('Tienes cambios sin guardar en Configuración. Guárdalos antes de generar la ficha MLC1.', 'warning');
    return null;
  }

  const btn = document.getElementById('btnGenerateMlc1Token');
  if (btn) btn.disabled = true;

  try {
    const res = await fetch('/api/config/generate-sync-token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.ok) {
      throw new Error(data.error || `Error HTTP ${res.status}`);
    }

    lastGeneratedMlc1Data = data;
    if (data.config) {
      ownerConfig = data.config;
      if (typeof buildNormalizedSettingsSnapshotFromConfig === 'function') {
        savedSettingsSnapshot = buildNormalizedSettingsSnapshotFromConfig(ownerConfig);
        updateSettingsDirtyState();
      }
    }

    const tokOut = document.getElementById('mlc1TokenOutput');
    if (tokOut) tokOut.value = data.token || '';

    const revBadge = document.getElementById('mlc1RevisionBadge');
    if (revBadge) revBadge.textContent = `Revisión #${data.revision}`;

    const issuedBadge = document.getElementById('mlc1IssuedAtLimaBadge');
    if (issuedBadge) issuedBadge.textContent = `Emitida: ${data.issued_at_lima || data.issued_at || '-'}`;

    const sizeBadge = document.getElementById('mlc1PayloadSizeBadge');
    if (sizeBadge) sizeBadge.textContent = `${data.payload_bytes || 0} B JSON (${data.token_bytes || 0} B total / 8192 B)`;

    const dartOut = document.getElementById('mlc1DartSnippetOutput');
    if (dartOut && data.dart_snippet) dartOut.value = data.dart_snippet;
    _syncMlc1DartTargetMetadata(data);

    if (data.summary) renderMlc1CommercialSummary(data.summary);

    const resultContainer = document.getElementById('mlc1TokenResultContainer');
    const emptyHint = document.getElementById('mlc1EmptyResultHint');
    if (resultContainer) resultContainer.style.display = 'grid';
    if (emptyHint) emptyHint.style.display = 'none';

    const qrContainer = document.getElementById('mlc1QrContainer');
    let qrInst;
    if (qrContainer && typeof renderSafeQrCode === 'function') {
      qrInst = renderSafeQrCode(qrContainer, data.token, 512, '#0f172a', '#ffffff');
    }
    updateMlc1QrAndInspectorUiState(qrInst, Boolean(data.token));

    showToast(`Ficha comercial MLC1 (Revisión #${data.revision}) emitida y verificada con Ed25519.`, 'success');
    return data;
  } catch (err) {
    showToast('Error al generar ficha MLC1: ' + err.message, 'error');
    return null;
  } finally {
    if (btn) btn.disabled = false;
  }
}

async function auditMlc1TokenInInspector() {
  const tok = document.getElementById('mlc1TokenOutput')?.value?.trim() || '';
  if (!tok) {
    showToast('Genera primero una ficha MLC1 antes de auditarla en Inspector.', 'warning');
    return false;
  }

  if (typeof closeModal === 'function') {
    closeModal('modalCommercialConfigSync');
  }

  document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

  document.querySelector('[data-tab="tabInspector"]')?.classList.add('active');
  document.getElementById('tabInspector')?.classList.add('active');

  const viewNameEl = document.getElementById('currentViewName');
  if (viewNameEl) {
    viewNameEl.textContent = 'Inspector Forense (ML9 / MLS1 / MLC1)';
  }

  const inspectInput = document.getElementById('inspectTokenInput');
  if (inspectInput) {
    inspectInput.value = tok;
    if (typeof inspectToken === 'function') {
      await inspectToken();
    }
    showToast('Ficha MLC1 transferida al Inspector Forense.', 'info');
    return true;
  }
  return false;
}

function shareMlc1TokenViaWhatsApp() {
  const tok = document.getElementById('mlc1TokenOutput')?.value?.trim() || '';
  if (!tok) {
    showToast('Genera primero una ficha MLC1 antes de compartir.', 'warning');
    return;
  }
  const rev = lastGeneratedMlc1Data?.revision || ownerConfig?.system?.commercial_sync_revision || 1;
  const brand = ownerConfig?.legal_identity?.commercial_name || 'MochilaLista';
  const supportPhone = ownerConfig?.legal_identity?.support_phone || '+51 922 836 879';

  const msg = [
    `*${brand} — Actualización Oficial de Tarifas y Medios de Pago (Rev. #${rev})*`,
    '',
    'Para actualizar tus tarifas y cuentas oficiales al instante sin internet:',
    '1. Abre MochilaLista en tu teléfono.',
    '2. Ve a Menú > Estado de Licencia y Activación.',
    '3. Pega la ficha firmada de abajo o escanea el QR adjunto.',
    '',
    tok,
    '',
    `Soporte oficial: ${supportPhone}`,
  ].join('\n');

  copyPlainTextToClipboard(msg, 'Mensaje MLC1 copiado al portapapeles; abriendo WhatsApp...');
  window.open(buildWhatsAppSendUrl('', msg), '_blank');
}

function downloadMlc1DartDefaultsFile() {
  const code = document.getElementById('mlc1DartSnippetOutput')?.value || '';
  if (!code.trim()) {
    showToast('No hay archivo Dart cargado todavía.', 'warning');
    return false;
  }
  const fileName = currentMlc1DartFilename || 'owner_commercial_defaults.dart';
  const cleanContent = code.replace(/^\uFEFF/, '');
  try {
    const blob = new Blob([cleanContent], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    if (link.style) link.style.display = 'none';
    document.body?.appendChild?.(link);
    if (typeof link.click === 'function') {
      link.click();
    }
    if (typeof link.remove === 'function') {
      link.remove();
    } else {
      document.body?.removeChild?.(link);
    }
    setTimeout(() => {
      try {
        URL.revokeObjectURL(url);
      } catch (_) {}
    }, 1500);
    showToast(`Archivo ${fileName} descargado (UTF-8 sin BOM).`, 'success');
    return true;
  } catch (err) {
    showToast('No se pudo descargar el archivo .dart: ' + err.message, 'error');
    return false;
  }
}

function copyMlc1QrToClipboard() {
  const container = document.getElementById('mlc1QrContainer');
  const sourceEl = container?.querySelector('canvas') || container?.querySelector('img');
  if (!sourceEl) {
    showToast('Genera primero la ficha MLC1 para copiar el QR.', 'warning');
    return;
  }

  const marginPx = 32;
  const w = sourceEl.width || sourceEl.naturalWidth || 512;
  const h = sourceEl.height || sourceEl.naturalHeight || 512;
  const offscreen = document.createElement('canvas');
  offscreen.width = w + marginPx * 2;
  offscreen.height = h + marginPx * 2;
  const ctx = offscreen.getContext('2d');
  if (!ctx) {
    showToast('No fue posible preparar el lienzo del QR.', 'error');
    return;
  }
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(0, 0, offscreen.width, offscreen.height);
  ctx.drawImage(sourceEl, marginPx, marginPx, w, h);

  offscreen.toBlob(async (blob) => {
    if (!blob) {
      showToast('No se pudo convertir el QR a PNG.', 'error');
      return;
    }
    await copyPngBlobToClipboard(blob, {
      successMsg: 'Imagen QR MLC1 copiada al portapapeles con margen blanco.',
      fallbackMsg: 'Tu navegador no permite copiar imágenes directamente; usa "Descargar QR PNG".',
    });
  }, 'image/png');
}
