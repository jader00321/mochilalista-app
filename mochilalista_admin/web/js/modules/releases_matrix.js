function triggerVariantUpload(variant, versionName) {
  currentUploadVariantVersion = versionName;
  currentUploadVariantType = variant;
  const inputId = variant === 'arm64' ? 'editRelArm64Input' : 'editRelUniversalInput';
  const input = document.getElementById(inputId);
  if (input) {
    input.value = '';
    input.click();
  }
}

async function handleVariantFileSelected(file, variant, versionName) {
  if (!file || !versionName) return;
  if (!String(file.name || '').toLowerCase().endsWith('.apk')) {
    showToast('El archivo seleccionado no es un archivo .APK válido.', 'error');
    return;
  }
  showToast(`Analizando variante ${variant.toUpperCase()} para v${versionName}...`, 'info');
  try {
    const res = await fetch(`/api/releases/upload-apk?filename=${encodeURIComponent(file.name)}`, {
      method: 'POST',
      body: file,
    });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      throw new Error(data.error || 'Error al inspeccionar archivo subido');
    }

    const abiCheck = validateApkAbiForVariantSlot(data.abi_variant, variant);
    if (!abiCheck.ok) {
      showToast(abiCheck.error, 'error');
      return;
    }

    await commitReleaseVariantUpdate(
      versionName,
      variant,
      data,
      data.file_path,
      'por subida directa'
    );
  } catch (err) {
    showToast('Error al actualizar variante: ' + err.message, 'error');
  }
}

/**
 * Abre el modal de edición de versión
 */
function openEditReleaseModal(versionName) {
  const rel = globalReleases.find(r => r.version_name === versionName);
  if (!rel) return;

  document.getElementById('editRelVersionName').value = rel.version_name;
  document.getElementById('editRelVersionDisplay').value = `v${rel.version_name}`;
  document.getElementById('editRelVersionCode').value = rel.version_code || 82;
  document.getElementById('editRelDbSchema').value = rel.db_schema_version || 36;
  document.getElementById('editRelMinRequiredVersion').value = rel.min_required_version || '9.0.0';
  document.getElementById('editRelType').value = rel.type || 'FEATURE_RELEASE';
  document.getElementById('editRelDownloadUrl').value = rel.apk_download_url || '';
  document.getElementById('editRelChangelog').value = rel.changelog || '';
  document.getElementById('editRelInternalNotes').value = rel.internal_notes || '';

  if (typeof resetExpandableTextarea === 'function') {
    resetExpandableTextarea('editRelChangelog');
    resetExpandableTextarea('editRelInternalNotes');
  }
  const editDirsPanel = document.getElementById('editSearchDirsPanel');
  if (editDirsPanel) editDirsPanel.style.display = 'none';
  const newEditDirInp = document.getElementById('inputEditNewApkSearchDir');
  if (newEditDirInp) newEditDirInp.value = '';

  // Actualizar tarjeta explicativa reactiva
  updateReleaseTypeInfo('editRelType', 'editRelTypeInfoText');

  // Variantes físicas en disco con soporte de reemplazo/subida
  renderEditReleaseVariants(rel);

  openModal('modalEditRelease');
}

/**
 * Elimina una versión
 */
function deleteRelease(versionName) {
  showConfirmModal(
    'Eliminar Versión del Catálogo',
    `¿Estás seguro de eliminar permanentemente la versión v${versionName}? Si el archivo .apk existe en disco, también se eliminará.`,
    async () => {
      try {
        const res = await fetch(`/api/releases/${encodeURIComponent(versionName)}`, {
          method: 'DELETE',
        });
        if (!res.ok) throw new Error('Error al eliminar versión');
        showToast(`Versión v${versionName} eliminada.`, 'success');
        await loadReleases();
        await loadReleaseMatrix();
        await loadDashboard();
      } catch (e) {
        showToast('Error: ' + e.message, 'error');
      }
    },
    true
  );
}

/**
 * Actualiza la información explicativa de tipo de release
 */
