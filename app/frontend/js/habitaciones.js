'use strict';

/**
 * Buscar disponibilidad y listar habitaciones.
 * Consume: GET /api/reservas/habitaciones[/disponibles]
 */
(function () {
  if (!window.Auth.requireAuth()) return;

  const form = document.getElementById('search-form');
  const resultados = document.getElementById('resultados');
  const message = document.getElementById('message');
  const submitBtn = form.querySelector('button[type="submit"]');

  function cardHabitacion(h, fechaInicio, fechaFin) {
    const params = new URLSearchParams({ habitacion_id: h.id });
    if (fechaInicio) params.set('fecha_inicio', fechaInicio);
    if (fechaFin) params.set('fecha_fin', fechaFin);

    const disponible = h.estado === 'disponible';
    return `
      <article class="card" aria-label="Habitacion ${UI.escapeHtml(h.numero)}">
        <h3>Habitacion ${UI.escapeHtml(h.numero)}</h3>
        <p class="card__tipo">${UI.escapeHtml(h.tipo)} · ${UI.escapeHtml(h.capacidad)} huesped(es)</p>
        <p class="card__precio">$${UI.money(h.precioNoche)} / noche</p>
        <p class="badge badge--${disponible ? 'ok' : 'warn'}">${UI.escapeHtml(h.estado)}</p>
        ${
          disponible
            ? `<a class="btn btn--primary" href="reserva.html?${params.toString()}">Reservar</a>`
            : `<button class="btn" disabled>No disponible</button>`
        }
      </article>`;
  }

  function render(lista, fechaInicio, fechaFin) {
    if (!lista || lista.length === 0) {
      resultados.innerHTML = '<p class="empty">No hay habitaciones que coincidan con la busqueda.</p>';
      return;
    }
    resultados.innerHTML = lista.map((h) => cardHabitacion(h, fechaInicio, fechaFin)).join('');
  }

  async function cargarTodas() {
    UI.showInfo(message, 'Cargando habitaciones…');
    try {
      const lista = await window.Api.listarHabitaciones();
      UI.clearMessage(message);
      render(lista);
    } catch (err) {
      UI.showError(message, err);
      resultados.innerHTML = '';
    }
  }

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const fechaInicio = document.getElementById('fecha_inicio').value;
    const fechaFin = document.getElementById('fecha_fin').value;
    const capacidad = document.getElementById('capacidad').value;

    if (!fechaInicio || !fechaFin) {
      UI.showError(message, { message: 'Elegi fecha de entrada y de salida.' });
      return;
    }
    if (fechaFin <= fechaInicio) {
      UI.showError(message, { message: 'La fecha de salida debe ser posterior a la de entrada.' });
      return;
    }

    UI.setLoading(submitBtn, true, 'Buscando…');
    UI.showInfo(message, 'Buscando disponibilidad…');
    try {
      const lista = await window.Api.buscarDisponibles({
        fecha_inicio: fechaInicio,
        fecha_fin: fechaFin,
        capacidad: capacidad || undefined,
      });
      UI.clearMessage(message);
      render(lista, fechaInicio, fechaFin);
    } catch (err) {
      UI.showError(message, err);
      resultados.innerHTML = '';
    } finally {
      UI.setLoading(submitBtn, false);
    }
  });

  cargarTodas();
})();
