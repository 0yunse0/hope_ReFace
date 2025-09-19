// routes/expressions.js
'use strict';
const express = require('express');
const router = express.Router();

const {
  saveInitialScores,
  getInitialScores,
} = require('../controllers/expressionsController');

router.post(['/initial', '/scores'], saveInitialScores);

router.get(['/initial', '/scores'], getInitialScores);

module.exports = router;
