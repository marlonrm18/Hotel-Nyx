'use strict';

/**
 * Resumen final tras volver de Mercado Pago.
 *
 * La verificacion es del lado SERVIDOR: consultamos el estado real del pago y
 * de la reserva al backend (no confiamos en los query params que agrega MP).
 * Consume: GET /api/pagos/:id  y  GET /api/reservas/:id
 */
(function () {
  if (!window.Auth.requireAuth()) return;

  const message = document.getElementById('message');
  const detalle = document.getElementById('detalle');
  const estadoBox = document.getElementById('estado-box');
  const refrescarBtn = document.getElementById('refrescar-btn');

  // MP puede agregar external_reference (= id del pago) y/o payment_id.
  const pagoId = UI.qs('external_reference') || sessionStorage.getItem('nyx_pago_id');
  const reservaId = sessionStorage.getItem('nyx_reserva_id');

  function pintarEstado(estadoPago) {
    const mapa = {
      aprobado: { txt: '✅ Pago aprobado — reserva confirmada', cls: 'ok' },
      rechazado: { txt: '❌ Pago rechazado', cls: 'warn' },
      pendiente: { txt: '⏳ Pago pendiente de confirmacion', cls: 'info' },
    };
    const info = mapa[estadoPago] || { txt: `Estado: ${estadoPago}`, cls: 'info' };
    estadoBox.className = 'badge badge--' + info.cls;
    estadoBox.textContent = info.txt;
    estadoBox.hidden = false;
  }

  async function cargar() {
    UI.showInfo(message, 'Consultando el estado de tu pago…');
    detalle.innerHTML = '';
    try {
      if (!pagoId) {
        UI.showError(message, { message: 'No encontramos el pago. Revisa "Mis reservas".' });
        return;
      }

      const pago = await window.Api.obtenerPago(pagoId);
      pintarEstado(pago.estado);

      let reservaHtml = '';
      const rid = reservaId || pago.reservaId;
      if (rid) {
        try {
          const r = await window.Api.obtenerReserva(rid);
          reservaHtml = `
            <h3>Reserva #${UI.escapeHtml(r.id)}</h3>
            <p>Huesped: ${UI.escapeHtml(r.nombreHuesped)} (${UI.escapeHtml(r.emailHuesped)})</p>
            <p>Habitacion: ${UI.escapeHtml(r.habitacion ? r.habitacion.numero : r.habitacionId)}</p>
            <p>Del ${UI.fecha(r.fechaInicio)} al ${UI.fecha(r.fechaFin)}</p>
            <p class="badge badge--info">Reserva: ${UI.escapeHtml(r.estado)}</p>`;
        } catch (e) {
          reservaHtml = '';
        }
      }

      detalle.innerHTML = `
        ${reservaHtml}
        <h3>Pago #${UI.escapeHtml(pago.id)}</h3>
        <p class="card__precio">$${UI.money(pago.monto)}</p>`;

      UI.clearMessage(message);
      if (pago.estado === 'pendiente') {
        UI.showInfo(message, 'El pago todavia se esta procesando. Podes refrescar en unos segundos.');
        refrescarBtn.hidden = false;
      }
    } catch (err) {
      UI.showError(message, err);
    }
  }

  if (refrescarBtn) refrescarBtn.addEventListener('click', cargar);
  cargar();
})();
