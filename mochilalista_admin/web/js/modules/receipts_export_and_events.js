function downloadReceiptPdf() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas) return;
  const isInvoice = currentReceiptData?.voucher_type === 'FAC';
  const correlative = currentReceiptData?.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const biz = sanitizeDownloadFileName(currentReceiptData?.client?.business_name || 'Cliente');
  const prefix = isInvoice ? 'Factura' : 'Boleta';
  const cleanCorrelative = sanitizeDownloadFileName(correlative);
  const fileName = `${prefix}_${cleanCorrelative}_${biz}.pdf`;

  try {
    generateOfflinePdfFromCanvas(canvas, fileName);
    showToast(`${prefix} ${correlative} descargada en PDF con éxito.`, 'success');
  } catch (e) {
    console.error('Error generando PDF offline:', e);
    showToast('Error al generar PDF: ' + e.message, 'error');
  }
}

function downloadReceiptPng() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas) return;
  const isInvoice = currentReceiptData?.voucher_type === 'FAC';
  const correlative = currentReceiptData?.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const biz = sanitizeDownloadFileName(currentReceiptData?.client?.business_name || 'Cliente');
  const prefix = isInvoice ? 'Factura' : 'Boleta';
  const cleanCorrelative = sanitizeDownloadFileName(correlative);
  const link = document.createElement('a');
  link.download = `${prefix}_${cleanCorrelative}_${biz}.png`;
  link.href = canvas.toDataURL('image/png');
  link.click();
  showToast(`${prefix} ${correlative} descargada en PNG con éxito.`, 'success');
}

async function copyReceiptToClipboard() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas) return;
  const isInvoice = currentReceiptData?.voucher_type === 'FAC';
  const correlative = currentReceiptData?.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const docName = isInvoice ? 'Factura' : 'Boleta';
  try {
    canvas.toBlob(async (blob) => {
      if (!blob) {
        showToast('No se pudo generar la imagen para el portapapeles.', 'error');
        return;
      }
      await copyPngBlobToClipboard(blob, {
        successMsg: `${docName} ${correlative} copiada al portapapeles. ¡Lista para pegar con Ctrl+V en WhatsApp!`,
        onFallbackDownload: () => downloadReceiptPng(),
        fallbackMsg: `Portapapeles no disponible en este navegador. Se descargó el archivo PNG ${correlative}.`,
      });
    }, 'image/png');
  } catch (e) {
    showToast('Error al copiar al portapapeles: ' + e.message, 'error');
  }
}

function printReceiptPdf() {
  window.print();
}

function sendReceiptViaWhatsapp() {
  if (!currentReceiptData) return;
  const client = currentReceiptData.client;
  const payment = currentReceiptData.payment;
  const isInvoice = currentReceiptData.voucher_type === 'FAC';
  const correlative = currentReceiptData.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const amount = (parseFloat(payment.amount) || 0).toFixed(2);
  const titular = client.owner_name || client.business_name || 'Estimado cliente';
  const concept = payment.plan || 'Servicio MochilaLista';

  const docTypeName = isInvoice ? 'Factura de Pago Oficial' : 'Boleta de Pago Oficial';
  const docExtra = isInvoice ? 'fiscal para tu control tributario y administrativo' : 'para tu control contable';

  const msg = `¡Hola, ${titular}! Te saluda el equipo de MochilaLista.\n\n` +
    `Te hacemos entrega de tu *${docTypeName} N.° ${correlative}* por el monto de *S/ ${amount}* correspondiente a *${concept}*.\n\n` +
    `📌 Hemos adjuntado el comprobante digital ${docExtra}.\n\n` +
    `¡Muchas gracias por tu confianza y preferencia!`;

  closeReceiptModal();
  if (typeof openWhatsAppComposer === 'function' && client.id) {
    openWhatsAppComposer(client.id, null, {
      customMessage: msg,
      templateKey: 'custom'
    });
  } else if (typeof openWaComposerForClient === 'function' && client.id) {
    openWaComposerForClient(client.id, {
      customMessage: msg,
      templateKey: 'custom'
    });
  } else {
    const url = buildWhatsAppSendUrl(client.phone, msg);
    window.open(url, '_blank');
  }
}

