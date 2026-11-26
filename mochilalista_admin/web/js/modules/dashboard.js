// =================== 1. DASHBOARD FINANCIERO & MICRO-GRÁFICOS SVG ===================
async function loadDashboard() {
  try {
    const res = await fetch('/api/dashboard', {
      headers: { 'X-App-Mode': currentMode }
    });
    if (!res.ok) throw new Error('Error al cargar dashboard');
    const data = await res.json();

    document.getElementById('kpiRevenueMonth').textContent = `S/ ${data.totalRevenueMonth.toFixed(2)}`;
    document.getElementById('kpiRevenueTotal').textContent = `S/ ${data.totalRevenueAccumulated.toFixed(2)}`;
    document.getElementById('kpiActiveClients').textContent = data.totalActiveClients;
    const kpiProspectsEl = document.getElementById('kpiProspects');
    if (kpiProspectsEl) {
      kpiProspectsEl.textContent = data.prospectClients !== undefined ? data.prospectClients : 0;
    }
    document.getElementById('kpiExpiringSoon').textContent = data.expiringSoonClients;
    document.getElementById('kpiExpired').textContent = data.expiredClients;
    document.getElementById('kpiPerpetual').textContent = data.perpetualClients;
    document.getElementById('kpiOutdated').textContent = data.outdatedAppClients;

    // Tabla de acciones urgentes
    const tbody = document.getElementById('urgentTableBody');
    tbody.innerHTML = '';

    if (!data.urgentActions || data.urgentActions.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:1.5rem;">No hay licencias por vencer en los próximos 7 días.</td></tr>';
    } else {
      data.urgentActions.forEach(action => {
        const tr = document.createElement('tr');
        const msgText = renderConfigTemplate('expiring_reminder', {
          titular: action.owner_name,
          negocio: action.business_name,
          dias: action.days_left,
          vencimiento: action.expires_date ? action.expires_date.substring(0, 10) : 'Próximamente',
          device_id: action.current_device_id,
        });
        const waLink = buildWhatsAppSendUrl(action.phone, msgText);

        tr.innerHTML = `
          <td><strong>${escapeHtml(action.business_name)}</strong></td>
          <td>${escapeHtml(action.owner_name)}</td>
          <td><span class="device-id-badge" title="Hardware ID (ANDROID_ID)">${escapeHtml(action.current_device_id)}</span></td>
          <td><span class="badge badge-yellow" style="display:inline-flex; align-items:center; gap:4px;"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg> ${action.days_left} día(s)</span></td>
          <td>${action.expires_date ? action.expires_date.substring(0, 10) : '-'}</td>
          <td>
            <button type="button" class="btn btn-wa btn-sm" onclick="openWhatsAppComposer('${action.client_id}', 'expiring')" title="Abrir Compositor de WhatsApp">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" style="width:14px; height:14px; margin-right:4px;"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>
              <span>Avisar por WhatsApp</span>
            </button>
          </td>
        `;
        tbody.appendChild(tr);
      });
    }

    // Acciones pendientes CRM (Plan Maestro 18 - Fase 3): Seguimientos pendientes y Bonos IA por emitir
    const todayStr = getLocalIsoDate();
    let countFollowupDue = 0;
    let countPendingBonus = 0;
    if (globalClients && globalClients.length > 0) {
      globalClients.forEach(c => {
        if (c.next_followup_date && c.next_followup_date <= todayStr) countFollowupDue++;
        if ((c.ai_pending_bonus || 0) > 0) countPendingBonus++;
      });
    }

    const alertBanner = document.getElementById('dashPendingActionsAlert');
    const followupItem = document.getElementById('dashFollowupAlertItem');
    const bonusItem = document.getElementById('dashBonusAlertItem');
    const followupCountEl = document.getElementById('dashFollowupAlertCount');
    const bonusCountEl = document.getElementById('dashBonusAlertCount');

    if (alertBanner) {
      if (countFollowupDue > 0 || countPendingBonus > 0) {
        alertBanner.style.display = 'block';
        if (followupItem) {
          followupItem.style.display = countFollowupDue > 0 ? 'inline-flex' : 'none';
          if (followupCountEl) followupCountEl.textContent = countFollowupDue;
        }
        if (bonusItem) {
          bonusItem.style.display = countPendingBonus > 0 ? 'inline-flex' : 'none';
          if (bonusCountEl) bonusCountEl.textContent = countPendingBonus;
        }
      } else {
        alertBanner.style.display = 'none';
      }
    }

    // Cargar finanzas si están vacías para alimentar el gráfico de ingresos
    if (globalFinances.length === 0) {
      try {
        const finRes = await fetch('/api/finances');
        if (finRes.ok) globalFinances = await finRes.json();
      } catch (_) { }
    }

    // Renderizar los 2 Micro-Gráficos SVG Nativos
    renderMonthlyRevenueChart(globalFinances);
    renderPlanDistributionChart(globalClients);
  } catch (e) {
    console.error('Error al cargar dashboard:', e);
  }
}

