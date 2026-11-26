// =================== INTERCEPTOR GLOBAL DE FETCH (SESIÓN PIN VAULT HTTP 423) ===================
const _originalFetch = (typeof window !== 'undefined' && window.fetch)
  ? window.fetch
  : (typeof fetch === 'function' ? fetch : null);
if (typeof window !== 'undefined') {
  window.fetch = async function (...args) {
    let [resource, config] = args;
    config = config || {};
    config.headers = config.headers || {};

    const vaultToken = typeof sessionStorage !== 'undefined'
      ? sessionStorage.getItem('ml_vault_session_token')
      : null;
    if (vaultToken) {
      if (config.headers instanceof Headers) {
        if (!config.headers.has('X-Vault-Session-Token')) {
          config.headers.set('X-Vault-Session-Token', vaultToken);
        }
      } else if (Array.isArray(config.headers)) {
        if (!config.headers.some(([k]) => k.toLowerCase() === 'x-vault-session-token')) {
          config.headers.push(['X-Vault-Session-Token', vaultToken]);
        }
      } else {
        if (!config.headers['X-Vault-Session-Token'] && !config.headers['x-vault-session-token']) {
          config.headers['X-Vault-Session-Token'] = vaultToken;
        }
      }
    }

    const response = await _originalFetch(resource, config);
    if (response.status === 423) {
      // Sesión bloqueada localmente por PIN
      if (typeof showVaultPinLockOverlay === 'function') {
        showVaultPinLockOverlay();
      }
    }
    return response;
  };
}
