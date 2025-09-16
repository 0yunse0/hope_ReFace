'use strict';

const express = require('express');
const router = express.Router();
const requireAuth = require('../middlewares/auth');
const { saveInitialExpressionScores } = require('../controllers/expressionsController');

router.use(requireAuth);

router.post('/scores', saveInitialExpressionScores);

module.exports = router;
