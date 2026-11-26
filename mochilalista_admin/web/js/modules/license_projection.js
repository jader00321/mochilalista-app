// =================== PROYECCIÓN COMERCIAL Y PAYLOAD ED25519 ===================
const GEN_SVGS = {
  lightbulb: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/></svg>`,
  calendar: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>`,
  bolt: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>`,
  lock: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`,
  coin: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>`,
  gear: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>`,
  star: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`,
  refresh: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>`,
  clock: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`
};

function decodeMl9TokenPayload(token) {
  if (!token || typeof token !== 'string') return null;
  const trimmed = token.trim();
  let b64Part = '';
  if (trimmed.startsWith('ML9-')) {
    const parts = trimmed.substring(4).split('.');
    b64Part = parts[0] || '';
  } else if (trimmed.includes('.')) {
    b64Part = trimmed.split('.')[0] || '';
  } else {
    b64Part = trimmed;
  }
  if (!b64Part) return null;
  try {
    let base64 = b64Part.replace(/-/g, '+').replace(/_/g, '/');
    while (base64.length % 4 !== 0) {
      base64 += '=';
    }
    const decodedStr = atob(base64);
    return JSON.parse(decodedStr);
  } catch (e) {
    return null;
  }
}

function resetCustomSettings() {
  const customDays = document.getElementById('licCustomDays');
  const customAi = document.getElementById('licCustomAiBonus');
  const customDate = document.getElementById('licCustomExactDate');
  const chkCustom = document.getElementById('chkEnableCustomSettings');
  const customContent = document.getElementById('licCustomContent');
  const accordionArrow = document.getElementById('accordionArrow');
  if (customDays) customDays.value = '';
  if (customAi) customAi.value = '0';
  if (customDate) customDate.value = '';
  if (chkCustom) chkCustom.checked = false;
  if (customContent) customContent.classList.remove('open');
  if (accordionArrow) accordionArrow.textContent = '▼';
}

function buildGeneratorWhatsAppMessage(code, client) {
  const token = code?.token || '';
  const plan = code?.plan || client?.license_type || 'MENSUAL';
  const titular = client?.owner_name || 'Comerciante';
  const negocio = client?.business_name || 'su negocio';
  const deviceId = code?.device_id || client?.current_device_id || 'ML-0000';
  const aiVal = (code?.ai_credits !== undefined && code?.ai_credits !== null) ? code.ai_credits : (code?.ai_extra_credits ?? 0);
  const expires = (plan === 'PERPETUO_LIBERADO') ? 'Vitalicia' : (code?.expires_at ? code.expires_at.substring(0, 10) : (client?.license_expires ? client.license_expires.substring(0, 10) : 'Activa'));
  const version = client?.installed_version ? `v${client.installed_version}` : 'v9.35.0';

  if (plan === 'BONO_IA_PERSONALIZADO' || plan === 'RECARGA_IA_150') {
    return `¡Hola, ${titular}! 👋 Te saludamos de MochilaLista.\nTu recarga de escaneos de Inteligencia Artificial para *${negocio}* ha sido acreditada con éxito.\n\n⚡ Detalle de la Recarga:\n• Créditos IA Otorgados: +${aiVal} escaneos vitalicios\n• Hardware ID Vinculado: \`${deviceId}\`\n\n🔑 Token de Activación IA:\n\`${token}\`\n\nPuedes ingresar este token o escanear el QR en tu app para sumarlos inmediatamente a tu saldo disponible. ¡A seguir potenciando tu negocio! 🚀`;
  } else if (plan === 'EXTENSION_CORTESIA') {
    return `Estimado(a) ${titular}, te saludamos de MochilaLista.\nTe confirmamos la habilitación de una extensión de cortesía para tu sistema en *${negocio}*.\n\n📌 Nueva vigencia temporal: *${expires}*\n• Hardware ID: \`${deviceId}\`\n\n🔑 Código de Activación:\n\`${token}\`\n\nIngresa este código o escanea el QR en tu aplicación para continuar operando sin interrupciones. ¡Quedamos a tu servicio! 🎒✅`;
  } else {
    return `¡Excelente noticia, ${titular}!\nTu licencia oficial de MochilaLista para el negocio *${negocio}* ha sido generada exitosamente.\n\n📌 Detalles de la Licencia:\n• Plan: ${plan.replace(/_/g, ' ')}\n• Hardware ID: \`${deviceId}\`\n• Vigencia: ${expires}\n• Versión: ${version}\n\n🔑 Código de Activación:\n\`${token}\`\n\nPuedes ingresar este código o escanear el QR desde la pantalla de activación de tu aplicación móvil. ¡Gracias por confiar en MochilaLista! 🎒✅`;
  }
}

