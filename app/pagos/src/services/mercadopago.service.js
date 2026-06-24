'use strict';

const { MercadoPagoConfig, Preference, Payment } = require('mercadopago');

const { config } = require('../config');
const { getMpSecret } = require('../db/mpSecrets');

/**
 * Wrapper del SDK de Mercado Pago (modo sandbox/test). El access token se lee
 * de Secrets Manager en runtime y se cachea el cliente. Nunca se loguea.
 */

let cachedClient = null;

async function getClient() {
  if (cachedClient) return cachedClient;

  const { access_token: accessToken } = await getMpSecret();
  if (!accessToken) {
    throw new Error('El secret de Mercado Pago no contiene access_token.');
  }

  cachedClient = new MercadoPagoConfig({
    accessToken,
    options: { timeout: 8000 },
  });
  return cachedClient;
}

/**
 * Crea una preferencia de pago. external_reference = id interno del Pago, que
 * es como reconciliamos la notificacion del webhook con nuestro registro.
 */
async function crearPreferencia({ pagoId, descripcion, monto, emailComprador }) {
  const client = await getClient();
  const preference = new Preference(client);

  const body = {
    items: [
      {
        id: String(pagoId),
        title: descripcion,
        quantity: 1,
        unit_price: Number(monto),
        currency_id: config.mpCurrency,
      },
    ],
    external_reference: String(pagoId),
    ...(emailComprador ? { payer: { email: emailComprador } } : {}),
    ...(config.mpNotificationUrl ? { notification_url: config.mpNotificationUrl } : {}),
    ...(config.appBaseUrl
      ? {
          // Las tres vuelven a confirmacion.html: esa pagina consulta al backend
          // el estado REAL del pago/reserva (no confia en los query params de MP).
          // appBaseUrl es configurable via APP_BASE_URL (inyectado por ECS).
          back_urls: {
            success: `${config.appBaseUrl}/confirmacion.html`,
            failure: `${config.appBaseUrl}/confirmacion.html`,
            pending: `${config.appBaseUrl}/confirmacion.html`,
          },
          auto_return: 'approved',
        }
      : {}),
  };

  const result = await preference.create({ body });
  return {
    id: result.id,
    initPoint: result.init_point,
    sandboxInitPoint: result.sandbox_init_point,
  };
}

/**
 * Consulta el estado REAL de un pago en Mercado Pago. Es la fuente de verdad:
 * jamas confiamos en el payload del webhook para decidir si un pago es valido.
 */
async function obtenerPago(paymentId) {
  const client = await getClient();
  const payment = new Payment(client);
  return payment.get({ id: paymentId });
}

module.exports = { crearPreferencia, obtenerPago };
