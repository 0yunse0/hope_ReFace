const express = require('express');
const router = express.Router();
const {
  startSession, finalizeSession, listSessions, getSession, getRecommendations,
} = require('../controllers/trainingController');

router.post('/sessions', startSession);
router.put('/sessions/:sid', finalizeSession);
router.get('/sessions', listSessions);
router.get('/sessions/:sid', getSession);
router.get('/recommendations', getRecommendations);

module.exports = router;
