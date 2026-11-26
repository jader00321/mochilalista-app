// =================== 4. RELEASE MANAGER & MATRIZ INTELIGENTE (PLAN 19 / 22) ===================
let globalReleaseMatrix = [];
let currentMatrixFilter = 'ALL';
let currentMatrixSearch = '';
let lastInspectedCreateData = null;
let editModalLocalBuildsCache = [];
let activeCreateApkSource = null; // null | 'manual' | 'autodetect'
let selectedLocalBuildPath = null;
let selectedLocalBuildIndex = -1;
let pendingManualFileMeta = null;
let createApkSearchDirs = [];
let localBuildsFilterState = { abi: 'ALL', query: '', limit: 6 };
let localBuildsFilterTimer = null;

/**
 * Normaliza tamaños APK para evitar valores sin sufijo o "MB MB" duplicado
 */
function formatApkSizeMb(raw) {
  if (raw === null || raw === undefined) return '-';
  const s = String(raw).trim();
  if (!s || s === '-' || s === 'null' || s === 'undefined') return '-';
  const cleaned = s.replace(/\s*MB\s*$/i, '').trim();
  if (!cleaned) return '-';
  const num = Number(cleaned);
  if (!Number.isNaN(num) && Number.isFinite(num)) {
    return `${num.toFixed(2)} MB`;
  }
  return /\bMB$/i.test(s) ? s.replace(/\s*MB$/i, ' MB') : `${s} MB`;
}

/**
 * Infiere tipo de lanzamiento sugerido desde SemVer:
 * patch > 0 -> HOTFIX, patch == 0 -> FEATURE_RELEASE
 */
function inferReleaseTypeFromSemVer(versionName) {
  if (!versionName) return 'FEATURE_RELEASE';
  const clean = String(versionName).trim().replace(/^[vV]/, '').split('+')[0].split('-')[0];
  const segs = clean.split('.');
  const patch = segs.length > 2 ? (parseInt(segs[2], 10) || 0) : 0;
  return patch > 0 ? 'HOTFIX' : 'FEATURE_RELEASE';
}

/**
 * Renderiza el badge de firma criptográfica de 3 estados honestos
 */
function renderSignatureStatusBadge(sigStatus, sigVerified, labelOfficial = 'Oficial RSA-4096') {
  if (sigStatus === 'OFFICIAL_RELEASE' || sigVerified === true) {
    return `<span class="badge badge-official-sig" title="Firma Oficial Verificada (RSA-4096 — Julio Angello Vasquez Navarro)"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg> ${escapeHtml(labelOfficial)}</span>`;
  }
  if (sigStatus === 'UNOFFICIAL_SIGNATURE' || (sigVerified === false && sigStatus !== 'UNVERIFIED')) {
    return '<span class="badge badge-unofficial-sig" title="Firma No Oficial / Debug Keystore"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg> No Oficial</span>';
  }
  return '<span class="badge badge-unverified-sig" title="Firma no verificada en este entorno"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg> Sin Verificar</span>';
}

/**
 * Carga el catálogo de versiones publicadas
 */
