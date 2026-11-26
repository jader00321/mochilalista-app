// =================== 3B. COMPOSITOR UNIVERSAL DE WHATSAPP (PLAN 22 FASE 3) ===================
let currentWaComposerTemplateKey = 'welcome';
let currentWaPreTemplateDraft = '';
let currentWaRenderedTemplateBase = '';
let openedInApkDispatchMode = false;
let currentDispatchRelease = null;
let currentDispatchClient = null;
let currentDispatchMode = 'eligible';
let currentDispatchVariant = 'universal';
let isApkDispatchMode = false;

const WA_SNIPPET_KEYS = ['payment', 'device', 'expiration', 'token'];

const WA_TEMPLATES = {
  welcome: {
    name: 'Saludo y Bienvenida',
    text: '¡Hola, {titular}! 👋 Te saluda el equipo de MochilaLista.\nQueremos darte la más cordial bienvenida a nuestra plataforma de punto de venta 100% Offline-First para tu negocio *{negocio}*.\nTu sistema ya está configurado para operar con el Hardware ID: `{device_id}`.\nCuentas con soporte técnico y todas las herramientas de control comercial sin depender de conexión a internet.\n¡Quedamos atentos a cualquier consulta! 🎒🚀'
  },
  expiring: {
    name: 'Recordatorio de Renovación Preventiva',
    text: 'Estimado(a) {titular}, te saludamos de MochilaLista.\nTe recordamos cordialmente que la licencia de tu sistema para *{negocio}* (Plan {plan}) se encuentra próxima a vencer en *{dias_restantes} día(s)* (Fecha de vencimiento: *{vencimiento}*).\nPara garantizar la continuidad ininterrumpida de tus ventas y la emisión de comprobantes, te invitamos a coordinar tu renovación anticipada.\nHardware ID: `{device_id}`.\n¡Estamos a tu entera disposición! 📲✨'
  },
  prospect: {
    name: 'Seguimiento a Prospecto',
    text: '¡Hola, {titular}! Te saludamos cordialmente de MochilaLista.\nNos comunicamos para hacer seguimiento a la evaluación del sistema de punto de venta en tu negocio *{negocio}*.\n¿Has tenido oportunidad de revisar las funciones de cobro rápido, inventario e IA offline?\nCon gusto podemos coordinar una breve demostración o habilitarte una activación personalizada adaptada al ritmo de tu negocio.\n¡Quedamos a tu orden! 💼📊'
  },
  license: {
    name: 'Entrega Oficial de Licencia / Credencial',
    text: '¡Excelente noticia, {titular}!\nTu licencia oficial de MochilaLista para el negocio *{negocio}* ha sido generada exitosamente.\n\n📌 Detalles de la Licencia:\n• Plan: {plan}\n• Hardware ID: `{device_id}`\n• Vigencia: {vencimiento}\n• Versión: {version}\n\n🔑 Código de Activación:\n`{codigo_licencia}`\n\nPuedes ingresar este código o escanear el QR desde la pantalla de activación de tu aplicación móvil. ¡Gracias por confiar en MochilaLista! 🎒✅'
  },
  ai_bonus: {
    name: 'Bono / Recarga IA',
    text: '¡Hola, {titular}! 👋 Te saludamos de MochilaLista.\nTu recarga de escaneos de Inteligencia Artificial para *{negocio}* ha sido acreditada con éxito.\n\n⚡ Detalle de la Recarga:\n• Créditos IA Otorgados: +{creditos_ia} escaneos vitalicios\n• Hardware ID Vinculado: `{device_id}`\n\n🔑 Token de Activación IA:\n`{codigo_licencia}`\n\nPuedes ingresar este token o escanear el QR en tu app para sumarlos inmediatamente a tu saldo disponible. ¡A seguir potenciando tu negocio! 🚀'
  },
  courtesy_extension: {
    name: 'Extensión de Cortesía',
    text: 'Estimado(a) {titular}, te saludamos de MochilaLista.\nTe confirmamos la habilitación de una extensión de cortesía por *{dias} día(s)* adicionales para tu sistema en *{negocio}*.\n\n📌 Nueva vigencia temporal: *{vencimiento}*\n• Hardware ID: `{device_id}`\n\n🔑 Código de Activación:\n`{codigo_licencia}`\n\nIngresa este código o escanea el QR en tu aplicación para continuar operando sin interrupciones. ¡Quedamos a tu servicio! 🎒✅'
  },
  update: {
    name: 'Aviso de Nueva Versión APK',
    text: '¡Hola, {titular}! Te saludamos de MochilaLista.\nTe informamos que ya se encuentra disponible una nueva actualización de la aplicación: versión *v{version}* con mejoras clave de rendimiento, estabilidad y nuevas funciones comerciales para tu negocio *{negocio}*.\nTu equipo actual (`{device_id}`) es totalmente compatible.\nContáctanos por este medio para facilitarte el enlace de descarga directa del APK oficial. 🚀📲'
  },
  empty: {
    name: 'Chat Vacío',
    text: ''
  }
};

