async function resetOwnerConfigByScope(scope = 'all') {
  try {
    const res = await fetch('/api/config/reset', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scope }),
    });
    if (!res.ok) throw new Error('Error al restablecer configuración');
    const data = await res.json();
    ownerConfig = data.config;
    populateSettingsForm(ownerConfig);
    applyConfigToUi(ownerConfig);
    if ((scope === 'all' || scope === 'preferences') && ownerConfig?.system?.theme) {
      applyTheme(ownerConfig.system.theme);
    }
    renderTemplatePreview();
    showToast(data.message || 'Configuración restablecida a los valores oficiales de fábrica.', 'success');
  } catch (e) {
    showToast('Error: ' + e.message, 'error');
  }
}

function triggerTemplatePreviewDebounced() {
  clearTimeout(templatePreviewTimer);
  templatePreviewTimer = setTimeout(() => {
    renderTemplatePreview();
  }, 250);
}

async function renderTemplatePreview() {
  const content = document.getElementById('cfgTemplateContent')?.value;
  const key = document.getElementById('cfgTemplateSelect')?.value;
  const bubble = document.getElementById('waBubbleContent');
  if (!bubble) return;

  try {
    const res = await fetch('/api/config/preview-template', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        template: content,
        template_key: key,
        context: {
          titular: 'Juan Pérez',
          negocio: 'Librería Central',
          plan: 'MENSUAL',
          dias: '30',
          dias_restantes: '3',
          vencimiento: '2026-12-31',
          creditos_ia: '100',
          codigo: 'ML9-DEMO-ACTIVATION-TOKEN-XXXXX',
          version: '9.41.0',
          version_actual: '9.38.0',
          device_id: 'ML-9K4B',
          changelog: 'Mejoras en el escáner IA y velocidad.',
          link_descarga: 'https://drive.google.com/file/d/demo/view (o adjunto en chat)',
          precio_pase: Number(ownerConfig?.catalog?.PASE_ACTUALIZACION_ANUAL?.price ?? 150).toFixed(2),
        },
      }),
    });

    if (res.ok) {
      const data = await res.json();
      bubble.innerHTML = formatWhatsAppPreview(data.rendered || '');
    } else {
      bubble.textContent = content || '';
    }
  } catch (_) {
    bubble.textContent = content || '';
  }
}

