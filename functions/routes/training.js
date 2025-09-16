const express = require('express');
const router = express.Router();
const {
  startSession, finalizeSession, listSessions, getSession
} = require('../controllers/trainingController');

router.post('/sessions', startSession);
router.put('/sessions/:sid', finalizeSession);
router.get('/sessions', listSessions);
router.get('/sessions/:sid', getSession);

module.exports = router;
