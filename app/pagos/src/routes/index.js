'use strict';

const { Router } = require('express');
const pagosRouter = require('./pagos.routes');

const router = Router();

/**
 * Health check liviano para el ALB y el healthCheck de ECS (path /health).
 * NO toca la base de datos: debe responder rapido aunque RDS este lento,
 * para no tumbar tareas sanas (DISPONIBILIDAD).
 */
router.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'svc-pagos' });
});

/**
 * Rutas de negocio. El prefijo /api/pagos coincide con el path-based routing
 * del ALB y del API Gateway (no hacen strip del prefijo).
 */
router.use('/api/pagos', pagosRouter);

module.exports = router;
