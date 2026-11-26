function closeClient360Drawer() {
  drawerReturnState = null;
  document.getElementById('drawerClient360Backdrop')?.classList.remove('open');
  document.getElementById('drawerClient360')?.classList.remove('open');
  currentDrawerClientId = null;
}

/**
 * Eliminación segura con confirmación del cliente desde la Ficha 360°
 */
function deleteClientFromDrawer() {
  if (!currentDrawerClientId) return;
  drawerReturnState = null;
  const clientId = currentDrawerClientId;
  const client = globalClients.find(c => c.id === clientId);
  const name = client ? client.business_name : clientId;

  showConfirmModal(
    'Eliminar Cliente Definitivamente',
    `¿Estás seguro de que deseas eliminar permanentemente a "${name}" de la cartera activa? Se creará automáticamente un respaldo de seguridad en disco antes de procesar la eliminación.`,
    async () => {
      try {
        const res = await fetch(`/api/clients/${currentDrawerClientId}`, {
          method: 'DELETE',
        });
        if (!res.ok) {
          const errData = await res.json().catch(() => ({}));
          throw new Error(errData.error || 'Error al eliminar cliente');
        }
        showToast(`Cliente "${name}" eliminado de la cartera exitosamente.`, 'success');
        closeClient360Drawer();
        await loadClients();
        await loadDashboard();
      } catch (err) {
        showToast('Error al eliminar: ' + err.message, 'error');
      }
    },
    true
  );
}

/**
 * Apertura de Modal para Registrar Pago Manual
 */
/**
 * Apertura de Modal para Registrar Pago Manual (Fase 5)
 */
function openAddPaymentModal(clientId) {
  const client = globalClients.find(c => c.id === clientId);
  if (!client) return;
  document.getElementById('manualPayClientId').value = clientId;
  const payId = document.getElementById('manualPayId');
  if (payId) payId.value = '';
  const payTitle = document.getElementById('manualPayTitle');
  if (payTitle) payTitle.textContent = 'Registrar Pago';

  // Resumen del Cliente en Cabecera
  const bizEl = document.getElementById('manualPayBizName');
  if (bizEl) bizEl.textContent = client.business_name || 'Sin negocio';
  const ownerEl = document.getElementById('manualPayOwnerName');
  if (ownerEl) ownerEl.textContent = client.owner_name || 'Sin propietario';
  const devEl = document.getElementById('manualPayDevId');
  if (devEl) devEl.textContent = client.current_device_id || '-';
  const statusBadge = document.getElementById('manualPayStatusBadge');
  if (statusBadge) {
    statusBadge.outerHTML = `<span id="manualPayStatusBadge">${getClientStatusBadge(client)}</span>`;
  }
  const expEl = document.getElementById('manualPayExpiresText');
  if (expEl) expEl.textContent = client.license_expires ? client.license_expires.substring(0, 10) : 'No configurada';

  // Total recaudado
  let totalPaid = 0;
  if (Array.isArray(client.payment_history)) {
    client.payment_history.forEach(p => totalPaid += (parseFloat(p.amount) || 0));
  }
  const totalPaidEl = document.getElementById('manualPayTotalPaid');
  if (totalPaidEl) totalPaidEl.textContent = `S/ ${totalPaid.toFixed(2)}`;

  const payDate = document.getElementById('manualPayDate');
  if (payDate) payDate.value = new Date().toISOString().substring(0, 10);

  // Preset inteligente homologado
  const presetSel = document.getElementById('manualPayPlanPreset');
  const customConcept = document.getElementById('manualPayCustomConcept');
  if (presetSel) {
    presetSel.value = 'MENSUAL';
    if (customConcept) {
      customConcept.value = '';
      customConcept.style.display = 'none';
    }
  }

  const defaultPrice = ownerConfig?.catalog?.['MENSUAL']?.price ?? 35.0;
  document.getElementById('manualPayAmount').value = parseFloat(defaultPrice).toFixed(2);
  document.getElementById('manualPayPlan').value = 'MENSUAL';
  document.getElementById('manualPayMethod').value = 'Yape';
  document.getElementById('manualPayRef').value = '';
  document.getElementById('manualPayNotes').value = '';

  // Banner y Checkbox de Comprobante
  const receiptNotice = document.getElementById('manualPayReceiptNotice');
  if (receiptNotice) receiptNotice.style.display = 'none';
  const receiptLabel = document.getElementById('manualPayGenerateReceiptLabel');
  if (receiptLabel) receiptLabel.textContent = 'Generar Boleta de Pago al guardar (Abre comprobante BOL-XXXX de inmediato)';
  const genReceiptChk = document.getElementById('manualPayGenerateReceipt');
  if (genReceiptChk) genReceiptChk.checked = true;

  openModal('modalManualPayment');
}

const openManualPaymentModal = openAddPaymentModal;

/**
 * Apertura de Modal para Editar Pago Registrado
 */
