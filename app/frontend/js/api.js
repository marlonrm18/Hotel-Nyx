'use strict';

/**
 * Wrapper de fetch para llamar al backend (API Gateway).
 *
 * - Antepone API_BASE_URL y serializa JSON.
 * - Adjunta Authorization: Bearer <access_token> (el access token lleva los
 *   scopes hotel-api/*). Refresca el token si esta por expirar.
 * - Traduce errores a un ApiError uniforme y maneja 401/403 de forma amigable
 *   (no deja pantallas en blanco → DISPONIBILIDAD percibida).
 *
 * Usa las RUTAS REALES del backend: /api/reservas/... y /api/pagos/...
 */
(function (global) {
  const CFG = global.HOTEL_NYX_CONFIG;

  class ApiError extends Error {
    constructor(message, status, code) {
      super(message);
      this.name = 'ApiError';
      this.status = status || 0;
      this.code = code || 'error';
    }
  }

  function buildUrl(path, query) {
    const base = CFG.API_BASE_URL.replace(/\/+$/, '');
    const url = new URL(base + path);
    if (query) {
      Object.entries(query).forEach(([k, v]) => {
        if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, v);
      });
    }
    return url.toString();
  }

  async function apiFetch(path, options) {
    const opts = options || {};
    const method = opts.method || 'GET';
    const requireAuth = opts.auth !== false;

    const headers = { Accept: 'application/json' };
    if (opts.body !== undefined) headers['Content-Type'] = 'application/json';

    if (requireAuth) {
      const ok = await global.Auth.ensureValidToken();
      const token = global.Auth.getAccessToken();
      if (!ok || !token) {
        redirectToLogin();
        throw new ApiError('Sesion expirada. Inicia sesion nuevamente.', 401, 'no_autenticado');
      }
      headers.Authorization = `Bearer ${token}`;
    }

    let resp;
    try {
      resp = await fetch(buildUrl(path, opts.query), {
        method,
        headers,
        body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
      });
    } catch (networkErr) {
      // fetch solo rechaza ante fallo de red / CORS, no por status HTTP.
      throw new ApiError(
        'No pudimos conectar con el servidor. Revisa tu conexion e intenta de nuevo.',
        0,
        'network'
      );
    }

    if (resp.status === 401) {
      redirectToLogin();
      throw new ApiError('Tu sesion expiro. Inicia sesion nuevamente.', 401, 'no_autenticado');
    }
    if (resp.status === 403) {
      throw new ApiError('No tienes permisos para realizar esta accion.', 403, 'sin_permiso');
    }
    if (resp.status === 204) return null;

    let data = null;
    const text = await resp.text();
    if (text) {
      try {
        data = JSON.parse(text);
      } catch (parseErr) {
        data = { error: text };
      }
    }

    if (!resp.ok) {
      const message = (data && data.error) || `Error ${resp.status}.`;
      const code = (data && data.code) || 'error';
      throw new ApiError(message, resp.status, code);
    }

    return data;
  }

  function redirectToLogin() {
    global.Auth.consumeReturnTo();
    sessionStorage.setItem('nyx_return_to', global.location.href);
    // Ruta relativa: funciona en raiz y en /admin/.
    const prefix = global.location.pathname.includes('/admin/') ? '../' : '';
    global.location.replace(prefix + 'login.html');
  }

  global.Api = {
    ApiError,
    request: apiFetch,
    get: (path, query) => apiFetch(path, { method: 'GET', query }),
    post: (path, body) => apiFetch(path, { method: 'POST', body }),
    patch: (path, body) => apiFetch(path, { method: 'PATCH', body }),

    // ─── Endpoints REALES del backend ─────────────────────────────────────────
    // Reservas
    buscarDisponibles: (q) => apiFetch('/api/reservas/habitaciones/disponibles', { query: q }),
    listarHabitaciones: (q) => apiFetch('/api/reservas/habitaciones', { query: q }),
    obtenerHabitacion: (id) => apiFetch(`/api/reservas/habitaciones/${id}`),
    crearHabitacion: (body) => apiFetch('/api/reservas/habitaciones', { method: 'POST', body }),
    crearReserva: (body) => apiFetch('/api/reservas', { method: 'POST', body }),
    listarReservas: (q) => apiFetch('/api/reservas', { query: q }),
    obtenerReserva: (id) => apiFetch(`/api/reservas/${id}`),
    confirmarReserva: (id) => apiFetch(`/api/reservas/${id}/confirmar`, { method: 'PATCH' }),
    cancelarReserva: (id) => apiFetch(`/api/reservas/${id}/cancelar`, { method: 'PATCH' }),
    // Pagos
    iniciarPago: (reservaId) => apiFetch('/api/pagos', { method: 'POST', body: { reserva_id: reservaId } }),
    obtenerPago: (id) => apiFetch(`/api/pagos/${id}`),
  };
})(window);
