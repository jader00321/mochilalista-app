// =================== 2. CRM DE CLIENTES & BUSCADOR OMNICANAL ===================
function initOmnichannelSearch() {
  const searchInput = document.getElementById('inputClientSearch');
  const clearBtn = document.getElementById('btnClearClientSearch');

  searchInput?.addEventListener('input', (e) => {
    currentSearchQuery = e.target.value.trim().toLowerCase();
    if (clearBtn) {
      clearBtn.style.display = currentSearchQuery.length > 0 ? 'block' : 'none';
    }
    renderClientsTable();
  });

  clearBtn?.addEventListener('click', () => {
    if (searchInput) {
      searchInput.value = '';
      currentSearchQuery = '';
      clearBtn.style.display = 'none';
      renderClientsTable();
      searchInput.focus();
    }
  });
}

async function loadClients() {
  try {
    const res = await fetch('/api/clients', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar clientes');
    globalClients = await res.json();

    // Poblar selector en Generador
    const licSelect = document.getElementById('licClientSelect');
    const currentVal = licSelect ? licSelect.value : '';
    if (licSelect) {
      licSelect.innerHTML = '<option value="">-- Elige un cliente --</option>';

      globalClients.forEach(c => {
        const opt = document.createElement('option');
        opt.value = c.id;
        opt.textContent = `${c.business_name} (${c.owner_name}) — ${c.current_device_id}`;
        licSelect.appendChild(opt);
      });

      if (currentVal && globalClients.some(c => c.id === currentVal)) {
        licSelect.value = currentVal;
      } else {
        licSelect.value = '';
        currentSelectedClientId = null;
      }
    }

    updateFilterCounts();
    renderClientsTable();
    updateClientSummaryCard();
    updateLiveLicenseProjection();
    const activeClient = globalClients.find(c => c.id === licSelect?.value);
    updateGeneratorRightColumn(activeClient || null);
    if (typeof renderPlanDistributionChart === 'function') {
      renderPlanDistributionChart(globalClients);
    }
  } catch (e) {
    console.error('Error al cargar clientes:', e);
  }
}

// =================== CONTEOS, ESTADOS Y TABLA CRM ===================
function updateFilterCounts() {
  const now = new Date();
  const todayStr = getLocalIsoDate(now);
  let countActive = 0;
  let countExpiring = 0;
  let countExpired = 0;
  let countPerpetual = 0;
  let countProspect = 0;
  let countOutdated = 0;
  let countTrial = 0;
  let countPendingBonus = 0;
  let countFollowupDue = 0;

  const latestVer = getLatestPublishedVersion();

  globalClients.forEach(c => {
    const plan = (c.license_type || 'MENSUAL').toUpperCase();
    const status = (c.license_status || '').toUpperCase();
    const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
    const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
    const isTrial = plan === 'TRIAL' || status === 'TRIAL' || plan === 'TRIAL_GRATUITO';
    const expDate = c.license_expires ? new Date(c.license_expires) : null;

    if (isTrial) {
      countTrial++;
    }

    if ((c.ai_pending_bonus || 0) > 0) {
      countPendingBonus++;
    }

    if (c.next_followup_date && c.next_followup_date <= todayStr) {
      countFollowupDue++;
    }

    if (isProspect) {
      countProspect++;
    } else if (isPerp) {
      countPerpetual++;
      countActive++;
    } else if (expDate) {
      const diffDays = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
      if (diffDays < 0) {
        countExpired++;
      } else if (diffDays <= 7) {
        countExpiring++;
        countActive++;
      } else {
        countActive++;
      }
    }

    const clientVer = (c.installed_version || '').trim();
    if (!isProspect && latestVer && clientVer.length > 0) {
      if (compareSemVer(clientVer, latestVer) < 0) {
        countOutdated++;
      }
    }
  });

  const setTxt = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
  setTxt('countAll', globalClients.length);
  setTxt('countActive', countActive);
  setTxt('countExpiring', countExpiring);
  setTxt('countExpired', countExpired);
  setTxt('countPerpetual', countPerpetual);
  setTxt('countProspect', countProspect);
  setTxt('countOutdated', countOutdated);
  setTxt('countTrial', countTrial);
  setTxt('countPendingBonus', countPendingBonus);
  setTxt('countFollowupDue', countFollowupDue);

  const chipBonus = document.getElementById('chipFilterPendingBonus');
  if (chipBonus) {
    if (countPendingBonus > 0) {
      chipBonus.classList.add('accent-pending');
    } else {
      chipBonus.classList.remove('accent-pending');
    }
  }
}

// =================== HELPER CENTRALIZADO: BADGE DE ESTADO DEL CLIENTE ===================
function getClientStatusBadge(client, options = {}) {
  const asObject = options.asObject || false;
  if (!client) {
    return asObject
      ? { className: 'badge badge-outline', text: '-', isProspect: false, isTrial: false, isPerp: false, diffDays: 0 }
      : '<span class="badge badge-outline">-</span>';
  }

  const plan = (client.license_type || 'MENSUAL').toUpperCase();
  const status = (client.license_status || '').toUpperCase();
  const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
  const isTrial = plan === 'TRIAL';
  const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const diffDays = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : 999;

  let className = 'badge badge-green';
  let text = 'Activa';

  if (isProspect) {
    className = 'badge badge-prospect';
    text = 'Prospecto';
  } else if (isTrial) {
    className = 'badge badge-yellow';
    const trialDays = (client.trial_days_remaining !== undefined && client.trial_days_remaining !== null)
      ? client.trial_days_remaining
      : (diffDays >= 0 ? diffDays : 0);
    text = `Trial (${trialDays}d)`;
  } else if (isPerp) {
    className = 'badge badge-purple';
    text = 'Perpetua';
  } else if (diffDays < 0) {
    className = 'badge badge-red';
    text = 'Vencida';
  } else if (diffDays <= 7) {
    className = 'badge badge-yellow';
    text = `Vence en ${diffDays}d`;
  } else {
    className = 'badge badge-green';
    text = 'Activa';
  }

  if (asObject) {
    return { className, text, isProspect, isTrial, isPerp, diffDays };
  }
  return `<span class="${className}">${text}</span>`;
}

function renderClientsTable() {
  const tbody = document.getElementById('clientsTableBody');
  tbody.innerHTML = '';

  const now = new Date();
  const todayStr = getLocalIsoDate(now);
  const latestVer = getLatestPublishedVersion();

  const filtered = globalClients.filter(c => {
    // 1. Filtro por chip de estado
    if (currentClientFilter !== 'all') {
      const plan = (c.license_type || 'MENSUAL').toUpperCase();
      const status = (c.license_status || '').toUpperCase();
      const isProspect = plan === 'PROSPECTO' || status === 'PROSPECTO';
      const isPerp = plan === 'PERPETUO_LIBERADO' || plan === 'PERPETUO';
      const isTrial = plan === 'TRIAL' || status === 'TRIAL' || plan === 'TRIAL_GRATUITO';
      const expDate = c.license_expires ? new Date(c.license_expires) : null;
      const diffDays = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : 999;

      if (currentClientFilter === 'prospect' && !isProspect) return false;
      if (currentClientFilter === 'active' && (isProspect || !(isPerp || diffDays >= 0))) return false;
      if (currentClientFilter === 'expiring' && (isProspect || !(!isPerp && diffDays >= 0 && diffDays <= 7))) return false;
      if (currentClientFilter === 'expired' && (isProspect || !(!isPerp && diffDays < 0))) return false;
      if (currentClientFilter === 'perpetual' && (isProspect || !isPerp)) return false;
      if (currentClientFilter === 'trial' && !isTrial) return false;
      if (currentClientFilter === 'pending_bonus' && (!c.ai_pending_bonus || c.ai_pending_bonus <= 0)) return false;
      if (currentClientFilter === 'followup_due' && (!c.next_followup_date || c.next_followup_date > todayStr)) return false;
      if (currentClientFilter === 'outdated') {
        const clientVer = (c.installed_version || '').trim();
        if (isProspect || !latestVer || !clientVer || compareSemVer(clientVer, latestVer) >= 0) {
          return false;
        }
      }
    }

    // 2. Filtro omnicanal por texto
    if (currentSearchQuery) {
      const matchText = [
        c.id,
        c.business_name,
        c.owner_name,
        c.document_id,
        c.phone,
        c.current_device_id,
        c.installed_version,
        c.license_type,
        c.notes,
        c.next_followup_date,
      ].filter(Boolean).join(' ').toLowerCase();

      if (!matchText.includes(currentSearchQuery)) {
        return false;
      }
    }

    return true;
  });

  // Si se filtra por seguimientos pendientes, ordenar por fecha más vencida primero (ascendente)
  if (currentClientFilter === 'followup_due') {
    filtered.sort((a, b) => (a.next_followup_date || '').localeCompare(b.next_followup_date || ''));
  }

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No se encontraron clientes para este filtro o criterio de búsqueda.</td></tr>';
    return;
  }

  const fragment = document.createDocumentFragment();

  filtered.forEach(c => {
    const tr = document.createElement('tr');
    const badgeInfo = getClientStatusBadge(c, { asObject: true });
    const statusBadge = `<span class="${badgeInfo.className}">${escapeHtml(badgeInfo.text)}</span>`;

    const plan = (c.license_type || 'MENSUAL').toUpperCase();
    const isProspect = badgeInfo.isProspect;
    const isTrial = badgeInfo.isTrial;
    const isPerp = badgeInfo.isPerp;
    const expDate = c.license_expires ? new Date(c.license_expires) : null;

    const expText = isProspect
      ? (c.expected_subscription_date ? `Seguim: ${escapeHtml(c.expected_subscription_date)}` : 'Sin vencimiento')
      : (isPerp ? 'De por Vida' : (c.license_expires ? c.license_expires.substring(0, 10) : 'Sin fecha'));

    const clientVer = (c.installed_version || '').trim();
    const isOutdated = !isProspect && !!latestVer && clientVer.length > 0 && compareSemVer(clientVer, latestVer) < 0;

    let verBadge = '';
    if (isProspect || !clientVer) {
      verBadge = '<span class="badge badge-outline" style="font-size:0.68rem; padding:1px 6px; margin-top:2px; color:var(--text-muted);">Sin versión</span>';
    } else if (!latestVer) {
      verBadge = '<span class="badge badge-green" style="font-size:0.68rem; padding:1px 6px; margin-top:2px;">Al día</span>';
    } else if (isOutdated) {
      verBadge = '<span class="badge badge-yellow" style="font-size:0.68rem; padding:1px 6px; margin-top:2px;">Update pend.</span>';
    } else {
      verBadge = '<span class="badge badge-green" style="font-size:0.68rem; padding:1px 6px; margin-top:2px;">Al día</span>';
    }

    const isPendingDev = !c.current_device_id || c.current_device_id === 'PENDIENTE' || c.current_device_id === 'ML-0000';
    const deviceMarkup = (isProspect && isPendingDev)
      ? '<span class="badge badge-unlinked">Sin vincular</span>'
      : `<span class="device-id-badge" title="Hardware ID derivado de Settings.Secure.ANDROID_ID">
          <span>${escapeHtml(c.current_device_id)}</span>
          <button class="btn-micro" onclick="copyDeviceIdToClipboard('${escapeHtml(c.current_device_id)}')" title="Copiar Hardware ID">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:12px; height:12px;"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
          </button>
        </span>`;

    // Homogeneización 1:1 de Créditos IA (Plan Maestro 18 - Fase 3)
    const displayAi = (c.ai_reported_balance !== undefined && c.ai_reported_balance !== null)
      ? c.ai_reported_balance
      : (c.ai_accumulated_credits ?? c.ai_extra_credits ?? 0);
    const hasAiCredits = displayAi > 0;
    const aiMarkup = hasAiCredits
      ? `<span class="badge badge-purple">${displayAi} IA</span>`
      : '<span class="badge badge-outline" style="color:var(--text-muted); border:1px solid var(--border-color);">0 IA</span>';

    const pendingBonusBadge = (c.ai_pending_bonus && c.ai_pending_bonus > 0)
      ? `<div class="badge-pending-bonus" title="Bono acordado pendiente de emitir en token Ed25519">+${c.ai_pending_bonus} pend.</div>`
      : '';

    // Seguimiento en columna Negocio & Titular
    let followupBadge = '';
    if (c.next_followup_date) {
      if (c.next_followup_date < todayStr) {
        followupBadge = `<div style="margin-top:3px;"><span class="badge badge-red badge-xs" style="font-size:0.7rem; padding:1px 6px;" title="Seguimiento comercial vencido">Seg. Vencido: ${escapeHtml(c.next_followup_date)}</span></div>`;
      } else if (c.next_followup_date === todayStr) {
        followupBadge = `<div style="margin-top:3px;"><span class="badge badge-yellow badge-xs" style="font-size:0.7rem; padding:1px 6px;" title="Seguimiento programado para hoy">Seg. Hoy</span></div>`;
      } else {
        followupBadge = `<div style="margin-top:3px;"><span class="badge badge-outline badge-xs" style="font-size:0.7rem; padding:1px 6px; color:var(--text-muted); border-color:var(--border-color);" title="Próximo seguimiento">Seg: ${escapeHtml(c.next_followup_date)}</span></div>`;
      }
    }

    const planSuffix = (!isProspect && !isTrial)
      ? `<small style="font-weight:700; color:var(--text-secondary);">(${escapeHtml(c.license_type || 'MENSUAL')})</small>`
      : '';

    tr.innerHTML = `
      <td style="white-space: nowrap; font-family: var(--font-mono);"><strong>${escapeHtml(c.id)}</strong></td>
      <td>
        <div><strong>${escapeHtml(c.business_name)}</strong></div>
        <div style="font-size:0.8rem; color:var(--text-secondary); margin-top:2px;">
          ${escapeHtml(c.owner_name)}${c.document_id ? ' • ' + escapeHtml(c.document_id) : ''}
        </div>
        ${followupBadge}
        ${c.notes ? `<div style="font-size:0.75rem; color:var(--text-muted); margin-top:2px;">${escapeHtml(c.notes)}</div>` : ''}
      </td>
      <td>
        <div style="display:flex; align-items:center; gap:0.35rem; flex-wrap:wrap;">
          ${statusBadge}
          ${planSuffix}
        </div>
        <div style="font-size:0.78rem; color:var(--text-secondary); margin-top:3px; font-family:var(--font-mono);">
          ${expText}
        </div>
      </td>
      <td>
        ${deviceMarkup}
      </td>
      <td>
        <div style="font-weight:600;">${clientVer ? 'v' + escapeHtml(clientVer) : '<span style="color:var(--text-muted); font-size:0.85rem;">-</span>'}</div>
        ${verBadge}
      </td>
      <td>
        ${aiMarkup}
        ${pendingBonusBadge}
      </td>
      <td style="text-align:center; white-space: nowrap;">
        <div class="crm-actions-cell">
          <button type="button" class="btn-crm-action" onclick="openClient360Drawer('${c.id}', 'drawerTabOverview')" title="Ficha 360° del Cliente">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
          </button>
          <button type="button" class="btn-crm-action primary" onclick="openClient360Drawer('${c.id}', 'drawerTabQr')" title="Ver QR y Credencial Oficial">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
          </button>
          <button type="button" class="btn-crm-action wa" onclick="openWhatsAppComposer('${c.id}')" title="Enviar WhatsApp (Compositor)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>
          </button>
          <button type="button" class="btn-crm-action" onclick="selectClientForLicense('${c.id}')" title="Emitir Licencia Ed25519">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
          </button>
        </div>
      </td>
    `;
    fragment.appendChild(tr);
  });
  tbody.appendChild(fragment);
  if (typeof applyTableDensity === 'function') {
    applyTableDensity(ownerConfig?.system?.table_density);
  }
}

function copyDeviceIdToClipboard(deviceId) {
  copyPlainTextToClipboard(deviceId, `Hardware ID copiado: ${deviceId}`, {
    successType: 'info',
    errorMessage: `Hardware ID: ${deviceId}`,
    errorType: 'info',
  });
}
