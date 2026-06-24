'use strict';

const { Router } = require('express');
const reservasRouter = require('./reservas.routes');

const router = Router();

/**
 * Health check liviano para el ALB y el healthCheck de ECS (path /health).
 * NO toca la base de datos: debe responder rapido aunque RDS este lento,
 * para no tumbar tareas sanas (DISPONIBILIDAD).
 */
router.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'svc-reservas' });
});

/**
 * Rutas de negocio. El prefijo /api/reservas coincide con el path-based
 * routing del ALB y del API Gateway (no hacen strip del prefijo).
 */
router.use('/api/reservas', reservasRouter);

module.exports = router;
