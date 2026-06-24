'use strict';

const AppError = require('../errors/AppError');

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

const ESTADOS_HABITACION = ['disponible', 'mantenimiento'];
const ESTADOS_RESERVA = ['pendiente', 'confirmada', 'cancelada'];

function fail(message) {
  throw new AppError(422, message, 'validacion');
}

function parseId(raw) {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) fail('El id debe ser un entero positivo.');
  return id;
}

function parseFecha(raw, campo) {
  if (typeof raw !== 'string' || !DATE_RE.test(raw)) {
    fail(`${campo} debe tener formato YYYY-MM-DD.`);
  }
  // Se interpreta como fecha "de calendario" en UTC (columna @db.Date).
  const date = new Date(`${raw}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) fail(`${campo} no es una fecha valida.`);
  return date;
}

function hoyUTC() {
  const hoy = new Date();
  hoy.setUTCHours(0, 0, 0, 0);
  return hoy;
}

// ─── Habitaciones ─────────────────────────────────────────────────────────────

function validarCrearHabitacion(body = {}) {
  const numero = Number(body.numero);
  if (!Number.isInteger(numero) || numero <= 0) fail('numero debe ser un entero positivo.');

  const tipo = String(body.tipo || '').trim();
  if (!tipo) fail('tipo es obligatorio.');

  const capacidad = Number(body.capacidad);
  if (!Number.isInteger(capacidad) || capacidad <= 0) fail('capacidad debe ser un entero positivo.');

  const precioNoche = Number(body.precio_noche);
  if (!Number.isFinite(precioNoche) || precioNoche <= 0) fail('precio_noche debe ser mayor a 0.');

  const estado = body.estado ? String(body.estado) : 'disponible';
  if (!ESTADOS_HABITACION.includes(estado)) {
    fail(`estado invalido. Valores: ${ESTADOS_HABITACION.join(', ')}.`);
  }

  return { numero, tipo, capacidad, precioNoche, estado };
}

function validarRangoFechas(query = {}) {
  const fechaInicio = parseFecha(query.fecha_inicio, 'fecha_inicio');
  const fechaFin = parseFecha(query.fecha_fin, 'fecha_fin');
  if (fechaFin <= fechaInicio) fail('fecha_fin debe ser posterior a fecha_inicio.');

  let capacidad;
  if (query.capacidad !== undefined) {
    capacidad = Number(query.capacidad);
    if (!Number.isInteger(capacidad) || capacidad <= 0) fail('capacidad debe ser un entero positivo.');
  }

  return { fechaInicio, fechaFin, capacidad };
}

// ─── Reservas ─────────────────────────────────────────────────────────────────

function validarCrearReserva(body = {}) {
  const habitacionId = parseId(body.habitacion_id);

  const nombreHuesped = String(body.nombre_huesped || '').trim();
  if (nombreHuesped.length < 2) fail('nombre_huesped es obligatorio.');

  const emailHuesped = String(body.email_huesped || '').trim().toLowerCase();
  if (!EMAIL_RE.test(emailHuesped)) fail('email_huesped no es valido.');

  const fechaInicio = parseFecha(body.fecha_inicio, 'fecha_inicio');
  const fechaFin = parseFecha(body.fecha_fin, 'fecha_fin');
  if (fechaFin <= fechaInicio) fail('fecha_fin debe ser posterior a fecha_inicio.');
  if (fechaInicio < hoyUTC()) fail('fecha_inicio no puede ser en el pasado.');

  return { habitacionId, nombreHuesped, emailHuesped, fechaInicio, fechaFin };
}

function validarEstadoReserva(raw) {
  if (raw === undefined) return undefined;
  const estado = String(raw);
  if (!ESTADOS_RESERVA.includes(estado)) {
    fail(`estado invalido. Valores: ${ESTADOS_RESERVA.join(', ')}.`);
  }
  return estado;
}

module.exports = {
  parseId,
  validarCrearHabitacion,
  validarRangoFechas,
  validarCrearReserva,
  validarEstadoReserva,
  ESTADOS_HABITACION,
  ESTADOS_RESERVA,
};
