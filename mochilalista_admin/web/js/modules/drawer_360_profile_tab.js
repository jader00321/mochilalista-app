async function openClient360Drawer(clientId) {
  const initialTab = arguments[1] || 'drawerTabOverview';
  currentDrawerClientId = clientId;
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  // Activar pestaña solicitada de inmediato (con soporte para alias drawerTabSummary)
  const targetTabId = (initialTab === 'drawerTabSummary') ? 'drawerTabOverview' : initialTab;
  switchDrawerTab(targetTabId);

  // Cabecera Ficha 360°
  document.getElementById('drawerBizName').textContent = client.business_name || 'Sin Nombre';
  document.getElementById('drawerOwnerName').textContent = client.owner_name || '-';
  document.getElementById('drawerDeviceId').textContent = client.current_device_id || 'PENDIENTE';

  const statusBadge = document.getElementById('drawerStatusBadge');
  const badgeInfo = getClientStatusBadge(client, { asObject: true });
  if (statusBadge) {
    statusBadge.className = badgeInfo.className;
    statusBadge.textContent = badgeInfo.text;
  }
  const isProspect = badgeInfo.isProspect;
  const isTrial = badgeInfo.isTrial;
  const isPerp = badgeInfo.isPerp;
  const plan = (client.license_type || 'MENSUAL').toUpperCase();

  // Pestaña 1: Resumen y Licencia
  document.getElementById('drawerKpiPlan').textContent = isProspect ? 'Prospecto' : formatPlanHumanLabel(client.license_type);
  document.getElementById('drawerKpiExpires').textContent = isProspect
    ? (client.expected_subscription_date ? `Seguimiento: ${client.expected_subscription_date}` : 'Sin vencimiento')
    : (isPerp ? 'De por Vida' : (client.license_expires ? client.license_expires.substring(0, 10) : 'Sin fecha'));

  const realAi = (client.ai_reported_balance !== undefined && client.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client.ai_accumulated_credits ?? client.ai_extra_credits ?? 0);
  const pendingAi = client.ai_pending_bonus || 0;

  document.getElementById('drawerKpiAiCredits').textContent = `${realAi} IA`;
  document.getElementById('drawerKpiVersion').textContent = `v${client.installed_version || '9.35.0'}`;
  
  const drawerKpiUpdates = document.getElementById('drawerBoxUpdates')?.querySelector('.drawer-kpi-val') || document.getElementById('drawerKpiUpdates');
  if (drawerKpiUpdates) {
    if (isPerp || plan === 'PASE_ACTUALIZACION_ANUAL') {
      drawerKpiUpdates.textContent = client.updates_until ? client.updates_until.substring(0, 10) : 'Vigente';
    } else if (isProspect || isTrial) {
      drawerKpiUpdates.textContent = 'No aplica';
    } else {
      drawerKpiUpdates.textContent = 'Incluido en suscripción';
    }
  }

  document.getElementById('drawerPhone').textContent = formatPeruvianPhoneDisplay(client.phone);
  document.getElementById('drawerDocId').textContent = client.document_id || '-';
  const drawerDeviceModel = document.getElementById('drawerDeviceModel');
  if (drawerDeviceModel) {
    drawerDeviceModel.textContent = client.device_model || 'No registrado';
  }
  const drawerAiBreakdown = document.getElementById('drawerAiBreakdown');
  if (drawerAiBreakdown) {
    const usedAi = client.ai_credits_used_total ?? 0;
    const deltaAi = client.ai_credits_used_delta ?? 0;
    const deltaTxt = deltaAi > 0 ? ` (+${deltaAi} reciente)` : '';
    drawerAiBreakdown.textContent = `En celular: ${realAi} IA | Consumidos: ${usedAi} IA${deltaTxt} | Bono pend: +${pendingAi} IA`;
  }
  const drawerLastSync = document.getElementById('drawerLastSync');
  if (drawerLastSync) {
    if (client.last_sync_at) {
      drawerLastSync.textContent = formatLimaDateTime(client.last_sync_at);
      drawerLastSync.title = `UTC: ${client.last_sync_at}`;
    } else {
      drawerLastSync.textContent = 'Nunca sincronizado';
      drawerLastSync.title = '';
    }
  }
  const drawerBackupDrive = document.getElementById('drawerBackupDrive');
  if (drawerBackupDrive) {
    if (client.backup_drive_linked) {
      const bh = humanizeSyncFieldValue('backup_health_status', client.backup_health_status || 'OK');
      drawerBackupDrive.textContent = `Vinculado (${bh})`;
    } else {
      drawerBackupDrive.textContent = 'No vinculado';
    }
  }
  const drawerProfilesCount = document.getElementById('drawerProfilesCount');
  if (drawerProfilesCount) {
    drawerProfilesCount.textContent = (client.profiles_count !== undefined && client.profiles_count !== null)
      ? String(client.profiles_count)
      : '-';
  }
  const drawerUltimoNonce = document.getElementById('drawerUltimoNonce');
  if (drawerUltimoNonce) {
    drawerUltimoNonce.textContent = (client.ultimo_nonce !== undefined && client.ultimo_nonce !== null)
      ? `#${client.ultimo_nonce}`
      : 'Sin reporte';
  }
  const drawerFollowup = document.getElementById('drawerFollowup');
  if (drawerFollowup) {
    if (client.next_followup_date) {
      const todayStr = getLocalIsoDate();
      if (client.next_followup_date < todayStr) {
        drawerFollowup.innerHTML = `<span style="color:var(--danger); font-weight:700;">Vencido (${escapeHtml(client.next_followup_date)})</span>`;
      } else if (client.next_followup_date === todayStr) {
        drawerFollowup.innerHTML = `<span style="color:var(--warning); font-weight:700;">¡Hoy! (${escapeHtml(client.next_followup_date)})</span>`;
      } else {
        drawerFollowup.innerHTML = `<span style="color:var(--primary); font-weight:600;">Programado (${escapeHtml(client.next_followup_date)})</span>`;
      }
    } else {
      drawerFollowup.textContent = 'Sin programar';
    }
  }
  document.getElementById('drawerNotes').textContent = client.notes || 'Sin observaciones registradas.';

  // Pestaña 4: Hardware Actual (Caja Superior)
  document.getElementById('drawerCurrentDevIdDisplay').textContent = client.current_device_id || 'PENDIENTE';
  const drawerHwModelDisplay = document.getElementById('drawerHwModelDisplay');
  if (drawerHwModelDisplay) {
    drawerHwModelDisplay.textContent = client.device_model || 'No registrado';
  }
  const drawerHwVersionDisplay = document.getElementById('drawerHwVersionDisplay');
  if (drawerHwVersionDisplay) {
    const latestVer = getLatestPublishedVersion();
    const clientVer = (client.installed_version || '').trim();
    let badgeHtml = '';
    if (isProspect || !clientVer) {
      badgeHtml = '<span class="badge badge-outline" style="font-size:0.68rem; padding:1px 6px; margin-left:4px; color:var(--text-muted);">Sin versión</span>';
    } else if (!latestVer) {
      badgeHtml = '<span class="badge badge-green" style="font-size:0.68rem; padding:1px 6px; margin-left:4px;">Al día</span>';
    } else if (compareSemVer(clientVer, latestVer) < 0) {
      badgeHtml = '<span class="badge badge-yellow" style="font-size:0.68rem; padding:1px 6px; margin-left:4px;">Update pend.</span>';
    } else {
      badgeHtml = '<span class="badge badge-green" style="font-size:0.68rem; padding:1px 6px; margin-left:4px;">Al día</span>';
    }
    drawerHwVersionDisplay.innerHTML = `<code>v${escapeHtml(client.installed_version || '9.35.0')}</code> ${badgeHtml}`;
  }
  const drawerHwNonceDisplay = document.getElementById('drawerHwNonceDisplay');
  if (drawerHwNonceDisplay) {
    drawerHwNonceDisplay.textContent = client.next_nonce || 1;
  }
  const drawerHwLinkedDateDisplay = document.getElementById('drawerHwLinkedDateDisplay');
  if (drawerHwLinkedDateDisplay) {
    drawerHwLinkedDateDisplay.textContent = client.created_at ? client.created_at.substring(0, 10) : 'Al registrar';
  }

  // Pestaña 5: Edición Rápida Form Pre-fill
  document.getElementById('drawerEditClientId').value = client.id;
  document.getElementById('drawerEditBizName').value = client.business_name || '';
  document.getElementById('drawerEditOwnerName').value = client.owner_name || '';
  document.getElementById('drawerEditDocId').value = client.document_id || '';
  document.getElementById('drawerEditPhone').value = client.phone || '';
  document.getElementById('drawerEditDeviceId').value = client.current_device_id || '';
  const editDevModel = document.getElementById('drawerEditDeviceModel');
  if (editDevModel) editDevModel.value = client.device_model || '';
  const editPlanSel = document.getElementById('drawerEditPlanSelect');
  if (editPlanSel) editPlanSel.value = client.license_type || 'MENSUAL';
  updateDrawerEditPlanFields(client.license_type);
  document.getElementById('drawerEditInstalledVersion').value = client.installed_version || '9.35.0';
  const editExpires = document.getElementById('drawerEditExpires');
  if (editExpires) editExpires.value = client.license_expires ? client.license_expires.substring(0, 10) : '';
  const editUpdates = document.getElementById('drawerEditUpdates');
  if (editUpdates) editUpdates.value = client.updates_until ? client.updates_until.substring(0, 10) : '';
  const editAiRep = document.getElementById('drawerEditAiReported');
  if (editAiRep) editAiRep.value = client.ai_reported_balance || 0;
  const editAiBonus = document.getElementById('drawerEditAiPendingBonus');
  if (editAiBonus) editAiBonus.value = client.ai_pending_bonus || 0;
  const editFollowup = document.getElementById('drawerEditFollowupDate');
  if (editFollowup) editFollowup.value = client.next_followup_date ? client.next_followup_date.substring(0, 10) : '';
  document.getElementById('drawerEditNotes').value = client.notes || '';

  try {
    const res = await fetch(`/api/clients/${clientId}/history`);
    if (res.ok) {
      const history = await res.json();

      // --- PESTAÑA 3: PAGOS & FINANZAS (Tarjetas Compactas - Cero Scroll Horizontal) ---
      let totalPaid = 0;
      const methodCounts = {};
      let lastDate = '-';
      const paymentsBody = document.getElementById('drawerPaymentsBody');
      if (paymentsBody) paymentsBody.innerHTML = '';

      const payments = history.payments || [];
      if (payments.length > 0 && paymentsBody) {
        payments.forEach(p => {
          const amt = parseFloat(p.amount) || 0;
          totalPaid += amt;
          const m = p.method || 'Otro';
          methodCounts[m] = (methodCounts[m] || 0) + 1;
          const pDate = p.date ? p.date.substring(0, 10) : '-';
          if (lastDate === '-' || (pDate !== '-' && pDate > lastDate)) {
            lastDate = pDate;
          }

          const card = document.createElement('div');
          card.className = 'drawer-payment-card';
          card.innerHTML = `
            <div class="dpc-row-top">
              <div class="dpc-concept-wrap" style="display:flex; align-items:center; gap:0.4rem; flex-wrap:wrap;">
                <span class="dpc-date">${escapeHtml(pDate)}</span>
                <span class="badge badge-mono">${escapeHtml(formatPlanHumanLabel(p.plan || '-'))}</span>
                ${p.updated_at ? `
                  <span class="badge-edited-payment" title="Pago editado el ${escapeHtml(p.updated_at.substring(0, 10))} ${escapeHtml(p.updated_at.substring(11, 16))} UTC">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:middle;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                    <span>Editado</span>
                  </span>
                ` : ''}
                ${p.receipt_number ? `
                  <button type="button" class="btn-micro-receipt" onclick="openPaymentReceiptModal('${clientId}', '${p.id}')" title="Ver / Reimprimir Comprobante Oficial">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:middle; margin-right:2px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
                    <span>${escapeHtml(p.receipt_number)}</span>
                  </button>
                ` : ''}
              </div>
              <div class="dpc-amount">S/ ${amt.toFixed(2)}</div>
            </div>
            <div class="dpc-row-mid">
              <span class="dpc-method">${escapeHtml(p.method || 'Medio no esp.')}</span>
              <span class="dpc-ref">${escapeHtml(p.reference || p.notes || '-')}</span>
            </div>
            <div class="dpc-row-actions">
              <button type="button" class="btn btn-outline btn-xs btn-pay-receipt" title="Emitir Boleta de Pago">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:12px; height:12px; margin-right:3px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
                Boleta
              </button>
              <button type="button" class="btn btn-outline btn-xs btn-pay-edit" title="Editar Pago">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:12px; height:12px; margin-right:3px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                Editar
              </button>
              <button type="button" class="btn btn-outline btn-xs btn-action-danger btn-pay-delete" title="Eliminar Pago">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:12px; height:12px; margin-right:3px;"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                Eliminar
              </button>
            </div>
          `;

          card.querySelector('.btn-pay-receipt').onclick = () => openPaymentReceiptModal(clientId, p.id);
          card.querySelector('.btn-pay-edit').onclick = () => openEditPaymentModal(clientId, p);
          card.querySelector('.btn-pay-delete').onclick = () => confirmDeletePayment(clientId, p.id);
          paymentsBody.appendChild(card);
        });
      } else if (paymentsBody) {
        paymentsBody.innerHTML = `
          <div class="drawer-payment-card" style="text-align:center; padding:1.5rem; color:var(--text-muted); font-size:0.85rem;">
            Sin pagos registrados para este cliente.
          </div>
        `;
      }

      // Calcular medio más frecuente
      let topMethod = '-';
      let maxCount = 0;
      for (const [meth, cnt] of Object.entries(methodCounts)) {
        if (cnt > maxCount) {
          maxCount = cnt;
          topMethod = meth;
        }
      }

      document.getElementById('drawerKpiTotalPaid').textContent = `S/ ${totalPaid.toFixed(2)}`;
      const drawerPayKpiTotal = document.getElementById('drawerPayKpiTotal');
      if (drawerPayKpiTotal) drawerPayKpiTotal.textContent = `S/ ${totalPaid.toFixed(2)}`;
      const drawerPayKpiCount = document.getElementById('drawerPayKpiCount');
      if (drawerPayKpiCount) drawerPayKpiCount.textContent = `${payments.length}`;
      const drawerPayKpiLastDate = document.getElementById('drawerPayKpiLastDate');
      if (drawerPayKpiLastDate) drawerPayKpiLastDate.textContent = lastDate;
      const drawerPayKpiMethod = document.getElementById('drawerPayKpiMethod');
      if (drawerPayKpiMethod) drawerPayKpiMethod.textContent = topMethod;

      // --- PESTAÑA 2: QR & CREDENCIAL OFICIAL ---
      const codes = (history.codes && history.codes.length > 0) ? history.codes : (client.generated_codes_history || []);
      const emptyState = document.getElementById('drawerQrEmptyState');
      const qrContent = document.getElementById('drawerQrContent');
      const selectorContainer = document.getElementById('drawerQrSelectorContainer');
      const codeSelector = document.getElementById('drawerQrCodeSelector');

      if (!codes || codes.length === 0) {
        if (emptyState) emptyState.style.display = 'flex';
        if (qrContent) qrContent.style.display = 'none';
      } else {
        if (emptyState) emptyState.style.display = 'none';
        if (qrContent) qrContent.style.display = 'flex';

        const renderSelectedDrawerLicense = (selectedCode, selectedIdx) => {
          const token = selectedCode.token;
          document.getElementById('drawerCodeDisplay').textContent = token;
          renderSafeQrCode('drawerQrContainer', token, 196);

          // Metadatos precisos sin desincronización (Directo del objeto emitido)
          const metaPlan = document.getElementById('drawerQrMetaPlan');
          if (metaPlan) metaPlan.textContent = (selectedCode.plan || client.license_type || 'MENSUAL').replace(/_/g, ' ');

          const codeDate = selectedCode.created_at || selectedCode.emitted_at;
          const metaEmitted = document.getElementById('drawerQrMetaEmitted');
          if (metaEmitted) metaEmitted.textContent = codeDate ? codeDate.substring(0, 10) : '-';

          const codeExp = selectedCode.expires_at || selectedCode.expires_result;
          const metaExpires = document.getElementById('drawerQrMetaExpires');
          if (metaExpires) metaExpires.textContent = codeExp ? codeExp.substring(0, 10) : (client.license_expires ? client.license_expires.substring(0, 10) : 'Activa');

          const codeNonce = selectedCode.nonce ?? selectedCode.n ?? (selectedIdx !== undefined ? selectedIdx + 1 : (codes.indexOf(selectedCode) + 1));
          const metaNonce = document.getElementById('drawerQrMetaNonce');
          if (metaNonce) metaNonce.textContent = codeNonce;

          const codeAi = selectedCode.ai_credits ?? selectedCode.total_ai_credited ?? selectedCode.base_ai_credits ?? 0;
          const metaAi = document.getElementById('drawerQrMetaAi');
          if (metaAi) metaAi.textContent = `+${codeAi} IA`;

          const metaDevice = document.getElementById('drawerQrMetaDevice');
          if (metaDevice) metaDevice.textContent = selectedCode.device_id || client.current_device_id || '-';

          // Botones de acción en QR & Credencial
          document.getElementById('btnDrawerCopyCode').onclick = () => {
            copyPlainTextToClipboard(token, '¡Código copiado al portapapeles!');
          };

          const btnCopyCred = document.getElementById('btnDrawerCopyCredential');
          if (btnCopyCred) {
            btnCopyCred.onclick = () => {
              renderCredentialCanvas({
                token: selectedCode.token,
                plan: selectedCode.plan || client.license_type,
                device_id: selectedCode.device_id || client.current_device_id,
                days_added: selectedCode.days_added,
                expires_result: selectedCode.expires_at || selectedCode.expires_result || client.license_expires,
                client: client,
              }, client, 'historyCredentialCanvas', 'drawerQrContainer');

              const canvas = document.getElementById('historyCredentialCanvas');
              if (canvas && canvas.toBlob) {
                canvas.toBlob(async (blob) => {
                  if (!blob) {
                    showToast('Error al generar imagen de la credencial', 'error');
                    return;
                  }
                  await copyPngBlobToClipboard(blob, {
                    successMsg: '¡Imagen de la credencial copiada! Pégala en WhatsApp con Ctrl+V.',
                    fallbackMsg: 'Tu navegador no permite copiar imágenes al portapapeles. Usa "Descargar Tarjeta".',
                  });
                }, 'image/png');
              }
            };
          }

          document.getElementById('btnDrawerDownloadCredential').onclick = () => {
            renderCredentialCanvas({
              token: selectedCode.token,
              plan: selectedCode.plan || client.license_type,
              device_id: selectedCode.device_id || client.current_device_id,
              days_added: selectedCode.days_added,
              expires_result: selectedCode.expires_at || selectedCode.expires_result || client.license_expires,
              client: client,
            }, client, 'historyCredentialCanvas', 'drawerQrContainer');

            const canvas = document.getElementById('historyCredentialCanvas');
            if (canvas) {
              const nameClean = (client.business_name || 'Licencia').replace(/[^a-zA-Z0-9]/g, '_');
              const link = document.createElement('a');
              link.download = `Credencial_${nameClean}_${selectedCode.plan || 'Oficial'}.png`;
              link.href = canvas.toDataURL('image/png');
              link.click();
              showToast('Credencial descargada en PNG @2x.', 'success');
            }
          };

          document.getElementById('btnDrawerDownloadQr').onclick = () => {
            downloadQrWithQuietZone('#drawerQrContainer', `QR_${client.current_device_id}_N${codeNonce}.png`, 32);
          };

          document.getElementById('btnDrawerAuditInspector').onclick = () => {
            auditTokenInInspector(token);
          };

          document.getElementById('btnDrawerSendWa').onclick = () => {
            openWhatsAppComposer(client.id, 'license');
          };

          const btnQrNew = document.getElementById('btnDrawerQrNewLicense');
          if (btnQrNew) {
            btnQrNew.onclick = () => {
              drawerReturnState = null;
              closeClient360Drawer();
              selectClientForLicense(client.id);
            };
          }
        };

        // Configurar selector histórico ordenado de la más reciente a la más antigua
        if (codes.length > 1) {
          if (selectorContainer) selectorContainer.style.display = 'block';
          if (codeSelector) {
            codeSelector.innerHTML = '';
            const reversed = codes.map((c, originalIdx) => ({ c, originalIdx })).reverse();
            reversed.forEach(({ c, originalIdx }) => {
              const opt = document.createElement('option');
              opt.value = originalIdx;
              const cDate = (c.created_at || c.emitted_at) ? (c.created_at || c.emitted_at).substring(0, 10) : '';
              const nonceVal = c.nonce ?? c.n ?? (originalIdx + 1);
              const isLatest = (originalIdx === codes.length - 1);
              const vigTag = isLatest ? ' [Vigente]' : '';
              const planName = (c.plan || 'LICENCIA').replace(/_/g, ' ');
              opt.textContent = `${planName} • Nonce #${nonceVal} • ${cDate}${vigTag}`;
              if (isLatest) opt.selected = true;
              codeSelector.appendChild(opt);
            });
            codeSelector.onchange = () => {
              const selectedIdx = parseInt(codeSelector.value);
              if (codes[selectedIdx]) renderSelectedDrawerLicense(codes[selectedIdx], selectedIdx);
            };
          }
        } else {
          if (selectorContainer) selectorContainer.style.display = 'none';
        }

        // Renderizar la última licencia por defecto
        renderSelectedDrawerLicense(codes[codes.length - 1], codes.length - 1);
      }

      // --- PESTAÑA 4: HARDWARE & MIGRACIONES (Edición interactiva de Motivo) ---
      const hwBody = document.getElementById('drawerHardwareBody');
      if (hwBody) {
        hwBody.innerHTML = '';
        const migrations = history.device_history || history.hardware || [];
        if (migrations && migrations.length > 0) {
          migrations.forEach((h, hIdx) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
              <td style="white-space: nowrap; min-width: 96px;">${h.migrated_at ? h.migrated_at.substring(0, 10) : '-'}</td>
              <td><code style="font-family:var(--font-mono); font-size:0.78rem;">${escapeHtml(h.old_device_id)}</code></td>
              <td><strong style="font-family:var(--font-mono); color:var(--primary); font-size:0.78rem;">${escapeHtml(h.new_device_id)}</strong></td>
              <td>S/ ${(h.fee_amount || h.fee_charged || 0).toFixed(2)}</td>
              <td class="mig-reason-cell">
                <div class="reason-display-wrap" style="display:flex; align-items:center; justify-content:space-between; gap:0.35rem;">
                  <span class="reason-text" style="font-size:0.8rem;">${escapeHtml(h.reason || '-')}</span>
                  <button type="button" class="btn-micro btn-edit-reason" title="Editar motivo de migración">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:11px; height:11px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                </div>
                <div class="reason-edit-wrap" style="display:none; align-items:center; gap:0.25rem;">
                  <input type="text" class="form-control reason-input" style="font-size:0.75rem; padding:2px 4px; height:24px; min-width:120px;" value="${escapeHtml(h.reason || '')}">
                  <button type="button" class="btn btn-primary btn-xs btn-save-reason" style="padding:2px 5px;" title="Guardar motivo">
                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                  </button>
                  <button type="button" class="btn btn-outline btn-xs btn-cancel-reason" style="padding:2px 5px;" title="Cancelar">
                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                  </button>
                </div>
              </td>
            `;

            const dispWrap = tr.querySelector('.reason-display-wrap');
            const editWrap = tr.querySelector('.reason-edit-wrap');
            const btnEditReason = tr.querySelector('.btn-edit-reason');
            const btnCancelReason = tr.querySelector('.btn-cancel-reason');
            const btnSaveReason = tr.querySelector('.btn-save-reason');
            const inputReason = tr.querySelector('.reason-input');

            btnEditReason.onclick = () => {
              dispWrap.style.display = 'none';
              editWrap.style.display = 'flex';
              inputReason.focus();
            };

            btnCancelReason.onclick = () => {
              editWrap.style.display = 'none';
              dispWrap.style.display = 'flex';
            };

            btnSaveReason.onclick = async () => {
              const newReason = inputReason.value.trim();
              try {
                const updateRes = await fetch(`/api/clients/${clientId}/device-history/${hIdx}`, {
                  method: 'PUT',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ reason: newReason }),
                });
                if (!updateRes.ok) throw new Error('Error al actualizar motivo');
                h.reason = newReason;
                tr.querySelector('.reason-text').textContent = newReason || '-';
                editWrap.style.display = 'none';
                dispWrap.style.display = 'flex';
                showToast('Motivo de migración actualizado con éxito.', 'success');
              } catch (err) {
                showToast('Error: ' + err.message, 'error');
              }
            };

            hwBody.appendChild(tr);
          });
        } else {
          hwBody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:var(--text-muted); padding:1rem;">Sin migraciones registradas.</td></tr>';
        }
      }
    }
  } catch (err) {
    console.error('Error loading history for drawer:', err);
  }

  document.getElementById('drawerClient360Backdrop')?.classList.add('open');
  document.getElementById('drawerClient360')?.classList.add('open');
}