async function loadReleases() {
  try {
    const res = await fetch('/api/releases', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar versiones');
    globalReleases = await res.json();

    const tbody = document.getElementById('releasesTableBody');
    if (!tbody) return;
    tbody.innerHTML = '';

    if (globalReleases.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No hay versiones registradas en este entorno.</td></tr>';
      if (globalClients && globalClients.length > 0) {
        updateFilterCounts();
        renderClientsTable();
      }
      return;
    }

    globalReleases.forEach(r => {
      const tr = document.createElement('tr');
      const badge = r.type === 'HOTFIX'
        ? '<span class="badge badge-green">HOTFIX (Parche)</span>'
        : '<span class="badge badge-purple">FEATURE RELEASE</span>';

      const shortSha = r.apk_sha256 ? `${r.apk_sha256.substring(0, 12)}...` : '-';
      const sizeInfo = formatApkSizeMb(r.file_size_mb);

      const verNorm = String(r.version_name || '').trim().replace(/^[vV]/, '');
      const adoptionCount = (globalClients || []).filter(c => {
        const inst = String(c.installed_version || '').trim().replace(/^[vV]/, '');
        return inst && inst === verNorm;
      }).length;
      const adoptionLabel = adoptionCount === 1 ? '1 cliente' : `${adoptionCount} clientes`;

      // Badges de variantes
      const variantsBadges = [];
      if (r.universal_apk || r.abi_variant === 'UNIVERSAL' || (!r.universal_apk && !r.arm64_apk)) {
        variantsBadges.push('<span class="badge badge-universal" title="Compatible con todos los procesadores">Universal</span>');
      }
      if (r.arm64_apk || r.abi_variant === 'ARM64') {
        variantsBadges.push('<span class="badge badge-arm64" title="Optimizado para 64 bits">ARM64</span>');
      }

      // Badge de firma oficial de 3 estados honestos
      const sigBadge = renderSignatureStatusBadge(r.signature_status, r.signature_verified, 'Oficial');

      tr.innerHTML = `
        <td>
          <div class="release-version-cell">
            <strong>v${escapeHtml(r.version_name)}</strong>
            <span class="release-adoption-pill ${adoptionCount > 0 ? 'has-clients' : ''}" title="${adoptionCount} cliente(s) con esta versión instalada">${adoptionLabel}</span>
          </div>
        </td>
        <td>${r.version_code || '-'}</td>
        <td>Esquema v${r.db_schema_version || 36}</td>
        <td>${badge}</td>
        <td style="white-space:nowrap;">${r.release_date ? r.release_date.substring(0, 10) : '-'}</td>
        <td>
          <div style="display:flex; gap:0.3rem; flex-wrap:wrap; align-items:center;">
            ${variantsBadges.join(' ')}
            ${sigBadge}
          </div>
        </td>
        <td>
          <div style="font-size:0.75rem; color:var(--text-secondary); white-space:nowrap;">${escapeHtml(sizeInfo)}</div>
          <code style="font-family:var(--font-mono); font-size:0.72rem;" title="${escapeHtml(r.apk_sha256 || '')}">${shortSha}</code>
        </td>
        <td>
          <div class="release-actions-row" style="display:flex; gap:0.25rem; flex-wrap:nowrap; align-items:center; white-space:nowrap;">
            ${(() => {
              const hasUniversal = !!r.universal_apk || (!r.universal_apk && !r.arm64_apk);
              const hasArm64 = !!r.arm64_apk;
              if (hasUniversal && hasArm64) {
                return `
                  <div class="variant-btn-group" title="Descargar APK directo del servidor">
                    <a href="/api/releases/download/${encodeURIComponent(r.version_name)}?variant=universal" class="btn btn-outline btn-xs" title="Descargar APK Universal">Univ</a>
                    <a href="/api/releases/download/${encodeURIComponent(r.version_name)}?variant=arm64" class="btn btn-outline btn-xs" title="Descargar APK ARM64 Ligero">ARM64</a>
                  </div>
                  <div class="variant-btn-group" title="Copiar archivo APK al portapapeles">
                    <button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(r.version_name)}', 'universal')" title="Copiar APK Universal al portapapeles">Copiar Univ</button>
                    <button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(r.version_name)}', 'arm64')" title="Copiar APK ARM64 Ligero al portapapeles">ARM64</button>
                  </div>
                `;
              } else if (hasArm64) {
                return `
                  <a href="/api/releases/download/${encodeURIComponent(r.version_name)}?variant=arm64" class="btn btn-outline btn-xs" title="Descargar APK ARM64 Ligero">
                    <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                    APK ARM64
                  </a>
                  <button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(r.version_name)}', 'arm64')" title="Copiar APK ARM64 Ligero al portapapeles">
                    <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                    Copiar ARM64
                  </button>
                `;
              } else {
                return `
                  <a href="/api/releases/download/${encodeURIComponent(r.version_name)}?variant=universal" class="btn btn-outline btn-xs" title="Descargar APK directo del servidor">
                    <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                    APK
                  </a>
                  <button type="button" class="btn btn-outline btn-xs" onclick="copyReleaseApkToClipboard('${escapeHtml(r.version_name)}', 'universal')" title="Copiar archivo APK binario al portapapeles para pegar en WhatsApp">
                    <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                    Copiar
                  </button>
                `;
              }
            })()}
            <button type="button" class="btn btn-outline btn-xs" onclick="revealReleaseInExplorer('${escapeHtml(r.version_name)}')" title="Mostrar en Carpeta de Windows">
              <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
              Carpeta
            </button>
            <button type="button" class="btn btn-outline btn-xs" onclick="verifyReleaseIntegrity('${escapeHtml(r.version_name)}')" title="Verificar archivo en disco y firma criptográfica RSA-4096">
              <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
              Verificar
            </button>
            <button type="button" class="btn btn-outline btn-xs" onclick="openEditReleaseModal('${escapeHtml(r.version_name)}')" title="Editar Versión y Changelog">
              <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
            </button>
            <button type="button" class="btn btn-outline btn-xs" style="color:var(--danger); border-color:var(--danger);" onclick="deleteRelease('${escapeHtml(r.version_name)}')" title="Eliminar Versión">
              <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
            </button>
          </div>
        </td>
      `;
      tbody.appendChild(tr);
    });

    if (globalClients && globalClients.length > 0) {
      updateFilterCounts();
      renderClientsTable();
    }
    if (typeof applyTableDensity === 'function') {
      applyTableDensity(ownerConfig?.system?.table_density);
    }
  } catch (e) {
    console.error('Error al cargar releases:', e);
  }
}

