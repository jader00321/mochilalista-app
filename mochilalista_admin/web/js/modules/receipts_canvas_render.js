function drawReceiptOnCanvas() {
  const canvas = document.getElementById('receiptExportCanvas');
  if (!canvas || !currentReceiptData) return;

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
  const footerNotes = document.getElementById('rcInputFooterNotes')?.value.trim() || 'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.';
  const signatureText = document.getElementById('rcInputSignature')?.value.trim() || 'Administración Comercial — MochilaLista';

  // Datos fiscales de factura
  const invoiceRuc = document.getElementById('rcInputInvoiceRuc')?.value.trim() || '';
  const invoiceBiz = document.getElementById('rcInputInvoiceBizName')?.value.trim() || '';
  const invoiceAddress = document.getElementById('rcInputInvoiceAddress')?.value.trim() || '';
  const showIgv = document.getElementById('rcCheckShowIgv')?.checked === true;

  const correlative = currentReceiptData.receipt_number || (isInvoice ? 'FAC-0001' : 'BOL-0001');
  const rawDate = currentReceiptData.receipt_issued_at || payment.date || new Date().toISOString();
  const dateFormatted = formatLimaReceiptStamp(rawDate, rawDate.substring(0, 10));

  const totalVal = parseFloat(payment.amount) || 0;
  let subtotalVal = totalVal;
  let igvVal = 0;
  if (showIgv) {
    subtotalVal = +(totalVal / 1.18).toFixed(2);
    igvVal = +(totalVal - subtotalVal).toFixed(2);
  }

  const width = 1200;
  const height = 940;
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  // Fondo blanco y marco exterior sutil
  ctx.save();
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, width, height);
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 2;
  ctx.strokeRect(10, 10, width - 20, height - 20);
  ctx.restore();

  // Cabecera superior
  let startX = 60;
  if (showLogo) {
    const img = document.getElementById('rdocLogoImg');
    if (img && img.complete && img.naturalWidth > 0) {
      try {
        ctx.drawImage(img, 60, 48, 72, 72);
      } catch (_) {
        drawFallbackLogo(ctx, 60, 48, 72, 72, accentColor);
      }
    } else {
      drawFallbackLogo(ctx, 60, 48, 72, 72, accentColor);
    }
    startX = 150;
  }

  ctx.save();
  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 30px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText(title, startX, 80);

  ctx.fillStyle = accentColor;
  ctx.font = 'bold 22px sans-serif';
  ctx.fillText(commercial, startX, 112);
  ctx.restore();

  // Caja de correlativo (esquina superior derecha)
  ctx.save();
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 2;
  roundRect(ctx, width - 360, 42, 300, 88, 10, true, true);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 13px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText(isInvoice ? 'FACTURA DE VENTA N.°' : 'COMPROBANTE N.°', width - 210, 68);

  ctx.fillStyle = accentColor;
  ctx.font = 'bold 28px monospace';
  ctx.fillText(correlative, width - 210, 98);

  ctx.fillStyle = '#64748b';
  ctx.font = '500 13px sans-serif';
  ctx.fillText(dateFormatted, width - 210, 120);
  ctx.restore();

  // Línea divisoria de acento
  ctx.save();
  ctx.fillStyle = accentColor;
  ctx.fillRect(60, 145, width - 120, 4);
  ctx.restore();

  // Cajas de Emisor y Cliente
  const colW = (width - 150) / 2;

  // 1. Tarjeta Emisor
  ctx.save();
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 60, 165, colW, 160, 8, true, true);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 14px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText('EMISOR DEL COMPROBANTE', 80, 192);

  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 20px sans-serif';
  ctx.fillText(issuer, 80, 222);

  ctx.fillStyle = '#475569';
  ctx.font = '16px sans-serif';
  let emitY = 252;
  if (showIssuerDoc) {
    ctx.fillText(`Documento: ${issuerDoc}`, 80, emitY);
    emitY += 28;
  }
  if (showIssuerPhone) {
    ctx.fillText(`WhatsApp: ${issuerPhone}`, 80, emitY);
    emitY += 28;
  }
  ctx.fillText(`Ciudad: ${issuerCity}`, 80, emitY);
  ctx.restore();

  // 2. Tarjeta Cliente / Empresa (con aislamiento estricto y padding interno exacto)
  const clientCardX = 60 + colW + 30;
  const clientTextX = clientCardX + 20; // 110 + colW (exact 20px padding)

  ctx.save();
  ctx.fillStyle = '#f8fafc';
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 1.5;
  roundRect(ctx, clientCardX, 165, colW, 160, 8, true, true);

  ctx.fillStyle = '#64748b';
  ctx.font = 'bold 14px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText(isInvoice ? 'DATOS DE LA EMPRESA / CLIENTE' : 'DATOS DEL CLIENTE', clientTextX, 192);

  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 20px sans-serif';
  const clientBizDisplay = (isInvoice && invoiceBiz) ? invoiceBiz : (client.business_name || 'Cliente Registrado');
  ctx.fillText(clientBizDisplay, clientTextX, 222);

  ctx.fillStyle = '#475569';
  ctx.font = '16px sans-serif';
  let cliY = 252;
  if (isInvoice) {
    if (showClientDoc) {
      ctx.fillText(`RUC: ${invoiceRuc || client.document_number || '-'}`, clientTextX, cliY);
      cliY += 28;
    }
    if (invoiceAddress) {
      ctx.fillText(`Dirección: ${invoiceAddress}`, clientTextX, cliY);
      cliY += 28;
    }
  } else {
    ctx.fillText(`Titular: ${client.owner_name || '-'}`, clientTextX, cliY);
    cliY += 28;
    if (showClientDoc) {
      ctx.fillText(`RUC / DNI: ${client.document_number || '-'}`, clientTextX, cliY);
      cliY += 28;
    }
    if (showHardwareId) {
      ctx.fillText(`Hardware ID: ${client.current_device_id || '-'}`, clientTextX, cliY);
    }
  }
  ctx.restore();

  // Tabla de Cobro
  const tableY = 350;
  const tableW = width - 120;
  ctx.save();
  ctx.fillStyle = '#f1f5f9';
  ctx.fillRect(60, tableY, tableW, 44);
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 1;
  ctx.strokeRect(60, tableY, tableW, 44);

  ctx.fillStyle = '#334155';
  ctx.font = 'bold 16px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText('Descripción / Concepto', 80, tableY + 28);
  ctx.fillText('Medio', 550, tableY + 28);
  ctx.fillText('N.° Operación', 700, tableY + 28);
  ctx.fillText('Fecha', 880, tableY + 28);
  ctx.textAlign = 'right';
  ctx.fillText('Total (S/)', 60 + tableW - 20, tableY + 28);
  ctx.restore();

  // Fila tabla
  const rowY = tableY + 44;
  const rowH = 75;
  ctx.save();
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(60, rowY, tableW, rowH);
  ctx.strokeStyle = '#e2e8f0';
  ctx.strokeRect(60, rowY, tableW, rowH);

  ctx.textAlign = 'left';
  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 18px sans-serif';
  ctx.fillText(formatPlanHumanLabel(payment.plan) || payment.plan || 'Pago Registrado', 80, rowY + 30);

  if (showObservation && customNote) {
    ctx.fillStyle = '#64748b';
    ctx.font = '14px sans-serif';
    ctx.fillText(customNote, 80, rowY + 54);
  }

  ctx.fillStyle = '#334155';
  ctx.font = '16px sans-serif';
  ctx.fillText(payment.method || 'Yape', 550, rowY + 35);
  ctx.fillText(showOperationNumber ? (payment.reference || '-') : '-', 700, rowY + 35);
  ctx.fillText(payment.date ? payment.date.substring(0, 10) : '-', 880, rowY + 35);

  ctx.textAlign = 'right';
  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 20px sans-serif';
  ctx.fillText(`S/ ${totalVal.toFixed(2)}`, 60 + tableW - 20, rowY + 38);
  ctx.restore();

  // Caja de Totales (con o sin desglose de IGV - Cero colisión con ancho >= 430px)
  if (showIgv) {
    ctx.save();
    const boxW = Math.max(430, width - 120 > 430 ? 430 : width - 120);
    const boxH = 115;
    const boxX = width - 60 - boxW;
    const boxY = 470;
    ctx.fillStyle = '#f8fafc';
    ctx.strokeStyle = accentColor;
    ctx.lineWidth = 2.5;
    roundRect(ctx, boxX, boxY, boxW, boxH, 10, true, true);

    ctx.font = '500 15px sans-serif';
    ctx.fillStyle = '#475569';
    ctx.textAlign = 'left';
    ctx.fillText('SUBTOTAL (OP. GRAVADA):', boxX + 24, boxY + 30);
    ctx.font = 'bold 15px sans-serif';
    ctx.fillStyle = '#1e293b';
    ctx.textAlign = 'right';
    ctx.fillText(`S/ ${subtotalVal.toFixed(2)}`, boxX + boxW - 24, boxY + 30);

    ctx.font = '500 15px sans-serif';
    ctx.fillStyle = '#475569';
    ctx.textAlign = 'left';
    ctx.fillText('I.G.V. (18%):', boxX + 24, boxY + 58);
    ctx.font = 'bold 15px sans-serif';
    ctx.fillStyle = '#1e293b';
    ctx.textAlign = 'right';
    ctx.fillText(`S/ ${igvVal.toFixed(2)}`, boxX + boxW - 24, boxY + 58);

    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(boxX + 15, boxY + 70);
    ctx.lineTo(boxX + boxW - 15, boxY + 70);
    ctx.stroke();

    ctx.font = 'bold 17px sans-serif';
    ctx.fillStyle = '#0f172a';
    ctx.textAlign = 'left';
    ctx.fillText('TOTAL A PAGAR:', boxX + 24, boxY + 95);
    ctx.font = '900 24px sans-serif';
    ctx.fillStyle = accentColor;
    ctx.textAlign = 'right';
    ctx.fillText(`S/ ${totalVal.toFixed(2)}`, boxX + boxW - 24, boxY + 96);
    ctx.restore();
  } else {
    ctx.save();
    const labelText = isInvoice ? 'TOTAL FACTURADO:' : 'TOTAL RECIBIDO:';
    const amountText = `S/ ${totalVal.toFixed(2)}`;

    ctx.font = 'bold 18px sans-serif';
    const labelW = ctx.measureText(labelText).width;
    ctx.font = '900 30px sans-serif';
    const amountW = ctx.measureText(amountText).width;

    const boxW = Math.max(430, labelW + amountW + 70);
    const boxH = 75;
    const boxX = width - 60 - boxW;
    const totalBoxY = 490;

    ctx.fillStyle = '#f8fafc';
    ctx.strokeStyle = accentColor;
    ctx.lineWidth = 3;
    roundRect(ctx, boxX, totalBoxY, boxW, boxH, 10, true, true);

    ctx.fillStyle = '#1e293b';
    ctx.font = 'bold 18px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText(labelText, boxX + 24, totalBoxY + 45);

    ctx.fillStyle = accentColor;
    ctx.font = '900 30px sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(amountText, boxX + boxW - 24, totalBoxY + 47);
    ctx.restore();
  }

  // Línea divisoria pie
  ctx.save();
  ctx.strokeStyle = '#cbd5e1';
  ctx.lineWidth = 2;
  ctx.setLineDash([6, 6]);
  ctx.beginPath();
  ctx.moveTo(60, 680);
  ctx.lineTo(width - 60, 680);
  ctx.stroke();
  ctx.restore();

  // Notas al pie
  if (showFooterNotes) {
    ctx.save();
    ctx.textAlign = 'left';
    ctx.fillStyle = '#64748b';
    ctx.font = '15px sans-serif';
    wrapText(ctx, footerNotes, 60, 725, width - 460, 22);
    ctx.restore();
  }

  // Firma
  if (showSignature) {
    ctx.save();
    const signX = width - 250;
    ctx.strokeStyle = '#64748b';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(signX - 120, 770);
    ctx.lineTo(signX + 120, 770);
    ctx.stroke();

    ctx.textAlign = 'center';
    ctx.fillStyle = '#334155';
    ctx.font = 'bold 15px sans-serif';
    ctx.fillText(signatureText, signX, 795);
    ctx.restore();
  }
}