window.openWaComposerForClient = function(clientId, options = {}) {
  return openWhatsAppComposer(clientId, options.templateKey || null, options);
};

async function saveReceiptDefaultDesign() {
  const isInvoice = currentReceiptData?.voucher_type === 'FAC';
  const title = document.getElementById('rcInputTitle')?.value.trim() || 'BOLETA DE PAGO ADMINISTRATIVA';
  const commercial = document.getElementById('rcInputCommercialName')?.value.trim() || 'MochilaLista';
  const issuer = document.getElementById('rcInputIssuerName')?.value.trim() || 'Julio Angello Vasquez Navarro';
  const issuerDoc = document.getElementById('rcInputIssuerDoc')?.value.trim() || 'D.N.I. / R.U.C. Registrado';
  const issuerPhone = document.getElementById('rcInputIssuerPhone')?.value.trim() || '+51 922 836 879';
  const issuerCity = document.getElementById('rcInputIssuerCity')?.value.trim() || 'Piura, Perú';
  const showLogo = document.getElementById('rcCheckShowLogo')?.checked !== false;
  const showIssuerDoc = document.getElementById('rcCheckShowIssuerDoc')?.checked !== false;
  const showIssuerPhone = document.getElementById('rcCheckShowIssuerPhone')?.checked !== false;
  const showClientDoc = document.getElementById('rcCheckShowClientDoc')?.checked !== false;
  const showHardwareId = document.getElementById('rcCheckShowHardwareId')?.checked !== false;
  const showOperationNumber = document.getElementById('rcCheckShowOperationNumber')?.checked !== false;
  const showObservation = document.getElementById('rcCheckShowObservation')?.checked !== false;
  const showSignature = document.getElementById('rcCheckShowSignature')?.checked !== false;
  const showFooterNotes = document.getElementById('rcCheckShowFooterNotes')?.checked !== false;
  const showIgv = document.getElementById('rcCheckShowIgv')?.checked === true;
  const accentColor = document.getElementById('rcInputAccentColor')?.value || '#2563eb';
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || '';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || '';

  const newRc = {
    title: isInvoice ? (ownerConfig?.receipt_config?.title || 'BOLETA DE PAGO ADMINISTRATIVA') : title,
    invoice_title: isInvoice ? title : (ownerConfig?.receipt_config?.invoice_title || 'FACTURA DE VENTA / PAGO'),
    commercial_name: commercial,
    issuer_name: issuer,
    issuer_doc: issuerDoc,
    issuer_phone: issuerPhone,
    issuer_city: issuerCity,
    show_logo: showLogo,
    show_issuer_doc: showIssuerDoc,
    show_issuer_phone: showIssuerPhone,
    show_client_doc: showClientDoc,
    show_hardware_id: showHardwareId,
    show_operation_number: showOperationNumber,
    show_observation: showObservation,
    show_signature: showSignature,
    show_footer_notes: showFooterNotes,
    show_igv_breakdown: showIgv,
    accent_color: accentColor,
    footer_notes: footerNotes,
    signature_text: signatureText,
  };

  try {
    const cfgRes = await fetch('/api/config');
    const currentCfg = cfgRes.ok ? await cfgRes.json() : {};
    currentCfg.receipt_config = Object.assign({}, currentCfg.receipt_config || {}, newRc);

    const saveRes = await fetch('/api/config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(currentCfg),
    });

    if (!saveRes.ok) throw new Error('Error al guardar configuración');
    const saved = await saveRes.json();
    ownerConfig = saved;
    if (currentReceiptData) {
      currentReceiptData.receipt_config = saved.receipt_config;
    }
    showToast('Diseño y preferencias de comprobante guardados con éxito.', 'success');
  } catch (e) {
    showToast('Error al guardar diseño: ' + e.message, 'error');
  }
}

