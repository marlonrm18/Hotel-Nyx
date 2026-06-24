'use strict';

const asyncHandler = require('../middlewares/asyncHandler');
const AppError = require('../errors/AppError');
const validators = require('../validators');
const service = require('../services/habitaciones.service');

const listar = asyncHandler(async (req, res) => {
  const estado = req.query.estado
    ? validators.ESTADOS_HABITACION.includes(String(req.query.estado))
      ? String(req.query.estado)
      : (() => { throw new AppError(422, 'estado invalido.', 'validacion'); })()
    : undefined;

  const habitaciones = await service.listHabitaciones({ estado });
  res.json(habitaciones);
});

const disponibles = asyncHandler(async (req, res) => {
  const rango = validators.validarRangoFechas(req.query);
  const habitaciones = await service.findDisponibles(rango);
  res.json(habitaciones);
});

const obtener = asyncHandler(async (req, res) => {
  const id = validators.parseId(req.params.id);
  const habitacion = await service.getHabitacion(id);
  if (!habitacion) throw new AppError(404, 'Habitacion no encontrada.', 'habitacion_no_encontrada');
  res.json(habitacion);
});

const crear = asyncHandler(async (req, res) => {
  const data = validators.validarCrearHabitacion(req.body);
  const habitacion = await service.createHabitacion(data);
  res.status(201).json(habitacion);
});

module.exports = { listar, disponibles, obtener, crear };
