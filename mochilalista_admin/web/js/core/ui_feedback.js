// =================== SISTEMA DE NOTIFICACIONES TOAST ===================
function showToast(message, type = 'info', durationOrOptions = 3500) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  let duration = 3500;
  let actionLabel = null;
  let onAction = null;

  if (typeof durationOrOptions === 'number') {
    duration = durationOrOptions;
  } else if (durationOrOptions && typeof durationOrOptions === 'object') {
    if (typeof durationOrOptions.duration === 'number') {
      duration = durationOrOptions.duration;
    }
    if (durationOrOptions.actionLabel) {
      actionLabel = String(durationOrOptions.actionLabel);
    }
    if (typeof durationOrOptions.onAction === 'function') {
      onAction = durationOrOptions.onAction;
    }
    if (actionLabel && typeof durationOrOptions.duration !== 'number') {
      duration = 7500;
    }
  }

  const toast = document.createElement('div');
  toast.className = `toast ${type} toast-${type}`;

  let iconSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>';
  if (type === 'success') {
    iconSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>';
  } else if (type === 'error') {
    iconSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>';
  } else if (type === 'warning') {
    iconSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>';
  }

  const iconSpan = document.createElement('span');
  iconSpan.className = 'toast-icon';
  iconSpan.innerHTML = iconSvg;

  const contentDiv = document.createElement('div');
  contentDiv.className = 'toast-content';
  contentDiv.textContent = message == null ? '' : String(message);

  toast.appendChild(iconSpan);
  toast.appendChild(contentDiv);

  let dismissTimer = null;
  let removed = false;
  const removeToast = () => {
    if (removed) return;
    removed = true;
    if (dismissTimer) clearTimeout(dismissTimer);
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    toast.style.transition = 'all 0.25s ease';
    setTimeout(() => toast.remove(), 260);
  };

  if (actionLabel && onAction) {
    let actionRan = false;
    const actionBtn = document.createElement('button');
    actionBtn.type = 'button';
    actionBtn.className = 'toast-action-btn';
    actionBtn.textContent = actionLabel;
    actionBtn.addEventListener('click', async () => {
      if (actionRan) return;
      actionRan = true;
      actionBtn.disabled = true;
      try {
        await onAction();
      } finally {
        removeToast();
      }
    });
    toast.appendChild(actionBtn);
  }

  const closeBtn = document.createElement('button');
  closeBtn.type = 'button';
  closeBtn.className = 'toast-close';
  closeBtn.title = 'Cerrar';
  closeBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
  closeBtn.addEventListener('click', removeToast);
  toast.appendChild(closeBtn);

  container.appendChild(toast);

  dismissTimer = setTimeout(removeToast, duration);
}

// =================== MODAL DE CONFIRMACIÓN PROFESIONAL ===================
let confirmCallback = null;
let confirmCancelCallback = null;

function initModalConfirm() {
  const modal = document.getElementById('modalConfirm');
  const btnOk = document.getElementById('btnConfirmOk');
  const btnCancel = document.getElementById('btnConfirmCancel');
  const btnClose = document.getElementById('btnConfirmClose');

  const closeWithoutConfirm = () => {
    modal?.classList.remove('open');
    const cancelCb = confirmCancelCallback;
    confirmCallback = null;
    confirmCancelCallback = null;
    if (typeof cancelCb === 'function') {
      cancelCb();
    }
  };

  btnCancel?.addEventListener('click', closeWithoutConfirm);
  btnClose?.addEventListener('click', closeWithoutConfirm);

  btnOk?.addEventListener('click', () => {
    const okCb = confirmCallback;
    modal?.classList.remove('open');
    confirmCallback = null;
    confirmCancelCallback = null;
    if (typeof okCb === 'function') {
      okCb();
    }
  });
}

function showConfirmModal(
  title,
  message,
  onConfirm,
  isDanger = false,
  onCancel = null
) {
  const modal = document.getElementById('modalConfirm');
  const titleEl = document.getElementById('confirmModalTitle');
  const msgEl = document.getElementById('confirmModalMessage');
  const btnOk = document.getElementById('btnConfirmOk');

  if (!modal || !titleEl || !msgEl || !btnOk) return;

  titleEl.textContent = title;
  msgEl.innerHTML = escapeHtml(message);
  confirmCallback = onConfirm;
  confirmCancelCallback = typeof onCancel === 'function' ? onCancel : null;

  if (isDanger) {
    btnOk.className = 'btn btn-outline';
    btnOk.style.color = 'var(--danger)';
    btnOk.style.borderColor = 'var(--danger)';
    btnOk.textContent = 'Confirmar';
  } else {
    btnOk.className = 'btn btn-primary';
    btnOk.style.color = '';
    btnOk.style.borderColor = '';
    btnOk.textContent = 'Confirmar';
  }

  modal.classList.add('open');
}

// =================== DETECCIÓN DE ENTORNO NATIVO / ESCRITORIO ===================
/**
 * Detecta si la interfaz se está ejecutando en Modo Aplicación de Escritorio
 * (parámetro ?mode=app o modo standalone / minimal-ui de PWA/Chrome App).
 */
function isDesktopAppMode() {
  const params = new URLSearchParams(window.location.search);
  if (params.get('mode') === 'app') return true;
  if (window.matchMedia) {
    if (window.matchMedia('(display-mode: standalone)').matches) return true;
    if (window.matchMedia('(display-mode: minimal-ui)').matches) return true;
  }
  return false;
}

// =================== UTILIDADES GENÉRICAS ===================
function openModal(id) {
  const drawer = document.getElementById('drawerClient360');
  const isDrawerOpen = drawer && drawer.classList.contains('open');
  if (isDrawerOpen && currentDrawerClientId) {
    drawerReturnState = {
      clientId: currentDrawerClientId,
      tabId: currentDrawerTab || 'drawerTabOverview',
    };
    drawer.classList.remove('open');
    document.getElementById('drawerClient360Backdrop')?.classList.remove('open');
  }
  document.getElementById(id)?.classList.add('open');
}

function openModalFromDrawer(modalId) {
  openModal(modalId);
}

function closeModal(id) {
  document.getElementById(id)?.classList.remove('open');
  if (id === 'modalCreateRelease' && typeof resetCreateReleaseModalState === 'function') {
    resetCreateReleaseModalState();
  }
  if (id === 'modalEditRelease') {
    if (typeof resetExpandableTextarea === 'function') {
      resetExpandableTextarea('editRelChangelog');
      resetExpandableTextarea('editRelInternalNotes');
    }
    const editDirsPanel = document.getElementById('editSearchDirsPanel');
    if (editDirsPanel) editDirsPanel.style.display = 'none';
    const newEditDirInp = document.getElementById('inputEditNewApkSearchDir');
    if (newEditDirInp) newEditDirInp.value = '';
  }
  const remainingModals = document.querySelectorAll('.modal-overlay.open');
  if (remainingModals.length === 0 && drawerReturnState) {
    const returnInfo = drawerReturnState;
    drawerReturnState = null;
    openClient360Drawer(returnInfo.clientId, returnInfo.tabId);
  }
}