function resetReceiptDefaultDesign() {
  const defaultRc = {
    title: 'BOLETA DE PAGO ADMINISTRATIVA',
    invoice_title: 'FACTURA DE VENTA / PAGO',
    commercial_name: 'MochilaLista',
    issuer_name: 'Julio Angello Vasquez Navarro',
    issuer_doc: 'D.N.I. / R.U.C. Registrado',
    issuer_phone: '+51 922 836 879',
    issuer_city: 'Piura, Perú',
    show_logo: true,
    show_issuer_doc: true,
    show_issuer_phone: true,
    show_client_doc: true,
    show_hardware_id: true,
    show_operation_number: true,
    show_observation: true,
    show_signature: true,
    show_footer_notes: true,
    show_igv_breakdown: false,
    accent_color: '#2563eb',
    footer_notes: 'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.',
    signature_text: 'Administración Comercial — MochilaLista',
  };
  if (currentReceiptData) {
    currentReceiptData.receipt_config = defaultRc;
    populateReceiptUI(currentReceiptData);
  }
  showToast('Plantilla restablecida a valores de fábrica.', 'info');
}

function initReceiptModalEvents() {
  const textInputs = [
    'rcInputTitle', 'rcInputCommercialName', 'rcInputIssuerName',
    'rcInputIssuerDoc', 'rcInputIssuerPhone', 'rcInputIssuerCity',
    'rcInputAccentColor', 'rcInputCustomNote', 'rcInputFooterNotes',
    'rcInputSignature', 'rcInputInvoiceRuc', 'rcInputInvoiceBizName',
    'rcInputInvoiceAddress'
  ];
  textInputs.forEach(id => {
    document.getElementById(id)?.addEventListener('input', () => {
      renderReceiptPreviewAndCanvas();
    });
  });

  // Selector de Tipo de Comprobante (BOL vs FAC)
  document.getElementById('rcSelectVoucherType')?.addEventListener('change', (e) => {
    switchReceiptVoucherType(e.target.value);
  });

  // Checkbox de IGV 18%
  document.getElementById('rcCheckShowIgv')?.addEventListener('change', () => {
    renderReceiptPreviewAndCanvas();
  });

  // 9 Interruptores de visibilidad
  const toggleCheckIds = [
    'rcCheckShowLogo', 'rcCheckShowIssuerDoc', 'rcCheckShowIssuerPhone',
    'rcCheckShowClientDoc', 'rcCheckShowHardwareId', 'rcCheckShowOperationNumber',
    'rcCheckShowObservation', 'rcCheckShowSignature', 'rcCheckShowFooterNotes'
  ];
  toggleCheckIds.forEach(id => {
    document.getElementById(id)?.addEventListener('change', () => {
      renderReceiptPreviewAndCanvas();
    });
  });

  document.querySelectorAll('.rc-swatch').forEach(swatch => {
    swatch.addEventListener('click', () => {
      const col = swatch.getAttribute('data-color');
      const inp = document.getElementById('rcInputAccentColor');
      if (inp && col) {
        inp.value = col;
        renderReceiptPreviewAndCanvas();
      }
    });
  });

  document.getElementById('btnRcSaveDefault')?.addEventListener('click', saveReceiptDefaultDesign);
  document.getElementById('btnRcResetDefault')?.addEventListener('click', resetReceiptDefaultDesign);
  document.getElementById('btnRcDownloadPng')?.addEventListener('click', downloadReceiptPng);
  document.getElementById('btnRcDownloadPdf')?.addEventListener('click', downloadReceiptPdf);
  document.getElementById('btnRcCopyClipboard')?.addEventListener('click', copyReceiptToClipboard);
  document.getElementById('btnRcPrintPdf')?.addEventListener('click', printReceiptPdf);
  document.getElementById('btnRcSendWhatsapp')?.addEventListener('click', sendReceiptViaWhatsapp);
}