function selectClientForLicense(clientId, options = {}) {
  drawerReturnState = null;
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

  const studioTab = document.querySelector('[data-tab="tabLicenseStudio"]');
  studioTab?.classList.add('active');
  document.getElementById('tabLicenseStudio')?.classList.add('active');

  const licSelect = document.getElementById('licClientSelect');
  if (licSelect) {
    licSelect.value = clientId;
    const client = globalClients.find(c => c.id === clientId);

    resetCustomSettings();

    // Si el cliente tiene bono IA acordado pendiente de emitir o se solicitó preferBonus
    if (client && (client.ai_pending_bonus || 0) > 0) {
      const planSel = document.getElementById('licPlanSelect');
      if (planSel) planSel.value = 'BONO_IA_PERSONALIZADO';
      const aiInput = document.getElementById('licCustomAiAmount');
      if (aiInput) aiInput.value = client.ai_pending_bonus;
      updateEcoModeUI('free');
    }

    updateClientSummaryCard();
    updateLiveLicenseProjection();
    updateGeneratorRightColumn(client || null);
  }
}

function updateEcoModeUI(mode) {
  const isFree = mode === 'free';
  const freeRadio = document.getElementById('ecoModeFree');
  const paidRadio = document.getElementById('ecoModePaid');
  const lblFree = document.getElementById('lblEcoModeFree');
  const lblPaid = document.getElementById('lblEcoModePaid');
  const boxSuggested = document.getElementById('boxSuggestedPrice');
  const grpAmount = document.getElementById('grpLicPaymentAmount');
  const grpMethod = document.getElementById('grpLicPaymentMethod');
  const grpRef = document.getElementById('grpLicPaymentRef');
  const amountInput = document.getElementById('licPaymentAmount');

  if (freeRadio) freeRadio.checked = isFree;
  if (paidRadio) paidRadio.checked = !isFree;

  if (lblFree) {
    lblFree.style.borderColor = isFree ? 'var(--primary)' : 'var(--border-color)';
    lblFree.style.background = isFree ? 'rgba(37,99,235,0.1)' : 'var(--bg-secondary)';
  }
  if (lblPaid) {
    lblPaid.style.borderColor = !isFree ? 'var(--primary)' : 'var(--border-color)';
    lblPaid.style.background = !isFree ? 'rgba(37,99,235,0.1)' : 'var(--bg-secondary)';
  }

  if (isFree) {
    if (amountInput) amountInput.value = '0.00';
    if (grpAmount) grpAmount.style.display = 'none';
    if (grpMethod) grpMethod.style.display = 'none';
    if (grpRef) grpRef.style.display = 'none';
    if (boxSuggested) boxSuggested.style.display = 'none';
  } else {
    if (grpAmount) { grpAmount.style.display = ''; grpAmount.style.opacity = '1'; }
    if (grpMethod) { grpMethod.style.display = ''; grpMethod.style.opacity = '1'; }
    if (grpRef) { grpRef.style.display = ''; grpRef.style.opacity = '1'; }
    if (boxSuggested) boxSuggested.style.display = 'block';
    updateSuggestedPrice();
  }
}

function updateSuggestedPrice() {
  const scans = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
  const cfgRecarga = ownerConfig?.catalog?.RECARGA_IA_150;
  const basePrice = (cfgRecarga?.price !== undefined) ? cfgRecarga.price : 20.0;
  const baseScans = (cfgRecarga?.ai_credits !== undefined) ? cfgRecarga.ai_credits : 150;

  const unitRate = basePrice / baseScans;
  let suggested = scans * unitRate;

  // Redondeo comercial al medio punto más cercano (piso S/ 1.00)
  suggested = Math.round(suggested * 2) / 2;
  if (suggested < 1.0) suggested = 1.0;

  const txtCalc = document.getElementById('txtSuggestedCalc');
  const valPrice = document.getElementById('valSuggestedPrice');
  if (txtCalc) txtCalc.textContent = `Tasa base: S/ ${basePrice.toFixed(2)} por ${baseScans} IA (${scans} × S/ ${unitRate.toFixed(3)})`;
  if (valPrice) valPrice.textContent = `S/ ${suggested.toFixed(2)}`;

  return suggested;
}

