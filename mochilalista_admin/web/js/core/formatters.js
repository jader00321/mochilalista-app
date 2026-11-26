// =================== NORMALIZACIÓN COMERCIAL, TELÉFONOS Y HTML (DRY D-ADM-05) ===================
// =================== NORMALIZACIÓN DE TELÉFONOS PERÚ (+51) ===================
function normalizePeruPhone(raw) {
  if (!raw) return '';
  const trimmed = String(raw).trim();
  if (!trimmed) return '';
  const hasPlus = trimmed.startsWith('+');
  const digits = trimmed.replace(/\D/g, '');
  if (!digits) return '';

  if (hasPlus) {
    return '+' + digits;
  }
  if (digits.length === 9 && digits.startsWith('9')) {
    return '+51' + digits;
  }
  if (digits.length === 11 && digits.startsWith('519')) {
    return '+' + digits;
  }
  return digits;
}

function formatPeruvianPhoneDisplay(phone) {
  if (!phone) return '-';
  const raw = String(phone).trim();
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 9) {
    return `+51${digits}`;
  }
  if (digits.length === 11 && digits.startsWith('51')) {
    return `+${digits}`;
  }
  return raw.startsWith('+') ? raw : (digits ? `+${digits}` : raw);
}

const CANONICAL_PLAN_LABELS = {
  MENSUAL: { full: 'Plan Mensual', short: 'Mensual' },
  TRIMESTRAL: { full: 'Plan Trimestral', short: 'Trimestral' },
  SEMESTRAL: { full: 'Plan Semestral', short: 'Semestral' },
  ANUAL: { full: 'Plan Anual', short: 'Anual' },
  PERPETUO_LIBERADO: { full: 'Licencia Perpetua', short: 'Perpetuo Liberado' },
  PERPETUO: { full: 'Licencia Perpetua', short: 'Perpetuo Liberado' },
  TRIAL: { full: 'Trial Gratuito', short: 'Trial Gratuito' },
  TRIAL_GRATUITO: { full: 'Trial Gratuito', short: 'Trial Gratuito' },
  EXTENSION_CORTESIA: { full: 'Extensión Cortesía', short: 'Cortesía' },
  PASE_ACTUALIZACION_ANUAL: { full: 'Pase Actualización Anual', short: 'Pase Actualización Anual' },
  RECARGA_IA_150: { full: 'Recarga IA 150', short: 'Recarga IA 150' },
  BONO_IA_PERSONALIZADO: { full: 'Recarga IA Personalizada', short: 'Recarga IA Personalizada' },
  SERVICIO_MIGRACION: { full: 'Servicio de Migración', short: 'Servicio de Migración' },
  ABONO_PARCIAL: { full: 'Abono Parcial', short: 'Abono Parcial' },
  PROSPECTO: { full: 'Prospecto Comercial', short: 'Prospecto' },
};

function formatPlanHumanLabel(planCode, options = {}) {
  const shortMode = options && options.short === true;
  if (!planCode) return shortMode ? 'MENSUAL' : '-';
  const raw = String(planCode).trim();
  const key = raw.toUpperCase();
  const entry = CANONICAL_PLAN_LABELS[key];
  if (entry) {
    return shortMode ? entry.short : entry.full;
  }
  return (shortMode ? raw : key).replace(/_/g, ' ');
}

function formatPlanLabel(plan) {
  return formatPlanHumanLabel(plan, { short: true });
}

/**
 * Normaliza cualquier denominación de plan (canónica o legada) a su slug oficial.
 * Retorna null si es un concepto personalizado no catalogado.
 */
function normalizePlanToSlug(rawPlan) {
  if (!rawPlan) return null;
  const p = String(rawPlan).trim().toUpperCase();

  // Coincidencias directas con slugs canónicos
  if (p === 'MENSUAL') return 'MENSUAL';
  if (p === 'TRIMESTRAL') return 'TRIMESTRAL';
  if (p === 'SEMESTRAL') return 'SEMESTRAL';
  if (p === 'ANUAL') return 'ANUAL';
  if (p === 'PERPETUO_LIBERADO' || p === 'PERPETUO') return 'PERPETUO_LIBERADO';
  if (p === 'PASE_ACTUALIZACION_ANUAL') return 'PASE_ACTUALIZACION_ANUAL';
  if (p === 'RECARGA_IA_150') return 'RECARGA_IA_150';
  if (p === 'BONO_IA_PERSONALIZADO') return 'BONO_IA_PERSONALIZADO';
  if (p === 'SERVICIO_MIGRACION') return 'SERVICIO_MIGRACION';
  if (p === 'EXTENSION_CORTESIA') return 'EXTENSION_CORTESIA';
  if (p === 'ABONO_PARCIAL') return 'ABONO_PARCIAL';

  // Normalización defensiva para textos descriptivos legados
  if (p.includes('MENSUAL')) return 'MENSUAL';
  if (p.includes('TRIMESTRAL')) return 'TRIMESTRAL';
  if (p.includes('SEMESTRAL')) return 'SEMESTRAL';
  if (p.includes('ANUAL') && !p.includes('UPDATE') && !p.includes('ACTUALIZAC')) return 'ANUAL';
  if (p.includes('PERPETU')) return 'PERPETUO_LIBERADO';
  if (p.includes('PASE') || (p.includes('UPDATE') && p.includes('ANUAL')) || p.includes('ACTUALIZACION')) return 'PASE_ACTUALIZACION_ANUAL';
  if (p.includes('150') || p.includes('BOLSA EXTRA IA') || p.includes('RECARGA EXTRA IA') || p.includes('RECARGA IA 150')) return 'RECARGA_IA_150';
  if (p.includes('BONO IA') || p.includes('RECARGA IA PERSONALIZADA')) return 'BONO_IA_PERSONALIZADO';
  if (p.includes('MIGRAC') || p.includes('SERVICIO TÉCNICO') || p.includes('SERVICIO TECNICO')) return 'SERVICIO_MIGRACION';
  if (p.includes('CORTES') || p.includes('EXTENSION') || p.includes('EXTENSIÓN')) return 'EXTENSION_CORTESIA';
  if (p.includes('ABONO') || p.includes('PARCIAL') || p.includes('A CUENTA')) return 'ABONO_PARCIAL';

  return null;
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