const editModalLocalBuildsByVariant = { universal: [], arm64: [] };

/**
 * Valida estrictamente que la arquitectura ABI detectada del APK coincida con la ranura destino
 */
function validateApkAbiForVariantSlot(detectedAbi, targetSlot) {
  const normalizedDetected = String(detectedAbi || '').trim().toUpperCase();
  const normalizedTarget = String(targetSlot || '').trim().toUpperCase();
  const isArm64Slot = normalizedTarget === 'ARM64';
  const expectedAbi = isArm64Slot ? 'ARM64' : 'UNIVERSAL';

  if (!normalizedDetected) {
    return {
      ok: false,
      expectedAbi,
      detectedAbi: 'DESCONOCIDA',
      error: `No se pudo confirmar la arquitectura ABI del APK para la ranura ${expectedAbi}.`,
    };
  }

  if (isArm64Slot && normalizedDetected !== 'ARM64') {
    return {
      ok: false,
      expectedAbi: 'ARM64',
      detectedAbi: normalizedDetected,
      error: `Arquitectura incompatible: el archivo es ${normalizedDetected}, pero esta ranura exige un APK ARM64 Ligero (~30 MB). Selecciona un build compilado con compilar_apk_arm64.bat.`,
    };
  }

  if (!isArm64Slot && normalizedDetected === 'ARM64') {
    return {
      ok: false,
      expectedAbi: 'UNIVERSAL',
      detectedAbi: normalizedDetected,
      error: `Arquitectura incompatible: el archivo es ARM64 Ligero, pero esta ranura exige un APK Universal (~110 MB). Adjúntalo en ARM64 Ligero o usa compilar_apk_comercial.bat.`,
    };
  }

  return {
    ok: true,
    expectedAbi,
    detectedAbi: normalizedDetected,
    error: null,
  };
}

function getEditVariantData(rel, variantKey) {
  if (!rel) return null;
  if (variantKey === 'arm64') {
    return rel.arm64_apk || (rel.apk_file_path && rel.abi_variant === 'ARM64' ? {
      file_path: rel.apk_file_path,
      file_size_mb: rel.file_size_mb,
      sha256: rel.apk_sha256,
      signature_status: rel.signature_status,
      signature_verified: rel.signature_verified,
      file_exists: rel.file_exists,
    } : null);
  }
  return rel.universal_apk || (rel.apk_file_path && rel.abi_variant !== 'ARM64' ? {
    file_path: rel.apk_file_path,
    file_size_mb: rel.file_size_mb,
    sha256: rel.apk_sha256,
    signature_status: rel.signature_status,
    signature_verified: rel.signature_verified,
    file_exists: rel.file_exists,
  } : null);
}

function canUnlinkEditVariantSlot(rel, variantKey) {
  if (!rel) return { allowed: false, reason: 'Versión no cargada.' };
  const slotData = getEditVariantData(rel, variantKey);
  if (!slotData || !slotData.file_path) {
    return { allowed: false, reason: 'Esta variante no tiene ningún archivo vinculado.' };
  }
  if (variantKey === 'arm64') {
    return { allowed: true, reason: null };
  }
  const arm64Data = getEditVariantData(rel, 'arm64');
  const hasHealthyArm64 = Boolean(arm64Data && arm64Data.file_path && arm64Data.file_exists !== false);
  const isUniversalMissing = slotData.file_exists === false;
  if (hasHealthyArm64 || isUniversalMissing) {
    return { allowed: true, reason: null };
  }
  return {
    allowed: false,
    reason: 'No puedes desvincular Universal mientras sea el único APK válido en disco (adjunta primero ARM64 Ligero o reemplaza Universal).',
  };
}

/**
 * Sincroniza una versión actualizada hacia globalReleases, #modalEditRelease, Catálogo, Matriz y #modalWaComposer
 */