// 1.1 Micro-Gráfico SVG: Evolución de Ingresos Mensuales
function renderMonthlyRevenueChart(payments = []) {
  const container = document.getElementById('chartMonthlyRevenue');
  if (!container) return;

  const pList = (payments && payments.length > 0) ? payments : globalFinances;

  if (!pList || pList.length === 0) {
    container.innerHTML = `
      <div class="chart-empty-state">
        <svg style="width:36px; height:36px; color:var(--text-muted); opacity:0.6;" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <span>Sin movimientos contables registrados</span>
        <small style="color:var(--text-muted); font-size:0.75rem;">Los cobros aparecerán aquí en tiempo real.</small>
      </div>
    `;
    return;
  }

  const monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
  const monthsData = [];
  const now = new Date();

  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    monthsData.push({
      key: key,
      label: `${monthNames[d.getMonth()]} ${String(d.getFullYear()).slice(2)}`,
      total: 0,
    });
  }

  pList.forEach(p => {
    if (!p.date) return;
    const pKey = p.date.substring(0, 7);
    const mObj = monthsData.find(m => m.key === pKey);
    if (mObj) {
      mObj.total += (parseFloat(p.amount) || 0);
    }
  });

  const maxTotal = Math.max(100, ...monthsData.map(m => m.total));
  const svgWidth = 460;
  const svgHeight = 210;
  const chartTop = 25;
  const chartBottom = 165;
  const chartHeight = chartBottom - chartTop;
  const barWidth = 38;
  const barGap = (svgWidth - 60 - (barWidth * 6)) / 5;

  let barsSvg = '';
  monthsData.forEach((m, idx) => {
    const x = 30 + idx * (barWidth + barGap);
    const h = (m.total / maxTotal) * chartHeight;
    const y = chartBottom - h;
    const amtLabel = m.total > 0 ? `S/ ${Number(m.total).toFixed(2)}` : 'S/ 0';

    barsSvg += `
      <g class="chart-bar" tabindex="0">
        <title>${m.label}: S/ ${Number(m.total).toFixed(2)}</title>
        <rect x="${x}" y="${y}" width="${barWidth}" height="${Math.max(4, h)}" rx="6" fill="url(#revGrad)" opacity="${m.total > 0 ? '1' : '0.2'}"/>
        <text x="${x + barWidth / 2}" y="${Math.max(15, y - 6)}" text-anchor="middle" font-size="10" font-weight="700" fill="var(--text-primary)">${amtLabel}</text>
        <text x="${x + barWidth / 2}" y="${chartBottom + 18}" text-anchor="middle" font-size="11" font-weight="600" fill="var(--text-secondary)">${m.label}</text>
      </g>
    `;
  });

  container.innerHTML = `
    <svg viewBox="0 0 ${svgWidth} ${svgHeight}" class="svg-chart">
      <defs>
        <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#10b981"/>
          <stop offset="100%" stop-color="#059669"/>
        </linearGradient>
      </defs>
      <line x1="15" y1="${chartBottom}" x2="${svgWidth - 15}" y2="${chartBottom}" stroke="var(--border-color)" stroke-width="1"/>
      <line x1="15" y1="${chartTop + chartHeight / 2}" x2="${svgWidth - 15}" y2="${chartTop + chartHeight / 2}" stroke="var(--border-color)" stroke-width="1" stroke-dasharray="4"/>
      ${barsSvg}
    </svg>
  `;
}

