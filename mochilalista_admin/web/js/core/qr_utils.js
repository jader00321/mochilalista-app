// =================== UTILIDADES QR VECTORIALES & QUIET ZONE ===================
/**
 * Calcula longitud UTF-8 en bytes de forma segura en navegador y Node.js
 */
function getUtf8ByteLength(text) {
  const str = String(text ?? '');
  if (typeof TextEncoder !== 'undefined') {
    return new TextEncoder().encode(str).length;
  }
  try {
    return unescape(encodeURIComponent(str)).length;
  } catch (_) {
    return str.length;
  }
}

/**
 * Renderiza de forma segura un código QR vectorial sin fallos por QRCode.CorrectLevel
 * Selecciona automáticamente CorrectLevel.L para payloads densos (> 900 B, p. ej. MLC1)
 * y aplica fallback controlado sin dejar errores silenciosos.
 */
function renderSafeQrCode(container, text, size = 196, colorDark = '#0f172a', colorLight = '#ffffff') {
  const containerEl = (typeof container === 'string') ? document.getElementById(container) : container;
  if (!containerEl) return null;
  containerEl.innerHTML = '';
  if (typeof QRCode === 'undefined') return null;

  const payloadStr = String(text ?? '');
  const byteLen = getUtf8ByteLength(payloadStr);
  const hasLevels = typeof QRCode.CorrectLevel !== 'undefined';
  const levelL = hasLevels && QRCode.CorrectLevel.L !== undefined ? QRCode.CorrectLevel.L : 1;
  const levelM = hasLevels && QRCode.CorrectLevel.M !== undefined ? QRCode.CorrectLevel.M : 0;
  const preferredLevel = byteLen > 900 ? levelL : levelM;

  try {
    return new QRCode(containerEl, {
      text: payloadStr,
      width: size,
      height: size,
      colorDark: colorDark,
      colorLight: colorLight,
      correctLevel: preferredLevel,
    });
  } catch (e) {
    try {
      return new QRCode(containerEl, {
        text: payloadStr,
        width: size,
        height: size,
        colorDark: colorDark,
        colorLight: colorLight,
        correctLevel: levelL,
      });
    } catch (e2) {
      console.error('renderSafeQrCode capacity/fallback error:', e2);
      if (typeof document !== 'undefined' && typeof document.createElement === 'function') {
        const warnEl = document.createElement('div');
        warnEl.className = 'qr-capacity-warning';
        warnEl.style.cssText = 'padding:0.75rem; font-size:0.78rem; color:#b91c1c; text-align:center; font-weight:600;';
        warnEl.textContent = `No se pudo generar el QR (${byteLen} B excede el máximo físico QR V40-L de 2,953 B).`;
        containerEl.appendChild(warnEl);
      }
      return null;
    }
  }
}

/**
 * Exporta un código QR con margen reglamentario blanco puro (#FFFFFF) de 32px (Quiet Zone).
 * Resuelve la imposibilidad de detección en cámaras móviles y decodificadores de galería.
 * @param {HTMLElement|string} sourceContainer - Contenedor del canvas/img o elemento directo
 * @param {string} fileName - Nombre de descarga del archivo PNG
 * @param {number} marginPx - Tamaño del margen perimetral blanco en píxeles (default: 32)
 */
function downloadQrWithQuietZone(sourceContainer, fileName, marginPx = 32) {
  let container = null;
  if (typeof sourceContainer === 'string') {
    container = document.querySelector(sourceContainer);
  } else if (sourceContainer instanceof HTMLElement) {
    container = sourceContainer;
  }

  if (!container) {
    showToast('No hay código QR disponible para descargar.', 'warning');
    return;
  }

  const sourceEl = container.tagName && (container.tagName.toLowerCase() === 'canvas' || container.tagName.toLowerCase() === 'img')
    ? container
    : (container.querySelector('canvas') || container.querySelector('img'));

  if (!sourceEl) {
    showToast('No hay código QR disponible para descargar.', 'warning');
    return;
  }

  function doExport(srcCanvasOrImg, w, h) {
    const totalW = w + (marginPx * 2);
    const totalH = h + (marginPx * 2);
    const offscreen = document.createElement('canvas');
    offscreen.width = totalW;
    offscreen.height = totalH;
    const ctx = offscreen.getContext('2d');
    if (!ctx) return;
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, totalW, totalH);
    ctx.drawImage(srcCanvasOrImg, marginPx, marginPx, w, h);

    const a = document.createElement('a');
    a.download = fileName.endsWith('.png') ? fileName : `${fileName}.png`;
    a.href = offscreen.toDataURL('image/png');
    a.click();
    showToast('QR descargado con margen blanco reglamentario.', 'success');
  }

  if (sourceEl.tagName.toLowerCase() === 'canvas') {
    doExport(sourceEl, sourceEl.width, sourceEl.height);
  } else if (sourceEl.tagName.toLowerCase() === 'img') {
    if (sourceEl.complete && sourceEl.naturalWidth > 0) {
      doExport(sourceEl, sourceEl.naturalWidth, sourceEl.naturalHeight);
    } else {
      const img = new Image();
      img.onload = () => doExport(img, img.naturalWidth || 256, img.naturalHeight || 256);
      img.src = sourceEl.src;
    }
  }
}
