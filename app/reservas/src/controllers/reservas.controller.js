'use strict';

const asyncHandler = require('../middlewares/asyncHandler');
const AppError = require('../errors/AppError');
const validators = require('../validators');
const service = require('../services/reservas.service');

const crear = asyncHandler(async (req, res) => {
  const data = validators.validarCrearReserva(req.body);
  const reserva = await service.crearReserva(data);
  res.status(201).json(reserva);
});

const listar = asyncHandler(async (req, res) => {
  const filtros = {};
  const estado = validators.validarEstadoReserva(req.query.estado);
  if (estado) filtros.estado = estado;
  if (req.query.email_huesped) {
    filtros.emailHuesped = String(req.query.email_huesped).trim().toLowerCase();
  }
  if (req.query.habitacion_id) {
    filtros.habitacionId = validators.parseId(req.query.habitacion_id);
  }

  const reservas = await service.listReservas(filtros);
  res.json(reservas);
});

const obtener = asyncHandler(async (req, res) => {
  const id = validators.parseId(req.params.id);
  const reserva = await service.getReserva(id);
  if (!reserva) throw new AppError(404, 'Reserva no encontrada.', 'reserva_no_encontrada');
  res.json(reserva);
});

const confirmar = asyncHandler(async (req, res) => {
  const id = validators.parseId(req.params.id);
  const reserva = await service.confirmarReserva(id);
  res.json(reserva);
});

const cancelar = asyncHandler(async (req, res) => {
  const id = validators.parseId(req.params.id);
  const reserva = await service.cancelarReserva(id);
  res.json(reserva);
});

module.exports = { crear, listar, obtener, confirmar, cancelar };
