'use strict';

const AppError = require('../errors/AppError');
const logger = require('../lib/logger');
const { isUniqueViolation } = require('../db/prismaErrors');

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
