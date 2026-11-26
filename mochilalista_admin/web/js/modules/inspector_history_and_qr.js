// =================== 5. INSPECTOR FORENSE DUAL / TRI-PROTOCOLO (ML9 / MLS1 / MLC1 — PLAN 22 FASE 4 + PLAN 23.5) ===================
const INSPECTOR_HISTORY_STORAGE_KEY = 'ml_inspector_session_history_v1';
const MAX_INSPECTOR_SESSION_HISTORY = 10;
let inspectorSessionHistory = [];
let currentInspectorAuditSnapshot = null;

function reconcileInspectorNonceStatus(tNonceRaw, matchedClient) {
  const tNonce = Number(tNonceRaw ?? 0);
  const cNonce = Number(matchedClient?.next_nonce ?? 1);
  const hasSyncedNonce = Boolean(
    matchedClient &&
    matchedClient.ultimo_nonce !== null &&
    matchedClient.ultimo_nonce !== undefined
  );
  const syncedNonce = hasSyncedNonce ? Number(matchedClient.ultimo_nonce) : null;

  if (syncedNonce !== null && !Number.isNaN(syncedNonce) && tNonce <= syncedNonce) {
    return {
      state: 'REDEEMED_SYNCED',
      badgeClass: 'badge badge-green',
      label: `Canjeado en celular (Verificado por .mlsync #${syncedNonce})`,
    };
  }
  if (tNonce === cNonce - 1) {
    return {
      state: 'EMITTED_PENDING',
      badgeClass: 'badge badge-blue',
      label: 'Emitido — Pendiente de canje en celular (Sin .mlsync reciente)',
    };
  }
  if (tNonce >= cNonce) {
    return {
      state: 'FUTURE_READY',
      badgeClass: 'badge badge-yellow',
      label: 'Nonce futuro listo para canje',
    };
  }
  return {
    state: 'HISTORICAL_SUPERSEDED',
    badgeClass: 'badge badge-purple',
    label: 'Superado / Histórico',
  };
}

function loadInspectorSessionHistory() {
  try {
    const raw = typeof sessionStorage !== 'undefined'
      ? sessionStorage.getItem(INSPECTOR_HISTORY_STORAGE_KEY)
      : null;
    if (raw) {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        inspectorSessionHistory = parsed.slice(0, MAX_INSPECTOR_SESSION_HISTORY);
      }
    }
  } catch (_) {
    // fallback in-memory si sessionStorage no está disponible
  }
  return inspectorSessionHistory;
}

function saveInspectorSessionHistory() {
  try {
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.setItem(
        INSPECTOR_HISTORY_STORAGE_KEY,
        JSON.stringify(inspectorSessionHistory.slice(0, MAX_INSPECTOR_SESSION_HISTORY))
      );
    }
  } catch (_) {
    // ignore storage errors
  }
}

function recordInspectorSessionEntry(entry) {
  if (!entry || !entry.rawInput) return;
  loadInspectorSessionHistory();
  const filtered = inspectorSessionHistory.filter(item => item.rawInput !== entry.rawInput);
  filtered.unshift({
    kind: entry.kind || 'ML9',
    summaryLabel: entry.summaryLabel || '-',
    hardwareId: entry.hardwareId || '-',
    statusText: entry.statusText || '-',
    statusTone: entry.statusTone || 'badge-mono',
    timestampIso: entry.timestampIso || new Date().toISOString(),
    timestampLima: formatLimaDateTime(entry.timestampIso || Date.now()),
    rawInput: entry.rawInput,
  });
  inspectorSessionHistory = filtered.slice(0, MAX_INSPECTOR_SESSION_HISTORY);
  saveInspectorSessionHistory();
  renderInspectorSessionHistory();
}

function pushInspectorSessionHistory(entry) {
  return recordInspectorSessionEntry(entry);
}

function clearInspectorSessionHistory() {
  inspectorSessionHistory = [];
  saveInspectorSessionHistory();
  renderInspectorSessionHistory();
  showToast('Historial de auditorías de sesión limpiado.', 'info');
}

function reloadInspectorHistoryEntry(idx) {
  const entry = inspectorSessionHistory[idx];
  if (!entry) return;
  const input = document.getElementById('inspectTokenInput');
  if (input) {
    input.value = entry.rawInput;
    inspectToken({ skipHistoryRecord: true });
  }
}

