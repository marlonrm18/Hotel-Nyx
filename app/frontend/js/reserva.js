'use strict';

/**
 * Crear una reserva (estado pendiente).
 * Consume: GET /api/reservas/habitaciones/:id  y  POST /api/reservas
 * Al crear, guarda nyx_reserva_id y navega a pago.html.
 */
(function () {
  if (!window.Auth.requireAuth()) return;

  const form = document.getElementById('reserva-form');
  const message = document.getElementById('message');
  const resumen = document.getElementById('resumen-habitacion');
  const submitBtn = form.querySelector('button[type="submit"]');

  const habitacionId = UI.qs('habitacion_id');
  const fechaInicioQs = UI.qs('fecha_inicio');
  const fechaFinQs = UI.qs('fecha_fin');

  // Prefill desde el perfil de Cognito (id token).
  const perfil = window.Auth.getProfile();
  if (perfil) {
    if (perfil.email) document.getElementById('email_huesped').value = perfil.email;
    if (perfil.name) document.getElementById('nombre_huesped').value = perfil.name;
  }
  if (fechaInicioQs) document.getElementById('fecha_inicio').value = fechaInicioQs;
  if (fechaFinQs) document.getElementById('fecha_fin').value = fechaFinQs;
  if (habitacionId) document.getElementById('habitacion_id').value = habitacionId;

  async function cargarHabitacion() {
    if (!habitacionId) {
      resumen.innerHTML = '<p class="empty">Elegi una habitacion desde la <a href="habitaciones.html">busqueda</a>.</p>';
      return;
    }
    try {
      const h = await window.Api.obtenerHabitacion(habitacionId);
      resumen.innerHTML = `
        <h3>Habitacion ${UI.escapeHtml(h.numero)}</h3>
        <p>${UI.escapeHtml(h.tipo)} · ${UI.escapeHtml(h.capacidad)} huesped(es)</p>
        <p class="card__precio">$${UI.money(h.precioNoche)} / noche</p>`;
    } catch (err) {
      UI.showError(message, err);
    }
  }

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    UI.clearMessage(message);

    const payload = {
      habitacion_id: Number(document.getElementById('habitacion_id').value),
      nombre_huesped: document.getElementById('nombre_huesped').value.trim(),
      email_huesped: document.getElementById('email_huesped').value.trim(),
      fecha_inicio: document.getElementById('fecha_inicio').value,
      fecha_fin: document.getElementById('fecha_fin').value,
    };

    if (!payload.habitacion_id) {
      UI.showError(message, { message: 'Falta la habitacion. Volve a la busqueda.' });
      return;
    }

    UI.setLoading(submitBtn, true, 'Creando reserva…');
    try {
      const reserva = await window.Api.crearReserva(payload);
      sessionStorage.setItem('nyx_reserva_id', String(reserva.id));
      window.location.assign(`pago.html?reserva_id=${reserva.id}`);
    } catch (err) {
      // 409 fechas_no_disponibles → mensaje claro de doble reserva.
      UI.showError(message, err);
      UI.setLoading(submitBtn, false);
    }
  });

  cargarHabitacion();
})();