function formatWhatsAppPreview(rawText) {
  if (!rawText) return '';
  let escaped = escapeHtml(rawText);
  escaped = escaped.replace(/`([^`\n]+)`/g, '<code>$1</code>');
  escaped = escaped.replace(/\*([^*\n]+)\*/g, '<strong>$1</strong>');
  escaped = escaped.replace(/_([^_\n]+)_/g, '<em>$1</em>');
  escaped = escaped.replace(/~([^~\n]+)~/g, '<del>$1</del>');
  return escaped.replace(/\n/g, '<br>');
}

function renderSettingsApkDirsSummary(cfg) {
  const container = document.getElementById('settingsApkDirsSummary');
  if (!container) return;
  const dirs = cfg?.system?.apk_search_dirs;
  if (!Array.isArray(dirs) || dirs.length === 0) {
    const fallbackLib = cfg?.system?.apk_library_dir || 'No configurada';
    container.innerHTML = `
      <div class="settings-apk-dir-row">
        <div>
          <strong>Biblioteca Oficial</strong>
          <div class="settings-apk-dir-path">${escapeHtml(fallbackLib)}</div>
        </div>
        <span class="badge badge-green">Activa</span>
      </div>
    `;
    return;
  }

  container.innerHTML = dirs.map(d => {
    const label = d.label || (d.kind === 'official_library' ? 'Biblioteca Oficial' : 'Carpeta Personalizada');
    const enabled = d.enabled !== false;
    return `
      <div class="settings-apk-dir-row">
        <div>
          <div style="font-weight:600; color:var(--text-primary);">${escapeHtml(label)}</div>
          <div class="settings-apk-dir-path">${escapeHtml(d.path || '-')}</div>
        </div>
        <div style="display:flex; gap:0.35rem; align-items:center;">
          ${d.is_default ? '<span class="badge badge-mono">Fábrica</span>' : '<span class="badge badge-purple">Personalizada</span>'}
          <span class="badge ${enabled ? 'badge-green' : 'badge-amber'}">${enabled ? 'Activa' : 'Omitida'}</span>
        </div>
      </div>
    `;
  }).join('');
}

function populateSettingsForm(cfg) {
  if (!cfg) return;

  // 1. Catálogo
  const tbody = document.getElementById('catalogConfigTableBody');
  if (tbody && cfg.catalog) {
    tbody.innerHTML = '';
    const catalog = cfg.catalog;
    for (const [slug, item] of Object.entries(catalog)) {
      const hasDefault12Updates = slug === 'PERPETUO_LIBERADO' || slug === 'PASE_ACTUALIZACION_ANUAL';
      const rawUpd = Number(item.updates_window_months ?? item.updates_months ?? 0);
      const updatesVal = (hasDefault12Updates && (!Number.isFinite(rawUpd) || rawUpd <= 0)) ? 12 : rawUpd;
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><strong style="font-family:var(--font-mono);">${slug}</strong></td>
        <td><input type="text" class="cfg-plan-label" data-slug="${slug}" value="${escapeHtml(item.label || slug)}" style="width:100%; min-width:140px; font-size:0.85rem;"></td>
        <td><input type="number" class="cfg-plan-price" data-slug="${slug}" value="${Number(item.price || 0).toFixed(2)}" step="0.5" min="0" style="width:100%; font-weight:700; text-align:right;"></td>
        <td><input type="number" class="cfg-plan-days" data-slug="${slug}" value="${item.days || 0}" min="0" style="width:100%; text-align:right;"></td>
        <td><input type="number" class="cfg-plan-ai" data-slug="${slug}" value="${item.ai_credits || 0}" min="0" style="width:100%; text-align:right; color:var(--primary); font-weight:700;"></td>
        <td><input type="number" class="cfg-plan-updates" data-slug="${slug}" value="${updatesVal}" min="0" style="width:100%; text-align:right;"></td>
        <td><input type="text" class="cfg-plan-desc" data-slug="${slug}" value="${escapeHtml(item.description || '')}" style="width:100%; min-width:180px; font-size:0.82rem;"></td>
      `;
      tbody.appendChild(tr);
    }
  }

  // Tarifa de migración
  const migFeeInput = document.getElementById('cfgMigrationFee');
  if (migFeeInput) {
    const migPrice = (cfg?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
      ? cfg.catalog.HARDWARE_MIGRATION_FEE.price
      : (cfg?.migration_fee || 40.0);
    migFeeInput.value = Number(migPrice).toFixed(2);
  }

  // 2. Plantillas (con borrador en memoria)
  syncDraftTemplatesFromConfig(cfg);
  const tplSelect = document.getElementById('cfgTemplateSelect');
  const tplTextarea = document.getElementById('cfgTemplateContent');
  if (tplSelect && tplTextarea) {
    const selKey = tplSelect.value || 'license_issued';
    activeSettingsTemplateKey = selKey;
    tplTextarea.value = settingsDraftTemplates[selKey] || resolveCanonicalTemplateFromMap(cfg.templates, selKey) || '';
  }

  // 3. Legal & Pagos
  if (cfg.legal_identity) {
    const li = cfg.legal_identity;
    setInputValue('cfgLegalOwner', li.author_full_name);
    setInputValue('cfgBrandName', li.commercial_name || li.brand_name);
    setInputValue('cfgSupportPhone', li.support_phone);
  }

  if (cfg.payment_methods) {
    const pm = cfg.payment_methods;
    setInputValue('cfgYapePhone', pm.yape_plin_phone);
    setInputValue('cfgYapeHolder', pm.yape_plin_holder);
    setInputValue('cfgBcpHolder', pm.bcp_account_holder);
    setInputValue('cfgBcpAccount', pm.bcp_account_number);
    setInputValue('cfgBcpCci', pm.bcp_cci);
    setInputValue('cfgBbvaHolder', pm.bbva_account_holder);
    setInputValue('cfgBbvaAccount', pm.bbva_account_number);
    setInputValue('cfgBbvaCci', pm.bbva_cci);
  }

  // 4. Preferencias y Sistema
  const sys = cfg.system || cfg.preferences || {};
  setInputValue('cfgDefaultEnv', sys.default_mode || sys.default_environment || 'sandbox');
  setInputValue('cfgDefaultTheme', sys.theme || sys.default_theme || 'dark');
  setInputValue('cfgTableDensity', sys.table_density || 'comfortable');
  renderSettingsApkDirsSummary(cfg);

  savedSettingsSnapshot = buildNormalizedSettingsSnapshotFromConfig(cfg);
  updateSettingsDirtyState();
}