function openEditPaymentModal(clientId, payment) {
  const client = globalClients.find(c => c.id === clientId);
  document.getElementById('manualPayClientId').value = clientId;
  const payId = document.getElementById('manualPayId');
  if (payId) payId.value = payment.id || '';
  const payTitle = document.getElementById('manualPayTitle');
  if (payTitle) payTitle.textContent = 'Editar Pago Registrado';

  // Resumen del Cliente en Cabecera
  if (client) {
    const bizEl = document.getElementById('manualPayBizName');
    if (bizEl) bizEl.textContent = client.business_name || 'Sin negocio';
    const ownerEl = document.getElementById('manualPayOwnerName');
    if (ownerEl) ownerEl.textContent = client.owner_name || 'Sin propietario';
    const devEl = document.getElementById('manualPayDevId');
    if (devEl) devEl.textContent = client.current_device_id || '-';
    const statusBadge = document.getElementById('manualPayStatusBadge');
    if (statusBadge) {
      statusBadge.outerHTML = `<span id="manualPayStatusBadge">${getClientStatusBadge(client)}</span>`;
    }
    const expEl = document.getElementById('manualPayExpiresText');
    if (expEl) expEl.textContent = client.license_expires ? client.license_expires.substring(0, 10) : 'No configurada';

    let totalPaid = 0;
    if (Array.isArray(client.payment_history)) {
      client.payment_history.forEach(p => totalPaid += (parseFloat(p.amount) || 0));
    }
    const totalPaidEl = document.getElementById('manualPayTotalPaid');
    if (totalPaidEl) totalPaidEl.textContent = `S/ ${totalPaid.toFixed(2)}`;
  }

  const payDate = document.getElementById('manualPayDate');
  if (payDate) payDate.value = payment.date ? payment.date.substring(0, 10) : new Date().toISOString().substring(0, 10);
  document.getElementById('manualPayAmount').value = parseFloat(payment.amount ?? 0).toFixed(2);

  // Matching de slug canónico con retrocompatibilidad o fallback a CUSTOM
  const presetSel = document.getElementById('manualPayPlanPreset');
  const customConcept = document.getElementById('manualPayCustomConcept');
  const planVal = payment.plan || '';
  const slug = normalizePlanToSlug(planVal);

  if (slug && presetSel) {
    presetSel.value = slug;
    if (customConcept) {
      customConcept.value = '';
      customConcept.style.display = 'none';
    }
    document.getElementById('manualPayPlan').value = slug;
  } else {
    if (presetSel) presetSel.value = 'CUSTOM';
    if (customConcept) {
      customConcept.value = planVal;
      customConcept.style.display = 'block';
    }
    document.getElementById('manualPayPlan').value = planVal;
  }

  document.getElementById('manualPayMethod').value = payment.method || 'Yape';
  document.getElementById('manualPayRef').value = payment.reference || '';
  document.getElementById('manualPayNotes').value = payment.notes || '';

  // Blindaje contable de comprobante previo
  const receiptNotice = document.getElementById('manualPayReceiptNotice');
  const receiptBadge = document.getElementById('manualPayReceiptNumberBadge');
  const receiptLabel = document.getElementById('manualPayGenerateReceiptLabel');
  const genReceiptChk = document.getElementById('manualPayGenerateReceipt');

  if (payment.receipt_number) {
    if (receiptNotice) receiptNotice.style.display = 'flex';
    if (receiptBadge) receiptBadge.textContent = payment.receipt_number;
    if (receiptLabel) receiptLabel.textContent = `Abrir comprobante ${payment.receipt_number} actualizado al guardar`;
    if (genReceiptChk) genReceiptChk.checked = true;
  } else {
    if (receiptNotice) receiptNotice.style.display = 'none';
    if (receiptLabel) receiptLabel.textContent = 'Generar Boleta de Pago al guardar (Abre comprobante BOL-XXXX de inmediato)';
    if (genReceiptChk) genReceiptChk.checked = false;
  }

  openModal('modalManualPayment');
}

/**
 * Confirmación y eliminación de pago en el historial contable
 */
function confirmDeletePayment(clientId, paymentId) {
  showConfirmModal(
    'Eliminar Registro de Pago',
    '¿Estás seguro de que deseas anular y eliminar este registro de pago del historial contable del cliente?',
    async () => {
      try {
        const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}`, {
          method: 'DELETE',
        });
        if (!res.ok) {
          const errData = await res.json().catch(() => ({}));
          throw new Error(errData.error || 'Error al eliminar pago');
        }
        showToast('Registro de pago eliminado correctamente.', 'success');
        if (currentDrawerClientId === clientId) {
          await openClient360Drawer(clientId, 'drawerTabFinances');
        }
        if (currentHistoryClientId === clientId) {
          await openClientHistoryModal(clientId);
        }
        await loadClients();
        await loadDashboard();
        await loadFinances();
      } catch (err) {
        showToast('Error al eliminar pago: ' + err.message, 'error');
      }
    },
    true
  );
}
