'use strict';

const express = require('express');
const routes = require('./routes');
const errorHandler = require('./middlewares/errorHandler');

/**
 * Construye la app Express (sin escuchar). Separado de index.js para poder
 * testearla sin levantar el servidor ni depender de la base de datos.
 */
function createApp() {
  const app = express();

  // Endurecimiento basico (seguridad).
  app.disable('x-powered-by');
  app.use(express.json({ limit: '64kb' }));

  app.use(routes);

  // 404 para cualquier ruta no contemplada.
  app.use((req, res) => {
    res.status(404).json({ error: 'Recurso no encontrado', code: 'not_found' });
  });

  // Manejador central de errores (siempre al final).
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
