# syntax=docker/dockerfile:1
# Hotel Nyx — svc-reservas (multi-stage, imagen minima, usuario no-root)

# ─── Stage 1: build (instala todo + genera el cliente Prisma) ─────────────────
FROM node:20-alpine AS build
WORKDIR /app

# Prisma necesita openssl para su query engine.
RUN apk add --no-cache openssl

# NOTA: `npm ci` requiere package-lock.json. Generarlo una sola vez en local
# con `npm install` (aun no ejecutado en este paso) antes del primer build.
COPY package*.json ./
RUN npm ci

# Generar el cliente Prisma a partir del schema.
COPY prisma ./prisma
RUN npx prisma generate

COPY src ./src

# ─── Stage 2: runtime (solo dependencias de produccion) ───────────────────────
FROM node:20-alpine AS runtime
ENV NODE_ENV=production \
    TZ=UTC

RUN apk add --no-cache openssl

WORKDIR /app

# Solo dependencias de produccion.
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Cliente Prisma ya generado y schema (en la imagen final no esta el CLI dev).
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/src ./src

# Usuario no-root (el usuario `node` ya viene en la imagen oficial).
USER node

EXPOSE 3000

CMD ["node", "src/index.js"]
