'use strict';

const AppError = require('../errors/AppError');

function fail(message) {
  throw new AppError(422, message, 'validacion');
}

function parseId(raw) {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) fail('El id debe ser un entero positivo.');
  return id;
}

function validarIniciarPago(body = {}) {
  const reservaId = parseId(body.reserva_id);
  return { reservaId };
}

module.exports = { parseId, validarIniciarPago };
