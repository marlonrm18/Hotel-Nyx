'use strict';

const { getPrisma } = require('../db');
const AppError = require('../errors/AppError');

const ESTADOS_ACTIVOS = ['pendiente', 'confirmada'];

async function listReservas(filtros = {}) {
  const prisma = await getPrisma();
  const where = {};
  if (filtros.estado) where.estado = filtros.estado;
  if (filtros.emailHuesped) where.emailHuesped = filtros.emailHuesped;
  if (filtros.habitacionId) where.habitacionId = filtros.habitacionId;

  return prisma.reserva.findMany({ where, orderBy: { fechaInicio: 'asc' } });
}

async function getReserva(id) {
  const prisma = await getPrisma();
  return prisma.reserva.findUnique({
    where: { id },
    include: { habitacion: true },
  });
}

/**
 * Crea una reserva en estado `pendiente` con doble defensa anti-doble-reserva:
 *  1. Pre-chequeo de solapamiento (half-open) → mensaje amigable.
 *  2. La EXCLUSION CONSTRAINT de la BD es el guardia definitivo ante una
 *     condicion de carrera (dos reservas simultaneas que pasan el pre-chequeo);
 *     su violacion la traduce el errorHandler a 409 fechas_no_disponibles.
 */
async function crearReserva(data) {
  const prisma = await getPrisma();

  const habitacion = await prisma.habitacion.findUnique({ where: { id: data.habitacionId } });
  if (!habitacion) {
    throw new AppError(404, 'La habitacion indicada no existe.', 'habitacion_no_encontrada');
  }
  if (habitacion.estado !== 'disponible') {
    throw new AppError(409, 'La habitacion no esta disponible (en mantenimiento).', 'habitacion_no_disponible');
  }

  const solapada = await prisma.reserva.findFirst({
    where: {
      habitacionId: data.habitacionId,
      estado: { in: ESTADOS_ACTIVOS },
      fechaInicio: { lt: data.fechaFin },
      fechaFin: { gt: data.fechaInicio },
    },
  });
  if (solapada) {
    throw new AppError(409, 'Ya existe una reserva activa que se solapa con esas fechas.', 'fechas_no_disponibles');
  }

  return prisma.reserva.create({ data: { ...data, estado: 'pendiente' } });
}

async function confirmarReserva(id) {
  const prisma = await getPrisma();
  const reserva = await prisma.reserva.findUnique({ where: { id } });
  if (!reserva) throw new AppError(404, 'Reserva no encontrada.', 'reserva_no_encontrada');

  if (reserva.estado === 'cancelada') {
    throw new AppError(409, 'No se puede confirmar una reserva cancelada.', 'estado_invalido');
  }
  if (reserva.estado === 'confirmada') return reserva; // idempotente

  return prisma.reserva.update({ where: { id }, data: { estado: 'confirmada' } });
}

async function cancelarReserva(id) {
  const prisma = await getPrisma();
  const reserva = await prisma.reserva.findUnique({ where: { id } });
  if (!reserva) throw new AppError(404, 'Reserva no encontrada.', 'reserva_no_encontrada');

  if (reserva.estado === 'cancelada') return reserva; // idempotente

  return prisma.reserva.update({ where: { id }, data: { estado: 'cancelada' } });
}

module.exports = {
  listReservas,
  getReserva,
  crearReserva,
  confirmarReserva,
  cancelarReserva,
};
