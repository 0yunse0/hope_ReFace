'use strict';

const express = require('express');
const router = express.Router();

const {
  saveInitialScores,
  getInitialScores,
} = require('../controllers/expressionsController');

// 초기 점수 저장
router.post('/scores', saveInitialScores);

// 초기 점수 조회(옵션)
router.get('/scores', getInitialScores);

module.exports = router;
