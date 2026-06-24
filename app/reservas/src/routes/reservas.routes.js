'use strict';

const { Router } = require('express');
const ctrl = require('../controllers/reservas.controller');
const habitacionesRouter = require('./habitaciones.routes');

const router = Router();

// Sub-recurso habitaciones. Se monta ANTES de '/:id' para evitar que
// '/habitaciones' sea interpretado como un id de reserva.
router.use('/habitaciones', habitacionesRouter);

router.post('/', ctrl.crear);
router.get('/', ctrl.listar);
router.get('/:id', ctrl.obtener);
router.patch('/:id/confirmar', ctrl.confirmar);
router.patch('/:id/cancelar', ctrl.cancelar);

module.exports = router;