function renderInspectorSessionHistory() {
  const panel = document.getElementById('inspectorSessionHistoryPanel');
  const listEl = document.getElementById('inspectorSessionHistoryList');
  const countEl = document.getElementById('inspectorHistoryCount');
  if (!panel || !listEl) return;

  loadInspectorSessionHistory();
  if (countEl) countEl.textContent = String(inspectorSessionHistory.length);

  if (inspectorSessionHistory.length === 0) {
    panel.style.display = 'none';
    listEl.innerHTML = '';
    return;
  }

  panel.style.display = 'block';
  listEl.innerHTML = '';
  inspectorSessionHistory.forEach((item, idx) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'inspector-history-item';
    btn.title = 'Clic para recargar y volver a auditar';
    const kindBadgeClass = item.kind === 'MLS1'
      ? 'badge-blue'
      : (item.kind === 'MLC1' ? 'badge-mlc1' : 'badge-mono');
    btn.innerHTML = `
      <div style="display:flex; align-items:center; gap:0.5rem; flex-wrap:wrap;">
        <span class="badge ${escapeHtml(kindBadgeClass)}">${escapeHtml(item.kind)}</span>
        <strong style="font-size:0.84rem;">${escapeHtml(item.summaryLabel)}</strong>
        <code style="font-family:var(--font-mono); font-size:0.78rem; color:var(--primary);">${escapeHtml(item.hardwareId)}</code>
      </div>
      <div style="display:flex; align-items:center; gap:0.5rem; flex-wrap:wrap;">
        <span class="badge ${escapeHtml(item.statusTone)}">${escapeHtml(item.statusText)}</span>
        <span style="font-size:0.74rem; color:var(--text-muted);" title="UTC: ${escapeHtml(item.timestampIso)}">${escapeHtml(item.timestampLima)}</span>
      </div>
    `;
    btn.addEventListener('click', () => reloadInspectorHistoryEntry(idx));
    listEl.appendChild(btn);
  });
}

function openClientDrawerFromInspector(clientId) {
  if (!clientId) return;
  document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
  document.querySelector('[data-tab="tabClients"]')?.classList.add('active');
  document.getElementById('tabClients')?.classList.add('active');
  openClient360Drawer(clientId, 'drawerTabOverview');
}

function openSettingsFromInspector(subTabId = null) {
  document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
  document.querySelector('[data-tab="tabSettings"]')?.classList.add('active');
  document.getElementById('tabSettings')?.classList.add('active');
  const viewNameEl = document.getElementById('currentViewName');
  if (viewNameEl) {
    viewNameEl.textContent = 'Configuración y Personalización';
  }
  if (subTabId) {
    const subBtn = document.querySelector(`.settings-tab-btn[data-stab="${subTabId}"]`);
    if (subBtn && typeof subBtn.click === 'function') {
      subBtn.click();
    }
  }
  if (typeof loadConfig === 'function' && (typeof ownerConfig === 'undefined' || !ownerConfig || !ownerConfig.catalog)) {
    loadConfig();
  }
}

function toggleInspectorProtocolGuide(forceOpen) {
  const panel = document.getElementById('inspectorProtocolGuide');
  const btn = document.getElementById('btnToggleInspectorGuide');
  if (!panel) return false;
  const currentlyOpen = panel.style.display !== 'none' && panel.style.display !== '';
  const nextOpen = typeof forceOpen === 'boolean' ? forceOpen : !currentlyOpen;
  panel.style.display = nextOpen ? 'block' : 'none';
  if (btn) {
    btn.setAttribute('aria-expanded', nextOpen ? 'true' : 'false');
    btn.classList.toggle('active', nextOpen);
  }
  return nextOpen;
}

