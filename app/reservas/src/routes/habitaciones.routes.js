'use strict';

const { Router } = require('express');
const ctrl = require('../controllers/habitaciones.controller');

const router = Router();

// '/disponibles' va ANTES de '/:id' para que no lo capture el parametro.
router.get('/disponibles', ctrl.disponibles);
router.get('/', ctrl.listar);
router.post('/', ctrl.crear);
router.get('/:id', ctrl.obtener);

module.exports = router;
