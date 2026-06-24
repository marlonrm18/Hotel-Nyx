'use strict';

/**
 * Detecta violacion de unicidad (P2002 de Prisma o SQLSTATE 23505).
 */
function isUniqueViolation(err) {
  if (!err) return false;
  const message = String(err.message || '');
  return err.code === 'P2002' || err.code === '23505' || message.includes('23505');
}

module.exports = { isUniqueViolation };
