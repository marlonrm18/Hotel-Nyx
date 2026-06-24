'use strict';

const asyncHandler = require('../middlewares/asyncHandler');
const AppError = require('../errors/AppError');
const validators = require('../validators');
const service = require('../services/pagos.service');
const logger = require('../lib/logger');

/**
 * POST /api/pagos — inicia un pago para una reserva pendiente.
 */
const iniciar = asyncHandler(async (req, res) => {
  const { reservaId } = validators.validarIniciarPago(req.body);
  const resultado = await service.iniciarPago({ reservaId });
  res.status(201).json(resultado);
});

/**
 * GET /api/pagos/:id — estado de un pago.
 */
const obtener = asyncHandler(async (req, res) => {
  const id = validators.parseId(req.params.id);
  const pago = await service.getPago(id);
  if (!pago) throw new AppError(404, 'Pago no encontrado.', 'pago_no_encontrado');
  res.json(pago);
});

/**
 * POST /api/pagos/webhook — notificacion de Mercado Pago.
 *
 * Flujo:
 *  1. Extrae data.id (query `data.id` o body) y el tipo (`type`/`topic`).
 *  2. Valida la FIRMA del webhook con el webhook_secret (Secrets Manager).
 *     Firma invalida → 401, sin procesar nada.
 *  3. Delega en el service, que consulta el estado real en MP y aplica la
 *     transicion de forma idempotente.
 *  4. Responde 200 para que MP deje de reintentar (incluso en no-procesados),
 *     salvo que la firma sea invalida.
 */
const webhook = asyncHandler(async (req, res) => {
  const dataId =
    req.query['data.id'] || req.query.id || (req.body && req.body.data && req.body.data.id);
  const tipo = req.query.type || req.query.topic || (req.body && req.body.type) || null;

  const xSignature = req.get('x-signature');
  const xRequestId = req.get('x-request-id');

  const valido = await service.notificacionValida({ xSignature, xRequestId, dataId });
  if (!valido) {
    logger.warn({ xRequestId }, 'firma de webhook invalida; notificacion rechazada');
    return res.status(401).json({ error: 'firma invalida', code: 'firma_invalida' });
  }

  const resultado = await service.procesarNotificacion({
    tipo,
    dataId: dataId != null ? String(dataId) : null,
  });

  return res.status(200).json({ received: true, ...resultado });
});

module.exports = { iniciar, obtener, webhook };
