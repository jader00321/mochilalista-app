/**
 * ==========================================================================
 * GENERADOR Y PERSONALIZADOR DE BOLETAS DE PAGO BOL-XXXX (FASE 5)
 * ==========================================================================
 */
function closeReceiptModal() {
  closeModal('modalPaymentReceipt');
}

/**
 * Resuelve y abre la Boleta de Pago con correlativo persistente (idempotente)
 */
async function openPaymentReceiptModal(clientId, paymentId, voucherType = null) {
  try {
    const payload = {};
    if (voucherType) payload.voucher_type = voucherType;
    const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}/receipt`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'No se pudo resolver el comprobante de pago.');
    }
    const data = await res.json();
    currentReceiptData = data;
    populateReceiptUI(data);
    openModal('modalPaymentReceipt');
  } catch (e) {
    showToast('Error al abrir comprobante: ' + e.message, 'error');
  }
}

async function switchReceiptVoucherType(newType) {
  if (!currentReceiptData || !currentReceiptData.client || !currentReceiptData.payment) return;
  const clientId = currentReceiptData.client.id;
  const paymentId = currentReceiptData.payment.id;
  try {
    const res = await fetch(`/api/clients/${clientId}/payments/${paymentId}/receipt`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        voucher_type: newType,
        invoice_ruc: document.getElementById('rcInputInvoiceRuc')?.value.trim() || undefined,
        invoice_business_name: document.getElementById('rcInputInvoiceBizName')?.value.trim() || undefined,
        invoice_fiscal_address: document.getElementById('rcInputInvoiceAddress')?.value.trim() || undefined,
        show_igv_breakdown: document.getElementById('rcCheckShowIgv')?.checked ?? false,
      }),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Error al cambiar serie del comprobante.');
    }
    const data = await res.json();
    currentReceiptData = data;
    populateReceiptUI(data);
  } catch (e) {
    showToast('Error al alternar serie: ' + e.message, 'error');
  }
}

function populateReceiptUI(data) {
  if (!data) return;
  const rc = data.receipt_config || {};
  const payment = data.payment || {};
  const client = data.client || {};
  const voucherType = data.voucher_type || (data.receipt_number?.startsWith('FAC') ? 'FAC' : 'BOL');
  const isInvoice = voucherType === 'FAC';

  // Modal header badge & main title
  const mainTitle = document.getElementById('receiptModalMainTitle');
  if (mainTitle) {
    mainTitle.textContent = isInvoice ? 'Factura de Pago Oficial & Comprobante Digital' : 'Generador de Boleta de Pago';
  }
  const badge = document.getElementById('receiptModalBadge');
  if (badge) badge.textContent = data.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');

  // Selector de Tipo de Comprobante
  const selectVoucher = document.getElementById('rcSelectVoucherType');
  if (selectVoucher) selectVoucher.value = voucherType;

  // Bloque de datos fiscales de factura
  const invoiceBlock = document.getElementById('rcInvoiceFieldsBlock');
  if (invoiceBlock) invoiceBlock.style.display = isInvoice ? 'block' : 'none';

  const invRuc = document.getElementById('rcInputInvoiceRuc');
  if (invRuc) invRuc.value = payment.invoice_ruc || client.document_number || '';
  const invBiz = document.getElementById('rcInputInvoiceBizName');
  if (invBiz) invBiz.value = payment.invoice_business_name || client.business_name || '';
  const invAddr = document.getElementById('rcInputInvoiceAddress');
  if (invAddr) invAddr.value = payment.invoice_fiscal_address || '';
  const invIgv = document.getElementById('rcCheckShowIgv');
  if (invIgv) invIgv.checked = payment.show_igv_breakdown === true || (isInvoice && rc.show_igv_breakdown === true);

  // Título de comprobante
  const titleInp = document.getElementById('rcInputTitle');
  if (titleInp) {
    if (isInvoice) {
      titleInp.value = rc.invoice_title || 'FACTURA DE VENTA / PAGO';
    } else {
      titleInp.value = rc.title || 'BOLETA DE PAGO ADMINISTRATIVA';
    }
  }

  const commInp = document.getElementById('rcInputCommercialName');
  if (commInp) commInp.value = rc.commercial_name || 'MochilaLista';
  const issuerInp = document.getElementById('rcInputIssuerName');
  if (issuerInp) issuerInp.value = rc.issuer_name || 'Julio Angello Vasquez Navarro';
  const docInp = document.getElementById('rcInputIssuerDoc');
  if (docInp) docInp.value = rc.issuer_doc || 'D.N.I. / R.U.C. Registrado';
  const phoneInp = document.getElementById('rcInputIssuerPhone');
  if (phoneInp) phoneInp.value = rc.issuer_phone || '+51 922 836 879';
  const cityInp = document.getElementById('rcInputIssuerCity');
  if (cityInp) cityInp.value = rc.issuer_city || 'Piura, Perú';

  // 9 Interruptores de Visibilidad
  const setChk = (id, val) => {
    const el = document.getElementById(id);
    if (el) el.checked = val !== false;
  };
  setChk('rcCheckShowLogo', rc.show_logo);
  setChk('rcCheckShowIssuerDoc', rc.show_issuer_doc);
  setChk('rcCheckShowIssuerPhone', rc.show_issuer_phone);
  setChk('rcCheckShowClientDoc', rc.show_client_doc);
  setChk('rcCheckShowHardwareId', rc.show_hardware_id);
  setChk('rcCheckShowOperationNumber', rc.show_operation_number);
  setChk('rcCheckShowObservation', rc.show_observation);
  setChk('rcCheckShowSignature', rc.show_signature);
  setChk('rcCheckShowFooterNotes', rc.show_footer_notes);

  const colorInp = document.getElementById('rcInputAccentColor');
  if (colorInp) colorInp.value = rc.accent_color || '#2563eb';

  const noteInp = document.getElementById('rcInputCustomNote');
  if (noteInp) noteInp.value = payment.receipt_custom_note || '';

  const footInp = document.getElementById('rcInputFooterNotes');
  if (footInp) footInp.value = rc.footer_notes || 'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.';

  const signInp = document.getElementById('rcInputSignature');
  if (signInp) signInp.value = rc.signature_text || 'Administración Comercial — MochilaLista';

  renderReceiptPreviewAndCanvas();
}

function renderReceiptPreviewAndCanvas() {
  if (!currentReceiptData) return;
  const payment = currentReceiptData.payment || {};
  const client = currentReceiptData.client || {};
  const voucherType = currentReceiptData.voucher_type || (currentReceiptData.receipt_number?.startsWith('FAC') ? 'FAC' : 'BOL');
  const isInvoice = voucherType === 'FAC';

  const title = document.getElementById('rcInputTitle')?.value.trim() || (isInvoice ? 'FACTURA DE VENTA / PAGO' : 'BOLETA DE PAGO ADMINISTRATIVA');
  const commercial = document.getElementById('rcInputCommercialName')?.value.trim() || ownerConfig?.legal_identity?.commercial_name || 'MochilaLista';
  const issuer = document.getElementById('rcInputIssuerName')?.value.trim() || ownerConfig?.legal_identity?.author_full_name || 'Julio Angello Vasquez Navarro';
  const issuerDoc = document.getElementById('rcInputIssuerDoc')?.value.trim() || 'D.N.I. / R.U.C. Registrado';
  const issuerPhone = document.getElementById('rcInputIssuerPhone')?.value.trim() || ownerConfig?.legal_identity?.support_phone || '+51 922 836 879';
  const issuerCity = document.getElementById('rcInputIssuerCity')?.value.trim() || 'Piura, Perú';

  // Toggles de visibilidad
  const showLogo = document.getElementById('rcCheckShowLogo')?.checked !== false;
  const showIssuerDoc = document.getElementById('rcCheckShowIssuerDoc')?.checked !== false;
  const showIssuerPhone = document.getElementById('rcCheckShowIssuerPhone')?.checked !== false;
  const showClientDoc = document.getElementById('rcCheckShowClientDoc')?.checked !== false;
  const showHardwareId = document.getElementById('rcCheckShowHardwareId')?.checked !== false;
  const showOperationNumber = document.getElementById('rcCheckShowOperationNumber')?.checked !== false;
  const showObservation = document.getElementById('rcCheckShowObservation')?.checked !== false;
  const showSignature = document.getElementById('rcCheckShowSignature')?.checked !== false;
  const showFooterNotes = document.getElementById('rcCheckShowFooterNotes')?.checked !== false;

  const accentColor = document.getElementById('rcInputAccentColor')?.value || '#2563eb';
  const customNote = document.getElementById('rcInputCustomNote')?.value.trim() || '';
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || '';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || '';

  // Datos fiscales de factura
  const invoiceRuc = document.getElementById('rcInputInvoiceRuc')?.value.trim() || '';
  const invoiceBiz = document.getElementById('rcInputInvoiceBizName')?.value.trim() || '';
  const invoiceAddress = document.getElementById('rcInputInvoiceAddress')?.value.trim() || '';
  const showIgv = document.getElementById('rcCheckShowIgv')?.checked === true;

  const correlative = currentReceiptData.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const rawDate = currentReceiptData.receipt_issued_at || payment.date || new Date().toISOString();
  const dateFormatted = formatLimaReceiptStamp(rawDate, rawDate.substring(0, 10));

  // Actualizar DOM
  const rdocTitle = document.getElementById('rdocDocTitle');
  if (rdocTitle) rdocTitle.textContent = title;
  const rdocComm = document.getElementById('rdocCommercialName');
  if (rdocComm) {
    rdocComm.textContent = commercial;
    rdocComm.style.color = accentColor;
  }
  const rdocCorrLbl = document.getElementById('rdocCorrelativeLbl');
  if (rdocCorrLbl) {
    rdocCorrLbl.textContent = isInvoice ? 'FACTURA N.°' : 'COMPROBANTE N.°';
  }
  const rdocCorr = document.getElementById('rdocCorrelativeNum');
  if (rdocCorr) {
    rdocCorr.textContent = correlative;
    rdocCorr.style.color = accentColor;
  }
  const rdocDateTime = document.getElementById('rdocDateTime');
  if (rdocDateTime) rdocDateTime.textContent = dateFormatted;

  const rdocDiv = document.getElementById('rdocDivider');
  if (rdocDiv) rdocDiv.style.backgroundColor = accentColor;

  const rdocLogoWrap = document.getElementById('rdocLogoWrap');
  if (rdocLogoWrap) rdocLogoWrap.style.display = showLogo ? 'flex' : 'none';

  const rdocIssuer = document.getElementById('rdocIssuerName');
  if (rdocIssuer) rdocIssuer.textContent = issuer;
  const rdocDocRow = document.getElementById('rdocIssuerDocRow');
  if (rdocDocRow) rdocDocRow.style.display = showIssuerDoc ? 'block' : 'none';
  const rdocDoc = document.getElementById('rdocIssuerDoc');
  if (rdocDoc) rdocDoc.textContent = issuerDoc;
  const rdocPhoneRow = document.getElementById('rdocIssuerPhoneRow');
  if (rdocPhoneRow) rdocPhoneRow.style.display = showIssuerPhone ? 'block' : 'none';
  const rdocPhone = document.getElementById('rdocIssuerPhone');
  if (rdocPhone) rdocPhone.textContent = issuerPhone;
  const rdocCity = document.getElementById('rdocIssuerCity');
  if (rdocCity) rdocCity.textContent = issuerCity;

  // Cliente o Empresa
  const rdocClientTag = document.getElementById('rdocClientTag');
  if (rdocClientTag) {
    rdocClientTag.textContent = isInvoice ? 'DATOS DE LA EMPRESA / CLIENTE' : 'DATOS DEL CLIENTE';
  }
  const rdocClientBiz = document.getElementById('rdocClientBiz');
  if (rdocClientBiz) {
    rdocClientBiz.textContent = (isInvoice && invoiceBiz) ? invoiceBiz : (client.business_name || 'Cliente Registrado');
  }
  const rdocClientOwnerRow = document.getElementById('rdocClientOwnerRow');
  if (rdocClientOwnerRow) {
    rdocClientOwnerRow.style.display = (!isInvoice && client.owner_name) ? 'block' : 'none';
  }
  const rdocClientOwner = document.getElementById('rdocClientOwner');
  if (rdocClientOwner) rdocClientOwner.textContent = client.owner_name || '-';

  const rdocClientDocRow = document.getElementById('rdocClientDocRow');
  if (rdocClientDocRow) rdocClientDocRow.style.display = showClientDoc ? 'block' : 'none';
  const rdocClientDocLbl = document.getElementById('rdocClientDocLbl');
  if (rdocClientDocLbl) rdocClientDocLbl.textContent = isInvoice ? 'RUC:' : 'RUC / DNI:';
  const rdocClientDoc = document.getElementById('rdocClientDoc');
  if (rdocClientDoc) {
    rdocClientDoc.textContent = (isInvoice && invoiceRuc) ? invoiceRuc : (client.document_number || '-');
  }

  const rdocClientAddressRow = document.getElementById('rdocClientAddressRow');
  if (rdocClientAddressRow) {
    rdocClientAddressRow.style.display = (isInvoice && invoiceAddress) ? 'block' : 'none';
  }
  const rdocClientAddress = document.getElementById('rdocClientAddress');
  if (rdocClientAddress) rdocClientAddress.textContent = invoiceAddress;

  const rdocClientDevIdRow = document.getElementById('rdocClientDevIdRow');
  if (rdocClientDevIdRow) {
    rdocClientDevIdRow.style.display = (showHardwareId && !isInvoice) ? 'block' : 'none';
  }
  const rdocClientDevId = document.getElementById('rdocClientDevId');
  if (rdocClientDevId) rdocClientDevId.textContent = client.current_device_id || '-';

  const rdocConcept = document.getElementById('rdocPaymentConcept');
  if (rdocConcept) rdocConcept.textContent = formatPlanHumanLabel(payment.plan) || payment.plan || 'Pago Registrado';
  const rdocNote = document.getElementById('rdocPaymentCustomNote');
  if (rdocNote) {
    rdocNote.textContent = customNote;
    rdocNote.style.display = (showObservation && customNote) ? 'block' : 'none';
  }
  const rdocMethod = document.getElementById('rdocPaymentMethod');
  if (rdocMethod) rdocMethod.textContent = payment.method || 'Yape';
  const rdocRef = document.getElementById('rdocPaymentRef');
  if (rdocRef) rdocRef.textContent = showOperationNumber ? (payment.reference || '-') : '-';
  const rdocPayDate = document.getElementById('rdocPaymentDate');
  if (rdocPayDate) rdocPayDate.textContent = payment.date ? payment.date.substring(0, 10) : '-';

  const totalVal = parseFloat(payment.amount) || 0;
  const rdocRowAmt = document.getElementById('rdocPaymentRowAmount');
  if (rdocRowAmt) rdocRowAmt.textContent = `S/ ${totalVal.toFixed(2)}`;

  // Cálculo de IGV 18% opcional
  let subtotalVal = totalVal;
  let igvVal = 0;
  if (showIgv) {
    subtotalVal = +(totalVal / 1.18).toFixed(2);
    igvVal = +(totalVal - subtotalVal).toFixed(2);
  }

  const rdocTotalBox = document.querySelector('.rdoc-total-box');
  if (rdocTotalBox) {
    rdocTotalBox.style.borderColor = accentColor;
    if (showIgv) {
      rdocTotalBox.classList.add('with-igv');
      rdocTotalBox.innerHTML = `
        <div class="rdoc-igv-row">
          <span style="color:#475569;">Subtotal (Op. Gravada):</span>
          <strong style="color:#1e293b;">S/ ${subtotalVal.toFixed(2)}</strong>
        </div>
        <div class="rdoc-igv-row">
          <span style="color:#475569;">I.G.V. (18%):</span>
          <strong style="color:#1e293b;">S/ ${igvVal.toFixed(2)}</strong>
        </div>
        <div class="rdoc-igv-total-row">
          <span style="font-weight:700; color:#0f172a;">TOTAL A PAGAR:</span>
          <span id="rdocPaymentTotal" style="color:${accentColor}; font-weight:900; font-size:1.35rem;">S/ ${totalVal.toFixed(2)}</span>
        </div>
      `;
    } else {
      rdocTotalBox.classList.remove('with-igv');
      rdocTotalBox.innerHTML = `
        <span style="font-size:0.8rem; font-weight:700; color:#334155;">${isInvoice ? 'TOTAL FACTURADO:' : 'TOTAL RECIBIDO:'}</span>
        <span id="rdocPaymentTotal" style="color:${accentColor}; font-weight:900; font-size:1.5rem;">S/ ${totalVal.toFixed(2)}</span>
      `;
    }
  }

  const rdocFoot = document.getElementById('rdocFooterNotes');
  if (rdocFoot) {
    rdocFoot.textContent = footerNotes;
    rdocFoot.style.display = showFooterNotes ? 'block' : 'none';
  }
  const rdocSignBlock = document.getElementById('rdocSignatureBlock');
  if (rdocSignBlock) rdocSignBlock.style.display = showSignature ? 'flex' : 'none';
  const rdocSign = document.getElementById('rdocSignatureText');
  if (rdocSign) rdocSign.textContent = signatureText;

  drawReceiptOnCanvas();
}