function buildInspectorForensicReportText(snapshot) {
  if (!snapshot) return '';
  const lines = [
    `INFORME FORENSE MOCHILALISTA (${snapshot.kind})`,
    `Fecha de Auditoría: ${formatLimaDateTime(snapshot.auditedAtIso)} [UTC: ${snapshot.auditedAtIso}]`,
    `Validez Criptográfica: ${snapshot.valid ? 'VÁLIDA' : 'INVÁLIDA'} (${snapshot.statusDetail || '-'})`,
  ];
  if (snapshot.clientSummary) {
    lines.push(`${snapshot.kind === 'MLC1' ? 'Contexto Admin' : 'Cliente CRM'}: ${snapshot.clientSummary}`);
  }
  if (snapshot.nonceStatusLabel) {
    lines.push(`Estado de Nonce Reconciliado: ${snapshot.nonceStatusLabel}`);
  }
  if (snapshot.recommendation) {
    lines.push(`Acción Recomendada: ${snapshot.recommendation}`);
  }
  if (snapshot.securityAlert) {
    lines.push(`Alerta Crítica: ${snapshot.securityAlert}`);
  }
  if (Array.isArray(snapshot.highlights) && snapshot.highlights.length > 0) {
    lines.push('Detalle Técnico:');
    snapshot.highlights.forEach(h => lines.push(`- ${h.label}: ${h.value}`));
  }
  return lines.join('\n');
}

function copyInspectorForensicReport() {
  const reportText = buildInspectorForensicReportText(currentInspectorAuditSnapshot);
  if (!reportText) {
    showToast('No hay informe forense activo para copiar.', 'warning');
    return;
  }
  copyPlainTextToClipboard(reportText, 'Informe forense copiado al portapapeles.');
}

function renderInspectorQuickActionsBar(matchedClient) {
  if (!matchedClient || !matchedClient.id) return '';
  return `
    <div class="inspector-actions-bar">
      <button type="button" class="btn btn-outline btn-xs" id="btnInspectOpenDrawer360">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        Abrir Ficha 360°
      </button>
      <button type="button" class="btn btn-outline btn-xs" id="btnInspectOpenWa">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>
        Abrir WhatsApp
      </button>
      <button type="button" class="btn btn-outline btn-xs" id="btnInspectCopyReport">
        <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
        Copiar Informe Forense
      </button>
    </div>
  `;
}

function bindInspectorQuickActions(clientId) {
  document.getElementById('btnInspectOpenDrawer360')?.addEventListener('click', () => {
    openClientDrawerFromInspector(clientId);
  });
  document.getElementById('btnInspectOpenWa')?.addEventListener('click', () => {
    openWhatsAppComposer(clientId);
  });
  document.getElementById('btnInspectCopyReport')?.addEventListener('click', () => {
    copyInspectorForensicReport();
  });
}

function initInspectorEvents() {
  document.getElementById('btnToggleInspectorGuide')?.addEventListener('click', () => {
    toggleInspectorProtocolGuide();
  });
  document.getElementById('btnInspectToken')?.addEventListener('click', () => inspectToken());
  document.getElementById('btnClearInspectToken')?.addEventListener('click', () => {
    const inp = document.getElementById('inspectTokenInput');
    if (inp) inp.value = '';
    const resCont = document.getElementById('inspectResultContainer');
    if (resCont) resCont.style.display = 'none';
    const mlc1Card = document.getElementById('inspectMlc1AuditCard');
    if (mlc1Card) {
      mlc1Card.style.display = 'none';
      mlc1Card.innerHTML = '';
    }
    currentInspectorAuditSnapshot = null;
  });
  renderInspectorSessionHistory();

  // Lector óptico Drag & Drop
  const qrDropZone = document.getElementById('qrOpticalDropZone');
  const qrFileInput = document.getElementById('qrOpticalFileInput');

  qrDropZone?.addEventListener('click', () => qrFileInput?.click());

  qrDropZone?.addEventListener('dragover', (e) => {
    e.preventDefault();
    qrDropZone.classList.add('dragover');
  });

  qrDropZone?.addEventListener('dragleave', () => {
    qrDropZone.classList.remove('dragover');
  });

  qrDropZone?.addEventListener('drop', (e) => {
    e.preventDefault();
    qrDropZone.classList.remove('dragover');
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleOpticalQrFile(e.dataTransfer.files[0]);
    }
  });

  qrFileInput?.addEventListener('change', () => {
    if (qrFileInput.files && qrFileInput.files.length > 0) {
      handleOpticalQrFile(qrFileInput.files[0]);
    }
  });
}

/**
 * Decodifica un canvas QR usando jsQR con soporte para inversiones y reescalado entero
 * sin suavizado + quiet zone blanca ante QR densos (como fichas MLC1-...).
 */
