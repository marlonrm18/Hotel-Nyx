-- CreateEnum
CREATE TYPE "EstadoHabitacion" AS ENUM ('disponible', 'mantenimiento');

-- CreateEnum
CREATE TYPE "EstadoReserva" AS ENUM ('pendiente', 'confirmada', 'cancelada');

-- CreateEnum
CREATE TYPE "EstadoPago" AS ENUM ('pendiente', 'aprobado', 'rechazado');

-- CreateTable
CREATE TABLE "habitaciones" (
    "id" SERIAL NOT NULL,
    "numero" INTEGER NOT NULL,
    "tipo" TEXT NOT NULL,
    "capacidad" INTEGER NOT NULL,
    "precio_noche" DECIMAL(10,2) NOT NULL,
    "estado" "EstadoHabitacion" NOT NULL DEFAULT 'disponible',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "habitaciones_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reservas" (
    "id" SERIAL NOT NULL,
    "habitacion_id" INTEGER NOT NULL,
    "nombre_huesped" TEXT NOT NULL,
    "email_huesped" TEXT NOT NULL,
    "fecha_inicio" DATE NOT NULL,
    "fecha_fin" DATE NOT NULL,
    "estado" "EstadoReserva" NOT NULL DEFAULT 'pendiente',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "reservas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pagos" (
    "id" SERIAL NOT NULL,
    "reserva_id" INTEGER NOT NULL,
    "monto" DECIMAL(10,2) NOT NULL,
    "estado" "EstadoPago" NOT NULL DEFAULT 'pendiente',
    "mp_payment_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pagos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "habitaciones_numero_key" ON "habitaciones"("numero");

-- CreateIndex
CREATE INDEX "reservas_habitacion_id_idx" ON "reservas"("habitacion_id");

-- CreateIndex
CREATE INDEX "pagos_reserva_id_idx" ON "pagos"("reserva_id");

-- AddForeignKey
ALTER TABLE "reservas" ADD CONSTRAINT "reservas_habitacion_id_fkey" FOREIGN KEY ("habitacion_id") REFERENCES "habitaciones"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pagos" ADD CONSTRAINT "pagos_reserva_id_fkey" FOREIGN KEY ("reserva_id") REFERENCES "reservas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ─── REQUISITO CRITICO: anti-doble-reserva (EXCLUSION CONSTRAINT) ─────────────
-- Impide dos reservas activas (pendiente/confirmada) que se solapen en fechas
-- para la misma habitacion. Rango half-open '[)' (fin EXCLUSIVO): el checkout de
-- un huesped puede ser el check-in del siguiente. btree_gist permite combinar el
-- operador de igualdad (=) sobre habitacion_id con el de solapamiento (&&) sobre
-- el rango de fechas en un mismo indice GiST.
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE "reservas"
  ADD CONSTRAINT "reservas_no_overlap"
  EXCLUDE USING gist (
    "habitacion_id" WITH =,
    daterange("fecha_inicio", "fecha_fin", '[)') WITH &&
  )
  WHERE ("estado" IN ('pendiente', 'confirmada'));