function setInputValue(id, val) {
  const el = document.getElementById(id);
  if (el) el.value = val !== undefined && val !== null ? val : '';
}

function applyConfigToUi(cfg) {
  if (!cfg) return;

  // Actualizar sello de autor en el header
  if (cfg.legal_identity && cfg.legal_identity.author_full_name) {
    const seal = document.querySelector('.author-name');
    if (seal) seal.textContent = cfg.legal_identity.author_full_name;
  }

  // Sincronizar plantillas del compositor universal de WhatsApp
  if (typeof syncWaTemplatesFromOwnerConfig === 'function') {
    syncWaTemplatesFromOwnerConfig(cfg);
  }

  // Aplicar densidad de tablas
  const density = cfg.system?.table_density || cfg.preferences?.table_density || 'comfortable';
  applyTableDensity(density);

  // Actualizar resumen de Rutas APK en Tab 4
  renderSettingsApkDirsSummary(cfg);

  // Actualizar opciones en el Generador de Licencias, Modal de Pago Manual y Drawer 360
  if (cfg.catalog) {
    const planSelect = document.getElementById('licPlanSelect');
    if (planSelect) {
      for (const opt of planSelect.options) {
        const item = cfg.catalog[opt.value];
        if (item) {
          opt.setAttribute('data-price', Number(item.price || 0).toFixed(2));
          opt.setAttribute('data-days', item.days || 0);
          opt.setAttribute('data-scans', item.ai_credits || 0);
          opt.textContent = `${item.label || opt.value} (S/ ${Number(item.price || 0).toFixed(2)})`;
        }
      }
      updatePlanImpactAndProjection();
    }

    const manualPreset = document.getElementById('manualPayPlanPreset');
    if (manualPreset) {
      for (const opt of manualPreset.options) {
        const item = opt.value === 'SERVICIO_MIGRACION'
          ? cfg.catalog.HARDWARE_MIGRATION_FEE
          : cfg.catalog[opt.value];
        if (item) {
          const p = Number(item.price || 0);
          opt.setAttribute('data-price', p.toFixed(2));
          opt.textContent = `${item.label || opt.value} (S/ ${p.toFixed(2)})`;
        }
      }
    }

    const drawerPlanSel = document.getElementById('drawerEditPlanSelect');
    if (drawerPlanSel) {
      for (const opt of drawerPlanSel.options) {
        const item = cfg.catalog[opt.value];
        if (item) {
          opt.textContent = `${item.label || opt.value} (S/ ${Number(item.price || 0).toFixed(2)})`;
        }
      }
    }
  }

  // Actualizar tarifa de migración por defecto en modal
  const migFee = document.getElementById('migFee');
  if (migFee) {
    const p = (cfg?.catalog?.HARDWARE_MIGRATION_FEE?.price !== undefined)
      ? cfg.catalog.HARDWARE_MIGRATION_FEE.price
      : (cfg?.migration_fee || 40.0);
    migFee.value = Number(p).toFixed(2);
  }

  // Si hay una credencial generada visible, re-renderizar el canvas con la nueva identidad legal
  const licCode = document.getElementById('licCode')?.value;
  if (licCode && typeof renderCredentialCanvas === 'function') {
    renderCredentialCanvas();
  }
}

