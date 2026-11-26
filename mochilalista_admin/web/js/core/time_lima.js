// =================== FECHAS Y HORA OFICIAL PERÚ (AMERICA/LIMA GMT-5 — D-ADM-04) ===================
/**
 * Convierte timestamps ISO UTC o epoch ms a hora oficial Perú (America/Lima, GMT-5)
 * con formato DD/MM/YYYY HH:mm:ss (Lima GMT-5) y fallback aritmético determinista -5h.
 */
function formatLimaDateTime(isoOrEpoch, fallback = '-') {
  if (isoOrEpoch === null || isoOrEpoch === undefined || isoOrEpoch === '') return fallback;
  let dateObj = null;
  if (typeof isoOrEpoch === 'number') {
    dateObj = new Date(isoOrEpoch);
  } else {
    const raw = String(isoOrEpoch).trim();
    if (!raw || raw === '-' || raw === 'Nunca' || raw === 'Sin respaldos' || raw === 'Sin copias registradas' || raw === 'No aplica') {
      return raw || fallback;
    }
    if (/^\d{10,13}$/.test(raw)) {
      const n = Number(raw);
      dateObj = new Date(raw.length === 10 ? n * 1000 : n);
    } else {
      dateObj = new Date(raw);
    }
  }
  if (!dateObj || Number.isNaN(dateObj.getTime())) {
    return String(isoOrEpoch);
  }

  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: 'America/Lima',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    }).formatToParts(dateObj);
    const map = {};
    parts.forEach(p => { map[p.type] = p.value; });
    const hh = map.hour === '24' ? '00' : map.hour;
    return `${map.day}/${map.month}/${map.year} ${hh}:${map.minute}:${map.second} (Lima GMT-5)`;
  } catch (_) {
    const lima = new Date(dateObj.getTime() - 5 * 60 * 60 * 1000);
    const pad = (n) => String(n).padStart(2, '0');
    return `${pad(lima.getUTCDate())}/${pad(lima.getUTCMonth() + 1)}/${lima.getUTCFullYear()} ${pad(lima.getUTCHours())}:${pad(lima.getUTCMinutes())}:${pad(lima.getUTCSeconds())} (Lima GMT-5)`;
  }
}

/**
 * Devuelve la fecha calendario YYYY-MM-DD en Zona Oficial Perú (America/Lima, GMT-5).
 */
function formatLimaIsoDate(isoOrEpoch, fallback = '') {
  if (isoOrEpoch === null || isoOrEpoch === undefined || isoOrEpoch === '') return fallback;
  const raw = String(isoOrEpoch).trim();
  if (!raw || raw === '-') return fallback;
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;

  let dateObj = null;
  if (typeof isoOrEpoch === 'number') {
    dateObj = new Date(isoOrEpoch);
  } else if (/^\d{10,13}$/.test(raw)) {
    const n = Number(raw);
    dateObj = new Date(raw.length === 10 ? n * 1000 : n);
  } else {
    dateObj = new Date(raw);
  }
  if (!dateObj || Number.isNaN(dateObj.getTime())) return fallback;

  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: 'America/Lima',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(dateObj);
    const map = {};
    parts.forEach(p => { map[p.type] = p.value; });
    return `${map.year}-${map.month}-${map.day}`;
  } catch (_) {
    const lima = new Date(dateObj.getTime() - 5 * 60 * 60 * 1000);
    const pad = (n) => String(n).padStart(2, '0');
    return `${lima.getUTCFullYear()}-${pad(lima.getUTCMonth() + 1)}-${pad(lima.getUTCDate())}`;
  }
}

/**
 * Devuelve sello legible DD/MM/YYYY HH:mm en hora oficial Perú (America/Lima, GMT-5).
 */
function formatLimaReceiptStamp(isoOrEpoch, fallback = '-') {
  const formatted = formatLimaDateTime(isoOrEpoch, fallback);
  if (!formatted || formatted === fallback) return fallback;
  const match = formatted.match(/^(\d{2}\/\d{2}\/\d{4})\s+(\d{2}:\d{2})/);
  return match ? `${match[1]} ${match[2]}` : formatted;
}

/**
 * Devuelve fecha calendario ISO YYYY-MM-DD normalizada en Zona Oficial Perú (America/Lima, GMT-5).
 */
function getLocalIsoDate(d = new Date()) {
  const iso = formatLimaIsoDate(d, '');
  if (iso) return iso;
  const dateObj = d instanceof Date ? d : new Date();
  const lima = new Date(dateObj.getTime() - 5 * 60 * 60 * 1000);
  const y = lima.getUTCFullYear();
  const m = String(lima.getUTCMonth() + 1).padStart(2, '0');
  const day = String(lima.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}
