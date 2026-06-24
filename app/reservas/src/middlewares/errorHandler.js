'use strict';

const AppError = require('../errors/AppError');
const logger = require('../lib/logger');
const { isExclusionViolation, isUniqueViolation } = require('../db/prismaErrors');

/**
 * Middleware central de errores. Traduce errores conocidos a respuestas HTTP
 * limpias y, ante cualquier error inesperado, responde 500 SIN filtrar
 * detalles internos (seguridad).
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (err instanceof AppError) {
    logger.warn({ code: err.code, msg: err.message }, 'error operacional');
    return res.status(err.statusCode).json({ error: err.message, code: err.code });
  }

  // Guardia anti-doble-reserva a nivel BD (condicion de carrera).
  if (isExclusionViolation(err)) {
    logger.warn('exclusion_violation: reserva solapada rechazada por la BD');
    return res.status(409).json({
      error: 'Las fechas seleccionadas ya no estan disponibles para esa habitacion.',
      code: 'fechas_no_disponibles',
    });
  }

  if (isUniqueViolation(err)) {
    return res.status(409).json({
      error: 'Ya existe un recurso con ese valor unico.',
      code: 'conflicto_unicidad',
    });
  }

  // Inesperado: logueamos completo pero respondemos generico.
  logger.error({ err }, 'error no controlado');
  return res.status(500).json({ error: 'Error interno del servidor', code: 'internal_error' });
}

module.exports = errorHandler;