function collectCatalogPayloadFromDom(baseCatalog) {
  const catalog = JSON.parse(JSON.stringify(baseCatalog || {}));
  document.querySelectorAll('.cfg-plan-price').forEach(inp => {
    const slug = inp.dataset.slug;
    if (catalog[slug]) {
      const updatesVal = Math.max(0, parseInt(document.querySelector(`.cfg-plan-updates[data-slug="${slug}"]`)?.value, 10) || 0);
      const descInput = document.querySelector(`.cfg-plan-desc[data-slug="${slug}"]`);
      const rawDesc = descInput ? descInput.value.trim() : (catalog[slug].description || '');
      catalog[slug] = {
        ...catalog[slug],
        price: Math.max(0, parseFloat(inp.value) || 0),
        days: Math.max(0, parseInt(document.querySelector(`.cfg-plan-days[data-slug="${slug}"]`)?.value, 10) || 0),
        ai_credits: Math.max(0, parseInt(document.querySelector(`.cfg-plan-ai[data-slug="${slug}"]`)?.value, 10) || 0),
        updates_window_months: updatesVal,
        updates_months: updatesVal,
        label: document.querySelector(`.cfg-plan-label[data-slug="${slug}"]`)?.value?.trim() || catalog[slug].label,
        description: rawDesc || catalog[slug].description || '',
      };
    }
  });

  const migFeeVal = Math.max(0, parseFloat(document.getElementById('cfgMigrationFee')?.value) || 40.0);
  const tableMigInput = document.querySelector('.cfg-plan-price[data-slug="HARDWARE_MIGRATION_FEE"]');
  const effectiveMigPrice = tableMigInput
    ? Math.max(0, parseFloat(document.getElementById('cfgMigrationFee')?.value ?? tableMigInput.value) || 0)
    : migFeeVal;

  catalog.HARDWARE_MIGRATION_FEE = {
    ...(catalog.HARDWARE_MIGRATION_FEE || {}),
    price: effectiveMigPrice,
    label: catalog.HARDWARE_MIGRATION_FEE?.label || 'Tarifa Técnica de Migración',
  };
  return { catalog, migFeeVal: effectiveMigPrice };
}

function collectTemplatesPayloadFromDom(baseTemplates) {
  const templates = JSON.parse(JSON.stringify(baseTemplates || {}));
  const curContentEl = document.getElementById('cfgTemplateContent');
  if (activeSettingsTemplateKey && curContentEl) {
    settingsDraftTemplates[activeSettingsTemplateKey] = curContentEl.value ?? '';
  }
  Object.entries(settingsDraftTemplates).forEach(([k, val]) => {
    const canon = typeof resolveConfigTemplateKeyFromWa === 'function'
      ? resolveConfigTemplateKeyFromWa(k)
      : k;
    templates[canon] = val;
  });
  return templates;
}

