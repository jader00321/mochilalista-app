// =================== STUDIO GENERADOR & MODAL QR RÁPIDO ===================
function initLicenseStudioEvents() {
  const planSelect = document.getElementById('licPlanSelect');
  const clientSelect = document.getElementById('licClientSelect');

  planSelect?.addEventListener('change', () => {
    resetCustomSettings();
    updateLiveLicenseProjection();
  });

  clientSelect?.addEventListener('change', () => {
    resetCustomSettings();
    updateClientSummaryCard();
    updateLiveLicenseProjection();
    const activeClient = globalClients.find(c => c.id === clientSelect.value);
    updateGeneratorRightColumn(activeClient || null);
  });

  // Modalidad económica de Bono IA (Gratis vs Cobro)
  document.getElementById('ecoModeFree')?.addEventListener('change', () => {
    updateEcoModeUI('free');
    updateLiveLicenseProjection();
  });
  document.getElementById('ecoModePaid')?.addEventListener('change', () => {
    updateEcoModeUI('paid');
    updateLiveLicenseProjection();
  });

  // Chips rápidos de escaneos IA (+20, +50, +100, +150)
  document.querySelectorAll('.ai-chip-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const val = parseInt(btn.getAttribute('data-ai')) || 20;
      const input = document.getElementById('licCustomAiAmount');
      if (input) {
        input.value = val;
        document.querySelectorAll('.ai-chip-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        updateSuggestedPrice();
        updateLiveLicenseProjection();
      }
    });
  });

  // Input manual de escaneos IA
  document.getElementById('licCustomAiAmount')?.addEventListener('input', () => {
    const val = parseInt(document.getElementById('licCustomAiAmount')?.value) || 0;
    document.querySelectorAll('.ai-chip-btn').forEach(b => {
      if (parseInt(b.getAttribute('data-ai')) === val) {
        b.classList.add('active');
      } else {
        b.classList.remove('active');
      }
    });
    updateSuggestedPrice();
    updateLiveLicenseProjection();
  });

  // Botón aplicar precio sugerido
  document.getElementById('btnApplySuggestedPrice')?.addEventListener('click', () => {
    const suggested = updateSuggestedPrice();
    const amountInput = document.getElementById('licPaymentAmount');
    if (amountInput) {
      amountInput.value = suggested.toFixed(2);
      showToast(`Precio sugerido aplicado: S/ ${suggested.toFixed(2)}`, 'info');
      updateLiveLicenseProjection();
    }
  });

  // Acordeón de ajustes comerciales personalizados
  const btnToggleCustom = document.getElementById('btnToggleCustomSettings');
  const customContent = document.getElementById('licCustomContent');
  const accordionArrow = document.getElementById('accordionArrow');

  btnToggleCustom?.addEventListener('click', () => {
    const isOpen = customContent.classList.toggle('open');
    if (accordionArrow) accordionArrow.textContent = isOpen ? '▲' : '▼';
  });

  // Checkbox de habilitación explícita de ajustes personalizados
  document.getElementById('chkEnableCustomSettings')?.addEventListener('change', (e) => {
    if (e.target.checked) {
      if (customContent) customContent.classList.add('open');
      if (accordionArrow) accordionArrow.textContent = '▲';
    }
    updateLiveLicenseProjection();
  });

  // Botón para restablecer ajustes personalizados a los valores originales del plan
  document.getElementById('btnResetCustomSettings')?.addEventListener('click', () => {
    resetCustomSettings();
    updateLiveLicenseProjection();
    showToast('Ajustes comerciales personalizados restablecidos.', 'info');
  });

  // Escuchar inputs para recalcular proyección en vivo
  document.getElementById('licCustomDays')?.addEventListener('input', updateLiveLicenseProjection);
  document.getElementById('licCustomAiBonus')?.addEventListener('input', updateLiveLicenseProjection);
  document.getElementById('licCustomComputationMode')?.addEventListener('change', updateLiveLicenseProjection);
  document.getElementById('licPaymentAmount')?.addEventListener('input', updateLiveLicenseProjection);
  document.getElementById('licPaymentMethod')?.addEventListener('change', updateLiveLicenseProjection);
  document.getElementById('licCustomExactDate')?.addEventListener('change', () => {
    const exactDateVal = document.getElementById('licCustomExactDate').value;
    if (exactDateVal) {
      const targetDate = new Date(exactDateVal + 'T23:59:59');
      const now = new Date();
      const diff = Math.max(1, Math.ceil((targetDate - now) / (1000 * 60 * 60 * 24)));
      document.getElementById('licCustomDays').value = diff;
    }
    updateLiveLicenseProjection();
  });

  // Botón de emisión (Interceptado con Modal de Confirmación Pre-Emisión - Fase 2 Plan 18.5)
  document.getElementById('btnGenerateLicense')?.addEventListener('click', openConfirmEmissionModal);
  document.getElementById('btnExecuteConfirmEmission')?.addEventListener('click', executeConfirmedEmission);

  // Botones de acción sobre la licencia emitida / activa
  document.getElementById('btnCopyCode')?.addEventListener('click', () => {
    const code = document.getElementById('generatedCodeDisplay')?.textContent?.trim();
    if (!code) return;
    copyPlainTextToClipboard(code, '¡Código copiado al portapapeles!');
  });

  document.getElementById('btnGenCopyMessageAndCode')?.addEventListener('click', () => {
    const clientId = document.getElementById('licClientSelect')?.value;
    const client = globalClients.find(c => c.id === clientId);
    if (!currentSelectedGeneratorCode || !client) {
      showToast('No hay una licencia activa seleccionada para copiar.', 'warning');
      return;
    }
    const msg = buildGeneratorWhatsAppMessage(currentSelectedGeneratorCode, client);
    copyPlainTextToClipboard(msg, '¡Mensaje contextual y código copiados para WhatsApp!');
  });

  document.getElementById('btnDownloadQr')?.addEventListener('click', downloadQrCode);
  document.getElementById('btnDownloadCredential')?.addEventListener('click', downloadCredential);
  document.getElementById('btnCopyCredentialImage')?.addEventListener('click', copyCredentialToClipboard);

  document.getElementById('btnSendWa')?.addEventListener('click', () => {
    const clientId = document.getElementById('licClientSelect')?.value;
    const client = globalClients.find(c => c.id === clientId);
    if (!client || !currentSelectedGeneratorCode) {
      showToast('No hay una licencia activa seleccionada para enviar.', 'warning');
      return;
    }
    const plan = currentSelectedGeneratorCode.plan || client.license_type;
    let tpl = 'license';
    if (plan === 'BONO_IA_PERSONALIZADO' || plan === 'RECARGA_IA_150') {
      tpl = 'ai_bonus';
    } else if (plan === 'EXTENSION_CORTESIA') {
      tpl = 'courtesy_extension';
    }
    if (typeof openWhatsAppComposer === 'function') {
      openWhatsAppComposer(client.id, tpl, {
        token: currentSelectedGeneratorCode.token,
        aiCredits: (currentSelectedGeneratorCode.ai_credits ?? currentSelectedGeneratorCode.ai_extra_credits ?? 0),
        diasExtension: currentSelectedGeneratorCode.days || 7,
      });
    }
  });

  // Botón Auditar en el Inspector
  document.getElementById('btnAuditInInspector')?.addEventListener('click', () => {
    const token = document.getElementById('generatedCodeDisplay')?.textContent?.trim();
    if (!token) return;

    const tabs = document.querySelectorAll('.nav-tab');
    tabs.forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

    const inspectTab = document.querySelector('[data-tab="tabInspector"]');
    inspectTab?.classList.add('active');
    document.getElementById('tabInspector')?.classList.add('active');

    const inspectInput = document.getElementById('inspectTokenInput');
    if (inspectInput) {
      inspectInput.value = token;
      inspectToken();
      showToast('Token transferido al Inspector Forense.', 'info');
    }
  });
}