function tryDecodeQrCanvasWithUpscale(sourceCanvas, jsQrFn) {
  if (!sourceCanvas || typeof jsQrFn !== 'function') return null;
  const srcCtx = typeof sourceCanvas.getContext === 'function'
    ? sourceCanvas.getContext('2d')
    : null;
  if (!srcCtx || typeof srcCtx.getImageData !== 'function') return null;

  const width = Number(sourceCanvas.width || 0);
  const height = Number(sourceCanvas.height || 0);
  if (width <= 0 || height <= 0) return null;

  try {
    const baseImg = srcCtx.getImageData(0, 0, width, height);
    const direct = jsQrFn(baseImg.data, baseImg.width, baseImg.height, {
      inversionAttempts: 'attemptBoth',
    });
    if (direct && direct.data) {
      return direct.data;
    }
  } catch (err) {
    console.error('jsQR direct error:', err);
  }

  const maxDim = Math.max(width, height);
  const scaleFactors = maxDim < 600 ? [2, 3] : [2];
  for (const scale of scaleFactors) {
    try {
      const pad = 24;
      const scaledW = (width * scale) + (pad * 2);
      const scaledH = (height * scale) + (pad * 2);
      const offscreen = document.createElement('canvas');
      offscreen.width = scaledW;
      offscreen.height = scaledH;
      const oCtx = typeof offscreen.getContext === 'function'
        ? offscreen.getContext('2d')
        : null;
      if (!oCtx || typeof oCtx.getImageData !== 'function') continue;

      oCtx.imageSmoothingEnabled = false;
      oCtx.fillStyle = '#ffffff';
      if (typeof oCtx.fillRect === 'function') {
        oCtx.fillRect(0, 0, scaledW, scaledH);
      }
      if (typeof oCtx.drawImage === 'function') {
        oCtx.drawImage(sourceCanvas, pad, pad, width * scale, height * scale);
      }
      const upscaled = oCtx.getImageData(0, 0, scaledW, scaledH);
      const code = jsQrFn(upscaled.data, upscaled.width, upscaled.height, {
        inversionAttempts: 'attemptBoth',
      });
      if (code && code.data) {
        return code.data;
      }
    } catch (err) {
      console.error(`jsQR upscale ${scale}x error:`, err);
    }
  }

  return null;
}

async function handleOpticalQrFile(file) {
  // Soporte directo para archivos de sincronización .mlsync o JSON
  if (file.name.endsWith('.mlsync') || file.name.endsWith('.json') || file.type === 'application/json') {
    const reader = new FileReader();
    reader.onload = (e) => {
      document.getElementById('inspectTokenInput').value = e.target.result;
      showToast('Archivo .mlsync cargado en Inspector Forense.', 'success');
      inspectToken();
    };
    reader.readAsText(file);
    return;
  }

  if (!file.type.startsWith('image/')) {
    showToast('El archivo no es una imagen válida ni un archivo .mlsync.', 'error');
    return;
  }

  showToast('Procesando imagen ópticamente...', 'info');

  const reader = new FileReader();
  reader.onload = async (e) => {
    const img = new Image();
    img.onload = async () => {
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0);

      let decodedText = null;

      // 1. Decodificación offline con jsQR + reescalado sin suavizado ante alta densidad
      if (typeof jsQR !== 'undefined') {
        decodedText = tryDecodeQrCanvasWithUpscale(canvas, jsQR);
      }

      // 2. Fallback con BarcodeDetector si está disponible en el navegador
      if (!decodedText && 'BarcodeDetector' in window) {
        try {
          const detector = new BarcodeDetector({ formats: ['qr_code'] });
          const barcodes = await detector.detect(img);
          if (barcodes.length > 0) {
            decodedText = barcodes[0].rawValue;
          }
        } catch (err) {
          console.error('BarcodeDetector error:', err);
        }
      }

      if (decodedText) {
        document.getElementById('inspectTokenInput').value = decodedText;
        showToast('¡Código QR detectado y decodificado ópticamente!', 'success');
        inspectToken();
      } else {
        showToast('No se encontró un código QR legible en la imagen. Intenta con una imagen más nítida.', 'warning');
      }
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
}