async function saveOwnerConfig(options = {}) {
  if (!ownerConfig) return false;
  const scope = (options && typeof options === 'object' && typeof options.scope === 'string')
    ? options.scope
    : 'all';

  try {
    const baseConfig = JSON.parse(JSON.stringify(ownerConfig));
    const newConfig = JSON.parse(JSON.stringify(baseConfig));

    // Preservar siempre rutas de búsqueda APK (Plan 22.5)
    const preservedApkLib = baseConfig?.system?.apk_library_dir;
    const preservedSearchDirs = baseConfig?.system?.apk_search_dirs;

    if (scope === 'all' || scope === 'pricing') {
      const { catalog, migFeeVal } = collectCatalogPayloadFromDom(baseConfig.catalog);
      newConfig.catalog = catalog;
      newConfig.migration_fee = migFeeVal;
    }

    if (scope === 'all' || scope === 'templates') {
      newConfig.templates = collectTemplatesPayloadFromDom(baseConfig.templates);
    }

    if (scope === 'all' || scope === 'payment') {
      const prevBrand = baseConfig?.legal_identity?.commercial_name || baseConfig?.legal_identity?.brand_name || 'MochilaLista';
      const prevAuthor = baseConfig?.legal_identity?.author_full_name || 'Julio Angello Vasquez Navarro';
      const prevPhone = baseConfig?.legal_identity?.support_phone || '+51 922 836 879';

      const nextAuthor = document.getElementById('cfgLegalOwner')?.value?.trim() || 'Julio Angello Vasquez Navarro';
      const nextBrand = document.getElementById('cfgBrandName')?.value?.trim() || 'MochilaLista';
      const nextPhone = document.getElementById('cfgSupportPhone')?.value?.trim() || '+51 922 836 879';

      newConfig.legal_identity = {
        ...(baseConfig.legal_identity || {}),
        author_full_name: nextAuthor,
        brand_name: nextBrand,
        commercial_name: nextBrand,
        support_phone: nextPhone,
        support_whatsapp_url: baseConfig?.legal_identity?.support_whatsapp_url || 'https://wa.me/51922836879',
        official_website: baseConfig?.legal_identity?.official_website || 'https://mochilalista.com',
        legal_framework: baseConfig?.legal_identity?.legal_framework || 'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI Perú',
        personal_data_law: baseConfig?.legal_identity?.personal_data_law || 'Ley N° 29733 (Ley de Protección de Datos Personales)',
      };

      newConfig.payment_methods = {
        yape_plin_phone: document.getElementById('cfgYapePhone')?.value?.trim() || '922836879',
        yape_plin_holder: document.getElementById('cfgYapeHolder')?.value?.trim() || 'Julio Angello Vasquez Navarro',
        bcp_account_holder: document.getElementById('cfgBcpHolder')?.value?.trim() || '',
        bcp_account_number: document.getElementById('cfgBcpAccount')?.value?.trim() || '',
        bcp_cci: document.getElementById('cfgBcpCci')?.value?.trim() || '',
        bbva_account_holder: document.getElementById('cfgBbvaHolder')?.value?.trim() || '',
        bbva_account_number: document.getElementById('cfgBbvaAccount')?.value?.trim() || '',
        bbva_cci: document.getElementById('cfgBbvaCci')?.value?.trim() || '',
      };

      if (newConfig.receipt_config) {
        const rc = { ...newConfig.receipt_config };
        if (!rc.issuer_name || rc.issuer_name === prevAuthor) rc.issuer_name = nextAuthor;
        if (!rc.commercial_name || rc.commercial_name === prevBrand) rc.commercial_name = nextBrand;
        if (!rc.issuer_phone || rc.issuer_phone === prevPhone) rc.issuer_phone = nextPhone;
        newConfig.receipt_config = rc;
      }
    }

    if (scope === 'all' || scope === 'preferences') {
      const defaultEnv = document.getElementById('cfgDefaultEnv')?.value || 'sandbox';
      const defaultTheme = document.getElementById('cfgDefaultTheme')?.value || 'dark';
      const tableDensity = document.getElementById('cfgTableDensity')?.value || 'comfortable';

      newConfig.system = {
        ...(baseConfig.system || {}),
        default_mode: defaultEnv,
        theme: defaultTheme,
        table_density: tableDensity,
        version: baseConfig?.system?.version || '1.0.0',
      };

      newConfig.preferences = {
        default_environment: defaultEnv,
        default_theme: defaultTheme,
        table_density: tableDensity,
      };
    }

    newConfig.system = { ...(newConfig.system || {}) };
    if (preservedApkLib && !newConfig.system.apk_library_dir) {
      newConfig.system.apk_library_dir = preservedApkLib;
    }
    if (Array.isArray(preservedSearchDirs) && (!Array.isArray(newConfig.system.apk_search_dirs) || newConfig.system.apk_search_dirs.length === 0)) {
      newConfig.system.apk_search_dirs = preservedSearchDirs;
    }

    const res = await fetch('/api/config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newConfig),
    });

    if (!res.ok) throw new Error('Error al guardar la configuración');

    ownerConfig = await res.json();
    const freshSnap = buildNormalizedSettingsSnapshotFromConfig(ownerConfig);

    if (scope === 'all') {
      populateSettingsForm(ownerConfig);
    } else {
      if (!savedSettingsSnapshot) savedSettingsSnapshot = freshSnap;
      savedSettingsSnapshot[scope] = freshSnap[scope];
      if (scope === 'templates') {
        syncDraftTemplatesFromConfig(ownerConfig);
      }
      updateSettingsDirtyState();
    }

    if ((scope === 'all' || scope === 'preferences') && ownerConfig?.system?.theme) {
      applyTheme(ownerConfig.system.theme);
    }

    applyConfigToUi(ownerConfig);
    renderTemplatePreview();

    const scopeOkMessages = {
      all: '¡Toda la configuración guardada! Snapshot automático creado en backups/.',
      pricing: 'Tarifario y bolsas IA guardados y propagados en el sistema.',
      templates: 'Plantillas de WhatsApp guardadas y sincronizadas con el Compositor CRM.',
      payment: 'Medios de pago e identidad legal guardados y propagados.',
      preferences: 'Preferencias del sistema guardadas en disco.',
    };
    showToast(scopeOkMessages[scope] || scopeOkMessages.all, 'success');
    return true;
  } catch (err) {
    showToast('Error al guardar: ' + err.message, 'error');
    return false;
  }
}

