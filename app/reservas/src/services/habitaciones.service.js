'use strict';

const { getPrisma } = require('../db');

const ESTADOS_ACTIVOS = ['pendiente', 'confirmada'];

async function listHabitaciones({ estado } = {}) {
  const prisma = await getPrisma();
  return prisma.habitacion.findMany({
    where: estado ? { estado } : undefined,
    orderBy: { numero: 'asc' },
  });
}

async function getHabitacion(id) {
  const prisma = await getPrisma();
  return prisma.habitacion.findUnique({ where: { id } });
}

async function createHabitacion(data) {
  const prisma = await getPrisma();
  return prisma.habitacion.create({ data });
}

/**
 * Habitaciones libres en un rango [fechaInicio, fechaFin) usando solape
 * half-open: una reserva activa choca si  inicio < fechaFin  Y  fin > fechaInicio.
 * Asi, una reserva que termina justo cuando empieza el rango NO bloquea
 * (checkout == check-in permitido), consistente con la EXCLUSION CONSTRAINT '[)'.
 */
async function findDisponibles({ fechaInicio, fechaFin, capacidad }) {
  const prisma = await getPrisma();
  return prisma.habitacion.findMany({
    where: {
      estado: 'disponible',
      ...(capacidad ? { capacidad: { gte: capacidad } } : {}),
      reservas: {
        none: {
          estado: { in: ESTADOS_ACTIVOS },
          fechaInicio: { lt: fechaFin },
          fechaFin: { gt: fechaInicio },
        },
      },
    },
    orderBy: { numero: 'asc' },
  });
}

module.exports = { listHabitaciones, getHabitacion, createHabitacion, findDisponibles };
