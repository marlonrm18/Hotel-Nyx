'use strict';

/**
 * Error operacional con codigo HTTP y codigo de aplicacion.
 * Se usa para errores esperados (validacion, no encontrado, conflicto) que
 * SI podemos mostrar al cliente. Los errores inesperados nunca exponen
 * detalles internos (ver errorHandler).
 */
class AppError extends Error {
  constructor(statusCode, message, code = 'error') {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