function updateClientSummaryCard() {
  const clientId = document.getElementById('licClientSelect').value;
  const card = document.getElementById('licClientSummaryCard');
  if (!card) return;

  const client = globalClients.find(c => c.id === clientId);
  if (!client) {
    card.style.display = 'none';
    return;
  }

  card.style.display = 'flex';
  document.getElementById('sumBizName').textContent = client.business_name || 'Negocio Sin Nombre';
  document.getElementById('sumOwnerName').textContent = `• Titular: ${client.owner_name || '-'}`;
  document.getElementById('sumDeviceId').textContent = client.current_device_id || 'ML-0000';
  const nextNonce = client.next_nonce || 1;
  document.getElementById('sumPlanNonce').textContent = `${(client.license_type || 'MENSUAL').replace(/_/g, ' ')} (Próximo Nonce: #${nextNonce})`;

  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const badgeInfo = getClientStatusBadge(client, { asObject: true });
  const isPerp = badgeInfo.isPerp;
  const isProspect = badgeInfo.isProspect;
  const isTrial = badgeInfo.isTrial;

  const sumStatusBadge = document.getElementById('sumStatusBadge');
  if (sumStatusBadge) {
    sumStatusBadge.className = badgeInfo.className;
    sumStatusBadge.textContent = badgeInfo.text.toUpperCase();
  }

  if (isProspect) {
    document.getElementById('sumExpiresDate').textContent = client.expected_subscription_date
      ? `Seguimiento: ${client.expected_subscription_date}`
      : 'Sin vencimiento (Prospecto)';
  } else if (isTrial) {
    const trialDays = (client.trial_days_remaining !== undefined && client.trial_days_remaining !== null)
      ? client.trial_days_remaining
      : (badgeInfo.diffDays >= 0 ? badgeInfo.diffDays : 0);
    document.getElementById('sumExpiresDate').textContent = `${client.license_expires ? client.license_expires.substring(0, 10) : 'Trial'} (${trialDays}d restantes)`;
  } else if (isPerp) {
    document.getElementById('sumExpiresDate').textContent = 'Vitalicia (De por Vida)';
  } else if (expDate) {
    const diff = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
    document.getElementById('sumExpiresDate').textContent = `${client.license_expires.substring(0, 10)} (${diff}d restantes)`;
  } else {
    document.getElementById('sumExpiresDate').textContent = 'Sin fecha';
  }

  const realAi = (client.ai_reported_balance !== undefined && client.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client.ai_accumulated_credits ?? client.ai_extra_credits ?? 0);
  const pendingAi = client.ai_pending_bonus || 0;
  let aiText = `${realAi} IA en celular`;
  if (pendingAi > 0) {
    aiText += ` (+${pendingAi} IA pendientes de emitir)`;
  }
  document.getElementById('sumAiCredits').textContent = aiText;
  document.getElementById('sumInstalledVersion').textContent = `v${client.installed_version || '9.35.0'}`;
  document.getElementById('sumUpdatesUntil').textContent = client.updates_until ? client.updates_until.substring(0, 10) : 'No configurada';
}

