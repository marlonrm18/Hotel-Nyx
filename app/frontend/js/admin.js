'use strict';

/**
 * Panel de administracion. Solo accesible si el access token tiene el scope
 * hotel-api/admin:write (o el grupo Cognito `admin`); si no, redirige a login.
 *
 * Cada pagina del admin define window.ADMIN_PAGE = 'dashboard'|'habitaciones'|'reservas'.
 * Usa unicamente endpoints REALES del backend.
 */
(function () {
  if (!window.Auth.requireAdmin()) return;

  const page = window.ADMIN_PAGE;
  const message = document.getElementById('message');

  // ─── Dashboard ───────────────────────────────────────────────────────────────
  async function initDashboard() {
    const box = document.getElementById('metricas');
    UI.showInfo(message, 'Cargando metricas…');
    try {
      const [habitaciones, reservas] = await Promise.all([
        window.Api.listarHabitaciones(),
        window.Api.listarReservas(),
      ]);

      const totalHab = habitaciones.length;
      const disponibles = habitaciones.filter((h) => h.estado === 'disponible').length;
      const porEstado = reservas.reduce((acc, r) => {
        acc[r.estado] = (acc[r.estado] || 0) + 1;
        return acc;
      }, {});

      box.innerHTML = `
        <div class="metric"><span class="metric__num">${totalHab}</span><span>Habitaciones</span></div>
        <div class="metric"><span class="metric__num">${disponibles}</span><span>Disponibles</span></div>
        <div class="metric"><span class="metric__num">${porEstado.confirmada || 0}</span><span>Reservas confirmadas</span></div>
        <div class="metric"><span class="metric__num">${porEstado.pendiente || 0}</span><span>Reservas pendientes</span></div>
        <div class="metric"><span class="metric__num">${porEstado.cancelada || 0}</span><span>Reservas canceladas</span></div>`;
      UI.clearMessage(message);
    } catch (err) {
      UI.showError(message, err);
    }
  }

  // ─── Gestion de habitaciones ─────────────────────────────────────────────────
  async function initHabitaciones() {
    const tabla = document.getElementById('tabla-habitaciones');
    const form = document.getElementById('habitacion-form');
    const submitBtn = form.querySelector('button[type="submit"]');

    async function recargar() {
      try {
        const lista = await window.Api.listarHabitaciones();
        tabla.innerHTML = lista
          .map(
            (h) => `
          <tr>
            <td>${UI.escapeHtml(h.numero)}</td>
            <td>${UI.escapeHtml(h.tipo)}</td>
            <td>${UI.escapeHtml(h.capacidad)}</td>
            <td>$${UI.money(h.precioNoche)}</td>
            <td><span class="badge badge--${h.estado === 'disponible' ? 'ok' : 'warn'}">${UI.escapeHtml(h.estado)}</span></td>
          </tr>`
          )
          .join('');
      } catch (err) {
        UI.showError(message, err);
      }
    }

    form.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      UI.clearMessage(message);
      const payload = {
        numero: Number(document.getElementById('numero').value),
        tipo: document.getElementById('tipo').value.trim(),
        capacidad: Number(document.getElementById('capacidad').value),
        precio_noche: Number(document.getElementById('precio_noche').value),
        estado: document.getElementById('estado').value,
      };
      UI.setLoading(submitBtn, true, 'Guardando…');
      try {
        await window.Api.crearHabitacion(payload);
        UI.showSuccess(message, `Habitacion ${payload.numero} creada.`);
        form.reset();
        recargar();
      } catch (err) {
        UI.showError(message, err);
      } finally {
        UI.setLoading(submitBtn, false);
      }
    });

    recargar();
  }

  // ─── Reservas + acciones ─────────────────────────────────────────────────────
  async function initReservas() {
    const tabla = document.getElementById('tabla-reservas');
    const filtro = document.getElementById('filtro-estado');

    async function recargar() {
      UI.showInfo(message, 'Cargando reservas…');
      try {
        const query = filtro.value ? { estado: filtro.value } : undefined;
        const lista = await window.Api.listarReservas(query);
        UI.clearMessage(message);
        if (!lista.length) {
          tabla.innerHTML = '<tr><td colspan="6" class="empty">Sin reservas.</td></tr>';
          return;
        }
        tabla.innerHTML = lista
          .map(
            (r) => `
          <tr>
            <td>${UI.escapeHtml(r.id)}</td>
            <td>${UI.escapeHtml(r.nombreHuesped)}</td>
            <td>${UI.escapeHtml(r.habitacionId)}</td>
            <td>${UI.fecha(r.fechaInicio)} → ${UI.fecha(r.fechaFin)}</td>
            <td><span class="badge badge--info">${UI.escapeHtml(r.estado)}</span></td>
            <td>
              <button class="btn btn--small" data-accion="confirmar" data-id="${r.id}" ${r.estado !== 'pendiente' ? 'disabled' : ''}>Confirmar</button>
              <button class="btn btn--small btn--danger" data-accion="cancelar" data-id="${r.id}" ${r.estado === 'cancelada' ? 'disabled' : ''}>Cancelar</button>
            </td>
          </tr>`
          )
          .join('');
      } catch (err) {
        UI.showError(message, err);
      }
    }

    tabla.addEventListener('click', async (ev) => {
      const btn = ev.target.closest('button[data-accion]');
      if (!btn) return;
      const id = btn.dataset.id;
      btn.disabled = true;
      try {
        if (btn.dataset.accion === 'confirmar') await window.Api.confirmarReserva(id);
        else await window.Api.cancelarReserva(id);
        recargar();
      } catch (err) {
        UI.showError(message, err);
        btn.disabled = false;
      }
    });

    filtro.addEventListener('change', recargar);
    recargar();
  }

  if (page === 'dashboard') initDashboard();
  else if (page === 'habitaciones') initHabitaciones();
  else if (page === 'reservas') initReservas();
})();
