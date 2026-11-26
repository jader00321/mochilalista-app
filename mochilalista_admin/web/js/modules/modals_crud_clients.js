// =================== 7. MODALES Y CRUD ===================
function initModalEvents() {
  // Cierre de modales al hacer clic en el backdrop exterior
  document.querySelectorAll('.modal-overlay').forEach(modal => {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        closeModal(modal.id);
      }
    });
  });

  // Listener global de tecla Escape para modales y drawer
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const openModals = document.querySelectorAll('.modal-overlay.open');
      if (openModals.length > 0) {
        const topModal = openModals[openModals.length - 1];
        closeModal(topModal.id);
      } else {
        const drawer = document.getElementById('drawerClient360');
        if (drawer && drawer.classList.contains('open')) {
          closeClient360Drawer();
        }
      }
    }
  });

  // Filtros de cartera
  document.querySelectorAll('.filter-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      currentClientFilter = chip.dataset.filter;
      renderClientsTable();
    });
  });

  // Modal Crear Cliente (Reingeniería Fase 3)
  const situationSelect = document.getElementById('newClientSituation');
  const updateSituationFields = () => {
    const sit = situationSelect?.value || 'TRIAL';
    const grpPlan = document.getElementById('grpNewPlan');
    const grpTrial = document.getElementById('grpTrialDaysRemaining');
    const grpSubDate = document.getElementById('grpExpectedSubscriptionDate');
    const lblDevice = document.getElementById('lblNewDeviceId');
    const reqDevice = document.getElementById('reqStarDeviceId');
    const inputDevice = document.getElementById('newDeviceId');
    const aiReported = document.getElementById('newAiReportedBalance');

    if (sit === 'PROSPECTO') {
      if (grpPlan) grpPlan.style.display = 'none';
      if (grpTrial) grpTrial.style.display = 'none';
      if (grpSubDate) grpSubDate.style.display = 'flex';
      if (lblDevice) lblDevice.innerHTML = 'Hardware ID (Opcional — PENDIENTE):';
      if (reqDevice) reqDevice.style.display = 'none';
      if (inputDevice) {
        inputDevice.required = false;
        inputDevice.placeholder = 'PENDIENTE (Opcional)';
      }
      if (aiReported && !aiReported.dataset.manual) aiReported.value = 0;
    } else if (sit === 'TRIAL') {
      if (grpPlan) grpPlan.style.display = 'none';
      if (grpTrial) grpTrial.style.display = 'flex';
      if (grpSubDate) grpSubDate.style.display = 'none';
      if (lblDevice) lblDevice.innerHTML = 'Hardware ID del Celular (ML-XXXX): <span class="required-star">*</span>';
      if (reqDevice) reqDevice.style.display = 'inline';
      if (inputDevice) {
        inputDevice.required = true;
        inputDevice.placeholder = 'Ej: ML-9K4B';
      }
      if (aiReported && !aiReported.dataset.manual) aiReported.value = 50;
    } else { // COMMERCIAL
      if (grpPlan) grpPlan.style.display = 'flex';
      if (grpTrial) grpTrial.style.display = 'none';
      if (grpSubDate) grpSubDate.style.display = 'none';
      if (lblDevice) lblDevice.innerHTML = 'Hardware ID del Celular (ML-XXXX): <span class="required-star">*</span>';
      if (reqDevice) reqDevice.style.display = 'inline';
      if (inputDevice) {
        inputDevice.required = true;
        inputDevice.placeholder = 'Ej: ML-9K4B';
      }
      if (aiReported && !aiReported.dataset.manual) aiReported.value = 0;
    }
  };

  situationSelect?.addEventListener('change', updateSituationFields);

  // Aviso Contextual de Crédito IA Offline
  const aiBonusInput = document.getElementById('newAiPendingBonus');
  aiBonusInput?.addEventListener('input', () => {
    const val = parseInt(aiBonusInput.value) || 0;
    const notice = document.getElementById('noticeAiBonus');
    if (notice) {
      notice.style.display = val > 0 ? 'block' : 'none';
    }
  });

  // Normalización interactiva de Teléfono
  const phoneInput = document.getElementById('newPhone');
  phoneInput?.addEventListener('input', () => {
    const hint = document.getElementById('hintPhonePreview');
    if (hint) {
      const norm = normalizePeruPhone(phoneInput.value);
      hint.textContent = norm ? `Formato normalizado: ${norm}` : 'Se normalizará automáticamente con prefijo Perú +51';
    }
  });
  phoneInput?.addEventListener('blur', () => {
    const norm = normalizePeruPhone(phoneInput.value);
    if (norm) phoneInput.value = norm;
  });

  // Cálculo en vivo de vencimiento de Trial
  const trialDaysInput = document.getElementById('newTrialDaysRemaining');
  trialDaysInput?.addEventListener('input', () => {
    const days = parseInt(trialDaysInput.value) || 30;
    const hint = document.getElementById('hintTrialExpires');
    if (hint) {
      const expDate = new Date();
      expDate.setDate(expDate.getDate() + days);
      hint.textContent = `Vencerá el ${expDate.toISOString().substring(0, 10)} (en ${days} días).`;
    }
  });

  const aiRepInput = document.getElementById('newAiReportedBalance');
  aiRepInput?.addEventListener('input', () => {
    aiRepInput.dataset.manual = 'true';
  });

  document.getElementById('btnOpenCreateClient')?.addEventListener('click', () => {
    document.getElementById('formCreateClient')?.reset();
    const aiRep = document.getElementById('newAiReportedBalance');
    if (aiRep) delete aiRep.dataset.manual;
    const notice = document.getElementById('noticeAiBonus');
    if (notice) notice.style.display = 'none';
    updateSituationFields();

    // Versión instalada dinámica según último release publicado (Plan 19)
    const verInput = document.getElementById('newInstalledVersion');
    if (verInput) {
      verInput.value = (globalReleases && globalReleases.length > 0) ? (globalReleases[0].version_name || '9.38.0') : '9.38.0';
    }

    openModal('modalCreateClient');
  });

  document.getElementById('btnSubmitCreateClient')?.addEventListener('click', () => {
    handleCreateClient(false);
  });

  document.getElementById('btnSubmitAndEmit')?.addEventListener('click', () => {
    handleCreateClient(true);
  });

  // Modal Editar Cliente (Guardar)
  document.getElementById('btnSubmitEditClient')?.addEventListener('click', async () => {
    const id = document.getElementById('editClientId').value;
    const biz = document.getElementById('editBizName').value.trim();
    const owner = document.getElementById('editOwnerName').value.trim();
    const doc = document.getElementById('editDocId').value.trim();
    const phone = document.getElementById('editPhone').value.trim();
    const device = document.getElementById('editDeviceId').value.trim().toUpperCase();
    const ver = document.getElementById('editInstalledVersion').value.trim();
    const licType = document.getElementById('editLicenseType').value;
    const licStatus = document.getElementById('editLicenseStatus').value;
    const licExpires = document.getElementById('editLicenseExpires').value;
    const updatesUntil = document.getElementById('editUpdatesUntil').value;
    const aiExtra = parseInt(document.getElementById('editAiExtraCredits').value) || 0;
    const nonce = parseInt(document.getElementById('editNextNonce').value) || 1;
    const notes = document.getElementById('editNotes').value.trim();

    if (!biz || !owner || !phone || !device) {
      showToast('Por favor completa los campos requeridos.', 'warning');
      return;
    }

    try {
      const res = await fetch(`/api/clients/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          business_name: biz,
          owner_name: owner,
          document_id: doc,
          phone: phone,
          current_device_id: device,
          installed_version: ver || '9.24.0',
          license_type: licType,
          license_status: licStatus,
          license_expires: licExpires || null,
          updates_until: updatesUntil || null,
          ai_extra_credits: aiExtra,
          next_nonce: nonce,
          notes: notes,
        }),
      });

      if (!res.ok) throw new Error('Error al actualizar cliente');
      closeModal('modalEditClient');
      showToast('Cliente y directivas actualizados con éxito.', 'success');
      await loadClients();
      await loadDashboard();
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Modal Editar Cliente (Eliminar Cliente)
  document.getElementById('btnDeleteClient')?.addEventListener('click', () => {
    const id = document.getElementById('editClientId').value;
    const biz = document.getElementById('editBizName').value;

    showConfirmModal(
      'Eliminar Cliente Permanentemente',
      `¿Estás seguro de eliminar a "${biz}" (${id}) y todo su historial de pagos y licencias? Esta acción no se puede deshacer.`,
      async () => {
        try {
          const res = await fetch(`/api/clients/${id}`, { method: 'DELETE' });
          if (!res.ok) throw new Error('Error al eliminar cliente');
          closeModal('modalEditClient');
          showToast(`Cliente "${biz}" eliminado permanentemente.`, 'success');
          await loadClients();
          await loadDashboard();
        } catch (e) {
          showToast('Error: ' + e.message, 'error');
        }
      },
      true
    );
  });

  // Modal Migrar Dispositivo
  document.getElementById('btnSubmitMigrateDevice')?.addEventListener('click', handleMigrateDeviceSubmit);

  document.getElementById('migFeeMode')?.addEventListener('change', (e) => {
    const mode = e.target.value;
    const feeInput = document.getElementById('migFee');
    const customGroup = document.getElementById('migCustomFeeGroup');
    const paymentGroup = document.getElementById('migPaymentFieldsGroup');
    const reasonInput = document.getElementById('migReason');
    const defaultFee = (ownerConfig?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
      ? ownerConfig.catalog.HARDWARE_MIGRATION_FEE.price
      : (ownerConfig?.migration_fee || 40.0);

    if (mode === 'FREE') {
      if (feeInput) feeInput.value = '0.00';
      if (customGroup) customGroup.style.display = 'none';
      if (paymentGroup) paymentGroup.style.display = 'none';
      if (reasonInput && !reasonInput.value) {
        reasonInput.value = 'Garantía de equipo / Traslado gratuito por cortesía';
      }
    } else if (mode === 'CUSTOM') {
      if (customGroup) customGroup.style.display = 'block';
      if (paymentGroup) paymentGroup.style.display = 'block';
    } else {
      // STANDARD
      if (feeInput) feeInput.value = Number(defaultFee).toFixed(2);
      if (customGroup) customGroup.style.display = 'none';
      if (paymentGroup) paymentGroup.style.display = 'block';
      if (reasonInput && reasonInput.value === 'Garantía de equipo / Traslado gratuito por cortesía') {
        reasonInput.value = '';
      }
    }
  });

  document.getElementById('migScenario')?.addEventListener('change', (e) => {
    const scenario = e.target.value;
    const hint = document.getElementById('migScenarioHint');
    if (hint) {
      if (scenario === 'RESTORED_BACKUP') {
        hint.textContent = 'Recomendado si el cliente restauró su copia de Google Drive o .mlbg: reactiva el nuevo equipo preservando exactamente su vencimiento con cero duplicación de días.';
      } else {
        hint.textContent = 'Instalación limpia desde cero: el token transferirá exactamente los días restantes hasta la fecha de expiración.';
      }
    }
  });

  // Modal Crear Release
  document.getElementById('btnOpenCreateRelease')?.addEventListener('click', () => {
    resetCreateReleaseModalState();
    openModal('modalCreateRelease');
  });

  document.getElementById('btnSubmitCreateRelease')?.addEventListener('click', async () => {
    const versionName = document.getElementById('relVersionName').value.trim();
    const versionCode = parseInt(document.getElementById('relVersionCode').value, 10) || 82;
    const minRequired = document.getElementById('relMinRequiredVersion').value.trim() || '9.0.0';
    const schemaVersion = parseInt(document.getElementById('relDbSchema').value, 10) || 36;
    const type = document.getElementById('relType').value;
    const rawSizeMb = document.getElementById('relSizeMb').value.trim();
    const sizeMb = rawSizeMb ? formatApkSizeMb(rawSizeMb) : '';
    const url = document.getElementById('relDownloadUrl').value.trim();
    const sha = document.getElementById('relSha256').value.trim();
    const changelog = document.getElementById('relChangelog').value.trim();
    const internalNotes = document.getElementById('relInternalNotes').value.trim();
    const uploadedPath = document.getElementById('relUploadedPath').value.trim();
    const abiVariant = document.getElementById('relAbiVariant').value || 'UNIVERSAL';

    const sigStatus = document.getElementById('relSignatureStatus')?.value;
    const sigVerifiedRaw = document.getElementById('relSignatureVerified')?.value;
    const sigVerified = sigVerifiedRaw === 'true' ? true : (sigVerifiedRaw === 'false' ? false : null);
    const signerSha = document.getElementById('relSignerSha256')?.value;
    const signerDn = document.getElementById('relSignerDn')?.value;

    // Escudo Anti-debug.apk: Bloqueo preventivo de firmas no oficiales
    if (sigStatus === 'UNOFFICIAL_SIGNATURE') {
      const chkAck = document.getElementById('chkAcknowledgeUnofficialApk');
      if (!chkAck || !chkAck.checked) {
        showToast('ATENCIÓN: Este APK no cuenta con la firma comercial oficial. Debes confirmar la casilla de advertencia para poder publicarlo.', 'error');
        return;
      }
    }

    if (!versionName) {
      showToast('Por favor completa el nombre de la versión.', 'warning');
      return;
    }

    try {
      const res = await fetch('/api/releases', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          version_name: versionName,
          version_code: versionCode,
          min_required_version: minRequired,
          db_schema_version: schemaVersion,
          type: type,
          file_size_mb: sizeMb,
          apk_file_path: uploadedPath,
          apk_download_url: url,
          apk_sha256: sha,
          changelog: changelog,
          internal_notes: internalNotes,
          abi_variant: abiVariant,
          signature_verified: sigVerified,
          signature_status: sigStatus || 'UNVERIFIED',
          signer_sha256: signerSha,
          signer_dn: signerDn,
        }),
      });

      if (!res.ok) throw new Error('Error al publicar versión');
      closeModal('modalCreateRelease');
      resetCreateReleaseModalState();
      showToast(`Versión v${versionName} registrada y publicada.`, 'success');
      await loadReleases();
      await loadReleaseMatrix();
      await loadDashboard();
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Modal Editar Release / Changelog (Guardar)
  document.getElementById('btnSubmitEditRelease')?.addEventListener('click', async () => {
    const versionName = document.getElementById('editRelVersionName').value;
    const versionCode = parseInt(document.getElementById('editRelVersionCode').value, 10) || 82;
    const dbSchema = parseInt(document.getElementById('editRelDbSchema').value, 10) || 36;
    const minRequired = document.getElementById('editRelMinRequiredVersion').value.trim() || '9.0.0';
    const type = document.getElementById('editRelType').value;
    const url = document.getElementById('editRelDownloadUrl').value.trim();
    const changelog = document.getElementById('editRelChangelog').value.trim();
    const internalNotes = document.getElementById('editRelInternalNotes').value.trim();

    try {
      const res = await fetch(`/api/releases/${encodeURIComponent(versionName)}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          version_code: versionCode,
          db_schema_version: dbSchema,
          min_required_version: minRequired,
          type: type,
          apk_download_url: url,
          changelog: changelog,
          internal_notes: internalNotes,
        }),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || 'Error al actualizar versión');
      }
      const updatedRel = await res.json().catch(() => null);
      closeModal('modalEditRelease');
      showToast(`Versión v${versionName} actualizada.`, 'success');
      if (updatedRel && typeof syncReleaseAcrossUiAndComposer === 'function') {
        await syncReleaseAcrossUiAndComposer(versionName, updatedRel);
      } else {
        await loadReleases();
        await loadReleaseMatrix();
      }
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Inputs ocultos para subida de variantes en modal de edición
  document.getElementById('editRelUniversalInput')?.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (file) {
      handleVariantFileSelected(file, 'universal', currentUploadVariantVersion);
    }
    e.target.value = '';
  });

  document.getElementById('editRelArm64Input')?.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (file) {
      handleVariantFileSelected(file, 'arm64', currentUploadVariantVersion);
    }
    e.target.value = '';
  });

  // Modal Registrar Pago Manual (Abrir y Guardar)
  document.getElementById('btnOpenManualPayment')?.addEventListener('click', () => {
    if (!currentHistoryClientId) return;
    openAddPaymentModal(currentHistoryClientId);
  });

  // Cambio reactivo de preset de concepto en modal de pago
  document.getElementById('manualPayPlanPreset')?.addEventListener('change', (e) => {
    const val = e.target.value;
    const customConcept = document.getElementById('manualPayCustomConcept');
    const amountInput = document.getElementById('manualPayAmount');
    const planInput = document.getElementById('manualPayPlan');
    const paymentId = document.getElementById('manualPayId')?.value?.trim();

    if (val === 'CUSTOM') {
      if (customConcept) {
        customConcept.style.display = 'block';
        customConcept.focus();
      }
      if (planInput) planInput.value = customConcept?.value?.trim() || '';
    } else {
      if (customConcept) {
        customConcept.style.display = 'none';
        customConcept.value = '';
      }
      if (planInput) planInput.value = val;
      const selectedOpt = e.target.selectedOptions?.[0];
      const price = selectedOpt?.dataset?.price;
      if (price !== undefined && !paymentId && amountInput) {
        amountInput.value = parseFloat(price).toFixed(2);
      }
    }
  });

  document.getElementById('btnSubmitManualPayment')?.addEventListener('click', async () => {
    const clientId = document.getElementById('manualPayClientId').value;
    const paymentId = document.getElementById('manualPayId')?.value?.trim();
    const rawAmt = parseFloat(document.getElementById('manualPayAmount').value);
    if (isNaN(rawAmt) || rawAmt < 0) {
      showToast('El monto debe ser mayor o igual a cero.', 'warning');
      return;
    }
    const amount = parseFloat(rawAmt.toFixed(2));
    
    // Resolver concepto según preset o personalizado
    let plan = '';
    const presetSelect = document.getElementById('manualPayPlanPreset');
    const customConceptInput = document.getElementById('manualPayCustomConcept');
    if (presetSelect && presetSelect.value === 'CUSTOM') {
      plan = customConceptInput?.value?.trim() || '';
    } else if (presetSelect && presetSelect.value) {
      plan = presetSelect.value;
    } else {
      plan = document.getElementById('manualPayPlan')?.value?.trim() || '';
    }

    if (!plan) {
      showToast('Por favor completa el concepto o plan del pago.', 'warning');
      return;
    }

    const method = document.getElementById('manualPayMethod').value;
    const ref = document.getElementById('manualPayRef').value.trim();
    const notes = document.getElementById('manualPayNotes').value.trim();
    const date = document.getElementById('manualPayDate')?.value || new Date().toISOString().substring(0, 10);
    const shouldGenerateReceipt = document.getElementById('manualPayGenerateReceipt')?.checked ?? false;

    try {
      let res;
      if (paymentId) {
        // Actualizar pago existente (PUT)
        res = await fetch(`/api/clients/${clientId}/payments/${paymentId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            amount: amount,
            plan: plan,
            method: method,
            reference: ref,
            notes: notes,
            date: date,
          }),
        });
      } else {
        // Registrar nuevo pago (POST)
        res = await fetch(`/api/clients/${clientId}/payments`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            amount: amount,
            plan: plan,
            method: method,
            reference: ref,
            notes: notes,
            date: date,
          }),
        });
      }

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || 'Error al procesar registro de pago');
      }

      const updatedClient = await res.json();
      closeModal('modalManualPayment');
      showToast(paymentId ? 'Pago actualizado con éxito.' : 'Pago manual registrado con éxito.', 'success');

      // Si se marcó emitir o abrir comprobante de pago al guardar
      if (shouldGenerateReceipt) {
        if (paymentId) {
          openPaymentReceiptModal(clientId, paymentId);
        } else if (updatedClient && Array.isArray(updatedClient.payment_history)) {
          const newPayment = updatedClient.payment_history[updatedClient.payment_history.length - 1];
          if (newPayment && newPayment.id) {
            openPaymentReceiptModal(clientId, newPayment.id);
          }
        }
      }

      if (currentHistoryClientId === clientId) {
        await openClientHistoryModal(clientId);
      }
      if (currentDrawerClientId === clientId) {
        await openClient360Drawer(clientId, 'drawerTabFinances');
      }
      await loadClients();
      await loadDashboard();
      await loadFinances();
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });
}

function openEditClientModal(clientId) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;

  document.getElementById('editClientId').value = client.id;
  document.getElementById('editBizName').value = client.business_name || '';
  document.getElementById('editOwnerName').value = client.owner_name || '';
  document.getElementById('editDocId').value = client.document_id || '';
  document.getElementById('editPhone').value = client.phone || '';
  document.getElementById('editDeviceId').value = client.current_device_id || '';
  document.getElementById('editInstalledVersion').value = client.installed_version || '9.24.0';
  document.getElementById('editLicenseType').value = client.license_type || 'MENSUAL';
  document.getElementById('editLicenseStatus').value = client.license_status || 'ACTIVE';

  if (client.license_expires) {
    document.getElementById('editLicenseExpires').value = client.license_expires.substring(0, 10);
  } else {
    document.getElementById('editLicenseExpires').value = '';
  }

  if (client.updates_until) {
    document.getElementById('editUpdatesUntil').value = client.updates_until.substring(0, 10);
  } else {
    document.getElementById('editUpdatesUntil').value = '';
  }

  document.getElementById('editAiExtraCredits').value = client.ai_extra_credits || 0;
  document.getElementById('editNextNonce').value = client.next_nonce || 1;
  document.getElementById('editNotes').value = client.notes || '';

  openModal('modalEditClient');
}
