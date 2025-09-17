// routes/expressions.js
'use strict';
const express = require('express');
const router = express.Router();

const { saveInitialScores, getInitialScores } =
  require('../controllers/expressionsController');

// 초기 점수 저장: /initial 과 /scores 둘 다 받기 (호환용)
router.post(['/initial', '/scores'], saveInitialScores);

// 초기 점수 조회: 동일
router.get(['/initial', '/scores'], getInitialScores);

module.exports = router;
