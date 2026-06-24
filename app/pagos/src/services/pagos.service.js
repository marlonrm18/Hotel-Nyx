'use strict';

const { getPrisma } = require('../db');
const { getMpSecret } = require('../db/mpSecrets');
const { verifyWebhookSignature } = require('../lib/mpSignature');
const AppError = require('../errors/AppError');
const logger = require('../lib/logger');
const mp = require('./mercadopago.service');
const email = require('./email.service');

const MS_POR_DIA = 24 * 60 * 60 * 1000;

function calcularNoches(fechaInicio, fechaFin) {
  const noches = Math.round((new Date(fechaFin) - new Date(fechaInicio)) / MS_POR_DIA);
  return noches > 0 ? noches : 0;
}

async function getPago(id) {
  const prisma = await getPrisma();
  return prisma.pago.findUnique({ where: { id } });
}

/**
 * Inicia un pago: valida la reserva, calcula el monto EN EL SERVIDOR
 * (noches × precio_noche — el cliente nunca decide el monto), crea el registro
 * Pago en estado pendiente y la preferencia en Mercado Pago. No marca nada como
 * pagado todavia.
 */
async function iniciarPago({ reservaId }) {
  const prisma = await getPrisma();

  const reserva = await prisma.reserva.findUnique({
    where: { id: reservaId },
    include: { habitacion: true },
  });
  if (!reserva) {
    throw new AppError(404, 'La reserva indicada no existe.', 'reserva_no_encontrada');
  }
  if (reserva.estado !== 'pendiente') {
    throw new AppError(409, 'La reserva no esta en estado pendiente.', 'estado_invalido');
  }

  // Si ya hay un pago aprobado para esta reserva, no iniciar otro.
  const yaAprobado = await prisma.pago.findFirst({
    where: { reservaId, estado: 'aprobado' },
  });
  if (yaAprobado) {
    throw new AppError(409, 'La reserva ya tiene un pago aprobado.', 'pago_ya_aprobado');
  }

  const noches = calcularNoches(reserva.fechaInicio, reserva.fechaFin);
  if (noches <= 0) {
    throw new AppError(422, 'El rango de fechas de la reserva es invalido.', 'rango_invalido');
  }
  const monto = Number(reserva.habitacion.precioNoche) * noches;

  // El id del Pago es el external_reference que vincula la notificacion del
  // webhook con este registro.
  const pago = await prisma.pago.create({
    data: { reservaId, monto, estado: 'pendiente' },
  });

  let preferencia;
  try {
    preferencia = await mp.crearPreferencia({
      pagoId: pago.id,
      descripcion: `Reserva #${reservaId} — Habitacion ${reserva.habitacion.numero}`,
      monto,
      emailComprador: reserva.emailHuesped,
    });
  } catch (err) {
    logger.error({ err, pagoId: pago.id }, 'fallo al crear la preferencia en Mercado Pago');
    throw new AppError(502, 'No se pudo iniciar el pago con Mercado Pago.', 'mp_error');
  }

  return {
    pagoId: pago.id,
    preferenceId: preferencia.id,
    // En sandbox se usa sandbox_init_point.
    initPoint: preferencia.sandboxInitPoint || preferencia.initPoint,
    monto,
    noches,
  };
}

/**
 * Valida la autenticidad de la notificacion del webhook (firma HMAC con el
 * webhook_secret leido de Secrets Manager). Sin firma valida, no se procesa.
 */
async function notificacionValida({ xSignature, xRequestId, dataId }) {
  const { webhook_secret: webhookSecret } = await getMpSecret();
  if (!webhookSecret) {
    logger.error('webhook_secret ausente en el secret de Mercado Pago; rechazando notificacion');
    return false;
  }
  return verifyWebhookSignature({ xSignature, xRequestId, dataId, secret: webhookSecret });
}

/**
 * Procesa la notificacion de un pago. Pasos:
 *  1. Consulta el estado REAL del pago en MP (fuente de verdad).
 *  2. Reconcilia via external_reference → registro Pago local.
 *  3. Verifica el monto (seguridad): debe coincidir con el calculado.
 *  4. Transicion atomica (transaccion): Pago → aprobado/rechazado y, si
 *     aprobado, Reserva → confirmada.
 *  5. Idempotencia: la transicion usa updateMany WHERE estado='pendiente'; si
 *     count === 0 la notificacion ya fue procesada → no repite efectos
 *     (ni correo). El mp_payment_id queda como clave de reconciliacion.
 *  6. Solo tras una transicion real a 'aprobado' se dispara el correo (SES).
 */