const DEFAULT_WA_TEMPLATES = JSON.parse(JSON.stringify(WA_TEMPLATES));

function getCurrentWaComposerClient() {
  return (globalClients && globalClients.find(c => c.id === currentWaComposerClientId)) ||
         (globalReleaseMatrix && globalReleaseMatrix.find(r => r.client_id === currentWaComposerClientId)) ||
         currentDispatchClient ||
         null;
}

function normalizeWaSnippetKey(rawType) {
  if (rawType === 'payment' || rawType === 'yape') return 'payment';
  if (rawType === 'device' || rawType === 'hardware') return 'device';
  if (rawType === 'expiration' || rawType === 'vencimiento') return 'expiration';
  if (rawType === 'token') return 'token';
  return rawType;
}

function buildWaSnippetBlock(rawType, options = {}) {
  const key = normalizeWaSnippetKey(rawType);
  const notify = options.notify === true;
  const client = getCurrentWaComposerClient();
  const modalEl = document.getElementById('modalWaComposer');
  const pm = ownerConfig?.payment_methods || {};
  const li = ownerConfig?.legal_identity || {};

  if (key === 'payment') {
    const hasConfiguredPm = Boolean(ownerConfig && ownerConfig.payment_methods);
    const phone = hasConfiguredPm
      ? String(pm.yape_plin_phone ?? '').trim()
      : '922836879';
    const titular = String(pm.yape_plin_holder || li.author_full_name || '').trim() || 'Julio Angello Vasquez Navarro';
    if (!phone) {
      if (notify) showToast('No hay número Yape / Plin configurado en Ajustes.', 'warning');
      return null;
    }
    return `*Datos de Pago Yape / Plin:*\n• Número: *${phone}*\n• Titular: *${titular}*\n• Enviar comprobante por este medio.`;
  }

  if (key === 'device') {
    const devId = String(client?.current_device_id || client?.device_id || '').trim();
    if (!devId || devId === 'PENDIENTE' || devId === '-') {
      if (notify) showToast('Este cliente aún no tiene un Hardware ID vinculado.', 'warning');
      return null;
    }
    return `*Hardware ID:* \`${devId}\``;
  }

  if (key === 'expiration') {
    const licType = String(client?.license_type || '').toUpperCase();
    const isPerp = licType === 'PERPETUO_LIBERADO' || licType === 'PERPETUO';
    const expRaw = String(client?.license_expires || '').trim();
    if ((!expRaw && !isPerp) || licType === 'PROSPECTO') {
      if (notify) showToast('Este cliente no tiene fecha de vencimiento activa registrada.', 'warning');
      return null;
    }
    if (expRaw) {
      const expDate = new Date(expRaw);
      const diffDays = Number.isNaN(expDate.getTime())
        ? 0
        : Math.max(0, Math.ceil((expDate - new Date()) / (1000 * 60 * 60 * 24)));
      return `*Vencimiento:* ${expRaw.substring(0, 10)} (${diffDays} día(s) restantes)`;
    }
    const updStr = client?.updates_until ? String(client.updates_until).substring(0, 10) : 'Vigente';
    return `*Vencimiento:* Licencia Perpetua (Updates hasta: ${updStr})`;
  }

  if (key === 'token') {
    const hasRealToken = modalEl?.dataset?.hasRealToken === 'true';
    const lastToken = String(modalEl?.dataset?.lastToken || '').trim();
    if (!hasRealToken || !lastToken || lastToken.startsWith('ML9-PENDIENTE')) {
      if (notify) showToast('Este cliente aún no tiene un token de licencia emitido.', 'warning');
      return null;
    }
    return `*Último Token de Licencia:*\n\`${lastToken}\``;
  }

  return null;
}