async function syncReleaseAcrossUiAndComposer(versionName, updatedRel, options = {}) {
  if (updatedRel) {
    const idx = globalReleases.findIndex(r => r.version_name === versionName);
    if (idx !== -1) {
      globalReleases[idx] = updatedRel;
    } else {
      globalReleases.unshift(updatedRel);
    }

    const editModalOpen = document.getElementById('modalEditRelease')?.classList.contains('open');
    const currentEditVer = document.getElementById('editRelVersionName')?.value;
    if ((editModalOpen || options.forceRenderEditModal) && currentEditVer === versionName) {
      const vcInput = document.getElementById('editRelVersionCode');
      const dbInput = document.getElementById('editRelDbSchema');
      if (vcInput && updatedRel.version_code) vcInput.value = updatedRel.version_code;
      if (dbInput && updatedRel.db_schema_version) dbInput.value = updatedRel.db_schema_version;
      renderEditReleaseVariants(updatedRel);
    }
  }

  await loadReleases();
  await loadReleaseMatrix();

  if (updatedRel) {
    const idxAfter = globalReleases.findIndex(r => r.version_name === versionName);
    if (idxAfter !== -1) globalReleases[idxAfter] = updatedRel;
    if (typeof currentDispatchRelease !== 'undefined' && currentDispatchRelease?.version_name === versionName) {
      currentDispatchRelease = updatedRel;
      const waOpen = document.getElementById('modalWaComposer')?.classList.contains('open');
      if ((waOpen && typeof isApkDispatchMode !== 'undefined' && isApkDispatchMode) || options.forceSyncWaComposer) {
        syncWaApkDispatchPanel(updatedRel, { preserveCopyHint: true });
      }
    }
  }
}

async function commitReleaseVariantUpdate(versionName, variantKey, inspectedData, filePath, originText = '') {
  const normalizedSize = formatApkSizeMb(inspectedData.size_mb);
  const variantData = {
    file_path: filePath,
    file_size_mb: normalizedSize,
    sha256: inspectedData.sha256,
    signature_status: inspectedData.signature_status,
    signature_verified: inspectedData.signature_verified,
    signature_detail: inspectedData.signature_detail,
    signer_sha256: inspectedData.signer_sha256,
    signer_dn: inspectedData.signer_dn,
    file_exists: true,
  };

  const updates = {};
  if (variantKey === 'arm64') {
    updates.arm64_apk = variantData;
  } else {
    updates.universal_apk = variantData;
    updates.apk_file_path = filePath;
    updates.file_size_mb = normalizedSize;
    updates.apk_sha256 = inspectedData.sha256;
    updates.signature_status = inspectedData.signature_status;
    updates.signature_verified = inspectedData.signature_verified;
    updates.signature_detail = inspectedData.signature_detail;
    updates.signer_sha256 = inspectedData.signer_sha256;
    updates.signer_dn = inspectedData.signer_dn;
  }

  const putRes = await fetch(`/api/releases/${encodeURIComponent(versionName)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(updates),
  });
  const updatedRel = await putRes.json().catch(() => ({}));
  if (!putRes.ok) {
    throw new Error(updatedRel.error || 'Error al vincular variante en la base de datos');
  }
  updatedRel.file_exists = true;

  await syncReleaseAcrossUiAndComposer(versionName, updatedRel);
  const suffix = originText ? ` ${originText}` : '';
  showToast(`Variante ${variantKey.toUpperCase()} vinculada${suffix} (${normalizedSize}).`, 'success');
  return updatedRel;
}

/**
 * Re-verifica en disco duro el archivo físico y firma RSA-4096 de una versión
 */
async function verifyReleaseIntegrity(versionName, fromEditModal = false) {
  if (!versionName) return;
  try {
    showToast(`Auditando archivo y firma de v${versionName}...`, 'info', 2500);
    const res = await fetch(`/api/releases/${encodeURIComponent(versionName)}/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      throw new Error(data.error || 'No se pudo verificar la versión');
    }

    const updatedRel = data.release;
    await syncReleaseAcrossUiAndComposer(versionName, updatedRel, {
      forceRenderEditModal: Boolean(fromEditModal),
    });

    if (!data.file_exists) {
      showToast(`No se encontró ningún APK físico en disco para v${versionName}.`, 'warning');
    } else if (updatedRel?.signature_status === 'OFFICIAL_RELEASE' || updatedRel?.signature_verified === true) {
      showToast(`v${versionName} verificada: Firma Oficial RSA-4096 y archivo en disco OK.`, 'success');
    } else if (updatedRel?.signature_status === 'UNOFFICIAL_SIGNATURE' || updatedRel?.signature_verified === false) {
      showToast(`v${versionName} auditada: se detectó firma NO OFICIAL.`, 'warning');
    } else {
      showToast(`v${versionName} auditada en disco (${updatedRel?.signature_detail || 'Sin Verificar'}).`, 'info');
    }
  } catch (e) {
    showToast('Error al verificar versión: ' + e.message, 'error');
  }
}
