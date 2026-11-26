// =================== HISTORIAL MULTI-PESTAÑA (PAGOS & HARDWARE) ===================
function switchHistoryTab(tabName) {
  activeHistoryTab = tabName;
  const btnPayments = document.getElementById('tabBtnHistoryPayments');
  const btnHardware = document.getElementById('tabBtnHistoryHardware');
  const viewPayments = document.getElementById('historyViewPayments');
  const viewHardware = document.getElementById('historyViewHardware');

  if (tabName === 'payments') {
    btnPayments?.classList.add('active');
    btnHardware?.classList.remove('active');
    if (viewPayments) viewPayments.style.display = 'flex';
    if (viewHardware) viewHardware.style.display = 'none';
  } else {
    btnHardware?.classList.add('active');
    btnPayments?.classList.remove('active');
    if (viewHardware) viewHardware.style.display = 'flex';
    if (viewPayments) viewPayments.style.display = 'none';
  }
}

async function openClientHistoryModal(clientId) {
  try {
    currentHistoryClientId = clientId;
    const res = await fetch(`/api/clients/${clientId}/history`);
    if (!res.ok) throw new Error('Error al cargar historial del cliente');
    const data = await res.json();
    const client = data.client;

    document.getElementById('historyModalTitle').textContent = `Historial Comercial — ${client.business_name}`;
    document.getElementById('historyClientSummary').innerHTML = `
      <strong>Titular:</strong> ${escapeHtml(client.owner_name)} (${escapeHtml(client.document_id || 'Sin doc')})
      • <strong>Dispositivo Actual:</strong> <span class="device-id-badge">${escapeHtml(client.current_device_id)}</span>
      • <strong>Plan:</strong> ${escapeHtml(client.license_type)}
      • <strong>Total Pagado Histórico:</strong> <strong style="color:var(--success);">S/ ${(data.total_paid || 0).toFixed(2)}</strong>
    `;

    // 1. Pagos registrados
    const payBody = document.getElementById('historyPaymentsBody');
    payBody.innerHTML = '';
    if (!data.payments || data.payments.length === 0) {
      payBody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1rem;">Sin pagos registrados</td></tr>';
    } else {
      data.payments.forEach(p => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${p.date ? p.date.substring(0, 10) : '-'}</td>
          <td><strong>S/ ${(p.amount || 0).toFixed(2)}</strong></td>
          <td>${escapeHtml(formatPlanHumanLabel(p.plan || '-'))}${p.updated_at ? ` <span class="badge-edited-payment" title="Pago editado el ${escapeHtml(p.updated_at.substring(0, 10))} ${escapeHtml(p.updated_at.substring(11, 16))} UTC"><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:middle;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg> <span>Editado</span></span>` : ''}</td>
          <td>${escapeHtml(p.method || '-')}</td>
          <td>${escapeHtml(p.reference || '-')}</td>
          <td>
            <button class="btn btn-outline btn-sm" style="color:var(--danger); border-color:var(--danger); font-size:0.75rem; display:inline-flex; align-items:center; gap:0.3rem;" onclick="voidPayment('${client.id}', '${p.id}')" title="Anular transacción">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
              <span>Anular</span>
            </button>
          </td>
        `;
        payBody.appendChild(tr);
      });
    }

    // 2. Códigos Ed25519 Emitidos con Re-descarga de Credencial PNG
    const codesBody = document.getElementById('historyCodesBody');
    codesBody.innerHTML = '';
    if (!data.codes || data.codes.length === 0) {
      codesBody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1rem;">Sin códigos emitidos</td></tr>';
    } else {
      data.codes.forEach((c, idx) => {
        const tr = document.createElement('tr');
        const shortToken = c.token ? `${c.token.substring(0, 18)}...` : '-';
        tr.innerHTML = `
          <td>${c.emitted_at ? c.emitted_at.substring(0, 10) : '-'}</td>
          <td>${escapeHtml(c.plan || '-')}</td>
          <td>+${c.days_added} días</td>
          <td><span class="device-id-badge">${escapeHtml(c.device_id || '-')}</span></td>
          <td><code style="font-family:var(--font-mono); font-size:0.75rem;">${shortToken}</code></td>
          <td>
            <div style="display:flex; gap:0.3rem;">
              <button class="btn btn-outline btn-sm" onclick="copyTokenToClipboard('${escapeHtml(c.token)}')" title="Copiar Token">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
              </button>
              <button class="btn btn-primary btn-sm" onclick="downloadHistoricalCredential(${idx})" title="Descargar Credencial PNG Oficial" style="display:inline-flex; align-items:center; gap:0.3rem;">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><line x1="15" y1="10" x2="19" y2="10"/><line x1="7" y1="15" x2="19" y2="15"/></svg>
                <span>Tarjeta PNG</span>
              </button>
            </div>
          </td>
        `;
        codesBody.appendChild(tr);
      });
    }

    // 3. Pestaña de Hardware y Migraciones
    const hwBox = document.getElementById('historyCurrentDeviceBox');
    hwBox.innerHTML = `
      <div style="font-size:0.85rem; color:var(--text-secondary); margin-bottom:0.25rem;">Dispositivo Actualmente Vinculado:</div>
      <div style="font-size:1.1rem; font-weight:700; color:var(--success); font-family:var(--font-mono); display:flex; align-items:center; gap:0.4rem;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
        <span>${escapeHtml(client.current_device_id)}</span>
      </div>
      <div style="font-size:0.78rem; color:var(--text-muted); margin-top:0.25rem;">
        Versión de la app: v${escapeHtml(client.installed_version || '9.24.0')} • Licencia válida exclusivamente para esta placa.
      </div>
    `;

    const hwBody = document.getElementById('historyHardwareBody');
    hwBody.innerHTML = '';
    if (!data.hardware_history || data.hardware_history.length === 0) {
      hwBody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1rem;">El cliente no ha realizado cambios de teléfono (opera en su dispositivo original).</td></tr>';
    } else {
      data.hardware_history.forEach(h => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td style="white-space: nowrap; min-width: 96px;">${h.migrated_at ? h.migrated_at.substring(0, 10) : '-'}</td>
          <td><span class="device-id-badge" style="opacity:0.7;">${escapeHtml(h.old_device_id)}</span></td>
          <td><span class="device-id-badge" style="color:var(--success);">${escapeHtml(h.new_device_id)}</span></td>
          <td>S/ ${(h.fee_charged || h.fee_amount || 0).toFixed(2)}</td>
          <td>${escapeHtml(h.payment_method || '-')}</td>
          <td>${escapeHtml(h.reason || 'Sin motivo')}</td>
        `;
        hwBody.appendChild(tr);
      });
    }

    // Guardar referencia a códigos para la re-descarga histórica
    window._currentHistoryData = data;

    // Iniciar en la pestaña de pagos
    switchHistoryTab('payments');
    openModal('modalClientHistory');
  } catch (e) {
    showToast('Error al abrir historial: ' + e.message, 'error');
  }
}

