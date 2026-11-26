// =================== BOOTSTRAP DE ENTRADA ADMINISTRATIVA ===================
document.addEventListener('DOMContentLoaded', async () => {
  initNavigation();
  initTheme();
  initModeSwitcher();
  initOmnichannelSearch();
  initModalConfirm();
  initDashboardKpiClickEvents();
  initDrawerEvents();
  initReceiptModalEvents();
  initSettingsEvents();
  initExcelExportEvents();
  initVaultEvents();
  const isPinLocked = await checkVaultInitialStatus();
  if (!isPinLocked) {
    await loadConfig();
    await loadSystemMode();
    await loadClients();
    await loadDashboard();
    await loadReleases();
    await loadReleaseMatrix();
  }
  initLicenseStudioEvents();
  initModalEvents();
  initWaComposerEvents();
  initInspectorEvents();
  initClientSyncEvents();
  initReleaseUploadAndAutoDetect();
  initFinancesAndBackupsEvents();
});

async function bootstrapAuthenticatedWorkspace() {
  await loadConfig();
  await loadSystemMode();
  await loadClients();
  await loadDashboard();
  await loadReleases();
  await loadReleaseMatrix();
  await Promise.allSettled([
    loadFinances(),
    loadBackups(),
    loadVaultHealth(),
  ]);
}