function renderSelectedGeneratorLicense(code, client, isLatest = true) {
  if (!code) return;
  currentSelectedGeneratorCode = code;

  const placeholder = document.getElementById('resultPlaceholder');
  const content = document.getElementById('resultContent');
  const badgeStatus = document.getElementById('licResultBadgeStatus');
  const displayCode = document.getElementById('generatedCodeDisplay');

  if (placeholder) placeholder.style.display = 'none';
  if (content) content.style.display = 'flex';

  if (badgeStatus) {
    badgeStatus.style.display = 'inline-flex';
    if (isLatest) {
      badgeStatus.className = 'badge badge-green';
      badgeStatus.textContent = 'ACTIVA / VIGENTE';
    } else {
      badgeStatus.className = 'badge badge-gray';
      badgeStatus.textContent = 'HISTÓRICA / REEMPLAZADA';
    }
  }

  const token = code.token || '';
  if (displayCode) displayCode.textContent = token;

  // Decodificación defensiva desacoplada del token Ed25519 como fallback
  const claims = decodeMl9TokenPayload(token) || {};

  // Actualizar metadatos en grid
  const metaPlan = document.getElementById('metaGenPlan');
  const metaNonce = document.getElementById('metaGenNonce');
  const metaEmitted = document.getElementById('metaGenEmitted');
  const metaExpires = document.getElementById('metaGenExpires');
  const metaAi = document.getElementById('metaGenAi');
  const metaDevice = document.getElementById('metaGenDeviceId');

  const pPlan = code.plan || (claims.y ? claims.y : client?.license_type) || 'MENSUAL';
  if (metaPlan) metaPlan.textContent = pPlan.replace(/_/g, ' ');

  const nonceVal = (code.nonce !== undefined && code.nonce !== null)
    ? code.nonce
    : (claims.n !== undefined ? claims.n : null);
  if (metaNonce) metaNonce.textContent = nonceVal !== null ? `#${nonceVal}` : '-';

  const emittedDate = code.emitted_at || code.created_at;
  if (metaEmitted) {
    metaEmitted.textContent = emittedDate ? emittedDate.substring(0, 10) : new Date().toISOString().substring(0, 10);
  }

  if (metaExpires) {
    if (pPlan === 'PERPETUO_LIBERADO') {
      metaExpires.textContent = 'Vitalicia';
    } else if (pPlan === 'BONO_IA_PERSONALIZADO' || pPlan === 'RECARGA_IA_150') {
      metaExpires.textContent = client?.license_expires ? client.license_expires.substring(0, 10) : 'Sin alteración';
    } else if (code.expires_at) {
      metaExpires.textContent = code.expires_at.substring(0, 10);
    } else if (code.expires_result) {
      metaExpires.textContent = code.expires_result.substring(0, 10);
    } else if (claims.x) {
      metaExpires.textContent = new Date(claims.x * 1000).toISOString().substring(0, 10);
    } else if (client?.license_expires) {
      metaExpires.textContent = client.license_expires.substring(0, 10);
    } else {
      metaExpires.textContent = '-';
    }
  }

  const aiCreds = (code.ai_credits !== undefined && code.ai_credits !== null)
    ? code.ai_credits
    : ((code.ai_extra_credits !== undefined && code.ai_extra_credits !== null)
      ? code.ai_extra_credits
      : (claims.c !== undefined ? claims.c : 0));
  if (metaAi) metaAi.textContent = `+${aiCreds} IA`;
  if (metaDevice) metaDevice.textContent = code.device_id || claims.d || client?.current_device_id || 'ML-0000';

  // Configuración dinámica del botón directo 'Generar / Ver Boleta'
  const btnOpenReceipt = document.getElementById('btnGenOpenReceipt');
  if (btnOpenReceipt) {
    let matchedPayment = null;
    const historyPayments = client?.payment_history || [];
    if (code.payment_id) {
      matchedPayment = historyPayments.find(p => p.id === code.payment_id);
    }
    if (!matchedPayment && code.amount_paid > 0) {
      const codeDate = (code.emitted_at || code.created_at || '').substring(0, 10);
      matchedPayment = historyPayments.find(p => {
        const pDate = (p.date || '').substring(0, 10);
        return pDate === codeDate && Math.abs((p.amount || 0) - (code.amount_paid || 0)) < 0.01;
      });
    }

    if (matchedPayment || (code.amount_paid && code.amount_paid > 0) || code.payment_id) {
      btnOpenReceipt.style.display = 'inline-flex';
      const receiptNum = matchedPayment?.receipt_number;
      const btnSpan = document.getElementById('btnGenOpenReceiptText');
      if (btnSpan) {
        btnSpan.textContent = receiptNum ? `Ver Boleta (${receiptNum})` : 'Generar / Ver Boleta';
      }
      btnOpenReceipt.onclick = () => {
        const targetPaymentId = matchedPayment?.id || code.payment_id;
        if (targetPaymentId && typeof openPaymentReceiptModal === 'function') {
          openPaymentReceiptModal(client.id, targetPaymentId);
        } else {
          showToast('No se encontró el registro contable del pago.', 'warning');
        }
      };
    } else {
      btnOpenReceipt.style.display = 'none';
      btnOpenReceipt.onclick = null;
    }
  }

  // Renderizar QR Code
  const qrContainer = document.getElementById('qrContainer');
  lastGeneratedQr = renderSafeQrCode(qrContainer, token, 230);

  // Renderizar Canvas PNG de Alta Resolución tras render del QR
  setTimeout(() => {
    renderCredentialCanvas(code, client);
  }, 150);
}

