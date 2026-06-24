'use strict';

const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');

const { config } = require('../config');
const logger = require('../lib/logger');

/**
 * Envio del correo de confirmacion de reserva via SES.
 *
 * Regla clave: el fallo de SES NUNCA debe romper la confirmacion del pago. El
 * pago ya es valido aunque el correo falle; aqui solo logueamos el error y
 * devolvemos un resultado para que el llamador pueda registrar un reintento.
 * Por eso esta funcion NO lanza excepciones hacia arriba.
 */

let cachedClient = null;

function getSesClient() {
  if (!cachedClient) {
    cachedClient = new SESClient({ region: config.awsRegion });
  }
  return cachedClient;
}

function fmtFecha(value) {
  const d = value instanceof Date ? value : new Date(value);
  return Number.isNaN(d.getTime()) ? String(value) : d.toISOString().slice(0, 10);
}

function fmtMonto(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n.toFixed(2) : String(value);
}

async function enviarConfirmacionReserva({
  to,
  nombreHuesped,
  habitacionNumero,
  fechaInicio,
  fechaFin,
  monto,
}) {
  if (!config.mailFrom) {
    logger.warn('MAIL_FROM no configurado; se omite el envio del correo de confirmacion.');
    return { sent: false, reason: 'mail_from_no_configurado' };
  }

  const inicio = fmtFecha(fechaInicio);
  const fin = fmtFecha(fechaFin);
  const total = fmtMonto(monto);

  const subject = 'Confirmacion de tu reserva — Hotel Nyx';
  const text =
    `Hola ${nombreHuesped},\n\n` +
    `Tu pago fue aprobado y tu reserva quedo CONFIRMADA.\n\n` +
    `Habitacion: ${habitacionNumero}\n` +
    `Check-in:  ${inicio}\n` +
    `Check-out: ${fin}\n` +
    `Monto pagado: $${total}\n\n` +
    `Gracias por elegir Hotel Nyx.`;
  const html =
    `<h2>Reserva confirmada — Hotel Nyx</h2>` +
    `<p>Hola <strong>${nombreHuesped}</strong>, tu pago fue aprobado y tu reserva quedo <strong>confirmada</strong>.</p>` +
    `<ul>` +
    `<li>Habitacion: <strong>${habitacionNumero}</strong></li>` +
    `<li>Check-in: <strong>${inicio}</strong></li>` +
    `<li>Check-out: <strong>${fin}</strong></li>` +
    `<li>Monto pagado: <strong>$${total}</strong></li>` +
    `</ul>` +
    `<p>Gracias por elegir Hotel Nyx.</p>`;

  try {
    const result = await getSesClient().send(
      new SendEmailCommand({
        Source: config.mailFrom,
        Destination: { ToAddresses: [to] },
        Message: {
          Subject: { Data: subject, Charset: 'UTF-8' },
          Body: {
            Text: { Data: text, Charset: 'UTF-8' },
            Html: { Data: html, Charset: 'UTF-8' },
          },
        },
      })
    );
    logger.info({ to, messageId: result.MessageId }, 'correo de confirmacion enviado');
    return { sent: true, messageId: result.MessageId };
  } catch (err) {
    // No re-lanzar: el pago sigue siendo valido aunque el correo falle.
    logger.error({ err, to }, 'fallo el envio del correo de confirmacion (pago ya valido; reintentar)');
    return { sent: false, reason: 'ses_error' };
  }
}

module.exports = { enviarConfirmacionReserva };
