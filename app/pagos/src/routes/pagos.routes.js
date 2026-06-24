'use strict';

const { Router } = require('express');
const ctrl = require('../controllers/pagos.controller');

const router = Router();

// El webhook va ANTES de '/:id' para que '/webhook' no se interprete como id.
router.post('/webhook', ctrl.webhook);

router.post('/', ctrl.iniciar);
router.get('/:id', ctrl.obtener);

module.exports = router;
