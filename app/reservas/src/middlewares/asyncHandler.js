'use strict';

/**
 * Envuelve un handler async para que cualquier rechazo de promesa termine en
 * el middleware de errores de Express (en vez de quedar como unhandled
 * rejection y, potencialmente, tumbar el proceso → DISPONIBILIDAD).
 */
module.exports = function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
};
