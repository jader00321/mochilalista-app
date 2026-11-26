// =================== PORTAPAPELES UNIFICADO CON FALLBACK (DRY D-ADM-03) ===================
/**
 * Copia texto plano al portapapeles de forma segura con fallback textarea + execCommand.
 */
async function copyPlainTextToClipboard(
  text,
  successMsg = 'Texto copiado al portapapeles.',
  options = {}
) {
  if (!text) return false;
  try {
    if (typeof navigator !== 'undefined' && navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
    } else if (typeof document !== 'undefined' && document.body && typeof document.createElement === 'function') {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      if (typeof ta.select === 'function') ta.select();
      if (typeof document.execCommand === 'function') {
        document.execCommand('copy');
      }
      if (typeof ta.remove === 'function') {
        ta.remove();
      } else if (document.body && typeof document.body.removeChild === 'function') {
        document.body.removeChild(ta);
      }
    } else {
      throw new Error('API de portapapeles no disponible en este entorno');
    }
    if (options.suppressSuccessToast !== true && successMsg && typeof showToast === 'function') {
      showToast(successMsg, options.successType || 'success');
    }
    return true;
  } catch (err) {
    if (options.suppressErrorToast !== true && typeof showToast === 'function') {
      const msg = options.errorMessage || ('No se pudo copiar al portapapeles: ' + err.message);
      showToast(msg, options.errorType || 'error');
    }
    return false;
  }
}

/**
 * Copia un Blob PNG al portapapeles ejecutando descarga de respaldo si el navegador bloquea ClipboardItem.
 */
async function copyPngBlobToClipboard(blob, options = {}) {
  if (!blob) return false;
  try {
    if (
      typeof navigator !== 'undefined' &&
      navigator.clipboard &&
      typeof navigator.clipboard.write === 'function' &&
      typeof ClipboardItem !== 'undefined'
    ) {
      await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
      if (typeof showToast === 'function') {
        showToast(
          options.successMsg || '¡Credencial copiada al portapapeles! Pégala con Ctrl+V en WhatsApp Web.',
          'success'
        );
      }
      return true;
    }
    throw new Error('ClipboardItem PNG no disponible');
  } catch (_) {
    if (typeof options.onFallbackDownload === 'function') {
      options.onFallbackDownload();
    }
    if (typeof showToast === 'function') {
      showToast(
        options.fallbackMsg || 'El navegador requirió descarga directa del archivo PNG.',
        'info'
      );
    }
    return false;
  }
}