function updateLiveLicenseProjection() {
  const planSelect = document.getElementById('licPlanSelect');
  const clientSelect = document.getElementById('licClientSelect');
  const amountInput = document.getElementById('licPaymentAmount');
  const impactBadge = document.getElementById('licPlanImpactBadge');
  const projectionText = document.getElementById('licPlanProjection');
  const panelCustomAi = document.getElementById('panelCustomAiBonus');

  if (!planSelect || !impactBadge || !projectionText) return;

  const plan = planSelect.value;
  const clientId = clientSelect?.value;
  const client = globalClients.find(c => c.id === clientId);

  // Anti-doble bono: Ocultar y forzar a 0 el bono de regalo si el plan es Bono IA Personalizado
  const grpLicCustomAiBonus = document.getElementById('grpLicCustomAiBonus');
  if (plan === 'BONO_IA_PERSONALIZADO') {
    if (grpLicCustomAiBonus) grpLicCustomAiBonus.style.display = 'none';
    const customAiInput = document.getElementById('licCustomAiBonus');
    if (customAiInput) customAiInput.value = '0';
  } else {
    if (grpLicCustomAiBonus) grpLicCustomAiBonus.style.display = '';
  }

  // Mostrar / Ocultar panel interactivo de Bono IA Personalizado
  if (plan === 'BONO_IA_PERSONALIZADO') {
    if (panelCustomAi) panelCustomAi.style.display = 'block';
  } else {
    if (panelCustomAi) panelCustomAi.style.display = 'none';
  }

  const selectedOpt = planSelect.options[planSelect.selectedIndex];
  const cfgPlan = ownerConfig?.catalog?.[plan];

  const grpAmount = document.getElementById('grpLicPaymentAmount');
  const grpMethod = document.getElementById('grpLicPaymentMethod');
  const grpRef = document.getElementById('grpLicPaymentRef');

  if (plan === 'EXTENSION_CORTESIA') {
    if (grpAmount) grpAmount.style.display = 'none';
    if (grpMethod) grpMethod.style.display = 'none';
    if (grpRef) grpRef.style.display = 'none';
    if (amountInput) amountInput.value = '0.00';
  } else if (plan === 'BONO_IA_PERSONALIZADO') {
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    if (isFree) {
      if (amountInput) amountInput.value = '0.00';
      if (grpAmount) grpAmount.style.display = 'none';
      if (grpMethod) grpMethod.style.display = 'none';
      if (grpRef) grpRef.style.display = 'none';
    } else {
      if (grpAmount) { grpAmount.style.display = ''; grpAmount.style.opacity = '1'; }
      if (grpMethod) { grpMethod.style.display = ''; grpMethod.style.opacity = '1'; }
      if (grpRef) { grpRef.style.display = ''; grpRef.style.opacity = '1'; }
    }
  } else {
    const defaultPrice = (cfgPlan?.price !== undefined) ? cfgPlan.price.toFixed(2) : (selectedOpt?.getAttribute('data-price') || '35.00');
    if (amountInput && document.activeElement !== amountInput) {
      amountInput.value = defaultPrice;
    }
    if (grpAmount) { grpAmount.style.display = ''; grpAmount.style.opacity = '1'; }
    if (grpMethod) { grpMethod.style.display = ''; grpMethod.style.opacity = '1'; }
    if (grpRef) { grpRef.style.display = ''; grpRef.style.opacity = '1'; }
  }

  impactBadge.style.display = 'block';
  projectionText.style.display = 'block';
  impactBadge.className = 'plan-impact-badge';

  const now = new Date();
  let baseDate = now;

  // Leer ajustes personalizados estrictamente si el switch está activado y el plan no es Bono IA
  const isCustomEnabled = (document.getElementById('chkEnableCustomSettings')?.checked === true) && (plan !== 'BONO_IA_PERSONALIZADO');
  const customMode = document.getElementById('licCustomComputationMode')?.value || 'cumulative';
  const customDaysVal = isCustomEnabled ? (parseInt(document.getElementById('licCustomDays')?.value) || 0) : 0;
  const customAiBonus = isCustomEnabled ? (parseInt(document.getElementById('licCustomAiBonus')?.value) || 0) : 0;

  if (customMode === 'cumulative' && client && client.license_expires) {
    const exp = new Date(client.license_expires);
    if (exp > now && client.license_type !== 'TRIAL_VENCIDO') {
      baseDate = exp;
    }
  }

  const formatDateStr = (d) => {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${day}/${m}/${y}`;
  };

  const currentAi = (client?.ai_reported_balance !== undefined && client?.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client?.ai_accumulated_credits ?? client?.ai_extra_credits ?? 0);
  const nextNonce = client?.next_nonce || 1;
  const lastNonce = nextNonce > 1 ? nextNonce - 1 : 0;
  const nonceHtml = `<div>${GEN_SVGS.lock} <strong>Nonce Criptográfico:</strong> Último Nonce Emitido (#${lastNonce > 0 ? lastNonce : 'Ninguno'}) → <strong>Próximo Nonce a Firmar (#${nextNonce})</strong>.</div>`;

  // 1. Proyección de Bono IA Personalizado (0 días)
  if (plan === 'BONO_IA_PERSONALIZADO') {
    impactBadge.classList.add('recharge');
    const customScans = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    const paymentAmt = parseFloat(amountInput?.value) || 0;
    const paymentMth = document.getElementById('licPaymentMethod')?.value || 'Yape';

    impactBadge.innerHTML = `${GEN_SVGS.lightbulb} <strong>Bono / Recarga IA Personalizada:</strong> Otorga <strong>+${customScans} créditos de escaneos IA</strong> vitalicios directos al celular sin alterar días ni suscripción.`;

    const clientExpStr = client?.license_expires ? client.license_expires.substring(0, 10) : 'Sin fecha';
    const isTrial = client?.license_type === 'TRIAL' || client?.trial_days_remaining !== null;
    const trialDays = client?.trial_days_remaining ?? '-';
    const vigenciaTxt = isTrial ? `Trial (${trialDays}d restantes)` : clientExpStr;

    const projectedAi = currentAi + customScans;
    const financeTxt = isFree
      ? 'Cortesía / Sin costo (S/ 0.00) — No afectará ingresos contables'
      : `Cobro acordado: S/ ${paymentAmt.toFixed(2)} vía ${escapeHtml(paymentMth)}`;

    projectionText.innerHTML = `
      <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Vigencia:</strong> Mantiene fecha actual (${vigenciaTxt}) (Sin cambios de días).</div>
      <div style="margin-bottom:0.35rem;">${GEN_SVGS.bolt} <strong>Créditos IA:</strong> Saldo celular (${currentAi} IA) + Esta emisión (+${customScans} IA) = <strong>Total proyectado (${projectedAi} IA)</strong>.</div>
      <div style="margin-bottom:0.35rem;">${nonceHtml}</div>
      <div style="font-size:0.82rem; color:var(--text-secondary);">${GEN_SVGS.coin} <strong>Impacto Financiero:</strong> ${financeTxt}.</div>
    `;
    return;
  }

  // 2. Si hay días personalizados configurados en el acordeón
  if (customDaysVal > 0) {
    impactBadge.innerHTML = `${GEN_SVGS.gear} <strong>Ajuste Personalizado:</strong> Se otorgarán <strong>+${customDaysVal} días</strong> directos (${customMode === 'from_today' ? 'contando desde hoy' : 'acumulativos'})` +
      (customAiBonus > 0 ? ` + <strong>${customAiBonus} escaneos IA de regalo</strong>.` : '.');
    const projCustom = new Date(baseDate.getTime() + customDaysVal * 24 * 60 * 60 * 1000);
    const projAi = currentAi + customAiBonus;
    projectionText.innerHTML = `
      <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projCustom)}.</div>
      ${customAiBonus > 0 ? `<div style="margin-bottom:0.35rem;">${GEN_SVGS.bolt} <strong>Créditos IA:</strong> ${currentAi} IA + ${customAiBonus} IA = <strong>${projAi} IA</strong> proyectados.</div>` : ''}
      ${nonceHtml}
    `;
    return;
  }

  // 3. Proyección según planes de catálogo
  switch (plan) {
    case 'RECARGA_IA_150': {
      const aiCredits = (cfgPlan?.ai_credits !== undefined) ? cfgPlan.ai_credits : 150;
      impactBadge.classList.add('recharge');
      impactBadge.innerHTML = `${GEN_SVGS.lightbulb} <strong>Impacto:</strong> Conservará su plan actual y su fecha de vigencia. Se sumarán <strong>+${aiCredits} créditos de escaneos IA</strong> acumulativos sin fecha de caducidad.`;
      const projAi = currentAi + aiCredits;
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Vigencia:</strong> Mantiene su fecha actual (${client?.license_expires ? client.license_expires.substring(0, 10) : 'Activa'}) (Sin alteración de suscripción).</div>
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.bolt} <strong>Créditos IA:</strong> Saldo celular (${currentAi} IA) + Recarga (+${aiCredits} IA) = <strong>${projAi} IA</strong> proyectados.</div>
        ${nonceHtml}
      `;
      break;
    }
    case 'PERPETUO_LIBERADO': {
      const updateMonths = (cfgPlan?.updates_window_months !== undefined) ? cfgPlan.updates_window_months : 12;
      impactBadge.classList.add('perpetual');
      impactBadge.innerHTML = `${GEN_SVGS.star} <strong>Impacto:</strong> Licencia Perpetua Liberada. Acceso ilimitado de por vida (+99,999 días) con ${updateMonths} meses de actualizaciones de funciones incluidas.`;
      const updatesTarget = new Date(now.getTime() + updateMonths * 30 * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Vigencia:</strong> Vitalicia de por vida • <strong>Pase de Updates hasta:</strong> ${formatDateStr(updatesTarget)}.</div>
        ${nonceHtml}
      `;
      break;
    }
    case 'PASE_ACTUALIZACION_ANUAL': {
      const passDays = (cfgPlan?.days !== undefined && cfgPlan.days > 0) ? cfgPlan.days : 365;
      impactBadge.classList.add('perpetual');
      impactBadge.innerHTML = `${GEN_SVGS.refresh} <strong>Impacto:</strong> Extiende por <strong>+${passDays} días adicionales</strong> la ventana de nuevas versiones y herramientas para clientes perpetuos.`;
      const currentUpdates = client && client.updates_until ? new Date(client.updates_until) : now;
      const baseUp = currentUpdates > now ? currentUpdates : now;
      const newUpdates = new Date(baseUp.getTime() + passDays * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Nueva Ventana de Updates:</strong> Hasta el ${formatDateStr(newUpdates)} (+${passDays} días).</div>
        ${nonceHtml}
      `;
      break;
    }
    case 'EXTENSION_CORTESIA': {
      const cortesiaDays = (cfgPlan?.days !== undefined && cfgPlan.days > 0) ? cfgPlan.days : 7;
      impactBadge.innerHTML = `${GEN_SVGS.clock} <strong>Impacto:</strong> Otorga <strong>+${cortesiaDays} días de gracia temporal</strong> (S/ 0.00) para resolver cobranza en trámite o emergencias operativas.`;
      const projCortesia = new Date(baseDate.getTime() + cortesiaDays * 24 * 60 * 60 * 1000);
      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projCortesia)} (+${cortesiaDays} días de gracia).</div>
        ${nonceHtml}
      `;
      break;
    }
    default: {
      const days = (cfgPlan?.days !== undefined) ? cfgPlan.days : (parseInt(selectedOpt?.getAttribute('data-days')) || 30);
      impactBadge.innerHTML = `${GEN_SVGS.calendar} <strong>Impacto:</strong> Renovación acumulativa sin pérdida de días. Se sumarán <strong>+${days} días</strong> directos al saldo remanente.`;
      const projRegular = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);

      const basePlanAi = (cfgPlan?.ai_credits !== undefined)
        ? cfgPlan.ai_credits
        : (plan === 'TRIMESTRAL' ? 180 : (plan === 'SEMESTRAL' ? 450 : (plan === 'ANUAL' ? 1200 : 50)));
      const totalToAdd = basePlanAi + customAiBonus;
      const projAi = currentAi + totalToAdd;
      const aiBreakdown = customAiBonus > 0
        ? `Saldo celular (${currentAi} IA) + Plan (+${basePlanAi} IA) + Regalo (+${customAiBonus} IA) = <strong>${projAi} IA</strong> proyectados.`
        : `Saldo celular (${currentAi} IA) + Cuota del plan (+${basePlanAi} IA) = <strong>${projAi} IA</strong> proyectados.`;

      projectionText.innerHTML = `
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.calendar} <strong>Nueva expiración proyectada:</strong> ${formatDateStr(projRegular)} (Cero pérdida de días).</div>
        <div style="margin-bottom:0.35rem;">${GEN_SVGS.bolt} <strong>Créditos IA:</strong> ${aiBreakdown}</div>
        ${nonceHtml}
      `;
      break;
    }
  }
}

const updatePlanImpactAndProjection = updateLiveLicenseProjection;
