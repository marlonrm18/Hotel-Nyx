'use strict';

/**
 * Checkout de Mercado Pago (sandbox).
 *
 * Conexion con el backend y con MP:
 *   1. POST /api/pagos { reserva_id }  → el BACKEND calcula el monto (server-side),
 *      crea la preferencia en MP y devuelve { pagoId, preferenceId, initPoint }.
 *   2. El frontend NO toca datos de tarjeta: o bien redirige al init_point
 *      (Checkout Pro), o renderiza el Wallet Brick del SDK de MP con la PUBLIC KEY
 *      y el preferenceId. La tarjeta se captura en el entorno de Mercado Pago.
 *   3. Al pagar, MP redirige a back_urls (configuradas por el backend) y la
 *      verificacion real ocurre en el webhook del backend, no aqui.
 */
(function () {
  if (!window.Auth.requireAuth()) return;

  const CFG = window.HOTEL_NYX_CONFIG;
  const message = document.getElementById('message');
  const resumen = document.getElementById('resumen-reserva');
  const pagarBtn = document.getElementById('pagar-btn');
  const walletContainer = document.getElementById('wallet_container');
  const initPointLink = document.getElementById('init-point-link');

  const reservaId = UI.qs('reserva_id') || sessionStorage.getItem('nyx_reserva_id');

  async function cargarReserva() {
    if (!reservaId) {
      UI.showError(message, { message: 'No hay una reserva para pagar. Volve a empezar.' });
      pagarBtn.disabled = true;
      return;
    }
    try {
      const r = await window.Api.obtenerReserva(reservaId);
      resumen.innerHTML = `
        <h3>Reserva #${UI.escapeHtml(r.id)}</h3>
        <p>Huesped: ${UI.escapeHtml(r.nombreHuesped)}</p>
        <p>Habitacion: ${UI.escapeHtml(r.habitacion ? r.habitacion.numero : r.habitacionId)}</p>
        <p>Del ${UI.fecha(r.fechaInicio)} al ${UI.fecha(r.fechaFin)}</p>
        <p class="badge badge--info">Estado: ${UI.escapeHtml(r.estado)}</p>`;
      if (r.estado !== 'pendiente') {
        UI.showInfo(message, 'Esta reserva ya no esta pendiente de pago.');
        pagarBtn.disabled = true;
      }
    } catch (err) {
      UI.showError(message, err);
    }
  }

  function renderWallet(preferenceId, initPoint) {
    // Enlace de respaldo (Checkout Pro) por si el SDK no carga.
    if (initPoint) {
      initPointLink.href = initPoint;
      initPointLink.hidden = false;
    }

    if (!window.MercadoPago || !CFG.MP_PUBLIC_KEY || CFG.MP_PUBLIC_KEY.indexOf('REEMPLAZAR') === 0) {
      // Sin SDK/clave: caemos a la redireccion directa al init_point.
      if (initPoint) window.location.assign(initPoint);
      return;
    }

    try {
      const mp = new window.MercadoPago(CFG.MP_PUBLIC_KEY, { locale: 'es-AR' });
      walletContainer.innerHTML = '';
      mp.bricks().create('wallet', 'wallet_container', {
        initialization: { preferenceId: preferenceId },
      });
    } catch (err) {
      if (initPoint) window.location.assign(initPoint);
    }
  }

  pagarBtn.addEventListener('click', async () => {
    UI.clearMessage(message);
    UI.setLoading(pagarBtn, true, 'Iniciando pago…');
    try {
      const pago = await window.Api.iniciarPago(Number(reservaId));
      sessionStorage.setItem('nyx_pago_id', String(pago.pagoId));
      sessionStorage.setItem('nyx_reserva_id', String(reservaId));
      UI.showInfo(message, `Total a pagar: $${UI.money(pago.monto)} (${pago.noches} noche/s).`);
      pagarBtn.hidden = true;
      renderWallet(pago.preferenceId, pago.initPoint);
    } catch (err) {
      UI.showError(message, err);
      UI.setLoading(pagarBtn, false);
    }
  });

  cargarReserva();
})();