function appendSnippetBlockToText(text, block) {
  const cleanText = String(text || '').replace(/\r\n/g, '\n');
  if (!block) return cleanText;
  if (cleanText.includes(block)) return cleanText;
  const trimmedEnd = cleanText.replace(/\s+$/, '');
  return trimmedEnd ? `${trimmedEnd}\n\n${block}` : block;
}

function removeSnippetBlockFromText(text, block) {
  const cleanText = String(text || '').replace(/\r\n/g, '\n');
  if (!block || !cleanText.includes(block)) return cleanText;
  return cleanText
    .split(block)
    .join('')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/^\n+|\n+$/g, '')
    .trim();
}

function extractBaseAndSnippetsFromText(text) {
  let working = String(text || '').replace(/\r\n/g, '\n');
  const activeMatches = [];

  WA_SNIPPET_KEYS.forEach(k => {
    const blk = buildWaSnippetBlock(k, { notify: false });
    if (blk && working.includes(blk)) {
      activeMatches.push({ key: k, block: blk, index: working.indexOf(blk) });
    }
  });

  activeMatches.sort((a, b) => a.index - b.index);
  activeMatches.forEach(item => {
    working = removeSnippetBlockFromText(working, item.block);
  });

  return {
    baseText: working,
    activeKeys: activeMatches.map(item => item.key),
  };
}

function syncWaInsertChipsState() {
  const textarea = document.getElementById('waCompMessage');
  const normalized = String(textarea?.value || '').replace(/\r\n/g, '\n');
  document.querySelectorAll('.wa-insert-chip').forEach(chip => {
    const key = normalizeWaSnippetKey(chip.dataset.snippet || '');
    if (!key) {
      chip.classList.remove('active');
      return;
    }
    const blk = buildWaSnippetBlock(key, { notify: false });
    const isActive = Boolean(blk && normalized.includes(blk));
    chip.classList.toggle('active', isActive);
  });
}

const WA_TO_CONFIG_TEMPLATE_KEY = {
  welcome: 'trial_welcome',
  expiring: 'expiring_reminder',
  license: 'license_issued',
  update: 'apk_update_eligible',
  prospect: 'prospect',
  ai_bonus: 'ai_bonus',
  courtesy_extension: 'courtesy_extension',
};

const CONFIG_TO_WA_TEMPLATE_KEY = {
  trial_welcome: 'welcome',
  expiring_reminder: 'expiring',
  license_issued: 'license',
  apk_update_eligible: 'update',
  prospect: 'prospect',
  ai_bonus: 'ai_bonus',
  courtesy_extension: 'courtesy_extension',
};

function resolveConfigTemplateKeyFromWa(tplKey) {
  return WA_TO_CONFIG_TEMPLATE_KEY[tplKey] || tplKey;
}

function resolveWaTemplateKeyFromConfig(cfgKey) {
  return CONFIG_TO_WA_TEMPLATE_KEY[cfgKey] || cfgKey;
}

function syncWaTemplatesFromOwnerConfig(cfg) {
  const cfgTemplates = cfg?.templates || {};
  Object.entries(WA_TO_CONFIG_TEMPLATE_KEY).forEach(([waKey, cfgKey]) => {
    if (!WA_TEMPLATES[waKey]) return;
    const persistedVal = cfgTemplates[cfgKey] ?? cfgTemplates[waKey];
    if (persistedVal !== undefined && persistedVal !== null && String(persistedVal).trim() !== '') {
      WA_TEMPLATES[waKey].text = String(persistedVal);
    } else if (DEFAULT_WA_TEMPLATES[waKey]) {
      WA_TEMPLATES[waKey].text = DEFAULT_WA_TEMPLATES[waKey].text;
    }
  });
}