// 1.2 Micro-Gráfico SVG: Distribución de Cartera por Plan (Donut Chart)
function renderPlanDistributionChart(clients = []) {
  const container = document.getElementById('chartPlanDistribution');
  if (!container) return;

  const cList = (clients && clients.length > 0) ? clients : globalClients;
  if (!cList || cList.length === 0) {
    container.innerHTML = `
      <div class="chart-empty-state">
        <svg style="width:36px; height:36px; color:var(--text-muted); opacity:0.6;" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M12 2a10 10 0 0 1 10 10h-10z"/></svg>
        <span>Sin clientes registrados</span>
        <small style="color:var(--text-muted); font-size:0.75rem;">Agrega clientes para visualizar la distribución.</small>
      </div>
    `;
    return;
  }

  const planCounts = {
    MENSUAL: { label: 'Mensual', count: 0, color: '#2563eb' },
    TRIMESTRAL: { label: 'Trimestral', count: 0, color: '#06b6d4' },
    SEMESTRAL: { label: 'Semestral', count: 0, color: '#10b981' },
    ANUAL: { label: 'Anual', count: 0, color: '#f59e0b' },
    PERPETUO: { label: 'Perpetuo', count: 0, color: '#8b5cf6' },
    EXTENSION_CORTESIA: { label: 'Cortesía', count: 0, color: '#d97706' },
    PROSPECTO: { label: 'Prospecto', count: 0, color: '#6366f1' },
    TRIAL: { label: 'Trial', count: 0, color: '#64748b' },
    OTROS: { label: 'Otros', count: 0, color: '#94a3b8' },
  };

  let totalCount = 0;
  cList.forEach(c => {
    const p = (c.license_type || 'MENSUAL').toUpperCase();
    const s = (c.license_status || '').toUpperCase();
    if (p.includes('PERPETUO')) {
      planCounts.PERPETUO.count++;
      totalCount++;
    } else if (p.includes('CORTESIA') || p.includes('EXTENSION_CORTESIA') || s === 'EXTENSION_CORTESIA') {
      planCounts.EXTENSION_CORTESIA.count++;
      totalCount++;
    } else if (p === 'PROSPECTO' || s === 'PROSPECTO') {
      planCounts.PROSPECTO.count++;
      totalCount++;
    } else if (planCounts[p]) {
      planCounts[p].count++;
      totalCount++;
    } else if (p.includes('TRIAL')) {
      planCounts.TRIAL.count++;
      totalCount++;
    } else {
      planCounts.OTROS.count++;
      totalCount++;
    }
  });

  const baseTotal = totalCount > 0 ? totalCount : 1;
  const radius = 62;
  const circumference = 2 * Math.PI * radius;
  let accumulatedOffset = 0;
  let circlesSvg = '';
  let legendHtml = '<div class="donut-legend-wrap">';

  for (const [key, item] of Object.entries(planCounts)) {
    if (item.count === 0) continue;
    const pct = (item.count / baseTotal);
    const strokeDash = pct * circumference;
    const strokeOffset = circumference - accumulatedOffset;
    accumulatedOffset += strokeDash;

    circlesSvg += `
      <circle class="donut-segment" cx="95" cy="100" r="${radius}" fill="none" stroke="${item.color}" stroke-width="26"
        stroke-dasharray="${strokeDash} ${circumference - strokeDash}"
        stroke-dashoffset="${strokeOffset}">
        <title>${item.label}: ${item.count} (${Math.round(pct * 100)}%)</title>
      </circle>
    `;

    legendHtml += `
      <div class="donut-legend-item">
        <span class="donut-legend-dot" style="background:${item.color};"></span>
        <span class="donut-legend-name">${item.label}</span>
        <span class="donut-legend-pct">${item.count} (${Math.round(pct * 100)}%)</span>
      </div>
    `;
  }
  legendHtml += '</div>';

  container.innerHTML = `
    <div style="display:flex; align-items:center; justify-content:center; width:100%; gap:1.5rem; flex-wrap:wrap;">
      <svg width="190" height="200" viewBox="0 0 190 200">
        <g transform="rotate(-90 95 100)">
          <circle cx="95" cy="100" r="${radius}" fill="none" stroke="var(--bg-hover)" stroke-width="26"/>
          ${circlesSvg}
        </g>
        <text x="95" y="96" text-anchor="middle" font-size="24" font-weight="800" fill="var(--text-primary)">${totalCount}</text>
        <text x="95" y="114" text-anchor="middle" font-size="10" font-weight="700" fill="var(--text-muted)" letter-spacing="0.5">CLIENTES</text>
      </svg>
      <div style="flex:1; min-width:180px;">
        ${legendHtml}
      </div>
    </div>
  `;
}

// 1.3 Eventos de Clic en KPI Cards para Filtrar CRM o Cambiar de Pestaña
function initDashboardKpiClickEvents() {
  const cards = document.querySelectorAll('[data-kpi-filter]');
  cards.forEach(card => {
    card.addEventListener('click', () => {
      const filter = card.dataset.kpiFilter;
      if (!filter) return;

      currentClientFilter = filter;

      document.querySelectorAll('.filter-chip').forEach(chip => {
        if (chip.dataset.filter === filter) {
          chip.classList.add('active');
        } else {
          chip.classList.remove('active');
        }
      });

      const tabs = document.querySelectorAll('.nav-tab');
      tabs.forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

      const clientTab = document.querySelector('[data-tab="tabClients"]');
      clientTab?.classList.add('active');
      document.getElementById('tabClients')?.classList.add('active');

      const viewNameEl = document.getElementById('currentViewName');
      if (viewNameEl) viewNameEl.textContent = 'Cartera CRM';

      renderClientsTable();
      showToast(`Filtrando clientes por: ${filter.toUpperCase()}`, 'info');
    });
  });

  // Acceso directo desde KPI de ingresos hacia Finanzas & Respaldos
  const tabCards = document.querySelectorAll('[data-kpi-tab]');
  tabCards.forEach(card => {
    card.addEventListener('click', () => {
      const targetTab = card.dataset.kpiTab;
      if (!targetTab) return;
      const tabBtn = document.querySelector(`.nav-tab[data-tab="${targetTab}"]`);
      if (tabBtn) tabBtn.click();
    });
  });
}