async function procesarNotificacion({ tipo, dataId }) {
  // Solo nos interesan notificaciones de pagos.
  if (tipo && tipo !== 'payment') {
    return { handled: false, reason: 'tipo_ignorado' };
  }
  if (!dataId) {
    throw new AppError(400, 'Falta data.id en la notificacion.', 'notificacion_invalida');
  }

  // 1. Estado real en Mercado Pago.
  const pagoMp = await mp.obtenerPago(dataId);
  const paymentId = String(pagoMp.id);
  const status = pagoMp.status; // approved | rejected | cancelled | pending | in_process
  const montoMp = pagoMp.transaction_amount;
  const externalReference = pagoMp.external_reference;

  if (!externalReference) {
    logger.warn({ paymentId }, 'pago de MP sin external_reference; se ignora');
    return { handled: false, reason: 'sin_external_reference' };
  }
  const pagoId = Number(externalReference);

  const prisma = await getPrisma();
  const pago = await prisma.pago.findUnique({
    where: { id: pagoId },
    include: { reserva: { include: { habitacion: true } } },
  });
  if (!pago) {
    logger.warn({ pagoId, paymentId }, 'no existe el Pago referenciado por la notificacion');
    return { handled: false, reason: 'pago_no_encontrado' };
  }

  // Idempotencia rapida: ya procesado con este mismo payment id.
  if (pago.estado !== 'pendiente' && pago.mpPaymentId === paymentId) {
    return { handled: true, idempotent: true, estado: pago.estado };
  }

  const aprobado = status === 'approved';
  const rechazado = status === 'rejected' || status === 'cancelled';

  // Estados intermedios (pending/in_process): guardamos el payment id y
  // esperamos una notificacion posterior. No tocamos la reserva.
  if (!aprobado && !rechazado) {
    await prisma.pago
      .updateMany({ where: { id: pagoId, estado: 'pendiente' }, data: { mpPaymentId: paymentId } })
      .catch((err) => logger.error({ err, pagoId }, 'no se pudo guardar mpPaymentId intermedio'));
    return { handled: true, estado: 'pendiente', mpStatus: status };
  }

  // 3. Verificacion de monto del lado servidor (anti-manipulacion).
  if (aprobado && montoMp != null && Number(montoMp) !== Number(pago.monto)) {
    logger.error(
      { pagoId, paymentId, montoMp, esperado: Number(pago.monto) },
      'monto del pago no coincide con el esperado; se marca rechazado'
    );
    await prisma.pago.updateMany({
      where: { id: pagoId, estado: 'pendiente' },
      data: { estado: 'rechazado', mpPaymentId: paymentId },
    });
    return { handled: true, estado: 'rechazado', reason: 'monto_no_coincide' };
  }

  const nuevoEstado = aprobado ? 'aprobado' : 'rechazado';

  // 4 + 5. Transicion atomica e idempotente.
  const transiciono = await prisma.$transaction(async (tx) => {
    const upd = await tx.pago.updateMany({
      where: { id: pagoId, estado: 'pendiente' },
      data: { estado: nuevoEstado, mpPaymentId: paymentId },
    });
    if (upd.count === 0) return false; // otra ejecucion ya lo proceso

    if (aprobado) {
      await tx.reserva.update({
        where: { id: pago.reservaId },
        data: { estado: 'confirmada' },
      });
    }
    return true;
  });

  if (!transiciono) {
    return { handled: true, idempotent: true, estado: nuevoEstado };
  }

  // 6. Efecto secundario SOLO tras una transicion real a aprobado.
  if (aprobado) {
    await email.enviarConfirmacionReserva({
      to: pago.reserva.emailHuesped,
      nombreHuesped: pago.reserva.nombreHuesped,
      habitacionNumero: pago.reserva.habitacion.numero,
      fechaInicio: pago.reserva.fechaInicio,
      fechaFin: pago.reserva.fechaFin,
      monto: pago.monto,
    });
  }

  return { handled: true, estado: nuevoEstado };
}

module.exports = { getPago, iniciarPago, notificacionValida, procesarNotificacion, calcularNoches };
