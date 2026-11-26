// =================== MODAL DE CONFIRMACIÓN PRE-EMISIÓN Y FIRMA ED25519 (FASE 2 PLAN 18.5) ===================
function openConfirmEmissionModal() {
  const clientId = document.getElementById('licClientSelect')?.value;
  if (!clientId) {
    showToast('Por favor selecciona un cliente de la lista.', 'warning');
    return;
  }

  const client = globalClients.find(c => c.id === clientId);
  if (!client) {
    showToast('Cliente seleccionado no encontrado en el sistema.', 'warning');
    return;
  }

  const devId = (client.current_device_id || '').trim();
  if (!devId) {
    showToast('El cliente seleccionado no cuenta con un Hardware ID vinculado.', 'warning');
    return;
  }

  const plan = document.getElementById('licPlanSelect')?.value;
  const isBonoIa = plan === 'BONO_IA_PERSONALIZADO';

  let paymentAmount = parseFloat(document.getElementById('licPaymentAmount')?.value);
  if (isNaN(paymentAmount) || paymentAmount < 0) {
    showToast('El monto de cobro debe ser un número válido mayor o igual a 0.', 'warning');
    return;
  }

  const isCustomEnabled = (document.getElementById('chkEnableCustomSettings')?.checked === true) && !isBonoIa;
  let customDaysVal = null;
  let customAiBonus = 0;
  let computationMode = 'cumulative';
  let customExactDate = null;

  if (isCustomEnabled) {
    customDaysVal = parseInt(document.getElementById('licCustomDays')?.value) || null;
    customAiBonus = parseInt(document.getElementById('licCustomAiBonus')?.value) || 0;
    computationMode = document.getElementById('licCustomComputationMode')?.value || 'cumulative';
    customExactDate = document.getElementById('licCustomExactDate')?.value || null;
  }

  let customAiScans = 0;
  if (isBonoIa) {
    customAiScans = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
    if (customAiScans <= 0) {
      showToast('La cantidad de escaneos IA debe ser mayor a 0.', 'warning');
      return;
    }
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    if (isFree) {
      paymentAmount = 0.0;
    }
  } else if (plan === 'EXTENSION_CORTESIA') {
    paymentAmount = 0.0;
  }

  // 1. Cliente y Dispositivo
  const elClientName = document.getElementById('confirmLicClientName');
  const elOwnerDoc = document.getElementById('confirmLicOwnerDoc');
  const elHwId = document.getElementById('confirmLicHardwareId');
  const elAppVer = document.getElementById('confirmLicAppVersion');

  if (elClientName) elClientName.textContent = client.business_name || 'Sin Nombre';
  const docText = client.doc_id ? ` • DNI/RUC: ${client.doc_id}` : '';
  if (elOwnerDoc) elOwnerDoc.textContent = `${client.owner_name || 'Sin Titular'}${docText}`;
  if (elHwId) elHwId.textContent = devId;
  if (elAppVer) elAppVer.textContent = client.installed_version ? `(v${client.installed_version})` : '(v9.34.0)';

  // 2. Plan / Modalidad y Beneficios
  const elPlanLabel = document.getElementById('confirmLicPlanLabel');
  if (elPlanLabel) {
    if (isBonoIa) {
      elPlanLabel.innerHTML = `<strong>Bono / Recarga IA Personalizada (+${customAiScans} IA)</strong>`;
    } else {
      elPlanLabel.innerHTML = `<strong>${escapeHtml(formatPlanHumanLabel(plan))}</strong>`;
    }
  }

  // Vigencia Proyectada
  const elExpiration = document.getElementById('confirmLicExpiration');
  const formatDateStr = (d) => {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${day}/${m}/${y}`;
  };

  const now = new Date();
  let baseDate = now;
  if (computationMode === 'cumulative' && client.license_expires) {
    const exp = new Date(client.license_expires);
    if (exp > now && client.license_type !== 'TRIAL_VENCIDO') {
      baseDate = exp;
    }
  }

  if (elExpiration) {
    if (isBonoIa || plan === 'RECARGA_IA_150') {
      const curExp = client.license_expires ? client.license_expires.substring(0, 10) : 'Activa';
      const isTrial = client.license_type === 'TRIAL' || client.trial_days_remaining !== null;
      const vig = isTrial ? `Trial (${client.trial_days_remaining ?? '-'}d restantes)` : curExp;
      elExpiration.textContent = `${vig} (Sin cambio de días)`;
    } else if (plan === 'PERPETUO_LIBERADO') {
      elExpiration.textContent = 'De por Vida / Sin Caducidad';
    } else if (customExactDate) {
      elExpiration.textContent = `Sobrescrita fija al ${customExactDate}`;
    } else {
      const curExpStr = client.license_expires ? client.license_expires.substring(0, 10) : 'Nueva emisión';
      const days = (customDaysVal && customDaysVal > 0)
        ? customDaysVal
        : (ownerConfig?.catalog?.[plan]?.days ?? (plan === 'EXTENSION_CORTESIA' ? 7 : 30));
      const proj = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);
      elExpiration.textContent = `${curExpStr} → ${formatDateStr(proj)} (+${days} días)`;
    }
  }

  // Créditos IA Celular
  const elAi = document.getElementById('confirmLicAiCredits');
  const currentAi = (client.ai_reported_balance !== undefined && client.ai_reported_balance !== null)
    ? client.ai_reported_balance
    : (client.ai_accumulated_credits ?? client.ai_extra_credits ?? 0);

  if (elAi) {
    if (isBonoIa) {
      const totalProj = currentAi + customAiScans;
      elAi.textContent = `${currentAi} IA (celular) + ${customAiScans} IA = ${totalProj} IA proyectados`;
    } else {
      const basePlanAi = ownerConfig?.catalog?.[plan]?.ai_credits ?? (plan === 'TRIMESTRAL' ? 180 : (plan === 'SEMESTRAL' ? 450 : (plan === 'ANUAL' ? 1200 : (plan === 'PERPETUO_LIBERADO' ? 0 : 50))));
      const toAdd = basePlanAi + customAiBonus;
      if (toAdd > 0) {
        const totalProj = currentAi + toAdd;
        elAi.textContent = `${currentAi} IA (celular) + ${toAdd} IA = ${totalProj} IA proyectados`;
      } else {
        elAi.textContent = `${currentAi} IA (celular) (Sin bonos de escaneo)`;
      }
    }
  }

  // 3. Nonce Criptográfico (Estricto Plan 18/18.5: Último Nonce Emitido -> Próximo Nonce a Firmar)
  const elNonce = document.getElementById('confirmLicNonce');
  const nextNonce = client.next_nonce || 1;
  const lastNonce = nextNonce > 1 ? nextNonce - 1 : 0;
  if (elNonce) {
    elNonce.textContent = `Último Nonce Emitido (#${lastNonce > 0 ? lastNonce : 'Ninguno'}) → Próximo Nonce a Firmar (#${nextNonce})`;
  }

  // 4. Impacto Financiero
  const elFinancial = document.getElementById('confirmLicFinancial');
  const paymentMethod = document.getElementById('licPaymentMethod')?.value || 'Yape';
  const paymentRef = document.getElementById('licPaymentRef')?.value?.trim() || '';
  if (elFinancial) {
    if (paymentAmount > 0) {
      const refText = paymentRef ? ` - ${paymentRef}` : '';
      elFinancial.innerHTML = `<strong>S/ ${paymentAmount.toFixed(2)}</strong> (${escapeHtml(paymentMethod)}${escapeHtml(refText)})`;
    } else {
      elFinancial.textContent = 'Cortesía / Sin Costo (S/ 0.00)';
    }
  }

  // 5. Badge de Ajustes Personalizados
  const badgeBox = document.getElementById('confirmLicCustomBadgeBox');
  const customDetails = document.getElementById('confirmLicCustomDetails');
  if (isCustomEnabled && (customDaysVal !== null || customAiBonus > 0 || customExactDate || computationMode !== 'cumulative')) {
    const details = [];
    if (customDaysVal !== null && customDaysVal > 0) {
      details.push(`Días manuales: +${customDaysVal} (${computationMode === 'from_today' ? 'desde hoy' : 'acumulativos'})`);
    }
    if (customAiBonus > 0) {
      details.push(`Bono IA regalo: +${customAiBonus} escaneos`);
    }
    if (customExactDate) {
      details.push(`Fecha fija exacta: ${customExactDate}`);
    }
    if (badgeBox && customDetails) {
      customDetails.innerHTML = details.join(' • ') || 'Ajustes comerciales manuales aplicados';
      badgeBox.style.display = 'block';
    }
  } else {
    if (badgeBox) badgeBox.style.display = 'none';
  }

  // Restaurar vistas y habilitar botones
  const summaryState = document.getElementById('confirmEmissionSummaryState');
  const animState = document.getElementById('confirmEmissionAnimState');
  const footer = document.getElementById('confirmEmissionFooter');
  const btnCancel = document.getElementById('btnCancelConfirmEmission');
  const btnExecute = document.getElementById('btnExecuteConfirmEmission');

  if (summaryState) summaryState.style.display = 'block';
  if (animState) animState.style.display = 'none';
  if (footer) footer.style.display = 'flex';
  if (btnCancel) btnCancel.disabled = false;
  if (btnExecute) btnExecute.disabled = false;

  openModal('modalConfirmLicenseEmission');
}

const generateLicense = openConfirmEmissionModal;

async function executeConfirmedEmission() {
  const clientId = document.getElementById('licClientSelect')?.value;
  const client = globalClients.find(c => c.id === clientId);
  if (!clientId || !client) {
    showToast('Por favor selecciona un cliente válido.', 'warning');
    closeModal('modalConfirmLicenseEmission');
    return;
  }

  const plan = document.getElementById('licPlanSelect')?.value;
  const isBonoIa = plan === 'BONO_IA_PERSONALIZADO';

  let paymentAmount = parseFloat(document.getElementById('licPaymentAmount')?.value) || 0;
  let paymentMethod = document.getElementById('licPaymentMethod')?.value || 'Yape';
  let paymentRef = document.getElementById('licPaymentRef')?.value?.trim() || 'Op. Generada';

  const isCustomEnabled = (document.getElementById('chkEnableCustomSettings')?.checked === true) && !isBonoIa;
  let customDaysVal = null;
  let customAiBonus = 0;
  let computationMode = 'cumulative';
  let customExactDate = null;

  if (isCustomEnabled) {
    customDaysVal = parseInt(document.getElementById('licCustomDays')?.value) || null;
    customAiBonus = parseInt(document.getElementById('licCustomAiBonus')?.value) || 0;
    computationMode = document.getElementById('licCustomComputationMode')?.value || 'cumulative';
    customExactDate = document.getElementById('licCustomExactDate')?.value || null;
  }

  if (isBonoIa) {
    const customAiAmount = parseInt(document.getElementById('licCustomAiAmount')?.value) || 20;
    customAiBonus = customAiAmount;
    const isFree = document.getElementById('ecoModeFree')?.checked ?? true;
    if (isFree) {
      paymentAmount = 0.0;
      paymentMethod = 'Cortesia / Promocion';
      paymentRef = 'Bono Gratuito';
    }
  } else if (plan === 'EXTENSION_CORTESIA') {
    paymentAmount = 0.0;
    paymentMethod = 'Cortesia / Promocion';
    paymentRef = 'Extension Cortesia';
  }

  // 1. Deshabilitar botones para impedir doble emisión accidental y activar vista animada
  const btnCancel = document.getElementById('btnCancelConfirmEmission');
  const btnExecute = document.getElementById('btnExecuteConfirmEmission');
  const summaryState = document.getElementById('confirmEmissionSummaryState');
  const animState = document.getElementById('confirmEmissionAnimState');
  const footer = document.getElementById('confirmEmissionFooter');

  if (btnCancel) btnCancel.disabled = true;
  if (btnExecute) btnExecute.disabled = true;
  if (summaryState) summaryState.style.display = 'none';
  if (footer) footer.style.display = 'none';
  if (animState) animState.style.display = 'block';

  // Configurar animación en Etapa 1
  const animTitle = document.getElementById('confirmEmissionAnimTitle');
  const animSubtitle = document.getElementById('confirmEmissionAnimSubtitle');
  const shieldSvg = animState?.querySelector('.shield-svg');
  const shieldKeyHole = document.getElementById('shieldKeyHole');
  const shieldCheckPath = document.getElementById('shieldCheckPath');

  if (animTitle) animTitle.textContent = 'Validando correlativo Nonce y vinculación de Hardware...';
  if (animSubtitle) animSubtitle.textContent = 'Sincronizando estado criptográfico seguro con la bóveda';
  if (shieldKeyHole) shieldKeyHole.style.display = 'block';
  if (shieldCheckPath) shieldCheckPath.style.display = 'none';
  if (shieldSvg) shieldSvg.style.color = 'var(--primary)';

  // Programar transición a Etapa 2 (~260ms)
  const stage2Timer = setTimeout(() => {
    if (animTitle) animTitle.textContent = 'Firmando criptográficamente con clave maestra Ed25519...';
    if (animSubtitle) animSubtitle.textContent = 'Generando firma asimétrica de 64 bytes (Envelope DPAPI)';
  }, 260);

  const startTime = Date.now();

  try {
    const res = await fetch('/api/licenses/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: clientId,
        plan: plan,
        payment_amount: paymentAmount,
        payment_method: paymentMethod,
        payment_ref: paymentRef,
        custom_days: customDaysVal,
        custom_ai_bonus: customAiBonus,
        ai_extra_credits: isBonoIa ? customAiBonus : undefined,
        computation_mode: computationMode,
        custom_exact_expiration: customExactDate,
      }),
    });

    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || 'Error al generar licencia');
    }

    const data = await res.json();
    currentSelectedGeneratorCode = data;

    // Etapa 3: Asegurar tiempo mínimo (~650ms total) para fluidez profesional
    const elapsed = Date.now() - startTime;
    const waitTime = Math.max(0, 650 - elapsed);

    setTimeout(async () => {
      if (animTitle) animTitle.textContent = '¡Licencia y Credencial Emitidas con Éxito!';
      if (animSubtitle) animSubtitle.textContent = 'Firma Ed25519 verificada e integrada en el historial comercial';
      if (shieldKeyHole) shieldKeyHole.style.display = 'none';
      if (shieldCheckPath) shieldCheckPath.style.display = 'block';
      if (shieldSvg) shieldSvg.style.color = 'var(--success)';

      // Cierre y transición suave a columna de resultado
      setTimeout(async () => {
        closeModal('modalConfirmLicenseEmission');

        await loadClients();
        await loadDashboard();

        const updatedClient = globalClients.find(c => c.id === clientId) || client || data.client;
        renderSelectedGeneratorLicense(data, updatedClient, true);
        updateGeneratorRightColumn(updatedClient);

        // Feedback visual en la columna derecha
        const resultContainer = document.getElementById('licenseResultContainer');
        if (resultContainer) {
          resultContainer.classList.remove('license-result-highlight');
          void resultContainer.offsetWidth; // Forzar reflow del DOM
          resultContainer.classList.add('license-result-highlight');
          setTimeout(() => {
            resultContainer.classList.remove('license-result-highlight');
          }, 1800);
          resultContainer.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }

        showToast('¡Licencia Ed25519 emitida y firmada con éxito!', 'success');
      }, 250);
    }, waitTime);

  } catch (e) {
    clearTimeout(stage2Timer);
    if (animState) animState.style.display = 'none';
    if (summaryState) summaryState.style.display = 'block';
    if (footer) footer.style.display = 'flex';
    if (btnCancel) btnCancel.disabled = false;
    if (btnExecute) btnExecute.disabled = false;
    showToast('Error al emitir licencia: ' + e.message, 'error');
  }
}
