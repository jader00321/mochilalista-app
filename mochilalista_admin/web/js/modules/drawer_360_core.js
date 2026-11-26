// =================== DRAWER LATERAL: FICHA 360° DEL CLIENTE (FASE 4A + FASE 5) ===================
/**
 * Control inteligente del campo Ventana Updates en la Ficha 360°
 */
function updateDrawerEditPlanFields(plan) {
  const p = (plan || '').toUpperCase();
  const grpUpdates = document.getElementById('grpDrawerEditUpdates');
  const updatesInput = document.getElementById('drawerEditUpdates');
  const isPerpetualOrPass = (p === 'PERPETUO_LIBERADO' || p === 'PERPETUO' || p === 'PASE_ACTUALIZACION_ANUAL');
  if (grpUpdates) {
    grpUpdates.style.display = isPerpetualOrPass ? 'block' : 'none';
  }
  if (updatesInput) {
    if (!isPerpetualOrPass) {
      updatesInput.value = '';
    }
  }
}

// =================== GESTIÓN GLOBAL DE PESTAÑAS EN DRAWER 360° (FASE 2 PLAN 18.5) ===================
function switchDrawerTab(targetTabId) {
  const normalizedId = (targetTabId === 'drawerTabSummary') ? 'drawerTabOverview' : targetTabId;
  currentDrawerTab = normalizedId;
  const dtabs = document.querySelectorAll('.drawer-tab-btn');
  dtabs.forEach(b => {
    if (b.dataset.dtab === normalizedId) {
      b.classList.add('active');
    } else {
      b.classList.remove('active');
    }
  });
  document.querySelectorAll('.drawer-tab-pane').forEach(p => {
    if (p.id === normalizedId) {
      p.classList.add('active');
    } else {
      p.classList.remove('active');
    }
  });

  if (normalizedId === 'drawerTabEdit') {
    setTimeout(() => {
      const followupInput = document.getElementById('drawerEditFollowupDate');
      if (followupInput) {
        followupInput.focus();
        followupInput.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 150);
  }
}
window.switchDrawerTab = switchDrawerTab;

function initDrawerEvents() {
  const dtabs = document.querySelectorAll('.drawer-tab-btn');
  dtabs.forEach(btn => {
    btn.addEventListener('click', () => {
      switchDrawerTab(btn.dataset.dtab);
    });
  });

  // Botón rápido en datos de contacto "Editar Seguimiento / Notas"
  document.getElementById('btnDrawerQuickEditFollowup')?.addEventListener('click', (e) => {
    e.preventDefault();
    switchDrawerTab('drawerTabEdit');
  });

  // Control inteligente de Ventana Updates en cambio de plan
  document.getElementById('drawerEditPlanSelect')?.addEventListener('change', (e) => {
    updateDrawerEditPlanFields(e.target.value);
  });

  // Edición rápida inline de Modelo Celular en pestaña Hardware
  const btnEditModel = document.getElementById('btnDrawerEditModelInline');
  const modelRow = document.getElementById('drawerHwModelRow');
  const modelForm = document.getElementById('drawerHwModelInlineForm');
  const modelInput = document.getElementById('inputDrawerModelInline');
  const btnSaveModel = document.getElementById('btnSaveDrawerModelInline');
  const btnCancelModel = document.getElementById('btnCancelDrawerModelInline');

  btnEditModel?.addEventListener('click', () => {
    const client = globalClients.find(c => c.id === currentDrawerClientId);
    if (modelInput) modelInput.value = client?.device_model || '';
    if (modelRow) modelRow.style.display = 'none';
    if (modelForm) modelForm.style.display = 'flex';
    modelInput?.focus();
  });

  btnCancelModel?.addEventListener('click', () => {
    if (modelForm) modelForm.style.display = 'none';
    if (modelRow) modelRow.style.display = 'flex';
  });

  btnSaveModel?.addEventListener('click', async () => {
    if (!currentDrawerClientId || !modelInput) return;
    const newModel = modelInput.value.trim();
    try {
      const res = await fetch(`/api/clients/${currentDrawerClientId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_model: newModel }),
      });
      if (!res.ok) throw new Error('Error al actualizar modelo');
      const target = globalClients.find(c => c.id === currentDrawerClientId);
      if (target) target.device_model = newModel;

      const disp = document.getElementById('drawerHwModelDisplay');
      if (disp) disp.textContent = newModel || 'No registrado';
      const disp2 = document.getElementById('drawerDeviceModel');
      if (disp2) disp2.textContent = newModel || 'No registrado';
      const editInp = document.getElementById('drawerEditDeviceModel');
      if (editInp) editInp.value = newModel;

      if (modelForm) modelForm.style.display = 'none';
      if (modelRow) modelRow.style.display = 'flex';
      showToast('Modelo de celular actualizado.', 'success');
      await loadClients();
      await loadDashboard();
    } catch (err) {
      showToast('Error: ' + err.message, 'error');
    }
  });

  document.getElementById('formDrawerEditClient')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!currentDrawerClientId) return;

    const biz = document.getElementById('drawerEditBizName').value.trim();
    const owner = document.getElementById('drawerEditOwnerName').value.trim();
    const doc = document.getElementById('drawerEditDocId').value.trim();
    const phone = document.getElementById('drawerEditPhone').value.trim();
    const device = document.getElementById('drawerEditDeviceId').value.trim().toUpperCase();
    const model = document.getElementById('drawerEditDeviceModel')?.value.trim() || '';
    const plan = document.getElementById('drawerEditPlanSelect')?.value || 'MENSUAL';
    const ver = document.getElementById('drawerEditInstalledVersion').value.trim();
    const exp = document.getElementById('drawerEditExpires')?.value || null;
    const upd = document.getElementById('drawerEditUpdates')?.value || null;
    const aiRep = parseInt(document.getElementById('drawerEditAiReported')?.value) || 0;
    const aiBonus = parseInt(document.getElementById('drawerEditAiPendingBonus')?.value) || 0;
    const followup = document.getElementById('drawerEditFollowupDate')?.value || null;
    const notes = document.getElementById('drawerEditNotes').value.trim();

    try {
      const res = await fetch(`/api/clients/${currentDrawerClientId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          business_name: biz,
          owner_name: owner,
          document_id: doc,
          phone: phone,
          current_device_id: device,
          device_model: model,
          license_type: plan,
          installed_version: ver,
          license_expires: exp,
          updates_until: upd,
          ai_reported_balance: aiRep,
          ai_pending_bonus: aiBonus,
          next_followup_date: followup,
          notes: notes,
        }),
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || 'Error al actualizar datos');
      }
      showToast('Ficha 360° del cliente actualizada de inmediato.', 'success');
      await loadClients();
      await loadDashboard();
      openClient360Drawer(currentDrawerClientId, 'drawerTabEdit');
    } catch (err) {
      showToast('Error: ' + err.message, 'error');
    }
  });

  document.getElementById('btnDrawerEmitLicense')?.addEventListener('click', () => {
    if (!currentDrawerClientId) return;
    const cid = currentDrawerClientId;
    drawerReturnState = null;
    closeClient360Drawer();
    selectClientForLicense(cid);
  });

  document.getElementById('btnDrawerMigrateDev')?.addEventListener('click', () => {
    if (!currentDrawerClientId) return;
    const cid = currentDrawerClientId;
    openMigrateModal(cid);
  });

  document.getElementById('btnDrawerAddPayment')?.addEventListener('click', () => {
    if (!currentDrawerClientId) return;
    openAddPaymentModal(currentDrawerClientId);
  });

  // Modal Sincronizar Datos Reportados del Celular (Envío de formulario)
  document.getElementById('btnSubmitSyncReported')?.addEventListener('click', async () => {
    const clientId = document.getElementById('syncRepClientId').value;
    if (!clientId) return;

    const deviceId = document.getElementById('syncRepDeviceId').value.trim();
    const deviceModel = document.getElementById('syncRepDeviceModel').value.trim();
    const version = document.getElementById('syncRepVersion').value.trim();
    const aiBalance = parseInt(document.getElementById('syncRepAiBalance').value);
    const trialDays = document.getElementById('syncRepTrialDays').value ? parseInt(document.getElementById('syncRepTrialDays').value) : null;
    const expires = document.getElementById('syncRepExpires').value || null;
    const notes = document.getElementById('syncRepNotes').value.trim();

    try {
      const res = await fetch(`/api/clients/${clientId}/sync-reported`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          device_id: deviceId || undefined,
          device_model: deviceModel || undefined,
          installed_version: version || undefined,
          ai_reported_balance: !isNaN(aiBalance) ? aiBalance : undefined,
          trial_days_remaining: trialDays !== null && !isNaN(trialDays) ? trialDays : undefined,
          license_expires: expires || undefined,
          notes: notes || undefined,
        }),
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || 'Error al sincronizar datos reportados');
      }

      await loadClients();
      await loadDashboard();
      closeModal('modalSyncReported');
      showToast('Datos del celular sincronizados con éxito.', 'success');
    } catch (e) {
      showToast('Error: ' + e.message, 'error');
    }
  });

  // Bidireccionalidad reactiva en Modal Sincronizar Datos Reportados
  const syncDaysInput = document.getElementById('syncRepTrialDays');
  const syncExpInput = document.getElementById('syncRepExpires');
  if (syncDaysInput && syncExpInput) {
    syncDaysInput.addEventListener('input', () => {
      const days = parseInt(syncDaysInput.value);
      if (!isNaN(days) && days >= 0) {
        const d = new Date();
        d.setDate(d.getDate() + days);
        syncExpInput.value = d.toISOString().substring(0, 10);
      }
    });
    syncExpInput.addEventListener('change', () => {
      if (syncExpInput.value) {
        const target = new Date(syncExpInput.value + 'T00:00:00');
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const diff = Math.max(0, Math.ceil((target - today) / (1000 * 60 * 60 * 24)));
        syncDaysInput.value = diff;
      }
    });
  }
}