function renderWaTemplateBaseText(tplKey) {
  const client = getCurrentWaComposerClient();
  const modalEl = document.getElementById('modalWaComposer');
  if (!client) return '';

  if (tplKey === 'update' && currentDispatchRelease) {
    return buildApkDispatchMessage(currentDispatchRelease, client, currentDispatchMode);
  }

  const canonKey = resolveConfigTemplateKeyFromWa(tplKey);
  const customText = ownerConfig?.templates?.[canonKey] ?? ownerConfig?.templates?.[tplKey];
  const rawTpl = (customText !== undefined && customText !== null && String(customText) !== '')
    ? String(customText)
    : (WA_TEMPLATES[tplKey]?.text || '');
  if (!rawTpl) return '';

  const now = new Date();
  const expDate = client.license_expires ? new Date(client.license_expires) : null;
  const diffDays = expDate ? Math.max(0, Math.ceil((expDate - now) / (1000 * 60 * 60 * 24))) : 0;
  const latestVer = getLatestPublishedVersion() || client.installed_version || '9.40.0';

  const pm = ownerConfig?.payment_methods || {};
  const li = ownerConfig?.legal_identity || {};
  const yapePhone = pm.yape_plin_phone || '922836879';
  const yapeTitular = pm.yape_plin_holder || li.author_full_name || 'Julio Angello Vasquez Navarro';
  const autor = li.author_full_name || 'Julio Angello Vasquez Navarro';
  const commercialName = li.commercial_name || li.brand_name || 'MochilaLista';
  const supportPhone = li.support_phone || '+51 922 836 879';
  const aiCredsVal = modalEl?.dataset?.aiCredits || client.ai_reported_balance || '0';
  const diasVal = modalEl?.dataset?.diasExtension || '7';
  const lastToken = (modalEl?.dataset?.lastToken || '').trim() || `ML9-PENDIENTE-${client.current_device_id || 'DISPOSITIVO'}`;

  const bcpAccount = String(pm.bcp_account_number || '').trim();
  const bcpHolder = String(pm.bcp_account_holder || '').trim();
  const bcpCci = String(pm.bcp_cci || '').trim();
  const bcpBlock = bcpAccount
    ? `\n🏦 BCP: ${bcpAccount}${bcpCci ? ` (CCI: ${bcpCci})` : ''}${bcpHolder ? ` - ${bcpHolder}` : ''}`
    : '';

  const bbvaAccount = String(pm.bbva_account_number || '').trim();
  const bbvaHolder = String(pm.bbva_account_holder || '').trim();
  const bbvaCci = String(pm.bbva_cci || '').trim();
  const bbvaBlock = bbvaAccount
    ? `\n🏦 BBVA: ${bbvaAccount}${bbvaCci ? ` (CCI: ${bbvaCci})` : ''}${bbvaHolder ? ` - ${bbvaHolder}` : ''}`
    : '';

  return rawTpl
    .replace(/\{negocio\}/g, client.business_name || 'su negocio')
    .replace(/\{titular\}/g, client.owner_name || 'Estimado cliente')
    .replace(/\{plan\}/g, formatPlanLabel(client.license_type))
    .replace(/\{dias_restantes\}/g, String(diffDays))
    .replace(/\{dias\}/g, String(diasVal))
    .replace(/\{creditos_ia\}/g, String(aiCredsVal))
    .replace(/\{vencimiento\}/g, client.license_expires ? client.license_expires.substring(0, 10) : 'Activa')
    .replace(/\{device_id\}/g, client.current_device_id || client.device_id || 'PENDIENTE')
    .replace(/\{version\}/g, latestVer)
    .replace(/\{codigo_licencia\}/g, lastToken)
    .replace(/\{codigo\}/g, lastToken)
    .replace(/\{yape_phone\}/g, yapePhone)
    .replace(/\{yape_titular\}/g, yapeTitular)
    .replace(/\{bloque_banco_bcp\}/g, bcpBlock)
    .replace(/\{bloque_banco_bbva\}/g, bbvaBlock)
    .replace(/\{commercial_name\}/g, commercialName)
    .replace(/\{support_phone\}/g, supportPhone)
    .replace(/\{autor\}/g, autor);
}
