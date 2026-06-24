'use strict';

const { PrismaClient } = require('@prisma/client');
const { config } = require('../config');
const { getDbSecret } = require('./secrets');
const logger = require('../lib/logger');

/**
 * Construye la connection string de Postgres leyendo la password desde
 * Secrets Manager en runtime, y expone un PrismaClient singleton.
 *
 * La URL nunca se hardcodea ni se versiona: host/usuario/password vienen del
 * secret gestionado por Terraform. Se fuerza sslmode=require por seguridad.
 *
 * Prioridad de credenciales (igual que svc-reservas):
 *   1. DB_SECRET_ARN definido  → AWS Secrets Manager (produccion).
 *   2. Si NO esta definido     → fallback a process.env.DATABASE_URL (local).
 * Se loguea la fuente usada para detectar si en prod cayera al fallback.
 *
 * NOTA: svc-pagos solo SE CONECTA a la BD; NO aplica migraciones. El unico
 * dueño de las migraciones (prisma migrate deploy) es svc-reservas.
 */

let prisma = null;

function encode(value) {
  return encodeURIComponent(String(value));
}

async function buildConnectionString() {
  const secret = await getDbSecret();
  const { host, port, dbname, username, password } = secret;

  const params = new URLSearchParams({
    schema: config.dbSchema,
    sslmode: config.dbSslMode,
  });

  return (
    `postgresql://${encode(username)}:${encode(password)}@${host}:${port}` +
    `/${encode(dbname)}?${params.toString()}`
  );
}

/**
 * Devuelve el PrismaClient inicializado (lazy). La primera llamada resuelve
 * el secret y construye el cliente; las siguientes reutilizan el singleton.
 */
async function getPrisma() {
  if (prisma) return prisma;

  if (config.dbSecretId) {
    // Produccion: credenciales desde AWS Secrets Manager (PRIORIDAD).
    logger.info('db: usando Secrets Manager');
    const url = await buildConnectionString();
    prisma = new PrismaClient({ datasources: { db: { url } } });
  } else if (process.env.DATABASE_URL) {
    // Local: fallback a DATABASE_URL (p. ej. .env -> Postgres en Docker).
    logger.info('db: usando DATABASE_URL (local)');
    prisma = new PrismaClient();
  } else {
    throw new Error(
      'No hay credenciales de BD: define DB_SECRET_ARN (prod) o DATABASE_URL (local).'
    );
  }

  return prisma;
}

async function disconnect() {
  if (prisma) {
    await prisma.$disconnect();
    prisma = null;
  }
}

module.exports = { getPrisma, buildConnectionString, disconnect };
