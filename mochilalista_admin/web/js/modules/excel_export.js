// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL .XLSX (FASE 4B) ===================

function initExcelExportEvents() {
  document.getElementById('btnHeaderExportExcel')?.addEventListener('click', () => {
    downloadExcelReport('/api/export/excel-master', `mochilalista_maestro_${Date.now()}.xlsx`);
  });

  document.getElementById('btnCrmExportExcel')?.addEventListener('click', () => {
    downloadExcelReport('/api/export/excel-master', `mochilalista_cartera_${Date.now()}.xlsx`);
  });

  document.getElementById('btnExportFinancesExcel')?.addEventListener('click', () => {
    const from = document.getElementById('finFilterFrom')?.value || '';
    const to = document.getElementById('finFilterTo')?.value || '';
    const query = new URLSearchParams();
    if (from) query.append('from', from);
    if (to) query.append('to', to);
    const qStr = query.toString() ? `?${query.toString()}` : '';
    downloadExcelReport(`/api/export/excel-finances${qStr}`, `mochilalista_finanzas_${Date.now()}.xlsx`);
  });
}

async function downloadExcelReport(url, defaultFilename) {
  try {
    showToast('Generando libro de Microsoft Excel (.xlsx)...', 'info');
    const res = await fetch(url);
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error del servidor HTTP ${res.status}`);
    }

    let filename = defaultFilename;
    const disposition = res.headers.get('content-disposition');
    if (disposition && disposition.indexOf('filename=') !== -1) {
      const match = disposition.match(/filename="?([^"]+)"?/);
      if (match && match[1]) filename = match[1];
    }

    const blob = await res.blob();
    const downloadUrl = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = downloadUrl;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.URL.revokeObjectURL(downloadUrl);

    showToast(`Libro Excel descargado: ${filename}`, 'success');
  } catch (err) {
    showToast(`Error al exportar Excel: ${err.message}`, 'error');
  }
}

// Bootstrap de entrada (pendiente de extracción a bootstrap.js en Fase 5B)