function renderConfigTemplate(templateKey, context = {}) {
  if (!ownerConfig || !ownerConfig.templates || !ownerConfig.templates[templateKey]) {
    return context.codigo ? `Código: ${context.codigo}` : 'MochilaLista';
  }

  let template = ownerConfig.templates[templateKey];
  const pm = ownerConfig.payment_methods || {};
  const li = ownerConfig.legal_identity || {};

  // Bloques bancarios con supresión inteligente
  const bcpAccount = (pm.bcp_account_number || '').trim();
  const bcpHolder = (pm.bcp_account_holder || '').trim();
  const bcpCci = (pm.bcp_cci || '').trim();
  let bcpBlock = '';
  if (bcpAccount) {
    const cciPart = bcpCci ? ` (CCI: ${bcpCci})` : '';
    const holderPart = bcpHolder ? ` - ${bcpHolder}` : '';
    bcpBlock = `\n🏦 BCP: ${bcpAccount}${cciPart}${holderPart}`;
  }

  const bbvaAccount = (pm.bbva_account_number || '').trim();
  const bbvaHolder = (pm.bbva_account_holder || '').trim();
  const bbvaCci = (pm.bbva_cci || '').trim();
  let bbvaBlock = '';
  if (bbvaAccount) {
    const cciPart = bbvaCci ? ` (CCI: ${bbvaCci})` : '';
    const holderPart = bbvaHolder ? ` - ${bbvaHolder}` : '';
    bbvaBlock = `\n🏦 BBVA: ${bbvaAccount}${cciPart}${holderPart}`;
  }

  const vars = {
    '{autor}': li.author_full_name || 'Julio Angello Vasquez Navarro',
    '{commercial_name}': li.commercial_name || li.brand_name || 'MochilaLista',
    '{support_phone}': li.support_phone || '+51 922 836 879',
    '{website}': li.official_website || 'https://mochilalista.com',
    '{official_website}': li.official_website || 'https://mochilalista.com',
    '{legal_framework}': li.legal_framework || 'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI Perú',
    '{personal_data_law}': li.personal_data_law || 'Ley N° 29733 (Ley de Protección de Datos Personales)',
    '{yape_phone}': pm.yape_plin_phone || '922836879',
    '{yape_titular}': pm.yape_plin_holder || 'Julio Angello Vasquez Navarro',
    '{bloque_banco_bcp}': bcpBlock,
    '{bloque_banco_bbva}': bbvaBlock,
  };

  for (const [k, v] of Object.entries(context)) {
    const cleanK = k.startsWith('{') && k.endsWith('}') ? k : `{${k}}`;
    vars[cleanK] = v !== undefined && v !== null ? String(v) : '';
  }

  for (const [pattern, replacement] of Object.entries(vars)) {
    template = template.split(pattern).join(replacement);
  }

  return template;
}