function updateReleaseTypeInfo(selectId, textId) {
  const sel = document.getElementById(selectId);
  const textEl = document.getElementById(textId);
  if (!sel || !textEl) return;

  if (sel.value === 'HOTFIX') {
    textEl.textContent = 'Parche de corrección o estabilidad. Derecho gratuito vitalicio para todos los clientes con la app instalada, incluidos Perpetuos sin pase vigente.';
  } else {
    textEl.textContent = 'Nuevas funciones comerciales. Gratis para suscripciones activas, Trial y Perpetuos con pase de updates vigente; requiere Pase Anual (S/ 150.00) o cortesía para Perpetuos con pase vencido.';
  }
}

/**
 * Carga la matriz de distribución desde el backend
 */
async function loadReleaseMatrix() {
  try {
    const res = await fetch('/api/releases/matrix', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar matriz');
    globalReleaseMatrix = await res.json();
    renderReleaseMatrix();
  } catch (e) {
    console.error('Error al cargar matriz:', e);
  }
}

/**
 * Establece el filtro activo de la matriz
 */
function setMatrixFilter(filterType) {
  currentMatrixFilter = filterType;
  const chips = document.querySelectorAll('#matrixFilterChips .rel-chip');
  chips.forEach(c => {
    if (c.getAttribute('data-filter') === filterType) {
      c.classList.add('active');
    } else {
      c.classList.remove('active');
    }
  });
  renderReleaseMatrix();
}

/**
 * Renderiza la matriz de distribución y la barra de progreso de despliegue
 */
function renderReleaseMatrix() {
  const tbody = document.getElementById('matrixTableBody');
  if (!tbody) return;
  tbody.innerHTML = '';

  if (!globalReleaseMatrix || globalReleaseMatrix.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Sin clientes para evaluar matriz.</td></tr>';
    updateRolloutProgress(0, 0, 0, 0);
    return;
  }

  // Identificar última versión lanzada
  const latestRelease = globalReleases?.[0];
  const latestVersion = latestRelease?.version_name || (globalReleaseMatrix[0]?.latest_version || '9.38.0');

  // Calcular métricas de despliegue global (excluyendo prospectos sin app instalada)
  let totalWithApp = 0;
  let countUpToDate = 0;
  let countSent = 0;
  let countOutdated = 0;

  globalReleaseMatrix.forEach(row => {
    const isProspect = (row.situation === 'PROSPECTO') || (row.license_type === 'PROSPECTO') || (row.update_status === 'PROSPECT');
    if (isProspect) return;

    totalWithApp++;
    const status = row.update_status || (row.is_up_to_date ? 'UP_TO_DATE' : 'OUTDATED');
    if (status === 'UP_TO_DATE' || status === 'AHEAD') {
      countUpToDate++;
    } else if (status === 'SENT') {
      countSent++;
    } else {
      countOutdated++;
    }
  });

  updateRolloutProgress(totalWithApp, countUpToDate, countSent, countOutdated);

  // Filtrado de filas
  const term = currentMatrixSearch.trim().toLowerCase();
  const filtered = globalReleaseMatrix.filter(row => {
    // Filtro por texto
    if (term) {
      const matchText = (row.business_name || '').toLowerCase().includes(term) ||
                        (row.owner_name || '').toLowerCase().includes(term) ||
                        (row.phone || '').includes(term) ||
                        (row.installed_version || '').includes(term);
      if (!matchText) return false;
    }

    const isProspect = (row.situation === 'PROSPECTO') || (row.license_type === 'PROSPECTO') || (row.update_status === 'PROSPECT');
    const status = row.update_status || (row.is_up_to_date ? 'UP_TO_DATE' : 'OUTDATED');

    if (currentMatrixFilter === 'ALL') {
      return true;
    } else if (currentMatrixFilter === 'OUTDATED') {
      return !isProspect && (status === 'OUTDATED');
    } else if (currentMatrixFilter === 'REQUIRES_PASS') {
      return !isProspect && !row.is_eligible_for_free && (status === 'OUTDATED');
    } else if (currentMatrixFilter === 'SENT') {
      return !isProspect && (status === 'SENT');
    } else if (currentMatrixFilter === 'UP_TO_DATE') {
      return !isProspect && (status === 'UP_TO_DATE' || status === 'AHEAD');
    }
    return true;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No se encontraron clientes con el filtro aplicado.</td></tr>';
    return;
  }

  filtered.forEach(row => {
    const tr = document.createElement('tr');
    const isProspect = (row.situation === 'PROSPECTO') || (row.license_type === 'PROSPECTO') || (row.update_status === 'PROSPECT');
    const status = row.update_status || (row.is_up_to_date ? 'UP_TO_DATE' : 'OUTDATED');
    const cmp = compareSemVer(row.installed_version, row.latest_version);

    // Estado & Derecho Badge
    let statusBadge = '';
    if (isProspect) {
      statusBadge = '<span class="badge" style="background:rgba(148,163,184,0.15); color:var(--text-muted);">Prospecto (Sin App)</span>';
    } else if (status === 'AHEAD' || cmp > 0) {
      statusBadge = `<span class="badge badge-ahead" title="Cliente cuenta con versión superior de prueba o desarrollo">Versión superior (v${escapeHtml(row.installed_version)})</span>`;
    } else if (status === 'UP_TO_DATE' || row.is_up_to_date) {
      statusBadge = '<span class="badge badge-green"><svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> Al Día</span>';
    } else if (status === 'SENT') {
      let sentDate = '';
      if (row.last_apk_sent_at) {
        const isoDate = String(row.last_apk_sent_at).substring(0, 10).split('-');
        sentDate = isoDate.length === 3 ? `${isoDate[2]}/${isoDate[1]}` : '';
      }
      statusBadge = `<span class="badge badge-sent" title="APK enviado: pendiente de confirmación en cliente">Enviado ${sentDate}</span>`;
    } else {
      statusBadge = row.is_eligible_for_free
        ? '<span class="badge badge-yellow">Desactualizado (Derecho Gratuito)</span>'
        : '<span class="badge" style="background:rgba(239,68,68,0.15); color:#ef4444; border:1px solid rgba(239,68,68,0.3);">Requiere Pase</span>';
    }

    const cleanPhone = (row.phone || '').replace(/[^0-9]/g, '');
    const phoneDisplay = formatPeruvianPhoneDisplay(row.phone);

    let actionButtons = '<span style="color:var(--text-muted); font-size:0.8rem;">Sin acción requerida</span>';

    if (!isProspect && (status === 'OUTDATED' || status === 'SENT')) {
      if (row.is_eligible_for_free) {
        const sendLabel = status === 'SENT' ? 'Reenviar APK' : 'Enviar APK';
        actionButtons = `
          <button type="button" class="btn btn-wa btn-sm" onclick="openApkDispatchComposer('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}', 'eligible')" title="${sendLabel} por WhatsApp con copia de binario APK al portapapeles">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 2L11 13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
            ${sendLabel}
          </button>
          <button type="button" class="btn btn-outline btn-sm" onclick="markClientUpdated('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}')" title="Marcar como actualizado a v${escapeHtml(row.latest_version)}">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="20 6 9 17 4 12"/></svg>
            Marcar Actualizado
          </button>
        `;
      } else {
        actionButtons = `
          <button type="button" class="btn btn-outline btn-sm" onclick="openApkDispatchComposer('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}', 'quote')" title="Cotizar Pase Anual de Actualizaciones por WhatsApp">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
            Cotizar Pase
          </button>
          <button type="button" class="btn btn-primary btn-sm" onclick="jumpToIssuePass('${escapeHtml(row.client_id)}')" title="Ir a Emitir Pase Anual">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
            Emitir Pase
          </button>
          <button type="button" class="btn btn-outline btn-sm" style="opacity:0.85;" onclick="authorizeCourtesyUpdate('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}', '${escapeHtml(row.business_name)}', '${cleanPhone}', '${escapeHtml(row.owner_name)}')" title="Autorizar Envío de Cortesía Excepcional">
            <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="20 12 20 22 4 22 4 12"/><rect x="2" y="7" width="20" height="5"/><line x1="12" y1="22" x2="12" y2="7"/></svg>
            Cortesía
          </button>
        `;
      }
    } else if (!isProspect && (status === 'UP_TO_DATE' || status === 'AHEAD' || row.is_up_to_date || cmp >= 0)) {
      actionButtons = `
        <button type="button" class="btn btn-outline btn-sm" onclick="openApkDispatchComposer('${escapeHtml(row.client_id)}', '${escapeHtml(row.latest_version)}', 'resend')" title="Reenviar APK o elegir versión para este cliente">
          <svg class="btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 2L11 13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
          Reenviar / Elegir APK
        </button>
      `;
    }

    tr.innerHTML = `
      <td>
        <strong>${escapeHtml(row.business_name)}</strong>
        <div style="font-size:0.75rem; color:var(--text-muted);">${escapeHtml(row.owner_name || '')}</div>
      </td>
      <td>${escapeHtml(phoneDisplay)}</td>
      <td>
        <div class="matrix-installed-ver-cell">
          <span>v${escapeHtml(row.installed_version)}</span>
          ${!isProspect ? `
            <button type="button" class="btn-micro-edit-ver" data-fix-client-id="${escapeHtml(row.client_id)}" title="Corregir versión instalada">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
            </button>
          ` : ''}
        </div>
      </td>
      <td>v${escapeHtml(row.latest_version)}</td>
      <td>${escapeHtml(row.release_type || 'FEATURE_RELEASE')}</td>
      <td>${statusBadge}</td>
      <td>
        <div style="display:flex; gap:0.4rem; flex-wrap:wrap; align-items:center;">
          ${actionButtons}
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  });
  if (typeof applyTableDensity === 'function') {
    applyTableDensity(ownerConfig?.system?.table_density);
  }
}

/**
 * Actualiza los contadores y barra segmentada de despliegue
 */
function updateRolloutProgress(total, upToDate, sent, pending) {
  const totalEl = document.getElementById('rolloutTotal');
  const upToDateEl = document.getElementById('rolloutUpToDate');
  const sentEl = document.getElementById('rolloutSent');
  const pendingEl = document.getElementById('rolloutPending');

  const segUp = document.getElementById('segmentUpToDate');
  const segSent = document.getElementById('segmentSent');
  const segPen = document.getElementById('segmentPending');

  if (totalEl) totalEl.textContent = total;

  if (total === 0) {
    if (upToDateEl) upToDateEl.textContent = '0 (0%)';
    if (sentEl) sentEl.textContent = '0 (0%)';
    if (pendingEl) pendingEl.textContent = '0 (0%)';
    if (segUp) segUp.style.width = '0%';
    if (segSent) segSent.style.width = '0%';
    if (segPen) segPen.style.width = '100%';
    return;
  }

  const pctUp = Math.round((upToDate / total) * 100);
  const pctSent = Math.round((sent / total) * 100);
  const pctPen = Math.max(0, 100 - pctUp - pctSent);

  if (upToDateEl) upToDateEl.textContent = `${upToDate} (${pctUp}%)`;
  if (sentEl) sentEl.textContent = `${sent} (${pctSent}%)`;
  if (pendingEl) pendingEl.textContent = `${pending} (${pctPen}%)`;

  if (segUp) segUp.style.width = `${pctUp}%`;
  if (segSent) segSent.style.width = `${pctSent}%`;
  if (segPen) segPen.style.width = `${pctPen}%`;
}

/**
 * Registra despacho comercial de APK en backend
 */
async function recordApkSent(clientId, version, variant = 'universal') {
  try {
    await fetch('/api/releases/mark-sent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: clientId, version: version, variant: variant })
    });
    await loadReleaseMatrix();
  } catch (_) {}
}

function jumpToIssuePass(clientId) {
  selectClientForLicense(clientId);
  const planSelect = document.getElementById('licPlanSelect');
  if (planSelect) {
    planSelect.value = 'PASE_ACTUALIZACION_ANUAL';
    updatePlanImpactAndProjection();
  }
}

function authorizeCourtesyUpdate(clientId, latestVersion, businessName, cleanPhone, ownerName) {
  showConfirmModal(
    'Autorizar Envío de Cortesía',
    `¿Deseas autorizar excepcionalmente el envío gratuito de la versión v${latestVersion} a "${businessName}" sin requerir el pago del pase anual?`,
    async () => {
      await markClientUpdated(clientId, latestVersion);
      showToast(`Cortesía autorizada para ${businessName}. Abriendo compositor de despacho...`, 'success');
      openApkDispatchComposer(clientId, latestVersion, 'courtesy');
    }
  );
}
