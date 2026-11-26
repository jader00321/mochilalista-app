function initImportFactorSelectorEvents() {
  const radios = document.querySelectorAll('input[name="importFactorType"]');
  radios.forEach(radio => {
    radio.addEventListener('change', e => {
      triggerImportFactorChange(e.target.value);
    });
  });

  // Selector de archivo .mlkey para importación
  const keyFileInput = document.getElementById('importKeyFileInput');
  keyFileInput?.addEventListener('change', e => {
    if (e.target.files.length > 0) {
      const file = e.target.files[0];
      const nameEl = document.getElementById('importKeyFileNameDisplay');
      if (nameEl) nameEl.textContent = file.name;
      const reader = new FileReader();
      reader.onload = ev => {
        importMlKeySecret = ev.target.result;
        showToast('Archivo .mlkey cargado correctamente.', 'info');
      };
      reader.readAsText(file);
    }
  });
}

function triggerImportFactorChange(selectedFactor) {
  const cKey = document.getElementById('factorMlKeyInputContainer');
  const cRescue = document.getElementById('factorRescueInputContainer');
  const cPin = document.getElementById('factorPinInputContainer');

  if (cKey) cKey.style.display = selectedFactor === 'mlkey' ? 'block' : 'none';
  if (cRescue) cRescue.style.display = selectedFactor === 'rescue_code' ? 'block' : 'none';
  if (cPin) cPin.style.display = selectedFactor === 'pin' ? 'block' : 'none';
}

async function submitImportVault() {
  if (!loadedVaultJson) {
    showToast('Debes seleccionar o arrastrar un archivo .mlvault válido.', 'warning');
    return;
  }

  const selectedRadio = document.querySelector('input[name="importFactorType"]:checked');
  const factorType = selectedRadio ? selectedRadio.value : 'mlkey';

  let secret = null;
  if (factorType === 'mlkey') {
    if (!importMlKeySecret) {
      showToast('Por favor selecciona el archivo .mlkey para desencriptar.', 'warning');
      return;
    }
    secret = importMlKeySecret;
  } else if (factorType === 'rescue_code') {
    const code = document.getElementById('importRescueCodeInput')?.value.trim();
    if (!code) {
      showToast('Por favor ingresa un Código de Rescate (XXXX-XXXX-XXXX).', 'warning');
      return;
    }
    secret = code;
  } else if (factorType === 'pin') {
    const pin = document.getElementById('importPinInput')?.value.trim();
    if (!pin) {
      showToast('Por favor ingresa el PIN de la máquina de origen.', 'warning');
      return;
    }
    secret = pin;
  }

  const chkRewrap = document.getElementById('chkImportRewrap');
  const rewrapDpapi = chkRewrap ? chkRewrap.checked : true;

  try {
    showToast('Restaurando base de datos, firmas y configuraciones en caliente...', 'info');
    const res = await fetch('/api/vault/import', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        vault_json: loadedVaultJson,
        credential_type: factorType,
        secret: secret,
        rewrap_dpapi: rewrapDpapi,
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }

    const data = await res.json();
    closeModal('modalImportVault');
    showToast(data.message || 'Bóveda importada exitosamente y recargada en caliente.', 'success');

    await bootstrapAuthenticatedWorkspace();
  } catch (err) {
    showToast(`Error al importar bóveda: ${err.message}`, 'error');
  }
}