function updateGeneratorRightColumn(client) {
  const resultPlaceholder = document.getElementById('resultPlaceholder');
  const resultContent = document.getElementById('resultContent');
  const historySec = document.getElementById('genHistorySection');
  const badgeStatus = document.getElementById('licResultBadgeStatus');
  const historyList = document.getElementById('genHistoryList');
  const historyCount = document.getElementById('genHistoryCount');

  if (!client) {
    if (resultPlaceholder) {
      resultPlaceholder.innerHTML = 'Selecciona un cliente y presiona <strong>Firmar y Emitir Licencia</strong> para generar el código, el QR y la credencial oficial.';
      resultPlaceholder.style.display = 'block';
    }
    if (resultContent) resultContent.style.display = 'none';
    if (historySec) historySec.style.display = 'none';
    if (badgeStatus) badgeStatus.style.display = 'none';
    return;
  }

  const history = client.generated_codes_history || [];
  if (history.length === 0) {
    if (resultPlaceholder) {
      resultPlaceholder.innerHTML = `El cliente <strong>${escapeHtml(client.business_name)}</strong> aún no tiene licencias Ed25519 emitidas.<br><span style="font-size:0.85rem; color:var(--text-secondary); margin-top:0.4rem; display:inline-block;">Configura un plan a la izquierda y presiona <strong>Firmar Criptográficamente y Emitir Licencia</strong> para emitir su primera credencial oficial.</span>`;
      resultPlaceholder.style.display = 'block';
    }
    if (resultContent) resultContent.style.display = 'none';
    if (historySec) historySec.style.display = 'none';
    if (badgeStatus) badgeStatus.style.display = 'none';
    return;
  }

  // Ordenar historial: el más reciente primero (mayor nonce o timestamp descendente)
  const sorted = [...history].sort((a, b) => {
    const nA = a.nonce !== undefined ? a.nonce : 0;
    const nB = b.nonce !== undefined ? b.nonce : 0;
    if (nB !== nA) return nB - nA;
    const tA = new Date(a.emitted_at || a.created_at || 0).getTime();
    const tB = new Date(b.emitted_at || b.created_at || 0).getTime();
    return tB - tA;
  });

  // Mostrar la licencia más reciente como activa/vigente
  renderSelectedGeneratorLicense(sorted[0], client, true);

  // Renderizar la lista histórica debajo
  if (historySec) historySec.style.display = 'block';
  if (historyCount) historyCount.textContent = sorted.length;
  if (historyList) {
    historyList.innerHTML = '';
    sorted.forEach((item, idx) => {
      const isVigente = idx === 0;
      const itemEl = document.createElement('div');
      itemEl.className = `gen-history-item ${isVigente ? 'active' : ''}`;
      const dateStr = (item.emitted_at || item.created_at || '').substring(0, 10) || '-';
      const planStr = (item.plan || 'MENSUAL').replace(/_/g, ' ');
      const nonceStr = item.nonce !== undefined ? `#${item.nonce}` : '';
      const aiVal = item.ai_credits ?? item.ai_extra_credits ?? 0;
      const aiBadge = aiVal > 0 ? `<span class="badge badge-purple" style="font-size:0.7rem; padding:1px 6px; margin-left:0.4rem;">+${aiVal} IA</span>` : '';

      itemEl.innerHTML = `
        <div style="display:flex; justify-content:space-between; align-items:center; width:100%;">
          <div>
            <strong style="color:var(--text-primary); font-size:0.85rem;">${escapeHtml(planStr)} ${nonceStr}</strong>
            <span style="font-size:0.75rem; color:var(--text-muted); margin-left:0.4rem;">${dateStr}</span>
            ${aiBadge}
          </div>
          <span class="badge ${isVigente ? 'badge-green' : 'badge-gray'}" style="font-size:0.72rem;">
            ${isVigente ? 'Vigente' : 'Histórica'}
          </span>
        </div>
      `;

      itemEl.addEventListener('click', () => {
        document.querySelectorAll('.gen-history-item').forEach(el => el.classList.remove('active'));
        itemEl.classList.add('active');
        renderSelectedGeneratorLicense(item, client, isVigente);
      });

      historyList.appendChild(itemEl);
    });
  }
}

