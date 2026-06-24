-- Hotel Nyx — Requisito critico anti-doble-reserva (PostgreSQL) — REFERENCIA
-- ----------------------------------------------------------------------------
-- ⚠️ YA INTEGRADO en la migracion Prisma formal:
--    prisma/migrations/20260618090106_init/migration.sql
-- La fuente de verdad es esa migracion (se aplica sola en local y en RDS).
-- Este archivo queda SOLO como documentacion de referencia. NO aplicar a mano.
--
-- Objetivo: impedir a nivel de base de datos que dos reservas "activas"
-- (estado pendiente o confirmada) se solapen en fechas para la misma
-- habitacion. Es la ultima linea de defensa contra la doble reserva: aunque
-- la aplicacion tenga una condicion de carrera, Postgres rechaza el INSERT/
-- UPDATE que viole la restriccion.
--
-- Como integrarlo con Prisma:
--   1. `prisma migrate dev --create-only` para generar una migracion vacia.
--   2. Pegar este contenido en el archivo migration.sql generado.
--   3. Aplicar con `prisma migrate deploy` contra la RDS real.

-- btree_gist permite combinar el operador de igualdad (=) sobre habitacion_id
-- con el operador de solapamiento (&&) sobre el rango de fechas dentro de un
-- mismo indice GiST.
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE reservas
  ADD CONSTRAINT reservas_no_overlap
  EXCLUDE USING gist (
    habitacion_id WITH =,
    -- '[)' = inicio inclusivo, fin EXCLUSIVO. En un hotel el dia de checkout de
    -- un huesped puede ser el dia de check-in del siguiente; con '[)' las
    -- reservas consecutivas (fecha_fin == fecha_inicio de la siguiente) NO se
    -- consideran solapadas, asi que se permiten.
    daterange(fecha_inicio, fecha_fin, '[)') WITH &&
  )
  WHERE (estado IN ('pendiente', 'confirmada'));