async function autoRecoverFromMirror() {
  try {
    showToast('Restaurando Bóveda Espejo en 1 Clic con DPAPI...', 'info');
    const res = await fetch('/api/vault/recover-from-mirror', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ credential_type: 'dpapi' }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Error HTTP ${res.status}`);
    }

    const data = await res.json();
    closeModal('modalAutoRecovery');
    showToast(data.message || 'Bóveda recuperada automáticamente con éxito.', 'success');

    await bootstrapAuthenticatedWorkspace();
  } catch (err) {
    showToast(`Error al restaurar desde espejo: ${err.message}`, 'error');
  }
}

function initVaultPinEvents() {
  const chkPin = document.getElementById('chkEnablePin');
  const pinSetup = document.getElementById('pinSetupContainer');
  const btnSavePin = document.getElementById('btnSavePinConfig');
  const btnLockNow = document.getElementById('btnLockConsoleNow');

  chkPin?.addEventListener('change', e => {
    if (e.target.checked) {
      if (pinSetup) pinSetup.style.display = 'block';
    } else {
      showConfirmModal(
        'Desactivar Bloqueo por PIN',
        '¿Estás seguro de que deseas desactivar el PIN de consola? Cualquier usuario con acceso a tu navegador podrá ver la plataforma sin restricciones.',
        async () => {
          try {
            const res = await fetch('/api/vault/pin/configure', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ enabled: false }),
            });
            if (res.ok) {
              sessionStorage.removeItem('ml_vault_session_token');
              if (pinSetup) pinSetup.style.display = 'none';
              showToast('Bloqueo por PIN desactivado exitosamente.', 'info');
              await loadVaultHealth();
            } else {
              if (chkPin) chkPin.checked = true;
            }
          } catch (err) {
            if (chkPin) chkPin.checked = true;
            showToast(`Error al desactivar PIN: ${err.message}`, 'error');
          }
        },
        true,
        () => {
          if (chkPin) chkPin.checked = true;
        }
      );
    }
  });

  btnSavePin?.addEventListener('click', async () => {
    const pin = document.getElementById('inputVaultPin')?.value.trim();
    const pinConfirm = document.getElementById('inputVaultPinConfirm')?.value.trim();

    if (!pin || pin.length < 4) {
      showToast('El PIN debe contener al menos 4 caracteres.', 'warning');
      return;
    }
    if (pin !== pinConfirm) {
      showToast('Los campos de PIN y confirmación no coinciden.', 'warning');
      return;
    }

    try {
      const res = await fetch('/api/vault/pin/configure', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: true, pin: pin }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || `Error HTTP ${res.status}`);
      }
      const data = await res.json().catch(() => ({}));
      if (data.session_token) {
        sessionStorage.setItem('ml_vault_session_token', data.session_token);
      }
      showToast('PIN configurado y activado exitosamente.', 'success');
      document.getElementById('inputVaultPin').value = '';
      document.getElementById('inputVaultPinConfirm').value = '';
      if (pinSetup) pinSetup.style.display = 'none';
      await loadVaultHealth();
    } catch (err) {
      showToast(`Error al guardar PIN: ${err.message}`, 'error');
    }
  });

  btnLockNow?.addEventListener('click', async () => {
    try {
      await fetch('/api/vault/pin/lock', { method: 'POST' });
    } catch (_) {
    } finally {
      sessionStorage.removeItem('ml_vault_session_token');
      showVaultPinLockOverlay();
      showToast('Consola bloqueada por PIN.', 'info');
    }
  });

  // Desbloqueo mediante formulario
  document.getElementById('formUnlockPin')?.addEventListener('submit', async e => {
    e.preventDefault();
    const pin = document.getElementById('vaultPinInput')?.value.trim();
    if (!pin) return;

    try {
      const res = await fetch('/api/vault/pin/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pin: pin }),
      });
      const data = await res.json();
      if (data.ok && data.session_token) {
        sessionStorage.setItem('ml_vault_session_token', data.session_token);
        hideVaultPinLockOverlay();
        showToast('Consola desbloqueada correctamente.', 'success');
        await bootstrapAuthenticatedWorkspace();
      } else {
        const notice = document.getElementById('vaultPinBackoffNotice');
        if (notice) {
          notice.style.display = 'block';
          notice.textContent = data.error || 'PIN incorrecto.';
        }
      }
    } catch (err) {
      showToast(`Error al verificar PIN: ${err.message}`, 'error');
    }
  });

  // Enlace "¿Olvidaste tu PIN?"
  document.getElementById('linkForgotPin')?.addEventListener('click', () => {
    const panel = document.getElementById('vaultPinRecoveryPanel');
    if (panel) {
      panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
    }
  });

  // Carga de archivo .mlkey para recuperación
  const recKeyInput = document.getElementById('recoveryKeyFileInput');
  recKeyInput?.addEventListener('change', e => {
    if (e.target.files.length > 0) {
      const file = e.target.files[0];
      const nameEl = document.getElementById('recoveryKeyFileName');
      if (nameEl) nameEl.textContent = file.name;
      const reader = new FileReader();
      reader.onload = ev => {
        recoveryMlKeySecret = ev.target.result;
        showToast('Archivo .mlkey de recuperación listo.', 'info');
      };
      reader.readAsText(file);
    }
  });

  // Recuperación mediante DPAPI directa
  document.getElementById('btnRecoveryDpapi')?.addEventListener('click', async () => {
    await executePinRecovery('dpapi', null);
  });

  // Recuperación mediante Botón Confirmar
  document.getElementById('btnSubmitRecovery')?.addEventListener('click', async () => {
    const code = document.getElementById('recoveryCodeInput')?.value.trim();
    if (recoveryMlKeySecret) {
      await executePinRecovery('mlkey', recoveryMlKeySecret);
    } else if (code) {
      await executePinRecovery('rescue_code', code);
    } else {
      showToast('Selecciona un archivo .mlkey o ingresa un Código de Rescate.', 'warning');
    }
  });
}

async function executePinRecovery(credType, secretVal) {
  try {
    showToast('Recuperando acceso a la consola...', 'info');
    const res = await fetch('/api/vault/pin/recover', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        credential_type: credType,
        secret: secretVal,
        disable_pin: true,
      }),
    });

    const data = await res.json();
    if (data.ok) {
      if (data.pin_enabled === false) {
        sessionStorage.removeItem('ml_vault_session_token');
      } else if (data.session_token) {
        sessionStorage.setItem('ml_vault_session_token', data.session_token);
      }
      hideVaultPinLockOverlay();
      showToast('Acceso recuperado y consola desbloqueada con éxito.', 'success');
      await bootstrapAuthenticatedWorkspace();
    } else {
      showToast(`No se pudo recuperar: ${data.error || 'Factor inválido'}`, 'error');
    }
  } catch (err) {
    showToast(`Error en recuperación: ${err.message}`, 'error');
  }
}
