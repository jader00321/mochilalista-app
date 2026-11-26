// =================== GENERADOR DE CREDENCIAL EN CANVAS (PNG @2x / 900x520) ===================
function renderCredentialCanvas(licenseData, client, targetCanvasId = 'credentialCanvas', qrContainerId = 'qrContainer') {
  if (!licenseData) {
    const licCodeVal = document.getElementById('licCode')?.value?.trim() || '';
    const licClientId = document.getElementById('licClientSelect')?.value || '';
    const resolvedClient = client || (Array.isArray(globalClients) ? globalClients.find(c => c.id === licClientId) : null) || null;
    const resolvedPlan = document.getElementById('licPlanSelect')?.value || resolvedClient?.license_type || 'MENSUAL';
    if (!licCodeVal && !currentSelectedGeneratorCode) return;
    licenseData = (typeof currentSelectedGeneratorCode === 'object' && currentSelectedGeneratorCode)
      ? currentSelectedGeneratorCode
      : {
          token: licCodeVal || currentSelectedGeneratorCode || '',
          plan: resolvedPlan,
          device_id: resolvedClient?.current_device_id || 'ML-0000',
          client: resolvedClient,
        };
    client = resolvedClient;
  }
  const canvas = document.getElementById(targetCanvasId);
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  const width = canvas.width;
  const height = canvas.height;

  // 1. Fondo degradado ejecutivo
  const bgGrad = ctx.createLinearGradient(0, 0, width, height);
  bgGrad.addColorStop(0, '#090d16');
  bgGrad.addColorStop(0.5, '#0f172a');
  bgGrad.addColorStop(1, '#1e293b');
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, width, height);

  // 2. Patrón de líneas guilloche de seguridad
  ctx.strokeStyle = 'rgba(16, 185, 129, 0.06)';
  ctx.lineWidth = 1;
  for (let i = -width; i < width * 2; i += 24) {
    ctx.beginPath();
    ctx.moveTo(i, 0);
    ctx.lineTo(i + height, height);
    ctx.stroke();
  }

  // 3. Borde con acentos y cabecera
  ctx.strokeStyle = '#10b981';
  ctx.lineWidth = 4;
  ctx.strokeRect(8, 8, width - 16, height - 16);

  ctx.fillStyle = '#10b981';
  ctx.fillRect(8, 8, width - 16, 10);

  // 4. Encabezado Oficial
  const brandHeadline = (ownerConfig?.legal_identity?.commercial_name || 'MochilaLista').toUpperCase();
  ctx.fillStyle = '#10b981';
  ctx.font = 'bold 26px -apple-system, sans-serif';
  ctx.fillText(`${brandHeadline} POS`, 36, 54);

  ctx.fillStyle = '#94a3b8';
  ctx.font = '600 13px -apple-system, sans-serif';
  ctx.fillText('LICENCIA OFICIAL AUTORIZADA • SISTEMA DE GESTIÓN COMERCIAL', 36, 76);

  // Sello legal superior derecho
  ctx.fillStyle = '#1e3a8a';
  ctx.fillRect(width - 290, 34, 254, 28);
  ctx.fillStyle = '#60a5fa';
  ctx.font = 'bold 11px monospace';
  ctx.fillText('VERIFICADA ED25519 • D.L. 822', width - 275, 52);

  // Línea divisoria
  ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)';
  ctx.beginPath();
  ctx.moveTo(36, 96);
  ctx.lineTo(width - 36, 96);
  ctx.stroke();

  // 5. Datos Comerciales del Cliente (Columna Izquierda)
  const bizName = client ? (client.business_name || 'Negocio Comercial') : 'Negocio Comercial';
  const ownerName = client ? (client.owner_name || 'Propietario') : 'Propietario';
  const docId = client && client.document_id ? `RUC/DNI: ${client.document_id}` : '';
  const deviceId = licenseData.device_id || (client ? client.current_device_id : 'ML-0000');
  const plan = licenseData.plan || 'MENSUAL';

  let vigencia = '30 días de vigencia';
  if (plan === 'PERPETUO_LIBERADO') vigencia = 'Vitalicia (De por Vida)';
  else if (plan === 'RECARGA_IA_150') vigencia = 'Sin vencimiento (Acumulativo)';
  else if (plan === 'BONO_IA_PERSONALIZADO') vigencia = 'Sin alterar suscripción (0 días)';
  else if (licenseData.client && licenseData.client.license_expires) {
    vigencia = `Vence: ${licenseData.client.license_expires.substring(0, 10)}`;
  } else if (licenseData.expires_result) {
    vigencia = `Vence: ${licenseData.expires_result.substring(0, 10)}`;
  }

  // Nombre de Negocio
  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 24px -apple-system, sans-serif';
  ctx.fillText(bizName.length > 28 ? bizName.substring(0, 26) + '...' : bizName, 36, 136);

  // Propietario
  ctx.fillStyle = '#cbd5e1';
  ctx.font = '14px -apple-system, sans-serif';
  ctx.fillText(`Titular: ${ownerName} ${docId ? '• ' + docId : ''}`, 36, 162);

  // Bloque Hardware ID (ANDROID_ID)
  ctx.fillStyle = '#1e293b';
  ctx.fillRect(36, 186, 260, 48);
  ctx.strokeStyle = '#334155';
  ctx.strokeRect(36, 186, 260, 48);

  ctx.fillStyle = '#94a3b8';
  ctx.font = '10px -apple-system, sans-serif';
  ctx.fillText('HARDWARE ID (ANDROID_ID)', 48, 204);

  ctx.fillStyle = '#38bdf8';
  ctx.font = 'bold 18px monospace';
  ctx.fillText(deviceId, 48, 226);

  // Plan y Vigencia
  ctx.fillStyle = '#94a3b8';
  ctx.font = '11px -apple-system, sans-serif';
  ctx.fillText('PLAN Y ESTADO:', 36, 264);

  ctx.fillStyle = plan === 'PERPETUO_LIBERADO' ? '#c084fc' : ((plan === 'RECARGA_IA_150' || plan === 'BONO_IA_PERSONALIZADO') ? '#34d399' : '#60a5fa');
  ctx.font = 'bold 18px -apple-system, sans-serif';
  ctx.fillText(plan.replace(/_/g, ' '), 36, 288);

  // Icono vectorial de calendario en Canvas2D (sin emoji crudo)
  ctx.save();
  ctx.strokeStyle = '#60a5fa';
  ctx.lineWidth = 1.6;
  ctx.strokeRect(37, 300, 12, 11);
  ctx.beginPath();
  ctx.moveTo(40, 298);
  ctx.lineTo(40, 301);
  ctx.moveTo(46, 298);
  ctx.lineTo(46, 301);
  ctx.moveTo(37, 304);
  ctx.lineTo(49, 304);
  ctx.stroke();
  ctx.restore();

  ctx.fillStyle = '#f1f5f9';
  ctx.font = '600 14px -apple-system, sans-serif';
  ctx.fillText(vigencia, 56, 312);

  // Cuota IA Acumulativa (Regla Plan 08/09)
  const baseScansMap = {
    TRIAL: 50,
    MENSUAL: 50,
    TRIMESTRAL: 180,
    SEMESTRAL: 450,
    ANUAL: 1200,
    PERPETUO_LIBERADO: 200,
    PASE_ACTUALIZACION_ANUAL: 100,
    RECARGA_IA_150: 150,
    BONO_IA_PERSONALIZADO: 0,
    EXTENSION_CORTESIA: 0,
  };
  const cfgPlan = ownerConfig?.catalog?.[plan];
  const baseScans = cfgPlan?.ai_credits !== undefined ? cfgPlan.ai_credits : (baseScansMap[plan] !== undefined ? baseScansMap[plan] : 50);
  const extraCredits = licenseData.ai_extra_credits || licenseData.ai_credits || (client ? client.ai_extra_credits : 0) || 0;
  const totalScans = plan === 'RECARGA_IA_150' ? 150 : (baseScans + extraCredits);
  let aiText = `+${totalScans} escaneos IA acumulativos vitalicios (o BYOK)`;
  if (plan === 'BONO_IA_PERSONALIZADO') {
    aiText = `+${extraCredits} escaneos IA sin caducidad (Bono)`;
  } else if (plan === 'RECARGA_IA_150') {
    aiText = '+150 escaneos IA sin vencimiento (Bolsa Acumulativa)';
  }
  // Icono vectorial de rayo/IA en Canvas2D (sin emoji crudo)
  ctx.save();
  ctx.strokeStyle = '#fbbf24';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.moveTo(45, 326);
  ctx.lineTo(39, 334);
  ctx.lineTo(44, 334);
  ctx.lineTo(42, 341);
  ctx.lineTo(49, 332);
  ctx.lineTo(44, 332);
  ctx.closePath();
  ctx.stroke();
  ctx.restore();

  ctx.fillStyle = '#94a3b8';
  ctx.font = '12px -apple-system, sans-serif';
  ctx.fillText(`Escáner IA: ${aiText}`, 56, 338);

  // Código de Acceso (Snippet)
  const token = licenseData.token || '';
  ctx.fillStyle = '#0f172a';
  ctx.fillRect(36, 360, 490, 44);
  ctx.strokeStyle = '#2563eb';
  ctx.strokeRect(36, 360, 490, 44);

  ctx.fillStyle = '#38bdf8';
  ctx.font = '12px monospace';
  const tokenSnippet = token.length > 56 ? token.substring(0, 54) + '...' : token;
  ctx.fillText(tokenSnippet, 46, 386);

  // 6. Tarjeta Blanca para el Código QR (Columna Derecha)
  const qrX = width - 290;
  const qrY = 120;
  const qrBoxSize = 254;

  ctx.fillStyle = '#ffffff';
  ctx.fillRect(qrX, qrY, qrBoxSize, qrBoxSize + 48);
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 2;
  ctx.strokeRect(qrX, qrY, qrBoxSize, qrBoxSize + 48);

  // Dibujar el QR desde el contenedor HTML designado
  const qrImg = document.querySelector(`#${qrContainerId} img`) || document.querySelector(`#${qrContainerId} canvas`);
  if (qrImg) {
    try {
      ctx.drawImage(qrImg, qrX + 17, qrY + 17, 220, 220);
    } catch (_) { }
  }

  ctx.fillStyle = '#0f172a';
  ctx.font = 'bold 11px -apple-system, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('ESCANEA CON LA APP PARA ACTIVAR', qrX + qrBoxSize / 2, qrY + qrBoxSize + 24);
  ctx.fillStyle = '#64748b';
  ctx.font = '10px -apple-system, sans-serif';
  ctx.fillText('Perfil > Licencia > Escanear QR', qrX + qrBoxSize / 2, qrY + qrBoxSize + 40);
  ctx.textAlign = 'left';

  // 7. Pie Legal de la Credencial
  ctx.fillStyle = '#475569';
  ctx.font = '11px -apple-system, sans-serif';
  const authorName = ownerConfig?.legal_identity?.author_full_name || 'Julio Angello Vasquez Navarro';
  const legalFramework = ownerConfig?.legal_identity?.legal_framework || 'Registrado ante INDECOPI bajo D.L. 822';
  ctx.fillText(`Autor y Titular Exclusivo: ${authorName} • ${legalFramework} • Lima, Perú`, 36, 458);

  ctx.fillStyle = '#334155';
  ctx.font = '10px monospace';
  ctx.fillText(`Firma Asimétrica: SHA-512/Ed25519 • Emisión: ${new Date().toLocaleString('es-PE')}`, 36, 478);
}

function downloadCredential() {
  const canvas = document.getElementById('credentialCanvas');
  if (!canvas) return;
  const clientId = document.getElementById('licClientSelect').value;
  const client = globalClients.find(c => c.id === clientId);
  const nameClean = (client ? client.business_name : 'Licencia').replace(/[^a-zA-Z0-9]/g, '_');

  const link = document.createElement('a');
  link.download = `Credencial_MochilaLista_${nameClean}_${Date.now()}.png`;
  link.href = canvas.toDataURL('image/png');
  link.click();
  showToast('Credencial PNG descargada en alta resolución.', 'success');
}

async function copyCredentialToClipboard() {
  const canvas = document.getElementById('credentialCanvas');
  if (!canvas) return;

  try {
    canvas.toBlob(async (blob) => {
      if (!blob) {
        showToast('No se pudo generar la imagen para el portapapeles.', 'error');
        return;
      }
      await copyPngBlobToClipboard(blob, {
        onFallbackDownload: () => downloadCredential(),
        fallbackMsg: 'El navegador requirió descarga directa del archivo PNG.',
      });
    }, 'image/png');
  } catch (e) {
    showToast('Error al copiar credencial: ' + e.message, 'error');
  }
}
