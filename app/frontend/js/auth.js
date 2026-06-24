'use strict';

/**
 * Autenticacion con Cognito via Authorization Code + PKCE (Hosted UI).
 *
 * Flujo del token:
 *   1. startLogin() genera un code_verifier aleatorio, calcula su SHA-256
 *      (code_challenge) y redirige a la Hosted UI de Cognito.
 *   2. Cognito autentica y vuelve a REDIRECT_URI (login.html) con ?code=...
 *   3. handleRedirectCallback() intercambia el code por tokens en /oauth2/token
 *      (cliente PUBLICO, sin secret) usando el code_verifier guardado.
 *   4. Los tokens se guardan en sessionStorage. El ACCESS TOKEN (que lleva los
 *      scopes hotel-api/*) es el que api.js envia como Authorization: Bearer.
 *
 * sessionStorage (no localStorage) → el token se borra al cerrar la pestaña.
 */
(function (global) {
  const CFG = global.HOTEL_NYX_CONFIG;

  const KEYS = {
    access: 'nyx_access_token',
    id: 'nyx_id_token',
    refresh: 'nyx_refresh_token',
    expiresAt: 'nyx_expires_at',
    verifier: 'nyx_pkce_verifier',
    state: 'nyx_oauth_state',
    returnTo: 'nyx_return_to',
  };

  // ─── Utilidades PKCE / JWT ──────────────────────────────────────────────────

  function base64UrlEncode(bytes) {
    let str = '';
    const arr = new Uint8Array(bytes);
    for (let i = 0; i < arr.length; i++) str += String.fromCharCode(arr[i]);
    return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function randomString(length) {
    const arr = new Uint8Array(length);
    crypto.getRandomValues(arr);
    return base64UrlEncode(arr).slice(0, length);
  }

  async function sha256Challenge(verifier) {
    const data = new TextEncoder().encode(verifier);
    const digest = await crypto.subtle.digest('SHA-256', data);
    return base64UrlEncode(digest);
  }

  function parseJwt(token) {
    try {
      const payload = token.split('.')[1];
      const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
      return JSON.parse(decodeURIComponent(escape(json)));
    } catch (err) {
      return null;
    }
  }

  // ─── Almacenamiento de tokens ───────────────────────────────────────────────

  function storeTokens(tokens) {
    if (tokens.access_token) sessionStorage.setItem(KEYS.access, tokens.access_token);
    if (tokens.id_token) sessionStorage.setItem(KEYS.id, tokens.id_token);
    if (tokens.refresh_token) sessionStorage.setItem(KEYS.refresh, tokens.refresh_token);
    const expiresInMs = (Number(tokens.expires_in) || 3600) * 1000;
    sessionStorage.setItem(KEYS.expiresAt, String(Date.now() + expiresInMs));
  }

  function clearTokens() {
    Object.values(KEYS).forEach((k) => sessionStorage.removeItem(k));
  }

  function getAccessToken() {
    return sessionStorage.getItem(KEYS.access);
  }
  function getIdToken() {
    return sessionStorage.getItem(KEYS.id);
  }

  function isExpired() {
    const exp = Number(sessionStorage.getItem(KEYS.expiresAt) || 0);
    return !exp || Date.now() >= exp;
  }

  function isAuthenticated() {
    return Boolean(getAccessToken()) && !isExpired();
  }

  // ─── Claims / roles ─────────────────────────────────────────────────────────

  function getAccessClaims() {
    const token = getAccessToken();
    return token ? parseJwt(token) : null;
  }

  function getProfile() {
    const claims = getIdToken() ? parseJwt(getIdToken()) : null;
    if (!claims) return null;
    return {
      email: claims.email || null,
      name: claims.name || claims.given_name || claims.email || null,
      groups: claims['cognito:groups'] || [],
    };
  }

  function hasAdminScope() {
    const claims = getAccessClaims();
    if (!claims) return false;
    const scopes = String(claims.scope || '').split(' ');
    const groups = claims['cognito:groups'] || [];
    return scopes.includes(CFG.ADMIN_SCOPE) || groups.includes('admin');
  }

  // ─── Login / callback / logout (PKCE) ───────────────────────────────────────

  async function startLogin(options) {
    const opts = options || {};
    const verifier = randomString(64);
    const challenge = await sha256Challenge(verifier);
    const state = randomString(24);

    sessionStorage.setItem(KEYS.verifier, verifier);
    sessionStorage.setItem(KEYS.state, state);

    const endpoint = opts.signup ? '/signup' : '/oauth2/authorize';
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: CFG.COGNITO_CLIENT_ID,
      redirect_uri: CFG.REDIRECT_URI,
      scope: CFG.COGNITO_SCOPES,
      state: state,
      code_challenge: challenge,
      code_challenge_method: 'S256',
    });

    global.location.assign(`${CFG.COGNITO_HOSTED_UI}${endpoint}?${params.toString()}`);
  }

  async function exchangeCodeForToken(code) {
    const verifier = sessionStorage.getItem(KEYS.verifier);
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: CFG.COGNITO_CLIENT_ID,
      code: code,
      redirect_uri: CFG.REDIRECT_URI,
      code_verifier: verifier || '',
    });

    const resp = await fetch(`${CFG.COGNITO_HOSTED_UI}/oauth2/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });

    if (!resp.ok) {
      throw new Error('No se pudo completar el inicio de sesion.');
    }
    return resp.json();
  }

  /**
   * Si la URL trae ?code=&state=, intercambia el code por tokens. Devuelve
   * true si proceso un callback de login. Limpia los query params al terminar.
   */
  async function handleRedirectCallback() {
    const url = new URL(global.location.href);
    const error = url.searchParams.get('error');
    if (error) {
      clearTokens();
      throw new Error(url.searchParams.get('error_description') || 'Error de autenticacion.');
    }

    const code = url.searchParams.get('code');
    const state = url.searchParams.get('state');
    if (!code) return false;

    const savedState = sessionStorage.getItem(KEYS.state);
    if (!savedState || state !== savedState) {
      throw new Error('Estado de autenticacion invalido (posible CSRF).');
    }

    const tokens = await exchangeCodeForToken(code);
    storeTokens(tokens);
    sessionStorage.removeItem(KEYS.verifier);
    sessionStorage.removeItem(KEYS.state);

    // Limpia el code/state de la URL sin recargar.
    url.searchParams.delete('code');
    url.searchParams.delete('state');
    global.history.replaceState({}, document.title, url.pathname + url.search);
    return true;
  }

  async function refreshTokens() {
    const refresh = sessionStorage.getItem(KEYS.refresh);
    if (!refresh) return false;

    const body = new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: CFG.COGNITO_CLIENT_ID,
      refresh_token: refresh,
    });

    try {
      const resp = await fetch(`${CFG.COGNITO_HOSTED_UI}/oauth2/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString(),
      });
      if (!resp.ok) return false;
      const tokens = await resp.json();
      // El refresh no devuelve refresh_token nuevo; conservamos el actual.
      tokens.refresh_token = tokens.refresh_token || refresh;
      storeTokens(tokens);
      return true;
    } catch (err) {
      return false;
    }
  }

  /** Garantiza un access token vigente; intenta refresh si esta por expirar. */
  async function ensureValidToken() {
    if (getAccessToken() && !isExpired()) return true;
    return refreshTokens();
  }

  function logout() {
    clearTokens();
    const params = new URLSearchParams({
      client_id: CFG.COGNITO_CLIENT_ID,
      logout_uri: CFG.LOGOUT_URI,
    });
    global.location.assign(`${CFG.COGNITO_HOSTED_UI}/logout?${params.toString()}`);
  }

  // ─── Guards de paginas protegidas ───────────────────────────────────────────

  function requireAuth() {
    if (isAuthenticated()) return true;
    sessionStorage.setItem(KEYS.returnTo, global.location.href);
    global.location.replace('login.html');
    return false;
  }

  function requireAdmin() {
    if (!isAuthenticated()) {
      sessionStorage.setItem(KEYS.returnTo, global.location.href);
      global.location.replace('../login.html');
      return false;
    }
    if (!hasAdminScope()) {
      global.location.replace('../login.html?denied=1');
      return false;
    }
    return true;
  }

  function consumeReturnTo() {
    const url = sessionStorage.getItem(KEYS.returnTo);
    sessionStorage.removeItem(KEYS.returnTo);
    return url;
  }

  global.Auth = {
    startLogin,
    handleRedirectCallback,
    ensureValidToken,
    refreshTokens,
    logout,
    isAuthenticated,
    hasAdminScope,
    getAccessToken,
    getIdToken,
    getProfile,
    requireAuth,
    requireAdmin,
    consumeReturnTo,
  };
})(window);
