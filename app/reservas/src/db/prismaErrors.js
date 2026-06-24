'use strict';

/**
 * Detecta si un error proveniente de Prisma corresponde a la violacion de la
 * EXCLUSION CONSTRAINT anti-doble-reserva (`reservas_no_overlap`).
 *
 * PostgreSQL devuelve SQLSTATE 23P01 (exclusion_violation). Prisma no mapea
 * esta constraint a un codigo propio, asi que la reconocemos por el SQLSTATE
 * o por el nombre de la constraint en el mensaje/meta. Esto es el guardia
 * definitivo ante una condicion de carrera entre dos reservas simultaneas.
 */
function isExclusionViolation(err) {
  if (!err) return false;
  const message = String(err.message || '');
  const meta = err.meta || {};
  const metaText = `${meta.code || ''} ${meta.constraint || ''} ${meta.message || ''}`;

  return (
    err.code === '23P01' ||
    meta.code === '23P01' ||
    message.includes('23P01') ||
    message.includes('reservas_no_overlap') ||
    metaText.includes('reservas_no_overlap')
  );
}

/**
 * Detecta violacion de unicidad (P2002 de Prisma o SQLSTATE 23505).
 * Util, por ejemplo, para el numero de habitacion unico.
 */
function isUniqueViolation(err) {
  if (!err) return false;
  const message = String(err.message || '');
  return err.code === 'P2002' || err.code === '23505' || message.includes('23505');
}

module.exports = { isExclusionViolation, isUniqueViolation };