function downloadQrCode() {
  downloadQrWithQuietZone('#qrContainer', `QR_MochilaLista_${Date.now()}.png`, 32);
}

// =================== MODAL RÁPIDO: VER QR / CREDENCIAL (FASE 4A) ===================
async function openQuickQrModal(clientId) {
  currentQuickQrClientId = clientId;
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  const titleEl = document.getElementById('quickQrTitle');
  const subEl = document.getElementById('quickQrSubtitle');
  if (titleEl) titleEl.textContent = `${client.business_name} — Credencial Oficial`;
  if (subEl) subEl.textContent = `Titular: ${client.owner_name} • Hardware ID: ${client.current_device_id} • Plan: ${(client.license_type || 'MENSUAL').replace(/_/g, ' ')}`;

  let token = '';
  let licenseData = {
    plan: client.license_type || 'MENSUAL',
    device_id: client.current_device_id,
    ai_extra_credits: client.ai_extra_credits || 0,
    client: client,
  };

  try {
    const res = await fetch(`/api/clients/${clientId}/history`);
    if (res.ok) {
      const history = await res.json();
      if (history.codes && history.codes.length > 0) {
        const lastCode = history.codes[history.codes.length - 1];
        token = lastCode.token;
        licenseData.token = token;
        licenseData.plan = lastCode.plan || licenseData.plan;
      }
    }
  } catch (err) {
    console.error('Error fetching client history for QR modal:', err);
  }

  if (!token) {
    token = `ML9-PENDIENTE-${client.current_device_id}`;
    licenseData.token = token;
  }

  const qrContainer = document.getElementById('quickQrContainer');
  lastQuickQr = renderSafeQrCode(qrContainer, token, 236);

  document.getElementById('quickQrCodeDisplay').textContent = token;

  setTimeout(() => {
    renderCredentialCanvas(licenseData, client, 'quickCredentialCanvas', 'quickQrContainer');
  }, 150);

  document.getElementById('btnQuickCopyCode').onclick = () => {
    copyPlainTextToClipboard(token, '¡Código copiado al portapapeles!');
  };

  document.getElementById('btnQuickDownloadQr').onclick = () => {
    downloadQrWithQuietZone(qrContainer, `QR_MochilaLista_${client.current_device_id}_${Date.now()}.png`, 32);
  };

  document.getElementById('btnQuickCopyCredential').onclick = async () => {
    const canvas = document.getElementById('quickCredentialCanvas');
    if (!canvas) return;
    try {
      canvas.toBlob(async (blob) => {
        if (!blob) return;
        await copyPngBlobToClipboard(blob, {
          onFallbackDownload: () => {
            const a = document.createElement('a');
            a.download = `Credencial_${client.current_device_id}.png`;
            a.href = canvas.toDataURL('image/png');
            a.click();
          },
          fallbackMsg: 'Credencial descargada como archivo PNG.',
        });
      }, 'image/png');
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  };

  document.getElementById('btnQuickDownloadCredential').onclick = () => {
    const canvas = document.getElementById('quickCredentialCanvas');
    if (!canvas) return;
    const a = document.createElement('a');
    a.download = `Credencial_MochilaLista_${client.current_device_id}_${Date.now()}.png`;
    a.href = canvas.toDataURL('image/png');
    a.click();
    showToast('Credencial oficial PNG descargada.', 'success');
  };

  const tplKey = (client.license_type || '').toUpperCase() === 'TRIAL' ? 'trial_welcome' : 'license_issued';
  const msgText = renderConfigTemplate(tplKey, {
    titular: client.owner_name,
    negocio: client.business_name,
    plan: (client.license_type || 'MENSUAL').replace(/_/g, ' '),
    dias: '30',
    vencimiento: client.license_expires ? client.license_expires.substring(0, 10) : '30 días',
    creditos_ia: client.ai_extra_credits || 0,
    codigo: token,
    device_id: client.current_device_id,
  });
  document.getElementById('btnQuickSendWa').href = buildWhatsAppSendUrl(client.phone, msgText);

  document.getElementById('btnQuickAuditInInspector').onclick = () => {
    closeModal('modalQuickQr');
    const tabs = document.querySelectorAll('.nav-tab');
    tabs.forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

    const inspTab = document.querySelector('[data-tab="tabInspector"]');
    inspTab?.classList.add('active');
    document.getElementById('tabInspector')?.classList.add('active');

    const inp = document.getElementById('inspectTokenInput');
    if (inp) {
      inp.value = token;
      inspectToken();
    }
  };

  openModal('modalQuickQr');
}
