/**
 * Renderizado de Auditoría Especializada para Fichas Comerciales Declarativas MLC1-...
 */
function renderInspectCommercialConfig(data, rawToken, options = {}) {
  const container = document.getElementById('inspectResultContainer');
  const badge = document.getElementById('inspectStatusBadge');
  const mlc1AuditCard = document.getElementById('inspectMlc1AuditCard');
  const syncAuditCard = document.getElementById('inspectSyncAuditCard');
  const licenseClaimsWrapper = document.getElementById('inspectLicenseClaimsWrapper');
  const matchBox = document.getElementById('inspectMatchingClientBox');

  if (container) container.style.display = 'block';
  if (licenseClaimsWrapper) licenseClaimsWrapper.style.display = 'none';
  if (syncAuditCard) syncAuditCard.style.display = 'none';
  if (matchBox) matchBox.style.display = 'none';
  if (mlc1AuditCard) mlc1AuditCard.style.display = 'block';

  const isValid = Boolean(data.valid || data.isValid);
  const cmp = data.current_config_comparison || {};
  const revStatus = cmp.revision_status || (isValid ? 'CURRENT' : 'INVALID');
  const tokenRev = data.revision ?? cmp.token_revision ?? data.diagnostic_summary?.revision ?? '-';
  const localRev = cmp.local_revision ?? 0;

  // 1. Sello Criptográfico Principal
  if (badge) {
    if (isValid) {
      badge.style.background = 'rgba(16, 185, 129, 0.15)';
      badge.style.border = '1px solid rgba(16, 185, 129, 0.4)';
      badge.style.color = '#10b981';
      badge.innerHTML = `
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg>
        <span><strong>FICHA COMERCIAL MLC1 AUTÉNTICA (Ed25519 + Separación de Dominio):</strong> Revisión #${escapeHtml(String(tokenRev))} verificada matemáticamente sin scripts ejecutables.</span>
      `;
    } else {
      badge.style.background = 'rgba(239, 68, 68, 0.15)';
      badge.style.border = '1px solid rgba(239, 68, 68, 0.4)';
      badge.style.color = '#ef4444';
      const alertMsg = data.security_alert || 'FIRMA ED25519 INVÁLIDA O FICHA ALTERADA — No compartir ni aplicar; regenera una ficha oficial desde Configuración';
      badge.innerHTML = `
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <span><strong>${escapeHtml(alertMsg)}</strong> (${escapeHtml(data.status || 'INVALID_SIGNATURE')})</span>
      `;
    }
  }

  let cardHtml = '';
  const highlights = [];

  if (isValid) {
    const revToneClass = revStatus === 'CURRENT'
      ? 'is-current'
      : (revStatus === 'SUPERSEDED' ? 'is-superseded' : 'is-ahead');
    const revBadgeClass = revStatus === 'CURRENT'
      ? 'badge badge-green'
      : (revStatus === 'SUPERSEDED' ? 'badge badge-yellow' : 'badge badge-blue');
    const revBadgeText = revStatus === 'CURRENT'
      ? 'Revisión vigente en Admin'
      : (revStatus === 'SUPERSEDED' ? 'Revisión anterior (Anti-downgrade)' : 'Revisión superior a la local');
    const recommendationText = cmp.recommendation || 'Ficha válida y verificada con la clave pública oficial.';

    const issuedIso = data.issued_at || (data.issued_at_unix ? new Date(Number(data.issued_at_unix) * 1000).toISOString() : '');
    const issuedLimaFormatted = issuedIso
      ? formatLimaDateTime(issuedIso)
      : (data.issued_at_lima || '-');
    const payloadBytes = data.payload_bytes ?? 0;
    const tokenBytes = data.token_bytes ?? 0;
    const maxPayloadBytes = data.max_payload_bytes ?? 8192;

    const diffData = cmp.diff_vs_current || {};
    const productsDiff = Array.isArray(diffData.products_diff) ? diffData.products_diff : [];
    const channelsDiff = Array.isArray(diffData.channels_diff) ? diffData.channels_diff : [];
    const totalDiffs = Number(diffData.total_differences ?? 0);

    const rowsHtml = productsDiff.map(p => {
      const tv = p.token_values || {};
      const cv = p.current_values || {};
      const changedFields = Array.isArray(p.changed_fields) ? p.changed_fields : [];
      const priceStr = `S/ ${Number(tv.pr ?? 0).toFixed(2)}`;
      const daysStr = Number(tv.d ?? 0) >= 99999 ? 'Vitalicia' : `${tv.d ?? 0} d`;
      const aiStr = `+${tv.ai ?? 0} IA`;
      const umStr = Number(tv.um ?? 0) > 0 ? `${tv.um} m` : '-';

      let statusCellHtml = '<span class="badge badge-green">Coincide</span>';
      if (!p.matches) {
        const diffNotes = [];
        if (changedFields.includes('pr')) {
          diffNotes.push(`Precio: Ficha S/ ${Number(tv.pr ?? 0).toFixed(2)} vs Admin S/ ${Number(cv.pr ?? 0).toFixed(2)}`);
        }
        if (changedFields.includes('d')) {
          diffNotes.push(`Días: Ficha ${tv.d ?? 0} vs Admin ${cv.d ?? 0}`);
        }
        if (changedFields.includes('ai')) {
          diffNotes.push(`Bolsa IA: Ficha ${tv.ai ?? 0} vs Admin ${cv.ai ?? 0}`);
        }
        if (changedFields.includes('um')) {
          diffNotes.push(`Updates: Ficha ${tv.um ?? 0}m vs Admin ${cv.um ?? 0}m`);
        }
        statusCellHtml = `
          <div style="display:flex; flex-direction:column; gap:0.25rem;">
            <span class="badge badge-yellow">Difiere de Config actual</span>
            <span style="font-size:0.75rem; color:var(--text-secondary);">${escapeHtml(diffNotes.join(' · ') || 'Valores distintos')}</span>
          </div>
        `;
      }

      return `
        <tr>
          <td>
            <strong>${escapeHtml(p.label || p.id)}</strong>
            <div><code style="font-size:0.72rem; color:var(--text-muted);">${escapeHtml(p.id)}</code></div>
          </td>
          <td style="font-family:var(--font-mono);"><strong>${escapeHtml(priceStr)}</strong></td>
          <td>${escapeHtml(daysStr)}</td>
          <td>${escapeHtml(aiStr)}</td>
          <td>${escapeHtml(umStr)}</td>
          <td>${statusCellHtml}</td>
        </tr>
      `;
    }).join('');

    const channelsHtml = channelsDiff.map(ch => {
      const statusBadge = ch.matches
        ? '<span class="badge badge-green">Coincide</span>'
        : '<span class="badge badge-yellow">Difiere</span>';
      const diffDetail = !ch.matches
        ? `<div style="font-size:0.74rem; color:var(--text-secondary); margin-top:0.3rem;">Admin actual: <code>${escapeHtml(ch.current_value || '-')}</code></div>`
        : '';
      return `
        <div class="inspect-mlc1-channel-card${ch.matches ? '' : ' has-diff'}">
          <div style="display:flex; justify-content:space-between; align-items:center; gap:0.4rem; margin-bottom:0.35rem;">
            <strong>${escapeHtml(ch.label || ch.key)}</strong>
            ${statusBadge}
          </div>
          <div style="font-family:var(--font-mono); font-size:0.77rem; color:var(--text-primary); word-break:break-word;">
            ${escapeHtml(ch.token_value || 'Omitido')}
          </div>
          ${diffDetail}
        </div>
      `;
    }).join('');

    cardHtml = `
      <div class="mlc1-audit-guidance-banner ${revToneClass}">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="flex-shrink:0; margin-top:2px;"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
        <div>
          <div style="font-weight:700; margin-bottom:0.2rem;">Qué significa este resultado y qué hacer ahora:</div>
          <div>${escapeHtml(recommendationText)}</div>
        </div>
      </div>

      <div class="inspect-mlc1-meta-grid">
        <div class="inspect-mlc1-meta-card" title="Número de revisión monotónica embebido en la ficha MLC1">
          <span class="inspect-mlc1-meta-label">Revisión de Ficha</span>
          <span class="inspect-mlc1-meta-val">Revisión #${escapeHtml(String(tokenRev))}</span>
          <span class="inspect-mlc1-meta-sub">Admin local actual: Rev. #${escapeHtml(String(localRev))}</span>
        </div>
        <div class="inspect-mlc1-meta-card" title="Comparación anti-downgrade respecto a la revisión local en owner_config.json">
          <span class="inspect-mlc1-meta-label">Estado frente a Admin</span>
          <div><span class="${escapeHtml(revBadgeClass)}">${escapeHtml(revBadgeText)}</span></div>
          <span class="inspect-mlc1-meta-sub">${totalDiffs === 0 ? 'Sin diferencias frente a config actual' : `${totalDiffs} diferencia(s) detectada(s)`}</span>
        </div>
        <div class="inspect-mlc1-meta-card" title="${issuedIso ? `UTC: ${escapeHtml(issuedIso)}` : 'Hora Perú GMT-5'}">
          <span class="inspect-mlc1-meta-label">Emisión (Lima GMT-5)</span>
          <span class="inspect-mlc1-meta-val" style="font-size:0.86rem;">${escapeHtml(issuedLimaFormatted)}</span>
          <span class="inspect-mlc1-meta-sub">Dominio separado: <code>MLC1-</code> (Activo)</span>
        </div>
        <div class="inspect-mlc1-meta-card" title="Cota máxima declarativa permitida por protocolo: ${escapeHtml(String(maxPayloadBytes))} bytes">
          <span class="inspect-mlc1-meta-label">Tamaño de Payload</span>
          <span class="inspect-mlc1-meta-val">${escapeHtml(String(payloadBytes))} B / ${escapeHtml(String(maxPayloadBytes))} B</span>
          <span class="inspect-mlc1-meta-sub">Token completo: ${escapeHtml(String(tokenBytes))} B</span>
        </div>
      </div>

      <h4 style="font-size:0.95rem; font-weight:700; color:var(--text-primary); margin-bottom:0.5rem;">
        Comparativa de los 8 Productos Comerciales (Ficha vs Config Actual)
      </h4>
      <div class="table-responsive" style="margin-bottom:1rem;">
        <table class="claims-table" id="inspectMlc1ProductsTable">
          <thead>
            <tr>
              <th>Producto</th>
              <th>Precio</th>
              <th>Días</th>
              <th>Bolsa IA</th>
              <th>Updates</th>
              <th>Estado vs Config actual</th>
            </tr>
          </thead>
          <tbody>
            ${rowsHtml || '<tr><td colspan="6" style="text-align:center; color:var(--text-muted);">Sin productos para mostrar.</td></tr>'}
          </tbody>
        </table>
      </div>

      <h4 style="font-size:0.95rem; font-weight:700; color:var(--text-primary); margin-bottom:0.35rem;">
        Soporte y Medios de Pago Declarados
      </h4>
      <div class="inspect-mlc1-channels-grid">
        ${channelsHtml}
      </div>

      <div class="inspector-actions-bar">
        <button type="button" class="btn btn-outline btn-xs" id="btnInspectMlc1CopyReport">
          <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
          Copiar Informe Forense
        </button>
        <button type="button" class="btn btn-primary btn-xs" id="btnInspectMlc1OpenSettings">
          <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
          Abrir Configuración (#tabSettings)
        </button>
      </div>
    `;

    highlights.push(
      { label: 'Revisión Ficha / Local', value: `Rev. #${tokenRev} / Admin Rev. #${localRev}` },
      { label: 'Estado Anti-Downgrade', value: `${revStatus} (${revBadgeText})` },
      { label: 'Separación de Dominio', value: 'Ed25519 sobre utf8(MLC1-payloadB64)' },
      { label: 'Emitido (Lima GMT-5)', value: issuedLimaFormatted },
      { label: 'Tamaño Payload / Token', value: `${payloadBytes} B / ${tokenBytes} B (límite ${maxPayloadBytes} B)` },
      { label: 'Diferencias vs Config actual', value: totalDiffs === 0 ? '0 diferencias (Coincide al 100 %)' : `${totalDiffs} diferencia(s)` }
    );
    productsDiff.filter(p => !p.matches).forEach(p => {
      const tv = p.token_values || {};
      const cv = p.current_values || {};
      highlights.push({
        label: `Producto ${p.id}`,
        value: `Ficha S/ ${Number(tv.pr ?? 0).toFixed(2)} (${tv.d ?? 0}d, +${tv.ai ?? 0} IA) vs Admin S/ ${Number(cv.pr ?? 0).toFixed(2)} (${cv.d ?? 0}d, +${cv.ai ?? 0} IA)`,
      });
    });
    channelsDiff.filter(c => !c.matches).forEach(c => {
      highlights.push({
        label: `Canal ${c.label}`,
        value: `Ficha "${c.token_value}" vs Admin "${c.current_value}"`,
      });
    });
  } else {
    const alertMsg = data.security_alert || 'FIRMA ED25519 INVÁLIDA O FICHA ALTERADA — No compartir ni aplicar; regenera una ficha oficial desde Configuración';
    let diagSectionHtml = '';
    if (data.diagnostic_payload && typeof data.diagnostic_payload === 'object') {
      const ds = data.diagnostic_summary || {};
      const unexpected = Array.isArray(ds.unexpected_keys) && ds.unexpected_keys.length > 0
        ? ` · Claves no autorizadas detectadas: ${ds.unexpected_keys.join(', ')}`
        : '';
      diagSectionHtml = `
        <div id="inspectMlc1DiagnosticBox" class="inspect-mlc1-diagnostic-box">
          <div style="display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:0.5rem;">
            <strong style="color:var(--danger); font-size:0.88rem;">Lectura Diagnóstica (NO CONFIABLE — Firma fallida)</strong>
            <span class="badge badge-red">NO CONFIABLE</span>
          </div>
          <p style="margin:0.35rem 0 0.45rem 0; font-size:0.78rem; color:var(--text-secondary);">
            Los siguientes datos se decodificaron únicamente para diagnóstico de soporte y <strong>no deben aplicarse ni compartirse</strong>:
            Rev. #${escapeHtml(String(ds.revision ?? data.diagnostic_payload.ver ?? '-'))}
            · Soporte: ${escapeHtml(String(ds.support_phone ?? data.diagnostic_payload.sup ?? '-'))}${escapeHtml(unexpected)}
          </p>
          <pre class="inspect-mlc1-diagnostic-pre">${escapeHtml(JSON.stringify(data.diagnostic_payload, null, 2))}</pre>
        </div>
      `;
    }

    cardHtml = `
      <div class="mlc1-audit-guidance-banner is-invalid">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="flex-shrink:0; margin-top:2px;"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <div>
          <div style="font-weight:700; margin-bottom:0.2rem;">${escapeHtml(alertMsg)}</div>
          <div>Motivo técnico (${escapeHtml(data.status || 'INVALID')}): ${escapeHtml(data.error || 'La firma criptográfica no corresponde a tu clave maestra privada.')}</div>
        </div>
      </div>
      ${diagSectionHtml}
      <div class="inspector-actions-bar">
        <button type="button" class="btn btn-outline btn-xs" id="btnInspectMlc1CopyReport">
          <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
          Copiar Informe Forense
        </button>
        <button type="button" class="btn btn-primary btn-xs" id="btnInspectMlc1OpenSettings">
          <svg class="btn-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
          Abrir Configuración (#tabSettings)
        </button>
      </div>
    `;

    highlights.push(
      { label: 'Código de Error', value: data.status || 'INVALID_SIGNATURE' },
      { label: 'Detalle', value: data.error || 'Firma Ed25519 inválida' }
    );
  }

  if (mlc1AuditCard) {
    mlc1AuditCard.innerHTML = cardHtml;
  }

  document.getElementById('btnInspectMlc1CopyReport')?.addEventListener('click', () => {
    copyInspectorForensicReport();
  });
  document.getElementById('btnInspectMlc1OpenSettings')?.addEventListener('click', () => {
    openSettingsFromInspector();
  });

  currentInspectorAuditSnapshot = {
    kind: 'MLC1',
    auditedAtIso: new Date().toISOString(),
    valid: isValid,
    statusDetail: isValid
      ? 'Firma Ed25519 auténtica con separación de dominio MLC1-'
      : (data.status || 'INVALID_SIGNATURE'),
    clientSummary: isValid
      ? `Revisión #${tokenRev} vs Admin local Rev. #${localRev}`
      : 'Ficha MLC1 rechazada por verificación criptográfica',
    recommendation: isValid ? (cmp.recommendation || '') : null,
    securityAlert: !isValid ? (data.security_alert || '') : null,
    highlights: highlights,
  };

  if (!options.skipHistoryRecord) {
    const historyStatusText = !isValid
      ? 'Firma inválida'
      : (revStatus === 'CURRENT'
          ? 'Vigente'
          : (revStatus === 'SUPERSEDED' ? 'Anterior' : 'Superior'));
    const historyStatusTone = !isValid
      ? 'badge-red'
      : (revStatus === 'CURRENT'
          ? 'badge-green'
          : (revStatus === 'SUPERSEDED' ? 'badge-yellow' : 'badge-blue'));
    recordInspectorSessionEntry({
      kind: 'MLC1',
      summaryLabel: isValid ? `Revisión #${tokenRev} (Tarifas y Pagos)` : 'Ficha MLC1 Inválida',
      hardwareId: isValid ? `Rev. #${tokenRev} · ${data.payload_bytes ?? 0} B` : (data.status || 'INVALID'),
      statusText: historyStatusText,
      statusTone: historyStatusTone,
      timestampIso: new Date().toISOString(),
      rawInput: rawToken,
    });
  }
}