function downloadHistoricalCredential(codeIndex) {
  const data = window._currentHistoryData;
  if (!data || !data.codes || !data.codes[codeIndex]) return;
  const c = data.codes[codeIndex];
  const client = data.client;

  // Renderizar en el canvas oculto
  renderCredentialCanvas({
    token: c.token,
    plan: c.plan,
    device_id: c.device_id,
    days_added: c.days_added,
    expires_result: c.expires_result,
    client: client,
  }, client, 'historyCredentialCanvas');

  const canvas = document.getElementById('historyCredentialCanvas');
  if (!canvas) return;

  const nameClean = (client.business_name || 'Licencia').replace(/[^a-zA-Z0-9]/g, '_');
  const link = document.createElement('a');
  link.download = `Credencial_MochilaLista_${nameClean}_${c.plan}_${Date.now()}.png`;
  link.href = canvas.toDataURL('image/png');
  link.click();
  showToast('Credencial histórica descargada en PNG @2x.', 'success');
}

function copyTokenToClipboard(token) {
  copyPlainTextToClipboard(token, '¡Token copiado al portapapeles!', {
    errorMessage: 'Token copiado.',
    errorType: 'info',
  });
}

function voidPayment(clientId, paymentId) {
  showConfirmModal(
    'Anular Pago Registrado',
    '¿Estás seguro de anular y eliminar este registro de pago? Se descontará del total histórico cobrado del cliente.',
    async () => {
      try {
        const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}`, {
          method: 'DELETE',
        });
        if (!res.ok) throw new Error('Error al anular pago');
        showToast('Pago anulado con éxito.', 'success');
        await openClientHistoryModal(clientId);
        await loadClients();
        await loadDashboard();
        await loadFinances();
      } catch (e) {
        showToast('Error: ' + e.message, 'error');
      }
    },
    true
  );
}

// =================== FLUJOS DE 1 SOLO PASO (FASE 4A / REINGENIERÍA FASE 3) ===================
async function handleCreateClient(andEmit = false) {
  const situation = document.getElementById('newClientSituation')?.value || 'TRIAL';
  const biz = document.getElementById('newBizName').value.trim();
  const owner = document.getElementById('newOwnerName').value.trim();
  const doc = document.getElementById('newDocId').value.trim();
  const rawPhone = document.getElementById('newPhone').value.trim();
  const phone = normalizePeruPhone(rawPhone);
  let device = document.getElementById('newDeviceId').value.trim().toUpperCase();
  const deviceModel = document.getElementById('newDeviceModel')?.value.trim() || '';
  const installedVer = document.getElementById('newInstalledVersion').value.trim() || '9.35.0';
  const aiReported = parseInt(document.getElementById('newAiReportedBalance').value) || 0;
  const aiBonus = parseInt(document.getElementById('newAiPendingBonus').value) || 0;
  const trialDays = parseInt(document.getElementById('newTrialDaysRemaining')?.value) || 30;
  const expectedSubDate = document.getElementById('newExpectedSubscriptionDate')?.value || null;
  const followupDate = document.getElementById('newFollowupDate')?.value || null;
  const notes = document.getElementById('newNotes').value.trim();

  let plan = 'TRIAL';
  if (situation === 'PROSPECTO') {
    plan = 'PROSPECTO';
    if (!device) device = 'PENDIENTE';
  } else if (situation === 'TRIAL') {
    plan = 'TRIAL';
  } else { // COMMERCIAL
    plan = document.getElementById('newPlan').value;
  }

  // Validaciones según situación
  if (!biz || !owner || !phone) {
    showToast('Por favor completa los campos obligatorios: Negocio, Titular y Teléfono WhatsApp.', 'warning');
    return;
  }

  if (situation !== 'PROSPECTO' && (!device || device === 'PENDIENTE')) {
    showToast('Para clientes con app instalada o licencia comercial, el Hardware ID es obligatorio.', 'warning');
    return;
  }

  try {
    const res = await fetch('/api/clients', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        business_name: biz,
        owner_name: owner,
        document_id: doc,
        phone: phone,
        current_device_id: device,
        device_model: deviceModel,
        license_type: plan,
        license_status: situation === 'PROSPECTO' ? 'PROSPECTO' : (plan.includes('PERPETU') ? 'PERPETUA' : 'ACTIVA'),
        installed_version: installedVer,
        ai_reported_balance: aiReported,
        ai_pending_bonus: aiBonus,
        ai_extra_credits: 0,
        trial_days_remaining: situation === 'TRIAL' ? trialDays : null,
        expected_subscription_date: situation === 'PROSPECTO' ? expectedSubDate : null,
        next_followup_date: followupDate,
        notes: notes,
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Error al registrar cliente');
    }

    const createdClient = await res.json();
    closeModal('modalCreateClient');
    document.getElementById('formCreateClient').reset();
    const notice = document.getElementById('noticeAiBonus');
    if (notice) notice.style.display = 'none';

    await loadClients();
    await loadDashboard();

    if (andEmit && createdClient && createdClient.id) {
      showToast(`¡Cliente "${biz}" guardado! Abriendo Generador de Licencias...`, 'success');
      const hasBonus = (createdClient.ai_pending_bonus || 0) > 0;
      selectClientForLicense(createdClient.id, { preferBonus: hasBonus });
      const curView = document.getElementById('currentViewName');
      if (curView) curView.textContent = 'Generar Licencia';
    } else {
      showToast(`Cliente "${biz}" registrado con éxito.`, 'success');
    }
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

async function handleMigrateDeviceSubmit() {
  const clientId = document.getElementById('migClientId').value;
  const newDeviceId = document.getElementById('migNewDeviceId').value.trim().toUpperCase();
  const newDeviceModel = document.getElementById('migNewDeviceModel')?.value.trim() || '';
  const scenario = document.getElementById('migScenario')?.value || 'RESTORED_BACKUP';
  const feeMode = document.getElementById('migFeeMode')?.value || 'STANDARD';
  const fee = feeMode === 'FREE' ? 0.0 : (parseFloat(document.getElementById('migFee').value) || 0);
  const method = feeMode === 'FREE' ? 'Gratuito / Cortesía' : document.getElementById('migPaymentMethod').value;
  const ref = document.getElementById('migPaymentRef')?.value.trim() || '';
  const reason = document.getElementById('migReason').value.trim();
  const emitImmediately = document.getElementById('migEmitImmediately')?.checked ?? true;
  const shouldGenReceipt = document.getElementById('migGenerateReceipt')?.checked ?? false;

  if (!newDeviceId) {
    showToast('Por favor ingresa el nuevo Hardware ID (ML-YYYY).', 'warning');
    return;
  }

  try {
    const res = await fetch(`/api/clients/${clientId}/migrate-device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        new_device_id: newDeviceId,
        device_model: newDeviceModel,
        fee_mode: feeMode,
        fee_amount: fee,
        payment_method: method,
        payment_reference: ref,
        reason: reason,
        emit_immediately: emitImmediately,
        migration_scenario: scenario,
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Error al migrar dispositivo');
    }

    const data = await res.json();
    await loadClients();
    await loadDashboard();

    const client = globalClients.find(c => c.id === clientId) || data;

    if (emitImmediately && data.emitted_migration_token) {
      const token = data.emitted_migration_token;
      const form = document.getElementById('formMigrateDevice');
      if (form) form.style.display = 'none';

      const successBox = document.getElementById('migSuccessInline');
      if (successBox) successBox.style.display = 'block';

      const devEl = document.getElementById('migSuccessNewDev');
      if (devEl) devEl.textContent = newDeviceId;

      const codeEl = document.getElementById('migSuccessCode');
      if (codeEl) codeEl.textContent = token;

      const qrBox = document.getElementById('migSuccessQrContainer');
      if (qrBox) {
        renderSafeQrCode(qrBox, token, 170);
      }

      document.getElementById('btnMigCopyCode').onclick = () => {
        copyPlainTextToClipboard(token, '¡Código de migración copiado al portapapeles!');
      };

      const msgText = renderConfigTemplate('device_migration', {
        titular: client.owner_name,
        negocio: client.business_name,
        device_id: newDeviceId,
        vencimiento: (client.license_expires || '').substring(0, 10),
        creditos_ia: client.ai_extra_credits || 0,
        codigo: token,
      });
      document.getElementById('btnMigSendWa').href = buildWhatsAppSendUrl(client.phone, msgText);

      // Botón para generar boleta si se registró cobro de tarifa
      const receiptBtn = document.getElementById('btnMigViewReceipt');
      if (data.payment_id && receiptBtn) {
        receiptBtn.style.display = 'inline-flex';
        receiptBtn.onclick = () => {
          openPaymentReceiptModal(clientId, data.payment_id);
        };
      } else if (receiptBtn) {
        receiptBtn.style.display = 'none';
      }

      const footer = document.getElementById('migModalFooter');
      if (footer) {
        footer.innerHTML = `
          <button type="button" class="btn btn-primary" onclick="closeModal('modalMigrateDevice')">Aceptar y Cerrar</button>
        `;
      }
      showToast(`¡Dispositivo migrado y token emitido para ${newDeviceId}!`, 'success');
    } else {
      closeModal('modalMigrateDevice');
      showToast(`¡Dispositivo migrado a ${newDeviceId}! Emite ahora su licencia en el Generador.`, 'success');
      selectClientForLicense(clientId);
      if (shouldGenReceipt && data.payment_id) {
        openPaymentReceiptModal(clientId, data.payment_id);
      }
    }
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

function openMigrateModal(clientId, options = {}) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  document.getElementById('migClientId').value = client.id;
  document.getElementById('migClientName').value = `${client.business_name} (${client.owner_name})`;
  document.getElementById('migOldDeviceId').value = client.current_device_id || '';
  document.getElementById('migNewDeviceId').value = options.newDeviceId || '';
  document.getElementById('migNewDeviceModel').value = options.newDeviceModel || '';

  // Poblar Tarjeta Resumen de Preservación
  const planEl = document.getElementById('migPreservePlan');
  if (planEl) planEl.textContent = client.license_type || 'MENSUAL';

  const expEl = document.getElementById('migPreserveExpires');
  if (expEl) {
    if (client.license_expires) {
      const expDate = new Date(client.license_expires);
      const now = new Date();
      const days = Math.max(0, Math.ceil((expDate - now) / 86400000));
      expEl.textContent = `${client.license_expires.substring(0, 10)} • ${days} días restantes`;
    } else {
      expEl.textContent = 'Sin vencimiento';
    }
  }

  const aiEl = document.getElementById('migPreserveAi');
  if (aiEl) {
    const totalAi = (client.ai_reported_balance || 0) + (client.ai_extra_bonus || 0);
    aiEl.textContent = `+${totalAi} escaneos`;
  }

  const updatesWrapper = document.getElementById('migPreserveUpdatesWrapper');
  const updatesEl = document.getElementById('migPreserveUpdates');
  if (client.updates_until && updatesWrapper && updatesEl) {
    updatesWrapper.style.display = 'flex';
    updatesEl.textContent = client.updates_until.substring(0, 10);
  } else if (updatesWrapper) {
    updatesWrapper.style.display = 'none';
  }

  // Escenario por defecto o prellenado desde rescate
  const scenarioSel = document.getElementById('migScenario');
  if (scenarioSel) scenarioSel.value = options.scenario || 'RESTORED_BACKUP';
  const hint = document.getElementById('migScenarioHint');
  if (hint) {
    hint.textContent = 'Recomendado si el cliente restauró su copia de Google Drive o .mlbg: reactiva el nuevo equipo preservando exactamente su vencimiento con cero duplicación de días.';
  }

  // Modalidad de cobro
  const feeModeSel = document.getElementById('migFeeMode');
  if (feeModeSel) feeModeSel.value = 'STANDARD';
  const customFeeGroup = document.getElementById('migCustomFeeGroup');
  if (customFeeGroup) customFeeGroup.style.display = 'none';
  const payGroup = document.getElementById('migPaymentFieldsGroup');
  if (payGroup) payGroup.style.display = 'block';

  const migDefault = (ownerConfig?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
    ? ownerConfig.catalog.HARDWARE_MIGRATION_FEE.price
    : (ownerConfig?.migration_fee || 40.0);
  document.getElementById('migFee').value = Number(migDefault).toFixed(2);
  document.getElementById('migPaymentMethod').value = 'Yape';
  document.getElementById('migPaymentRef').value = '';
  document.getElementById('migReason').value = '';

  const genReceiptChk = document.getElementById('migGenerateReceipt');
  if (genReceiptChk) genReceiptChk.checked = true;

  const emitCb = document.getElementById('migEmitImmediately');
  if (emitCb) emitCb.checked = true;

  const form = document.getElementById('formMigrateDevice');
  if (form) form.style.display = 'flex';

  const successBox = document.getElementById('migSuccessInline');
  if (successBox) successBox.style.display = 'none';

  const qrBox = document.getElementById('migSuccessQrContainer');
  if (qrBox) qrBox.innerHTML = '';

  const receiptBtn = document.getElementById('btnMigViewReceipt');
  if (receiptBtn) receiptBtn.style.display = 'none';

  const footer = document.getElementById('migModalFooter');
  if (footer) {
    footer.innerHTML = `
      <button type="button" class="btn btn-outline" onclick="closeModal('modalMigrateDevice')">Cancelar</button>
      <button type="button" class="btn btn-primary" id="btnSubmitMigrateDevice">Confirmar Migración</button>
    `;
    document.getElementById('btnSubmitMigrateDevice')?.addEventListener('click', handleMigrateDeviceSubmit);
  }

  openModal('modalMigrateDevice');
}
